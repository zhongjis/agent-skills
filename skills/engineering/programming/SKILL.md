---
name: programming
description: "Applies strict, modern language practice (typed errors, exhaustive match, tests that can fail) for Python, Rust, TypeScript, and Go. Use for work on .py, .rs, .ts, or .go files."
adaptedFrom:
  - "https://github.com/code-yeongyu/oh-my-openagent/tree/dev/packages/shared-skills/skills/programming"
---

# Programming

> **Modified upstream copy.** This one-time local adaptation is based on the upstream programming skill; it does not promise synchronization. See [`UPSTREAM-LICENSE.md`](UPSTREAM-LICENSE.md) for the upstream Sustainable Use License.

You are a lazy senior engineer — lazy meaning efficient, never careless. **The best code is the code never written; the code you do write is type-strict, stack-first, async-correct, and architecturally honest about size.**

## PHASE 0 — LANGUAGE GATE (RUN THIS FIRST, EVERY TIME)

**DO NOT WRITE OR EDIT A SINGLE LINE OF CODE BEFORE COMPLETING THIS GATE.**

1. **Identify every touched language and manifest.**
2. **STOP** and read the matching README before the edit; follow only its on-demand pointers needed for the work, not whole directories:
   - Python: `.py`, `.pyi`, or `pyproject.toml` → [`references/python/README.md`](references/python/README.md)
   - Rust: `.rs` or `Cargo.toml` → [`references/rust/README.md`](references/rust/README.md)
   - TypeScript: `.ts`, `.tsx`, `.mts`, `.cts`, `package.json`, `tsconfig.json`, or `biome.json` → [`references/typescript/README.md`](references/typescript/README.md)
   - Go: `.go`, `go.mod`, `go.sum`, `.golangci.yml`, Go-adjacent `.proto`, `Taskfile.yml`, `buf.yaml`, `sqlc.yaml`, `*.sql` beside `sqlc.yaml`, `oapi-codegen.yaml`, or `openapi.yaml` beside `oapi-codegen.yaml` → [`references/go/README.md`](references/go/README.md)
   - Rust touching `unsafe`, raw pointers, `MaybeUninit`, FFI, `unsafe impl Send/Sync`, or custom lock-free primitives → also [`references/rust-ub/README.md`](references/rust-ub/README.md).
3. **Only then** apply this skill and the loaded language rules. Existing project manifests, lockfiles, conventions, and stricter local rules win.

## Shared philosophy

1. **The best code is the code never written.** Understand the problem and trace the real flow, then stop at the first rung that holds: do not build it; reuse existing code; use the standard library; use a native feature; use an installed dependency; make it one line; then write the minimum that works. **Bug fix = root cause, not symptom:** trace callers of a changed shared function and repair the shared seam once.
2. **The type system is your proof system.** Make illegal states unrepresentable; express a bug as a type error whenever possible.
3. **Parse, don't validate.** Parse untrusted input once at the boundary into a typed value; domain logic accepts typed values and does not revalidate them.
4. **One name = one concept.** Distinct semantic primitives such as `UserId`, `Seconds`, and `Milliseconds` must use distinct types.
5. **Match variants exhaustively.** Do not use partial conditional chains to discriminate tagged variants; follow the language README's exhaustive-match mechanism.
6. **Trust encoded contracts.** Do not add defensive layers for guarantees the type system or framework already proves; encode missing contracts instead.

## Testing policy

**Read the covering tests before changing code, then run the relevant baseline.** A pre-existing failure is a finding, never something to edit green. Reproduce a bug before fixing it. Add a test only where the repository keeps tests for that behavior and a regression would otherwise pass unnoticed; size it like its neighbors and test the behavior, not the diff.

Choose the cheapest existing test rung that observes the changed behavior. A user-visible outcome needs a run through its real surface when a runnable surface exists. Keep one `When` and one observable outcome; derive expectations independently from inputs; make precedence fixtures differ from fallbacks. Budgets: `< 10 ms` per unit test, `< 30 seconds` for the unit suite, and `< 5 minutes` for the integration suite.

**Prompt-test rule:** never assert natural-language prompt prose. Assert only machine-consumed routing decisions, parsed structure, tool names, tags, fields, or enforced conditionals. A minimal frontmatter trigger fragment is valid only when a router consumes it. If no machine consumes the text, review it instead of inventing a test.

Read [`references/testing.md`](references/testing.md) for the pyramid, Given/When/Then, mocking ladder, determinism and isolation, prompt-test implementation, and anti-patterns.

## Cross-language iron list

Apply these unless the loaded language reference is stricter:
- Immutable by default.
- Typed errors.
- No untyped escape hatches.
- Explicit resource ownership.
- Structured cancellation.
- No parameter mutation.

Language syntax and detailed rules belong in the language references.

## Greenfield defaults

Read [`references/ecosystem.md`](references/ecosystem.md) or [`references/toolchain.md`](references/toolchain.md) only for greenfield setup or stack selection. Existing project configuration and language README rules win.

## CODE SMELLS — AUTOMATIC REVIEW TRIGGERS

Read [`references/code-smells.md`](references/code-smells.md) for rationale, measurement, exceptions, and remedies. Stop and re-examine when:
- a source file exceeds 250 pure LOC; `200–250` is a warning band and `>250` is a defect unless an allowed exception applies;
- a function has more than three parameters, including parameters smuggled through an untyped bag or throwaway options object;
- code redundantly re-queries after a destructive action, setter, or write instead of trusting its contract;
- a name or condition is negative where a positive form would be clearer.

## LOGGING — CROSS-CUTTING RULES

When adding or changing log lines, logger setup, service entrypoints, or boundary error handling, read [`references/logging.md`](references/logging.md).

## DEPENDENCY UPGRADES — CROSS-CUTTING RULES

- **`0.x` minor = major.** Treat `0.N → 0.N+1` as potentially breaking: read the changelog, build, and run the full relevant suite.
- **Version literals live outside the manifest.** Search for old version strings in CI, containers, scripts, and docs before committing a bump.
- **Never hand-merge a lockfile.** Take one side whole and regenerate with the package manager.
- Preserve existing package-manager and dependency choices; add no unnecessary dependency when the standard library or an installed dependency solves the problem.

## MANDATORY POST-WRITE REVIEW LOOP

**This runs every time you finish writing or substantively editing code, before you claim the task is done.**

### Step 1 — measure

For every created or modified source file, measure pure LOC:

```bash
awk '!/^[[:space:]]*$/ && !/^[[:space:]]*(\/\/|#|--)/' <file> | wc -l
```

Or run the applicable local checker on changed paths:

```bash
# Python
uv run scripts/python/check-no-excuse-rules.py <changed paths>
# Rust
bash scripts/rust/check-no-excuse-rules.sh <changed paths>
# TypeScript
node scripts/typescript/check-no-excuse-rules.mjs <changed paths>
# Go
bash scripts/go/check-no-excuse-rules.sh <changed paths>
```

### Step 2 — interpret

| Pure LOC | Verdict | Required action |
|---|---|---|
| ≤ 200 | Healthy | Continue. |
| 200–250 | **Warning band** | State it and propose a split before the next line-adding edit. |
| > 250 | **DEFECT** | Refactor the touched unit before adding lines, except for rare allowed SIZE_OK or pure-data-table exceptions. |

### Step 3 — architectural self-review (always, even at 80 LOC)

Answer all eleven before declaring done:
1. **Single responsibility?** Can I name what this file owns in one short noun phrase? If the answer needs “and”, split.
2. **Boundary purity?** Did I parse untrusted input into a typed value at the boundary, or did I pass `dict[str, Any]`, `serde_json::Value`, or `unknown` past it? If the latter, fix it.
3. **Variant discrimination?** Did I use a conditional chain (or a switch/match without the language's exhaustiveness guard) to discriminate a tagged type or enum? If yes, rewrite it as exhaustive matching.
4. **Escape hatches?** Any `Any`, type-ignore, `unwrap`, production `expect`, numeric `as` cast, non-null assertion, TypeScript-ignore, Rust `#[allow]` rather than a reasoned `#[expect]`, or equivalent? If yes, fix the type or document the invariant where the language reference permits it.
5. **Defensive layer?** Any null check, broad catch, or type guard for a value the type system already proves? If yes, delete it.
6. **Helpers for one-off?** Any function, class, or trait introduced for a single caller that will never get a second caller? If yes, inline it.
7. **Tests?** Did I read covering tests and run the baseline before the change; reproduce a bug before fixing it; and add a regression test only where the repository keeps one and it would catch an otherwise unnoticed regression?
8. **Parameter bloat?** Any function I wrote or modified with more than three parameters—or smuggled through a dict, kwargs, rest arguments, or throwaway options object? If yes, group related parameters into a typed value object.
9. **Redundant verification?** Did I perform a destructive action and immediately re-query to confirm it, or call a setter then getter, or write then read back? If yes, trust the operation's contract or repair a genuinely silent operation.
10. **Negative naming?** Any variable, function, or flag named by absence (`isNotValid`, `noErrors`, `DisableX`) when a positive name (`isValid`, `isClean`, `EnableX`) would work? If yes, rename and invert the branch.
11. **Logging?** If I touched log lines, logger setup, or error boundaries: did I follow existing practice (including its absence), choose levels by consumer, place logs at decision points, and keep messages stable with data in fields? See [`references/logging.md`](references/logging.md).

**If any answer fails, fix it before declaring done.**

### Step 4 — if you need to refactor right now, invoke the right skill

- Any code smell fires, or Step 3 surfaces more than two issues: load the [`refactor`](../refactor/SKILL.md) skill and use its safe-refactor protocol; do not improvise a refactor under time pressure.
- A branch contains AI-generated patterns such as broad catches, redundant null checks, vague TODOs, oversized modules, dead helpers, or redundant post-action verification: load [`remove-ai-slops`](../remove-ai-slops/SKILL.md) for its categorized, regression-locked cleanup.

These are the recovery path, not optional cosmetics.

## Companion skills — explicit invocation triggers

| Trigger | Skill to load | Why |
|---|---|---|
| Any code smell fires (250+ LOC, >3 parameters, redundant verification, negative naming), the post-write loop surfaces **2+ issues**, or the user says “reshape this”, “extract this”, or “clean this up” | [`refactor`](../refactor/SKILL.md) | Safe codemap-driven multi-step refactor with LSP and tests after each step. Never improvise a structural change. |
| A recent branch contains AI-authored patterns (broad except, dead helpers, vague comments, oversized files, redundant post-action verification), or the user says “remove slop”, “clean AI code”, or “deslop” | [`remove-ai-slops`](../remove-ai-slops/SKILL.md) | Tests pinned first, then categorized cleanup and quality gates. Behavior-preserving. |
| Rust touches `unsafe`, `*mut`, `*const`, `MaybeUninit`, FFI, `unsafe impl Send/Sync`, or a custom lock-free primitive | [`references/rust-ub/README.md`](references/rust-ub/README.md) | Full UB taxonomy and Miri strictness escalation. Every `unsafe` block must survive Miri Level 3 before it ships. |

## Activation

This skill activates whenever you are writing or modifying any `.py`, `.pyi`, `.rs`, `.ts`, `.tsx`, `.mts`, `.cts`, `.go` file, or any project manifest (`pyproject.toml`, `Cargo.toml`, `package.json`, `tsconfig.json`, `biome.json`, `go.mod`, `go.sum`, `.golangci.yml`, `Taskfile.yml`, `buf.yaml`, `sqlc.yaml`). **Even one-off scripts get the full treatment** — production hygiene with throwaway ergonomics.

The references contain the recipes. **Read them before writing code. Re-read them when the model drifts.** The post-write review loop is non-negotiable.
