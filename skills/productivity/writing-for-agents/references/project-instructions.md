# Project instructions

The project `AGENTS.md` / `CLAUDE.md` branch of [`writing-for-agents`](../SKILL.md): repo/project-scoped instructions for how agents work in one repository. Everything else about writing it is the universal reference in `SKILL.md`.

## Current state

The file describes the repository as it is now. Code is the source of truth for detail; the file holds the high-level contracts code cannot state: boundaries, ownership, conventions, and the reasons behind them.

- When a contract changes, rewrite its line in the same change; when it goes away, delete the line. The file never records how it got here: no dates, no "previously / now / no longer", no change log.
- Keep a reason when it explains the current rule ("use pnpm; the lockfile is pnpm-only"); drop the story of how the rule arrived.
- When deprecated code still exists, name the current path ("use `newClient()` for API calls") and leave the deprecated one unnamed: naming it pulls it into context (see negation in `SKILL.md`).
- High level is not vague. A command or convention the agent cannot guess stays concrete enough to check; what drops out is the walkthrough of code the agent can read.

## Tooling

Linters, formatters, type checkers, CI, and hooks enforce deterministic rules. The file holds only what tooling cannot enforce; a restated tool rule is a cache that drifts from the tool's config.

## Nested files

Put each rule in the nearest file whose scope covers all the code it governs: repo-wide rules at the root, area rules beside the area. A child file adds to its parent and never repeats it.
