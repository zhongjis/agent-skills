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
- `misc/pi-jsonl-logs/` owns Pi session-history analysis; preserve whole-file accounting, direct/recorded-nested tool coverage, explicit branch-history scope, and visible incomplete-metadata limits. `SKILL.md` routes extraction; `references/schema-and-patterns.md` owns schema/context distinctions; `tests/check.sh` verifies the Bash/jq CLI contracts.
- `engineering/research/` owns ordinary primary-source research and explicitly opted-in deep workflow routing; deep findings require atomic evidence and verified coverage, failures remain visible, and research or workflow execution does not authorize persistence, rendering, or publication.
- `code-review/SKILL.md` and its context-gathering / parallel-axes references own scope-matched local reviews, shared dependency-contract evidence, and scope-grounded requirements; preserve these contracts across review passes.
- `productivity/orchestrate-using-herdr/` owns user-invoked Herdr orchestration of tasks agreed in conversation before invocation: `SKILL.md` owns invocation (tasks, batch, flags, sticky work routing, authority), roles (orchestrator writes spec and acceptance criteria, uses subagents only for its own duties; workers own execution and approach), the per-task workflow with queued tasks, context assessment before each work instruction (Keep, Compact, Handoff, New), safe transition boundaries and verified session delivery, house rules, supervision, and the log-built report at each yield; `scripts/` own startup (`orchestrate-init.sh`: Herdr check, idempotent `[o]` pane label, per-pane log path outside every repo) and the append-only TSV task log (`log.sh`); `references/` own per-task launch (`preflight.md`), the ticket-shaped brief (`delegation-contract.md`), `--track` ticket filing (`track.md`), `--auto` merging (`auto-merge.md`), and per-kind `agent-quirks.md`; `evals/evals.json` owns focused scenarios.
- `productivity/writing-for-agents/SKILL.md` owns agent-document writing guidance, including the document table (readers, load, reference per document type), scope- and risk-proportionate completion criteria, contract-preserving compression, and authorized simplification checked against intended behavior; `references/tool-descriptions.md` owns self-scoped tool descriptions, leaving tool routing to instruction layers. `references/project-instructions.md` owns contract-only project instructions, shared harness-neutral readers, code as implementation truth, and scope-based progressive disclosure.
- `engineering/pr/SKILL.md` owns PR title and description rules for creation and post-push maintenance; `engineering/pr/evals/evals.json` owns focused scenarios. `engineering/address-comments/` owns comments; `tools/gh/` owns generic GitHub operations; installed `before-and-after` owns UI media attachment, using `agent-browser` for capture.
- `engineering/retro/` is adapted from Matt Pocock's upstream `retro`; it locates session logs and steering files through the global **Agent Environment** instruction (nix-config `common/instructions/personal`) and names an owning source for each finding; it judges layer placement against `writing-for-agents` and owns only the symptom-to-source lookup and shared-file delivery as proposals.
- `engineering/programming/` owns code and test quality (testing policy, mocking ladder, test anti-patterns) and routes test-first work one-way to `engineering/tdd/`. `engineering/tdd/` is adapted from Matt Pocock's upstream `tdd` and owns only test-first sequencing: seams agreed once per task (revisited on scope or interface change), vertical slices, and red → green with refactoring deferred to review; it must not reference `programming` or restate test-quality policy.
- `engineering/address-comments/` defaults an invocation without a PR identifier to the open PR associated with the current branch; an explicit PR number or URL selects and checks out that PR first. Default mode executes its scoped plan and amendments without approval; explicit `--manual` requires approval for listed local work and named remote actions while retaining the same safety and completion gates. It owns identity-based conversation-bot triage without excluding bot reviews/threads, and check-failure triage separating configured required checks from other observed CI/deployment checks (including none configured). Every reported failure requires read-only log inspection or an exact access/tool blocker and link as unclassified. Replies follow publication; each push gets one 5-minute required-check window and refreshes both check views. Existing actionable, in-scope test/CI gate failures are repaired alongside comments regardless of required-check configuration or PR attribution; later repairs amend the plan, and failures left open require concrete blockers. Reply/review writes are serialized; prefer REST root-comment replies and verify submitted comments, non-pending parent reviews, and intended reply targets. Draft publication is limited to authorized workflow-owned reviews with `COMMENT`; non-thread replies exclude findings already represented inline. Threads replied to in a pass stay unresolved for the reviewer; only `settled` prior-round threads are resolved, where the PR author replied last and the same reviewer has later PR activity.

## Verification

- Run `nix eval --file tests/selector.nix` and full checks in `tests/AGENTS.md`.

## Child DOX Index

- Other nested AGENTS.md files under skill fixtures are test material unless indexed here.
