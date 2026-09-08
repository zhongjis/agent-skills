# sqlc Operations and Integration Tests

Goose migrations, testcontainers integration, and ORM tradeoffs.

## Migrations — goose

```bash
goose -dir internal/store/migrations create create_users sql
```

```sql
-- migrations/00001_create_users.sql
-- +goose Up
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- +goose Down
DROP TABLE users;
```

Run:

```bash
goose -dir internal/store/migrations postgres "$DATABASE_URL" up
goose -dir internal/store/migrations postgres "$DATABASE_URL" status
goose -dir internal/store/migrations postgres "$DATABASE_URL" down
```

Rules:

- One DDL change per migration. Never combine schema + data migrations in one file.
- `Down` is real, not a stub. CI runs `up` → `down` → `up` on a fresh container to prove reversibility.
- Migrations are append-only. Never edit a merged migration; add a new one.

`goose` can run programmatically as well:

```go
import "github.com/pressly/goose/v3"

if err := goose.UpContext(ctx, db, "migrations"); err != nil { ... }
```

Useful for tools that own their schema (CI runner, integration test setup).

---

## Integration tests — testcontainers

```go
package store_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/require"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
)

func newTestDB(t *testing.T) *pgxpool.Pool {
    t.Helper()
    ctx := context.Background()

    pgC, err := postgres.Run(ctx,
        "postgres:16-alpine",
        postgres.WithDatabase("test"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        postgres.BasicWaitStrategies(),
    )
    require.NoError(t, err)
    t.Cleanup(func() {
        require.NoError(t, pgC.Terminate(ctx))
    })

    dsn, err := pgC.ConnectionString(ctx, "sslmode=disable")
    require.NoError(t, err)

    pool, err := store.NewPool(ctx, dsn)
    require.NoError(t, err)
    t.Cleanup(pool.Close)

    require.NoError(t, goose.UpContext(ctx, /* sql.DB from pool */, "../migrations"))
    return pool
}

func TestUserStore_Create_returns_new_user(t *testing.T) {
    // Given
    pool := newTestDB(t)
    s := store.NewUserStore(pool)
    ctx := context.Background()

    // When
    user, err := s.Create(ctx, domain.User{
        ID:       domain.UserID(uuid.Must(uuid.NewV7())),
        Email:    mustEmail("a@b.com"),
        Username: mustUsername("alice"),
    })

    // Then
    require.NoError(t, err)
    require.NotEmpty(t, user.ID)

    fetched, err := s.Get(ctx, user.ID)
    require.NoError(t, err)
    require.Equal(t, user.Email, fetched.Email)
}
```

testcontainers spins a real Postgres in Docker, runs migrations, hands you a pool. Tests are slow (~2s startup) but **real** — no fake that diverges from production.

For test suites with many cases, build an explicit package fixture that returns cleanup and errors. `TestMain` calls it, reports setup or cleanup failures, then exits with the resulting status. Keep container and pool ownership in that fixture rather than package-startup hooks.

Each test uses a transaction rolled back at the end: fast and isolated.

---

## Why NOT gorm

| Concern | gorm | sqlc + pgx |
|---|---|---|
| Type safety | runtime reflection; column-to-field via tags | compile-time-checked from SQL |
| Performance | 2–5x slower than pgx | pgx is the fastest Go pg driver |
| N+1 queries | encouraged by `Preload` API | explicit JOIN in `.sql` |
| Migrations | AutoMigrate (unsafe in prod) | goose, explicit |
| Debugging | "what query did it run?" requires logging | the query IS the source |
| Cancellation | spotty ctx support | first-class |
| Active development | Yes but with churn and breaking changes | sqlc is stable |

Existing gorm projects: leave them. New code: sqlc + pgx.

---

## Sources

- sqlc docs: https://docs.sqlc.dev
- pgx: https://github.com/jackc/pgx
- goose: https://github.com/pressly/goose
- testcontainers-go: https://golang.testcontainers.org
- pgx pool config: https://pkg.go.dev/github.com/jackc/pgx/v5/pgxpool#Config
