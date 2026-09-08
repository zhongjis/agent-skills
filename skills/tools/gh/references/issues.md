# Issues (gh issue)

## Create Issue

```bash
# Create issue interactively
gh issue create

# Create with title
gh issue create --title "Bug: Login not working"

# Create with title and body
gh issue create \
  --title "Bug: Login not working" \
  --body "Steps to reproduce..."

# Create with body from file
gh issue create --body-file issue.md

# Create with labels
gh issue create --title "Fix bug" --labels bug,high-priority

# Create with assignees
gh issue create --title "Fix bug" --assignee user1,user2

# Create in specific repository
gh issue create --repo owner/repo --title "Issue title"

# Create issue from web
gh issue create --web
```

## Production-Ready Issue Creation

Use `--body-file` for long Markdown bodies. It avoids shell quoting bugs, preserves checklists/code blocks, and makes partial-failure recovery easier.

```bash
# Confirm target repo
gh repo view --json nameWithOwner,url

# Confirm labels before create/edit
gh label list --limit 200 --json name

# Create from a prepared body file
gh issue create \
  --title "Issue title" \
  --body-file issue-body.md \
  --label label-name

# Verify created issue and capture GraphQL node id
gh issue view 123 --json id,number,title,labels,url
```

Guidelines:
- Create related issues in dependency order so later issues can reference earlier blockers.
- Put human-readable blockers in the body even when also using GitHub relationship links.
- Check that labels exist before creating issues. If a requested label is missing, ask before creating labels unless the user explicitly requested label management.
- Keep parent issues unchanged unless the user asks to edit them; linking sub-issues is a relationship change, not a body rewrite.

## Issue Trees and Relationships

GitHub sub-issues and blocked-by links are GraphQL mutations. Use them when the user asks for sub-issues, parent/child issues, issue dependencies, blockers, or blocked-by relationships.

### Link Sub-Issues

```bash
# Get parent and child node ids
gh issue view 123 --json id,number,title,url
gh issue view 124 --json id,number,title,url

# Link child under parent
gh api graphql \
  -f query='mutation($issueId: ID!, $subIssueId: ID!) { addSubIssue(input: { issueId: $issueId, subIssueId: $subIssueId }) { issue { id } subIssue { id } } }' \
  -f issueId=PARENT_ID \
  -f subIssueId=CHILD_ID

# Verify parent lists the child
gh api graphql \
  -f query='query($owner: String!, $repo: String!, $number: Int!) { repository(owner: $owner, name: $repo) { issue(number: $number) { subIssues(first: 50) { nodes { number title url } } } } }' \
  -f owner=OWNER \
  -f repo=REPO \
  -F number=123
```

### Link Blocked-By Dependencies

```bash
# Link issue as blocked by another issue
gh api graphql \
  -f query='mutation($issueId: ID!, $blockingIssueId: ID!) { addBlockedBy(input: { issueId: $issueId, blockingIssueId: $blockingIssueId }) { issue { id } blockingIssue { id } } }' \
  -f issueId=BLOCKED_ISSUE_ID \
  -f blockingIssueId=BLOCKER_ISSUE_ID
```

Publish blockers first. This lets issue bodies and relationship links reference real issue numbers.

### Partial Failure Recovery

When a create/link batch fails midway:
1. List or view the issues already created; do not recreate them.
2. Capture their node ids with `gh issue view <number> --json id,number,title,url`.
3. Verify existing sub-issue and blocked-by links.
4. Retry only missing relationship mutations.
5. Re-run verification and report any links that still failed.


## List Issues

```bash
# List all open issues
gh issue list

# List all issues (including closed)
gh issue list --state all

# List closed issues
gh issue list --state closed

# Limit results
gh issue list --limit 50

# Filter by assignee
gh issue list --assignee username
gh issue list --assignee @me

# Filter by labels
gh issue list --labels bug,enhancement

# Filter by milestone
gh issue list --milestone "v1.0"

# Search/filter
gh issue list --search "is:open is:issue label:bug"

# JSON output
gh issue list --json number,title,state,author

# Table view with jq
gh issue list --json number,title,labels \
  --jq '.[] | [.number, .title, .labels[].name] | @tsv'

# Sort by
gh issue list --sort created --order desc
```

## View Issue

```bash
# View issue
gh issue view 123

# View with comments
gh issue view 123 --comments

# View in browser
gh issue view 123 --web

# JSON output
gh issue view 123 --json title,body,state,labels,comments

# View specific fields
gh issue view 123 --json title --jq '.title'
```

## Edit Issue

```bash
# Edit interactively
gh issue edit 123

# Edit title
gh issue edit 123 --title "New title"

# Edit body
gh issue edit 123 --body "New description"

# Add labels
gh issue edit 123 --add-label bug,high-priority

# Remove labels
gh issue edit 123 --remove-label stale

# Add assignees
gh issue edit 123 --add-assignee user1,user2

# Remove assignees
gh issue edit 123 --remove-assignee user1

# Set milestone
gh issue edit 123 --milestone "v1.0"
```

## Close/Reopen Issue

```bash
# Close issue
gh issue close 123

# Close with comment
gh issue close 123 --comment "Fixed in PR #456"

# Reopen issue
gh issue reopen 123
```

## Comment on Issue

```bash
# Add comment
gh issue comment 123 --body "This looks good!"

# Edit comment
gh issue comment 123 --edit 456789 --body "Updated comment"

# Delete comment
gh issue comment 123 --delete 456789
```

## Issue Status

```bash
# Show issue status summary
gh issue status

# Status for specific repository
gh issue status --repo owner/repo
```

## Pin/Unpin Issues

```bash
# Pin issue (pinned to repo dashboard)
gh issue pin 123

# Unpin issue
gh issue unpin 123
```

## Lock/Unlock Issue

```bash
# Lock conversation
gh issue lock 123

# Lock with reason
gh issue lock 123 --reason off-topic

# Unlock
gh issue unlock 123
```

## Transfer Issue

```bash
# Transfer to another repository
gh issue transfer 123 --repo owner/new-repo
```

## Delete Issue

```bash
# Delete issue
gh issue delete 123

# Confirm without prompt
gh issue delete 123 --yes
```

## Develop Issue (Create Branch/PR)

```bash
# Create draft PR from issue
gh issue develop 123

# Create in specific branch
gh issue develop 123 --branch fix/issue-123

# Create with base branch
gh issue develop 123 --base main
```
