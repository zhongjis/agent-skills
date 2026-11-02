# Agent quirks

T3 Code runs every worker kind behind the same thread tools; read only the section for the kind you launch.

## All kinds

- **Approvals.** A worker that needs a tool approval waits in its thread; T3 lets only the user approve it. Report the task and the thread link to the user, then confirm the run continues.

## pi

- **Prompts end with `ulw`** as the last token, after every contract section; it puts the worker in ultrawork mode so it runs to a finished result.
- **Skills by prompt.** Load a skill in the worker with `$skill:<name>` in the prompt.
- **Compact:** send `/compact [what to preserve]` with `t3_thread_send`; T3 runs Pi's own compaction. Send the follow-up once that run has ended.

## claude

- **Compact:** T3 compacts idle Claude sessions on its own when the setting is enabled; for a deliberate context change, use Handoff ([worker-context.md](worker-context.md)).
