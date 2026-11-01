# Reap

Killing an agent leaves its detached daemons running (browsers, prettierd, Compose containers), so reap before removing anything. Workers start inside their own `AGENT_BROWSER_NAMESPACE` (preflight step 4), so reaping closes only their browsers. Log `reaped` with what was stopped.

- **Keep worker**, for a task that can still get follow-ups (PR open, review or CI pending): `scripts/reap-worker.sh <worktree> <name> --keep-agent` closes the worker's browser namespace, removes Compose projects whose working directory is inside the worktree, and stops listening processes (dev servers) running there. The worker and its worktree stay.
- **Finished**, for a task whose PR merged or closed, or whose result the user accepted: `scripts/reap-worker.sh <worktree> <name>` also stops every process running inside the worktree. Then `herdr worktree remove --workspace <ws> --force` removes the git worktree, closes the workspace, and kills its agent; map the workspace from the `pane_id` prefix in `herdr agent list`. Confirm the path is gone from `git worktree list` (the ground truth) and from disk.
- On any blocker, keep the PR, worktree, and evidence intact.
