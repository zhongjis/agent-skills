# Agent quirks

Read only the section for the agent kind you start or read, plus Hibernated workers. `<name>` is the worker's `hc` terminal name.

## Hibernated workers

herdr-app's Focus sidebar hibernates a Pi or Claude worker that stays idle for 15 minutes, to free the host. It exits the agent, and the terminal finishes with the labels `hibernated=<ms>` and `resume=<line>`. Its exit notice is that hibernation, not a crash. A `hc send` to it fails with exit 11 (finished).

Before you send a hibernated worker more work, revive it:

1. Read the session id from the `resume` label in `hc get <name> --json`: the value after `--session` (Pi) or `--resume` (Claude).
2. `hc rm <name>`.
3. `scripts/start-worker.sh <name> <worktree> <brief-file> --resume <session> [--kind <kind>]`, with the follow-up as the brief. It keeps the name, worktree, browser namespace, and session.

## pi

- **Prompts end with `ulw`** as the last token, after every contract section; it puts the worker in ultrawork mode so it runs to a finished result.
- **Skills by prompt.** Load a skill in the worker with `$skill:<name>` in the prompt.
- **Status races startup.** Right after launch, `hc wait` can return `idle` at turn 0 before Pi submits the argv brief; `scripts/start-worker.sh` confirms by turn count instead.
- **Approval dialogs.** Pi stops on a numbered chooser (tool approval, a question with options) and its status can read `blocked` or `idle` while the dialog is up. Read it with `hc read <name>`, answer with `hc keys <name> <digit> enter`, and confirm with `hc get <name>` that the status returns to `working`. `hc send` refuses a `blocked` terminal; never use `--force` to bypass a permission decision.
- **Interrupt:** `hc interrupt <name>` stops the current turn; the session and its context survive.
- **New session:** `hc send <name> /new`, then send the full brief. The terminal name survives; the session starts empty.
- **New session bug:** an unknown Pi bug sometimes makes `/new` exit Pi, which finishes the terminal. If `hc get <name>` shows `finished`, `hc rm <name>`, restart with `scripts/start-worker.sh <name> <worktree> <brief-file>` carrying the full brief, and confirm it is `working`. Exiting is a bug, not the normal `/new` behavior.
- **Compact:** `hc send <name> "/compact [what to preserve]"`; status can read `done` while compaction runs, and a message queued during compaction is dropped. Send the follow-up only once `hc read <name>` no longer shows "Compacting".
- **Handoff:** `hc send <name> "/handoff <follow-up request> ulw"`. Pi summarizes into a new session and **preloads** the summary plus request in the editor without submitting it; once the agent is `idle`, submit with `hc keys <name> enter`. The terminal name survives.

## claude

- **Folder trust.** In a folder Claude has not trusted (every new worktree), startup blocks on a "trust this folder" dialog and `start-worker.sh` exits 2 with `blocked`. Read it with `hc read <name>`, answer it yourself with `hc keys` (select "Yes, I trust this folder" for the assigned worktree), then confirm the agent is `working` on the brief; if it is `idle` at turn 0, send the brief with `hc send`.
- **New session:** `hc send <name> /new` (Claude shows it as `/clear`), then send the full brief. The terminal name survives.
- **Compact:** `hc send <name> "/compact [what to preserve]"`, then send the follow-up request.
- **Handoff** takes three steps:
  1. `hc send <name> "/handoff <follow-up focus>"`; the worker writes a handoff document to `$TMPDIR` and prints its path.
  2. Take only the path from the worker's output; do not read the document yourself.
  3. `hc send <name> /new`, then prompt the worker to read that path and continue with the follow-up request.

## codex

- `start-worker.sh --kind codex` adds `--no-daemon`; without it, Codex runs its commands outside `hc`.
