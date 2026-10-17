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
- `productivity/orchestrate-using-herdr/SKILL.md` owns user-invoked Herdr orchestration: task source (invocation list, else agreed session tasks), subagent-versus-Herdr-agent choice, house rules (worktree per unit from the parent source, pi workers by default, scoped local-commit authority carried into implementation briefs, lowercase unit-derived names, no focus or label mutation, briefs per `references/delegation-contract.md`, `ulw` ending Pi prompts), follow-up worker context (keep, handoff, or new; steering is out of scope) with per-kind commands in `agent-quirks.md`, and modes (default fire-and-forget; `--watch` supervises to destination-verified results; `--track` adds a ticket and supervises; `--auto` merges PRs through fail-closed gates). References own the one-task (`single.md`) and confirmed batch (`batch.md`, including the PR-review example) workflows, `track.md`, `auto-merge.md`, `herdr-pitfalls.md`, and per-kind `agent-quirks.md`; `evals/evals.json` owns focused scenarios.
- `productivity/writing-for-agents/SKILL.md` owns agent-document writing guidance, including contract-preserving compression and behavioral-equivalence checks.
- `engineering/pr/SKILL.md` owns PR title and description rules for creation and post-push maintenance; `engineering/pr/evals/evals.json` owns focused scenarios. `engineering/address-comments/` owns comments; `tools/gh/` owns generic GitHub operations; installed `before-and-after` owns UI media attachment, using `agent-browser` for capture.
- `engineering/retro/` is adapted from Matt Pocock's upstream `retro`; it locates session logs and steering files through the global **Agent Environment** instruction (nix-config `common/instructions/personal`) and names an owning source for each finding.
- `engineering/programming/` owns code and test quality (testing policy, mocking ladder, test anti-patterns) and routes test-first work one-way to `engineering/tdd/`. `engineering/tdd/` is adapted from Matt Pocock's upstream `tdd` and owns only test-first sequencing: seams agreed once per task (revisited on scope or interface change), vertical slices, and red → green with refactoring deferred to review; it must not reference `programming` or restate test-quality policy.
- `engineering/address-comments/` defaults an invocation without a PR identifier to the open PR associated with the current branch; an explicit PR number or URL selects and checks out that PR first. Default mode executes its scoped plan and amendments without approval; explicit `--manual` requires approval for listed local work and named remote actions while retaining the same safety and completion gates. It owns identity-based conversation-bot triage without excluding bot reviews/threads, and check-failure triage separating configured required checks from other observed CI/deployment checks (including none configured). Every reported failure requires read-only log inspection or an exact access/tool blocker and link as unclassified. Replies follow publication; each push gets one 5-minute required-check window and refreshes both check views. PR-introduced required-check failures carry scoped repair authority; other actionable in-scope failures require a material plan amendment or stay open, and evidenced base/pre-existing, flaky, or infrastructure failures stay open. Reply/review writes are serialized; prefer REST root-comment replies and verify submitted comments, non-pending parent reviews, and intended reply targets. Draft publication is limited to authorized workflow-owned reviews with `COMMENT`; non-thread replies exclude findings already represented inline. Threads replied to in a pass stay unresolved for the reviewer; only `settled` prior-round threads are resolved, where the PR author replied last and the same reviewer has later PR activity.

## Verification

- Run `nix eval --file tests/selector.nix` and full checks in `tests/AGENTS.md`.

## Child DOX Index

- Other nested AGENTS.md files under skill fixtures are test material unless indexed here.
