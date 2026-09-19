---
name: address-comments
adaptedFrom:
  - "https://github.com/openai/skills/tree/main/skills/.curated/gh-address-comments"
  - "https://github.com/v1-io/v1tamins/tree/main/claude/skills/address-review"
description: Address unresolved pull request review comments and threads to closure.
disable-model-invocation: true
companions: [gh, writing-clearly-and-concisely]
---

# Address PR Review Threads

Work unresolved PR review threads and actionable review/conversation comments to closure with an explicit approved plan: gather context, classify comments and required checks, make approved repairs, publish them, wait for required checks, then close handled threads.

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

   Record the printed absolute `WORK_DIR` path. The JSON contains `pull_request`, `conversation_comments`, `reviews`, `review_threads`, and `bodies_file`; the named sidecar contains full bodies keyed by node `id`. Keep both files only for this pass. Before every final or blocked report, remove the recorded path with `rm -rf -- "<recorded absolute WORK_DIR path>"`; shell variables do not persist across tool calls.

## Ordered workflow

### 1. Discover and triage comments

Enumerate unresolved review threads, non-empty `CHANGES_REQUESTED` or `COMMENTED` review submissions, and conversation comments. Exclude bot/automation conversation authors. For each item record its id, source, author, and, for threads, path, line/range, full chain, and resolution state. If no actionable comments exist, continue through required-check classification; stop only when no actionable comments exist and every required check is green.

Review-thread comments always retain their inline full body. Use preview triage only for untruncated non-thread items. A `CHANGES_REQUESTED` review is addressable regardless of preview.

For a truncated non-thread item, load its full body from the sidecar before assigning `skip`, `addressable`, or `unsure`. The only exceptions are metadata that proves the author is bot/automation or a full-text comparison that proves it is an exact duplicate; never infer either exception from a preview. Record skipped items (id, author, preview, and reason) for the plan.

### 2. Establish the required-check baseline

Before edits, inspect every required PR check and record its status and links/log evidence. For each failing required check, inspect its logs and reproduce locally when feasible. Attribution is relative to the PR base, not when this skill started:

- `PR-introduced`: the PR differs from its base in a way that causes the failure, including a failure already present at invocation and one introduced while addressing a comment.
- `base/pre-existing`: evidence shows the failure occurs on the base or is unrelated to the PR diff.
- `flaky`: repeat or provider evidence confirms nondeterministic failure.
- `infrastructure`: provider evidence confirms an environmental outage.

When attribution is unclear, compare the PR against its merge base and test the base only through CI evidence or a separate temporary worktree. Never check out, reset, or otherwise mutate the working PR branch just to test the base. Leave an unclassified failure open with its evidence; do not speculate.

### 3. Gather context and classify comments

For every unresolved thread and retained non-thread item, read local code around its location and relevant PR diff context. Classify each exactly once:

| Verdict | Action |
| --- | --- |
| `fix` | Make the smallest code change that addresses the concern. |
| `disagree` | Keep the code and give a concise technical reason. |
| `left open` | Needs user input, broader scope, or cannot be resolved safely. |

Record a one-sentence rationale. Also identify each known `PR-introduced` required-check repair and its local verification.

### 4. Present one plan and obtain explicit approval

Present one plan containing every comment action, every known required-check repair, files to edit, local tests, items left open, skipped items, and the exact remote actions. Remote actions must be named individually: commit, push, each reply, and each thread resolution. Approval covers only the listed local edits/tests and listed remote actions; it does not imply broad permission for side effects.

Get explicit confirmation before applying the planned local edits or tests and before committing, pushing, posting GitHub replies, or resolving threads. If material new scope appears, present a plan amendment naming its edits, tests, and remote actions, then get confirmation before proceeding.

### 5. Apply and verify approved fixes

Make only approved local edits. Run the planned narrow local checks and fix failures. For every `PR-introduced` required-check failure, fix it, rerun affected local checks, and include its repair in the approved publication plan. Do not repair `base/pre-existing`, confirmed `flaky`, or `infrastructure` failures; retain their evidence and leave them open.

### 6. Commit and publish approved code

After local verification passes, create the approved descriptive commit and push it. Confirm that the commit is visible on the PR branch. If publication was not approved or fails, leave handled review threads unresolved and do not claim completion.

### 7. Close the required-check loop

After each approved publication, inspect all required remote checks again. For a failure, inspect logs, reproduce when feasible, and classify it using the PR base workflow above.

- Repair every `PR-introduced` failure. A repair first discovered here is a material scope change: amend the plan and obtain confirmation, then verify, commit, push, and inspect required checks again.
- Leave evidenced `base/pre-existing`, confirmed `flaky`, `infrastructure`, and unclassified failures open with evidence.
- Continue the approved repair loop until every required check is green. A reported `PR-introduced` failure is not completion.

Required checks must be green before closing replies or thread resolution. If approved code is not published or required checks are not green, do not claim done and do not resolve threads.

### 8. Reply and resolve only after checks are green

Load writing-clearly-and-concisely. Post one concise, outcome-based reply for each handled `fix` or `disagree`, using the approved action. For example, state what changed and any relevant verification, or state why the code remains unchanged. Do not use a mandatory reply template.

Reply in existing review threads; post new PR conversation comments for review submissions and conversation comments. Resolve only handled review threads after their replies. Leave `left open` threads unresolved; submissions and conversation comments have no resolution state.

## Output

Before the final or blocked report, remove the recorded absolute temporary-directory path. Report:

- Unresolved threads and non-thread comments surfaced, including skipped count
- Fixed, disagreed, and left-open counts with reasons
- Required checks: green status, repairs made, and evidence for every open base/pre-existing, flaky, infrastructure, or unclassified failure
- Files changed, local verification, and commit/push result
- Replies posted and threads resolved

Include a compact table:

| # | Source | File:Line | Issue | Action | Reply |
| --- | --- | --- | --- | --- | --- |
