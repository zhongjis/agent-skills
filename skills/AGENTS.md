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
- `engineering/delegate-using-herdr/SKILL.md` owns single-task, user-invoked issue-tracker-to-Herdr handoff: tracker resolution (supplied URL, named tracker, repository convention, otherwise one question), latest-intent handoff-contract agreement, supplied-issue reuse or creation, parent-source worktree resolution, same-kind agent dispatch, and default immediate handoff without parent monitoring or integration. Its naming contract keeps repository branch conventions distinct from lowercase issue-slug worktree basenames (numeric identifiers prefixed `gh-`), friendly labels, and unique ≤32-character lowercase-hyphen live agent names without session/tab mutation; explicit `--auto` gives the worker optional fail-closed remote delivery through merge and tracker-native closeout, while its `evals/evals.json` owns focused delegation scenarios.
- `engineering/pr/` owns evidence-backed PR-body drafting and revision on Matt Pocock's upstream `pr` skill as the unchanged base: template/body precedence, a required Summary visual, `<MISSING_EVIDENCE>` for unobserved proof, generic tracker references with `- N/A` fallback, `[<primary item ID>]` PR-title prefix, and focused eval scenarios; `tools/gh/` owns generic GitHub CLI, authentication, PR creation, comment, and review operations; installed `before-and-after` owns specialized user-visible UI media attachment, using `agent-browser` for capture.
- `engineering/address-comments/` defaults an invocation without a PR identifier to the open PR associated with the current branch; an explicit PR number or URL selects and checks out that PR first. Default mode executes its scoped plan and amendments without approval; explicit `--manual` requires approval for listed local work and named remote actions while retaining the same safety and completion gates. It owns bounded required-check handling: replies follow publication, each push gets one 5-minute required-check window, every failure introduced relative to the PR base is repaired, and evidenced base/pre-existing, flaky, or infrastructure failures stay open. Threads replied to in a pass stay unresolved for the reviewer; only `settled` prior-round threads are resolved, where the PR author replied last and the same reviewer has later PR activity.

## Verification

- Run `nix eval --file tests/selector.nix` and full checks in `tests/AGENTS.md`.

## Child DOX Index

- Other nested AGENTS.md files under skill fixtures are test material unless indexed here.
