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

Work unresolved PR review threads end-to-end: gather full context, decide fix or technical disagreement, make approved changes, reply in-thread, and resolve only threads addressed in this pass.

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

Complete when `pr-comments.json` contains `pull_request`, `conversation_comments`, `reviews`, and `review_threads`. The script must run from the PR repository so `gh pr view` can resolve the current branch.

## Workflow

### 1. Discover unresolved threads

Use `pr-comments.json` to list every unresolved review thread. Complete when every unresolved thread has an identifier, file path, line or range, full comment chain, and resolved state recorded. If none exist, report that and stop.

### 2. Gather local context

For each unresolved thread, read the referenced file around the location and the relevant PR diff or patch context. Complete when every thread has current code context plus enough diff context to judge the comment.

### 3. Classify each thread

Classify every unresolved thread as one of:

| Verdict | Action |
| --- | --- |
| `fix` | Make the smallest code change that addresses the concern. |
| `disagree` | Keep the code and reply with a concise technical reason. |
| `left open` | Needs user input, broader scope, or cannot be resolved safely in this pass. |

Complete when every unresolved thread has exactly one verdict and a one-sentence rationale.

### 4. Present plan and get approval before side effects

Present a per-thread plan with identifier, verdict, files to touch, intended change or reply, and threads that will remain open. Get user confirmation before commits, pushes, PR comments, thread replies, or thread resolution. Complete when the user explicitly confirms the plan, or stop without external side effects.

### 5. Apply approved fixes

For every approved `fix`, edit only the files needed, follow local patterns, and avoid unrelated refactors. Complete when every approved `fix` has either a code change that addresses it or a documented blocker.

### 6. Verify changes

Run the narrowest relevant tests, typechecks, or linters for changed files. Complete when checks pass, or report the failing command and affected threads.

### 7. Publish code changes if needed

If code changed and the confirmed plan includes publishing, create one descriptive commit and push it using the repository's VCS. Complete when the pushed commit is visible on the PR branch, or report the failed command.

### 8. Reply in addressed threads

Load writing-clearly-and-concisely skill first, then reply in the existing thread for every `fix` or `disagree` handled in this pass. Keep replies brief: `Fixed` plus a note when the implementation differs, or `Not changing this - <technical reason>`. Complete when every handled thread has exactly one closing reply.

### 9. Resolve handled threads

Resolve only threads handled in this pass, after their closing replies. Leave `left open` threads unresolved. Complete when every handled thread is resolved and every unhandled thread remains unresolved.

## Output

Provide a final summary with:

- Total unresolved threads found
- Count fixed with code changes
- Count answered with technical disagreement
- Count left open, with reasons
- Files changed
- Commit and push result, if applicable
- Threads replied to and resolved

Include a compact table:

| # | File:Line | Issue | Action | Reply |
| --- | --- | --- | --- | --- |
