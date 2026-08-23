# Hono API Documentation UIs

Mount Scalar, Swagger UI, or both against one generated OpenAPI endpoint.

## Scalar

```typescript
import { Scalar } from "@scalar/hono-api-reference"

app.get(
  "/scalar",
  Scalar({
    url: "/openapi.json",
    theme: "saturn",
    pageTitle: "Service API Reference",
    favicon: "/favicon.svg",
  }),
)
```

Common mount paths are `/scalar`, `/docs`, and `/openapi/ui`. `url` must match the generated specification endpoint.

Use request-aware configuration when environment bindings affect documentation:

```typescript
app.get(
  "/scalar",
  Scalar((c) => ({
    url: "/openapi.json",
    proxyUrl: c.env.ENVIRONMENT === "development"
      ? "https://proxy.scalar.com"
      : undefined,
  })),
)
```

Prefer `Scalar`; avoid compatibility aliases when the supported export is available.

## Scalar configuration

Start with a small explicit configuration. Add options only for a concrete requirement:

```typescript
app.get(
  "/scalar",
  Scalar({
    url: "/openapi.json",
    pageTitle: "Service API Reference",
    theme: "saturn",
    layout: "modern",
    darkMode: true,
    hideModels: false,
    hideSearch: false,
    showOperationId: true,
    servers: [{ url: "https://api.example.com" }],
  }),
)
```

Avoid embedding environment-specific server URLs in shared source when they can come from config. Treat proxy and authentication settings as deployment config, not copy-paste defaults.

## Swagger UI

```typescript
import { swaggerUI } from "@hono/swagger-ui"

app.get(
  "/swagger",
  swaggerUI({
    url: "/openapi.json",
    title: "Swagger UI",
  }),
)
```

Common mount paths are `/swagger`, `/ui`, and `/docs`. Point `url` at the same OpenAPI endpoint used by Scalar.

Use a package-resolved asset version. Do not pin a moving CDN tag in durable documentation.

## Parallel mounts

Both UIs can serve the same specification:

```typescript
app.get("/scalar", Scalar({ url: "/openapi.json" }))
app.get("/swagger", swaggerUI({ url: "/openapi.json" }))
```

Keep one UI when product requirements do not need both. Multiple UIs increase asset surface but should not duplicate schema generation.

## Embedded specifications

Swagger UI configuration is URL-oriented. Keep the generated document at an HTTP endpoint and provide `url` or `urls`.

Scalar can accept inline content when a deployment requires it, but a shared endpoint is easier to inspect, cache, and test. Prefer the endpoint pattern unless embedding solves a specific constraint.
