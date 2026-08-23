# Advanced Go Testing

Property tests, HTTP tests, determinism, benchmarks, coverage, and TUI tests.

## Property-based tests — `rapid`

```go
import "pgregory.net/rapid"

func Test_Email_NewEmail_then_String_roundtrips(t *testing.T) {
    rapid.Check(t, func(t *rapid.T) {
        // Given — generate valid emails
        local  := rapid.StringMatching(`[a-z]{3,10}`).Draw(t, "local")
        domain := rapid.StringMatching(`[a-z]{3,10}\.com`).Draw(t, "domain")
        raw    := local + "@" + domain

        // When
        e, err := domain.NewEmail(raw)
        require.NoError(t, err)

        // Then — round-trip property
        e2, err := domain.NewEmail(e.String())
        require.NoError(t, err)
        require.Equal(t, e, e2)
    })
}
```

`rapid` shrinks failing cases to minimal counterexamples. Use for:

- Round-trips (parse → serialize → parse).
- Algebraic properties (sort produces ordered, dedup is idempotent, JSON marshal/unmarshal is involutive).
- Invariants under random input (validator never panics, serializer never produces invalid UTF-8).

---

## HTTP testing — `httptest`

### Server side

```go
func Test_GetUser_returns_user_for_existing_id(t *testing.T) {
    // Given
    svc := newSvcWithFake(t)
    r := gin.New()
    h := &Handler{Users: svc}
    h.Mount(r)

    req := httptest.NewRequest("GET", "/api/v1/users/u-1", nil)
    rec := httptest.NewRecorder()

    // When
    r.ServeHTTP(rec, req)

    // Then
    require.Equal(t, 200, rec.Code)
    var body domain.User
    require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
    require.Equal(t, "u-1", string(body.ID))
}
```

### Client side — `httptest.NewServer`

```go
func Test_Client_retries_on_500(t *testing.T) {
    // Given — fake upstream
    var calls int
    srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        calls++
        if calls < 3 {
            w.WriteHeader(500)
            return
        }
        w.WriteHeader(200)
        _, _ = w.Write([]byte(`{"ok":true}`))
    }))
    defer srv.Close()

    client := myclient.New(srv.URL)

    // When
    err := client.DoSomething(context.Background())

    // Then
    require.NoError(t, err)
    require.Equal(t, 3, calls)
}
```

`httptest.NewServer` spins a real HTTP server on a random port. The fake handler implements the upstream contract. Test the client against the contract, not the implementation.

---

## Determinism — the cardinal rules

- **No `time.Sleep` in tests.** If you need delay, you need a Clock injection.
- **`go test -shuffle=on`** in every CI run.
- **`go test -count=1`** to defeat the cache.
- **Subscribe to the event, do not poll for it.** Channels, callbacks, `t.Cleanup` over polling.
- **`t.Parallel()`** for tests that share no state. Speeds up large suites by 4-8x.

A test that fails 1-in-10 runs is a bug, not flake. The race detector + `-shuffle=on` + ordering hygiene catches >95% of "flake".

---

## Benchmarks — `testing.B` + `benchstat`

```go
func Benchmark_NewEmail(b *testing.B) {
    for b.Loop() {  // Go 1.24+ idiom, replaces `for i := 0; i < b.N; i++`
        _, _ = domain.NewEmail("alice@example.com")
    }
}
```

Run:

```bash
go test -bench=. -count=10 -benchmem ./... | tee bench.txt
benchstat bench.txt   # statistical comparison
```

Always `-count=10` for stable means. `-benchmem` reports allocations. A 5%-slower benchmark in one run is noise; 10 runs + benchstat tells you what is real.

To compare before/after a change:

```bash
git stash
go test -bench=. -count=10 ./... > before.txt
git stash pop
go test -bench=. -count=10 ./... > after.txt
benchstat before.txt after.txt
```

---

## Coverage — the right target

Run:

```bash
go test -race -shuffle=on -coverprofile=cover.out ./...
go tool cover -html=cover.out -o cover.html
```

**Aim for 80%+ on `internal/domain` and `internal/service`.** Boundary code (handlers, store mappers) is exercised by integration tests, where line coverage understates what is actually verified. Do not chase 100% — the last 5% is usually error paths that need fault-injection to hit.

The `golangci-lint` config does not enforce a minimum — coverage as a CI gate becomes a goal-displacement metric. Treat it as feedback, not requirement.

---

## TUI testing — `teatest`

```go
import teatest "charm.land/bubbletea/v2/teatest"

func Test_Counter_increments_on_space(t *testing.T) {
    // Given
    tm := teatest.NewTestModel(t, initial(), teatest.WithInitialTermSize(80, 24))

    // When
    tm.Send(tea.KeyPressMsg{Code: ' '})

    // Then
    final := tm.FinalModel(t).(model)
    require.Equal(t, 1, final.count)
}
```

For full-view regression, snapshot the rendered output via `autogold`.

---

## Antipatterns the skill rejects

| Bad | Why | Good |
|---|---|---|
| `if got != want { t.Errorf("expected %v got %v", want, got) }` | Reinvents `require.Equal` | Use testify |
| `time.Sleep(100 * time.Millisecond)` after triggering async work | Flake | Subscribe to completion signal, bounded await |
| `t.Skip(...)` to silence a known failure | Buries the bug | Fix or open an issue; never silently skip |
| One mega-test asserting 12 things | First failure hides next 11 | Split by `Then` |
| Snapshot-everything | Locks formatting, not behavior | Snapshots for structure, asserts for values |
| Mock every collaborator | Test asserts implementation, not behavior | Real or fake, never mock everything |
| Test calls private function via `_test.go` in same package only | Couples test to implementation | Test through the public surface |

---

## Sources

- testify: https://github.com/stretchr/testify
- goleak: https://github.com/uber-go/goleak
- autogold: https://github.com/hexops/autogold
- rapid: https://pkg.go.dev/pgregory.net/rapid
- testcontainers-go: https://golang.testcontainers.org
- benchstat: https://pkg.go.dev/golang.org/x/perf/cmd/benchstat
- "Go test naming conventions" (Dave Cheney): https://dave.cheney.net/practical-go/presentations/qcon-china.html
