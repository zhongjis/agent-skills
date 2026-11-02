# Supervision (`--watch`, `--auto`)

Run until every task is settled. Supervision rests on the Run bound in [preflight.md](preflight.md): workers report to it with `worker_done`, `escalation`, and `question` messages.

## Waiting

- Wait for the whole wave with one call: `orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 900000 --json`. Messages are at `.result.messages`; the batch has a `deliveryId`. An empty result or timeout is a checkpoint, not a failure.
- Process every message in the batch: answer a `question` with `orca orchestration reply --id <message_id> --body "<answer>" --json`; validate each `worker_done` against the expected active dispatch (dispatch ID, task, outcome) and check the destination; decide each settled worker's next owner (reap, reuse per [worker-context.md](worker-context.md), or retain) before acknowledging with `orca orchestration check --ack <deliveryId> --wait --types worker_done,escalation,question --timeout-ms 900000 --json`. An unacked batch replays and hides newer mail.
- After three consecutive empty waits, run `orca orchestration worker-list --include-remote --json` and act on each row's `projection.nextAction` argv and `projection.liveness.verdict` (`live`, `unverifiable`, `exited`). Rows page at 100: follow `page.nextCursor` with `--cursor` while `page.hasMore`. `unverifiable` and a `none` next action mean keep waiting. Never stop, abandon, retry, or release a worker on idle, timeout, a missing heartbeat, or `unverifiable`.
- `worker_done` and `--outcome` are lifecycle signals, not success. Read the worker's summary and check the destination itself (PR, posted review, ticket, artifact, test output) against the acceptance criteria.
- `scripts/watch-ci.sh <repo-dir> <pr>...` waits for PR checks, exits 2 on conflicts, and prints head SHAs and failing checks. When your harness supports background tasks, run it as one without an output pipeline.
- A visible chooser ([agent-quirks.md](agent-quirks.md)) is not settled; answer it first. Inspect with `orca terminal read --terminal <handle> --screen --json` (`.result.terminal.tail`) or `orca orchestration worker-read --dispatch <id> --json`.

## Broken worker contract

Pi reads the preamble Orca injects and sends `worker_done` itself. When a Pi worker exits or goes idle without one, take no action on idle alone. Gather positive evidence: `orca terminal wait --terminal <handle> --for tui-idle --timeout-ms <ms> --json`, `orca worktree ps --agent-wait --json`, and the terminal tail. Treat the task as **settled** only when the worker is idle and its result is accounted for from the destination (PR, ticket, artifact, test output). If the agent process is proven exited, stop or abandon the dispatch per `orca skills get orchestration --reference references/recovery-and-cleanup.md`; otherwise send a reminder with `orca orchestration send --to dispatch:<id> --subject "worker_done required" --body "<what to report>"`. Log the deviation as a `note`.

## Steering

- Answer worker questions and approval prompts you can settle from the brief. Tell the user only when a question needs their decision; they can see blocked terminals themselves.
- Steer a worker with `orca orchestration send --to dispatch:<id> --subject <subject> --body <body> --json` (`--subject` is required). Key presses go through `orca terminal send --terminal <handle> --text "<text>" --enter`; see [agent-quirks.md](agent-quirks.md).
- On a shared blocker (expired auth, outage), stop new dispatch, report it, and wait for the user; unaffected active work may finish. Keep independent tasks going after an isolated failure. Keep a queued task queued when a prerequisite failed.
- Reap each task once it settles ([reap.md](reap.md)).
- For an authorized history-rewriting push pinned to main, use `scripts/push-pinned.sh <worktree> <branch> <expected-main-sha> [-- <build-command> [args...]]`; pass the repository's package build command when it has one. This is not the atomic-landing update path; `land-change` owns that decision.
