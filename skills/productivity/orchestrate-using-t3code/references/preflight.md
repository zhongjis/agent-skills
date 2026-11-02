# Preflight

Run per task, before its worker works. **Done when** the worker thread has accepted its brief and its run is in progress.

1. **Pick the base.** The agreed base, unless the task depends on another; then read the `land-change` skill; it decides the landing shape (GitHub stack, or draft layers plus one landing PR) and each layer's base. For `gh stack` mechanics, read the gh skill's `stacked-prs.md`. Carry branch and base identities into briefs and maintain dependencies as they change. Authorized publication opens PRs from the same branches and worktrees, never a parallel set; keep backup refs when recovery points are needed.
2. **Name the worker.** Lowercase, derived from the task, matching `[a-z][a-z0-9_-]{0,31}`, `<issue-id>-<slug>` when the task has a ticket (`a2a-140-cache-keys`), a concise slug otherwise (`review-457`); prefix bare numeric IDs with `gh-`; unique among the session's workers, with a short hyphenated discriminator on a collision. The name keys the log, the worker's browser namespace, and the branch. Choose the branch by repository convention, and a friendly thread title (`A2A-140 Cache keys`).
3. **Launch the worker** with one `t3_thread_launch`:
   - `workspaceStrategy: {type: "worktree", baseRef, branch}`; for a base that is a local parent branch (a stacked layer), add `startFromOrigin: false`. T3 creates the worktree from the project checkout, never from your own worktree.
   - `title`: the friendly title.
   - `modelSelection`: omit it when you run on Pi and the user named no kind or model, so the worker inherits your provider and model; otherwise pass Pi or the kind the user named, with IDs from `orchestrator_capabilities`. Omit runtime and interaction modes: the worker inherits yours.
   - `clientRequestId`: stable per task and attempt, so a retry returns the same thread.
   - `message`: the brief ([delegation-contract.md](delegation-contract.md)), read from its file, with the worker kind's suffix from [agent-quirks.md](agent-quirks.md).
4. **Confirm it.** Read the worktree path and branch from `thread.worktreePath` and `thread.branch` in `t3_thread_read` for the returned thread, never from the title, the branch name, or `t3_worktree_list` (it lists every ref in the repository, the project checkout included); confirm `git -C <path> rev-parse HEAD` equals the intended base. When the worktree must sit at a remote head and the local branch already existed, `git fetch`, then `git -C <path> reset --hard origin/<branch>` on the fresh, clean checkout, and confirm HEAD again. Confirm the run is in progress from the launch result, or once with `t3_thread_read`; when it is uncertain, inspect with `t3_thread_list` before retrying, and retry only with the same `clientRequestId`.

## Failures

A failed or uncertain launch or prompt: report the details T3 returned and stop that task, leaving an uncertain side effect in place.
