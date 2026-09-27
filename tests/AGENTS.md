# tests

## Purpose

- Repository verification for the Nix selection API, pack runner, and scoped Skills CLI lifecycle.

## Ownership

- `selector.nix` — asserts root/vendored/physical discovery, configuration-derived sparse routing, profile outputs, overrides, argument validation, and path validity.
- `assembly.nix` — asserts layer collision rejection and stale/unsupported route rejection.
- `exclusion.nix` — asserts root-only global exclusion, stale-name rejection, source preservation, and valid excluded project projections.
- `skills-cli.sh` — exercises lock-aware discovery, configuration-derived project projections, and an explicit copy/list/refresh/remove lifecycle.
- `packs.sh` — exercises the root pack runner through synthetic fixtures and every repository manifest with a fake Skills CLI.

## Local Contracts

- `selector.nix` imports `assembly.nix` and `exclusion.nix`, derives selection and routing expectations from discovered layers and configuration, and preserves profile, path, override, argument, and profile-reference checks.
- `skills-cli.sh` derives project projection expectations from symlinks and `skill-selection.nix`, then uses installed `skills`, falling back to `npx skills`; `SKILLS_CLI_FORCE_NPX=true` forces npx. Its mixed-root fixture verifies discovery, copied add/list/refresh/remove, support files, regular-file installs, lock cleanup, source immutability, and temp cleanup.
- `packs.sh` invokes root `packs.sh` from an arbitrary temp cwd with synthetic or repository `PACKS_DIR` catalogs and a `PACKS_SKILLS_BIN` fake. It verifies default `universal` and explicit agent targets, dependency-first closure resolution, cycle/missing/malformed preflight rejection, full HTTPS sources and shorthand rejection, dynamic repository-manifest success, ordered grouping and deduplication, exact synthetic CLI arguments/cwd/status, and exclusive fake-CLI ownership of lock bytes without any real remote install.

## Verification

- Full suite:
  - `nix flake check path:.`
  - `nix eval --file tests/selector.nix`
  - `bash tests/packs.sh`
  - `bash tests/skills-cli.sh`
  - `SKILLS_CLI_FORCE_NPX=true bash tests/skills-cli.sh`

## Child DOX Index

- No child AGENTS.md files.
