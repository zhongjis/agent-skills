# Remote Clone Reference

Safe shallow-clone and sparse-checkout scripts for deep remote investigation (Tier 2 of the remote search strategy in `SKILL.md`). Treat `/tmp/agent-repos/` as a reusable cache, not disposable scratch. Before cloning, always inspect an existing destination first — never `rm` first. Read the removal policy in `SKILL.md` before removing anything.

## Safe shallow clone (reuse-or-refresh existing cache)

```bash
# 1. Check repo size BEFORE cloning (skip clone for repos >500MB)
gh api repos/{owner}/{repo} --jq '.size'

# 2. Choose a deterministic cache path
dest=/tmp/agent-repos/owner-repo
mkdir -p /tmp/agent-repos

# 3. If the path exists, inspect it first. Never rm first.
if [ -d "$dest/.git" ]; then
  actual_remote=$(git -C "$dest" remote get-url origin 2>/dev/null || true)
  expected_remote="https://github.com/owner/repo.git"

  if [ "$actual_remote" = "$expected_remote" ] || [ "$actual_remote" = "git@github.com:owner/repo.git" ]; then
    if [ -n "$(git -C "$dest" status --short)" ]; then
      echo "Existing clone has local changes; use a different destination."
      exit 1
    fi
    git -C "$dest" pull --ff-only --depth 1
  else
    echo "Existing clone has different origin: $actual_remote"
    echo "Use a different destination; remove only as last resort after manual confirmation."
    exit 1
  fi
elif [ -e "$dest" ]; then
  echo "Destination exists but is not a git repo: $dest"
  echo "Inspect it; use a different destination unless you can prove it is disposable."
  exit 1
else
  gh repo clone owner/repo "$dest" -- --depth 1
fi

# 4. Use full local search tooling on the clone
```

## Sparse checkout (huge repos)

For very large repos (size >500000 KB, ~500MB), fetch only the relevant directories:

```bash
# Sparse clone for huge repos — only fetch relevant directories.
# Same rule: if destination exists, inspect it first; never remove first.
dest=/tmp/agent-repos/owner-repo-sparse
expected_remote="https://github.com/owner/repo.git"
if [ -d "$dest/.git" ]; then
  actual_remote=$(git -C "$dest" remote get-url origin 2>/dev/null || true)
  [ "$actual_remote" = "$expected_remote" ] || { echo "Different origin: $actual_remote"; exit 1; }
elif [ -e "$dest" ]; then
  echo "Destination exists but is not a git repo: $dest"; exit 1
else
  git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/owner/repo.git "$dest"
fi
git -C "$dest" sparse-checkout set src/relevant/path
```
