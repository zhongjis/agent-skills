---
name: delegate-using-herdr
description: Delegate an issue-tracker task (Linear, Jira, GitHub Issues) through Herdr; add `--review` for local Claude side-pane review and `--auto` for fail-closed worker delivery.
disable-model-invocation: true
---

# Delegate using Herdr

Reuse or create an issue in the resolved tracker and hand it to a matching Herdr agent. Invoking this skill authorizes issue creation and dispatch once the required inputs agree; do not add a blanket confirmation gate. By default, the parent immediately hands off and stops. Only an explicit `--auto` authorizes the delegated worker's remote delivery side effects; it does not authorize the parent to monitor or integrate.

## Workflow

1. **Preflight** — Run exactly:
   ```bash
   command -v herdr >/dev/null && test "${HERDR_ENV:-}" = 1
   ```
   If it fails, hard stop. Do not install, diagnose, troubleshoot, fall back, or create an issue. **Complete** when the command succeeds.

2. **Resolve the tracker** — Resolve in this order. A supplied issue URL selects the tracker from its host (for example `linear.app`, a Jira `/browse/KEY-N` URL, `github.com/<owner>/<repo>/issues/N`); otherwise use a tracker the user explicitly names; otherwise use the repository convention (for example AGENTS.md, PR templates, tracker issue URLs in PR or commit history). A bare key such as `ENG-42` is ambiguous between Linear and Jira, so it alone never selects a tracker. If still unresolved, ask one precise question naming the tracker choice and stop before any tracker mutation, worktree creation, or dispatch. Access the tracker through its available skill or CLI (for example `linear`, `jira-integration`, `gh`); if access fails, report and stop before those same side effects. **Complete** when the tracker and its access path are known, or one precise question has stopped the workflow.

3. **Establish the handoff contract** — From the latest explicit user intent, draft a concise contract covering actor, trigger, timing, and outcome; constraints; verification; and requested external deliverables. Treat `--auto` as an explicit authorization for the worker's remote delivery lifecycle in [Auto worker delivery](references/auto-delivery.md); without it, retain the immediate-handoff mode. Record whether `--review` requires the worker's [Local Claude review](references/review.md), independently of `--auto`. If the user explicitly supplied an existing issue, inspect it; also draft the proposed worker prompt enough to compare all three. If user intent, issue, and prompt materially disagree, ask one precise question naming the conflicting field and stop before any tracker mutation, worktree creation, or dispatch. When they agree, do not ask for routine confirmation. **Complete** when the contract agrees and the mode is recorded, or one precise question has stopped the workflow.

4. **Establish the issue** — Reuse a user-supplied existing issue in the resolved tracker; do not create or rewrite it. Otherwise, create one in the resolved tracker from the agreed contract using tracker-native markup (Jira wiki markup; Markdown for Linear and GitHub). Record the issue identifier and URL. **Complete** when both are available.

5. **Read current Herdr mechanics and resolve the source** — Run `herdr --skill` and use its current guidance (and installed help where needed) for pane inspection, worktree creation, agent startup, and prompting. Detect the current pane's agent kind. Before creation, use `herdr worktree list` with the current cwd/workspace and parse the returned `source_workspace_id` or `source_checkout_path`. Create from that repository parent source, never a linked-worktree cwd. If source resolution fails, stop before worktree creation. **Complete** when the current agent kind and parent source are known.

6. **Create the worker workspace** — From the resolved repository parent source, preserve the repository's branch convention independently (for example, `fix/a2a-140-conversation-feedback`). Set the worktree directory basename to lowercase `<issue-id>-<concise-work-slug>` (for example, `a2a-140-conversation-feedback`); when the identifier is purely numeric (GitHub `#123`), prefix it with `gh-` (for example, `gh-123-conversation-feedback`) so the basename and agent-name stem start with a letter. Use `herdr worktree create --path` when needed to decouple it from the branch, and `--label` with a friendly workspace label (for example, `A2A-140 Conversation feedback`). Keep the current Herdr session and new workspace's default tab label unchanged (typically `default` and `1`); do not rename either. Create without moving the user's focus. Record the returned worktree path, workspace, pane, and branch. **Complete** when Herdr returns the new workspace details.

7. **Start the worker** — In the returned worktree root pane, start an agent of the same kind as the current pane. Derive its live name from the same issue-and-slug stem, including the `gh-` prefix when the identifier is numeric, using lowercase letters, digits, and hyphens; it must match Herdr `[a-z][a-z0-9_-]{0,31}` and be unique among live agents. Shorten the work slug first to fit 32 characters; on a collision, shorten further as needed and add a short hyphenated discriminator, preserving the issue identifier when possible. **Complete** when Herdr reports the agent name and pane.

8. **Dispatch** — Submit one bounded worker prompt containing:
   - the tracker, issue identifier, and URL;
   - the agreed handoff contract: actor, trigger, timing, outcome, constraints, verification, and requested external deliverables; and
   - an instruction to work only in the assigned worktree and report blockers rather than expanding scope.

   With `--review`, read [references/review.md](references/review.md) and include its complete worker contract, not just the file path; the same-kind main worker owns it. Independently, with `--auto`, read [references/auto-delivery.md](references/auto-delivery.md) and include its complete worker contract, stating that the worker, not the parent, owns every listed side effect and decision. Load only selected references before dispatch. With both flags, include review before auto delivery: local review precedes publication and never replaces remote reviewer or current-SHA gates. Without `--auto`, preserve every requested external deliverable, such as updating the issue or creating a PR, in the worker prompt without adding the auto lifecycle. Do not perform those deliverables, monitor the worker, or integrate results yourself. When the worker is a Pi agent, always append the literal keyword `ulw` at the end of the complete worker prompt, after all optional contracts. Confirm that Herdr accepted the prompt. **Complete** when acceptance is confirmed.

9. **Hand off** — Report the issue URL, branch, worktree path, workspace, pane, agent name, and selected mode, then stop. Leave the worker and worktree running. Do not monitor, collect results, integrate, create a PR, clean up, or perform extra checkout or environment validation. **Complete** when that handoff report is sent.

## Bounded failures

- **Tracker resolution or access fails:** ask one precise question or report the failure, then stop before any tracker mutation, worktree creation, or dispatch.
- **Issue creation fails or is uncertain:** report the failure and stop; do not dispatch or blindly retry issue creation.
- **Worktree-source resolution fails:** report the failure and stop before creation.
- **Worktree creation or agent startup fails:** report the issue and any workspace details already returned, then stop. Do not clean up or retry an uncertain side effect.
- **Prompt submission is not confirmed:** report it as uncertain and stop. Do not submit the prompt again, monitor the worker, or assume it was not delivered.
