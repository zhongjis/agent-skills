---
name: pr
description: "Draft or revise pull-request body text from repository evidence, including an existing body or PR template. Use whenever asked for PR description text; use `gh` for generic GitHub operations."
adaptedFrom:
  - "https://github.com/mattpocock/skills/blob/main/skills/in-progress/pr/SKILL.md"
---

# PR Body

`pr` produces the body text. `gh` performs generic GitHub CLI, authentication, PR, comment, and review operations. For a combined request, draft the body here, then hand the requested GitHub operation and completed body to `gh`.

## UI media routing

For a user-visible UI change, route to `before-and-after` only when the user requests screenshot or recording evidence, or asks for a review-ready published PR. Draft or revise the body first; `before-and-after` coordinates the visual-evidence workflow and owns media attachment, while `agent-browser` owns capture mechanics.

- New PR: draft the body → `gh` creates the PR → `before-and-after` adds the media.
- Existing PR: revise the body if needed, then hand the PR to `before-and-after`; do not create another PR.
- A body-only UI request does not authorize capture or publication. Preserve supplied media references without capturing or publishing media.
- Backend or otherwise non-visible changes do not route to `before-and-after`.

Prefer real UI evidence to synthetic diagrams. [`references/visual-summary.md`](references/visual-summary.md) remains for structural or flow explanations.

## Choose the structure

1. If the user supplied an existing body to revise, revise that body. Preserve its meaningful headings and order.
2. Otherwise inspect repository PR templates. Use the explicitly requested template, the sole template, or a clearly applicable template. If several templates fit and none is clearly selected, ask the user to choose; do not guess.
3. With no applicable template, use the fallback structure below.
4. Treat headings with equivalent meaning as present (for example, `Testing` for evidence, `Risks` for merge danger, or `Links` for references). Fill that heading rather than adding a duplicate generic section. Preserve retained heading text and order; append only semantically absent fallback sections.

## Ground the body

Keep the evidence roles separate:

- The task or conversation establishes intent.
- The branch diff establishes the actual change.
- Commits provide supporting context, not proof.
- Completed observed command, test, or review results establish verification.

Write concise, ordinary change bullets unless a repository convention requires labels. State only completed verification; use `<MISSING_EVIDENCE>` exactly when required proof is unavailable. Keep merge risk brief: identify the door (one-way or two-way), blast radius, and concrete irreversible or rollout risk when one exists.

Discover references in this order: supplied or current body, task or conversation, branch name, commits, then explicit companion-change evidence. Keep only directly relevant references, primary first; templates and placeholders are not references. Preserve supplied URLs exactly; render a plain supplied key without inventing a URL or placeholder (for example, `- ACME-42`). When no reference exists, place `- N/A` under the existing reference-equivalent heading, or add:

```markdown
## References
- N/A
```

Preserve or include a footer only when the template, repository guidance or convention, or supplied evidence requires it; never invent one.

## Fallback body

```markdown
## Summary

<one or two sentences, or a useful visual>

## Changes

- <concise change>

## Evidence

- <completed command/check and observed result, or <MISSING_EVIDENCE>>

## Merge Danger

**Door:** <one-way | two-way>
**Blast Radius:** <scope>

<concrete risk, when applicable>

## References

- <tracker reference, or N/A>
```

## Optional reviewer help

- Read [`references/visual-summary.md`](references/visual-summary.md) for an ownership, structural, or flow explanation; otherwise use concise prose.
- Link one companion PR when work spans repositories; keep its details there.
- For a large or mechanical diff, add a short Reviewer Guide: where to start, behavioral risk, one representative bulk file, then docs/tests.
- Put secondary rationale, long enumerations, and extended verification in `<details>` only when they would bury essential content; keep merge-critical content visible.

## Completion check

Before returning the body, confirm its structure follows the selected existing body or template (or fallback), every change claim is supported by the diff, evidence contains only completed results or `<MISSING_EVIDENCE>`, references preserve supplied values, and required footers are evidence-backed. Route generic GitHub operations and PR creation to `gh`; for authorized user-visible UI media, route capture and attachment to `before-and-after` in the required order.
