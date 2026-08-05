---
name: gh
description: GitHub CLI (gh) comprehensive reference for repositories, issues, pull requests, Actions, projects, releases, gists, codespaces, organizations, extensions, and all GitHub operations from the command line. Use when creating PRs, managing issues, running workflows, checking CI status, managing releases, making GitHub API calls, or handling operational issue workflows such as bulk issue creation, sub-issues, blocked-by links, labels, and GitHub API/GraphQL issue relationships. Triggers on "create PR", "list issues", "gh command", "merge PR", "run workflow", "check status", "create release", "download artifacts", "set secret", "create issues", "sub-issues", "blocked by", and "GitHub API".
upstream: https://github.com/github/awesome-copilot/blob/main/skills/gh-cli/SKILL.md
---

# GitHub CLI (gh)

Work seamlessly with GitHub from the command line.

## Quick Reference

| Task                    | Command                                           |
| ----------------------- | ------------------------------------------------- |
| Create PR               | `gh pr create --title "..." --body "..."`         |
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

## CLI Structure

```
gh                          # Root command
├── auth                    # Authentication
├── browse                  # Open in browser
├── repo                    # Repositories
├── issue                   # Issues
├── pr                      # Pull Requests
├── run                     # Workflow runs
├── workflow                # Workflows
├── release                 # Releases
├── project                 # Projects
├── codespace               # Codespaces
├── gist                    # Gists
├── cache                   # Actions caches
├── secret                  # Secrets
├── variable                # Variables
├── api                     # API requests
├── search                  # Search
├── label                   # Labels
├── org                     # Organizations
├── ssh-key                 # SSH keys
├── gpg-key                 # GPG keys
├── extension               # Extensions
├── alias                   # Aliases
├── config                  # Configuration
├── ruleset                 # Rulesets
├── attestation             # Attestations
├── status                  # Status overview
└── completion              # Shell completion
```

## Detailed References

For comprehensive command documentation:

- [Authentication](references/auth.md) - Login, tokens, credentials, environment variables
- [Repositories](references/repos.md) - Create, clone, fork, sync, browse, edit
- [Issues](references/issues.md) - Create, list, edit, close, comment, labels
- [Pull Requests](references/prs.md) - Create, review, merge, checkout, diff
- [Actions](references/actions.md) - Workflows, runs, caches, secrets, variables
- [Releases](references/releases.md) - Create, upload, download, verify
- [Projects](references/projects.md) - Create, manage items, fields
- [Codespaces](references/codespaces.md) - Create, connect, manage
- [API](references/api.md) - REST and GraphQL requests
- [Misc](references/misc.md) - Gists, orgs, search, labels, keys, extensions, aliases

## Global Flags

| Flag                       | Description                            |
| -------------------------- | -------------------------------------- |
| `--help` / `-h`            | Show help for command                  |
| `--repo [HOST/]OWNER/REPO` | Select another repository              |
| `--hostname HOST`          | GitHub hostname                        |
| `--jq EXPRESSION`          | Filter JSON output                     |
| `--json FIELDS`            | Output JSON with specified fields      |
| `--template STRING`        | Format JSON using Go template          |
| `--web`                    | Open in browser                        |
| `--paginate`               | Make additional API calls              |

## Output Formatting

### JSON Output

```bash
# Basic JSON
gh repo view --json name,description

# Nested fields
gh repo view --json owner,name --jq '.owner.login + "/" + .name'

# Array operations
gh pr list --json number,title --jq '.[] | select(.number > 100)'

# Complex queries
gh issue list --json number,title,labels \
  --jq '.[] | {number, title: .title, tags: [.labels[].name]}'
```

### Template Output

```bash
# Custom template
gh repo view --template '{{.name}}: {{.description}}'

# Multiline template
gh pr view 123 --template 'Title: {{.title}}
Author: {{.author.login}}
State: {{.state}}'
```

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

# 5. Link sub-issues / blockers with GraphQL, then verify
gh api graphql -f query='mutation($issueId: ID!, $subIssueId: ID!) { addSubIssue(input: { issueId: $issueId, subIssueId: $subIssueId }) { issue { id } subIssue { id } } }' -f issueId=PARENT_ID -f subIssueId=CHILD_ID
gh api graphql -f query='mutation($issueId: ID!, $blockingIssueId: ID!) { addBlockedBy(input: { issueId: $issueId, blockingIssueId: $blockingIssueId }) { issue { id } blockingIssue { id } } }' -f issueId=CHILD_ID -f blockingIssueId=BLOCKER_ID
```

If a relationship call fails after issue creation, do not recreate issues. Re-fetch created issue numbers/node ids, verify which relationships exist, then retry only missing links.

### Create PR from Issue

```bash
# Create branch from issue
gh issue develop 123 --branch feature/issue-123

# Make changes, commit, push
git add . && git commit -m "Fix issue #123" && git push

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
# Run workflow
gh workflow run ci.yml --ref main

# Get latest run
RUN_ID=$(gh run list --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')

# Watch the run
gh run watch "$RUN_ID"

# Download artifacts on completion
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

## Environment Variables

```bash
export GH_TOKEN=ghp_xxxxxxxxxxxx    # Token for automation
export GH_HOST=github.com           # GitHub hostname
export GH_PROMPT_DISABLED=true      # Disable prompts
export GH_REPO=owner/repo           # Override default repo
```

## Best Practices

1. **Set default repository** to avoid repetition:
   ```bash
   gh repo set-default owner/repo
   ```

2. **Use JSON + jq** for complex data extraction:
   ```bash
   gh pr list --json number,title --jq '.[] | select(.title | contains("fix"))'
   ```

3. **Use --paginate** for large result sets:
   ```bash
   gh issue list --state all --paginate
   ```

4. **Use environment variables** for automation:
   ```bash
   export GH_TOKEN=$(gh auth token)
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
