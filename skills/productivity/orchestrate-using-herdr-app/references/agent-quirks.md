# Agent quirks

Read Every kind, the section for the agent kind you start or read, and Hibernated or finished workers. `<name>` is the worker's `hc` terminal name.

## Hibernated or finished workers

Workers start without `hibernate=ok`. After a task settles and its resources are reaped, `reap-worker.sh --keep-agent` sets `hc label <name> hibernate=ok`; only then may herdr-app's Focus sidebar hibernate a Pi or Claude worker that stays idle for 5 minutes, to free the host. It exits the agent, and the terminal finishes with the labels `hibernated=<ms>` and `resume=<line>`. Its exit is that hibernation, not a crash. A worker that finished another way (a restart: `stopped_by_restart`) has no `hibernated` label but keeps the `resume=<line>` label the sidebar set while it ran. A `hc send` to either fails with exit 11 (finished).

Send every re-instruction with `scripts/send-reinstruction.sh <name> <worktree> <bead> <text>`. It writes the full text as an `event=re-instructed agent=<name>` comment and sends a pointer to the latest comment with that exact agent. Ordinary live re-instructions do not reload Pi skills. After `/new`, pass `--new-context` to repeat skill activation; revival goes through startup's bootstrap. It sends to a live worker and revives a finished one from its `resume` label (`start-worker.sh --resume` with the same name, worktree, kind, browser namespace, and session, launched beside the finished terminal, which `hc rm` removes by address only after the replacement started; `--check` first confirms the agent program is on PATH). For `r-` reviewer targets, pass the new claimed review bead and add `--last-reviewed <commit>` on every re-instruction: the script requires an ancestor of the worktree's HEAD and stores the resolved incremental scope in the comment on that review bead, explicitly superseding earlier scope, before live delivery or revival; exit 3 rejects a missing or invalid base. Initial whole-branch review uses `start-worker.sh` instead. Exit 2 means the worker is blocked on a dialog, has no resumable session, or its terminal vanished; read its screen.

## Every kind

- **Slash commands go as keys.** `hc send` from an `hc` terminal wraps the text in `<hc from="…">…</hc>`, so the agent reads a slash command as chat and does not run it. Type every slash command with `scripts/type-command.sh <name> /new`, which presses one key per character (`space` between words, `shift+<letter>` for capitals) and then `enter`. It exits 1 without typing when the text holds a character `hc keys` has no key for (for example `_`, `!`, `$`); never run `hc keys <name> "/new" enter` as one string or hide its errors. Confirm the result on screen (Pi: `New session started`, or the status line's `ctx` drops). Work instructions go through `send-reinstruction.sh`.

## pi

- **Bootstrap prompts end with `ulw`** as the last token; it puts the worker in ultrawork mode so it runs to a finished result. Ordinary live re-instructions carry no skill triggers or `ulw`.
- **Skills by prompt.** Load a skill in the worker with `$skill:<name>` in the prompt. `start-worker.sh` sends `$skill:orchestrated-worker`, literal `$skill:<name>` tokens from the assigned bead's design and final `ulw`, with `bd prime` and `bd show <bead>` instructions. Tokens only in the bead would not activate Pi skills.
- **Status races startup.** Right after launch, `hc wait` can return `idle` at turn 0 before Pi submits the argv prompt; `scripts/start-worker.sh` confirms by turn count instead.
- **Approval dialogs.** Pi stops on a numbered chooser (tool approval, a question with options) and its status can read `blocked` or `idle` while the dialog is up. Read it with `hc read <name>`, answer with `hc keys <name> <digit> enter`, and confirm with `hc get <name>` that the status returns to `working`. `hc send` refuses a `blocked` terminal; never use `--force` to bypass a permission decision. Digits reach only numbered options: `Other…` has none, an out-of-range digit is ignored, and the following Enter confirms the highlighted row, which starts on the recommended option (pi-config `extensions/ask/state.ts`). To give your own answer, `hc interrupt <name>` and send it as a follow-up. After every answer, read the screen's `answered` line and correct a wrong answer in the same turn.
- **Interrupt:** `hc interrupt <name>` stops the current turn; the session and its context survive.
- **Blocked goal:** a Pi worker that marked its goal blocked shows `Goal blocked (/goal resume)`, and ordinary messages never resume it. When a follow-up clears that blocker, first type `/goal resume` with `scripts/type-command.sh <name> "/goal resume"` and confirm the status line no longer shows `Goal blocked`, then send the follow-up.
- **New session:** type `/new` with `scripts/type-command.sh <name> /new`, then use `send-reinstruction.sh <name> <worktree> <bead> <text> --new-context` to repeat the standing-contract/prime/show bootstrap and Pi skill activation. The terminal name survives; the session starts empty.
- **New session bug:** an unknown Pi bug sometimes makes `/new` exit Pi, which finishes the terminal. If `hc get <name>` shows `finished`, `hc rm <name>`, restart with `scripts/start-worker.sh <name> <worktree> <bead>` carrying the bead bootstrap, and confirm it is `working`. Exiting is a bug, not the normal `/new` behavior.
- **Crash:** Pi can exit on `uncaughtException` (`AbortError: The operation was aborted`) mid-turn; the watcher reports `settled: exited`. Revive it with `scripts/send-reinstruction.sh` and the same re-instruction, opened with a line that the previous session crashed so it checks `git status` for work already done.
- **Compact:** type `/compact [what to preserve]` with `scripts/type-command.sh <name> "/compact …"`; status can read `done` while compaction runs, and a message queued during compaction is dropped. Send the follow-up only once `hc read <name>` no longer shows "Compacting".
- **Handoff:** type `/handoff <follow-up request> ulw` with `scripts/type-command.sh <name> "/handoff …"`. Pi summarizes into a new session and **preloads** the summary plus request in the editor without submitting it; once the agent is `idle`, submit with `hc keys <name> enter`. The terminal name survives.
- **Peer orchestrator** ([handoff.md](handoff.md)): argv `["pi"]`; with flags, the first prompt opens with `$skill:orchestrate-using-herdr-app <flags>`; every peer first prompt ends with `ulw`.
- **Reviewer on another model** ([supervise.md](supervise.md) step 2): start it with `scripts/start-worker.sh r-<stem> <worktree> <bead>`, then `hc interrupt r-<stem>`, type `/mode-model <provider/model>` with `scripts/type-command.sh r-<stem> "/mode-model …"`, confirm the status line shows that model, and `hc send` the same first prompt (standing skill, `bd prime`, `bd show <bead>`, review bead design skill tokens, final `ulw`).

## claude

Worker and reviewer prompts tell Claude to load `orchestrated-worker`, run `bd prime` and `bd show <bead>`, and work that bead. For reviews use the plain prompt, never the bundled `/code-review`: it takes a target, not spec and scope instructions. The `orch-context` label restores the standing contract, current bead and latest re-instruction for `$BEADS_ACTOR` after compaction.

- **Folder trust.** In a folder Claude has not trusted (every new worktree), startup blocks on a "trust this folder" dialog and `start-worker.sh` exits 2 with `blocked`. Read it with `hc read <name>`, answer it yourself with `hc keys` (select "Yes, I trust this folder" for the assigned worktree), then confirm the agent is `working` on the bead; if it is `idle` at turn 0, send the bead bootstrap pointer.
- **New session:** type `/new` with `scripts/type-command.sh <name> /new` (Claude shows it as `/clear`), then use `send-reinstruction.sh` with the bead and `--new-context` to repeat the standing-contract/prime/show bootstrap. The terminal name survives.
- **Compact:** type `/compact [what to preserve]` with `scripts/type-command.sh <name> "/compact …"`, then send the follow-up request.
- **Handoff** takes three steps:
  1. Type `/handoff <follow-up focus>` with `scripts/type-command.sh <name> "/handoff …"`; the worker writes a handoff document to `$TMPDIR` and prints its path.
  2. Take only the path from the worker's output; do not read the document yourself.
  3. Type `/new` with `scripts/type-command.sh <name> /new`, then prompt the worker to read that path and continue with the follow-up request.
- **Peer orchestrator** ([handoff.md](handoff.md)): argv `["claude"]`; with flags, the first prompt opens with `/orchestrate-using-herdr-app <flags>`. Expect the folder-trust dialog in an untrusted folder.

## codex

Worker and reviewer prompts tell Codex to load `orchestrated-worker`, run `bd prime` and `bd show <bead>`, and work that bead. Codex has no compaction recovery hook; existing follow-up `wf-494` tracks it.

- `start-worker.sh --kind codex` adds `--no-daemon`; without it, Codex runs its commands outside `hc`.

## agy

Worker and reviewer prompts tell agy to load `orchestrated-worker`, run `bd prime` and `bd show <bead>`, and work that bead. agy always runs a Gemini model. It has no compaction recovery hook.

- **Launch:** `start-worker.sh --kind agy` passes the prompt through `-i`, so agy stays interactive; resume is `--conversation=<id>`. The herdr-app resume hook labels `resume=agy --conversation=<id>`.
- **Folder trust.** In a folder agy has not trusted, startup blocks on "Antigravity CLI requires permission to read, edit, and execute files here" and `start-worker.sh` exits 2 with `blocked`. Select "Yes, I trust this folder" for the assigned worktree with `hc keys <name> enter`, then confirm the agent is `working` on the bead; if it is `idle` at turn 0, send the bead bootstrap pointer.

## copilot

Worker and reviewer prompts tell Copilot to load `orchestrated-worker`, run `bd prime` and `bd show <bead>`, and work that bead. Copilot can run either family. It has no compaction recovery hook.

- **Launch:** `start-worker.sh --kind copilot` passes the prompt through `-i`; resume is `--resume=<id>`. The herdr-app resume hook labels `resume=copilot --resume=<id>`.
- **Reviewer on another model** ([supervise.md](supervise.md) step 2): read the model on the status line with `hc read r-<stem>`. When it is the worker's family, `hc interrupt r-<stem>`, type `/model` with `scripts/type-command.sh r-<stem> /model`, pick a model of the other family, confirm the status line shows it, and send the bead bootstrap pointer.
