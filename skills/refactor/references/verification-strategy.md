# Verification Strategy

How the [refactor workflow](../SKILL.md) proves behavior is preserved. Used to choose a strategy in Phase 3 and to run the gate after every step in Phase 5 and at the end in Phase 6.

## Detect the test infrastructure

Find how the project runs tests, types, and lint before planning any edit — read the project's scripts/config rather than assuming a runner:

- JS/TS: the `scripts` block of `package.json` (test / typecheck / lint).
- Python: `pytest.ini`, `pyproject.toml`, `setup.cfg`.
- Go: `*_test.go` and the module's task runner.
- Rust: `cargo test` / `cargo nextest`, `cargo clippy`.

Record the exact commands. The gate below runs these verbatim.

## Coverage → strategy matrix

Analyze coverage for the target (which test files exercise it, which cases and edge cases exist, integration vs unit), then choose:

| Coverage | Strategy |
|---|---|
| HIGH (> 80%) | Run the existing tests after each step. |
| MEDIUM (50–80%) | Run tests after each step and add safety assertions around the change. |
| LOW (< 50%) | **Pause.** Propose adding characterization tests first, then refactor. |
| NONE | **Block** an aggressive refactor. Add characterization tests, or refactor only under manual verification with explicit user sign-off. |

A characterization test pins current observable behavior (not implementation detail) so the refactor has a safety net. Write it, watch it pass against the *old* code, then refactor with it green throughout.

## The gate — run after every change

The Phase 5 post-step gate and the Phase 6 final check use the same three signals. Every one must be green before the step is marked complete or the workflow ends:

1. **Diagnostics** — your editor's LSP reports clean, or no worse than the pre-change baseline, on every touched file.
2. **Tests** — the relevant tests (Phase 5) or the full suite (Phase 6) pass. Read the actual result and confirm zero failures; running tests is not the same as verifying they passed.
3. **Typecheck** — the project's type checker is clean; no new errors introduced.

Phase 6 adds the linter and the build (if any) to the same gate, plus diagnostics on the complete set of changed files.

## Regression indicators

From the codemap and coverage analysis, name the specific things that must not change and check them explicitly at the gate:

- The specific tests that must stay green.
- The observable behavior that must be preserved (return values, side effects, error/exception behavior, edge-case handling).
- The public contracts that must not change (exported API signatures, wire formats, CLI surface).

## Failure recovery

If the gate fails: STOP, revert the failing change, diagnose the cause, then fix and retry, skip an optional step, or ask the user. Never proceed to the next step on a broken build or a failing test. After three consecutive failures on the same step, stop and escalate with the file, what you tried, what failed, and your hypothesis.
