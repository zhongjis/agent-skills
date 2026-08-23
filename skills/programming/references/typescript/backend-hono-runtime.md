# Hono Runtime and Compatibility

Bun entrypoints, schema compatibility, startup, and durable troubleshooting rules.

## Bun entrypoint

Bun can serve a Hono application from its default export:

```typescript
import { Hono } from "hono"

const app = new Hono()
app.get("/", (c) => c.text("Hello Bun!"))

export default app
```

For a custom port, export Bun's server-adapter object:

```typescript
export default {
  port: 3000,
  fetch: app.fetch,
}
```

`fetch: app.fetch` supplies a server callback to Bun. It is not an outbound bare-fetch recipe.

Useful scripts:

```json
{
  "scripts": {
    "dev": "bun run --hot src/index.ts",
    "start": "bun run src/index.ts",
    "typecheck": "tsc --noEmit"
  }
}
```

Use these defaults for new Bun projects. Preserve an existing project's runtime, `packageManager`, scripts, and lockfile.

## OpenAPI compatibility

Treat generated OpenAPI dialect as a library capability. Before depending on dialect-specific behavior, inspect the installed `hono-openapi` version and test the generated document.

The API's own `info.version` is application metadata:

```typescript
openAPIRouteHandler(app, {
  documentation: {
    info: {
      title: "Service API",
      version: "1.0.0",
    },
  },
})
```

Do not confuse application metadata with package versions. If a consumer requires another OpenAPI dialect, verify support in installed package docs or add an explicit, tested conversion step.

## Zod compatibility

Prefer Zod schemas that satisfy Standard Schema through the installed `hono-openapi` release:

```typescript
import { z } from "zod"

const EventSchema = z.object({
  id: z.string().uuid().brand("EventId"),
  occurredAt: z.string().datetime(),
})
```

Resolve compatibility from installed package peer dependencies and release notes. Do not copy a time-sensitive package matrix into durable docs.

For an existing project on another Zod major, keep its supported integration until a deliberate migration. Add compatibility packages only when installed dependency metadata requires them.

## Common pitfalls

1. **Wrong helper name** — inspect exports from the installed `hono-openapi` package; use `openAPIRouteHandler` in this stack.
2. **Invented subpath imports** — import `describeRoute`, `validator`, `resolver`, and `openAPIRouteHandler` from `hono-openapi`.
3. **Missing peer dependency** — let the active package manager resolve peers, then inspect its diagnostics rather than mixing lockfiles.
4. **Confusing packages** — `hono-openapi` and `@hono/zod-openapi` expose different APIs. Follow the package already selected by the project.
5. **UI path mismatch** — Scalar or Swagger UI `url` must match the OpenAPI endpoint.
6. **Unchecked brands** — create branded IDs with schema parsing; never assert a raw primitive into a brand.
7. **Outbound HTTP policy** — use the configured `ky` client from application infrastructure. Hono's `app.fetch` is server adaptation, not an outbound client.

## Quick start

```bash
mkdir my-api
cd my-api
bun init -y
bun add hono hono-openapi @scalar/hono-api-reference @hono/swagger-ui zod
bun add -d typescript @types/bun
```

Create `app.ts` from [`backend-hono-routes.md`](backend-hono-routes.md), then run:

```bash
bun run --hot app.ts
```

Expected endpoints from that example:

- `GET /health` — health check
- `GET /hello?name=world` — validated query and documented response
- `POST /users` — validated body and branded response ID
- `GET /openapi.json` — generated OpenAPI document
- `GET /scalar` — Scalar UI
- `GET /swagger` — Swagger UI
