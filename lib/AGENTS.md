# lib

## Purpose

- Pure Nix skill-selection API exported by `flake.nix` as `lib = import ./lib`.

## Ownership

- `default.nix` — skill discovery per category and the `skillsFor` entry point.
- `select-skills.nix` — argument validation, profile/harness grouping, merge, and duplicate detection.

## Local Contracts

- `lib.skillsFor { profile, harness? }` returns `{ skill-name = skill-directory-path; }`. No side effects; it does not install Home Manager config.
- `profile` is required and must be `"personal"` or `"work"`.
- `harness` is optional: `null` selects common skills only; otherwise one of `"claude-code"`, `"codex"`, `"factory"`, `"omp"`, `"opencode"`, `"pi"`.
- Unsupported arguments, missing/invalid `profile`, invalid `harness`, or duplicate skill names throw.
- `default.nix` reads every directory under each `skills/<category>` and throws when a directory lacks `SKILL.md`.
- Harness leaves override common leaves of the same name via `mergeGroups commonGroups // mergeGroups harnessGroups`.
- Adding a category/harness requires a new `discoverSkills ../skills/<category>` group in `default.nix` and a matching route in `select-skills.nix`.

## Verification

- `nix eval --file tests/selector.nix` and `nix flake check path:.`. Full suite: see `tests/AGENTS.md`.

## Child DOX Index

- No child AGENTS.md files. Root owns files above `lib/`.
