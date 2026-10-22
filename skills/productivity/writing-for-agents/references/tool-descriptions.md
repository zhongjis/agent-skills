# Tool descriptions

The tool branch of [`writing-for-agents`](../SKILL.md): a tool's description, parameter descriptions, prompt snippets and guidelines, and any prompt block the tool's extension injects. Everything else about writing it is the universal reference in `SKILL.md`.

## Self-scope

A tool description is the context pointer the agent reads to decide when to call the tool. Write it **self-scoped**: what this tool does, its inputs and outputs, its quirks, and its limits.

- Leave selection between tools to the system, mode, and agent instructions: which tool comes first, when to switch, and what to fall back to. A tool cannot know which sibling tools are loaded, so a line naming them ("prefer over `grep`", "fall back to `rg`") goes stale when the tool set changes and contradicts the instruction layer that owns routing.
- State limits as facts about this tool ("returns positions, not source"; "may miss generated names"); the instruction layer turns them into routing.
- Name sibling tools of the same extension freely: they ship and change together.
