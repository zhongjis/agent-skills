---
name: repo-doc-auditing
description: Audit repository docs for audience fit and ownership. Use when asked to audit, trim, or clean up repository docs (CONTRIBUTING.md, READMEs, AGENTS.md, docs/), find misplaced or irrelevant content, or check documentation ownership.
disable-model-invocation: true
---

# Audit Repository Docs

Report findings by default. Edit only when the user explicitly asks to apply changes.

## Establish scope and ownership

Inventory documentation across the repository, not just `docs/`: include root and nested READMEs, contributor guides, agent instructions, and docs beside packages, workflows, and tools. Honor any narrower scope the user names. Identify generated, vendored, or inaccessible docs separately and state any limits on coverage.

For each document, read its headers, purpose statement, and metadata alongside applicable `AGENTS.md` files from root to leaf and any owning index. Record the audience, purpose, and owner with evidence. Compare the declared remit to the actual content. If no declaration exists, label your inference; report conflicts or unknown ownership rather than assigning an owner without evidence.

## Judge each section

Ask: **Does this document's audience act on this text?** Identify the action, decision, or constraint it supports. Include unheaded content. Split a finding when parts of a section need different verdicts:

- **Keep**: The audience needs the current instruction, contract, or rationale here.
- **Trim**: Keep the actionable part; replace supporting detail with a short pointer to its owner where useful.
- **Cut**: Remove content with no remaining purpose, including stale instructions, incidental history, and facts already available from their authoritative source.
- **Move**: A different audience still needs the content. Name the existing owning path and suggest the shortest version that preserves the live requirement. Flag an unconfirmed destination.

Verify claims against owning docs, code, config, or tests before proposing removal. Code and config own implemented mechanics; keep reader-facing commands, constraints, and rationale that cannot be recovered from them. For a mechanic to stay, name the reader action it changes. Resolve duplicate rules to one authoritative owner, not one copy per audience. Distinguish obsolete narration in current guides from history that belongs in changelogs or decision records; retain live compatibility and safety constraints.

## Report impact

For proposed cuts, moves, or heading changes, search repository-wide for inbound references to affected paths and anchors. Search for the anchor alone as well as `path#anchor`: same-file links can use just `#anchor`. Resolve reference-style links, doc indexes, and instruction imports to their targets. Record each link that would break with its source location and proposed destination or removal. Distinguish no matches in the searched scope from unknown external backlinks.

Give every inventoried in-scope document, including ownership instructions, its own table preceded by audience and owner evidence. Cite code and config as evidence, not as documents:

| Section | Verdict | What the audience needs | Where the rest belongs |
| --- | --- | --- | --- |

Cite paths and lines for findings and authoritative sources. Follow each table with inbound-link impact. Finish when every in-scope section has a verdict or an explicit coverage limitation. Leave the repository unchanged in report-only mode.

## Example

A contributor guide lists uncached CI tasks and explains cache trust. Keep the command contributors use to force a fresh run; cut the task list that duplicates build config; move any live trust rule CI maintainers need to the workflow's owning instructions. If the guide loses a heading, list references to its anchor before recommending removal.
