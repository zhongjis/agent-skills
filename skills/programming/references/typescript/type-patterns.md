# Type Patterns

How to use TypeScript's type system to catch bugs at compile time.

---

## Branded types — distinct validated primitives

Same runtime type, different meaning. Create branded values by parsing runtime evidence, not by asserting a raw primitive.

```typescript
import { z } from "zod"

const UserIdSchema = z.string().uuid().brand("UserId")
const OrderIdSchema = z.string().uuid().brand("OrderId")

type UserId = z.infer<typeof UserIdSchema>
type OrderId = z.infer<typeof OrderIdSchema>

function UserId(value: unknown): UserId {
  return UserIdSchema.parse(value)
}

function OrderId(value: unknown): OrderId {
  return OrderIdSchema.parse(value)
}

function getUser(id: UserId): User { ... }

getUser(UserId("9e3d3ec7-2f06-4ee8-88cf-46e90e4a6591")) // OK
getUser(OrderId("9e3d3ec7-2f06-4ee8-88cf-46e90e4a6591")) // type error
getUser("9e3d3ec7-2f06-4ee8-88cf-46e90e4a6591") // type error
```

Use for IDs, indices, units, or any primitive pair where swapping is a bug. Parse at creation boundaries; pass branded values internally without re-validation.

---

## as const — literal types from values

Freezes a value to its narrowest possible type. The foundation for enum-free TypeScript.

```typescript
const ROLES = ["admin", "user", "guest"] as const
type Role = (typeof ROLES)[number]  // "admin" | "user" | "guest"

const HTTP_STATUS = {
  OK: 200,
  NOT_FOUND: 404,
  INTERNAL: 500,
} as const
type HttpStatus = (typeof HTTP_STATUS)[keyof typeof HTTP_STATUS]  // 200 | 404 | 500
```

**Use when**: fixed set of constants. Replaces `enum` entirely.
**Skip when**: the set is open-ended or user-defined.

---

## satisfies — validate without widening

Type-checks a value against a type while preserving the literal type. Best of both worlds.

```typescript
type Config = Record<string, string | number>

// BAD — widens to Record<string, string | number>
const config: Config = { api: "https://api.example.com", timeout: 30 }
config.api  // string | number — lost the narrowing

// GOOD — validates AND preserves literal types
const config = {
  api: "https://api.example.com",
  timeout: 30,
} satisfies Config
config.api      // string (narrowed)
config.timeout  // number (narrowed)
```

**Use when**: you want type validation on a value without losing narrowing.

## const type parameters — preserve literal inference

TypeScript 5.x `const` type parameters preserve narrow literals in generic helpers without requiring callers to write `as const`.

```typescript
function tupleOf<const T extends readonly string[]>(value: T): T {
  return value
}

const routes = tupleOf(["/", "/settings"])
// readonly ["/", "/settings"]
```

Use when a helper should retain caller-provided literal shapes; use an ordinary type parameter when widening is intended.

---

## Discriminated unions — algebraic data types

Model every outcome as a type. Force the caller to handle all cases.

```typescript
type GetUserResult =
  | { readonly kind: "found"; readonly user: User }
  | { readonly kind: "not_found"; readonly id: UserId }
  | { readonly kind: "forbidden"; readonly reason: string }
```

The `kind` field (or `type`, `status`, `_tag`) is the discriminant. TypeScript narrows on it automatically.

---

## Exhaustive switch — assertNever

Every switch on a discriminated union ends with a default that calls `assertNever`.

```typescript
function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${JSON.stringify(x)}`)
}

function handleResult(result: GetUserResult): string {
  switch (result.kind) {
    case "found":
      return result.user.name
    case "not_found":
      return `No user ${result.id}`
    case "forbidden":
      return `Denied: ${result.reason}`
    default:
      return assertNever(result)
  }
}
```

Add a new variant to `GetUserResult`? The compiler errors on the `assertNever` call until you handle it.

---

## Narrowing — let the compiler follow your logic

TypeScript narrows types through `typeof`, `instanceof`, `in`, equality checks, and discriminants.

```typescript
function process(value: string | number | null): string {
  if (value === null) return "nothing"
  // compiler knows: string | number

  if (typeof value === "string") return value.toUpperCase()
  // compiler knows: number

  return String(value * 2)
}
```

### Custom type guards

```typescript
function isNonNull<T>(value: T | null | undefined): value is T {
  return value != null
}

const items = [1, null, 2, undefined, 3]
const clean = items.filter(isNonNull)  // number[]
```

---

## import type — separate values from types

Always use `import type` for type-only imports. Enforced by `verbatimModuleSyntax`.

```typescript
import type { User, Config } from "./types"   // erased at runtime
import { createUser } from "./services"        // kept at runtime
```

For mixed imports:
```typescript
import { createUser, type User } from "./users"
```

---

## Utility types — quick reference

| Need | Use |
|---|---|
| All properties readonly | `Readonly<T>` |
| All properties optional | `Partial<T>` |
| All properties required | `Required<T>` |
| Pick specific properties | `Pick<T, "a" \| "b">` |
| Omit specific properties | `Omit<T, "a" \| "b">` |
| Key-value map | `Record<K, V>` |
| Extract from union | `Extract<T, U>` |
| Exclude from union | `Exclude<T, U>` |
| Return type of function | `ReturnType<typeof fn>` |
| Parameters of function | `Parameters<typeof fn>` |
| Awaited type | `Awaited<Promise<T>>` → `T` |

---

## Sources

- TypeScript Handbook: [Narrowing](https://www.typescriptlang.org/docs/handbook/2/narrowing.html)
- TypeScript Handbook: [Template Literal Types](https://www.typescriptlang.org/docs/handbook/2/template-literal-types.html)
- Total TypeScript: [as const](https://www.totaltypescript.com/as-const)
