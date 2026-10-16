# Tracking (`--track`)

1. **Resolve the tracker.** A supplied issue URL selects it by host (`linear.app`, a Jira `/browse/KEY-N` URL, `github.com/<owner>/<repo>/issues/N`); otherwise a tracker the user names; otherwise the repository convention (AGENTS.md, PR templates, issue URLs in PR or commit history). A bare key like `ENG-42` is ambiguous between Linear and Jira. If unresolved, ask one precise question and stop before any side effect. Access the tracker through its skill or CLI (`linear`, `jira-integration`, `gh`).
2. **Establish the ticket.** Reuse a supplied or existing ticket as is. Otherwise create one from the spec in tracker-native markup (Jira wiki markup; Markdown for Linear and GitHub). The ticket is authoritative for scope. Record its identifier and URL.
3. **Name from it.** Worktree basename and agent name use `<issue-id>-<slug>` (see [single.md](single.md)).
4. **Close out.** When a unit settles, comment on its ticket in tracker-native markup with the result, PR URL, and verification evidence, or the exact blocker.
