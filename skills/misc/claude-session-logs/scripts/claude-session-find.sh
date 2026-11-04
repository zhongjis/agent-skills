#!/usr/bin/env bash
# claude-session-find.sh — List Claude Code session files, newest first.
# Usage: claude-session-find.sh [--project PATH | --all | --id ID] [--limit N]
#
#   --project PATH  Sessions for one working directory (default: $PWD)
#   --all           Sessions for every project
#   --id ID         Session or subagent file whose name starts with ID
#   --limit N       Show at most N files (default: 10; 0 means all)
#
# Prints: mtime, size, path, then the latest ai-title and recorded cwd.
set -euo pipefail
fail() { printf 'Error: %s\n' "$*" >&2; exit 2; }
ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
MODE=project PROJECT=$PWD ID='' LIMIT=10
while (($#)); do
  case $1 in
    --project) [[ $# -ge 2 && -n $2 ]] || fail '--project requires a value'; MODE=project PROJECT=$2; shift 2 ;;
    --all) MODE=all; shift ;;
    --id) [[ $# -ge 2 && $2 =~ ^[A-Za-z0-9-]+$ ]] || fail '--id requires a session or agent id'; MODE=id ID=$2; shift 2 ;;
    --limit) [[ $# -ge 2 && $2 =~ ^[0-9]+$ ]] || fail '--limit requires a nonnegative integer'; LIMIT=$((10#$2)); shift 2 ;;
    --help) sed -n '2,10p' "$0"; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done
[[ -d $ROOT ]] || fail "no Claude Code projects directory: $ROOT"
files=()
case $MODE in
  project)
    # Claude Code replaces every non-alphanumeric path character with '-'.
    # The encoding is lossy; the cwd field inside each file is authoritative.
    dir="$ROOT/$(printf '%s' "$PROJECT" | sed 's/[^A-Za-z0-9]/-/g')"
    [[ -d $dir ]] || fail "no session directory for $PROJECT (try --all and match the cwd column)"
    for f in "$dir"/*.jsonl; do [[ -f $f ]] && files+=("$f"); done ;;
  all) for f in "$ROOT"/*/*.jsonl; do [[ -f $f ]] && files+=("$f"); done ;;
  id) while IFS= read -r f; do files+=("$f"); done < <(find "$ROOT" -name "$ID*.jsonl" -type f) ;;
esac
((${#files[@]})) || { printf 'no sessions found\n' >&2; exit 0; }
n=0
while IFS= read -r f; do
  ((LIMIT == 0 || n < LIMIT)) || break
  n=$((n+1))
  title=$(grep -F '"type":"ai-title"' -- "$f" | tail -n 1 | jq -r '.aiTitle // empty' 2>/dev/null || true)
  cwd=$(grep -m 1 -F '"cwd":' -- "$f" | jq -r '.cwd // empty' 2>/dev/null || true)
  printf '%s  %6sK  %s\n    title: %s  cwd: %s\n' \
    "$(date -r "$f" '+%F %T')" "$(( $(wc -c < "$f") / 1024 ))" "$f" "${title:--}" "${cwd:--}"
done < <(ls -t -- "${files[@]}")
