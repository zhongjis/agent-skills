# skills

## Purpose

- Canonical authored and adapted skill trees.

## Ownership

- Each direct child directory is one complete skill leaf.
- Root `skill-harnesses.nix` owns sparse logical harness routing.

## Local Contracts

- Preserve each whole tree, including scripts, references, assets, licenses, fixtures, and test material.
- Skills absent from `skill-harnesses.nix` are logical common.
- Routed skills belong only to their named logical harness, not common.
- Authored/adapted leaves have no `skills-lock.json` entry.

## Work Guidance

- Move whole directories; do not create compatibility copies or symlinks in old roots.
- Keep skill names, profile membership, and logical routing aligned.

## Verification

- Run `nix eval --file tests/selector.nix` and full checks in `tests/AGENTS.md`.

## Child DOX Index

- No child project AGENTS.md files. Nested fixture AGENTS.md files are test material.
