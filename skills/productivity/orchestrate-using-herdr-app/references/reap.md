# Reap

Killing an agent leaves its detached daemons running (browsers, prettierd, Compose containers), so reap before removing anything. Workers start inside their own `AGENT_BROWSER_NAMESPACE` (preflight step 5), so reaping closes only their browsers. Log `reaped` with what was stopped.

- **Keep worker**, for a task that can still get follow-ups (PR open, review or CI pending): `scripts/reap-worker.sh <worktree> <name> --keep-agent` closes the worker's browser namespace, removes Compose projects whose working directory is inside the worktree, and stops listening processes (dev servers) running there. The worker terminal and its worktree stay.
- **Finished**, for a task whose PR merged or closed, or whose result the user accepted: `scripts/reap-worker.sh <worktree> <name>` also stops every process running inside the worktree, the agent included. Then `hc kill <name>` (skip it for a hibernated worker, which has already finished) and `hc rm <name>` remove its terminal, and `git -C <source> worktree remove --force <worktree>` removes the git worktree. Confirm the terminal is gone from `hc ls`, and the path from `git worktree list` (the ground truth) and from disk.
- On any blocker, keep the PR, worktree, and evidence intact.
