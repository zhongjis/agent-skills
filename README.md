# agent-skills

Small, public-safe Skills CLI proof repo. Six native skills cover shared/common use and Pi-specific use across `general`, `personal`, and `work` categories.

## Skill matrix

| Category | Skill | Purpose |
| --- | --- | --- |
| common-general | `poc-common-general` | Turn a request into three concise next actions. |
| common-personal | `poc-common-personal` | Turn a side-project idea into a privacy-safe checklist. |
| common-work | `poc-common-work` | Draft a vendor-neutral handoff with status, risks, and next step. |
| pi-general | `poc-pi-general` | Summarize a Pi session as goal, progress, and next action. |
| pi-personal | `poc-pi-personal` | Sort personal Pi notes into keep, drop, and follow-up. |
| pi-work | `poc-pi-work` | Prepare a generic Pi work-session handoff. |

Skills live in native `skills/<category>/<skill>/SKILL.md` leaves. Category directories are ordinary containers, so discovery needs no `--full-depth` compatibility flag.

## Selection contract

`profile` is required and must be `personal` or `work`. Common selection always includes `poc-common-general` plus the matching common profile skill. Omit `harness` (or pass `null`) for common-only results. Set `harness = "pi"` to add `poc-pi-general` plus the matching Pi profile skill. The API returns skill directory paths, not `SKILL.md` paths.

This repository contains generic, public-safe instructions only. Keep private, work-internal, secret, host, and credential material outside this public repo.

## Maintainer workflow

Use the installed `skills` binary first; use literal `npx skills` when it is unavailable.

Initialize a skill:

```sh
skills init skill-name
npx skills init skill-name
```

Discover this source tree locally (no install):

```sh
skills add . --list
npx skills add . --list
```

Validate CLI availability:

```sh
skills --version
npx skills --version
```

Keep each fixture to one meaningful `SKILL.md`; do not add profile wrappers or generated profile views.

## Non-Nix consumption

Examples below target the published repository `zhongjis/agent-skills`. Run the bare command when `skills` is installed, or the paired literal `npx skills` command.

Claude Code common-only personal set (two skills):

```sh
skills add zhongjis/agent-skills --skill poc-common-general --skill poc-common-personal --agent claude-code --copy -y
npx skills add zhongjis/agent-skills --skill poc-common-general --skill poc-common-personal --agent claude-code --copy -y
```

Claude Code common-only work set (two skills):

```sh
skills add zhongjis/agent-skills --skill poc-common-general --skill poc-common-work --agent claude-code --copy -y
npx skills add zhongjis/agent-skills --skill poc-common-general --skill poc-common-work --agent claude-code --copy -y
```

Pi personal set (exactly four skills):

```sh
skills add zhongjis/agent-skills --skill poc-common-general --skill poc-common-personal --skill poc-pi-general --skill poc-pi-personal --agent pi --copy -y
npx skills add zhongjis/agent-skills --skill poc-common-general --skill poc-common-personal --skill poc-pi-general --skill poc-pi-personal --agent pi --copy -y
```

Pi work set (exactly four skills):

```sh
skills add zhongjis/agent-skills --skill poc-common-general --skill poc-common-work --skill poc-pi-general --skill poc-pi-work --agent pi --copy -y
npx skills add zhongjis/agent-skills --skill poc-common-general --skill poc-common-work --skill poc-pi-general --skill poc-pi-work --agent pi --copy -y
```

Project lifecycle commands (replace names with the explicit set being managed):

```sh
skills list --agent pi
npx skills list --agent pi
skills update -p -y
npx skills update -p -y
skills remove poc-common-general poc-common-personal poc-pi-general poc-pi-personal --agent pi -y
npx skills remove poc-common-general poc-common-personal poc-pi-general poc-pi-personal --agent pi -y
```

`--agent` chooses the destination harness; it does not select a profile. Profile users must choose explicit `--skill` names. Never use `--all` for profile selection: it installs every discovered skill.

With `--copy`, the Pi projection is a copy-snapshot. `skills update -p -y` updates shared canonical `.agents` content but does not refresh copied `.pi` leaves; re-run the explicit `skills add ... --agent pi --copy` command to refresh that projection. Likewise, `skills remove ... --agent pi` removes the Pi projection while retaining shared canonical content.

## Direct Nix consumption

The flake has no Home Manager module. Its pure `lib.skillsFor` function accepts a profile and optional harness, returning `{ skill-name = skill-directory-path; }`.

Add the public flake input:

```nix
inputs.agent-skills.url = "github:zhongjis/agent-skills";
```

Common-only Claude Code work selection (expected names: `poc-common-general`, `poc-common-work`):

```nix
programs.claude-code.skills = inputs.agent-skills.lib.skillsFor { profile = "work"; };
```

Pi work selection (expected names: `poc-common-general`, `poc-common-work`, `poc-pi-general`, `poc-pi-work`):

```nix
programs.pi.skills = inputs.agent-skills.lib.skillsFor { profile = "work"; harness = "pi"; };
```

These calls select directory paths through a pure function; they are not a Home Manager module and do not install anything by themselves.

## Contributor verification

Run from a checkout:

```sh
nix flake check
nix eval --file tests/selector.nix
bash tests/skills-cli.sh
```

Lifecycle QA uses the local source tree before a push. The `zhongjis/agent-skills` commands above are remote-release examples; do not describe them as locally verified until this repository is published and fetched remotely.
