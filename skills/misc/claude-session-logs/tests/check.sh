#!/usr/bin/env bash
# Regression check for the claude-session-* scripts against the S1 fixture.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
s="$root/scripts"
f="$root/tests/S1.jsonl"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
checks=0 failures=0
check() {
  local name=$1 needle=$2; shift 2
  local out status=0
  out=$("$@" 2>&1) || status=$?
  checks=$((checks+1))
  if [[ $status != 0 || $out != *"$needle"* ]]; then
    printf 'FAIL %s (exit %s): expected %s\n%s\n' "$name" "$status" "$needle" "$out"
    failures=$((failures+1))
  fi
}
absent() {
  local name=$1 needle=$2; shift 2
  local out status=0
  out=$("$@" 2>&1) || status=$?
  checks=$((checks+1))
  if [[ $status != 0 || $out == *"$needle"* ]]; then
    printf 'FAIL %s (exit %s): unexpected %s\n%s\n' "$name" "$status" "$needle" "$out"
    failures=$((failures+1))
  fi
}
reject() {
  local name=$1; shift
  local out status=0
  out=$("$@" 2>&1) || status=$?
  checks=$((checks+1))
  if [[ $status == 0 || -z $out ]]; then
    printf 'FAIL %s: status=%s output=%s\n' "$name" "$status" "$out"
    failures=$((failures+1))
  fi
}

# Split assistant lines repeat usage; totals count each message.id once and skip API errors.
check dedupe-tokens 'input=14 output=10 cache-read=100 cache-write=20' "$s/claude-session-overview.sh" "$f"
check user-kinds 'prompts=2 commands=1 injected=1 meta=1 tool-results=5 interrupts=1 compact-summaries=1' "$s/claude-session-overview.sh" "$f"
check cost '$1.2346' "$s/claude-session-overview.sh" "$f"
check subagent-count 'agent-calls=1 transcripts=1' "$s/claude-session-overview.sh" "$f"
check prompt-command '/retro abc session' "$s/claude-session-prompts.sh" "$f"
absent prompt-injected NOTIFY_BODY "$s/claude-session-prompts.sh" "$f"
absent prompt-interrupt 'Request interrupted' "$s/claude-session-prompts.sh" "$f"
check prompt-all NOTIFY_BODY "$s/claude-session-prompts.sh" "$f" --all
check prompt-tail 'finish now' "$s/claude-session-prompts.sh" "$f" --tail 1
absent prompt-tail-limit 'fix the bug' "$s/claude-session-prompts.sh" "$f" --tail 1
check thread-compact 'COMPACT manual: 1000 to 100 tokens' "$s/claude-session-thread.sh" "$f"
check thread-results 'RESULT ERROR Bash: Exit code 1 BASH_FAIL' "$s/claude-session-thread.sh" "$f" --tools
absent thread-thinking SECRET_THINKING "$s/claude-session-thread.sh" "$f" --tools --all
absent thread-image BASE64DATA "$s/claude-session-thread.sh" "$f" --tools --all
check thread-window 'TOOL Read' "$s/claude-session-thread.sh" "$f" --since 2026-11-01T10:00:05 --until 2026-11-01T10:00:06
absent thread-window-limit 'TOOL Bash' "$s/claude-session-thread.sh" "$f" --since 2026-11-01T10:00:05 --until 2026-11-01T10:00:06
check thread-cut 'start "quote…' "$s/claude-session-thread.sh" "$f" --max-chars 12
check toolcalls-match 'RESULT ERROR: Exit code 1' "$s/claude-session-toolcalls.sh" "$f" --match 'log\.sh' --with-results
check toolcalls-field 'Read: /work/proj/a.ts' "$s/claude-session-toolcalls.sh" "$f" --tool '^read$' --field file_path --compact
check errors-tool 'TOOL-ERROR Bash' "$s/claude-session-errors.sh" "$f"
check errors-api 'API-ERROR rate_limit' "$s/claude-session-errors.sh" "$f"
check files-unique '2x edit,read /work/proj/a.ts' "$s/claude-session-files.sh" "$f" --unique
check subagent-join 'transcript: ' "$s/claude-session-subagents.sh" "$f"
check subagent-status 'status: async_launched finished=true' "$s/claude-session-subagents.sh" "$f"
check skills 'totals: grilling=1 retro=1' "$s/claude-session-skills.sh" "$f"
check sidechain-file 'agent: abc' "$s/claude-session-overview.sh" "$root/tests/S1/subagents/agent-abc.jsonl"
check sidechain-files 'grep /work/proj/test' "$s/claude-session-files.sh" "$root/tests/S1/subagents/agent-abc.jsonl"

# find: encoded project directory, id lookup, and missing directory.
mkdir -p "$tmp/projects/-work-proj"
cp "$f" "$tmp/projects/-work-proj/S1.jsonl"
check find-project 'title: Fixture title  cwd: /work/proj' env CLAUDE_CONFIG_DIR="$tmp" "$s/claude-session-find.sh" --project /work/proj
check find-id 'S1.jsonl' env CLAUDE_CONFIG_DIR="$tmp" "$s/claude-session-find.sh" --id S1
reject find-missing env CLAUDE_CONFIG_DIR="$tmp" "$s/claude-session-find.sh" --project /nope

# Every report: empty input, malformed JSON, and argument validation.
: > "$tmp/empty.jsonl"
printf '{bad\n' > "$tmp/bad.jsonl"
for cli in "$s"/claude-session-*.sh; do
  [[ $cli != *find.sh ]] || continue
  check "empty ${cli##*/}" '' "$cli" "$tmp/empty.jsonl"
  reject "malformed ${cli##*/}" "$cli" "$tmp/bad.jsonl"
  reject "unknown flag ${cli##*/}" "$cli" "$f" --bogus
  reject "extra positional ${cli##*/}" "$cli" "$f" "$f"
  reject "missing file ${cli##*/}" "$cli" "$tmp/none.jsonl"
done
reject head-and-tail "$s/claude-session-thread.sh" "$f" --head 1 --tail 1
reject bad-op "$s/claude-session-files.sh" "$f" --op delete
reject bad-number "$s/claude-session-thread.sh" "$f" --max-chars -5

printf '%s checks, %s failures\n' "$checks" "$failures"
[[ $failures == 0 ]]
