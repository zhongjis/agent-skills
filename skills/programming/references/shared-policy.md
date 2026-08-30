# Shared Programming Policy

Apply this policy to Python, Rust, TypeScript, and Go. Language references may strengthen it. Existing project choices win where this policy offers defaults; they do not excuse weaker correctness.

## Shared philosophy (all three languages)

These are not style preferences. They are the seven axioms every recipe in `references/` derives from.

0. **The best code is the code never written.** Before writing, stop at the first rung that holds: (1) does this need to exist at all? (YAGNI) (2) does this codebase already have it? — reuse the helper or pattern, do not re-implement. (3) does the standard library do it? (4) does a native platform feature cover it? (5) does an installed dependency solve it? (6) can it be one line? (7) only then, write the minimum that works. Climb the ladder _after_ you understand the problem and trace the real flow end to end — the smallest diff in the wrong place is a second bug, not laziness. The ladder is a fast decision, not a written essay: pick the rung and move. **Bug fix = root cause, not symptom.** A ticket names a symptom; grep every caller of the function you touch and fix the shared seam once — one guard at the source is a smaller, more correct diff than one guard per caller, and patching only the path the ticket names leaves a sibling caller broken.

1. **The type system is your proof system.** Make illegal states unrepresentable. The compiler / type checker is the cheapest test you will ever run. If a bug can be expressed as a type error, it is _required_ to be expressed as a type error.

2. **Parse, don't validate.** Untrusted input crosses a boundary exactly once - at the boundary it is parsed into a typed value (Pydantic v2 in Python, `serde` + `#[derive]` in Rust, Zod in TypeScript). Inside the boundary, code receives typed values and never re-validates. The boundary owns trust; the interior owns logic.

3. **One name = one concept.** A `UserId` is not a `string`. A `Seconds` is not a `Milliseconds`. Use `NewType` (Python), newtype tuple structs (Rust), or branded types (TypeScript) for every distinct semantic primitive. The compiler refuses to let two semantic units mix.

4. **Exhaustive variant matching, always.** Discriminated unions and enums are matched exhaustively. Python: `match` + `case unreachable: assert_never(unreachable)`. Rust: `match` (the compiler enforces). TypeScript: `switch` + `assertNever`. **`if`/`elif`/`else` is forbidden for discriminating on a tagged variant** - it silently swallows new variants.

5. **Trust framework guarantees. Validate only at boundaries.** No null checks for values the type system already proves non-null. No `try/except` around code that cannot raise. No `unwrap`/`!`/`as` to paper over a contract you should have encoded in types. No defensive layer for a scenario you cannot name.

6. **Test-driven, with the right shape of test.** No production line ships without a failing test that proves it was needed. Behavior is locked by tests, not by hope. See the TDD discipline below.

## TDD

Every behavior change follows **red → green → refactor**:

1. **Red:** write the smallest test with a language-idiomatic Given / When / Then name, such as `Test_<Behavior>_when_<Condition>`, `it("<does X> when <Y>")`, or `behavior_when_condition`. Run it and confirm failure for the intended reason.
2. **Green:** write only enough production code to pass that test.
3. **Refactor:** improve structure with tests green, then rerun the focused checks.

A production behavior change does not ship without a test that would fail if the change were reverted. Use one `When` and one observable outcome per test. Derive expectations independently from test inputs, and make precedence fixtures differ from their fallbacks.

For the suite's shape (the test pyramid), the mocking ladder, the test anti-patterns, and prompt-test detail, see [`testing.md`](testing.md). Policy: prefer real objects over fakes over mocks; assert contracts, not implementation details; keep tests deterministic and isolated across concurrent processes.

Budgets: `< 10 ms` per unit test, `< 30 seconds` for the unit suite, and `< 5 minutes` for the integration suite.

**FORBIDDEN — NO EXCEPTIONS: a test MUST NOT assert natural-language prompt text.** `expect(prompt).toContain("based on GPT-5.6")`, `not.toContain("old wording")`, `toMatchSnapshot()` on prose, grepping a sentence fragment — every one of these is pretend-coverage. It stays green while the behavior it claims to guard breaks, then blocks every legitimate rewording until someone bumps the pinned string. A reviewer MUST block it as HIGH; deleting such a test is a fix, not a coverage loss. "A nearby test already does it" is not a defense — that test is the disease, not the convention.

Assert only machine-consumed routing decisions, parsed structure, tool names, tags, fields, or enforced conditionals. A minimal frontmatter trigger fragment is valid only when a router consumes it. If no machine consumes the text, review it instead of inventing a test. See [`testing.md`](testing.md) for examples, severity, and the test-writing delegation rule.

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
node scripts/typescript/check-no-excuse-rules.mjs <changed paths>
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
