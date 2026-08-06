---
title: NPX-Skills-First Repository Restructure
status: ready-for-agent
---

# NPX-Skills-First Repository Restructure

## Problem Statement

Today every skill in this repository — whether the maintainer wrote it by hand or
pulled it from an upstream project — is manually copied into a
`skills/<harness>-<profile>/<skill>/` directory, hand-genericized, and tagged with
`upstream:` frontmatter. There is no first-class way to *add* a vendored skill: the
maintainer clones the upstream repo, copies the directory, rewrites frontmatter, and
commits it by hand. Updates are equally manual. The maintainer wants to use the Vercel
`skills` CLI (`npx skills add`) as the primary way to bring in and update vendored
skills, keep hand-written ("self-authored") skills separate and freely editable, and
have Nix automatically wrap whatever exists on disk into the existing
nix-config integration — all **without changing the exposed `lib.skillsFor` API**.

## Solution

Restructure the repository around the `skills` CLI's native on-disk conventions
("npx skills first"), with Nix acting as a thin wrapper layer:

- **Harness axis becomes physical folders** — the CLI's per-agent skill directories.
  Common skills live in `.agents/skills/`; harness-specific skills live in that
  harness's directory (`.claude/skills/`, `.pi/skills/`, `.codex/skills/`,
  `.opencode/skills/`, `.factory/skills/`, `.omp/skills/`).
- **Profile axis becomes one small data file** — `profiles.nix` at the repo root,
  because the CLI has no concept of `general` / `personal` / `work`.
- **Provenance becomes the CLI's lockfile** — `skills-lock.json` records vendored
  skills; a skill absent from the lockfile is self-authored. Nix never reads the
  lockfile; the authored/vendored distinction is a human/maintenance concern only.
- **Nix stays a wrapper** — `lib/default.nix` is rewritten to discover each harness
  folder and split it into profile cells using `profiles.nix`, reconstructing the exact
  same `groups` attrset the current code builds. `lib/select-skills.nix` and the public
  `lib.skillsFor { profile, harness? }` signature and behavior are unchanged.

The result: the maintainer runs `npx skills add …` to vendor and `npx skills update` to
refresh; hand-authors skills directly in the appropriate agent folder; adds the skill's
name to `profiles.nix` only if it is not `general`; and Nix consumers keep calling
`inputs.agent-skills.lib.skillsFor { profile = …; harness = …; }` exactly as before.

## User Stories

1. As a Nix-config consumer, I want `lib.skillsFor { profile = "personal"; }` to keep
   returning the same `{ skill-name = path; }` attrset after the restructure, so that my
   Home Manager configuration does not break.
2. As a Nix-config consumer, I want `lib.skillsFor { profile = "work"; harness = "pi"; }`
   to still merge common skills with pi-specific skills and let pi override common on
   name clashes, so that harness selection behaves identically to today.
3. As a Nix-config consumer, I want the returned values to remain Nix *path* values (not
   strings), so that Home Manager modules that read the skill directory continue to work.
4. As a skill maintainer, I want to vendor a common upstream skill with a single
   `npx skills add <source> --skill <name> --agent codex -y` command, so that it lands in
   `.agents/skills/<name>/` and is tracked in `skills-lock.json` without manual copying.
5. As a skill maintainer, I want to vendor a Claude-specific upstream skill with
   `npx skills add <source> --skill <name> --agent claude-code -y`, so that it lands in
   `.claude/skills/<name>/` and Nix treats it as a `claude-code` harness skill.
6. As a skill maintainer, I want to vendor a Pi-specific upstream skill with
   `npx skills add <source> --skill <name> --agent pi -y`, so that it lands in
   `.pi/skills/<name>/` and Nix treats it as a `pi` harness skill.
7. As a skill maintainer, I want `npx skills update` to refresh only vendored
   (lockfile-tracked) skills, so that my self-authored skills are never overwritten.
8. As a skill maintainer, I want `npx skills remove <name>` to remove a vendored skill,
   so that removal is a single CLI command rather than a manual directory deletion.
9. As a skill author, I want to create a self-authored skill by placing a
   `SKILL.md` directory directly in the correct agent folder (e.g. `skills init` then
   move, or hand-create), so that I can write skills without the CLI and without any
   lockfile entry.
10. As a skill author, I want self-authored skills to be identified purely by their
    absence from `skills-lock.json`, so that I do not have to maintain any extra
    provenance marker.
11. As a skill maintainer, I want a common skill that is only relevant to the `personal`
    profile (e.g. `svelte`) to be listed once in `profiles.nix` under `personal`, so that
    `lib.skillsFor { profile = "work"; }` excludes it.
12. As a skill maintainer, I want a common skill that is only relevant to the `work`
    profile (e.g. `enterprise-scala`) to be listed once in `profiles.nix` under `work`, so
    that `lib.skillsFor { profile = "personal"; }` excludes it.
13. As a skill maintainer, I want any skill not listed in `profiles.nix` to be treated as
    `general` (available to both profiles), so that the common case requires no data-file
    edit.
14. As a consumer of the repository as a *source*, I want `npx skills add <this-repo>
    --list` to keep discovering every skill regardless of which agent folder it lives in,
    so that others can still install skills from this repository.
15. As a maintainer, I want `lib.skillsFor` to throw on an unsupported argument, a missing
    or invalid `profile`, or an invalid `harness`, so that misconfiguration fails loudly —
    exactly as today.
16. As a maintainer, I want a test that evaluates `lib.skillsFor` for every
    `(profile, harness)` combination in CI, so that a name listed in `profiles.nix` with no
    matching skill directory is caught.
17. As a maintainer, I want a test asserting that the `personal` and `work` lists in
    `profiles.nix` are disjoint, so that a skill cannot be silently classified into two
    profiles at once.
18. As a maintainer, I want a test asserting that every name in `profiles.nix` resolves to
    a discovered skill directory, so that stale profile entries are caught.
19. As a maintainer, I want the CLI lifecycle test (`tests/skills-cli.sh`) updated to the
    new folder layout, so that add/list/update/remove and source-tree immutability are
    still verified end-to-end.
20. As a maintainer, I want the migration to preserve each skill directory as one unit
    (`SKILL.md`, `scripts/`, `references/`, `assets/`, licenses), so that no supporting
    files are lost when skills move folders.
21. As a maintainer, I want documentation (`README.md`, the `AGENTS.md` DOX chain) updated
    to describe the new layout and vendoring workflow, so that the repository stays
    self-describing.
22. As a maintainer of `omp` skills, I want to hand-manage them in `.omp/skills/`, so that
    Nix reads them as `omp` harness skills even though the CLI cannot add, update, or
    discover them.
23. As a maintainer, I want to be warned never to vendor with `--agent '*'`, so that the
    symlink fan-out does not pollute harness folders with copies of common skills.

## Implementation Decisions

### Modules built / modified

- **`lib/default.nix` (rewritten internals, same output).** Replace the 21 hardcoded
  `discoverSkills ../skills/<category>` bindings with:
  1. A per-harness-folder discovery step (reuse the existing `discoverSkills` logic:
     read a directory, throw if any child lacks `SKILL.md`, return `{ name = dirPath; }`).
     One call per harness folder that exists.
  2. A profile-split step that partitions each folder's `{ name = path; }` map into
     `general` / `personal` / `work` cells using the global `profiles.nix` lists
     (`personal` names → the `*Personal` cell; `work` names → the `*Work` cell; the
     remainder → the `*General` cell).
  3. Assembly of the same 21-key `groups` attrset (`commonGeneral`, `commonPersonal`,
     `commonWork`, `claudeCodeGeneral`, …, `piWork`) that `select-skills.nix` consumes.
- **`profiles.nix` (new).** A pure attrset of two name lists:

  ```nix
  {
    personal = [ "recharts-patterns" "supabase-postgres-best-practices" "svelte" "sveltekit" ];
    work     = [ "enterprise-scala" "github-pr-management" "mysql-best-practices" "splunk" ];
  }
  ```

  Everything not listed is `general`. One global file; not scoped per harness (skill
  names are globally unique across the catalog, so global classification is
  unambiguous).
- **`lib/select-skills.nix` (unchanged).** Argument validation, `commonGroups` /
  `harnessGroups` selection, `mergeGroups commonGroups // mergeGroups harnessGroups`
  override, and duplicate detection are untouched.
- **`flake.nix` (unchanged).** Still `outputs = _: { lib = import ./lib; }`.

### Harness → folder mapping (the routing table, now physical)

| `harness` argument | Source folder | CLI install path? |
| --- | --- | --- |
| `null` (common) | `.agents/skills/` | yes (`--agent codex`/`opencode`/… all land here) |
| `claude-code` | `.claude/skills/` | yes (`--agent claude-code`) |
| `pi` | `.pi/skills/` | yes (`--agent pi`) |
| `factory` | `.factory/skills/` | yes (`--agent droid`) |
| `codex` | `.codex/skills/` | **no** — `--agent codex` installs to `.agents/skills/`; requires hand-placement/move to be codex-specific |
| `opencode` | `.opencode/skills/` | **no** — `--agent opencode` installs to `.agents/skills/`; requires hand-placement/move to be opencode-specific |
| `omp` | `.omp/skills/` | **no** — omp is not a CLI agent; always hand-managed |

`lib.skillsFor { harness = H }` reads `.agents/skills/` (common) plus the folder for `H`,
with `H` overriding common on name clash — identical to the current
`common // harness` merge.

### Public API contract (frozen)

- `lib.skillsFor { profile, harness? }` returns `{ skill-name = skill-directory-path; }`.
- `profile` is required and must be `"personal"` or `"work"`.
- `harness` is optional: `null` selects common only; otherwise one of `"claude-code"`,
  `"codex"`, `"factory"`, `"omp"`, `"opencode"`, `"pi"`.
- Harness skills override common skills of the same name.
- Unsupported arguments, missing/invalid `profile`, invalid `harness`, or duplicate skill
  names throw.
- Returned values are Nix *path* values. `default.nix` must build paths by path
  concatenation (`../<folder> + "/${name}"`), never string interpolation, to preserve the
  path type and `toString` output.

### Provenance / authored vs vendored

- `skills-lock.json` (CLI-owned, committed) is the single provenance record. A skill with
  a lockfile entry is vendored; a skill absent from it is self-authored.
- Nix does not read `skills-lock.json`. The distinction affects only the maintenance
  workflow (edit-in-place vs `npx skills update`).
- The prior `upstream:` frontmatter convention is retired for vendored skills (the
  lockfile replaces it). Self-authored skills carry no provenance marker.

### Vendoring / authoring workflow

- Common vendored skill: `npx skills add <source> --skill <name> --agent codex -y`
  → `.agents/skills/<name>/` + lockfile entry.
- Harness-specific vendored skill (claude-code / pi / factory): use that harness's agent
  (`--agent claude-code`, `--agent pi`, `--agent droid`) → the corresponding folder.
- codex/opencode-specific skill: vendor, then move from `.agents/skills/` into
  `.codex/skills/` or `.opencode/skills/` (documented manual step).
- omp skill: hand-author in `.omp/skills/`.
- Self-authored skill: `npx skills init <name>` then move into the target agent folder, or
  hand-create the directory; do not add a lockfile entry.
- Never use `--agent '*'`: it writes real files to `.agents/skills/` and drops symlinks
  into every other harness folder, which would misclassify a common skill as
  harness-specific.

### Guardrails to add (compensating for lost per-directory discovery)

- Evaluate `lib.skillsFor` for every `(profile, harness)` pair in CI (catches a
  `profiles.nix` name with no directory, and any broken folder).
- Assert `profiles.nix` `personal` and `work` lists are disjoint.
- Assert every name in `profiles.nix` resolves to a discovered skill directory.

## Testing Decisions

### What makes a good test here

Tests assert **external behavior of the two existing seams**, not internal directory
bookkeeping: the pure output of `lib.skillsFor` for given arguments, and the observable
CLI lifecycle (files installed, listed, updated, removed) — never the internal shape of
`groups` or the internal discovery mechanism.

### Seams

Keep testing at the two existing seams; introduce no new runtime seam (ideal seam count
preserved):

- **Seam 1 — `nix eval --file tests/selector.nix`** (highest seam for selection
  correctness). Asserts the exact skill-name set returned by `lib.skillsFor` for each
  `(profile, harness)` and all failure cases. Because skill *names* are unchanged by the
  restructure, the expected `personalNames` / `workNames` / per-harness lists should
  remain valid; update only if a skill's folder/profile assignment changes a returned set.
  Add the three new guardrail assertions (folder eval-all, disjoint profiles, no stale
  profile names) here.
- **Seam 2 — `tests/skills-cli.sh`** (CLI lifecycle + source immutability). Update the
  hardcoded `skills/common-general/caveman`-style source paths to the new agent-folder
  paths, recompute the expected discovery count, and confirm the source-git-status
  invariant still holds with the new folders committed. Continue exercising
  add / list / update / remove and support-file preservation.

### Modules tested

- `lib.skillsFor` / `lib/select-skills.nix` / `lib/default.nix` via `tests/selector.nix`.
- The CLI integration and the repository-as-source contract via `tests/skills-cli.sh`.

### Prior art

`tests/selector.nix` already encodes the exact-name-list and failure-case style; extend
it. `tests/skills-cli.sh` already encodes the temp-project install/update/remove lifecycle
with source-immutability checks; adapt its paths and counts.

## Out of Scope

- Any change to the `lib.skillsFor` signature, return shape, override precedence, or throw
  conditions.
- Reading `skills-lock.json` from Nix, or otherwise making Nix aware of the
  authored/vendored distinction.
- Auto-generating `profiles.nix` from frontmatter or from the lockfile.
- A CLI feature to install codex/opencode skills directly into `.codex/.opencode` (the CLI
  installs them to `.agents/skills/`; this spec accepts the manual move).
- Bringing `omp` into the Vercel CLI (it is not a supported agent).
- Genericization policy rewording beyond scoping the "genericize + keep private material
  out" rule to self-authored skills.
- The bulk content migration itself may be executed as a follow-up; this spec defines the
  target structure, the `default.nix` behavior, and the test contract.

## Further Notes

- **Verified CLI facts (Vercel `skills` v1.5.21):** `.agents/skills/`, `.claude/skills/`,
  `.pi/skills/`, `.factory/skills/`, `.codex/skills/`, and `.opencode/skills/` are all
  source-discovery locations; `.omp/skills/` is not. `--agent codex` and `--agent opencode`
  install to `.agents/skills/`. `--agent '*'` creates real files in `.agents/skills/` and
  relative in-repo symlinks in the other agent folders. Single-agent installs produce clean
  real directories in exactly one folder.
- **Symlink safety:** the CLI's cross-agent symlinks are relative and stay inside the repo,
  so they are git- and Nix-safe; the restructure nonetheless avoids them by mandating
  single-agent installs so Nix never mistakes a symlinked common skill for a
  harness-specific one.
- **Migration classification is derivable:** skills with `upstream:` frontmatter today are
  vendored (move to the matching agent folder and seed the lockfile, ideally by
  re-running `npx skills add` from the recorded upstream); skills without it are
  self-authored (move as-is, no lockfile entry). Current `common-personal` /
  `common-work` membership seeds the `profiles.nix` lists.
- **DOX impact:** the restructure will rewrite `skills/AGENTS.md` (category layout →
  agent-folder layout), `lib/AGENTS.md` (discovery description), `tests/AGENTS.md`, the
  root `AGENTS.md` Child DOX Index, and `README.md`.
