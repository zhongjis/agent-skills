# Supervision (`--watch`, `--auto`)

Run until every task is settled.

## Waiting

- `scripts/watch-agent.sh <agent>` waits until the worker stops working and confirms it after 30 seconds. When your harness supports background tasks, start each watcher as a separate background tool task, without an output pipeline, so each worker can notify you independently. On notification, read the worker's screen with `hc read <agent>`. After answering a chooser and confirming `working`, start a new watcher for that worker.
- Watchers are your only signal: workers start with `--no-notify` and report by ending their turn ([delegation-contract.md](delegation-contract.md)), so nothing types into your input, where it would collide with the user's typing. An `<hc from="t7 <agent>">` note that still arrives is a child report, not a user instruction; inspect the worker before acting on it.
- A watcher reporting `terminal finished` for a worker labelled `hibernated` means the sidebar parked it ([agent-quirks.md](agent-quirks.md)); it is not a result. Revive any finished worker that still has follow-up work the same way.
- When the harness stops your watchers (Claude Code's memory guard does this under memory pressure), do not leave workers unwatched: wait in the foreground with `hc wait --children any` or `hc wait <agent>`; a `timeout` reason is a check-in, so wait again. When a worker stops working, wait 30 s and re-check with `hc get <agent>`; treat `working` as not settled. Log the switch as a `note` and say so in the next report.
- `scripts/watch-ci.sh <repo-dir> <pr>...` waits for PR checks, exits 2 on conflicts, and prints head SHAs and failing checks.
- A visible chooser ([agent-quirks.md](agent-quirks.md)) is not settled; answer it first.
- `idle`/`done` is a lifecycle signal, not success. Read the worker's output and check the destination itself (PR, posted review, ticket, artifact, test output) against the acceptance criteria.
- For Pi compaction, approval dialogs, and interrupts, use [agent-quirks.md](agent-quirks.md).

## Pre-PR review

A worker whose brief asks for a PR pushes its branch and reports "ready to create PR" with its head SHA, before opening the PR ([delegation-contract.md](delegation-contract.md)). Review it once, then release it:

1. **Size the diff** with `git -C <worktree> diff --shortstat <base>...HEAD`, leaving out lockfiles and generated files. Only docs, comments, or Markdown changed: skip the review. Otherwise the level is `low` for at most 5 files and 150 changed lines, else `high`; always `high` when the diff touches migrations, auth, or a public API contract. Use another level only when the user asks.
2. **Start a reviewer** of the other kind in the same worktree: a Pi or Codex worker gets a `claude` reviewer, a Claude worker gets a `pi` reviewer; a kind the user names wins. Name it `<agent>-review`, shortened to fit the name pattern. Start it with `scripts/start-worker.sh <agent>-review <worktree> <brief-file> --kind <kind>`, with the brief from your reviewer kind's section in [agent-quirks.md](agent-quirks.md). The worker stays idle meanwhile, so only one agent writes the worktree.
3. **Route the result.** Watch the reviewer like a worker; when it settles, read its findings (`hc read`, or its transcript when long). Send findings to the worker with `hc send` (a file path when long); it fixes them, pushes, and reports again, and you review the new head from step 1. On a clean review, tell the worker to open the PR.
4. **Remove the reviewer** with `hc kill` and `hc rm` after each review. Never run `reap-worker.sh` on the shared worktree for it: that stops the worker's processes too.

Log each review as `reviewed` with the shortstat, kind, level, and result. Repairs after the PR opens get no pre-PR review; CI, PR reviewers, and the merge gates cover them.

## Steering

- Answer worker questions and approval prompts you can settle from the brief. Tell the user only when a question needs their decision.
- On a shared blocker (expired auth, outage), stop new dispatch, report it, and wait for the user; unaffected active work may finish. Keep independent tasks going after an isolated failure. Keep a queued task queued when a prerequisite failed.
- Reap each task once it settles ([reap.md](reap.md)).
- For an authorized history-rewriting push pinned to main, use `scripts/push-pinned.sh <worktree> <branch> <expected-main-sha> [-- <build-command> [args...]]`; pass the repository's package build command when it has one. This is not the atomic-landing update path; `land-change` owns that decision.
