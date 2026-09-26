---
name: gh
description: Use GitHub CLI (`gh`) for repositories, projects, gists, codespaces, organizations, and extensions; issue and pull-request lifecycles; Actions and releases; REST or GraphQL operations; or attaching existing files to GitHub. Includes stacked PRs, issue relationships, CI status, artifacts, secrets, and reviews. Use `before-and-after` instead for polished UI comparison or preview media.
adaptedFrom:
  - "https://github.com/github/awesome-copilot/blob/main/skills/gh-cli/SKILL.md"
---

# GitHub CLI (gh)

## Quick Reference

| Task                    | Command                                           |
| ----------------------- | ------------------------------------------------- |
| Create PR               | `gh pr create --title "..." --body "..."`         |
| Attach existing image    | `gh pr edit 123 --attach 'diagram.png#Architecture diagram'` ([requirements](references/attachments.md)) [1] |
| List open PRs           | `gh pr list`                                      |
| View PR                 | `gh pr view 123`                                  |
| Merge PR                | `gh pr merge 123 --squash --delete-branch`        |
| Checkout PR             | `gh pr checkout 123`                              |
| Create issue            | `gh issue create --title "..." --body "..."`      |
| List issues             | `gh issue list`                                   |
| Close issue             | `gh issue close 123 --comment "Fixed in #456"`   |
| Create issue from file  | `gh issue create --title "..." --body-file issue.md` |
| Add issue label         | `gh issue edit 123 --add-label label-name` |
| Link sub-issue          | `gh api graphql -f query='mutation...' -f issueId=... -f subIssueId=...` |
| Link blocked-by         | `gh api graphql -f query='mutation...' -f issueId=... -f blockingIssueId=...` |
| Clone repo              | `gh repo clone owner/repo`                        |
| Create repo             | `gh repo create my-repo --public`                 |
| List workflow runs      | `gh run list`                                     |
| Watch workflow          | `gh run watch 123456789`                          |
| Run workflow            | `gh workflow run ci.yml`                          |
| Download artifacts      | `gh run download 123456789`                       |
| Create release          | `gh release create v1.0.0 --notes "..."`          |
| Set secret              | `gh secret set MY_SECRET`                         |
| API request             | `gh api /user`                                    |

## Detailed References

For comprehensive command documentation:

- [Authentication](references/auth.md) - Login, tokens, credentials, environment variables
- [Repositories](references/repos.md) - Create, clone, fork, sync, browse, edit
- [Issues](references/issues.md) - Create, list, edit, close, comment, labels
- [Pull Requests](references/prs.md) - Create, review, merge, checkout, diff
- [Stacked Pull Requests](references/stacked-prs.md) - Create, submit, update, and merge dependent PRs
- [Attachments](references/attachments.md) - Attach existing files to PRs or comments; use `before-and-after` for polished UI comparison or preview media
- [Actions](references/actions.md) - Workflows, runs, caches, secrets, variables
- [Releases](references/releases.md) - Create, upload, download, verify
- [Projects](references/projects.md) - Create, manage items, fields
- [Codespaces](references/codespaces.md) - Create, connect, manage
- [API](references/api.md) - REST and GraphQL requests
- [Misc](references/misc.md) - Gists, orgs, search, labels, keys, extensions, aliases

## Common Workflows

### Publish Issue Tree

> Use this for generic GitHub execution mechanics. Planning skills decide what issues should exist; this workflow creates, links, and verifies them.

```bash
# 1. Confirm target repo and available labels
gh repo view --json nameWithOwner,url
gh label list --limit 200 --json name

# 2. Fetch parent issue node id when linking children
gh issue view 123 --json id,number,title,url

# 3. Create children in dependency order, using files for long Markdown bodies
gh issue create --title "Child issue title" --body-file child.md --label label-name

# 4. Capture node ids for relationship mutations
gh issue view 124 --json id,number,title,url

# 5. Link sub-issues / blockers with GraphQL
gh api graphql -f query='mutation($issueId: ID!, $subIssueId: ID!) { addSubIssue(input: { issueId: $issueId, subIssueId: $subIssueId }) { issue { id } subIssue { id } } }' -f issueId=PARENT_ID -f subIssueId=CHILD_ID
gh api graphql -f query='mutation($issueId: ID!, $blockingIssueId: ID!) { addBlockedBy(input: { issueId: $issueId, blockingIssueId: $blockingIssueId }) { issue { id } blockingIssue { id } } }' -f issueId=CHILD_ID -f blockingIssueId=BLOCKER_ID

# 6. Read back every affected issue
gh issue view 123 --json number,subIssues
gh issue view 124 --json number,parent,blockedBy,blocking
```

Complete only when every requested parent, sub-issue, blocker, and blocking relationship appears in the readback. If a relationship call fails after issue creation, re-fetch the created issue numbers and node IDs, then retry only missing links on the existing issues.

### Create PR from Issue

```bash
# Create and check out a linked branch
gh issue develop 123 --name feature/issue-123 --checkout

# Inspect changes and stage only intended paths
git status --short
git add path/to/changed-file
git diff --cached --stat
git commit -m "Fix issue #123"
git push -u origin HEAD

# Create PR linking to issue
gh pr create --title "Fix #123" --body "Closes #123"
```

### Bulk Operations

```bash
# Close multiple issues
gh issue list --search "label:stale" --json number --jq '.[].number' | \
  xargs -I {} gh issue close {} --comment "Closing as stale"

# Add label to multiple PRs
gh pr list --search "review:required" --json number --jq '.[].number' | \
  xargs -I {} gh pr edit {} --add-label needs-review
```

### Repository Setup

```bash
# Create repository with initial setup
gh repo create my-project --public \
  --description "My awesome project" \
  --clone --gitignore python --license mit

cd my-project

# Create labels
gh label create bug --color "d73a4a" --description "Bug report"
gh label create enhancement --color "a2eeef" --description "Feature request"
```

### CI/CD Workflow

```bash
# Dispatch and capture the created run URL
RUN_URL=$(gh workflow run ci.yml --ref main)
if [ -z "$RUN_URL" ]; then
  echo "No run URL returned; inspect gh run list before continuing." >&2
  exit 1
fi
RUN_ID=${RUN_URL##*/}

# Verify identity before watching or downloading
gh run view "$RUN_ID" --json databaseId,event,headBranch,url
gh run watch "$RUN_ID"
gh run download "$RUN_ID" --dir ./artifacts
```

### Fork and Sync

```bash
# Fork repository
gh repo fork original/repo --clone
cd repo

# Sync fork with upstream
gh repo sync
```

## Getting Help

```bash
gh --help              # General help
gh pr --help           # Command help
gh issue create --help # Subcommand help
gh help formatting     # Help topics
gh help environment
```

## References

- Official Manual: https://cli.github.com/manual/
- GitHub Docs: https://docs.github.com/en/github-cli
- REST API: https://docs.github.com/en/rest
- GraphQL API: https://docs.github.com/en/graphql

## Sources:

[1] gh pr edit manual (https://cli.github.com/manual/gh_pr_edit)
