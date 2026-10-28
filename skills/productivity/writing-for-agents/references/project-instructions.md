# Project instructions

The project `AGENTS.md` / `CLAUDE.md` branch of [`writing-for-agents`](../SKILL.md): repo/project-scoped instructions for how agents work in one repository. Everything else about writing it is the universal reference in `SKILL.md`.

## Current state

The file defines current contracts and general work guidance: purpose, ownership, boundaries, invariants, conventions, and their reasons.

Code is the source of truth for implementation. Detailed implementation descriptions are prohibited in project `AGENTS.md` / `CLAUDE.md`: algorithms, internal call flows, per-file walkthroughs, and inventories of functions or modules. Link to the owning code instead of restating it.

A contract states what must remain true; implementation describes how code currently achieves it. Keep the former, leave the latter in code.

- When a contract changes, rewrite its line in the same change; when it goes away, delete the line. The file never records how it got here: no dates, no "previously / now / no longer", no change log.
- Keep a reason when it explains the current rule ("use pnpm; the lockfile is pnpm-only"); drop the story of how the rule arrived.
- State the supported contract and link to its owner. Retain compatibility and safety requirements while they remain applicable.
- High level is not vague. A command or convention the agent cannot guess stays concrete enough to check; what drops out is the walkthrough of code the agent can read.

## Shared readers

The file is committed: every contributor's agent reads it, each with its own global instructions and harness, or none. State every repo contract here even when a personal global file repeats it, name tools and roles in harness-neutral terms, and leave personal preferences in global instructions.

## Tooling

Linters, formatters, type checkers, CI, and hooks enforce deterministic rules. The file holds only what tooling cannot enforce; a restated tool rule is a cache that drifts from the tool's config.

## Progressive disclosure

- Keep contracts shared across the file's scope directly available.
- Place area-specific contracts in the nearest applicable child instruction file.
- Put optional reference behind a pointer that names its subject and when to read it.
- Keep mandatory prerequisites explicit. A shared rule must not become reachable only through one task branch.
- Do not create reference files merely to relocate implementation descriptions; point to code.
- Split by distinct scope or reading need, not file length alone.

## Nested files

Put each rule in the nearest file whose scope covers all the code it governs: repo-wide rules at the root, area rules beside the area. A child file adds to its parent and never repeats it.
