# Agent quirks

Read only the section for the agent kind you start or read. `<handle>` is the worker's terminal handle (`.result.launch.outcome.handle`, or `worker-show --dispatch <id>`); always pass it as `--terminal`.

## pi

- **Prompts end with `ulw`** as the last token of the brief, after every contract section; it puts the worker in ultrawork mode so it runs to a finished result.
- **Alt screen.** pi renders on the terminal's alt screen: read it with `orca terminal read --terminal <handle> --screen --json` (`.result.terminal.tail`).
- **Skills by prompt.** Load a skill in the worker with `$skill:<name>` in the prompt.
- **Orca preamble.** Under a Run, Pi reads the injected worker preamble and sends `worker_done` itself. Without a Run it has no lifecycle obligation.
- **Approval dialogs.** Pi stops on a numbered chooser (tool approval, a question with options) and the worker can look idle while the dialog is up. Read the screen as above, answer with `orca terminal send --terminal <handle> --text "<digit>" --enter`, and confirm the screen shows work resumed. Under a Run, Pi's questions to you arrive as `question` messages; answer those with `reply`.
- **Interrupt:** `orca terminal send --terminal <handle> --text $'\x1b'` (Escape, without `--enter`) or `orca terminal send --terminal <handle> --interrupt` stops the current turn; the session and its context survive.
- **New session:** `orca terminal send --terminal <handle> --text "/new" --enter`, then send the full brief per [worker-context.md](worker-context.md). The terminal handle survives; the session starts empty.
- **New session bug:** an unknown Pi bug sometimes makes `/new` exit Pi. If the terminal falls back to a shell, it holds no agent: create a replacement worker in the same worktree (`orca orchestration worker-start --task <task_id> --worktree <selector> --agent pi --json`, or `orca agent launch` without a Run), use only the replacement handle, then resend the full brief. Exiting is a bug, not the normal `/new` behavior.
- **Compact:** `orca terminal send --terminal <handle> --text "/compact [what to preserve]" --enter`; a message queued during compaction is dropped. Send the follow-up only once the screen no longer shows "Compacting".
- **Carry-over (`/handoff`):** `orca terminal send --terminal <handle> --text "/handoff <follow-up request> ulw" --enter`. Pi summarizes into a new session and **preloads** the summary plus request in the editor without submitting it; once the screen shows the editor ready, submit with `orca terminal send --terminal <handle> --enter`. The terminal handle survives. Available without a Run only ([worker-context.md](worker-context.md)).

## claude

- **Trust and launch.** Orca starts Claude through the same `--agent claude` path; if the screen shows a trust or permission dialog, answer it from the screen as for Pi's chooser and confirm work resumed.
- **New session:** send `/new` (Claude shows it as `/clear`) with `orca terminal send --terminal <handle> --text "/new" --enter`, then send the full brief.
- **Compact:** send `/compact [what to preserve]` the same way, then send the follow-up request.
- **Carry-over** takes three steps:
  1. Send `/handoff <follow-up focus>`; the worker writes a handoff document to `$TMPDIR` and prints its path.
  2. Take only the path from the worker's output; do not read the document yourself.
  3. Send `/new`, then prompt the worker to read that path and continue with the follow-up request.
