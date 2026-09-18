---
name: pr
description: "Write, draft, revise, or update a pull-request body or description from repository evidence. Use for the PR text itself, not for creating, managing, reviewing, or commenting on pull requests."
adaptedFrom:
  - "https://github.com/mattpocock/skills/blob/main/skills/in-progress/pr/SKILL.md"
---

# PR Body

Produce the body only. Do not create a PR, authenticate, invoke GitHub tooling, post comments, or perform review operations; `gh` owns those operations.

## Gather the body

1. Inspect a repository PR template first. Preserve every existing heading and its order. Append only missing required sections; do not rename, remove, or reorder template headings. Without a template, use the fallback sections below in order.
2. Ground each claim in actual work evidence, in this order: the current conversation or task source, the committed branch diff against its base, commit messages, and completed verification evidence. Do not infer unobserved behavior.
3. Discover tracker references in this order: conversation/task source, branch name, commit messages, then the PR template or repository metadata. Include every directly relevant reference once, with the primary first. Accept Jira, Linear, GitHub Issues, and other tracker references as presented; do not use tracker-specific parsing or network queries.

## Required content

- **Summary:** Use a visual only when it makes the change easier to understand; otherwise write one or two sentences. Read [`references/visual-summary.md`](references/visual-summary.md) **only when a visual would help**.
- **Changes:** Use concise, typed bullets: `[feature]`, `[bugfix]`, `[test]`, `[perf]`, `[docs]`, `[style]`, or `[refactor]`.
- **Evidence:** State only completed, evidence-backed verification. When needed proof is unavailable, write `<MISSING_EVIDENCE>` rather than claiming success.
- **Merge Danger:** Keep it concise: whether rollback is a one-way or two-way door and the blast radius, with the concrete risk when one exists.
- **References:** List every directly relevant tracker reference, deduplicated with the primary first. For a key without a URL, use a linked placeholder that preserves it: `- [PROJ-123](<TRACKER_URL>)`. When none exists, emit exactly:

  ```markdown
  ## References
  - N/A
  ```

## Structure

Without a repository template, use:

```markdown
## Summary

<one or two sentences, or a useful visual>

## Changes

- [feature] <concise change>

## Evidence

- <completed command/check and observed result, or <MISSING_EVIDENCE>>

## Merge Danger

**Door:** <one-way | two-way>
**Blast Radius:** <scope>

<concrete risk, when applicable>

## References

- <tracker reference, or N/A>
```

With a template, retain its headings and order exactly, then append any semantically absent section from the fallback structure. Preserve evidence-backed release footers when relevant: `BREAKING_CHANGE`, `REBUILD_DOWNSTREAM`, `BUMP_DOWNSTREAM`, and `UNSTABLE_VERSIONS`. Use `BUMP_DOWNSTREAM` only for version-branch merges; never invent a footer.

## Reviewer help

- Link a companion PR once when work spans repositories; do not duplicate its details.
- For a large or mechanical diff, add a short Reviewer Guide: where to start, the behavioral risk, one representative bulk file to skim, then docs/tests.
- Put secondary rationale, long enumerations, and extended verification in `<details>` only when they would bury the essential summary, changes, merge danger, or required footers. Keep merge-critical information visible.
