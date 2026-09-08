# RPC — Connect-Go (default) + grpc-go (fallback) + protovalidate

`connectrpc/connect-go` is the default. It is wire-compatible with gRPC, also speaks Connect protocol + gRPC-Web from browsers, and uses ordinary `net/http` so middleware (logging, auth, tracing) composes the same way as REST. Reach for raw `grpc-go` only when you need a gRPC-specific feature Connect lacks.

---

## When Connect vs grpc-go

| Need | Use |
|---|---|
| Standard unary + server-streaming + client-streaming | **Connect** |
| Browser client without `grpc-web` proxy | **Connect** (native gRPC-Web support) |
| HTTP/1.1 fallback for hostile networks | **Connect** (gRPC requires HTTP/2 end-to-end) |
| Server reflection for `grpcurl` | grpc-go (Connect has reflection too, but ecosystem smaller) |
| Bidirectional streaming with frame-level control | grpc-go |
| Strict gRPC environment (Envoy with gRPC filters, Istio strict mode) | grpc-go |

**Default**: Connect.

---

## Toolchain — Buf, not protoc

Pin Buf and any local generators in repository tooling. Prefer remote plugins in `buf.gen.yaml`, which avoid local generator installation.

Buf replaces `protoc` for everything: linting, breaking-change detection, codegen, formatting. The `protoc` toolchain is dead-letter walking — every modern proto project uses Buf.

---

## Project layout

```
proto/
  buf.yaml
  buf.gen.yaml
  buf.lock
  myservice/v1/
    user.proto
    auth.proto

gen/
  myservice/v1/
    user.pb.go               # protoc-gen-go output
    auth.pb.go
    myservicev1connect/      # protoc-gen-connect-go output
      user.connect.go
      auth.connect.go
```

**`gen/` is committed.** Generated code is part of the API contract; CI proves it is up-to-date.

---

## `buf.yaml`

```yaml
version: v2
modules:
  - path: proto
lint:
  use:
    - STANDARD
breaking:
  use:
    - FILE
```

## `buf.gen.yaml`

```yaml
version: v2
managed:
  enabled: true
  override:
    - file_option: go_package_prefix
      value: github.com/your-org/myservice/gen
plugins:
  - remote: buf.build/protocolbuffers/go
    out: gen
    opt:
      - paths=source_relative
  - remote: buf.build/connectrpc/go
    out: gen
    opt:
      - paths=source_relative
  - remote: buf.build/bufbuild/validate-go
    out: gen
    opt:
      - paths=source_relative
```

The `buf.build/...` plugin URIs use Buf's hosted remote registry — no local plugin installation needed.

## Taskfile target

```yaml
gen:proto:
  cmds:
    - buf lint
    - buf format -w
    - buf generate
  sources:
    - proto/**/*.proto
    - buf.yaml
    - buf.gen.yaml
```

Run `task gen:proto` after editing any `.proto`. CI runs `buf generate` then `git diff --exit-code` to catch stale generated code.

---

## A `.proto` with validation

```proto
syntax = "proto3";

package myservice.v1;

import "buf/validate/validate.proto";

option go_package = "github.com/your-org/myservice/gen/myservice/v1;myservicev1";

service UserService {
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
  rpc GetUser(GetUserRequest)       returns (GetUserResponse);
  rpc StreamEvents(StreamEventsRequest) returns (stream Event);
}

message CreateUserRequest {
  string email    = 1 [(buf.validate.field).string.email = true];
  string username = 2 [
    (buf.validate.field).string.min_len = 3,
    (buf.validate.field).string.max_len = 32,
    (buf.validate.field).string.pattern = "^[a-zA-Z0-9_]+$"
  ];
  int32 age       = 3 [
    (buf.validate.field).int32.gte = 13,
    (buf.validate.field).int32.lte = 130
  ];
}

message CreateUserResponse {
  User user = 1;
}

message User {
  string id       = 1;
  string email    = 2;
  string username = 3;
  google.protobuf.Timestamp created_at = 4;
}
```

`protovalidate` replaces the abandoned `protoc-gen-validate` and integrates with Connect's interceptor pipeline.

---

## Server — Connect

```go
type UserServer struct {
    svc    *UserService
    logger *slog.Logger
}

func NewHandler(logger *slog.Logger, svc *UserService) (string, http.Handler, error) {
    validator, err := protovalidate.New()
    if err != nil {
        return "", nil, fmt.Errorf("create validator: %w", err)
    }
    options := connect.WithInterceptors(
        loggingInterceptor(logger),
        validateinterceptor.NewInterceptor(validator),
    )
    return myservicev1connect.NewUserServiceHandler(
        &UserServer{svc: svc, logger: logger},
        options,
    )
}

func (s *UserServer) CreateUser(
    ctx context.Context,
    req *connect.Request[myservicev1.CreateUserRequest],
) (*connect.Response[myservicev1.CreateUserResponse], error) {
    user, err := s.svc.Create(ctx, req.Msg.Email, req.Msg.Username, req.Msg.Age)
    if err != nil {
        return nil, mapError(ctx, s.logger, err)
    }
    return connect.NewResponse(&myservicev1.CreateUserResponse{
        User: userToProto(user),
    }), nil
}

func Run(ctx context.Context, logger *slog.Logger, svc *UserService) error {
    path, handler, err := NewHandler(logger, svc)
    if err != nil {
        return err
    }
    mux := http.NewServeMux()
    mux.Handle(path, handler)
    srv := &http.Server{
        Addr:    ":8080",
        Handler: h2c.NewHandler(mux, &http2.Server{}),
    }
    logger.InfoContext(ctx, "rpc server listening", slog.String("addr", srv.Addr))
    if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
        return fmt.Errorf("serve rpc: %w", err)
    }
    return nil
}
```

The handler is **just an `http.Handler`** — mount it in the same `http.ServeMux` as your REST routes if you want one binary serving both.

---

## Error mapping — Connect codes

```go
func mapError(ctx context.Context, logger *slog.Logger, err error) error {
    if err == nil { return nil }

    switch {
    case errors.Is(err, domain.ErrInvalidEmail),
         errors.Is(err, domain.ErrInvalidUsername):
        return connect.NewError(connect.CodeInvalidArgument, err)
    case errors.Is(err, ErrNotFound):
        return connect.NewError(connect.CodeNotFound, err)
    case errors.Is(err, ErrUnauthorized):
        return connect.NewError(connect.CodeUnauthenticated, err)
    case errors.Is(err, ErrConflict):
        return connect.NewError(connect.CodeAlreadyExists, err)
    default:
        logger.ErrorContext(ctx, "unmapped rpc error", slog.String("error", err.Error()))
        return connect.NewError(connect.CodeInternal, errors.New("internal"))
    }
}
```

Connect codes map 1:1 to gRPC codes. Clients see canonical error semantics.

---

## Logging interceptor

```go
func loggingInterceptor(logger *slog.Logger) connect.UnaryInterceptorFunc {
    return func(next connect.UnaryFunc) connect.UnaryFunc {
        return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
            start := time.Now()
            res, err := next(ctx, req)
            attrs := []slog.Attr{
                slog.String("proc",    req.Spec().Procedure),
                slog.Duration("elapsed", time.Since(start)),
            }
            if err != nil {
                attrs = append(attrs, slog.String("error", err.Error()))
                logger.LogAttrs(ctx, slog.LevelWarn, "rpc failed", attrs...)
            } else {
                logger.LogAttrs(ctx, slog.LevelInfo, "rpc ok", attrs...)
            }
            return res, err
        }
    }
}
```

For streaming, implement the full `connect.Interceptor` (`WrapStreamingClient`, `WrapStreamingHandler`). Pattern is identical.

---

## Server streaming

```go
func (s *UserServer) StreamEvents(
    ctx context.Context,
    req *connect.Request[myservicev1.StreamEventsRequest],
    stream *connect.ServerStream[myservicev1.Event],
) error {
    events, errs := s.svc.Subscribe(ctx, req.Msg.UserId)
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case e, ok := <-events:
            if !ok { return nil }
            if err := stream.Send(eventToProto(e)); err != nil {
                return err
            }
        case err := <-errs:
            return connect.NewError(connect.CodeInternal, err)
        }
    }
}
```

Same shape as SSE in `backend-stack.md`. Connect handles HTTP/2 framing.

---

## Client

```go
client := myservicev1connect.NewUserServiceClient(
    http.DefaultClient,
    "https://api.example.com",
    // Use connect.WithGRPC() if the server is grpc-go and you want strict gRPC framing.
    // Default is Connect protocol — works with Connect or gRPC servers transparently.
)

res, err := client.CreateUser(ctx, connect.NewRequest(&myservicev1.CreateUserRequest{
    Email:    "a@b.com",
    Username: "alice",
    Age:      30,
}))
if err != nil {
    var connectErr *connect.Error
    if errors.As(err, &connectErr) {
        logger.ErrorContext(ctx, "rpc failed",
            slog.String("code", connectErr.Code().String()),
            slog.String("message", connectErr.Message()))
    }
    return err
}
logger.InfoContext(ctx, "created", slog.String("id", res.Msg.User.Id))
```

---

## When you genuinely need raw grpc-go

```go
func RunGRPC(logger *slog.Logger, service myservicev1.UserServiceServer) error {
    lis, err := net.Listen("tcp", ":8080")
    if err != nil {
        return fmt.Errorf("listen: %w", err)
    }
    srv := grpc.NewServer(
        grpc.UnaryInterceptor(loggingUnaryInterceptor(logger)),
    )
    myservicev1.RegisterUserServiceServer(srv, service)
    if err := srv.Serve(lis); err != nil {
        return fmt.Errorf("serve grpc: %w", err)
    }
    return nil
}
```

The codegen is from `protoc-gen-go-grpc` (different binary from `protoc-gen-connect-go`). You can codegen **both** in the same `buf.gen.yaml` and switch by importing the right package. Most teams pick one.

---

## When NOT to use RPC at all

If your callers are all browsers, mobile apps, third-party developers, or the long tail of "things humans curl": **stay with REST + OpenAPI**. RPC's overhead is justified for service-to-service inside a single org. Outside that boundary, JSON over HTTP wins on debuggability.

`oapi-codegen/oapi-codegen/v2` generates Go server stubs and clients from OpenAPI 3 — the REST equivalent of what Connect does for proto. Same parse-don't-validate boundary discipline, different wire format.

---

## Sources

- Connect docs: https://connectrpc.com/docs/go/getting-started
- Buf: https://buf.build/docs
- protovalidate: https://github.com/bufbuild/protovalidate
- "Why we replaced protoc with buf" (Buf blog): https://buf.build/blog
- gRPC vs Connect comparison: https://connectrpc.com/docs/introduction
