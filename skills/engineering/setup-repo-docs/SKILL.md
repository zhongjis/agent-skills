---
name: setup-repo-docs
description: Set up, migrate, or clean up a repository's documentation into a purpose-led structure that works with existing agent skills.
disable-model-invocation: true
---

# Set Up Repository Docs

Build a durable documentation home without creating competing sources of truth. This is an explicit setup, migration, or cleanup workflow, not an ongoing writing assistant.

Work autonomously up to the point of mutation: examine the repository and report findings without asking. A gate is permission to mutate — stop and wait for the user before any file changes, and change nothing until they approve. Default to no mutation.

## Target structure

```text
CONTEXT.md                    # Canonical domain language; create lazily
CONTEXT-MAP.md                # Optional index for multiple bounded contexts
docs/
├── README.md                 # Map, authority model, and declared canonical paths
├── ideas/                    # Non-binding exploration; Status: idea
├── specs/                    # Draft, planned, or shipped behavior/contracts
├── adr/                      # Append-only architecture decision records
├── guides/                   # Task-oriented instructions
├── references/               # External, stable, citable material only
└── rules/                    # Locked execution policy imported by root AGENTS.md
```

Declare every bucket in `docs/README.md`. Create bucket directories only when they contain a document, except during `MIGRATION`: for each missing bucket, ask whether the user wants to initialize an empty directory with `.gitkeep`. Create approved buckets; leave declined buckets absent. Treat an approved `.gitkeep` bucket as intentional, not empty-directory drift. Use lowercase kebab-case paths. Name ADRs `NNNN-short-decision-title.md`.

Setup is idempotent: a second run against a complete structure proposes no changes.

## Companion conventions

Reuse established artifacts rather than duplicating them:

- `domain-modeling` owns domain-language discovery and writes `CONTEXT.md`, optional `CONTEXT-MAP.md`, and ADR substance. Adopt existing files. Create them only when resolved terms or decisions exist.
- Use the domain-modeling ADR test: record a choice only when it is hard to reverse, surprising without context, and the result of a real trade-off.
- `agents-md` owns execution-contract content in `AGENTS.md`. Preserve that content; update only imports or path references required by the docs setup.
- Link `CONTEXT.md`, `CONTEXT-MAP.md`, and `docs/adr/` from `docs/README.md` when present.

`CONTEXT.md` is authoritative for vocabulary, not system behavior. Behavioral conflicts resolve in this order: rules → ADRs → shipped specs → guides → ideas. References provide evidence, never policy.

## Lifecycle rules

Use statuses `idea`, `draft`, `planned`, `shipped`, `superseded`, and `retired`.

- Every idea uses exact `Status: idea`; ideas are non-binding.
- Specs use `draft`, `planned`, `shipped`, `superseded`, or `retired` as appropriate.
- Add `Owner` and `Last reviewed` when ownership or freshness matters.
- ADR history is append-only. Supersede through a new ADR plus reciprocal `Supersedes` and `Superseded by` links.
- A path under `docs/rules/` is locked once adopted: never move or rename it. Root `AGENTS.md` imports applicable rules.
- Keep retired or superseded docs at meaningful paths; do not create an archive bucket.

## Workflow

Run one structural pass every time, and an optional content pass only when the user asks to go deeper. Route every change through the same invariant checks regardless of pass: preserve locked `docs/rules/` paths, keep ADR history append-only, and repair every inbound reference in the same change set.

### Structural pass

#### 1. Examine

Read root and applicable child `AGENTS.md` files, existing canonical docs, `CONTEXT.md`, `CONTEXT-MAP.md`, ADRs, indexes, scripts, and inbound links. Inventory each document by purpose, authority, status, owner, freshness, and path constraints. Map clear documents to the target structure; flag mixed or ambiguous documents instead of guessing.

Complete when every existing document and inbound reference is accounted for, and the tree is classified as `MIGRATION`, `CLEANUP-ONLY`, or `CLEAN NO-OP`.

#### 2. Report

Open with the verdict header:

- **`MIGRATION`** — documents sit outside the target structure and need restructuring.
- **`CLEANUP-ONLY`** — structure is already correct; only stale links, undeclared-but-populated buckets, empty declared directories, or metadata/status drift remain.
- **`CLEAN NO-OP`** — nothing to change.

Then list discrepancies and missing pieces, with every fix tiered:

- **T1 — lossless:** declare an existing bucket in `docs/README.md`, repair a stale link, drop an empty declared directory, normalize a status field.
- **T2 — unambiguous move:** a single-purpose document that belongs in a different bucket.
- **T3 — flagged:** a mixed-purpose or ambiguous document; report it and leave it in place.

Every proposed fix carries a destination, an inbound-reference plan, and a rollback-safe step. For `MIGRATION`, list every missing bucket and its `.gitkeep` initialization choice. A `CLEANUP-ONLY` verdict still surfaces deferred structural doubts (for example, a non-canonical directory left untouched). Unless the verdict is `CLEAN NO-OP`, offer a deeper content reorganization as a menu option alongside the fixes.

Complete when the verdict header, tiered fixes, and — unless `CLEAN NO-OP` — the content-reorganization offer are stated.

#### Gate

Change nothing until the user approves. The user approves T1 and T2 in bulk, chooses initialization for each missing bucket, and approves T3 items individually or leaves them in place. A `CLEAN NO-OP` verdict has nothing to approve — stop here.

#### 3. Apply

Create only needed directories and documents, including approved `.gitkeep` bucket initializations. Make only approved, unambiguous changes. Update `docs/README.md`, Markdown links, indexes, scripts, and `AGENTS.md` imports in the same change set. Preserve locked `docs/rules/` paths and ADR history.

Complete when no active reference points to an obsolete path, no subject has competing canonical documents, and re-running the examine step against the resulting tree reports `CLEAN NO-OP`.

### Content pass (opt-in)

Run only when the user accepts the deeper-reorganization offer. This pass relocates content losslessly; it never rewrites prose. Merging overlapping documents, deduplicating, and reconciling contradictions are out of scope — flag them and recommend a writing skill instead. Never touch `docs/rules/` or `docs/adr/`.

#### 4. Examine

Read full document contents. Identify sections that can move verbatim into a better-fitting document, and mixed-purpose documents that split into verbatim slices. The test for every candidate: the content survives byte-for-byte and only its location changes.

Complete when every relocation candidate is byte-for-byte lossless, and merge or dedup opportunities are flagged rather than planned.

#### 5. Report

Present the relocation and split plan. Each item states its source, destination, and affected references, including intra-document anchors and heading links.

Complete when every proposed relocation has a destination and an anchor-level reference-repair plan.

#### Gate

Change nothing until the user approves.

#### 6. Apply

Move and split content verbatim. Repair intra-document anchors and heading links (`doc.md#section`) atomically with the move.

Complete when content is relocated with no lost bytes, every anchor and heading link resolves, and no document is mixed-purpose or shares a declared purpose and topic with another.

### Closing

Recommend the `domain-modeling` skill when `CONTEXT.md` is absent or thin, or ADR substance is missing, so the user can populate domain language and decisions. This is a non-blocking suggestion the user chooses to invoke.

## Report contract

State the verdict header, canonical sources inspected, proposed or applied paths, companion artifacts adopted, lifecycle changes, repaired references, verification evidence, idempotency result, and unresolved (flagged) decisions.
