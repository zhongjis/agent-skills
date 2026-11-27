# Code review

Applies [SKILL.md](../SKILL.md) to a code change.

- **Method:** reviewers run the `axis-review` skill; name it in the brief.
- **Target:** a commit range with its head commit. The first round covers the whole branch from its base; a later round covers `<last-reviewed>..<head>`.
- **Location:** `file:line` for every finding.
- **Session:** later rounds stay in the same reviewer session while it still runs an allowed family.
- **Visual target:** include the target and the author's before/after screenshots, and ask for visual conformance findings.
- **Cap:** the whole-branch round plus at most **1** incremental round.
