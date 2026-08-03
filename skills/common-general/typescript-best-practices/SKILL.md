---
name: typescript-best-practices
description: Provides TypeScript patterns for type-first development, making illegal states unrepresentable, exhaustive handling, and runtime validation. Use when setting up tsconfig.json, creating type definitions, or ensuring type safety in JS/TS codebases.
upstream: https://github.com/0xBigBoss/claude-code/tree/main/.claude/skills/typescript-best-practices
---

# TypeScript Best Practices

Type-first JavaScript with strict typing, explicit boundaries, and maintainable module design.

## Pair with React Best Practices

When working with React components (`.tsx`, `.jsx`, or files importing React APIs), load `react-best-practices` alongside this skill. This skill covers TypeScript fundamentals; React-specific guidance belongs in the dedicated React skill.

## Quick Start

```bash
# Initialize project
bun init --typescript

# Type check
bunx tsc --noEmit

# Run tests
vitest run
```

## Contents

- Start here: `Quick Start`, `Version Coverage`, `Project Quick Picks`
- Core design: `Type-First Workflow`, `Make Illegal States Unrepresentable`, `Exhaustive Control Flow`
- Runtime boundaries: `Runtime Validation with Zod`, `Configuration`
- Compiler setup: `TypeScript 5.x Guidance`, `TypeScript 6.x Guidance`, `tsconfig Baseline`
- Deep examples: `REFERENCE.md`

## Version Coverage

This skill now covers both major branches you are likely to encounter:

- **TypeScript 5.x**: common in existing codebases and still relevant for migration and maintenance work.
- **TypeScript 6.x**: current stable line as of March 2026, with new defaults and several deprecations that materially affect tsconfig guidance.

The core design guidance in this skill applies to both. The main differences are compiler defaults, module-resolution expectations, and deprecated configuration paths.

## Project Quick Picks

| Scenario | Start here |
| --- | --- |
| New Bun app or bundled frontend | Use `moduleResolution: "bundler"`, then follow the TS6 guidance and baseline config. |
| Direct Node.js app or published package | Use `moduleResolution: "nodenext"`, add explicit `types`, and keep runtime resolution aligned with actual Node behavior. |
| Existing TS5 codebase | Keep `strict` explicit, adopt `satisfies` and `const` type parameters where they improve inference, and migrate deprecated config deliberately. |

## Type-First Workflow

Start with the contract, then implement to satisfy it:

1. Define the data model first
2. Define function inputs and outputs before logic
3. Let the compiler guide missing cases
4. Validate untrusted data at runtime

## Make Illegal States Unrepresentable

Prefer types that prevent invalid combinations at compile time.

### Discriminated unions

```ts
// Good: only valid combinations are representable
type RequestState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

// Bad: allows invalid combinations
// { loading: true, error: Error } is possible
type LooseRequestState<T> = {
  loading: boolean;
  data?: T;
  error?: Error;
};
```

### Branded domain primitives

```ts
type UserId = string & { readonly __brand: "UserId" };
type OrderId = string & { readonly __brand: "OrderId" };
```

### Literal unions from constants

```ts
const ROLES = ["admin", "user", "guest"] as const;
type Role = typeof ROLES[number];
```

### Explicit create/update/read models

```ts
type CreateUser = {
  email: string;
  name: string;
};

type UpdateUser = Partial<CreateUser>;

type User = CreateUser & {
  id: UserId;
  createdAt: Date;
};
```

## Practical Rules

- Enable `strict` mode and keep types close to the code they protect.
- Prefer `unknown` over `any` at boundaries.
- Prefer `satisfies` when checking object shapes without widening useful literal inference.
- Use `const`, `readonly`, and immutable updates by default.
- Avoid mutating function parameters; return new values instead.
- Keep modules focused. Split files once they mix concerns or become hard to scan.
- Add or update focused tests when changing logic.

## TypeScript 5.x Guidance

TypeScript 5.x projects usually need more explicit compiler guidance.

- Keep `strict: true` explicit in `tsconfig.json`.
- Prefer `moduleResolution: "bundler"` for Bun or bundled web apps, and `moduleResolution: "nodenext"` for direct Node.js packages and apps.
- Use `satisfies` for config objects and lookup tables so shape checking does not widen literals unnecessarily.
- Use `const` type parameters when authoring helpers that should preserve narrow literal inference.
- Prefer `verbatimModuleSyntax: true` and `import type` for type-only imports when you care about predictable emitted JavaScript.

```ts
const routes = {
  home: "/",
  settings: "/settings",
} satisfies Record<string, `/${string}`>;

function tupleOf<const T extends readonly string[]>(value: T): T {
  return value;
}
```

## TypeScript 6.x Guidance

TypeScript 6.0 keeps the same core type-system practices, but the official defaults and deprecations changed enough that they deserve separate guidance.

- Do not assume old defaults: TS6 now defaults `strict` to `true`, `module` to `esnext`, and `types` to `[]`.
- Prefer explicit compiler settings anyway when you want reproducible behavior across TS5 and TS6.
- Add a `types` array intentionally in Node, Bun, and test projects instead of relying on ambient discovery.
- Set `rootDir` explicitly if you expect output rooted at `src/`.
- Expect `noUncheckedSideEffectImports` to be on by default and fix missing or mistyped side-effect imports instead of relying on silent resolution.
- Avoid `target: "es5"`; TS6 deprecates it.
- Avoid `moduleResolution: "node"` / `"node10"`; use `bundler` or `nodenext` instead.
- Avoid recommending `baseUrl` as a default path-alias baseline; prefer runtime-aligned module resolution and only add path mapping deliberately.

```json
{
  "compilerOptions": {
    "rootDir": "./src",
    "types": ["node"]
  }
}
```

## Exhaustive Control Flow

Every code path should return or throw. Use exhaustive `switch` statements so new cases fail at compile time instead of runtime.

```ts
type Status = "active" | "inactive";

export function processStatus(status: Status): string {
  switch (status) {
    case "active":
      return "processing";
    case "inactive":
      return "skipped";
    default: {
      const exhaustiveCheck: never = status;
      throw new Error(`Unhandled status: ${exhaustiveCheck}`);
    }
  }
}
```

## Runtime Validation with Zod

Use schemas as the source of truth for untrusted input and inferred types for the rest of the code.

```ts
import { z } from "zod";

const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().min(1),
  createdAt: z.string().transform((value) => new Date(value)),
});

type User = z.infer<typeof UserSchema>;
```

### Boundary rules

- Use `safeParse` when validation failure is expected and needs UI handling.
- Use `parse` at trust boundaries where invalid data means a broken contract.
- Compose schemas with `.extend()`, `.pick()`, `.omit()`, `.merge()`, and `.partial()` instead of duplicating them.

```ts
export async function fetchUser(id: string): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  if (!response.ok) {
    throw new Error(`fetch user ${id} failed: ${response.status}`);
  }

  const payload: unknown = await response.json();
  return UserSchema.parse(payload);
}
```

## Configuration

Load configuration once at startup, validate it, and pass around a typed config object instead of reading from `process.env` throughout the codebase.

```ts
import { z } from "zod";

const ConfigSchema = z.object({
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
});

export const config = ConfigSchema.parse(process.env);
```

## Module Structure

- Prefer one component, hook, or utility per file.
- Colocate tests with implementation (`foo.ts` and `foo.test.ts`).
- Group by feature before grouping by file type.
- Move verbose examples and deep reference material into `REFERENCE.md` instead of bloating the skill entrypoint.

## tsconfig Baseline

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "strict": true,
    "rootDir": "./src",
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedSideEffectImports": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "verbatimModuleSyntax": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true
  },
  "include": ["src"],
  "exclude": ["node_modules"]
}
```

If you are on TS6 and need ambient globals, add a `types` array explicitly, for example `"types": ["node"]`, `"types": ["bun"]`, or test-runner types as needed.

## Related Skills

- **react-best-practices**: React-specific effects, hooks, refs, and component patterns
- **vitest**: Test utilities and mocking
- **bun**: Package management and scripting
- **ast-grep**: Pattern matching for refactoring
