---
name: code-review
description: "Comprehensive code review for local diffs (git/jj) and GitHub PRs — severity-ranked, confidence-scored findings with structured PR feedback via the gh CLI."
disable-model-invocation: true
adaptedFrom:
  - "https://github.com/wshobson/agents/blob/main/plugins/developer-essentials/skills/code-review-excellence/SKILL.md"
---

# Code Review

A systematic framework for evaluating code changes that ensures consistency, security, and maintainability while fostering professional growth.

**Modes**: Local Review (git/jj diff) | PR Review (gh CLI)

---

## Principles

- **Critique the code, not the person.** No sarcasm, condescension, or personal attacks — every line represents effort.
- **Every finding leads to a better solution.** Reference exact lines, include a code example, and explain *why* it matters (rationale, not just the what). Vague feedback is useless.
- **Differentiate severity.** Tag every finding so the author can tell a blocker from a preference (see Severity System).
- **Code health over perfection (Google).** Approve changes that improve overall code health even when imperfect. Never `REQUEST_CHANGES` over style, naming, or other non-correctness preferences — that is preference-blocking.
- **Keep human review focused (Microsoft).** Under 400 LOC per session; let automated tooling catch formatting so review targets architecture and business logic.
- **Acknowledge good work.** Use `[KUDOS]` for well-written sections — it reinforces standards and builds trust.
- **Land on a stable set of required changes.** Ask when intent is unclear, but don't rubber-stamp with "LGTM" without inspection, and don't move the goalposts by introducing new requirements late or demanding a rewrite of an otherwise-valid approach.
- **Keep review scope to the actual changes.** Raise unrelated issues or feature ideas elsewhere, not in this review.

---

## Review Modes

### Local Review

For uncommitted or recently committed changes in the current workspace.

```bash
# Git
git diff --stat
git diff
git log --oneline -10

# Jujutsu
jj diff --stat
jj diff
jj log -r 'all()' --limit 10
```

1. Run `diff --stat` to understand the scope and distribution of changes.
2. Examine the full diff to identify logic and structural changes.
3. Check recent history to understand the context of current work.
4. Gather codebase context using Phase 1.5 below (at minimum Layers 1-2).
5. Proceed to the Review Process below.

### PR Review (gh CLI)

Full GitHub pull request workflow with structured feedback.

**Pipeline:**

1. **Gather context**: `gh pr view <number>` — read title, body, author, labels, linked issues.
2. **Fetch diff**: `gh pr diff <number>` — get the full changeset.
3. **Collect existing feedback first**: before drafting anything, read the full PR discussion.

```bash
# General PR conversation
gh pr view <number> --comments

# Line-specific review comments
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate

# Review summaries / states
gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate
```

Treat issues other reviewers already raised as **prior art** — your findings must be **net-new**. Reply in the existing thread rather than reposting, and add a fresh comment only when you have materially new information: a different root cause, a higher-severity impact, a more precise file/line, or a concrete fix the thread lacks. When in doubt, collapse the duplicate — the goal is signal, not vote-counting.

4. **Gather codebase context**: Expand understanding outward from the diff using the structured protocol in Phase 1.5 below. Depth depends on PR risk — at minimum, read full files and find callers of changed functions.
5. **Systematic review**: Follow the Review Process below.
6. **Submit review to GitHub** — always post the review. Never just show it in conversation.

Build a temporary JSON file containing the summary body, verdict event, and any inline comments, then submit it as a single atomic review. This ensures the summary appears in the Conversation tab and inline comments appear in the Files Changed tab, all grouped as one review.

```bash
# 1. Determine owner/repo and head commit
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
HEAD_OID=$(gh pr view <number> --json headRefOid -q .headRefOid)

# 2. Build the review payload as a JSON file
cat > /tmp/review.json << 'REVIEW_EOF'
{
  "body": "## Code Review Summary\n\n...",
  "event": "COMMENT",
  "comments": [
    {
      "path": "src/file.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "**[BLOCKER]** Brief title\n\n**Issue**: ...\n**Why it matters**: ...\n**Suggestion**:\n```lang\n// fix\n```"
    }
  ]
}
REVIEW_EOF

# 3. Submit the review (inline comments + summary in one call)
gh api repos/${OWNER_REPO}/pulls/<number>/reviews --input /tmp/review.json
```

Set `event` based on verdict:

| Verdict | `event` value |
| --- | --- |
| Approve | `APPROVE` |
| Request changes | `REQUEST_CHANGES` |
| Comment only | `COMMENT` |

The `comments` array contains inline comments that appear in the Files Changed tab. Each entry needs `path`, `line`, `side` (always `"RIGHT"` for new code), and `body`. Omit the `comments` array if no line-specific findings — the summary body still posts as a review comment.

If the review has no inline findings at all (e.g., a simple approval), you can use the simpler CLI form instead:

```bash
gh pr review <number> --approve --body "..."
gh pr review <number> --request-changes --body "..."
```

---

## Review Process

### Phase 1: Context and Scope

- Read the PR description and commit messages carefully.
- Understand the problem being solved and the proposed approach.
- Map out which files changed and how they interact with the broader system.
- Check for linked issues, related PRs, or migration dependencies.

### Phase 1.5: Codebase Context Gathering

Before evaluating architecture or correctness, build a working model of how the changed code fits into the system. Work outward from the diff in layers. Scale depth to PR risk.

**Layer 1 — Full file read** (always)

Read the COMPLETE file for every changed file, not just diff hunks. The diff alone hides surrounding invariants, sibling functions, and class structure that affect whether the change is correct.

**Layer 2 — Direct dependents and dependencies** (always)

For each changed file, identify:
- What it imports (dependencies) — read key imported modules to understand the contracts the changed code relies on.
- What imports it (dependents) — find with `rg "import.*from.*<module>"` or `rg "require.*<module>"` across the repo. These are the files that may break.

For each changed function, class, type, or exported symbol:
- Find all callers: `rg "<symbol>\b" --type <lang>` across the repo.
- Check whether signature, return type, or behavioral changes break any caller.

**Layer 3 — Data flow tracing** (when changes touch I/O, APIs, or user input)

Trace data through the change end-to-end:
- Where does input originate? (API endpoint, UI form, message queue, cron job)
- What transformations or validations does it pass through?
- Where does it end up? (DB write, rendered output, external API call, log)

Read each file along the path, not just the changed ones. This catches missing validation, auth gaps, and injection points that live outside the diff.

**Layer 4 — Convention sampling** (when changes introduce new patterns or touch unfamiliar areas)

Find 2-3 existing files that do something similar:
- `rg -l "<pattern>" --type <lang>` or browse sibling files in the same directory.
- Compare error handling, naming, structure, logging, and test patterns.
- Flag deviations from the dominant codebase convention.

**Layer 5 — History and churn** (when changes touch complex or bug-prone areas)

```bash
# Recent change velocity — high churn = higher scrutiny
git log --oneline -10 -- <changed_file>

# When was this symbol last modified and why?
git log --oneline --all -S "<changed_function>" -- <changed_file>

# Who owns this area? (for context, not blame)
git shortlog -sn --no-merges -- <changed_file>
```

**Depth control** — scale to risk:

| PR Risk Level | Examples | Layers |
| --- | --- | --- |
| Trivial | Docs, config, formatting, typo fixes | 1 only |
| Standard | Feature work, refactors, test additions | 1-2 |
| Risky | Auth, payments, DB schema, public API, concurrency | 1-5 |

When in doubt, do at least Layers 1-2. A review without caller analysis misses breaking changes.

### Phase 2: High-Level Architecture

- Does the change fit the existing architecture and conventions?
- Are there design concerns: tight coupling, missing abstractions, separation of concerns violations?
- Is this the simplest reasonable approach for the problem?
- Does this introduce technical debt that should be addressed now?
- Are there simpler alternatives worth proposing?

### Phase 3: Line-by-Line Analysis

| Dimension      | What to Look For                                                                                        |
| -------------- | ------------------------------------------------------------------------------------------------------- |
| Correctness    | Logic errors, off-by-one, null/undefined handling, edge cases, boundary conditions                      |
| Security       | Input validation, injection points (SQL, XSS, command), auth/authz gaps, secrets exposure, OWASP top 10 |
| Performance    | N+1 queries, heavy allocations in loops, algorithm complexity, resource leaks, missing pagination       |
| Concurrency    | Race conditions, deadlocks, unsafe shared mutable state, missing locks/atomic operations                |
| Error Handling | Swallowed exceptions, missing error context, improper error propagation, empty catch blocks             |
| Testing        | Coverage of new logic, edge case tests, test quality (meaningful assertions, not just existence)        |
| Observability  | Logging for debugging, metrics for monitoring, tracing for distributed systems                          |
| Code Quality   | Naming clarity, function length/complexity, DRY violations, single responsibility                       |

### Phase 4: Summary and Verdict

- Compile findings into the structured output template.
- Assign a confidence score.
- Render verdict: APPROVE, REQUEST_CHANGES, or COMMENT.

---

## Severity System

| Tag            | Meaning                                                                | Action Required           |
| -------------- | ---------------------------------------------------------------------- | ------------------------- |
| `[BLOCKER]`    | Security vulnerability, data loss risk, crash, correctness bug         | Must fix before merge     |
| `[MAJOR]`      | Logic error, missing edge case, architectural violation, missing tests | Must fix or justify       |
| `[SUGGESTION]` | Refactoring opportunity, readability improvement, optimization         | Recommended, not blocking |
| `[NIT]`        | Style, naming preference, trivial formatting                           | Optional, author's call   |
| `[KUDOS]`      | Exemplary code, clever solution, good pattern usage                    | No action — recognition   |

---

## Feedback Techniques

Phrasing craft — how to word findings so they land:

- **Write it clearly.** Run the `/writing-clearly-and-concisely` skill and apply it to every finding, the summary body, and PR comments — plain, tight, no filler.
- **Ask, don't assert.** "What happens if this input is empty?" invites reflection more than "This fails on empty input."
- **Suggest, don't command.** "Consider a Map here for O(1) lookups" over "Use a Map." Offer alternatives as possibilities.

---

## Confidence Scoring

Rate overall review confidence on a 1-5 scale.

| Score | Meaning                                                         |
| ----- | --------------------------------------------------------------- |
| 5/5   | Trivial or perfectly understood change, full context            |
| 4/5   | Well-understood change, minor areas of uncertainty              |
| 3/5   | Moderate complexity, some logic paths or side effects unclear   |
| 2/5   | Complex change, significant uncertainty or domain unfamiliarity |
| 1/5   | Very complex, likely issues missed                              |

**Adjustment rules** — subtract 1 for each that applies:

- Database migrations or schema changes
- Authentication or security-sensitive logic
- Complex concurrency or lock management
- Large-scale cross-cutting refactors
- Missing or inadequate test coverage
- Unfamiliar language or domain

For PRs touching multiple files with varying complexity, include a per-file confidence table in the review summary (see the File-Level Confidence table in Output Templates).

---

## Language-Specific Patterns

When the diff includes Python or TypeScript, consult `references/language-patterns.md` for language-specific bad/good examples and checklists (type hints, resource management, typed errors) plus cross-language patterns (N+1 queries, XSS, SQL injection, auth). Apply them alongside the Phase 3 dimensions.

---

## Output Templates

### Inline vs Summary Strategy

The atomic review API (see PR Review pipeline step 6) handles both inline and summary comments in one call. The summary body and inline comments serve different purposes — when used well they compose; when confused they duplicate.

**Core rule: the summary is an index, the inlines are the content.**

If a finding has a file and line, its full detail (issue, why it matters, suggested fix, test to add) lives in the inline comment. The summary references it by severity ID (B1, M1, S1) in the findings table — one row, one sentence. A reader should see severity distribution at a glance in the summary, then click through to the inline for the actual patch.

Why this matters: GitHub renders the summary in the Conversation tab and inlines in the Files Changed tab. Restating the same finding in both tabs forces the author to read it twice, visually inflates the PR page, and creates drift risk if one copy is updated and the other isn't. Keep the summary lean — resist the urge to "helpfully" restate inline content in a collapsible block.

| Finding type | Where it goes | Summary mention |
| --- | --- | --- |
| BLOCKER / MAJOR with a clear file:line | `comments` array entry (full detail) | One row in findings table |
| SUGGESTION / NIT on a specific line | `comments` array entry (keep brief) | One row in findings table |
| Architectural / cross-cutting concern spanning files | `body` summary (full detail) | Written out — no inline exists |
| Overall verdict, confidence, strengths (KUDOS) | `body` summary | N/A — can't live inline |

Avoid 20+ inline comments — group related nits into one inline on a representative line, or roll them into the summary only if they're truly cross-cutting. Each inline comment should stand alone and be actionable without reading the summary.

### Review Summary

Use this template for both local and PR reviews. Keep it lean — the summary is the index into inline comments, not a restatement of them.

````markdown
## Code Review Summary

**Scope**: [Brief description of the changes]
**Files Changed**: [N files, +X/-Y lines]
**Confidence**: [N/5] — [Brief justification]

### Findings

| Sev | Severity     | File                | Description       |
| --- | ------------ | ------------------- | ----------------- |
| B1  | [BLOCKER]    | path/to/file.ts:42  | One-line summary — full detail inline |
| M1  | [MAJOR]      | path/to/other.py:15 | One-line summary — full detail inline |
| S1  | [SUGGESTION] | path/to/lib.rs:88   | One-line summary — full detail inline |

Each row is a pointer to the matching inline comment. Do not expand findings here — the inline carries the issue, why it matters, suggested fix, and test to add. Include a `### Cross-cutting Concerns` section below *only* for findings that span multiple files or have no single line to attach to.

### File-Level Confidence

| File             | Confidence | Notes                 |
| ---------------- | ---------- | --------------------- |
| path/to/file.ts  | 3/5        | Complex auth logic    |
| path/to/other.py | 5/5        | Simple utility change |

### Strengths

- [Thing done well]
- [Another positive observation]

### Verdict: APPROVE | REQUEST_CHANGES | COMMENT

[Brief justification for the verdict]
````

### Progressive Disclosure in the Summary

For large reviews, keep the verdict and findings table above the fold -- that is the reviewer's need-to-know. Genuinely secondary, *summary-only* sections can go in `<details>` blocks so they don't push the verdict down: a File-Level Confidence table with many rows, Strengths/KUDOS, or a long context/methodology note.

This is distinct from the anti-pattern in "Inline vs Summary Strategy": collapse summary-only material that is truly secondary -- never a restatement of inline findings (those live in the Files Changed tab). Blockers and majors are never collapsed; they are the whole point of the review.

### GitHub Comment Formatting Rules

When posting comments to GitHub (both inline and summary):

- **Never use `#N` notation** (e.g., `#1`, `#2`, `#3`) — GitHub auto-links these to issues/PRs, creating broken references. Use severity-prefixed IDs instead: `B1`, `M1`, `S1`, `N1` (for Blocker, Major, Suggestion, Nit).
- **Never reference findings as "issue #1"** — write "finding B1" or just use the severity tag.
- Keep inline comment bodies self-contained — the author reads them in the diff without needing context from the summary.
