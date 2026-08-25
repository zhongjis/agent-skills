---
name: remove-ai-slops
description: "Remove AI-generated code smells (slop) from a branch diff or an explicit file list while preserving behavior: lock behavior with regression tests FIRST, run a categorized safe-to-risky cleanup pass, then verify with quality gates. Covers obvious comments, over-defensive code, excessive complexity, needless abstraction, boundary violations, dead code, duplication, behavior-preserving performance fixes, missing tests, and oversized modules, with concrete per-language slop patterns. MUST USE when asked to \"remove slop\", \"deslop\", \"clean AI code\", \"clean up AI-generated code\", \"remove AI slop\", \"strip slop\", or to clean AI-generated patterns from recent changes."
adaptedFrom:
  - "https://github.com/code-yeongyu/oh-my-openagent/blob/dev/packages/shared-skills/skills/remove-ai-slops/SKILL.md"
  - "https://github.com/scanaislop/aislop"
---

# Remove AI Slops

Clean AI-generated slop from a bounded set of changed files while strictly preserving behavior. Lock behavior with green regression tests, run a categorized multi-pass cleanup, then verify with quality gates and a critical review.

The core safety invariant: **behavior is locked by green tests before a single line is removed.** A checklist alone is not safety; a passing regression test is. When behavior equivalence is not obvious, the default action is SKIP, not GUESS.

## Inputs

- **Default scope**: branch diff vs `merge-base main` — no arguments needed.
- **Optional scope**: an explicit file list passed by the caller.

## References

- [`references/categories.md`](references/categories.md) owns what counts as slop: the ten categories with their KEEP/REFACTOR rules, and a concrete per-language detector table. Consult it during Phase 4 for every file.
- [`references/report-format.md`](references/report-format.md) owns the output template, the critical-review checklist, and the anti-patterns. Consult it during Phase 5–6.

## Quality Gates

A pass is complete only when all applicable gates are green. Report `N/A` explicitly for a gate that is genuinely not configured — never skip silently.

| Gate | Tool | Pass condition |
|---|---|---|
| Regression tests | project's test runner | all green |
| Lint | project's linter | zero errors (pre-existing warnings OK) |
| Typecheck | language-server / type-checker diagnostics on changed files | zero new errors |
| Unit/integration tests | project's test runner | all green (pre-existing failures noted, not introduced) |
| Static/security scan | project's scanner | zero new findings, or `N/A` if not configured |

## Process

### Phase 0 — Plan

Create a task list covering the phases below and keep exactly one in progress, so a long multi-file pass never loses its place.

### Phase 1 — Determine scope

If the caller passed file paths, that is the scope. Otherwise:

```bash
git diff $(git merge-base main HEAD)..HEAD --name-only
```

Filter out deleted, binary, and generated/vendored files (`node_modules/`, `dist/`, `target/`, lockfiles). List the final scope.

### Phase 2 — Lock behavior with regression tests

For each in-scope source file:

1. Identify the observable behavior it exposes (exported functions, HTTP handlers, CLI commands, classes used elsewhere).
2. Find whether existing tests cover that behavior.
3. If behavior is uncovered or weakly covered, **write the narrowest regression test that pins current behavior BEFORE editing the file.** Pin observable outputs, not implementation details. A PROSE file (prompt, `SKILL.md`, rule, markdown) has no behavioral seam — do NOT add a text/word-count pin; cover only a machine-consumed value or leave it to review.
4. Run the relevant tests. They must be **green** before any cleanup begins.

If you cannot establish a green baseline, STOP and report. Do not clean on unverified ground.

### Phase 3 — Plan: existence first, then smells

The largest, safest deletion is code that should not have existed. Before categorizing smells, run the **deletion ladder** on each changed unit:

- **Delete entirely** — the behavior is not needed (YAGNI, speculative, dead on arrival).
- **Reuse** — an existing helper or pattern in this repo already does it; call it instead.
- **Platform / stdlib / native / dependency** — the language, runtime, or an installed dependency already does it (a hand-rolled date picker → `<input type="date">`, a custom query parser → `URLSearchParams`).
- **Simplify in place** — it must exist; make it smaller.

Only units that land on **Simplify in place** proceed to the smell categories. For a diff that **fixes a bug**, grep the callers of every shared function it touches and prefer one root-cause fix at the shared seam over repeated per-caller guards.

Produce an explicit per-file plan before removal: the ladder outcome, the categories present, the safe→risky order, and the risk level.

**Intentional shortcuts:** if the plan deliberately keeps a bounded simplification (a naive scan fine under N rows, an O(n²) path), mark it in-code with a `debt:` comment naming the ceiling and the upgrade trigger — and where the project's linter recognises an inline-suppression marker (e.g. aislop's `// aislop-ignore-next-line <rule> -- reason`), pair it so the shortcut is not re-flagged as slop on the next scan. List it under "Remaining Risks / Deferred" in the report. A simplification with a known ceiling and no marker is indistinguishable from a bug.

Order rule (safest → riskiest): comments → dead code → defensive → duplication → complexity → abstraction/boundary → performance → tests → oversized-modules.

### Phase 4 — Remove slop, one focused pass per file

Process each in-scope file through the categories in [`references/categories.md`](references/categories.md), applying its KEEP and REFACTOR rules verbatim, in the safe→risky order above.

**Parallelize in bounded batches when the harness supports subagents.** Give each file its own focused pass with this skill's categories loaded, dispatched with enough reasoning depth to honor the KEEP rules rather than slipping into surface fixes. Process files in batches of about five, one file per worker: a wider batch creates result-merging noise and context contention, a narrower one wastes parallelism. Slice the scope into chunks of five, launch a batch, collect each worker's result, then launch the next; with no subagent mechanism, process sequentially instead.

**Keep the batch alive and isolated.** A wait that returns nothing means no update has arrived yet, not that a worker failed — treat a still-running worker as alive. One file's failure must not block the other four: collect the successful results, retry the failed file once on its own, and escalate it under "Remaining Risks" only if the retry also fails.

Per file, whichever mode:

- Behavior MUST be preserved. When equivalence is not obvious, SKIP.
- Do NOT change public API signatures or remove type hints.
- Do NOT introduce new abstractions or dependencies.
- Keep the diff minimal and scoped to slop removal.
- Report changes grouped by category with before/after, why-slop, and why-safe; for each skipped issue, give the reason.

### Phase 5 — Verify

Run the quality gates above, then walk the critical-review checklist in [`references/report-format.md`](references/report-format.md).

### Phase 6 — Fix failures

If any gate fails or any checklist item flips:

1. Identify the change that caused it and explain why it broke.
2. Revert just the problematic hunk (`git checkout` the file, or a targeted edit).
3. If genuine slop remains after revert, re-apply only the changes you can prove safe.
4. Re-run the failing gate and re-walk the checklist for that file.

If you fail three times on the same file, STOP and escalate: the file, what you tried, what failed, your hypothesis. Do not keep editing.

## Anti-Patterns

- **Skipping Phase 2.** Removing code on uncovered ground is a behavior-change time bomb. The regression test IS the safety mechanism.
- **Bundling unrelated refactors.** Dead-code deletion + abstraction removal + a performance change in one commit is impossible to review or bisect. Stay scoped to slop.
- **Algorithm changes disguised as performance fixes.** If equivalence needs a proof, it is a refactor, not a slop fix — separate change.
- **Silent skips.** Say `N/A` and why; never claim PASS without evidence.
- **Removing comments that explain WHY.** Only remove comments that restate WHAT.
- **Touching files outside scope.** Report out-of-scope slop under "Remaining Risks"; do not edit it.
