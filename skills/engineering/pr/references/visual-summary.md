# Visual summaries

Use this reference only when a visual makes the PR change clearer. Choose the smallest useful view; omit a visual when concise prose already explains the change.

## Compact taxonomy

- **Flow:** pseudocode or a call tree for behavior or order.
- **Interaction:** a small Mermaid diagram for participants or data movement.
- **Structure:** a shallow file tree for ownership or layout.
- **Delta:** a diff sketch for a localized change.

Show only the calls, files, states, or boundaries needed for the reviewer’s decision. Put the visual beside the sentence it supports.

### File-tree example

```text
src/
├── commands/       # parses user actions
├── sessions/       # owns session state
└── transport/      # sends API requests
```

### Diff-sketch example

```diff
 submitForm
   createSession
     persistPrompt
+    expandSkillMention
     launchAgent
```

This reference adapts the visual catalog in [mattpocock/skills `pr`](https://github.com/mattpocock/skills/blob/main/skills/in-progress/pr/SKILL.md). See [`../CREDITS.md`](../CREDITS.md) and [`../LICENSE`](../LICENSE).
