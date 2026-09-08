---
name: address-comments
adaptedFrom:
  - "https://github.com/openai/skills/tree/main/skills/.curated/gh-address-comments"
  - "https://github.com/v1-io/v1tamins/tree/main/claude/skills/address-review"
description: >
  Address unresolved pull request review comments and threads to closure.
disable-model-invocation: true
companions: [gh, writing-clearly-and-concisely]
---

# Address PR Review Threads

Work unresolved PR review threads and actionable review/conversation comments end-to-end: gather full context, triage from cheap previews which comments need addressing, decide fix or technical disagreement, make approved changes, reply, and resolve only review threads addressed in this pass.

## Prerequisites

1. Verify GitHub CLI authentication:

```bash
gh auth status
```

Complete when authentication succeeds, or stop with the auth error.

2. Ensure the correct PR branch is checked out:

```bash
gh pr checkout <PR_NUMBER>
```

Complete when the current branch is the PR branch, or stop with the checkout error.

3. Fetch structured PR context from the PR repository root:

```bash
SKILL_DIR="<base directory for this skill>"
python3 "$SKILL_DIR/scripts/fetch_comments.py" > pr-comments.json
```

Complete when `pr-comments.json` contains `pull_request`, `conversation_comments`, `reviews`, `review_threads`, and `bodies_file`, and the sidecar named by `bodies_file` (default `pr-comments-bodies.json`) exists. Long review-submission and conversation-comment bodies are truncated to `body_preview` with `truncated: true` and `body_chars`; their full text lives in the sidecar keyed by node `id`. Review-thread comments are never truncated and keep their full `body` inline. The script must run from the PR repository so `gh pr view` can resolve the current branch.

## Workflow

### 1. Discover threads and comments

Use `pr-comments.json` to enumerate three tracks:

- Unresolved review threads (`review_threads` where `isResolved` is false) — the core deliverable.
- Review submissions (`reviews`) whose `state` is `CHANGES_REQUESTED` or `COMMENTED` with a non-empty body. Skip `APPROVED` reviews with an empty body.
- Conversation comments (`conversation_comments`), excluding automation/bot authors.

For each item record identifier, source track, and author; for threads also record file path, line or range, full comment chain, and resolved state. Read previews only — do not fetch truncated full bodies yet. If no items exist, report that and stop.

### 2. Triage comment intent

Run an intent gate over each non-thread item (review submissions and conversation comments) using its `body`/`body_preview` plus metadata, and assign one of:

| Gate verdict | Meaning |
| --- | --- |
| `addressable` | Preview clearly raises a change or question for this PR. |
| `skip` | Pleasantry, LGTM, off-topic, bot, or duplicate of a thread already listed. |
| `unsure` | Preview is ambiguous, or `truncated: true` with any change signal. |

Treat metadata as a hard prior: a `CHANGES_REQUESTED` review is `addressable` regardless of preview. For every `addressable` or `unsure` item, fetch the full body on demand from the sidecar by node id, e.g. `jq -r '."<id>"' pr-comments-bodies.json`. Unresolved review threads are never gated and always proceed. Complete when every non-thread item has a gate verdict and every `addressable`/`unsure` item has its full body loaded. Record the `skip` list (id, author, preview) to surface at plan time.

### 3. Gather local context

For each unresolved thread and each retained comment, read the referenced file around the location and the relevant PR diff or patch context. Complete when every item has current code context plus enough diff context to judge it.

### 4. Classify each item

Classify every unresolved thread and every retained comment as one of:

| Verdict | Action |
| --- | --- |
| `fix` | Make the smallest code change that addresses the concern. |
| `disagree` | Keep the code and reply with a concise technical reason. |
| `left open` | Needs user input, broader scope, or cannot be resolved safely in this pass. |

Complete when every retained item has exactly one verdict and a one-sentence rationale.

### 5. Present plan and get approval before side effects

Present a per-item plan with identifier, source track, verdict, files to touch, intended change or reply, and items that will remain open. List the gate `skip` items separately so the user can pull any back in. Get user confirmation before commits, pushes, PR comments, thread replies, or thread resolution. Complete when the user explicitly confirms the plan, or stop without external side effects.

### 6. Apply approved fixes

For every approved `fix`, edit only the files needed, follow local patterns, and avoid unrelated refactors. Complete when every approved `fix` has either a code change that addresses it or a documented blocker.

### 7. Verify changes

Run the narrowest relevant tests, typechecks, or linters for changed files. Complete when checks pass, or report the failing command and affected items.

### 8. Publish code changes if needed

If code changed and the confirmed plan includes publishing, create one descriptive commit and push it using the repository's VCS. Complete when the pushed commit is visible on the PR branch, or report the failed command.

### 9. Reply to addressed items

Load writing-clearly-and-concisely skill first, then reply once for every `fix` or `disagree` handled in this pass. Keep replies brief: `Fixed` plus a note when the implementation differs, or `Not changing this - <technical reason>`.

- Review threads: reply in the existing thread.
- Review submissions and conversation comments: reply as a new PR conversation comment; they have no thread to resolve.

Complete when every handled item has exactly one closing reply.

### 10. Resolve handled threads

Resolve only review threads handled in this pass, after their closing replies. Leave `left open` threads unresolved, and never attempt to resolve review submissions or conversation comments — they have no resolve state. Complete when every handled thread is resolved and every unhandled thread remains unresolved.

## Output

Provide a final summary with:

- Total unresolved review threads found
- Review submissions and conversation comments surfaced, and how many the gate skipped
- Count fixed with code changes
- Count answered with technical disagreement
- Count left open, with reasons
- Files changed
- Commit and push result, if applicable
- Threads resolved and non-thread comments replied to

Include a compact table:

| # | Source | File:Line | Issue | Action | Reply |
| --- | --- | --- | --- | --- | --- |
