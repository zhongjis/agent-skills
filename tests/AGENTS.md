# tests

## Purpose

- Repository verification for the Nix selection API, pack runner, and scoped Skills CLI lifecycle.

## Ownership

- `selector.nix` — asserts root/vendored/physical discovery, sparse routing validation, collision rejection, profile outputs, and path validity.
- `skills-cli.sh` — exercises lock-aware discovery and an explicit copy/list/refresh/remove lifecycle.
- `packs.sh` — exercises the root pack runner through synthetic and repository manifests with a fake Skills CLI.

## Local Contracts

- `selector.nix` derives selection expectations from root `skills/`, vendored common, physical harness folders, `skill-harnesses.nix`, and `profiles.nix`. It pins the 18 authored/adapted root names, verifies Pi-only routing, layer collisions, stale/unsupported routes, profile filtering, valid paths, final harness overrides, invalid arguments, and profile references.
- `skills-cli.sh` uses installed `skills`, falling back to `npx skills`; `SKILLS_CLI_FORCE_NPX=true` forces npx. Its mixed-root fixture keeps unlocked authored source in `skills/` and locked vendored source in `.agents/skills/`, then verifies discovery, copied add/list/refresh/remove, support files, no symlinks, lock cleanup, source immutability, and temp cleanup.
- `packs.sh` invokes root `packs.sh` from an arbitrary temp cwd with synthetic or repository `PACKS_DIR` catalogs and a `PACKS_SKILLS_BIN` fake. It verifies default `universal` and explicit agent targets, dependency-first closure resolution, cycle/missing/malformed preflight rejection, full HTTPS sources and shorthand rejection, repository membership, ordered grouping and deduplication, exact CLI arguments/cwd/status, and exclusive fake-CLI ownership of lock bytes without any real remote install.

## Verification

- Full suite:
  - `nix flake check path:.`
  - `nix eval --file tests/selector.nix`
  - `bash tests/packs.sh`
  - `bash tests/skills-cli.sh`
  - `SKILLS_CLI_FORCE_NPX=true bash tests/skills-cli.sh`

## Child DOX Index

- No child AGENTS.md files.
