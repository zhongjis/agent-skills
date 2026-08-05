# tests

## Purpose

- Repository verification for the Nix selection API and the Skills CLI lifecycle.

## Ownership

- `selector.nix` — asserts `lib.skillsFor` outputs and path validity against `.agents/skills/`, `.claude/skills/`, `.pi/skills/` agent folders.
- `skills-cli.sh` — exercises the `skills` CLI install/update/remove lifecycle.

## Local Contracts

- `selector.nix` checks selection output against explicit expected name lists (`commonGeneralNames`, `personalNames`, `workNames`, and per-harness additions) plus failure cases; keep these lists in sync with agent-folder skill dirs when leaves change. Also imports `../profiles.nix` for 3 guardrail asserts: (i) personal∩work==[], (ii) every profile name has SKILL.md, (iii) bucket membership and 77-general count.
- `skills-cli.sh` uses the installed `skills` binary and falls back to `npx skills`. `SKILLS_CLI_FORCE_NPX=true` forces the npx path. It verifies discovery, explicit installs, support-file copies, updates, removals, cleanup, and source-tree immutability.

## Verification

- Full suite:
  - `nix flake check path:.`
  - `nix eval --file tests/selector.nix`
  - `bash tests/skills-cli.sh`
  - `SKILLS_CLI_FORCE_NPX=true bash tests/skills-cli.sh`

## Child DOX Index

- No child AGENTS.md files.
