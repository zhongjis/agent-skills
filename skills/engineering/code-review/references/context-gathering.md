# Context Gathering

Guidance for the **Gather context** step, scaled to the Risk dial's **Context depth** column. Caller search itself is defined in the Regression checklist (`axis-checklists.md`); this file adds dependency contracts and the history and churn digging that deeper reviews need.

## Full file read — every review

Read each changed file in full, not just the hunks. Surrounding invariants, sibling functions, and class structure decide whether a hunk is correct.

## Callers + dependency contracts — Standard reviews and up

- Callers of a changed symbol: `rg "<symbol>\b" --type <lang>` across the repo (see the Regression checklist).
- Dependents of a changed module: `rg "import.*<module>|require.*<module>"`.
- Key dependencies: when correctness depends on an imported or called dependency's contract, read its relevant implementation or authoritative documentation to establish return values, errors, side effects, and ownership obligations. Follow only contracts the changed behavior relies on, rather than exhaustively reading imports.

## History + churn — full data-flow tracing depth, Risky changes

- When and why a symbol last changed: `git log --oneline --all -S "<symbol>" -- <file>`.
- Change velocity / churn (high churn earns higher scrutiny): `git log --oneline -10 -- <file>`.
- Who owns the area, for context not blame: `git shortlog -sn --no-merges -- <file>`.

Read each file along a data-flow path, not only the changed ones — missing validation, auth gaps, and injection points often live just outside the diff.
