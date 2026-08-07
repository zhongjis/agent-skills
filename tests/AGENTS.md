# tests

## Purpose

- Repository verification for the Nix selection API and the scoped Skills CLI lifecycle.

## Ownership

- `selector.nix` — asserts `lib.skillsFor` outputs and path validity against `.agents/skills/`, `.claude/skills/`, `.pi/skills/` agent folders.
- `skills-cli.sh` — exercises lock-aware discovery and an explicit copy/list/refresh/remove lifecycle.

## Local Contracts

- `selector.nix` derives expectations from agent folders and `profiles.nix`. It verifies profile filtering, valid skill paths, harness additions and overrides, absent harnesses, duplicate rejection, invalid arguments, disjoint profile buckets, and existing profile references without pinning catalog names or counts.
- `skills-cli.sh` uses the installed `skills` binary and falls back to `npx skills`; `SKILLS_CLI_FORCE_NPX=true` forces the npx path. It verifies lock-aware discovery, explicit copied install/list/refresh/remove behavior, support-file preservation, zero symlink fan-out, lock cleanup, source immutability, and temp cleanup with synthetic fixtures.

## Verification

- Full suite:
  - `nix flake check path:.`
  - `nix eval --file tests/selector.nix`
  - `bash tests/skills-cli.sh`
  - `SKILLS_CLI_FORCE_NPX=true bash tests/skills-cli.sh`

## Child DOX Index

- No child AGENTS.md files.
