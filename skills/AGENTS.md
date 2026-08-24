# skills

## Purpose

- Canonical authored and adapted skill trees.

## Ownership

- Each direct child directory is one complete skill leaf.
- Root `skill-harnesses.nix` owns sparse logical harness routing.
- Root `skill-selection.nix` owns global selection exclusions.

## Local Contracts

- Preserve each whole tree, including scripts, references, assets, licenses, fixtures, and test material.
- Skills absent from `skill-harnesses.nix` are logical common.
- Routed skills belong only to their named logical harness, not common.
- Authored/adapted leaves have no `skills-lock.json` entry.
- Excluded authored leaves remain canonical here and may have one matching relative project projection at `.agents/skills/<name>` → `../../skills/<name>`.

## Work Guidance

- Move whole directories; keep only the explicit project projections owned by `skill-selection.nix`; do not create compatibility copies or symlinks in old roots.
- Keep skill names, profile membership, global exclusion, logical routing, and project projections aligned.

## Verification

- Run `nix eval --file tests/selector.nix` and full checks in `tests/AGENTS.md`.

## Child DOX Index

- `programming/AGENTS.md` — programming skill routing, reference ownership, checker consistency, and local verification.
- Other nested AGENTS.md files under skill fixtures are test material unless indexed here.
