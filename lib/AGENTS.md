# lib

## Purpose

- Pure Nix skill-selection API exported by `flake.nix` as `lib = import ./lib`.

## Ownership

- `default.nix` — discovery from root `skills/`, vendored common, and physical harness folders; profile splitting; `skillsFor` entry point.
- `assemble-skills.nix` — sparse root routing, route validation, layer partitioning, and same-layer collision rejection.
- `select-skills.nix` — argument validation, profile/harness grouping, merge, and duplicate detection.

## Local Contracts

- `lib.skillsFor { profile, harness? }` returns `{ skill-name = skill-directory-path; }`. No side effects; it does not install Home Manager config.
- `profile` is required and must be `"personal"` or `"work"`.
- `harness` is optional: `null` selects common skills only; otherwise one of `"claude-code"`, `"codex"`, `"factory"`, `"omp"`, `"opencode"`, `"pi"`.
- Unsupported arguments, missing/invalid `profile`, invalid `harness`, or duplicate skill names throw.
- `default.nix` discovers authored/adapted root skills, vendored common skills, and physical harness skills; missing folders return `{}`; directories without `SKILL.md` throw.
- `skill-harnesses.nix` routes named root skills only to supported logical harnesses; unlisted root skills are common. Stale/unsupported routes throw.
- Root-common/vendored-common and routed-root/physical-harness collisions throw before layer merge. Final harness-over-common precedence remains in `select-skills.nix`.
- Skills split into `general`/`personal`/`work` via `profiles.nix` (root). Names in `profiles.personal` → personal; names in `profiles.work` → work; others → general.
- All 21 group keys (`commonGeneral`…`piWork`) always present; `select-skills.nix` references them by name — do not edit `select-skills.nix`.
- Adding a harness: new entry in `agentFolders`, split bindings, three group keys in `groups`, matching route in `select-skills.nix`.

## Verification

- `nix eval --file tests/selector.nix` and `nix flake check path:.`. Full suite: see `tests/AGENTS.md`.

## Child DOX Index

- No child AGENTS.md files. Root owns files above `lib/`.
