# agent-skills

Canonical, public-safe agent skills for Nix and non-Nix consumers.

## Layout

Each selectable leaf follows the Skills CLI layout:

```text
skills/<category>/<skill>/SKILL.md
```

| Category | Selectable skills |
| --- | ---: |
| `common-general` | 77 |
| `common-personal` | 4 |
| `common-work` | 4 |
| `claude-code-general` | 1 |
| `claude-code-personal` | 0 |
| `claude-code-work` | 0 |
| `pi-general` | 1 |
| `pi-personal` | 0 |
| `pi-work` | 0 |

The source contains 87 unique selectable leaves. `skill-creator` is Claude Code-specific; `mcp-builder` is shared.

Keep private, work-internal, secret, host, and credential material outside this public repository.

## Skills CLI

Use the installed `skills` binary first. Use literal `npx skills` when the binary is unavailable.

List every discoverable skill:

```sh
skills add . --list
npx skills add . --list
```

Initialize a new leaf, then move it into the correct category:

```sh
skills init skill-name
npx skills init skill-name
```

Non-Nix users choose skills explicitly. `--agent` selects the destination harness; it does not select a profile.

Personal example:

```sh
skills add zhongjis/agent-skills --skill caveman --skill svelte --agent claude-code --copy -y
npx skills add zhongjis/agent-skills --skill caveman --skill svelte --agent claude-code --copy -y
```

Work Pi example:

```sh
skills add zhongjis/agent-skills --skill caveman --skill enterprise-scala --skill pi-jsonl-logs --agent pi --copy -y
npx skills add zhongjis/agent-skills --skill caveman --skill enterprise-scala --skill pi-jsonl-logs --agent pi --copy -y
```

Use explicit `--skill` names for profile selection. `--all` installs personal and work leaves together.

With `--copy`, a harness projection is a snapshot. `skills update -p -y` refreshes canonical `.agents` content but does not refresh copied harness leaves. Re-run the explicit `skills add ... --copy` command to update that projection.

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

`profile` must be `"personal"` or `"work"`. Omit `harness` for common skills. Supported harness values are `"claude-code"` and `"pi"`. Harness leaves override common leaves with the same name.

## Maintenance

Preserve each skill directory as one unit, including scripts, references, licenses, and assets. Keep existing `upstream` and `adaptedFrom` frontmatter when moving or updating a leaf.

Run:

```sh
nix flake check path:.
nix eval --file tests/selector.nix
bash tests/skills-cli.sh
SKILLS_CLI_FORCE_NPX=true bash tests/skills-cli.sh
```

The CLI test uses the installed `skills` command when available and falls back to `npx skills`. Set `SKILLS_CLI_FORCE_NPX=true` to exercise the fallback lifecycle even when `skills` is installed. The test verifies exact discovery, explicit installs, support-file copies, updates, removals, cleanup, and source-tree immutability.
