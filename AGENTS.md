# DOX framework

- DOX is highly performant AGENTS.md hierarchy installed here
- Agent must follow DOX instructions across any edits

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it

## Read Before Editing

1. Read the root AGENTS.md
2. Identify every file or folder you expect to touch
3. Walk from the repository root to each target path
4. Read every AGENTS.md found along each route
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:

- purpose, scope, ownership, or responsibilities
- durable structure, contracts, workflows, or operating rules
- required inputs, outputs, permissions, constraints, side effects, or artifacts
- user preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

Update parent docs when parent-level structure, ownership, workflow, or child index changes. Update child docs when parent changes alter local rules. Remove stale or contradictory text immediately. Small edits that do not change behavior or contracts may leave docs unchanged, but the DOX pass still must happen.

## Hierarchy

- Root AGENTS.md is the DOX rail: project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index
- Child AGENTS.md files own domain-specific instructions and their own Child DOX Index
- Each parent explains what its direct children cover and what stays owned by the parent
- The closer a doc is to the work, the more specific and practical it must be

## Child Doc Shape

- Create a child AGENTS.md when a folder becomes a durable boundary with its own purpose, rules, responsibilities, workflow, materials, or quality standards
- Work Guidance must reflect the current standards of the project or user instructions; if there are no specific standards or instructions yet, leave it empty
- Verification must reflect an existing check; if no verification framework exists yet, leave it empty and update it when one exists

Default section order:
- Purpose
- Ownership
- Local Contracts
- Work Guidance
- Verification
- Child DOX Index

## Style

- Keep docs concise, current, and operational
- Document stable contracts, not diary entries
- Put broad rules in parent docs and concrete details in child docs
- Prefer direct bullets with explicit names
- Do not duplicate rules across many files unless each scope needs a local version
- Delete stale notes instead of explaining history
- Trim obvious statements, repeated rules, misplaced detail, and warnings for risks that no longer exist

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and any affected parents or children
3. Refresh every affected Child DOX Index
4. Remove stale or contradictory text
5. Run existing verification when relevant
6. Report any docs intentionally left unchanged and why

## User Preferences

When the user requests a durable behavior change, record it here or in the relevant child AGENTS.md

## Skill catalog

- **Layout**: authored/adapted skills live in root `skills/`; vendored common skills live in `.agents/skills/`; physical harness skills live in `<agent-folder>/skills/`; absent harness folders yield empty groups
- **Profile axis**: `profiles.nix` at repo root lists skills by profile (`personal`, `work`); unlisted skills are `general`
- **Authored vs vendored**: root `skills/` leaves without lock entries are authored/adapted; `.agents/skills/` leaves with lock entries are vendored; `adaptedFrom` is informational lineage
- **Provenance drift**: `.agents/skills/` leaf without lock, root leaf with lock, orphan lock, or conflicting `upstream`/lock source is drift; singular `upstream`, when present, must agree with lock source
- **Logical routing**: `skill-harnesses.nix` sparsely maps root skill names to supported harnesses; unlisted root skills are logical common
- **Precedence/collisions**: physical harness skills override logical common at final selection; same-layer root/vendored or routed/physical duplicates are invalid
- **Whole-dir/source fidelity**: preserve complete skill directories and instructional content; only repository-owned provenance metadata may differ; reject unsuitable sources rather than rewriting them
- **Scoped CLI projection**: add and refresh exactly one skill for one harness with `--copy`; never use wildcard selectors or broad `skills update`
- **Bootstrap packs**: `packs/` catalogs are ordered Skills CLI source/name sets with optional ordered pack dependencies; they are separate from profile selection and never prune existing skills
- **Pack runner**: root `packs.sh` resolves dependencies first, validates the full closure before invoking Skills CLI, requires full HTTPS sources, groups calls by source, defaults omitted `--agent` to Skills CLI `universal` (`.agents/skills/`), and leaves `skills-lock.json` under Skills CLI ownership; the flake exposes it as `#packs` and the default app

## Child DOX Index

- `lib/AGENTS.md` — Nix selection API (`lib.skillsFor`, `select-skills.nix`, `default.nix`)
- `packs/AGENTS.md` — bootstrap pack manifests, ordering, validation, and lock-ownership contracts
- `tests/AGENTS.md` — repository verification (`selector.nix`, `packs.sh`, `skills-cli.sh`)
- `skills/AGENTS.md` — authored/adapted skill ownership, routing, and whole-tree contracts
- Root-owned files: `README.md`, `flake.nix`, `packs.sh`, `.gitignore`, and any other root-level project documentation or runner.
