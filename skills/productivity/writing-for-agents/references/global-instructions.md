# Global instructions

The global `AGENTS.md` / `CLAUDE.md` branch of [`writing-for-agents`](../SKILL.md): user/environment-scoped instructions for how agents work everywhere, including instruction principles and conventions. Everything else about writing it is the universal reference in `SKILL.md`.

## Every session, every repo

Global text loads in every session of every repository, so it carries the highest context load of any document. A line earns its place only when it holds across all of them.

- A rule that holds only in some contexts states its condition in its first words ("In enterprise codebases, …"), so the agent skips it fast where it does not apply.
