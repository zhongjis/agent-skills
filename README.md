# agent-skills

Canonical, public-safe agent skills for Nix and non-Nix consumers.

## Layout

Skills live in per-harness agent folders:

| Folder | Harness | Skills |
| --- | --- | ---: |
| `.agents/skills/` | Universal (all harnesses) | 85 |
| `.claude/skills/` | Claude Code | 1 |
| `.pi/skills/` | Pi | 1 |

Profile membership lives in `profiles.nix` at the repo root. Skills not listed there are `general`.

| Profile | Skills |
| --- | --- |
| `personal` | recharts-patterns, supabase-postgres-best-practices, svelte, sveltekit |
| `work` | enterprise-scala, github-pr-management, mysql-best-practices, splunk |

The source contains 87 unique selectable leaves. `skill-creator` is Claude Code-specific; `mcp-builder` is shared.

Keep private, work-internal, secret, host, and credential material outside this public repository.

## Skills CLI

Use the installed `skills` binary first. Use literal `npx skills` when the binary is unavailable.

List every discoverable skill:

```sh
skills add . --list
npx skills add . --list
```

Initialize a new leaf, then move it into the correct agent folder:

```sh
skills init skill-name
npx skills init skill-name
```

Non-Nix users choose skills explicitly. `--agent` selects the destination harness; it does not select a profile.

Personal example (Pi):

```sh
skills add zhongjis/agent-skills --skill caveman --skill svelte --agent pi --copy -y
npx skills add zhongjis/agent-skills --skill caveman --skill svelte --agent pi --copy -y
```

Work Claude Code example:

```sh
skills add zhongjis/agent-skills --skill caveman --skill enterprise-scala --agent claude-code --copy -y
npx skills add zhongjis/agent-skills --skill caveman --skill enterprise-scala --agent claude-code --copy -y
```

Work Pi example:

```sh
skills add zhongjis/agent-skills --skill caveman --skill enterprise-scala --skill pi-jsonl-logs --agent pi --copy -y
npx skills add zhongjis/agent-skills --skill caveman --skill enterprise-scala --skill pi-jsonl-logs --agent pi --copy -y
```

Notes:
- `codex` and `opencode`: `skills add` should write to `.codex/skills/` and `.opencode/skills/`; if the CLI does not auto-create those folders, move the installed dir manually after `add`.
- `omp`: hand-managed; copy skill dirs directly into `.omp/skills/`.
- **Never** use `--agent '*'` — symlink fan-out pollutes harness folders.

Use explicit `--skill` names for profile selection. `--all` installs personal and work leaves together.

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

Preserve each skill directory as one unit, including scripts, references, licenses, and assets. Keep existing `upstream` and `adaptedFrom` frontmatter when moving or updating a leaf.

Run:

```sh
nix flake check path:.
nix eval --file tests/selector.nix
bash tests/skills-cli.sh
SKILLS_CLI_FORCE_NPX=true bash tests/skills-cli.sh
```

Flake-consumer realization check (verifies dot-dirs survive the Nix store copy):

```sh
nix eval --impure --expr '(builtins.getFlake (toString ./.)).lib.skillsFor { profile = "personal"; harness = "pi"; }'
```

The CLI test uses the installed `skills` command when available and falls back to `npx skills`. Set `SKILLS_CLI_FORCE_NPX=true` to exercise the fallback lifecycle even when `skills` is installed. The test verifies exact discovery, explicit installs, support-file copies, updates, removals, cleanup, and source-tree immutability.
