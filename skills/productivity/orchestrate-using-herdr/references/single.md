# One task

1. **Spec the work.** Write the spec in the `to-spec` template shape from the agreed conversation: problem, solution, decisions, testing decisions, out of scope. With `--track`, the spec becomes the ticket ([track.md](track.md)); otherwise it goes into the brief. If a material user decision is missing, ask one precise question and stop before any side effect; routine gaps you resolve by inspection, with no confirmation gate. **Done when** the spec and any binding agreed details are written down.

2. **Resolve the source.** Run `herdr worktree list` from the current cwd/workspace and read `source_workspace_id` or `source_checkout_path`. Create from that parent source, or from the current worktree when the user asked. If resolution fails, stop before creation. **Done when** the source is known.

3. **Create the worktree.** Keep the repository's branch convention. Name the worktree directory lowercase `<id>-<slug>` (`a2a-140-cache-keys`; prefix numeric IDs with `gh-`), using `--path` to decouple it from the branch, and give a friendly `--label` (`A2A-140 Cache keys`). Without `--track`, use a concise slug alone. Create with `--no-focus`. **Done when** Herdr returns the worktree path, workspace, pane, and branch.

4. **Start the worker** in the returned root pane, same kind unless the user named one. Name it from the same stem, shortened to fit 32 characters; on a collision, add a short hyphenated discriminator. **Done when** Herdr reports the agent name and pane.

5. **Dispatch one brief** filled from the spec per [delegation-contract.md](delegation-contract.md). **Done when** Herdr confirms the prompt was accepted.

6. **Hand off or supervise** per the mode in `SKILL.md`.

## Failures

- Ticket creation fails or is uncertain: report and stop; do not dispatch or retry blindly.
- Worktree creation or agent startup fails: report the details already returned and stop; do not clean up or retry an uncertain side effect.
- Prompt acceptance is unconfirmed: report it as uncertain; do not resubmit.
