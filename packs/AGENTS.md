# packs

## Purpose

- Declarative bootstrap catalogs installed through the root `packs.sh` runner and Nix app.

## Ownership

- `typescript.json` — TypeScript tooling and best-practice skills.
- `typescript-vite-react.json` — React best practices layered on the TypeScript pack.
- `vercel.json` — Vercel deployment and React best-practice skills layered on the TypeScript pack.

## Local Contracts

- Every manifest has schema `1`, a nonempty explicit `skills` array, and optional `dependsOn`; each source is a full HTTPS URL, and each dependency is a logical pack name.
- The runner resolves requested packs and ordered dependencies depth-first, emits dependencies before dependents, deduplicates packs and identical `(source, name)` tuples, preserves first source and skill order, and rejects cycles, missing dependencies, or one skill name assigned to different sources.
- The full dependency closure is validated before Skills CLI runs.
- Packs bootstrap copied skills only. They do not prune existing skills and remain orthogonal to `profiles.nix` selection.
- Omitted `--agent` targets Skills CLI `universal` and writes to project `.agents/skills/`; an explicit agent remains a harness-specific override.
- Skills CLI exclusively owns caller `skills-lock.json`; manifests and runner must not restore, rewrite, remove, or otherwise manage it.

## Work Guidance

- Verify each source/name pairing against source discovery with `skills add SOURCE --list` before adding or changing catalog entries.
- Keep catalogs explicit; do not use wildcard or hosted pack expansion.

## Verification

- `bash tests/packs.sh`
- `nix run path:.#packs -- --help`

## Child DOX Index

- No child AGENTS.md files.
