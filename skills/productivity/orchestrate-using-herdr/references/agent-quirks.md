# Agent quirks

Read only the section for the agent kind you start or read.

## pi

- **Prompts end with `ulw`** as the last token, after every contract section; it puts the worker in ultrawork mode so it runs to a finished result.
- **Alt screen.** pi renders on the terminal's alt screen: read it with `herdr agent read <name> --source visible`; `recent-unwrapped` returns empty.
- **Skills by prompt.** Load a skill in the worker with `$skill:<name>` in the prompt (shell-escape the `$`).
- **New session:** prompt `/new`, then send the full brief. The Herdr agent name survives; the session starts empty.
- **Handoff:** prompt `/handoff <follow-up request> ulw`. Pi summarizes into a new session and **preloads** the summary plus request in the editor without submitting it; once the agent is `idle`, submit with `herdr agent send-keys <name> enter`. The agent name survives.

## claude

- **Folder trust.** In a folder Claude has not trusted (every new worktree), startup blocks on a "trust this folder" dialog and `agent start` returns `agent_not_ready`. Answer it yourself (select "Yes, I trust this folder" for the assigned worktree), then confirm the agent is `idle`.
- **New session:** prompt `/new` (Claude shows it as `/clear`), then send the full brief. The Herdr agent name survives.
- **Handoff** is a two-step skill flow:
  1. Prompt `/handoff <follow-up focus>`; the worker writes a handoff document to `$TMPDIR` and prints its path.
  2. Take only the path from the worker's output; do not read the document yourself.
  3. Prompt `/new`, then prompt the worker to read that path and continue with the follow-up request.
