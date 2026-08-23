# Go Testing Fundamentals

Tools, naming, table-driven tests, fakes, and narrow mocks.

## Tools

| Need | Use |
|---|---|
| Assertions | `stretchr/testify/require` (and `assert` only inside table loops) |
| Mocks | `go.uber.org/mock` (gomock successor) |
| Goroutine leaks | `go.uber.org/goleak` |
| Snapshots / golden | `hexops/autogold/v2` |
| Property-based | `pgregory.net/rapid` |
| HTTP mocks (outbound) | `h2non/gock` |
| HTTP test server (inbound) | stdlib `net/http/httptest` |
| Integration containers | `testcontainers/testcontainers-go` |
| TUI | `charm.land/bubbletea/v2/teatest` |
| Bench tooling | stdlib `testing.B` + `perf.dev/benchstat` |

---

## Test naming — Given / When / Then in the name

```go
// ──── PATTERN ────
// Test_<Subject>_<Outcome>_when_<Condition>
//   OR
// Test_<Subject>_<Action>_<ExpectedOutcome>

func Test_Email_NewEmail_lowercases_input(t *testing.T)
func Test_Email_NewEmail_rejects_input_without_at_sign(t *testing.T)
func Test_UserService_Create_persists_user_when_inputs_valid(t *testing.T)
func Test_UserService_Create_returns_validation_error_when_email_invalid(t *testing.T)
```

A test name should answer "what behavior is this asserting?" without reading the body. Names that need a comment to explain them are misnamed.

---

## Single test — explicit Given/When/Then

```go
func Test_Email_NewEmail_rejects_input_without_at_sign(t *testing.T) {
    // Given
    raw := "not-an-email"

    // When
    _, err := domain.NewEmail(raw)

    // Then
    require.Error(t, err)
    require.ErrorIs(t, err, domain.ErrInvalidEmail)
}
```

`require.*` fails the test immediately on miss. Use `require` for preconditions and primary assertions. Use `assert.*` only inside table-driven loops where you want all cases to report.

---

## Table-driven tests

```go
func Test_Email_NewEmail(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    string
        wantErr error
    }{
        {"lowercases", "ALICE@example.com", "alice@example.com", nil},
        {"trims whitespace", "  bob@example.com  ", "bob@example.com", nil},
        {"rejects missing @", "no-at-sign", "", domain.ErrInvalidEmail},
        {"rejects empty", "", "", domain.ErrInvalidEmail},
        {"rejects too long", strings.Repeat("a", 256) + "@e.com", "", domain.ErrInvalidEmail},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // When
            got, err := domain.NewEmail(tt.input)

            // Then
            if tt.wantErr != nil {
                require.ErrorIs(t, err, tt.wantErr)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tt.want, got.String())
        })
    }
}
```

Rules:

- One **scenario** per row, not one **assertion** per row.
- Subtest names are sentences in lowercase; `t.Run(tt.name, ...)` makes them filterable: `go test -run Test_Email_NewEmail/rejects_missing_@`.
- The loop body itself is Given/When/Then in shape.
- For Go 1.22+, the loop var capture works correctly without the `tt := tt` shadow line — the `copyloopvar` linter enforces the new style.

---

## Less mocks — the priority order

In Go specifically:

1. **Real implementation.** Domain types, pure functions, value objects — instantiate them. They are fast.
2. **In-memory fake** that satisfies the interface. Has its own test suite proving behavioral parity with the real impl.
3. **`httptest.Server`** for HTTP collaborators (real wire, no internet).
4. **`testcontainers`** for stateful collaborators (Postgres, Redis, S3-compatible, Kafka).
5. **gomock** ONLY for: clocks, randomness, third-party SaaS with no sandbox.

### Example: an in-memory fake

```go
// Real interface
type UserRepo interface {
    Save(ctx context.Context, u domain.User) error
    Get(ctx context.Context, id domain.UserID) (domain.User, error)
}

// In-memory fake — production-quality, tested separately
type FakeUserRepo struct {
    mu    sync.RWMutex
    users map[domain.UserID]domain.User
}

func NewFakeUserRepo() *FakeUserRepo {
    return &FakeUserRepo{users: map[domain.UserID]domain.User{}}
}

func (r *FakeUserRepo) Save(ctx context.Context, u domain.User) error {
    r.mu.Lock(); defer r.mu.Unlock()
    r.users[u.ID] = u
    return nil
}

func (r *FakeUserRepo) Get(ctx context.Context, id domain.UserID) (domain.User, error) {
    r.mu.RLock(); defer r.mu.RUnlock()
    u, ok := r.users[id]
    if !ok { return domain.User{}, domain.ErrUserNotFound }
    return u, nil
}
```

The fake has the same observable behavior as the real one. Tests against `FakeUserRepo` survive when the production repo's internals change. Tests against a gomock stub of `UserRepo` break.

**A test passing against a fake AND a test passing against the real impl is the gold standard.** Run the same test suite twice — once with the fake, once with testcontainers. The fakes earn their keep when the suites diverge.

### Example: gomock for the unmockable

```go
//go:generate mockgen -source=clock.go -destination=mocks/clock_mock.go -package=mocks

type Clock interface {
    Now() time.Time
}

// In a test:
ctrl := gomock.NewController(t)
clock := mocks.NewMockClock(ctrl)
clock.EXPECT().Now().Return(fixedTime).AnyTimes()
```

Mock the narrowest seam. Never mock `UserRepo` if a fake suffices.

---
