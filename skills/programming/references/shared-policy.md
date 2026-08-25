# Shared Programming Policy

Apply this policy to Python, Rust, TypeScript, and Go. Language references may strengthen it. Existing project choices win where this policy offers defaults; they do not excuse weaker correctness.

## Core rules

1. **Write the least code that solves the real problem.** Understand the end-to-end flow, fix root causes at the shared seam, reuse existing code, then prefer the standard library, platform features, and installed dependencies before adding code or packages. Do not create a one-use abstraction.
2. **Use the type system as proof.** Make illegal states unrepresentable. No untyped escape hatch may replace a contract the type system can express.
3. **Parse, do not repeatedly validate.** Parse untrusted input once at its boundary into a typed value. Interior logic accepts typed values and trusts their guarantees.
4. **Give each concept its own type.** Distinct IDs, units, and semantic primitives must not be interchangeable.
5. **Match variants exhaustively.** Tagged unions and enums require the language's exhaustive-match pattern; a fallback that silently accepts future variants is forbidden.
6. **Trust proven contracts.** Validate only at boundaries. Remove defensive null checks, catches, assertions, and post-action checks for states already excluded by types or operation contracts.
7. **Keep resources and concurrency structured.** Use language-native deterministic cleanup, cancellation, and task ownership. No detached work or leaked resources.

## TDD

Every behavior change follows **red → green → refactor**:

1. **Red:** write the smallest test with a language-idiomatic Given / When / Then name, such as `Test_<Behavior>_when_<Condition>`, `it("<does X> when <Y>")`, or `behavior_when_condition`. Run it and confirm failure for the intended reason.
2. **Green:** write only enough production code to pass that test.
3. **Refactor:** improve structure with tests green, then rerun the focused checks.

A production behavior change does not ship without a test that would fail if the change were reverted. Use one `When` and one observable outcome per test. Derive expectations independently from test inputs, and make precedence fixtures differ from their fallbacks.

For the suite's shape (the test pyramid), the mocking ladder, the test anti-patterns, and prompt-test detail, see [`testing.md`](testing.md). Policy: prefer real objects over fakes over mocks; assert contracts, not implementation details; keep tests deterministic and isolated across concurrent processes.

Budgets: `< 10 ms` per unit test, `< 30 seconds` for the unit suite, and `< 5 minutes` for the integration suite.

Never assert natural-language prompt prose, sentence fragments, or prose snapshots. Assert only machine-consumed routing decisions, parsed structure, tool names, tags, fields, or enforced conditionals. A minimal frontmatter trigger fragment is valid only when a router consumes it. If no machine consumes the text, review it instead of inventing a test. See [`testing.md`](testing.md) for examples, severity, and the test-writing delegation rule.

**Exemption:** documentation-only, comment-only, formatting-only, metadata-only, and other demonstrably non-behavioral changes do not require a red test. Run applicable validation, link checks, formatting, or static checks instead. If runtime behavior, generated output, routing, parsing, packaging, or a machine-consumed contract can change, the exemption does not apply.

Never delete or weaken a failing test to make CI pass. Fix the implementation or correct a test whose premise is wrong.

## Post-write review

After every substantive code edit, complete this review and answer each applicable item with concrete evidence in the final reply:

1. Run the language checker on all changed paths:

```bash
# Python
uv run scripts/python/check-no-excuse-rules.py <changed paths>
# Rust
bash scripts/rust/check-no-excuse-rules.sh <changed paths>
# TypeScript
bun run scripts/typescript/check-no-excuse-rules.ts <changed paths>
# Go
bash scripts/go/check-no-excuse-rules.sh <changed paths>
```

Paths are relative to this skill directory. Also run the project's focused tests, type checker, linter, and formatter required by the language README and local project.

2. Apply [`code-smells.md`](code-smells.md) to every changed source file. Its pure-LOC ceiling, warning band, exceptions, and remedies are mandatory.
3. Confirm one short noun phrase names each changed file's responsibility.
4. Confirm boundary inputs become typed values before entering domain logic.
5. Confirm tagged variants are matched exhaustively.
6. Remove type escape hatches, warning suppressions, unjustified broad catches, redundant defensive layers, and single-use abstractions introduced by the change.
7. Confirm no function the change adds or edits exceeds 3 parameters or smuggles them through a dict/kwargs/options bag (see [`code-smells.md`](code-smells.md) Smell 2).
8. Confirm no destructive action is followed by a redundant verifying re-query, setter-then-getter, or write-then-read-back (see [`code-smells.md`](code-smells.md) Smell 3).
9. Confirm names state the presence of a quality, not its absence (`isValid`, not `isNotInvalid`); see [`code-smells.md`](code-smells.md) Smell 4.
10. Confirm changed behavior has a test that fails when reverted, unless the non-behavior exemption applies.
11. If logging was touched, apply [`logging.md`](logging.md).

Any failed item blocks completion until fixed or covered by an explicit exception allowed by the owning reference.

## Dependency upgrades

- Treat a `0.x` minor upgrade as potentially breaking. Read its changelog and migration notes, then build and run the full relevant suite.
- Search the repository for every old version literal, including CI, containers, scripts, and docs; update all intentional pins together.
- Never hand-merge a lockfile. Resolve conflicts by taking one complete side and regenerating with the project's package manager.
- Preserve the existing package manager and dependency choices unless the task explicitly requests migration. Add no dependency when the standard library or an installed dependency already solves the problem.
