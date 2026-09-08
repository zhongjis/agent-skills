# sqlc Schema and Queries

Tooling, layout, sqlc configuration, schema, queries, and generated types.

## Toolchain

Pin `sqlc` and `goose` in the repository's tool module and expose them through task-runner commands.

---

## Layout

```
internal/store/
├── sqlc.yaml                 # sqlc config
├── schema.sql                # the cumulative DDL sqlc parses
├── queries/                  # one *.sql per resource
│   ├── users.sql
│   ├── orders.sql
│   └── sessions.sql
├── sqlc/                     # GENERATED — do not hand-edit
│   ├── db.go
│   ├── models.go
│   ├── users.sql.go
│   ├── orders.sql.go
│   └── sessions.sql.go
├── migrations/               # goose migrations, ordered
│   ├── 00001_create_users.sql
│   └── 00002_add_orders.sql
├── pool.go                   # pgxpool factory
├── user_store.go             # domain-facing wrapper around sqlc
└── user_store_test.go        # testcontainers integration test
```

---

## `sqlc.yaml`

```yaml
version: "2"
sql:
  - engine: "postgresql"
    schema:  "schema.sql"
    queries: "queries"
    gen:
      go:
        package: "sqlc"
        out:     "sqlc"
        sql_package: "pgx/v5"
        emit_json_tags: false
        emit_prepared_queries: false
        emit_interface: true          # generates a Querier interface
        emit_exact_table_names: false
        emit_pointers_for_null_types: true
        emit_empty_slices: true
        overrides:
          - db_type: "uuid"
            go_type:
              import: "github.com/google/uuid"
              type:   "UUID"
          - db_type: "timestamptz"
            go_type:
              import: "time"
              type:   "Time"
```

Key choices:

- `sql_package: "pgx/v5"` — generated code uses pgx directly, not `database/sql`. Faster, type-safer.
- `emit_interface: true` — generates a `Querier` interface. Lets stores accept either `*pgxpool.Pool` or `pgx.Tx` for transaction support.
- `emit_pointers_for_null_types: true` — nullable columns become `*T`, not `sql.NullString`. Cleaner mapping to domain types.
- `overrides` for `uuid` → `google/uuid.UUID` and `timestamptz` → `time.Time`.

---

## `schema.sql`

```sql
-- internal/store/schema.sql
-- The CUMULATIVE schema sqlc parses. Not migrations — the end state.
-- Regenerate from a fresh DB via `pg_dump --schema-only`, or hand-maintain.

CREATE TABLE users (
    id         UUID         PRIMARY KEY,
    email      TEXT         NOT NULL UNIQUE,
    username   TEXT         NOT NULL UNIQUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_created_at ON users(created_at DESC);
```

---

## `queries/users.sql`

```sql
-- name: GetUser :one
SELECT id, email, username, created_at
FROM users
WHERE id = $1;

-- name: ListUsers :many
SELECT id, email, username, created_at
FROM users
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: CreateUser :one
INSERT INTO users (id, email, username)
VALUES ($1, $2, $3)
RETURNING id, email, username, created_at;

-- name: UpdateUserEmail :exec
UPDATE users
SET email = $2
WHERE id = $1;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

sqlc directives:

- `:one` — exactly one row; returns `(T, error)`. Returns `pgx.ErrNoRows` on miss.
- `:many` — zero or more rows; returns `([]T, error)`.
- `:exec` — no rows returned; returns `error`.
- `:execrows` — returns `(int64, error)` with affected row count.
- `:batchone` / `:batchmany` / `:batchexec` — pgx batch mode for bulk operations.

Run `task gen:sqlc` (or `sqlc generate`). The generated file is committed; CI checks it is up-to-date.

---

## Generated code shape (`sqlc/users.sql.go`)

```go
// GENERATED — do not edit
type User struct {
    ID        uuid.UUID
    Email     string
    Username  string
    CreatedAt time.Time
}

const getUser = `-- name: GetUser :one
SELECT id, email, username, created_at FROM users WHERE id = $1`

func (q *Queries) GetUser(ctx context.Context, id uuid.UUID) (User, error) {
    row := q.db.QueryRow(ctx, getUser, id)
    var u User
    err := row.Scan(&u.ID, &u.Email, &u.Username, &u.CreatedAt)
    return u, err
}
```

Type-safe inputs, type-safe outputs, compile-time-checked column-to-field mapping. **A schema change that drops a column breaks compilation.** Hand-rolled SQL would have failed at runtime.

---
