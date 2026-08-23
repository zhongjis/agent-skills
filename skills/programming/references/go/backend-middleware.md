# HTTP Backend Middleware

Middleware ordering and canonical gin middleware implementations.

## Middleware ordering — the rule that actually matters

```
RequestID    →   Recovery    →   Logger    →   CORS    →   Auth    →   Handler
   (1)            (2)              (3)            (4)         (5)
```

1. **RequestID** is first so every subsequent middleware sees it.
2. **Recovery** wraps everything after it. Order: a panic in CORS still gets caught.
3. **Logger** sees the request_id and the recovered panic.
4. **CORS** before Auth — OPTIONS preflight must return without auth.
5. **Auth** is the last cross-cutting middleware. Per-route auth (admin-only) is mounted on a sub-router with extra middleware.

```go
// Public routes — no auth
api := r.Group("/api/v1")
{
    api.POST("/auth/login", h.Login)
    api.GET("/healthz", h.Healthz)
}

// Authenticated routes
authed := r.Group("/api/v1", middleware.Auth(authSvc))
{
    authed.GET("/users/:id", h.GetUser)
    authed.POST("/users", h.CreateUser)
}

// Admin-only routes
admin := r.Group("/api/v1/admin",
    middleware.Auth(authSvc),
    middleware.RequireRole("admin"))
{
    admin.GET("/users", h.ListAllUsers)
}
```

---

## Middleware examples

### `middleware/request_id.go`

```go
package middleware

import (
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/your-org/myservice/internal/obs"
)

func RequestID() gin.HandlerFunc {
    return func(c *gin.Context) {
        id := c.GetHeader("X-Request-ID")
        if id == "" {
            id = uuid.Must(uuid.NewV7()).String()
        }
        c.Request = c.Request.WithContext(obs.WithRequestID(c.Request.Context(), id))
        c.Header("X-Request-ID", id)
        c.Next()
    }
}
```

### `middleware/recovery.go`

```go
package middleware

import (
    "fmt"
    "log/slog"
    "net/http"
    "runtime/debug"

    "github.com/gin-gonic/gin"
)

func Recovery(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        defer func() {
            if r := recover(); r != nil {
                logger.ErrorContext(c.Request.Context(), "panic recovered",
                    slog.String("panic", fmt.Sprint(r)),
                    slog.String("stack", string(debug.Stack())),
                )
                if !c.Writer.Written() {
                    c.JSON(http.StatusInternalServerError,
                        gin.H{"error": "internal_error"})
                }
                c.Abort()
            }
        }()
        c.Next()
    }
}
```

### `middleware/request_logging.go`

```go
func RequestLogger(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        logger.InfoContext(c.Request.Context(), "http request",
            slog.String("method",  c.Request.Method),
            slog.String("path",    c.Request.URL.Path),
            slog.Int("status",     c.Writer.Status()),
            slog.Int("bytes",      c.Writer.Size()),
            slog.Duration("elapsed", time.Since(start)),
            slog.String("ip",      c.ClientIP()),
        )
    }
}
```

The `sloglint` policy requires typed attrs and an injected logger. Keep this form.

### `middleware/cors.go`

```go
func CORS() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Header("Access-Control-Allow-Origin",  "*")
        c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        c.Header("Access-Control-Allow-Headers", "*")
        if c.Request.Method == http.MethodOptions {
            c.AbortWithStatus(http.StatusNoContent)
            return
        }
        c.Next()
    }
}
```

Note the explicit OPTIONS short-circuit — preflight must NOT go through Auth.

---
