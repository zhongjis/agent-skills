# Supervision (`--watch`, `--auto`)

Run until every task is settled.

## Waiting

- `scripts/watch-thread.sh <thread-id>` waits until the thread's latest run ends and confirms it after 30 seconds. When your harness supports background tasks, start each watcher as a separate background tool task, without an output pipeline, so each worker can notify you independently. On notification, read the worker's thread with `t3_thread_read`. After answering a question and confirming the run is in progress again, start a new watcher for that worker.
- Without background tasks, or when the harness stops your watchers, do not leave workers unwatched: wait in the foreground with `t3_thread_wait {threadId, timeoutMs}`; when it returns, wait 30 s and re-check with `t3_thread_read`, treat a running run as not settled, and on timeout wait again. Log the switch as a `note` and say so in the next report.
- For each PR a worker reports, call `link_pull_request {threadId: <worker>, url}` so its status shows on the worker thread, then `watch_pull_request {url}` on your own thread. T3 wakes you on failed checks, passing required checks, new comments or reviews, and conflicts; the watch stays on after each wake. End your turn after arming it when nothing else needs you.
- A wake or an ended run is a lifecycle signal, not success. Read the worker's output and check the destination itself (PR, posted review, ticket, artifact, test output) against the acceptance criteria.
- A worker waiting on a question is not settled: answer it first. A worker waiting on an approval needs the user ([agent-quirks.md](agent-quirks.md)).

## Steering

- Answer worker questions you can settle from the brief with `t3_pending_request` on the worker's thread (`list`, `read`, `respond`). Tell the user only when a question needs their decision. Approvals reach only the user in T3: report the task and its thread link.
- Send steering, repairs, and follow-ups with `t3_thread_send` to the worker's thread, in the session context [worker-context.md](worker-context.md) chooses.
- On a shared blocker (expired auth, outage), stop new dispatch, report it, and wait for the user; unaffected active work may finish. Keep independent tasks going after an isolated failure. Keep a queued task queued when a prerequisite failed.
- Reap each task once it settles ([reap.md](reap.md)).
- For an authorized history-rewriting push pinned to main, use `scripts/push-pinned.sh <worktree> <branch> <expected-main-sha> [-- <build-command> [args...]]`; pass the repository's package build command when it has one. This is not the atomic-landing update path; `land-change` owns that decision.
