# agent-skills

Canonical, public-safe agent skills for Nix and non-Nix consumers.

## Layout

Authored and adapted skills live in root `skills/`; vendored common skills remain in `.agents/skills/`. Harness-specific physical skills use their agent folders. `skill-harnesses.nix` logically routes sparse root exceptions.

| Folder | Role | Skills |
| --- | --- | ---: |
| `skills/` | Authored/adapted (logical common unless routed) | 16 |
| `.agents/skills/` | Vendored common | 56 |
| `.claude/skills/` | Physical Claude Code | 0 |
| `.pi/skills/` | Physical Pi | 0 |
Profile membership lives in `profiles.nix` at the repo root. Skills not listed there are `general`.

| Profile | Skills |
| --- | --- |
| `personal` | _(none)_ |
| `work` | github-pr-management, mysql-best-practices, splunk |

The source contains 72 unique selectable leaves. Fifteen root skills are logical common; `pi-jsonl-logs` is routed only to Pi. `mcp-builder` is shared.

Keep private, work-internal, secret, host, and credential material outside this public repository.

## Skills CLI

Use the installed `skills` binary first. Use literal `npx skills` when the binary is unavailable.

List every discoverable skill:

```sh
skills add . --list
npx skills add . --list
```

Initialize a new authored leaf, then move it into root `skills/` (add a sparse `skill-harnesses.nix` route only when harness-specific):

```sh
skills init skill-name
npx skills init skill-name
```

Non-Nix users choose skills explicitly. `--agent` selects the destination harness; it does not select a profile.

Personal example (Pi):

```sh
skills add zhongjis/agent-skills --skill caveman --skill python --agent pi --copy -y
npx skills add zhongjis/agent-skills --skill caveman --skill python --agent pi --copy -y
```

Work Claude Code example:

```sh
skills add zhongjis/agent-skills --skill caveman --skill splunk --agent claude-code --copy -y
npx skills add zhongjis/agent-skills --skill caveman --skill splunk --agent claude-code --copy -y
```

Work Pi example:

```sh
skills add zhongjis/agent-skills --skill caveman --skill splunk --skill pi-jsonl-logs --agent pi --copy -y
npx skills add zhongjis/agent-skills --skill caveman --skill splunk --skill pi-jsonl-logs --agent pi --copy -y
```

Notes:
- `codex` and `opencode`: `skills add` should write to `.codex/skills/` and `.opencode/skills/`; if the CLI does not auto-create those folders, move the installed dir manually after `add`.
- `omp`: hand-managed; copy skill dirs directly into `.omp/skills/`.
- **Never** use `--agent '*'` — symlink fan-out pollutes harness folders.

Use explicit `--skill` names for profile selection. `--all` installs personal and work leaves together.

## Skill packs with Nix

Run a bootstrap pack from the target project directory. Omitting `--agent` installs to the shared `.agents/skills/` directory; pass `--agent` for a harness-specific destination:

```sh
nix run github:zhongjis/agent-skills#packs -- typescript
nix run github:zhongjis/agent-skills#packs -- typescript vercel
nix run github:zhongjis/agent-skills -- typescript
nix run github:zhongjis/agent-skills#packs -- typescript --agent pi
```

The app performs noninteractive copied installs (`--copy -y`). Without an override it invokes Skills CLI with `--agent universal`; explicit targets such as `--agent pi` remain unchanged. It validates every argument and manifest before installation, deduplicates exact source/name tuples, rejects one skill name from different sources, then groups ordered skills into one Skills CLI call per source. Skills CLI exclusively owns `skills-lock.json`. Packs are bootstrap-only: they do not prune existing skills and remain separate from `profiles.nix`.

Pack membership:

- `typescript`: `typescript-best-practices` from `0xBigBoss/claude-code`; `biome` from `bobmatnyc/claude-mpm-skills`; `pnpm` and `vitest` from `antfu/skills`; `turborepo` from `vercel/turborepo`.
- `vercel`: `deploy-to-vercel`, `vercel-react-best-practices`, `vercel-composition-patterns`, and `vercel-optimize` from `vercel-labs/agent-skills`.

## Nix selection

The flake exports a pure `lib.skillsFor` function. It returns `{ skill-name = skill-directory-path; }`; it does not install Home Manager configuration.

```nix
inputs.agent-skills.url = "github:zhongjis/agent-skills";
```

Common personal skills:

```nix
programs.codex.skills = inputs.agent-skills.lib.skillsFor {
  profile = "personal";
};
```

Claude Code work skills, including Claude-specific overrides:

```nix
programs.claude-code.skills = inputs.agent-skills.lib.skillsFor {
  profile = "work";
  harness = "claude-code";
};
```

Pi work skills:

```nix
programs.pi.skills = inputs.agent-skills.lib.skillsFor {
  profile = "work";
  harness = "pi";
};
```

`profile` must be `"personal"` or `"work"`. Omit `harness` for common skills. Supported harness values are `"claude-code"`, `"codex"`, `"factory"`, `"omp"`, `"opencode"`, and `"pi"`. Harness leaves override common leaves with the same name.

## Maintenance

Preserve each skill directory and its instructional content, including scripts, references, licenses, and assets. Only repository-owned provenance metadata may differ; reject unsuitable sources rather than rewriting them.

Run:

```sh
nix flake check path:.
nix eval --file tests/selector.nix
bash tests/packs.sh
bash tests/skills-cli.sh
SKILLS_CLI_FORCE_NPX=true bash tests/skills-cli.sh
```

Flake-consumer realization check (verifies dot-dirs survive the Nix store copy):

```sh
nix eval --impure --expr '(builtins.getFlake (toString ./.)).lib.skillsFor { profile = "personal"; harness = "pi"; }'
```

The CLI test uses the installed `skills` command when available and falls back to `npx skills`. Set `SKILLS_CLI_FORCE_NPX=true` to exercise the fallback lifecycle even when `skills` is installed. Synthetic fixtures verify lock-aware discovery, explicit copied install/list/refresh/remove behavior, support-file preservation, zero symlink fan-out, lock cleanup, source immutability, and temp cleanup.
