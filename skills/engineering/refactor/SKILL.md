---
name: refactor
description: "Intelligent, verification-driven refactoring: understand intent, map the codebase, assess test coverage, plan atomic steps, then execute with a test + diagnostics + typecheck gate after every change. Triggers: refactor, refactoring, cleanup, restructure, extract, simplify, modernize, rename, move, deduplicate, reduce complexity."
adaptedFrom:
  - "https://github.com/code-yeongyu/oh-my-openagent/tree/dev/packages/shared-skills/skills/refactor"
  - "https://github.com/github/awesome-copilot (refactor-method-complexity-reduce prompt)"
---

# Refactor

Deterministic, verification-driven refactoring with full codebase awareness. Unlike blind search-and-replace, this workflow understands intent, maps the code before touching it, assesses test coverage, plans atomic steps, and **verifies after every change** so structure changes while behavior does not.

The core invariant: **behavior is proven unchanged by tests + diagnostics + typecheck after each step.** Refactoring without tests is reckless; refactoring without understanding is destructive. This workflow refuses both.

## Inputs

- **Target** (required): what to refactor — a file path, a symbol name, a pattern ("all functions using the deprecated API"), or a description ("extract validation into its own module").
- **Scope** (default: module): `file` | `module` | `project`.
- **Strategy** (default: safe): `safe` (conservative, maximum coverage required) | `aggressive` (broader changes, still gated on adequate coverage).

## References

- [`references/codemap.md`](references/codemap.md) — the dependency-graph / impact-zone / coverage template built in Phase 2.
- [`references/verification-strategy.md`](references/verification-strategy.md) — test-assessment matrix and the diagnostics/test/typecheck gate used in Phases 3, 5, and 6.
- [`references/method-complexity-reduction.md`](references/method-complexity-reduction.md) — a focused technique for cutting a single method's cognitive complexity by extracting helpers (used during Phase 5).

Ownership: [`../programming/references/code-smells.md`](../programming/references/code-smells.md) owns smell definitions and thresholds (file size, parameter count, negative naming). This skill owns the execution workflow — reference a smell as a trigger, never restate its thresholds.

## Phase 0 — Intent gate

Classify and validate the request before any action.

| Signal | Classification | Action |
|---|---|---|
| Specific file/symbol | Explicit | Proceed to Phase 1 |
| "Refactor X to Y" | Clear transformation | Proceed to Phase 1 |
| "Improve", "clean up" | Open-ended | **Ask**: what specific improvement? |
| Ambiguous scope | Uncertain | **Ask**: which modules/files? |
| Missing context | Incomplete | **Ask**: what is the desired outcome? |

Confirm the target is identified, the outcome is understood, the scope is defined, and success criteria can be stated. If any is unclear, ask one clarifying question — state what you understood, the specific ambiguity, the options with implications, and your recommendation — before proceeding.

Then create a task list with one entry per phase below and keep exactly one in progress.

## Phase 1 — Codebase analysis

Understand the target and its blast radius before changing anything.

If your harness supports parallel subagents, launch background exploration in parallel — otherwise run these as direct searches sequentially. Cover:

1. **The target** — every definition and occurrence (file paths, line numbers, usage patterns).
2. **Dependents** — everything that imports, uses, or depends on the target (dependency and import chains).
3. **Similar patterns** — analogous implementations and established conventions to match.
4. **Tests** — test files, case names, and coverage indicators for the target.
5. **Architecture context** — module boundaries, layering, and design patterns around the target.

Alongside (or instead of) subagents, use direct tools:

- **Your editor's LSP** — go-to-definition (where it is defined), find-references across the workspace (every usage), document/workspace symbols (structure), and diagnostics (baseline errors before you start).
- **The [`ast-grep`](../ast-grep/SKILL.md) skill or the `sg` CLI** — structural pattern search; always preview a rewrite before applying it.
- **Text search** (`rg`) for string patterns the structural tools miss.

Collect every result before building the codemap.

## Phase 2 — Build the codemap

From Phase 1, construct the codemap using the template in [`references/codemap.md`](references/codemap.md): core files (direct impact), the dependency graph, impact zones with risk level and test coverage, and the established patterns to follow. Then name the constraints:

- **MUST follow** — existing patterns identified.
- **MUST NOT break** — critical dependencies and public contracts.
- **Safe to change** — isolated zones.
- **Requires migration** — breaking changes and their consumers.

## Phase 3 — Test assessment

Determine how you will prove behavior is preserved. Detect the test infrastructure, analyze coverage for the target, and pick a verification strategy from the coverage matrix in [`references/verification-strategy.md`](references/verification-strategy.md). If coverage is LOW or NONE, **pause** and propose adding characterization tests first — a refactor with no safety net is a behavior change waiting to happen. Document the exact test, typecheck, and lint commands plus the regression indicators that must stay green.

## Phase 4 — Plan

Produce a detailed plan before editing (delegate to a planning subagent if your harness has one). The plan must:

1. Break the work into atomic steps, each independently verifiable.
2. Order steps by dependency (what must happen first).
3. Name the exact files and line ranges per step.
4. Give a rollback for each step.
5. Define commit checkpoints.

Validate the plan (completeness, per-step reversibility, dependency order, verification commands), then expand it into granular todos — one for each step and one for each verification.

## Phase 5 — Execute

For each step, in order:

**Before** — mark the step in progress, read the current file state, confirm diagnostics are at baseline.

**Execute** — use the narrowest correct tool:
- Symbol renames → your editor's LSP prepare-rename → rename.
- Pattern transformations → the [`ast-grep`](../ast-grep/SKILL.md) skill / `sg` CLI: preview the rewrite, review it, then apply.
- Structural edits → precise line edits.
- Cutting a method's cognitive complexity → the technique in [`references/method-complexity-reduction.md`](references/method-complexity-reduction.md).

**After (mandatory)** — run the gate: diagnostics clean (or same as baseline), the relevant tests green, typecheck clean. Only then mark the step complete.

**On any failure** — STOP. Revert the failed change, diagnose the cause, then fix and retry, skip an optional step, or ask the user. Never proceed to the next step on a broken build or failing test. Commit at logical checkpoints with a scoped message.

## Phase 6 — Final verification

Run the full regression check: the complete test suite, a full typecheck, the linter, the build (if any), and diagnostics on every changed file — all clean. Then summarize what changed, the files modified, the verification results, and confirm no regressions.

## Critical rules

**Never** — skip the post-change diagnostics/test gate; proceed with failing tests; make changes without understanding impact; use `as any` / `@ts-ignore` / `@ts-expect-error` to hide breakage; delete a test to make it pass; commit broken code; refactor against patterns you did not first read.

**Always** — understand before changing; preview a structural rewrite before applying it; verify after every change; follow existing conventions; keep the task list current; commit at logical checkpoints; report problems immediately.

**Abort and consult the user** when: target coverage is zero and the strategy is aggressive; a change would break a public API; scope is unclear; three consecutive verification failures occur; or a user-defined constraint would be violated.

## Deprecated code and library migration

When you hit a deprecated method or API mid-refactor, look up the recommended modern replacement in the library's official docs before changing it. Do **not** auto-upgrade to a newer major version unless the user explicitly asks for a migration; if they do, read the target version's API docs first.
