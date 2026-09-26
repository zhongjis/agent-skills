---
name: delegate-using-herdr
description: Create a Linear issue and dispatch a matching Herdr worker in an isolated worktree.
disable-model-invocation: true
---

# Delegate using Herdr

Create a Linear issue and hand it to a matching Herdr agent. Invoking this skill authorizes issue creation and dispatch once the required inputs exist; do not ask again for blanket confirmation.

## Workflow

1. **Preflight** — Run exactly:
   ```bash
   command -v herdr >/dev/null && test "${HERDR_ENV:-}" = 1
   ```
   If it fails, hard stop. Do not install, diagnose, troubleshoot, fall back, or create a Linear issue. **Complete** when the command succeeds.

2. **Establish the issue** — Infer the Linear team, title, and material task scope from the user's context. Ask only if the team or material scope is missing. Use the available Linear skill or tool to create the issue, then record its identifier and URL. **Complete** when both are available.

3. **Read current Herdr mechanics** — Run `herdr --skill` and use its current guidance (and installed help where needed) for pane inspection, worktree creation, agent startup, and prompting. Do not cache or invent CLI syntax. Detect the current pane's agent kind. **Complete** when the current agent kind is known.

4. **Create the worker workspace** — Create a Herdr worktree and branch named from the Linear identifier (with a concise task slug if useful), without moving the user's focus. Record the returned worktree path, workspace, pane, and branch. **Complete** when Herdr returns the new workspace details.

5. **Start the worker** — In the returned worktree root pane, start an agent of the same kind as the current pane. Give it a unique name derived from the Linear identifier. **Complete** when Herdr reports the agent name and pane.

6. **Dispatch** — Submit one bounded worker prompt containing:
   - the Linear issue identifier and URL;
   - the task context, constraints, and expected outcome;
   - required verification; and
   - an instruction to work only in the assigned worktree and report blockers rather than expanding scope.

   Confirm that Herdr accepted the prompt. **Complete** when acceptance is confirmed.

7. **Hand off** — Report the issue URL, branch, worktree path, workspace, pane, and agent name, then stop. Leave the worker and worktree running. Do not monitor, collect results, integrate, create a PR, clean up, or perform extra checkout or environment validation.

## Bounded failures

- **Linear creation fails or is uncertain:** report the failure and stop; do not dispatch or blindly retry issue creation.
- **Worktree creation or agent startup fails:** report the Linear issue and any workspace details already returned, then stop. Do not clean up or retry an uncertain side effect.
- **Prompt submission is not confirmed:** report it as uncertain and stop. Do not submit the prompt again, monitor the worker, or assume it was not delivered.
