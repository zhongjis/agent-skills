# API Requests (gh api)

## REST API

### Basic Requests

```bash
# GET request
gh api /user

# Request with method
gh api --method POST /repos/owner/repo/issues \
  --field title="Issue title" \
  --field body="Issue body"

# Request with headers
gh api /user \
  --header "Accept: application/vnd.github.v3+json"
```

### Pagination

```bash
# Request with pagination
gh api /user/repos --paginate
```

### Output Control

```bash
# Raw output (no formatting)
gh api /user --raw

# Include headers in output
gh api /user --include

# Silent mode (no progress output)
gh api /user --silent
```

### Input from File

```bash
# Input from file
gh api --method POST /repos/owner/repo/issues --input request.json
```

### JQ Queries

```bash
# jq query on response
gh api /user --jq '.login'

# Field from response
gh api /repos/owner/repo --jq '.stargazers_count'

# Complex jq query
gh api /repos/owner/repo/issues --jq '.[] | {number, title}'
```

### GitHub Enterprise

```bash
# GitHub Enterprise
gh api /user --hostname enterprise.internal
```

## GraphQL API

```bash
# GraphQL query
gh api graphql \
  -f query='
  {
    viewer {
      login
      repositories(first: 5) {
        nodes {
          name
        }
      }
    }
  }'

# GraphQL with variables
gh api graphql \
  -f query='
    query($owner: String!, $repo: String!) {
      repository(owner: $owner, name: $repo) {
        issues(first: 10) {
          nodes {
            title
            number
          }
        }
      }
    }
  ' \
  -f owner='octocat' \
  -f repo='hello-world'
```

### Issue Relationship Mutations

Use GraphQL node ids from `gh issue view <number> --json id`. Relationship mutations are useful for sub-issues and blocked-by dependencies. Verify support first if working against GitHub Enterprise or an older API surface.

```bash
# Optional: confirm mutation names exist
gh api graphql \
  -f query='query { __schema { mutationType { fields { name } } } }' \
  --jq '.data.__schema.mutationType.fields[].name'

# Link a child issue under a parent issue
gh api graphql \
  -f query='mutation($issueId: ID!, $subIssueId: ID!) { addSubIssue(input: { issueId: $issueId, subIssueId: $subIssueId }) { issue { id } subIssue { id } } }' \
  -f issueId=PARENT_ID \
  -f subIssueId=CHILD_ID

# Mark one issue as blocked by another
gh api graphql \
  -f query='mutation($issueId: ID!, $blockingIssueId: ID!) { addBlockedBy(input: { issueId: $issueId, blockingIssueId: $blockingIssueId }) { issue { id } blockingIssue { id } } }' \
  -f issueId=BLOCKED_ISSUE_ID \
  -f blockingIssueId=BLOCKER_ISSUE_ID
```

```bash
# Verify parent sub-issues
gh api graphql \
  -f query='query($owner: String!, $repo: String!, $number: Int!) { repository(owner: $owner, name: $repo) { issue(number: $number) { subIssues(first: 50) { nodes { number title url } } } } }' \
  -f owner=OWNER \
  -f repo=REPO \
  -F number=123
```


## Common API Patterns

### Get Repository Info

```bash
gh api /repos/owner/repo --jq '{name, stars: .stargazers_count, forks: .forks_count}'
```

### List Collaborators

```bash
gh api /repos/owner/repo/collaborators --jq '.[].login'
```

### Get Workflow Runs

```bash
gh api /repos/owner/repo/actions/runs --jq '.workflow_runs[] | {id, status, conclusion}'
```

### Create Issue via API

```bash
gh api --method POST /repos/owner/repo/issues \
  --field title="Bug report" \
  --field body="Description" \
  --field labels='["bug"]'
```

### Get PR Comments

```bash
gh api /repos/owner/repo/pulls/123/comments --jq '.[].body'
```

### Get Review Comments

```bash
gh api /repos/owner/repo/pulls/123/reviews --jq '.[] | {user: .user.login, state}'
```
