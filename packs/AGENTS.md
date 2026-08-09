# packs

## Purpose

- Declarative bootstrap catalogs installed through the root `packs.sh` runner and Nix app.

## Ownership

- `typescript.json` — TypeScript tooling and best-practice skills.
- `vercel.json` — Vercel deployment and React best-practice skills.

## Local Contracts

- Every manifest has exactly `{ "schema": 1, "skills": [{"source":"owner/repo","name":"skill-name"}] }`; `skills` is nonempty and every source/name tuple is explicit.
- The runner merges selected manifests in pack order, preserves first source and skill order, deduplicates identical `(source, name)` tuples, and rejects one skill name assigned to different sources.
- Packs bootstrap copied skills only. They do not prune existing skills and remain orthogonal to `profiles.nix` selection.
- Skills CLI exclusively owns caller `skills-lock.json`; manifests and runner must not restore, rewrite, remove, or otherwise manage it.

## Work Guidance

- Verify each source/name pairing against source discovery with `skills add SOURCE --list` before adding or changing catalog entries.
- Keep catalogs explicit; do not use wildcard or hosted pack expansion.

## Verification

- `bash tests/packs.sh`
- `nix run path:.#packs -- --help`

## Child DOX Index

- No child AGENTS.md files.
