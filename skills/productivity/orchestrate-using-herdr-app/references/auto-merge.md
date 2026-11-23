# Auto merge (`--auto`)

The worker delivers a PR under the PR worker contract in [delegation-contract.md](delegation-contract.md), the same as under `--watch`; you merge it only when every gate closes. Never bypass branch protection or human approval.

## Merge gates (you)

Complete [supervise.md](supervise.md)'s local whole-branch review before push, same-session incremental review, and post-push bot convergence first. Its round budgets, no-bot-review fallback, relay of every finding, and cap handling apply here too. Non-blocking findings never trigger another round.

Immediately before merging, confirm all of these for the recorded head SHA:

- a [claims audit](supervise.md#local-review-before-push) of the worker's evidence since publication finds nothing open;
- the session epic's latest `event=mode` comment shows `--auto` for this task; under it, merge when the remaining gates close, without asking ([SKILL.md](../SKILL.md) Authority);
- the head SHA is unchanged and has no unexpected third-party commits;
- the PR is open, non-draft, and mergeable;
- CI is green for that SHA, including every required check, and no blocker remains;
- the task bead has no `blocked_reason=needs-user` metadata: an open user question holds the merge, even one asked by an earlier session;
- repository-required approvals and review-thread resolution are satisfied for that SHA, including protection that blocks merging on `CHANGES_REQUESTED`;
- no release or deploy run is in progress or queued on the default branch (another merge, possibly from a peer orchestrator). If one is, wait for it to finish, then re-check every gate. A wait past the release workflow's own timeout is a shared blocker ([supervise.md](supervise.md)).
- a saved infrastructure plan that the merge applies is current for the head SHA and marked non-destructive; `--auto` approves it with the merge. A destructive or stale plan stays a user decision.

Squash-merge: through the repository's merge queue when it has one (configured for squash), otherwise `gh pr merge <pr> --squash`. When the repository does not allow squash merges, leave the PR open and ask the user. An optional configured bot still silent after the 15-minute review window is not itself a merge blocker; non-blocking findings may be listed in the PR body. Any failed or uncertain repository-required gate (including a missing required approval, protected `CHANGES_REQUESTED`, or required thread resolution) leaves the PR open with evidence; send in-scope repairs back to the worker.

## After merge

Read back the merged state and verify the merge SHA on the target branch before reporting success or closing the task bead; record `scripts/event.sh <bead> merged merged_sha=<sha>` and `merged_sha` metadata. A changed PR head reopens the task bead for re-review. When the repository deploys on merge, watch that merge's release run to completion. The task is settled only when every deploy job succeeded at the merge SHA; record `settled result=succeeded` only with that evidence. A dependent's PR cannot merge before each prerequisite has that event. A failed release is a shared blocker ([supervise.md](supervise.md)): merge nothing more until it is understood. Report a merged change as live only with that evidence. Then reap the settled task with full cleanup ([reap.md](reap.md)). On any blocker, keep the PR, worktree, and evidence intact.
