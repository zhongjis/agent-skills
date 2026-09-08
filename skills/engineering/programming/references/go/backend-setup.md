# HTTP Backend Setup

Service dependencies, layout, config, logging, and explicit server assembly.

## `go.mod`

```go
module github.com/your-org/myservice

go 1.23

require (
    github.com/gin-gonic/gin v1.10.1
    github.com/go-playground/validator/v10 v10.22.1
    github.com/caarlos0/env/v11 v11.2.2
    github.com/google/uuid v1.6.0
    github.com/jackc/pgx/v5 v5.7.6
    golang.org/x/sync v0.18.0
)
```

---

## Project structure

```
cmd/server/main.go          # ≤ 50 LOC; flags → run.Execute(ctx)
internal/
  cmd/run.go                # ~150 LOC; signal handling, config load, server.Run
  config/config.go          # env-driven Config struct
  api/
    server.go               # gin.Engine setup, route mounting, http.Server
    middleware/
      request_id.go
      request_logging.go
      auth.go
      recovery.go
      cors.go
    handlers/
      users.go              # one file per resource
      streams.go            # SSE / WebSocket endpoints
  domain/                   # smart-constructor types (Email, UserID, ...)
  service/                  # business logic
  store/                    # pgx + sqlc
  obs/
    logger.go               # slog setup
```

---

## `cmd/server/main.go`

```go
package main

import (
    "context"
    "log/slog"
    "os"
    "os/signal"
    "syscall"

    "github.com/your-org/myservice/internal/cmd"
)

func main() {
    ctx, stop := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
    if err := cmd.Execute(ctx, logger); err != nil {
        logger.ErrorContext(ctx, "fatal", slog.String("error", err.Error()))
        os.Exit(1)
    }
}
```

That is the entire `main`. Anything more is a smell.

---

## `internal/config/config.go`

```go
package config

import (
    "time"
    "github.com/caarlos0/env/v11"
)

type Config struct {
    Host            string        `env:"HOST"             envDefault:"0.0.0.0"`
    Port            int           `env:"PORT"             envDefault:"8080"`
    DatabaseURL     string        `env:"DATABASE_URL,required"`
    ReadTimeout     time.Duration `env:"READ_TIMEOUT"     envDefault:"15s"`
    WriteTimeout    time.Duration `env:"WRITE_TIMEOUT"    envDefault:"30s"`
    ShutdownTimeout time.Duration `env:"SHUTDOWN_TIMEOUT" envDefault:"20s"`
    LogLevel        string        `env:"LOG_LEVEL"        envDefault:"info"`
    LogFormat       string        `env:"LOG_FORMAT"       envDefault:"json"`
    Env             string        `env:"ENV"              envDefault:"development"`
}

func Load() (Config, error) {
    var cfg Config
    if err := env.Parse(&cfg); err != nil {
        return Config{}, err
    }
    return cfg, nil
}
```

---

## `internal/obs/logger.go`

```go
package obs

import (
    "context"
    "fmt"
    "io"
    "log/slog"
)

type ctxKey struct{ name string }
var requestIDKey = ctxKey{"request_id"}

func NewLogger(out io.Writer, level, format string) (*slog.Logger, error) {
    var lvl slog.Level
    if err := lvl.UnmarshalText([]byte(level)); err != nil {
        return nil, fmt.Errorf("parse log level: %w", err)
    }

    opts := &slog.HandlerOptions{Level: lvl, AddSource: true}
    var h slog.Handler
    switch format {
    case "text":
        h = slog.NewTextHandler(out, opts)
    case "json":
        h = slog.NewJSONHandler(out, opts)
    default:
        return nil, fmt.Errorf("unsupported log format %q", format)
    }
    return slog.New(&ctxHandler{Handler: h}), nil
}

// ctxHandler pulls request_id from ctx into every log line.
type ctxHandler struct{ slog.Handler }

func (h *ctxHandler) Handle(ctx context.Context, r slog.Record) error {
    if id, ok := ctx.Value(requestIDKey).(string); ok && id != "" {
        r.AddAttrs(slog.String("request_id", id))
    }
    return h.Handler.Handle(ctx, r)
}

func WithRequestID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, requestIDKey, id)
}
```

---

## `internal/api/server.go`

```go
package api

import (
    "context"
    "fmt"
    "log/slog"
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/your-org/myservice/internal/api/handlers"
    "github.com/your-org/myservice/internal/api/middleware"
    "github.com/your-org/myservice/internal/config"
)

type Server struct {
    cfg    config.Config
    srv    *http.Server
    logger *slog.Logger
}

func New(cfg config.Config, logger *slog.Logger, h *handlers.Handler) *Server {
    gin.SetMode(gin.ReleaseMode)
    r := gin.New()

    // Middleware order matters — see "Middleware ordering" below.
    r.Use(
        middleware.RequestID(),     // 1. assign request_id first
        middleware.Recovery(logger), // 2. recovery wraps everything
        middleware.RequestLogger(logger),
        middleware.CORS(),
    )

    h.Mount(r)

    return &Server{
        cfg:    cfg,
        logger: logger,
        srv: &http.Server{
            Addr:         fmt.Sprintf("%s:%d", cfg.Host, cfg.Port),
            Handler:      r,
            ReadTimeout:  cfg.ReadTimeout,
            WriteTimeout: cfg.WriteTimeout,
        },
    }
}

func (s *Server) Run(ctx context.Context) error {
    errCh := make(chan error, 1)
    go func() {
        s.logger.InfoContext(ctx, "server starting",
            slog.String("addr", s.srv.Addr))
        if err := s.srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            errCh <- err
        }
        close(errCh)
    }()

    select {
    case <-ctx.Done():
        s.logger.InfoContext(ctx, "shutdown signal received")
        shutdownCtx, cancel := context.WithTimeout(
            context.WithoutCancel(ctx), s.cfg.ShutdownTimeout)
        defer cancel()
        return s.srv.Shutdown(shutdownCtx)
    case err := <-errCh:
        return err
    }
}
```

Notes:

- `gin.New()` not `gin.Default()` — `Default()` adds `Logger()` (text format, not slog) and `Recovery()` (no logger injection). We replace both.
- `gin.SetMode(gin.ReleaseMode)` silences debug output. Production assumed.
- `http.Server` with explicit timeouts. The default `nil` timeouts are a DoS waiting to happen.
- Graceful shutdown: SIGINT/SIGTERM cancels the ctx → `Shutdown(shutdownCtx)` gives in-flight requests up to `ShutdownTimeout` to finish.

---
