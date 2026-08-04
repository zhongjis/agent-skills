# skills

## Purpose

- Canonical, public-safe agent skill catalog.
- Every selectable leaf lives at `skills/<category>/<skill>/SKILL.md`.

## Ownership

- Owns the `<category>` buckets and the arrangement of skill leaves within them.
- Skill-internal files (`SKILL.md`, `references/`, scripts, licenses, assets, and any per-skill `AGENTS.md`/`CLAUDE.md`) are content of that skill, not this repo's DOX tree. Do not treat or edit them as DOX docs.

## Local Contracts

- Categories are `<harness>-<profile>`: harness ∈ `common`, `claude-code`, `codex`, `factory`, `omp`, `opencode`, `pi`; profile ∈ `general`, `personal`, `work`.
- Every skill directory must contain `SKILL.md` — Nix discovery (`lib/default.nix`) throws otherwise.
- Preserve each skill directory as one unit: scripts, references, licenses, assets.
- Keep existing `upstream` and `adaptedFrom` frontmatter when moving or updating a leaf.
- Harness leaves override common leaves of the same name; a name must not repeat within the common groups or within a single harness's groups.
- Keep private, work-internal, secret, host, and credential material out of this public repo.

## Work Guidance

- Add a leaf with `skills init <name>`, then move it into the correct `<category>` directory.
- When adding, removing, or renaming a leaf, update the README category counts and the expected name lists in `tests/selector.nix`.

## Verification

- Selection correctness is checked by `nix eval --file tests/selector.nix`. Full suite: see `tests/AGENTS.md`.

## Child DOX Index

- No child AGENTS.md files. Individual skill directories manage their own internal docs and are owned by this doc.
