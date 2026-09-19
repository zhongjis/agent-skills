# skills

## Purpose

- Canonical authored and adapted skill trees.

## Ownership

- Each direct child directory is a category grouping (`engineering/`, `tools/`, `productivity/`, `misc/`, `in-progress/`); each skill leaf is one complete directory nested one level under its category.
- Root `skill-harnesses.nix` owns sparse logical harness routing.
- Root `skill-selection.nix` owns global selection exclusions.

## Local Contracts

- Preserve each whole tree, including scripts, references, assets, licenses, fixtures, and test material.
- Skills absent from `skill-harnesses.nix` are logical common.
- Routed skills belong only to their named logical harness, not common.
- Authored/adapted leaves have no `skills-lock.json` entry.
- Excluded authored leaves remain canonical here and may have one matching relative project projection at `.agents/skills/<name>` → `../../skills/<category>/<name>`.

## Work Guidance

- Move whole directories; keep only the explicit project projections owned by `skill-selection.nix`; do not create compatibility copies or symlinks in old roots.
- Keep skill names, profile membership, global exclusion, logical routing, and project projections aligned.
- `engineering/research/` owns ordinary primary-source research and explicitly opted-in deep workflow routing; deep findings require atomic evidence and verified coverage, failures remain visible, and research or workflow execution does not authorize persistence, rendering, or publication.
- `code-review/SKILL.md` and its context-gathering / parallel-axes references own scope-matched local reviews, shared dependency-contract evidence, and scope-grounded requirements; preserve these contracts across review passes.
- `herdr-bulk-action/SKILL.md` owns user-invoked, explicitly confirmed generic Herdr batches: referenced task behavior with user overrides, task-needed isolation, and a bounded lifecycle; its `evals/evals.json` owns focused scenarios. Keep `herdr-bulk-review` separate.
- `engineering/pr/` owns evidence-backed PR-body drafting and revision, including template/body preservation, generic tracker references, disclosed visuals, and focused eval scenarios; `tools/gh/` owns generic GitHub CLI, authentication, PR creation, comment, and review operations; installed `before-and-after` owns specialized user-visible UI media attachment, using `agent-browser` for capture.
- `engineering/address-comments/` defaults an invocation without a PR identifier to the open PR associated with the current branch; an explicit PR number or URL selects and checks out that PR first. It owns required PR-check closure: repair every failure introduced relative to the PR base, and leave evidenced base/pre-existing, flaky, or infrastructure failures open.

## Verification

- Run `nix eval --file tests/selector.nix` and full checks in `tests/AGENTS.md`.

## Child DOX Index

- `engineering/programming/AGENTS.md` — programming skill routing, reference ownership, checker consistency, and local verification.
- Other nested AGENTS.md files under skill fixtures are test material unless indexed here.
