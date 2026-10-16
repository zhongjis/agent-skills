# Agent quirks

Read only the section for the agent kind you start or read.

## pi

- **Prompts end with `ulw`** as the last token, after every contract section; it puts the worker in ultrawork mode so it runs to a finished result.
- **Alt screen.** pi renders on the terminal's alt screen: read it with `herdr agent read <name> --source visible`; `recent-unwrapped` returns empty.
- **Skills by prompt.** Load a skill in the worker with `$skill:<name>` in the prompt (shell-escape the `$`).
