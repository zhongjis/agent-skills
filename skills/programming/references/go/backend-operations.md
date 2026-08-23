# HTTP Backend Operations

WebSocket handling, database wiring, health checks, and server tests.

## WebSocket upgrade

```go
import "github.com/gorilla/websocket"

type Handler struct {
    logger   *slog.Logger
    upgrader *websocket.Upgrader
}

func NewHandler(logger *slog.Logger) *Handler {
    return &Handler{
        logger: logger,
        upgrader: &websocket.Upgrader{
            ReadBufferSize:  4096,
            WriteBufferSize: 4096,
            CheckOrigin: func(r *http.Request) bool {
                return allowedOrigin(r.Header.Get("Origin"))
            },
        },
    }
}

func (h *Handler) WebSocketEcho(c *gin.Context) {
    conn, err := h.upgrader.Upgrade(c.Writer, c.Request, nil)
    if err != nil {
        h.logger.ErrorContext(c.Request.Context(), "ws upgrade failed",
            slog.String("error", err.Error()))
        return
    }
    defer func() {
        if err := conn.Close(); err != nil {
            h.logger.WarnContext(c.Request.Context(), "ws close failed",
                slog.String("error", err.Error()))
        }
    }()

    for {
        mt, msg, err := conn.ReadMessage()
        if err != nil { return }
        if err := conn.WriteMessage(mt, msg); err != nil { return }
    }
}
```

For long-lived connections, use `conn.SetReadDeadline` + `SetPongHandler` for keepalive. CLIProxyAPI's `wsrelay` package is a reference implementation.

---

## Database wiring — pgx pool, injected, never global

```go
package store

import (
    "context"
    "fmt"
    "github.com/jackc/pgx/v5/pgxpool"
)

func NewPool(ctx context.Context, dsn string) (*pgxpool.Pool, error) {
    cfg, err := pgxpool.ParseConfig(dsn)
    if err != nil {
        return nil, fmt.Errorf("parse dsn: %w", err)
    }
    cfg.MaxConns = 25
    cfg.MinConns = 5
    cfg.MaxConnLifetime = time.Hour
    cfg.MaxConnIdleTime = 30 * time.Minute

    pool, err := pgxpool.NewWithConfig(ctx, cfg)
    if err != nil {
        return nil, fmt.Errorf("connect: %w", err)
    }
    if err := pool.Ping(ctx); err != nil {
        pool.Close()
        return nil, fmt.Errorf("ping: %w", err)
    }
    return pool, nil
}
```

See `sqlc-pgx.md` for queries.

---

## Healthcheck

```go
func (h *Handler) Healthz(c *gin.Context) {
    if err := h.pool.Ping(c.Request.Context()); err != nil {
        c.JSON(503, gin.H{"db": "down", "error": err.Error()})
        return
    }
    c.JSON(200, gin.H{"ok": true})
}
```

Mount BEFORE auth. Health checks must be unauthenticated.

---

## Testing the server

```go
func TestCreateUser_returns_201_for_valid_input(t *testing.T) {
    // Given
    h := newTestHandler(t)
    r := gin.New()
    h.Mount(r)

    body := `{"email":"a@b.com","username":"alice"}`
    req := httptest.NewRequest("POST", "/api/v1/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    rec := httptest.NewRecorder()

    // When
    r.ServeHTTP(rec, req)

    // Then
    require.Equal(t, http.StatusCreated, rec.Code)
    var got struct{ ID string `json:"id"` }
    require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
    require.NotEmpty(t, got.ID)
}
```

See `testing.md` for full patterns (testcontainers integration, table-driven, goleak).

---

## Sources

- gin docs: https://gin-gonic.com/docs/
- CLIProxyAPI (reference impl): https://github.com/router-for-me/CLIProxyAPI
- pgx pool: https://pkg.go.dev/github.com/jackc/pgx/v5/pgxpool
- SSE spec: https://html.spec.whatwg.org/multipage/server-sent-events.html
- Go's `http.Server` graceful shutdown: https://pkg.go.dev/net/http#Server.Shutdown
