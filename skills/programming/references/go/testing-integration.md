# Go Integration and Snapshot Testing

E2E scenarios, goroutine leak detection, and golden tests.

## E2E scenario tests

```go
//go:build e2e

func Test_E2E_user_can_signup_then_login(t *testing.T) {
    // Given — full server in a goroutine
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    pool := newTestDB(t)              // testcontainers Postgres
    server := startServer(t, pool)    // real gin engine on a random port
    defer server.Close()

    client := server.Client()

    // When — sign up
    resp, err := client.Post(server.URL+"/api/v1/users",
        "application/json",
        strings.NewReader(`{"email":"a@b.com","username":"alice","password":"PassWord!23"}`),
    )
    require.NoError(t, err)
    require.Equal(t, 201, resp.StatusCode)

    // When — log in
    resp, err = client.Post(server.URL+"/api/v1/auth/login",
        "application/json",
        strings.NewReader(`{"email":"a@b.com","password":"PassWord!23"}`),
    )
    require.NoError(t, err)
    require.Equal(t, 200, resp.StatusCode)

    var body struct{ Token string `json:"token"` }
    require.NoError(t, json.NewDecoder(resp.Body).Decode(&body))
    require.NotEmpty(t, body.Token)

    // Then — token works on protected endpoint
    req, _ := http.NewRequestWithContext(ctx, "GET", server.URL+"/api/v1/me", nil)
    req.Header.Set("Authorization", "Bearer "+body.Token)
    resp, err = client.Do(req)
    require.NoError(t, err)
    require.Equal(t, 200, resp.StatusCode)
}
```

Patterns:

- `//go:build e2e` build tag separates slow E2E from fast unit tests. Run with `go test -tags=e2e ./...`.
- One narrative per test: "user can sign up then log in". One `Test_E2E_*` per user-visible outcome.
- Real DB via testcontainers, real gin engine, real HTTP. **No mocks.** The point is to catch integration bugs.
- Bounded context — every E2E gets a `context.WithTimeout` so failures don't hang CI.

---

## Goroutine leak detection

```go
package mypkg

import (
    "testing"
    "go.uber.org/goleak"
)

func TestMain(m *testing.M) {
    goleak.VerifyTestMain(m,
        goleak.IgnoreTopFunction("github.com/prometheus/client_golang/prometheus.(*Registry)..."),
    )
}
```

One line at the top of every package that spawns goroutines. Catches the bug class the race detector cannot.

---

## Snapshot / golden tests — `autogold`

```go
import "github.com/hexops/autogold/v2"

func Test_RenderHelp_matches_snapshot(t *testing.T) {
    // Given
    cmd := newRootCmd()

    // When
    out := captureOutput(t, func() { _ = cmd.Help() })

    // Then
    autogold.ExpectFile(t, out)
}
```

First run: `go test -update ./...` writes `testdata/Test_RenderHelp.golden`. Future runs compare; failures show a diff. Re-approve intentional changes with `-update`.

**Use snapshots for STRUCTURE, not BEHAVIOR.** Good targets:

- CLI `--help` output
- JSON response shape
- Generated SQL queries
- Rendered prompts (assert the structure, not exact wording — see SKILL.md prompt-test rule)

Bad targets: a function's return value where you should `require.Equal` on the actual structure.

---
