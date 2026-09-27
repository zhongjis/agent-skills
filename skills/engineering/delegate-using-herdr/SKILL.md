---
name: delegate-using-herdr
description: Reuse or create a Linear issue and dispatch a matching Herdr worker in an isolated worktree.
disable-model-invocation: true
---

# Delegate using Herdr

Reuse or create a Linear issue and hand it to a matching Herdr agent. Invoking this skill authorizes issue creation and dispatch once the required inputs agree; do not add a blanket confirmation gate.

## Workflow

1. **Preflight** — Run exactly:
   ```bash
   command -v herdr >/dev/null && test "${HERDR_ENV:-}" = 1
   ```
   If it fails, hard stop. Do not install, diagnose, troubleshoot, fall back, or create a Linear issue. **Complete** when the command succeeds.

2. **Establish the handoff contract** — From the latest explicit user intent, draft a concise contract covering actor, trigger, timing, and outcome; constraints; verification; and requested external deliverables. If the user explicitly supplied an existing Linear issue, inspect it; also draft the proposed worker prompt enough to compare all three. If user intent, issue, and prompt materially disagree, ask one precise question naming the conflicting field and stop before any Linear mutation, worktree creation, or dispatch. When they agree, do not ask for routine confirmation. **Complete** when the contract agrees or one precise question has stopped the workflow.

3. **Establish the issue** — Reuse a user-supplied existing Linear issue; do not create or rewrite it. Otherwise, create one from the agreed contract. Record the issue identifier and URL. **Complete** when both are available.

4. **Read current Herdr mechanics and resolve the source** — Run `herdr --skill` and use its current guidance (and installed help where needed) for pane inspection, worktree creation, agent startup, and prompting. Detect the current pane's agent kind. Before creation, use `herdr worktree list` with the current cwd/workspace and parse the returned `source_workspace_id` or `source_checkout_path`. Create from that repository parent source, never a linked-worktree cwd. If source resolution fails, stop before worktree creation. **Complete** when the current agent kind and parent source are known.

5. **Create the worker workspace** — From the resolved repository parent source, create a Herdr worktree and branch named from the Linear identifier (with a concise task slug if useful), without moving the user's focus. Record the returned worktree path, workspace, pane, and branch. **Complete** when Herdr returns the new workspace details.

6. **Start the worker** — In the returned worktree root pane, start an agent of the same kind as the current pane. Give it a unique name derived from the Linear identifier. **Complete** when Herdr reports the agent name and pane.

7. **Dispatch** — Submit one bounded worker prompt containing:
   - the Linear issue identifier and URL;
   - the agreed handoff contract: actor, trigger, timing, outcome, constraints, verification, and requested external deliverables; and
   - an instruction to work only in the assigned worktree and report blockers rather than expanding scope.

   Preserve every requested external deliverable, such as updating the Linear issue or creating a PR, in the worker prompt. Do not perform those deliverables, monitor the worker, or integrate results yourself. Confirm that Herdr accepted the prompt. **Complete** when acceptance is confirmed.

8. **Hand off** — Report the issue URL, branch, worktree path, workspace, pane, and agent name, then stop. Leave the worker and worktree running. Do not monitor, collect results, integrate, create a PR, clean up, or perform extra checkout or environment validation.

## Bounded failures

- **Linear creation fails or is uncertain:** report the failure and stop; do not dispatch or blindly retry issue creation.
- **Worktree-source resolution fails:** report the failure and stop before creation.
- **Worktree creation or agent startup fails:** report the Linear issue and any workspace details already returned, then stop. Do not clean up or retry an uncertain side effect.
- **Prompt submission is not confirmed:** report it as uncertain and stop. Do not submit the prompt again, monitor the worker, or assume it was not delivered.
