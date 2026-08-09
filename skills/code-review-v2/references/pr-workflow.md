# PR Workflow

GitHub pull-request specifics for the PR Review mode. Loaded only when reviewing a PR; local reviews never need this file.

## 1. Gather PR context

- `gh pr view <number>` — title, body, author, labels, linked issues. The body and linked issues are a Spec source — fetch the linked issues or tickets to ground the Spec axis.
- `gh pr diff <number>` — the full changeset.

## 2. Collect existing feedback first

Before drafting anything, read the full PR discussion:

```bash
gh pr view <number> --comments                                 # general conversation
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate # line-specific comments
gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate  # review summaries / states
```

Treat issues other reviewers already raised as prior art — your findings must be net-new. Reply in the existing thread rather than reposting; add a fresh comment only with materially new information (a different root cause, higher severity, a more precise line, or a fix the thread lacks). When in doubt, don't repost the duplicate — surface acknowledged overlaps only in the collapsed **Already raised by others** list (see Progressive disclosure), so prior discussion is credited without doubling the noise.

## 2b. Scope a re-review to new commits

If a prior code-review-v2 review already exists on this PR, scope this pass to what changed since it. Find that review in the `gh api repos/{owner}/{repo}/pulls/{number}/reviews` output by matching **both** the `<!-- code-review-v2 -->` marker in its `body` **and** an author login equal to the current `gh` user (`gh api user -q .login`) — match both, or you may grab another tool's review. Read that review's `commit_id`, enumerate the new commits (`git log <sha>..HEAD --oneline`) and their files (`git diff --stat <sha>...HEAD`), and review only that diff (`git diff <sha>...HEAD`) — the scope is those new commits, not a re-scan of the whole PR. Open the new summary body with the exact opener line "Incremental review since `<sha>` — prior findings not repeated." so the author knows what was and wasn't re-read.

"Prior findings not repeated" governs *findings*, not unresolved *risk*: any earlier `[BLOCKER]` or `[MAJOR]` still unfixed at the new head must be re-surfaced (reference it by its ID), never silently dropped. A missed marker only costs a safe full re-review; a false match mis-scopes, which is why the author-login match is mandatory.

## 2c. Incremental output

The incremental summary is a **binding contract**, not the § Output skeleton. It MUST open with the exact opener line from § 2b ("Incremental review since `<sha>` — prior findings not repeated."); a summary that re-renders the first-review skeleton — Strengths, empty axes, a restated prior — has ignored this contract. Reuse § Output only by reference — same findings-table format, verdict computation (§ Aggregation), and attribution footer (§ Attribution footer) — and change these:

- **Findings table: new rows only** (findings net-new since `<sha>`). If no axis has a new finding, drop the table and write one line — "No new findings since `<sha>`."
- **Omit axes that found nothing.** Every axis still runs and is accounted for (§ Aggregation), but an incremental summary indexes only new findings — it does not list the empty axes the way a first review does.
- **No Strengths / KUDOS section.** Strengths belong to a first/full review; an incremental pass indexes findings only.
- **Resolved prior findings stay silent** — GitHub already marks their threads resolved or outdated. At most one credit line, e.g. "Resolved: M1, S1–S5, N1–N5"; never a per-finding resolution table and never a prose "what's now fixed" recap.
- **Reference unresolved priors by ID — never restate them.** Any earlier `[BLOCKER]`/`[MAJOR]` still unfixed at the new head is listed by its ID (per § 2b) as one line, with no fresh write-up. For a prior raised by another reviewer, reply in that thread or link it under **Already raised by others** (§ Progressive disclosure) rather than reposting. The verdict is computed over the new findings **plus** those unresolved priors — so a head that resolves everything flips to `APPROVE`.

## 3. Submit as one atomic review

Build a temporary JSON file with the summary body, verdict event, and any inline comments, then submit it as a single review, so the summary lands in the Conversation tab and the inline comments in the Files Changed tab, grouped as one review.

```bash
# 1. Determine owner/repo and head commit
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
HEAD_OID=$(gh pr view <number> --json headRefOid -q .headRefOid)

# 2. Build the review payload
cat > /tmp/review.json << 'REVIEW_EOF'
{
  "body": "## Code Review Summary\n\n...",
  "event": "COMMENT",
  "comments": [
    {
      "path": "src/file.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "**[BLOCKER] (Security)** Brief title\n\n**Issue**: ...\n**Why it matters**: ...\n**Suggestion**:\n```lang\n// fix\n```"
    }
  ]
}
REVIEW_EOF

# 3. Submit (inline comments + summary in one call)
gh api repos/${OWNER_REPO}/pulls/<number>/reviews --input /tmp/review.json
```

Set `event` from the verdict:

| Verdict | `event` |
| --- | --- |
| Approve | `APPROVE` |
| Request changes | `REQUEST_CHANGES` |
| Comment only | `COMMENT` |

Each `comments` entry needs `path`, `line`, `side` (`"RIGHT"` for new code), and `body`. Omit the array if there are no line-specific findings; the summary still posts. For a simple approval with no inline findings, the short form works:

```bash
gh pr review <number> --approve --body "..."
gh pr review <number> --request-changes --body "..."
```

## Attribution footer (always, summary body only)

The review posts under the human's own GitHub identity and carries a verdict in their name, so the summary body MUST end with an attribution footer — the only signal that a human didn't hand-write it. Append it to the summary body only, never to inline comments. Two parts, in order:

1. **Visible credit line** (non-suppressible) — names the skill and its multi-axis method, so the review reads as a rigorous pass rather than ad-hoc AI. One line, e.g.:

   > 🔍 Reviewed with **[code-review-v2](https://github.com/zhongjis/agent-skills/tree/main/skills/code-review-v2)** — multi-axis AI review (correctness · standards · regression · security), each axis run in isolation so none masks another. Sharp eyes, no ego; a human still owns the merge.

2. **Invisible self-ID marker** — an HTML comment on its own line, so a later run can recognize this review as its own (see §2b):

   ```
   <!-- code-review-v2 -->
   ```

Keep the visible line even on a clean `APPROVE`: undisclosed AI authorship under a human identity is exactly what this footer prevents. The marker is not load-bearing — if it is ever missing or altered, re-review just falls back to a full pass.

## Inline vs summary

The summary is an index; the inlines are the content.

- A finding with a file and line: its full detail (issue, why it matters, fix, test to add) lives in the inline comment; the summary lists it as one row in the findings table (ID, axis, severity, location, one line).
- A cross-cutting finding with no single line: write it out in the summary body.
- Verdict, confidence, and strengths live in the summary only.

Don't restate inline content in the summary — GitHub renders them in different tabs, so duplication forces the author to read twice and drifts if one copy changes. Avoid 20+ inline comments; group related nits onto one representative line.

## Progressive disclosure in the summary

Keep the verdict and findings table above the fold. Genuinely secondary, summary-only sections — a long per-axis or per-file confidence table, strengths / KUDOS — can go in `<details>` blocks; the verification / methodology note is always collapsed (§ Output). Blockers and majors are never collapsed.

- **Already raised by others** — when your findings overlap comments already on the PR, list those overlaps here, one line each linking the existing thread, instead of reposting them. Appears only when overlaps exist, and never affects the verdict.

## GitHub comment formatting

- **Never use `#N` notation** (`#1`, `#2`) — GitHub auto-links it to issues/PRs, creating broken references. Use severity-prefixed IDs: `B1`, `M1`, `S1`, `N1`.
- **Never write "issue #1"** — write "finding B1", or use the severity tag.
- Keep inline comment bodies self-contained — the author reads them in the diff without the summary. Prefix each with its severity and axis, e.g. `**[MAJOR] (Regression)**`.
