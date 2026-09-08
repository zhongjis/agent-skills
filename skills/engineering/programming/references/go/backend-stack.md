# HTTP Backend Stack — gin + slog + validator + pgx

Canonical production HTTP service patterns, split by topic:

- [Setup and assembly](backend-setup.md) — dependencies, layout, config, injected logging, and server construction.
- [Middleware](backend-middleware.md) — ordering, request IDs, recovery, request logs, and CORS.
- [Handlers and streaming](backend-handlers.md) — boundary parsing, domain construction, and SSE.
- [Operations](backend-operations.md) — WebSockets, pgx wiring, health checks, and tests.

Use `golangci-strict.md` as logging and lint policy owner.
