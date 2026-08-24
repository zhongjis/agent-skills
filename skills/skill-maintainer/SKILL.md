---
name: skill-maintainer
description: Add, update, remove, and audit skills in the canonical agent-skills repository, including consuming maintenance-ready find-skills handoffs and repairing provenance, profile, lockfile, docs, or test drift.
---

# Skill Maintainer

Own the canonical repository lifecycle for authored and vendored skills.

## Repository Gate

Run from repository root. Continue only when all canonical markers exist:

```bash
test -f flake.nix \
  && test -d skills/ \
  && test -d .agents/skills/ \
  && test -f skill-harnesses.nix \
  && test -f skill-selection.nix \
  && test -f profiles.nix \
  && test -f lib/select-skills.nix
```

If this gate fails, stop and report that this workflow requires the canonical `agent-skills` repo. Do not switch to a generic-project workflow.

## Inputs and Placement

Accept either a direct user source or this exact `find-skills` handoff:

```yaml
source_spec: <exact Skills CLI source>
skill_name: <SKILL.md name>
skill_path: <source-repo-relative directory containing SKILL.md>
ref: <branch, tag, or commit>
reason: <fit>
evidence:
  reputation: <signal>
  adoption: <signal>
  activity: <signal>
  risks: <signal>
  checked_at: <timestamp>
```

For a new vendored import, confirm source, name, path, and ref before mutation. Determine harness and profile from user intent plus existing repository patterns. If harness or profile remains ambiguous in a behavior-changing way, stop and ask one precise question; never guess.

Repository model:
- Authored/adapted skills live in root `skills/`; vendored common skills live in `.agents/skills/`; physical harness skills live in `<agent-folder>/skills/`.
- `skill-selection.nix.exclude` removes named root skills from global selection. Each excluded skill may have one relative project projection at `.agents/skills/<name>` targeting `../../skills/<name>`.
- `skill-harnesses.nix` sparsely routes globally selectable root skills to logical harnesses; unlisted selected root skills are logical common.
- `profiles.nix` lists `personal` and `work` membership; unlisted skills are `general`.
- Same-name common and harness-specific skills are allowed only as an intentional final override; same-layer duplicates are invalid.
- Preserve whole skill directories, including `scripts/`, `references/`, `assets/`, licenses, and other required files.
- For add and refresh, use one exact skill, one explicit harness, and `--copy`. Never execute `--agent '*'`.

## Provenance Audit

Classify each skill before changing it:
- Root `skills/` leaf with no lock entry → authored/adapted; `adaptedFrom` is informational lineage.
- `.agents/skills/` directory with a tracked CLI-generated lock entry → vendored.
- `.agents/skills/<name>` symlink named by `skill-selection.nix.exclude` and targeting `../../skills/<name>` → project-local projection.
- Singular `upstream`, when present, must agree with the lock source.
- `.agents/skills/` directory without lock, mismatched projection, root leaf with lock, orphan lock, or conflicting `upstream`/lock source → provenance drift.

Skills CLI owns lock creation, update, removal, and hashes. Never calculate hashes or hand-write lock entries.

## CLI Contract

Prefer installed `skills`; use literal `npx skills` only as fallback:

```bash
if command -v skills >/dev/null 2>&1; then
  SKILLS=(skills)
else
  SKILLS=(npx skills)
fi
"${SKILLS[@]}" --help
```

Inspect current top-level and subcommand `--help` before assuming flags. Add and refresh only one named skill for one harness as an independent copy:

```bash
"${SKILLS[@]}" add "$source_spec" \
  --skill "$skill_name" \
  --agent "$harness" \
  --copy \
  -y
```

Never use wildcard selectors or broad `skills update`; those operations do not preserve this skill/harness/copy scope. Normalize CLI output to the provenance-owned canonical folder, profile, global exclusion, project projection, and sparse logical route; ensure lock metadata still describes final vendored state.

## Add

1. Check same-name skills across root, vendored common, and physical harness layers; confirm target folder, profile, global selection or exclusion, project projection, logical route, `upstream`, and lock state; distinguish intentional final override from invalid same-layer duplication or drift.
2. Acquire the whole source at confirmed `source_spec`, `ref`, and `skill_path` with the scoped `add --skill ... --agent ... --copy` command above.
3. Review every acquired file semantically for public-safe publication. Preserve every file and its instructional content, including licenses and technically necessary vendor terms. If it contains private or work-internal material, secrets, hosts, credentials, or content incompatible with repository purpose, stop without importing it.
4. Preserve singular `upstream` when present and confirm it agrees with the CLI-generated lock source.
5. Normalize the complete directory, profile, global exclusion and project projection when applicable, and route. Confirm provenance-owned folder, logical/physical harness, CLI-generated lock entry, profile, and any singular `upstream` agree.

## Update

1. Derive exact source, ref, and path from lock metadata plus any singular `upstream`; resolve disagreement before mutation.
2. Refresh by rerunning the scoped `add --skill ... --agent ... --copy` command above for the exact skill and harness.
3. Reconcile the full tree exactly: include upstream-added files, delete upstream-removed files, and discard local content changes.
4. Re-run public-safe and provenance review; refresh profile, exclusion, projection, README, tests, and applicable DOX when behavior or catalog state changed.

## Remove

1. Use Skills CLI removal for exact skill and explicit harness so lock state is removed by CLI.
2. Remove whole leaf directory plus stale profile, exclusion, project projection, test, README, and applicable DOX references.
3. Confirm no orphan lock or provenance state remains. Never patch the lockfile manually.

## Fetch Fallback

A reusable repository-specific `/tmp` clone is allowed only as an inspection or staging fallback after Skills CLI cannot fetch the source. Verify cached remote and ref before reuse. Feed any staged source back through Skills CLI; never complete a vendored import without CLI-produced lock metadata.

## Verification

Review scoped diff for public-safe content, provenance consistency, complete tree reconciliation, and unrelated edits. Run all checks:

```bash
nix flake check path:.
nix eval --file tests/selector.nix
bash tests/skills-cli.sh
SKILLS_CLI_FORCE_NPX=true bash tests/skills-cli.sh
```

## Completion Criteria

Complete only when:
- intended canonical folder, logical/physical harness, profile, global exclusion and project projection when applicable, and lock entry agree; any singular `upstream` agrees with lock source;
- whole tree is reconciled, including added and removed files;
- README, tests, and applicable DOX are synced;
- scoped diff contains no unrelated edits;
- every verification check passes, or exact pre-existing blockers are reported without hiding failures.

Route ecosystem discovery to `find-skills`. Route new or substantial authored skill creation to `skill-creator`.
