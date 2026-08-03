---
name: github-pr-management
description: "(project - Skill) Manage GitHub pull requests: create/update PR descriptions, add/edit PR comments, review PRs. Triggers on: 'create PR', 'update PR description', 'comment on PR', 'review PR', 'edit PR', 'PR summary', 'add PR comment', or any reference to pull request management. Use when the user wants to write, edit, or manage PR descriptions, comments, or reviews on GitHub Enterprise or github.com."
---

# GitHub PR Management

## Prerequisites: Authentication

Before any PR operation, verify `gh` CLI authentication:

```bash
gh auth status
```

- If authenticated: proceed.
- If NOT authenticated: **STOP. Prompt the user to configure `gh` CLI first** (`gh auth login`). Do not attempt any PR operations until auth succeeds.
- For enterprise GitHub instances: the user must have already authed via `gh auth login --hostname <host>`. The `gh` CLI routes to the correct host based on the repo's git remote. Do not manually set `GH_HOST`.

## Jira URL Parsing

When the user provides a Jira URL, extract the base URL and ticket key for use in Footers. **Do not fetch or interact with the Jira instance.**

Jira URLs follow this pattern: `https://<HOST>/browse/<TICKET_KEY>`

**Parse rules:**
- **JIRA_BASE_URL** = everything before `/browse/`
- **TICKET_KEY** = path segment after `/browse/`, stripped of trailing `/`, `?`, `#` and anything after
- Ticket keys match `<PROJECT>-<NUMBER>` (uppercase letters, hyphen, digits)

| Input URL | JIRA_BASE_URL | TICKET_KEY |
|-----------|---------------|------------|
| `https://jira.company.com/browse/PROJ-123` | `https://jira.company.com` | `PROJ-123` |
| `https://team.atlassian.net/browse/ENG-456?filter=open` | `https://team.atlassian.net` | `ENG-456` |
| `https://jira.internal.co/browse/PLAT-78/` | `https://jira.internal.co` | `PLAT-78` |

## PR Description

### 1. Check for PR Template

Always check for a PR template first:

```bash
# Common template locations
.github/PULL_REQUEST_TEMPLATE.md
.github/pull_request_template.md
docs/pull_request_template.md
PULL_REQUEST_TEMPLATE.md
```

If a template exists, follow its structure exactly. If not, use the format below.

### 2. Writing Style

- **Be concise.** Reviewers scan, not read. One-line summary, bullet changes, done.
- **No duplication.** If info exists in a companion PR or comment, link to it -- don't repeat.
- **No prose paragraphs.** Use tables and bullets.
- **Precise change types.** Use the verb that matches: "Add" = new, "Update" = enhance existing, "Fix" = bug.

### 3. Description Structure

```markdown
## Summary

<1-2 sentences: what changed and why>

## Changes:
- [change_type] Concise description of change
- [change_type] Another change

## Footers:
- Change: <JIRA_BASE_URL>/browse/<TICKET>
- Epic: <JIRA_BASE_URL>/browse/<EPIC>
```

**Variables:** If the user provided a Jira URL, parse it per the "Jira URL Parsing" section above to extract JIRA_BASE_URL, TICKET_KEY, and EPIC. If no Jira URL was provided, prompt the user. If the user defers, use placeholders (`<JIRA_BASE_URL>`, `<TICKET>`, `<EPIC>`) and move on.

For large or multi-file PRs, also append a **Reviewer Guide** (see §7) so reviewers know where to start and what they can safely skim.

### 4. Change Types

| Type | When to Use |
|------|-------------|
| `bugfix` | Fix for incorrect behavior |
| `feature` | New functionality |
| `test` | Adding or fixing tests only |
| `perf` | Performance improvement |
| `docs` | Documentation only |
| `style` | Formatting, whitespace, no logic change |
| `refactor` | Code restructure, no behavior change |

Format: `- [feature] Added X` or `- [bugfix] Fixed Y`

### 5. Footers

| Footer | Required | Description |
|--------|----------|-------------|
| `Change` | **Yes** | JIRA ticket. `Change: <JIRA_BASE_URL>/browse/<TICKET>` |
| `Epic` | **Yes** | JIRA epic. `Epic: <JIRA_BASE_URL>/browse/<EPIC>` |
| `BREAKING_CHANGE` | No | Presence = major version bump |
| `REBUILD_DOWNSTREAM` | No | Rebuild listed libs on main. `REBUILD_DOWNSTREAM: lib-a, lib-b` |
| `BUMP_DOWNSTREAM` | No | **High risk.** Patch downstream version branches. Only on version branch merges. |
| `UNSTABLE_VERSIONS` | No | Versions that won't get this fix. `UNSTABLE_VERSIONS: 1.4.X, 1.5.X` |

### 6. Companion PRs

When changes span multiple repos, link companion PRs:

```markdown
### Companion PR
[repo-name #N](url) -- one-line description
```

### 7. Reviewer Guide (large or mechanical PRs)

For PRs that touch many files -- especially when a small high-signal core sits alongside a large, repetitive bulk -- append a **Reviewer Guide** that tells reviewers where to start and what they can skim. Knowing where the risk lives makes review faster and better.

**Include it when:** the diff is large (rough rule: 10+ files or several hundred lines), the change mixes a mechanical/repetitive bulk with a few load-bearing files, or a reviewer wouldn't otherwise know which files matter.

**Rank files by review value, not by directory** -- highest-signal first, skimmable bulk last. Echo the real file count in the heading so scope is clear up front. Template:

> ## How to review N files
> 1. **Start here** -- the contract / entry points: the few files that define the change (interfaces, the one gate/seam, config).
> 2. **The one behavioral risk** -- the file(s) that can actually change runtime behavior; everything else is lower-risk.
> 3. **The bulk** -- name the repetitive change once, point to ONE reference file as the example, and say "skim one, the rest look the same."
> 4. **Docs / tests** -- pointers, reviewed last.

**Rules:**
- Be honest about risk -- the whole value is separating "scrutinize this" from "trust this." Never bury the risky file in the bulk.
- For repetitive changes, name a concrete reference file so reviewers don't re-read the same pattern N times.
- Skip it for small, focused PRs -- a 3-file change doesn't need a map.

### 8. Progressive Disclosure (keep the first screen scannable)

A reviewer's first screen should carry only what they *need to know* to start: the summary, the change list, and any breaking-change or required footers. Everything *nice to know on demand* -- the "why" rationale, verification evidence, long enumerations, out-of-scope notes, migration detail -- belongs in a GitHub `<details>` block, one click away instead of pushing the essentials below the fold.

Use it when the description would otherwise make a reviewer scroll past secondary detail to find the changes. Skip it for short descriptions -- collapsing three lines helps no one.

```markdown
<details>
<summary>Why <decision> (rationale)</summary>

<reasoning, references, trade-offs>
</details>

<details>
<summary>Verification</summary>

<how it was tested, commands, evidence>
</details>
```

**Never collapse the need-to-know.** The changes, breaking-change warnings, and required footers stay visible -- collapsibles add depth, they don't hide things a reviewer must act on. A good test: if a reviewer skips every collapsed block, they should still understand *what* the PR does and whether it's safe to merge.

## PR Comments

- Use comments for supplementary context (flowcharts, diagrams, design rationale) that doesn't belong in the description.
- Keep comments self-contained -- reader shouldn't need to cross-reference the description to understand the comment.
- No duplication with PR description. If the description covers it, don't repeat in comments.
- Mermaid diagrams are supported -- use for flow visualization.

## PR Review Comments

When reviewing code, be:
- **Specific**: Point to exact lines, suggest exact fixes
- **Constructive**: "Consider X because Y" not "This is wrong"
- **Scoped**: Comment on what changed, not pre-existing issues
