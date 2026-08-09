---
name: find-skills
description: "Discover and recommend external skills from the open agent skills ecosystem. Discovery only: qualify candidates, resolve a maintenance-ready handoff, then route all add, install, update, remove, and audit lifecycle work to skill-maintainer."
adaptedFrom:
  - "https://github.com/vercel-labs/skills/tree/main/skills/find-skills"
disable-model-invocation: true
---

# Find Skills

Discover external candidates; leave repository lifecycle work to `skill-maintainer`.

## Discovery Workflow

1. Capture the requested domain, concrete task, constraints, expected output, and why a reusable skill is preferable to direct help.
2. Check the [skills.sh leaderboard](https://skills.sh/) for established candidates, then search narrower or alternate terms as needed:

   ```bash
   if command -v skills >/dev/null 2>&1; then
     skills find <query> [--owner <owner>]
   else
     npx skills find <query> [--owner <owner>]
   fi
   ```

3. Qualify each plausible candidate beyond search rank:
   - **reputation** — source ownership, maintainer trust, and repository standing
   - **adoption** — current install count or other concrete usage signal
   - **activity** — recent maintenance, releases, and unresolved issues
   - **risks** — low adoption, stale code, unclear licensing, unsafe behavior, or scope mismatch
4. Recommend the best options with purpose, source, evidence, risks, and a `skills.sh` link when available.
5. Resolve the selected candidate into this exact handoff, preserving field order:

   ```yaml
   source_spec: <exact source accepted by Skills CLI>
   skill_name: <name from the selected SKILL.md>
   skill_path: <source-repo-relative directory containing SKILL.md>
   ref: <confirmed branch, tag, or commit>
   reason: <why this candidate fits the request>
   evidence:
     reputation: <verified source and maintainer signals>
     adoption: <current usage signal>
     activity: <current maintenance signal>
     risks: <known risks or "none found">
     checked_at: <ISO 8601 date or timestamp>
   ```

Use a mutually consistent `source_spec`, `ref`, and `skill_path` that `skill-maintainer` can act on. Missing or ambiguous source, ref, or path means candidate is not maintenance-ready: continue research or report handoff as incomplete; never ask maintainer to guess. 6. Route complete handoff to `skill-maintainer`.

## Boundary

This skill never installs or adds skills. It performs no update or remove operation, cloning or copying, target placement, frontmatter or lockfile work, or repository edits. `skill-maintainer` owns those lifecycle mechanics.

## No Match

If no qualified candidate exists, report searches and rejection reasons. Offer direct help for one-off work; route a new reusable skill to `skill-creator`.
