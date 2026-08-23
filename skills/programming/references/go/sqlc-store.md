# sqlc Store and Transactions

pgx pool construction, domain mapping, and transaction boundaries.

## `store/pool.go`

```go
package store

import (
    "context"
    "fmt"
    "time"

    "github.com/jackc/pgx/v5/pgxpool"
)

func NewPool(ctx context.Context, dsn string) (*pgxpool.Pool, error) {
    cfg, err := pgxpool.ParseConfig(dsn)
    if err != nil { return nil, fmt.Errorf("parse dsn: %w", err) }

    cfg.MaxConns        = 25
    cfg.MinConns        = 5
    cfg.MaxConnLifetime = time.Hour
    cfg.MaxConnIdleTime = 30 * time.Minute
    cfg.HealthCheckPeriod = 1 * time.Minute

    pool, err := pgxpool.NewWithConfig(ctx, cfg)
    if err != nil { return nil, fmt.Errorf("connect: %w", err) }

    if err := pool.Ping(ctx); err != nil {
        pool.Close()
        return nil, fmt.Errorf("ping: %w", err)
    }
    return pool, nil
}
```

`pgxpool.Pool` is `Querier`-compatible (implements the interface sqlc generates). Same pool flows into sqlc queries unchanged.

---

## `store/user_store.go` — domain ↔ sqlc

```go
package store

import (
    "context"
    "errors"
    "fmt"

    "github.com/google/uuid"
    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgxpool"

    "github.com/your-org/myservice/internal/domain"
    "github.com/your-org/myservice/internal/store/sqlc"
)

type UserStore struct {
    q *sqlc.Queries
}

func NewUserStore(pool *pgxpool.Pool) *UserStore {
    return &UserStore{q: sqlc.New(pool)}
}

func (s *UserStore) Get(ctx context.Context, id domain.UserID) (domain.User, error) {
    row, err := s.q.GetUser(ctx, uuid.UUID(id))
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return domain.User{}, domain.ErrUserNotFound
        }
        return domain.User{}, fmt.Errorf("get user %s: %w", id, err)
    }
    return rowToDomain(row)
}

func (s *UserStore) Create(ctx context.Context, u domain.User) (domain.User, error) {
    row, err := s.q.CreateUser(ctx, sqlc.CreateUserParams{
        ID:       uuid.UUID(u.ID),
        Email:    u.Email.String(),
        Username: u.Username.String(),
    })
    if err != nil {
        return domain.User{}, fmt.Errorf("create user: %w", err)
    }
    return rowToDomain(row)
}

func rowToDomain(r sqlc.User) (domain.User, error) {
    email, err := domain.NewEmail(r.Email)
    if err != nil {
        return domain.User{}, fmt.Errorf("db invariant: email %q: %w", r.Email, err)
    }
    username, err := domain.NewUsername(r.Username)
    if err != nil {
        return domain.User{}, fmt.Errorf("db invariant: username %q: %w", r.Username, err)
    }
    return domain.User{
        ID:        domain.UserID(r.ID),
        Email:     email,
        Username:  username,
        CreatedAt: r.CreatedAt,
    }, nil
}
```

The wrapping is verbose. **That is the point.** sqlc rows are storage representations; domain types are business representations. Mapping them explicitly is where invariants are enforced.

`pgx.ErrNoRows` becomes `domain.ErrUserNotFound` — callers never see storage-level errors.

---

## Transactions — pgx.Tx satisfies the Querier interface

```go
func (s *UserStore) CreateWithProfile(
    ctx context.Context,
    pool *pgxpool.Pool,
    u domain.User,
    p domain.Profile,
) error {
    tx, err := pool.Begin(ctx)
    if err != nil { return fmt.Errorf("begin: %w", err) }
    defer tx.Rollback(ctx)  // no-op if Commit succeeded

    q := s.q.WithTx(tx)  // sqlc.Queries bound to the tx

    if _, err := q.CreateUser(ctx, /* ... */); err != nil {
        return fmt.Errorf("create user: %w", err)
    }
    if _, err := q.CreateProfile(ctx, /* ... */); err != nil {
        return fmt.Errorf("create profile: %w", err)
    }
    return tx.Commit(ctx)
}
```

Pattern:

- `defer tx.Rollback(ctx)` immediately after `Begin` — safe even after Commit (returns "tx closed", which we ignore via the unhandled return).
- `q.WithTx(tx)` returns a `*Queries` bound to the tx.
- Last line: `tx.Commit(ctx)`.

For nested transactions across multiple stores, accept a `Querier` parameter:

```go
func (s *UserStore) CreateTx(ctx context.Context, q sqlc.Querier, u domain.User) (domain.User, error) {
    // uses q instead of s.q — caller decides if it's pool or tx
}
```

---
