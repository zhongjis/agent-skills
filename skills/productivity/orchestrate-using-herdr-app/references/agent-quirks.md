# Agent quirks

Read Every kind, the section for the agent kind you start or read, and Hibernated or finished workers. `<name>` is the worker's `hc` terminal name.

## Hibernated or finished workers

Workers start without `hibernate=ok`. After a task settles and its resources are reaped, `reap-worker.sh --keep-agent` sets `hc label <name> hibernate=ok`; only then may herdr-app's Focus sidebar hibernate a Pi or Claude worker that stays idle for 5 minutes, to free the host. It exits the agent, and the terminal finishes with the labels `hibernated=<ms>` and `resume=<line>`. Its exit is that hibernation, not a crash. A worker that finished another way (a restart: `stopped_by_restart`) has no `hibernated` label but keeps the `resume=<line>` label the sidebar set while it ran. A `hc send` to either fails with exit 11 (finished).

Send every follow-up brief with `scripts/send-followup.sh <name> <worktree> <brief-file>`. It sends to a live worker and revives a finished one from its `resume` label (`hc rm`, then `start-worker.sh --resume` with the same name, worktree, kind, browser namespace, and session). For `r-` reviewer targets, add `--last-reviewed <commit>` on every follow-up: the script requires an ancestor of the worktree's HEAD and prepends the resolved incremental scope, explicitly superseding any scope in the following writable brief while preserving its content and final tokens, before live delivery or revival; exit 3 rejects a missing or invalid base. Initial whole-branch review uses `start-worker.sh` instead. Exit 2 means the worker is blocked on a dialog or has no resumable session; read its screen.

## Every kind

- **Slash commands go as keys.** `hc send` from an `hc` terminal wraps the text in `<hc from="…">…</hc>`, so the agent reads a slash command as chat and does not run it. Type every slash command with `scripts/type-command.sh <name> /new`, which presses one key per character (`space` between words, `shift+<letter>` for capitals) and then `enter`. It exits 1 without typing when the text holds a character `hc keys` has no key for (for example `_`, `!`, `$`); never run `hc keys <name> "/new" enter` as one string or hide its errors. Confirm the result on screen (Pi: `New session started`, or the status line's `ctx` drops). Briefs and follow-ups still go through `hc send` and `send-followup.sh`.

## pi

- **Prompts end with `ulw`** as the last token, after every contract section; it puts the worker in ultrawork mode so it runs to a finished result.
- **Skills by prompt.** Load a skill in the worker with `$skill:<name>` in the prompt. `start-worker.sh` sends a short prompt to read the absolute brief path, copies the brief's literal `$skill:<name>` tokens into that initial prompt, and ends it with `ulw`; keeping the triggers only inside the file would not activate them.
- **Status races startup.** Right after launch, `hc wait` can return `idle` at turn 0 before Pi submits the argv prompt; `scripts/start-worker.sh` confirms by turn count instead.
- **Approval dialogs.** Pi stops on a numbered chooser (tool approval, a question with options) and its status can read `blocked` or `idle` while the dialog is up. Read it with `hc read <name>`, answer with `hc keys <name> <digit> enter`, and confirm with `hc get <name>` that the status returns to `working`. `hc send` refuses a `blocked` terminal; never use `--force` to bypass a permission decision. Digits reach only numbered options: `Other…` has none, an out-of-range digit is ignored, and the following Enter confirms the highlighted row, which starts on the recommended option (pi-config `extensions/ask/state.ts`). To give your own answer, `hc interrupt <name>` and send it as a follow-up. After every answer, read the screen's `answered` line and correct a wrong answer in the same turn.
- **Interrupt:** `hc interrupt <name>` stops the current turn; the session and its context survive.
- **Blocked goal:** a Pi worker that marked its goal blocked shows `Goal blocked (/goal resume)`, and ordinary messages never resume it. When a follow-up clears that blocker, first type `/goal resume` with `scripts/type-command.sh <name> "/goal resume"` and confirm the status line no longer shows `Goal blocked`, then send the follow-up.
- **New session:** type `/new` with `scripts/type-command.sh <name> /new`, then send the full brief. The terminal name survives; the session starts empty.
- **New session bug:** an unknown Pi bug sometimes makes `/new` exit Pi, which finishes the terminal. If `hc get <name>` shows `finished`, `hc rm <name>`, restart with `scripts/start-worker.sh <name> <worktree> <brief-file>` carrying the full brief, and confirm it is `working`. Exiting is a bug, not the normal `/new` behavior.
- **Crash:** Pi can exit on `uncaughtException` (`AbortError: The operation was aborted`) mid-turn; the watcher reports `settled: exited`. Revive it with `scripts/send-followup.sh` and the same follow-up, opened with a line that the previous session crashed so it checks `git status` for work already done.
- **Compact:** type `/compact [what to preserve]` with `scripts/type-command.sh <name> "/compact …"`; status can read `done` while compaction runs, and a message queued during compaction is dropped. Send the follow-up only once `hc read <name>` no longer shows "Compacting".
- **Handoff:** type `/handoff <follow-up request> ulw` with `scripts/type-command.sh <name> "/handoff …"`. Pi summarizes into a new session and **preloads** the summary plus request in the editor without submitting it; once the agent is `idle`, submit with `hc keys <name> enter`. The terminal name survives.
- **Peer orchestrator** ([handoff.md](handoff.md)): argv `["pi"]`; the brief opens with `$skill:orchestrate-using-herdr-app <flags>` and ends with `ulw`.
- **Reviewer** ([supervise.md](supervise.md) Reviewer brief): open the brief with `$skill:axis-review` and end it with `ulw`.
- **Reviewer on another model** ([supervise.md](supervise.md) step 2): start it with `scripts/start-worker.sh r-<stem> <worktree> <brief-file>`, then `hc interrupt r-<stem>`, type `/mode-model <provider/model>` with `scripts/type-command.sh r-<stem> "/mode-model …"`, confirm the status line shows that model, and `hc send` the same first prompt (read the brief at its absolute path, its `$skill:` tokens, `ulw`).

## claude

- **Folder trust.** In a folder Claude has not trusted (every new worktree), startup blocks on a "trust this folder" dialog and `start-worker.sh` exits 2 with `blocked`. Read it with `hc read <name>`, answer it yourself with `hc keys` (select "Yes, I trust this folder" for the assigned worktree), then confirm the agent is `working` on the brief; if it is `idle` at turn 0, send the brief with `hc send`.
- **New session:** type `/new` with `scripts/type-command.sh <name> /new` (Claude shows it as `/clear`), then send the full brief. The terminal name survives.
- **Compact:** type `/compact [what to preserve]` with `scripts/type-command.sh <name> "/compact …"`, then send the follow-up request.
- **Handoff** takes three steps:
  1. Type `/handoff <follow-up focus>` with `scripts/type-command.sh <name> "/handoff …"`; the worker writes a handoff document to `$TMPDIR` and prints its path.
  2. Take only the path from the worker's output; do not read the document yourself.
  3. Type `/new` with `scripts/type-command.sh <name> /new`, then prompt the worker to read that path and continue with the follow-up request.
- **Peer orchestrator** ([handoff.md](handoff.md)): argv `["claude"]`; the brief opens with `/orchestrate-using-herdr-app <flags>`. Expect the folder-trust dialog in an untrusted folder.
- **Reviewer** ([supervise.md](supervise.md) Reviewer brief): send that brief as a plain review prompt, not the bundled `/code-review`: that command takes only a target, reads any later text as part of the target, and accepts no spec. A worktree a Pi worker made is new to Claude, so expect the folder-trust dialog.

## codex

- `start-worker.sh --kind codex` adds `--no-daemon`; without it, Codex runs its commands outside `hc`.
