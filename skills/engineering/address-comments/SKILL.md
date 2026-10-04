---
name: address-comments
adaptedFrom:
  - "https://github.com/openai/skills/tree/main/skills/.curated/gh-address-comments"
  - "https://github.com/v1-io/v1tamins/tree/main/claude/skills/address-review"
description: Address unresolved pull request review comments and threads to closure automatically; add `--manual` to require approval.
disable-model-invocation: true
companions: [gh, writing-clearly-and-concisely]
---

# Address PR Review Threads

Work unresolved PR review threads and actionable review/conversation comments to closure with a scoped plan: gather context, classify comments and required checks, make authorized repairs, publish them, reply, settle prior rounds, then wait briefly for required checks.

## Mode

All workflow authorization follows this single rule:

- **Default** (without `--manual`): record the Step 4 plan or amendment and execute the full scoped workflow without asking for approval, including local edits/tests, commit, push, replies, and `settled` thread resolutions.
- **`--manual`**: present the Step 4 plan or amendment and obtain one explicit approval covering its listed local edits/tests and individually named remote actions.

`--manual` changes only the approval gate. Both modes keep fixes scoped, retain failure evidence and left-open items, publish code before replying, leave threads replied to in this pass unresolved for the reviewer, bound each required-check wait to 5 minutes per push, and clean up the temporary directory.

## Setup

1. Select the PR branch:

   - If the invocation specifies a PR number or URL, check out that PR:

   ```bash
   gh pr checkout <PR_NUMBER_OR_URL>
   ```

   - Otherwise use the open PR associated with the current branch:

   ```bash
   gh pr view --json number,url
   ```

   Stop and ask for a PR if no PR was specified and the current branch has no associated open PR.

2. From the PR repository root, create one temporary directory for both fetched files. The script verifies GitHub CLI authentication itself.

   ```bash
   WORK_DIR="$(mktemp -d)"
   SKILL_DIR="<base directory for this skill>"
   python3 "$SKILL_DIR/scripts/fetch_comments.py" \
     --bodies-out "$WORK_DIR/pr-comments-bodies.json" \
     > "$WORK_DIR/pr-comments.json"
   printf 'WORK_DIR=%s\n' "$WORK_DIR"
   ```

   Record the printed absolute `WORK_DIR` path. The JSON contains `pull_request` (including the PR `author` login), `conversation_comments`, `reviews`, `review_threads`, and `bodies_file`; the named sidecar contains full bodies keyed by node `id`. Keep both files only for this pass. Before every final or blocked report, remove the recorded path with `rm -rf -- "<recorded absolute WORK_DIR path>"`; shell variables do not persist across tool calls.

## Ordered workflow

### 1. Discover and triage comments

Enumerate unresolved review threads, non-empty `CHANGES_REQUESTED` or `COMMENTED` review submissions, and conversation comments. Exclude bot/automation conversation authors. For each item record its id, source, author, and, for threads, path, line/range, full chain, resolution state, and round. A thread's reviewer is the author of its first comment (earliest `createdAt`); the last comment is the latest `createdAt`. Split every unresolved review thread:

- `active`: someone other than the PR author wrote the last comment. It goes through normal triage.
- `settled`: the PR author wrote the last comment, and that same reviewer has PR activity created after that comment: a review submission (`submittedAt`), a comment in any review thread (`createdAt`), or a PR conversation comment (`createdAt`). A new round without pushback in this thread is the reviewer's chance to confirm the earlier reply, whether it reported a fix or explained why the code stays. Plan its resolution; it needs no new reply or verdict.
- `awaiting`: the PR author wrote the last comment, and that reviewer has no later activity. Leave it untouched.

A thread the PR author started is `active` only when someone else wrote its last comment; otherwise leave it untouched.

Review-thread comments always retain their inline full body. Use preview triage only for untruncated non-thread items. A `CHANGES_REQUESTED` review is addressable regardless of preview.

For a truncated non-thread item, load its full body from the sidecar before assigning `skip`, `addressable`, or `unsure`. The only exceptions are metadata that proves the author is bot/automation or a full-text comparison that proves it is an exact duplicate; never infer either exception from a preview. Record skipped items (id, author, preview, and reason) for the plan.

Deduplicate non-thread findings against inline threads using full bodies: retain independently actionable non-thread concerns, and record findings already represented inline as skipped with a link to their source comment/review.

When no `active` or `settled` thread and no actionable non-thread comment or review submission exists, still classify required checks. Stop when no `PR-introduced` repair is needed.

### 2. Establish the required-check baseline

Before edits, inspect every required PR check and record its status and links/log evidence. For each failing required check, inspect its logs and reproduce locally when feasible. Attribution is relative to the PR base, not when this skill started:

- `PR-introduced`: the PR differs from its base in a way that causes the failure, including a failure already present at invocation and one introduced while addressing a comment.
- `base/pre-existing`: evidence shows the failure occurs on the base or is unrelated to the PR diff.
- `flaky`: repeat or provider evidence confirms nondeterministic failure.
- `infrastructure`: provider evidence confirms an environmental outage.

When attribution is unclear, compare the PR against its merge base and test the base only through CI evidence or a separate temporary worktree. Never check out, reset, or otherwise mutate the working PR branch just to test the base. Leave an unclassified failure open with its evidence; do not speculate.

### 3. Gather context and classify comments

For every `active` thread and retained non-thread item, read local code around its location and relevant PR diff context. Classify each exactly once:

| Verdict | Action |
| --- | --- |
| `fix` | Make the smallest code change that addresses the concern. |
| `disagree` | Keep the code and give a concise technical reason. |
| `left open` | Needs user input, broader scope, or cannot be resolved safely. |

`settled` and `awaiting` threads take no verdict. Record a one-sentence rationale. Also identify each known `PR-introduced` required-check repair and its local verification.

### 4. Prepare one plan

Prepare one plan containing every comment action, every `settled` resolution, the `awaiting` threads, every known required-check repair, files to edit, local tests, items left open, skipped items, and the exact remote actions. Remote actions must be named individually: commit, push, each reply, and each `settled` thread resolution. Authorization is limited to the plan's listed local edits/tests and remote actions; it does not imply broad permission for side effects.

Apply the mode rule to this plan. If material new scope appears, prepare a plan amendment naming its edits, tests, and remote actions, then apply the mode rule again before proceeding.

### 5. Apply and verify authorized fixes

Make only authorized local edits. Run the planned narrow local checks and fix failures. For every `PR-introduced` required-check failure, fix it, rerun affected local checks, and include its repair in the authorized publication plan. Do not repair `base/pre-existing`, confirmed `flaky`, or `infrastructure` failures; retain their evidence and leave them open.

### 6. Commit and publish authorized code

After local verification passes, create the authorized descriptive commit and push it. Confirm that the commit is visible on the PR branch. If publication was not authorized or fails, post no reply that reports an unpublished change, and do not claim completion.

### 7. Reply and settle prior rounds

Load writing-clearly-and-concisely. After the code backing a `fix` reply is visible on the PR, post one concise, outcome-based reply per handled `fix` or `disagree`. The reply states what changed and its local verification, or why the code stays. Remote checks are still running, so the reply reports no CI outcome. No mandatory template.

Reply in existing threads. Prefer REST replies to the thread's root comment (earliest `createdAt`), using its numeric REST `databaseId`, not its GraphQL node `id`. The fetched data has only node IDs; resolve the root ID read-only at publication:

```bash
gh api graphql -f query='query($root: ID!) { node(id: $root) { ... on PullRequestReviewComment { databaseId } } }' \
  -f root='<root-comment-node-id>' --jq '.data.node.databaseId'
gh api --method POST repos/<owner>/<repo>/pulls/<number>/comments/<root-comment-database-id>/replies \
  -f body='<concise reply>'
```

Serialize all reply/review writes on this PR; finish each write and readback before the next. After an uncertain outcome, inspect the intended thread for an existing matching reply before retrying; verify or recover that reply rather than creating a duplicate.

Use the returned REST `node_id` (or the drafting mutation's comment node ID) for readback:

```bash
gh api graphql -f query='query($reply: ID!) { node(id: $reply) { ... on PullRequestReviewComment { state url replyTo { id databaseId } pullRequestReview { id state } } } }' \
  -f reply='<reply-comment-node-id>'
```

Count a reply as posted only when readback shows comment `state: SUBMITTED`, a present non-`PENDING` parent `pullRequestReview`, and `replyTo` matching the intended root comment. A success response, URL, or matching body alone is not completion. If a drafting API returns `PENDING`, submit only a pending review proven to have been created by this workflow and containing only the plan's authorized replies, using `COMMENT` (never `APPROVE` or `REQUEST_CHANGES`). Name that submission in the plan/amendment and apply the existing mode rule before submitting, then repeat readback. Never publish the user's pre-existing draft. If ownership is unknown or the parent review is absent, stop and report the reply as pending/unverified; deletion or reposting requires separate authorization.

Use new PR conversation comments only for independently actionable non-thread concerns retained in triage; link to the source comment/review rather than repeating findings already represented inline. Leave every thread replied to in this pass unresolved so its reviewer can confirm. Resolve each `settled` thread without a new reply. Leave `left open` and `awaiting` threads untouched. Submissions and conversation comments have no resolution state.

### 8. Wait for required checks (5-minute window per push)

After each push, watch required checks on the pushed head commit for at most 5 minutes. Each push starts a new window. Use a polling loop with a 5-minute deadline. Stop early when every required check is green or any required check fails.

For a failure, inspect logs, reproduce when feasible, and classify with the PR base workflow from Step 2.

- Repair every `PR-introduced` failure. A repair first discovered here is a material scope change: amend the plan, apply the mode rule, then verify, commit, and push. Reply again only when the repair changes behavior an earlier reply described; post that reply right after the push and leave that thread unresolved. Then start a new window.
- Leave evidenced `base/pre-existing`, confirmed `flaky`, `infrastructure`, and unclassified failures open with evidence.
- When the window ends with checks still pending, stop waiting and report each pending check with its link.

Pending checks block neither replies nor resolutions. A known `PR-introduced` failure blocks completion until repaired. Claim checks green only when observed green.

## Output

Before the final or blocked report, remove the recorded absolute temporary-directory path. Report:

- Surfaced threads by round (`active`, `settled`, `awaiting`) plus non-thread comments, including skipped count
- Fixed, disagreed, and left-open counts with reasons
- Required checks: status at the end of the last window (green, failed, or pending with links), repairs made, and evidence for every open base/pre-existing, flaky, infrastructure, or unclassified failure
- Files changed, local verification, and commit/push result
- Replies posted, `settled` threads resolved, and threads left for reviewers to resolve

Include a compact table:

| # | Source | File:Line | Issue | Action | Reply |
| --- | --- | --- | --- | --- | --- |
