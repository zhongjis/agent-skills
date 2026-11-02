# Supervision (`--watch`, `--auto`)

Run until every task is settled.

## Waiting

- `scripts/watch-agent.sh <agent>` waits for a settled state and confirms it after 30 seconds. When your harness supports background tasks, start each watcher as a separate background tool task, without an output pipeline, so each worker can notify you independently. On notification, inspect the worker's visible pane. After answering a chooser and confirming `working`, start a new watcher for that worker.
- When the harness stops your watchers (Claude Code's memory guard does this under memory pressure), do not leave workers unwatched: wait in the foreground with `herdr agent wait <agent> --until idle --until blocked --until done --timeout <ms>`; when it returns, wait 30 s and re-check with `herdr agent get <agent>`, treat `working` as not settled, and on timeout wait again. Log the switch as a `note` and say so in the next report.
- `scripts/watch-ci.sh <repo-dir> <pr>...` waits for PR checks, exits 2 on conflicts, and prints head SHAs and failing checks.
- A visible chooser ([agent-quirks.md](agent-quirks.md)) is not settled; answer it first.
- Herdr `idle`/`done` is a lifecycle signal, not success. Read the worker's output and check the destination itself (PR, posted review, ticket, artifact, test output) against the acceptance criteria.
- For Pi compaction, approval dialogs, and interrupts, use [agent-quirks.md](agent-quirks.md).

## Steering

- Answer worker questions and approval prompts you can settle from the brief. Tell the user only when a question needs their decision; they can see `blocked` panes themselves.
- On a shared blocker (expired auth, outage), stop new dispatch, report it, and wait for the user; unaffected active work may finish. Keep independent tasks going after an isolated failure. Keep a queued task queued when a prerequisite failed.
- Reap each task once it settles ([reap.md](reap.md)).
- For an authorized history-rewriting push pinned to main, use `scripts/push-pinned.sh <worktree> <branch> <expected-main-sha> [-- <build-command> [args...]]`; pass the repository's package build command when it has one. This is not the atomic-landing update path; `land-change` owns that decision.
