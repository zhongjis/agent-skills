# Method Complexity Reduction

A focused technique used during Phase 5 of the [refactor workflow](../SKILL.md): cut a single method's cognitive complexity to your project's threshold (e.g. cyclomatic complexity ≤ 10, or whatever the project's linter enforces) by extracting logic into focused helpers — without changing behavior.

## Analyze the sources of complexity

Identify what makes the target method hard to follow:

- Nested conditionals and deep indentation.
- Long `if`/`else` or `switch` chains.
- Repeated code blocks.
- Multiple loops carrying their own conditions.
- Complex boolean expressions.

## Find extraction opportunities

- Validation logic that can move into a dedicated `validate*` helper.
- Type-specific or case-specific processing that repeats.
- Complex transformations or calculations.
- Patterns that appear more than once.

## Extract focused helpers

- Each helper has one clear responsibility and a name that states it.
- Extract validation into separate methods; extract case-specific logic into handlers.
- Give helpers the narrowest appropriate binding (static/free function when they need no instance state; private when only used locally).
- Keep helpers close to where they are used.

## Simplify the main method

- Reduce nesting with guard clauses and early returns.
- Replace a large `if`/`else` chain with a small orchestration of named calls, or an exhaustive `switch`/`match` for variant dispatch.
- Leave the main method reading as a high-level flow: what happens, in order, delegated to well-named helpers.

## Preserve behavior

- Keep the same input/output contract.
- Preserve all validation and error handling, exception types, and error messages.
- Pass every parameter through correctly; do not drop or reorder side effects.

## Verify

Extract helpers first, then reshape the main flow, testing incrementally. Apply the workflow's standard gate ([`verification-strategy.md`](verification-strategy.md)): run the tests for the method and its surrounding functionality and **read the result to confirm zero failures** — running tests is not the same as verifying they passed. If any fail, find the root cause (common culprits: null handling, empty-collection checks, inverted conditions), fix the extracted code to restore the original behavior, and re-run until green. Confirm the type checker is clean and the complexity metric is at or below the target threshold.

## Done when

- The type checker and build are clean.
- The test result explicitly shows zero failures.
- Cognitive complexity is at or below the target threshold.
- All original functionality is preserved.
- The code follows project conventions.
