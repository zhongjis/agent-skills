---
name: code-review-v2
description: "Multi-axis code review for local diffs (git/jj) and GitHub PRs — independent review axes reported as isolated passes so no axis masks another."
disable-model-invocation: true
adaptedFrom:
  - "https://github.com/wshobson/agents/blob/main/plugins/developer-essentials/skills/code-review-excellence/SKILL.md"
  - "https://github.com/mattpocock/skills/blob/main/skills/engineering/code-review/SKILL.md"
---

# Code Review

A review runs as a set of independent **axes** — each a single lens (correctness, standards, regression, security, and conditional spec / performance / tests / observability) that produces its own findings. Axes run as **isolated passes** and are reported side by side, so a pass on one axis never masks a fail on another.

**Modes**: Local Review (git/jj diff) | PR Review (gh CLI). PR review prefers a local checkout — see `references/pr-workflow.md` § 0.

## Principles

- **Critique the code, not the person.** No sarcasm or condescension — every line represents effort.
- **Every finding leads to a better solution.** Cite the exact line, include a fix example, and explain *why* it matters. Vague feedback is useless.
- **Code health over perfection.** Approve changes that improve overall health even when imperfect; never block on style or personal preference.
- **Keep review focused.** Under 400 LOC per session — defect detection collapses past that. Let tooling catch formatting; spend human attention on architecture and behavior. Split larger changes.
- **Acknowledge good work.** Use `[KUDOS]` for exemplary sections — it reinforces standards.
- **Scope to the actual change.** Raise unrelated issues or feature ideas elsewhere, not in this review.

## Review process

Run these steps in order. Steps 1-3 run once, inline, in the main reviewing context and build the shared **foundation brief** — a fixed-field record every axis reads verbatim:

> **Mode** · **Risk** · **Behavior delta** · **Security depth** · **Active axes**

1. **Pin scope, mode + risk.** Fix the comparison point, note the mode, and classify the change's **Risk** — Trivial / Standard / Risky (see Risk dial; it is scope-level, readable from `git diff --stat` and the touched paths).
   - Local: `git diff <base>...HEAD` (three-dot, so the comparison is against the merge-base) or `jj diff`; `git diff --stat` for scope; `git log <base>..HEAD --oneline` for commits.
   - PR: follow `references/pr-workflow.md` — prefer a local checkout (§ 0), then gather PR metadata and pin scope.
   - Confirm the base resolves (`git rev-parse <base>`) and the diff is non-empty before going further — a bad ref or empty diff fails here, not inside an axis.
2. **Gather context + fetch links.** Read each changed file in full, not just the hunks. For every changed symbol, find its callers. Follow any links you encounter — the PR description, commit messages, linked issues or tickets, a path the user passed — and fetch the ones your environment can reach, so behavior and intent rest on real context. Scale depth to the Risk you pinned; `references/context-gathering.md` has the concrete caller / history / churn commands.
3. **Build the foundation brief.** Fill the record once:
   - **Behavior delta** — what observable behavior the change adds, removes, or alters. Descriptive, not a finding; it feeds every axis.
   - **Security depth** — whether the diff touches a **security surface** (input boundary, auth/authz, secrets, deserialization, SQL / shell / HTML sinks, network, file paths). This sets Security's depth and may **upgrade** the Risk you pinned in step 1.
   - **Active axes** — from the Axis registry, every always-on axis plus each conditional axis whose trigger the triage hit.
4. **Run each active axis in isolation.** Run the axes as isolated passes per the Execution rule. Each axis reads the foundation brief and its section in `references/axis-checklists.md`, then reports findings under its own heading — stating "no findings" when it finds nothing.
5. **Aggregate + verdict + post.** Combine per the Aggregation rules, render the verdict, and post (PR: via `references/pr-workflow.md`).

## Axis registry

| Axis | Runs when | Looks for | Checklist |
| --- | --- | --- | --- |
| Correctness | always | logic, edge cases, null/undefined, boundaries, concurrency, error handling — inward: is the new code right? | `axis-checklists.md` |
| Standards | always | conventions, naming, structure, Fowler code smells, non-behavioral quality | `axis-checklists.md` |
| Regression | always | callers, contracts, migrations, backward compatibility — outward: what could this break? | `axis-checklists.md` |
| Security | always (triage); deep pass only when a security surface is touched | injection, auth/authz, secrets, sensitive data, OWASP / STRIDE | `axis-checklists.md` |
| Spec | a spec source exists — PR description, commits, linked issue/ticket, or a path provided | missing or partial requirements, scope creep, a requirement implemented wrong | `axis-checklists.md` |
| Performance | diff touches hot paths, loops, queries, or allocations | N+1 queries, algorithmic complexity, resource leaks, missing pagination | `axis-checklists.md` |
| Tests | tests are present or expected for the change | coverage of new logic, edge-case tests, assertion quality | `axis-checklists.md` |
| Observability | change is operationally significant — services, error paths, external calls | logging, metrics, tracing | `axis-checklists.md` |

Every axis is a cheap triage first — does it apply, and how deep? — then a gated deep pass. Security is the most visible case of that rule, not an exception to it.

## Risk dial

Scale which axes fire and how deep the context work goes to the change's risk.

| Risk | Examples | Axes | Context depth |
| --- | --- | --- | --- |
| Trivial | docs, config, formatting, typo fixes | always-on axes at triage depth (Standards carries it) + Spec if a source exists | full file read only |
| Standard | feature work, refactors, test additions | all always-on + triggered conditionals | changed files + callers |
| Risky | auth, payments, DB schema, public API, concurrency | all applicable, deep passes | full data-flow tracing, history, convention sampling |

## Execution

An **isolated pass** runs one axis in its own fresh context, sharing nothing with the others — so no axis can color another. When your environment offers an isolation mechanism (a sub-agent or task tool is the usual one) and the risk is not Trivial, running the axes as isolated passes is **required, not a preference**: dispatch per `references/parallel-axes.md`, which bundles them into a few passes scaled to risk so isolation doesn't cost eight diff re-feeds. The foundation brief feeds each pass; it never replaces them — you remain the aggregator who re-checks every pass (§ Aggregation).

**Capability floor.** Give each pass enough capability and budget for its risk. Security, Correctness, and Regression are judgment axes — never run them as a reduced or recon-only pass; a Risky review needs your strongest reasoning throughout.

**Fallback.** Only when no isolation mechanism is available, or the risk is Trivial, fall back to **sequential inline** passes in one shared context. This fallback is weaker — one shared context is exactly where masking happens — so run each axis as its own deliberate pass: reset to that axis's brief, write its findings under its heading, and finish it before the next.

If an isolated pass fails, stalls, or returns empty, re-run it per `references/parallel-axes.md` — a silent drop must never read as "no findings".

## Severity

| Tag | Meaning | Action |
| --- | --- | --- |
| `[BLOCKER]` | security hole, data-loss risk, crash, correctness bug | blocking — fix before merge |
| `[MAJOR]` | logic error, missing edge case, architectural violation, missing tests | blocking — fix or justify |
| `[SUGGESTION]` | refactor, readability, optimization | non-blocking — recommended |
| `[NIT]` | style, naming preference, formatting | non-blocking — author's call |
| `[KUDOS]` | exemplary code, good pattern | recognition |

Assign severity **within each axis**. `[BLOCKER]` and `[MAJOR]` are blocking; the rest are non-blocking.

## Aggregation

**Re-check dispatched findings first.** Independently verify each dispatched finding against the code and its contract and re-severitize before assembling — dispatched severities are inputs, not final. This is within-axis validation against ground truth, not cross-axis re-judging: keep each axis's grouping intact, and a severity you overturn is also reason to lower that axis's confidence. Tighten each finding's prose in the same pass — active voice, no filler, no puffery (§ Feedback craft); a finding that reads loose isn't done.

Copy the re-checked findings into the report unchanged, under that axis's heading. Build the findings table by grouping stably on (axis, severity), keeping every axis's rows distinct.

- **Completion criteria** — two gates, both required to keep one axis from masking another:
  1. Each active axis ran in its own isolated pass whenever an isolation mechanism was available; only the Trivial or no-isolation fallback runs axes inline in one shared context.
  2. Every active axis is accounted for — it ran and its result is recorded, so none is silently dropped. A first/full review renders each axis as its own labeled group, including those that found nothing (which state "no findings"); an incremental re-review follows the § 2c contract — it MUST open with the § 2c opener line and index only new findings (no empty axes, no Strengths), never re-rendering this first-review skeleton (`references/pr-workflow.md` § 2c).
- **Verdict** is the only value computed across axes: `REQUEST_CHANGES` if any axis produced a `[BLOCKER]` or `[MAJOR]`, otherwise `COMMENT` or `APPROVE`. Compute it last, from the assembled findings; it never changes an individual finding.
- **Confidence** — each axis scores itself 1-5, lowering its own score for the risk multipliers it owns (see Confidence adjustments); the overall confidence is the **minimum** across active axes. Name the axis that set it and why.

### Confidence adjustments

Each axis drops its own score by 1 (floor 1) for every multiplier it carries. Two axes dropping for the same broad multiplier is two independent reasons to distrust two reads, not double-counting:

- **Security** — auth / authz or otherwise security-sensitive logic.
- **Regression** — database migrations or schema changes.
- **Correctness** — complex concurrency or lock management.
- **Tests** — missing or inadequate coverage for the change.
- **Every active axis** — a large cross-cutting refactor, or an unfamiliar language / domain.
- **Any axis folded inline after a failed isolated pass** — drop 1 and flag the fallback in that axis's output group, so a degraded read never passes as a clean one. (The Trivial / no-isolation baseline, where every axis runs inline by design, carries no such penalty.)

## Output

Use this skeleton for a first/full review in both modes. It is an index into the findings, not a restatement of them. Keep the verdict and findings table above the fold; blockers and majors are never collapsed. The **verification / methodology note is always collapsed** in `<details>`, whatever the review size; the per-file confidence table and strengths collapse on large reviews. A PR **incremental re-review** uses the lean output contract in `references/pr-workflow.md` § 2c instead of re-rendering this skeleton.

````markdown
## Code Review Summary

**Scope**: [what changed] · **Files**: [N files, +X/-Y] · **Confidence**: [min N/5 — the axis that set it, and why]

### Findings

| ID | Axis | Sev | Location | Summary |
| --- | --- | --- | --- | --- |
| B1 | Security | [BLOCKER] | path/to/file:42 | one line — full detail inline |
| M1 | Regression | [MAJOR] | path/to/other:15 | one line — full detail inline |

On a first/full review, axes with no findings are listed explicitly, e.g. "Correctness — no findings". An incremental re-review omits them and indexes only new findings (`references/pr-workflow.md` § 2c).

<details><summary>Per-file confidence</summary>

Only files whose confidence deviates from the overall — omit files that match it.

| File | Confidence | Notes |
| --- | --- | --- |
| path/to/file:42 | 2/5 | complex auth path |

</details>

<details><summary>Strengths</summary>

- `[KUDOS]` — exemplary section worth reinforcing.

</details>

<details><summary>Verification</summary>

Commands, suites, and live checks run to ground the review, with results. Always collapsed, whatever the review size.

</details>

### Verdict: APPROVE | REQUEST_CHANGES | COMMENT

[one-line justification]
````

For PR reviews, the inline-vs-summary strategy, GitHub comment formatting rules, the atomic-review pipeline, the AI attribution footer, and incremental re-review scoping and output live in `references/pr-workflow.md`.

## Feedback craft

- **Write it tight.** Apply to every finding, the summary, and PR comments: active voice; positive form (say what *is*, not what isn't); cut needless words; concrete and specific over vague; no AI puffery (`delve`, `leverage`, `seamless`, `robust`, `crucial`, `testament`). See `writing-clearly-and-concisely` for depth.
- **Ask, don't assert.** "What happens when this input is empty?" invites reflection more than a flat claim.
- **Suggest, don't command.** "Consider a Map here for O(1) lookups" over "Use a Map." Offer alternatives as possibilities.

## References

- `references/axis-checklists.md` — per-axis deep checklists; load the sections for the active axes.
- `references/parallel-axes.md` — isolated-pass dispatch, the self-contained brief template, bundling, and aggregation mechanics.
- `references/context-gathering.md` — the concrete caller / history / churn commands for the Gather-context step, scaled to the Risk dial.
- `references/pr-workflow.md` — GitHub PR pipeline: collect prior feedback, incremental re-review scoping and output, atomic review API, AI attribution footer, comment formatting.
- `references/language-patterns.md` — Python / TypeScript bad/good examples, applied within Correctness, Standards, and Security.
