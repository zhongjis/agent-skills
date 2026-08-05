---
name: jujutsu
description: "Manages version control with Jujutsu (jj), including rebasing, conflict resolution, and Git interop. Use only when the user explicitly mentions Jujutsu or `jj`, or when the current repository is jj-managed and contains a `.jj/` directory. Do not trigger for plain git repositories."
upstream: "https://github.com/knoopx/pi/tree/main/agent/skills/tools/jj-core"
---

# Jujutsu

Git-compatible VCS focused on concurrent development and ease of use.

**Trigger**: **DO NOT trigger for plain git repositories.** Trigger only for explicit `jj` or `Jujutsu` requests, or for general VCS operations after confirming a `.jj/` directory exists at the repo root.

## ⚠️ Precedence Rule

**When a repository contains a `.jj/` directory, this skill takes precedence over git-based workflows.** Never use `git add`, `git commit`, or `git push` in a jj-managed repo. All version control operations MUST use `jj` commands.

**Detection**: Check for `.jj/` directory at repo root. If present → use jj. If absent → fall back to git.

## Git Mental Model Translation

| User Says | Git Equivalent | Jj Command |
| --- | --- | --- |
| "commit" / "commit my changes" | `git add . && git commit -m "msg"` | `jj commit -m "msg"` (changes are already tracked) |
| "save and start new work" | `git commit -m "msg"` | `jj commit -m "msg"` |
| "push" | `git push` | `jj git push` |
| "create a branch" | `git checkout -b name` | `jj bookmark create name -r @` |
| "stash" | `git stash` | Not needed — just `jj new` and come back later |
| "amend" / "add to last commit" | `git commit --amend` | `jj squash` |
| "rebase" | `git rebase` | `jj rebase -d destination` |
| "see what changed" | `git diff` / `git status` | `jj diff` / `jj st` |
| "log" / "history" | `git log` | `jj log` |

## Commit Workflow (When User Says "Commit")

Jujutsu has **no staging area**. All file changes are automatically part of the current change. The "commit" workflow is:

```bash
# This describes the current change AND creates a new empty change to continue working
jj commit -m "feat: add new feature"

# That's it. No `add`, no `stage`. One command.
```

**Important behaviors:**
- `jj commit -m "msg"` = describe current change + create new empty change (equivalent of `git commit`)
- `jj desc -m "msg"` = only update description, stay on same change (use when user says "describe", not "commit")
- If user says "commit" without a message, ask for one — then use `jj commit -m "message"`
- Use conventional commits format: `type(scope): description`

## Key Commands

| Command                    | Description                                  |
| -------------------------- | -------------------------------------------- |
| `jj st`                    | Show working copy status                     |
| `jj log`                   | Show change log                              |
| `jj diff`                  | Show changes in working copy                 |
| `jj new`                   | Create new change                            |
| `jj desc`                  | Edit change description (stay on same change) |
| `jj commit`                | Describe + create new change (= git commit)   |
| `jj squash`                | Move changes to parent                       |
| `jj split`                 | Split current change                         |
| `jj rebase -s src -d dest` | Rebase changes                               |
| `jj absorb`                | Move changes into stack of mutable revisions |
| `jj bisect`                | Find bad revision by bisection               |
| `jj fix`                   | Update files with formatting fixes           |
| `jj sign`                  | Cryptographically sign a revision            |
| `jj metaedit`              | Modify metadata without changing content     |

## Project Setup

```bash
jj git init              # Init in existing git repo
jj git init --colocate   # Side-by-side with git
```

## Basic Workflow

```bash
jj new                   # Create new change
jj desc -m "feat: add feature"  # Set description
jj log                   # View history
jj edit change-id        # Switch to change
jj new --before @        # Time travel (create before current)
jj edit @-               # Go to parent
```

## Time Travel

```bash
jj edit change-id        # Switch to specific change
jj next --edit           # Next child change
jj edit @-               # Parent change
jj new --before @ -m msg # Insert before current
```

## Merging & Rebasing

```bash
jj new x yz -m msg       # Merge changes
jj rebase -s src -d dest # Rebase source onto dest
jj abandon              # Delete current change
```

## Conflicts

```bash
jj resolve              # Interactive conflict resolution
# Edit files, then continue
```

## Templates & Revsets

```bash
jj log -T 'commit_id ++ "\n" ++ description'
jj log -r 'heads(all())'    # All heads
jj log -r 'remote_bookmarks()..'  # Not on remote
jj log -r 'author(name)'    # By author
```

## Git Interop

```bash
jj bookmark create main -r @  # Create bookmark
jj git push --bookmark main   # Push bookmark
jj git fetch                 # Fetch from remote
jj bookmark track main@origin # Track remote
```

## Advanced Commands

```bash
jj absorb               # Auto-move changes to relevant commits in stack
jj bisect start         # Start bisection
jj bisect good          # Mark current as good
jj bisect bad           # Mark current as bad
jj fix                  # Run configured formatters on files
jj sign -r @            # Sign current revision
jj metaedit -r @ -m "new message"  # Edit metadata only
```

## Tips

- No staging: changes are immediate — never use `git add` in a jj repo
- Use conventional commits: `type(scope): desc`
- `jj undo` to revert operations
- `jj op log` to see operation history
- Bookmarks are like branches
- `jj absorb` is powerful for fixing up commits in a stack
- When user says "commit", always use `jj commit -m "msg"`

## Related Skills

- **gh**: GitHub CLI for PRs and issues
- **review**: Code review before committing
