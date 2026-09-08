# HTTP Backend Handlers and Streaming

Canonical handlers and production SSE streaming.

## Handlers — the canonical shape

```go
package handlers

import (
    "errors"
    "log/slog"
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/go-playground/validator/v10"
    "github.com/your-org/myservice/internal/domain"
    "github.com/your-org/myservice/internal/httperr"
    "github.com/your-org/myservice/internal/service"
)

type Handler struct {
    Users   *service.UserService
    Streams *service.ChatService
    logger  *slog.Logger
}

func New(users *service.UserService, streams *service.ChatService, logger *slog.Logger) *Handler {
    return &Handler{Users: users, Streams: streams, logger: logger}
}

func (h *Handler) Mount(r gin.IRouter) {
    api := r.Group("/api/v1")
    api.POST("/users", h.CreateUser)
    api.GET("/users/:id", h.GetUser)
}

type createUserReq struct {
    Email    string `json:"email"    binding:"required,email"`
    Username string `json:"username" binding:"required,alphanum,min=3,max=32"`
}

func (h *Handler) CreateUser(c *gin.Context) {
    var req createUserReq
    if err := c.ShouldBindJSON(&req); err != nil {
        writeBindingError(c, err)
        return
    }

    email, err := domain.NewEmail(req.Email)
    if err != nil {
        httperr.Write(c, h.logger, err)
        return
    }
    username, err := domain.NewUsername(req.Username)
    if err != nil {
        httperr.Write(c, h.logger, err)
        return
    }

    user, err := h.Users.Create(c.Request.Context(), email, username)
    if err != nil {
        httperr.Write(c, h.logger, err)
        return
    }
    c.JSON(http.StatusCreated, user)
}

func writeBindingError(c *gin.Context, err error) {
    var vErr validator.ValidationErrors
    if errors.As(err, &vErr) {
        out := make(map[string]string, len(vErr))
        for _, fe := range vErr {
            out[fe.Field()] = fe.Tag()
        }
        c.JSON(http.StatusBadRequest, gin.H{"errors": out})
        return
    }
    c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_json"})
}
```

See `data-modeling.md` for the validator tag reference; see `error-handling.md` for the `httperr.Write` funnel.

---

## SSE streaming — the production pattern

CLIProxyAPI streams OpenAI-compatible SSE for hundreds of concurrent clients. The pattern:

```go
func (h *Handler) StreamChat(c *gin.Context) {
    ctx, cancel := context.WithCancel(c.Request.Context())
    defer cancel()

    req, err := bindStreamRequest(c)
    if err != nil {
        httperr.Write(c, h.logger, err)
        return
    }

    // 1. Set SSE headers BEFORE writing any body
    c.Header("Content-Type",  "text/event-stream")
    c.Header("Cache-Control", "no-cache")
    c.Header("Connection",    "keep-alive")
    c.Header("X-Accel-Buffering", "no") // disable nginx buffering

    // 2. Obtain the flusher — REQUIRED for streaming
    flusher, ok := c.Writer.(http.Flusher)
    if !ok {
        httperr.Write(c, h.logger, errors.New("streaming unsupported"))
        return
    }

    // 3. Pull chunks from upstream
    chunks, errs := h.Streams.StreamCompletions(ctx, req)

    for {
        select {
        case <-ctx.Done():
            return  // client disconnected, ctx cancelled
        case chunk, ok := <-chunks:
            if !ok {
                fmt.Fprint(c.Writer, "data: [DONE]\n\n")
                flusher.Flush()
                return
            }
            fmt.Fprintf(c.Writer, "data: %s\n\n", chunk)
            flusher.Flush()
        case err := <-errs:
            // Error mid-stream — emit as SSE event and bail
            fmt.Fprintf(c.Writer, "event: error\ndata: %s\n\n", err.Error())
            flusher.Flush()
            return
        }
    }
}
```

Key facts:

- **Headers MUST be set before the first `Write`.** Otherwise gin auto-sets `Content-Type: text/plain`.
- **`c.Writer.(http.Flusher)` is the streaming primitive.** Without `flusher.Flush()`, the response is buffered and arrives as one blob at the end.
- **Always respond to `<-ctx.Done()`.** A disconnected client must stop upstream work — otherwise you generate tokens for nothing.
- **The trailing `\n\n` per event is wire-mandatory** for SSE parsing. Missing it = the client never sees the event.

---
