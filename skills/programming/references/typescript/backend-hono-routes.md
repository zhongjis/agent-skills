# Hono Routes and OpenAPI

Route validation, response documentation, and OpenAPI generation with `hono-openapi`.

## Install

For a new Bun project:

```bash
bun add hono hono-openapi @scalar/hono-api-reference @hono/swagger-ui zod
bun add -d typescript @types/bun
```

For an existing project, use its declared package manager and lockfile. Resolve compatible dependency versions from the package manager instead of copying pinned versions from documentation.

## Complete app

```typescript
import { swaggerUI } from "@hono/swagger-ui"
import { Scalar } from "@scalar/hono-api-reference"
import { Hono } from "hono"
import { describeRoute, openAPIRouteHandler, resolver, validator } from "hono-openapi"
import { z } from "zod"

const QuerySchema = z.object({
  name: z.string().optional(),
})

const UserIdSchema = z.string().uuid().brand("UserId")

const UserResponseSchema = z.object({
  id: UserIdSchema,
  name: z.string(),
})

const CreateUserSchema = z.object({
  name: z.string().min(1),
})

const app = new Hono()

app.get("/health", (c) => c.json({ status: "ok" }))

app.get(
  "/hello",
  describeRoute({
    tags: ["Greetings"],
    summary: "Say hello",
    responses: {
      200: {
        description: "Successful greeting",
        content: {
          "application/json": {
            schema: resolver(z.object({ message: z.string() })),
          },
        },
      },
    },
  }),
  validator("query", QuerySchema),
  (c) => {
    const query = c.req.valid("query")
    return c.json({ message: `Hello ${query.name ?? "Hono"}!` })
  },
)

app.post(
  "/users",
  describeRoute({
    tags: ["Users"],
    summary: "Create a user",
    responses: {
      201: {
        description: "User created",
        content: {
          "application/json": {
            schema: resolver(UserResponseSchema),
          },
        },
      },
    },
  }),
  validator("json", CreateUserSchema),
  (c) => {
    const body = c.req.valid("json")
    const id = UserIdSchema.parse(crypto.randomUUID())
    return c.json({ id, name: body.name }, 201)
  },
)

app.get(
  "/openapi.json",
  openAPIRouteHandler(app, {
    documentation: {
      info: {
        title: "Hono API",
        version: "1.0.0",
      },
      servers: [{ url: "http://localhost:3000", description: "Local server" }],
    },
  }),
)

app.get("/scalar", Scalar({ url: "/openapi.json", pageTitle: "Hono API Reference" }))
app.get("/swagger", swaggerUI({ url: "/openapi.json", title: "Swagger UI" }))

export default app
```

The default export is required by Bun's Hono server adapter; it is the framework exception to the named-export rule.

## `hono-openapi` imports

Import route helpers from the package root:

```typescript
import {
  describeResponse,
  describeRoute,
  generateSpecs,
  openAPIRouteHandler,
  resolver,
  validator,
} from "hono-openapi"
```

Do not invent validator-specific subpaths. Standard Schema support lets the package consume compatible schemas through the same helpers.

## Route descriptions

`describeRoute()` attaches OpenAPI metadata. Wrap response schemas with `resolver()`:

```typescript
app.get(
  "/users/:id",
  describeRoute({
    tags: ["Users"],
    summary: "Get user",
    responses: {
      200: {
        description: "User found",
        content: {
          "application/json": { schema: resolver(UserResponseSchema) },
        },
      },
      404: { description: "User not found" },
    },
  }),
  validator("param", z.object({ id: UserIdSchema })),
  handler,
)
```

Keep response schema and status aligned with the handler. A documented response does not validate the emitted body at runtime; construct responses from parsed or internally trusted values.

## Request validation

`validator()` validates a request segment and adds its schema to generated documentation:

```typescript
validator("query", QuerySchema)
validator("json", CreateUserSchema)
validator("param", z.object({ id: UserIdSchema }))
validator("form", z.object({ avatar: z.instanceof(File) }))
```

Read validated values with `c.req.valid(target)`. Do not read the unparsed request again after validation.

## OpenAPI endpoint

Mount generated JSON with `openAPIRouteHandler()`:

```typescript
app.get(
  "/openapi.json",
  openAPIRouteHandler(app, {
    documentation: {
      info: { title: "Service API", version: "1.0.0" },
      servers: [{ url: "https://api.example.com" }],
    },
  }),
)
```

`/openapi.json` is a clear default. A project may instead group it under a prefix such as `/openapi/spec.json`; keep UI configuration consistent with that path.
