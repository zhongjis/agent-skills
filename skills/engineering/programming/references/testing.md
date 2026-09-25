# Testing Depth — Pyramid, Mocking, and Anti-Patterns

Test-design depth for the [testing policy in `SKILL.md`](../SKILL.md#testing-policy). `SKILL.md` owns the baseline-first policy, test-rung selection, budgets, and the prompt-test rule. This file owns the pyramid, Given/When/Then, mocking ladder, deterministic isolation, anti-patterns, and prompt-test implementation. [`code-smells.md`](code-smells.md) owns code smells; this file owns test smells.

## The test pyramid

The rungs support the test-rung policy in `SKILL.md`:

| Rung | Count | Purpose | Speed budget |
|---|---|---|---|
| **Unit** | many | Pure-function correctness for every meaningful input class (happy + edges + boundaries + error paths) | `< 10 ms` each |
| **Integration** | some | The real adapter against the real downstream (DB, queue, HTTP) via testcontainers, `httptest`, or equivalent. A unit test pretending to be integration is not integration coverage. | `< 1 s` each |
| **E2E scenario** | few | A narrative for a user-visible outcome. Spins the binary or full app; drives it through its real surface (HTTP route, CLI invocation, TUI keystroke); asserts the observable outcome, not internal state. | seconds, on CI |

## Given / When / Then

Every test — unit, integration, E2E — is structured by three blocks:

```
Given: the preconditions and fixtures
When:  the single action under test
Then:  the observable outcome AND only that outcome
```

One `When` per test. Multiple `When`s = multiple tests. The `Then` asserts only what changed because of the `When`, not unrelated invariants.

## Less mock, the better

Mocks are a last resort, not a default. Walk the ladder top-down and stop at the first rung that works:

| Priority | Test double | Use when |
|---|---|---|
| 1 | **Real object** | Constructable in `< 1 ms` — most domain types, pure functions, value objects. |
| 2 | **In-memory fake** | Stores, caches, queues: a real implementation backed by a map/slice. The fake has its OWN test proving it behaves like the real thing. |
| 3 | **Testcontainer / sandbox** | Real Postgres, Redis, S3-compatible (MinIO) via testcontainers. Slow but truthful. |
| 4 | **HTTP-level fake** | `httptest.Server` (Go), `respx` (Python), `msw` (TS) — fake at the wire, not at the SDK. |
| 5 | **Mock** | Only when 1–4 are genuinely infeasible (clock, randomness, external SaaS with no sandbox). Mock the narrowest seam, never a whole service. |

The rule: if your test fails when the production code's *implementation* changes but its *behavior* did not, it is over-mocked. Delete the mock; assert on observable outputs. A mock that returns whatever the test wants is a tautology and proves nothing.

## Efficient AND accurate — both

- **Accurate**: the test fails for the bug it names, and only that bug. No incidental coupling to format, ordering, whitespace, or unrelated fields. Assert on the contract, not on the dump.
- **Efficient**: the whole unit suite runs in `< 30 s` on a laptop, the integration suite in `< 5 min`. Cross those budgets → profile and split; fast tests run on every save, slow ones on push.
- **Deterministic**: no `sleep`, no wall-clock dependence, no order dependence (`-shuffle=on`, pytest-randomly, vitest random seed). Inject a `Clock`. Subscribe to the event; do not poll for it. Time-based flake is a bug.
- **Isolated**: every test starts from a known fixture and tears down (`t.TempDir()`, `t.Setenv()`, transactional rollback). Isolation extends **across processes**: suite-global resources — sandbox/cache roots, listen ports, container names — are namespaced per run (`mktemp`, port `0`/ephemeral, unique names) so two checkouts running the suite concurrently cannot interfere. A fixed shared path is a flake generator on a multi-agent workstation; its signature is "a different test fails each run".

## Prompt-test implementation

Apply `SKILL.md`'s prompt-test rule by asserting only what a machine consumes:

- the builder's routing decision — `expect(getPromptSource(model)).toBe("model-a")`, never the sentence that routing produces
- a structural token the runtime dispatches on — a tool name, a tag like `<agent-identity>`, a parsed frontmatter field
- the conditional the code enforces — skill loaded → tool present; `verbose=false` → directive absent
- a routing-bearing trigger fragment inside a parsed frontmatter `description` that a router (code, or an LLM skill-picker) dispatches on — pin the *minimal fragment that carries the routing decision*, never the surrounding style prose. Such pins let a later rewrite change every sentence around them while proving the routing contract survived.

If no machine consumes the text, there is no seam: write no test and say so in the PR; review guards prose. When you delegate test-writing, hand the child the behavior the test must distinguish ("fails if override precedence breaks"), never a ready-made assertion string, prompt fragment, or marker to copy — a prescribed mechanism that is wrong gets implemented faithfully, and the error ships with a green suite.

## Anti-patterns the skill rejects

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| Ignoring covering tests or a failing baseline | Hides existing findings and makes a new failure impossible to attribute. | Read covering tests and run the baseline before changing code; reproduce a bug before fixing it. |
| One mega-test asserting 12 things | First failure hides the next 11. | Split by `Then` clause — one assertion class per test. |
| Mocking every collaborator | Test passes regardless of real behavior. | Use a fake or the real thing. Mock only true unmockables. |
| `time.sleep(0.1)` to "let it finish" | Flake guaranteed. | Subscribe to the completion signal; bounded await. |
| Snapshot tests for everything | Locks formatting, not behavior. | Snapshots for *structure* (CLI help, JSON shape). Assertions for *behavior*. |
| Removing a failing test to "unblock CI" | You just deleted a bug report. | Fix the code or correct the test's premise. |
| `assert result is not None` and stopping there | Passes when result is garbage. | Assert the *value*, not its existence. |
| Expected value derived from the output under test | Recomputes a projection of the output and compares it to itself — passes even when the artifact is built from the wrong input. | Derive the expected value from the test's *input* (an independent known-good builder fed the fixture's input), or a stable routing decision. |
| Override/precedence fixture equal to its fallback | The assertion passes whether or not the code honored the override — precedence is never exercised. | Make every value the code must select, preserve, or override differ from its fallback. Prove it: force the regression the test names, watch it fail, revert. |
| Single happy-path E2E with no edges | Edge behavior can remain unexercised. | Cover edges at the appropriate rung; drive changed user-visible error behavior through the app's real surface. |
