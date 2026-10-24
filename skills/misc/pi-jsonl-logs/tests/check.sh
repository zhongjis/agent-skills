#!/usr/bin/env bash
set -euo pipefail
root="$(dirname -- "${BASH_SOURCE[0]}")/.."
s="$root/scripts"
f="$root/tests/current.jsonl"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
checks=0
failures=0
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
check agent chengfeng "$s/pi-session-subagents.sh" "$f"
check tasks completed "$s/pi-session-tasks.sh" "$f"
check accounting 'tokens:      500' "$s/pi-session-overview.sh" "$f"
check files /nested "$s/pi-session-files.sh" "$f" --unique
check results ONE_RESULT "$s/pi-session-toolcalls.sh" "$f" --field path --with-results
check custom CUSTOM_TEXT "$s/pi-session-custom.sh" "$f" --compact
check thread SUMMARY "$s/pi-session-thread.sh" "$f" --no-empty
check errors interrupted "$s/pi-session-errors.sh" "$f"
check timing '1.5' "$s/pi-session-timing.sh" "$f" --from 'start "quoted"' --to finish
printf '%s checks, %s failures\n' "$checks" "$failures"
[[ $failures == 0 ]]
# Safety and distinct contracts beyond the original nine reproductions.
absent() {
  local name=$1 needle=$2; shift 2
  local out
  out=$("$@" 2>&1) || { printf 'FAIL %s: %s\n' "$name" "$out"; exit 1; }
  [[ $out != *"$needle"* ]] || { printf 'FAIL %s: unexpected %s\n' "$name" "$needle"; exit 1; }
  checks=$((checks+1))
}
reject() {
  local name=$1; shift
  local out status=0
  out=$("$@" 2>&1) || status=$?
  [[ $status != 0 && -n $out ]] || { printf 'FAIL %s: status=%s output=%s\n' "$name" "$status" "$out"; exit 1; }
  checks=$((checks+1))
}
: > "$tmp/empty"
printf '{"type":"session","version":3}\n' > "$tmp/header"
printf '{bad\n' > "$tmp/bad"
for cli in "$s"/pi-session-*.sh; do
  args=()
  [[ $cli != *timing.sh ]] || args=(--from start --to finish)
  reject 'malformed JSON' "$cli" "$tmp/bad" "${args[@]}"
  reject 'unknown flag' "$cli" "$f" --bogus
  reject 'extra positional' "$cli" "$f" "$f"
  if [[ $cli == *timing.sh ]]; then
    reject 'empty timing missing endpoint' "$cli" "$tmp/empty" "${args[@]}"
    reject 'header timing missing endpoint' "$cli" "$tmp/header" "${args[@]}"
  else
    "$cli" "$tmp/empty" > "$tmp/out"
    "$cli" "$tmp/header" > "$tmp/out"
    checks=$((checks+2))
  fi
done
for option in --max-chars --head --tail; do
  reject "missing $option" "$s/pi-session-thread.sh" "$f" "$option"
  reject "invalid $option" "$s/pi-session-thread.sh" "$f" "$option" '1+1'
done
reject 'invalid prompt length' "$s/pi-session-subagents.sh" "$f" --prompt-len -2
reject 'integer overflow' "$s/pi-session-thread.sh" "$f" --head 999999999999999999999
reject 'bad file op' "$s/pi-session-files.sh" "$f" --op garbage
reject 'missing type' "$s/pi-session-custom.sh" "$f" --type
reject 'missing field' "$s/pi-session-toolcalls.sh" "$f" --field
reject 'bad tool regex empty file' "$s/pi-session-toolcalls.sh" "$tmp/empty" --tool '['
reject 'bad custom regex' "$s/pi-session-custom.sh" "$f" --type '['
reject 'bad timing regex' "$s/pi-session-timing.sh" "$f" --from '[' --to finish
reject 'ambiguous endpoint' "$s/pi-session-timing.sh" "$f" --from start --from finish --to finish
reject 'tool-arg missing colon' "$s/pi-session-timing.sh" "$f" --from-tool-arg agent --to finish
check 'quoted regex' 'total: 0' "$s/pi-session-custom.sh" "$f" --type 'no"match'
check 'nested timing' '1.3s' "$s/pi-session-timing.sh" "$f" --from-tool-arg agent:chengfeng --to finish
check 'nested metadata warning' 'complete=false' "$s/pi-session-toolcalls.sh" "$f"
check 'missing arguments' 'arguments unavailable' "$s/pi-session-toolcalls.sh" "$f"
check 'namespace' 'namespace=functions' "$s/pi-session-toolcalls.sh" "$f"
check 'graph not individual' 'not an individual agent' "$s/pi-session-subagents.sh" "$f"
check 'filtered agent summary' 'chengfeng' "$s/pi-session-subagents.sh" "$f" --type chengfeng
absent 'filtered summary excludes others' jintong "$s/pi-session-subagents.sh" "$f" --type chengfeng
check 'task explicit result ID' 'task#7 Build' "$s/pi-session-tasks.sh" "$f"
check 'task dependencies' 'addBlockedBy=["6"]' "$s/pi-session-tasks.sh" "$f"
check 'reasoning not added' 'reasoning:   10 (subset of output)' "$s/pi-session-overview.sh" "$f"
check 'response model' 'requested=requested response=actual' "$s/pi-session-overview.sh" "$f"
check 'assistant count not turns' 'assistant messages: 2' "$s/pi-session-overview.sh" "$f"
check 'compact field results' 'ONE_RESULT' "$s/pi-session-toolcalls.sh" "$f" --compact --field path --with-results
check 'result paired by ID' 'result id=r2: unavailable' "$s/pi-session-toolcalls.sh" "$f" --with-results
check 'null custom data' 'data: null' "$s/pi-session-custom.sh" "$f" --data
check 'array custom data' 'CUSTOM_TEXT' "$s/pi-session-custom.sh" "$f" --data
absent 'custom no image data' SECRET_BASE64 "$s/pi-session-custom.sh" "$f" --data
absent 'thread no image data' SECRET_BASE64 "$s/pi-session-thread.sh" "$f" --tools
absent 'thinking-only hidden' '| thinking |' "$s/pi-session-thread.sh" "$f" --no-empty
check 'system changes' NEW_RULE "$s/pi-session-thread.sh" "$f"
check 'context edit raw metadata' 'target=u omission=true' "$s/pi-session-thread.sh" "$f"
check 'compaction preserves old history' 'start "quoted"' "$s/pi-session-thread.sh" "$f"
absent 'branch selection' OTHER_BRANCH "$s/pi-session-thread.sh" "$f" --leaf end
check 'branch alternate' OTHER_BRANCH "$s/pi-session-thread.sh" "$f" --leaf other
reject 'branch missing' "$s/pi-session-thread.sh" "$f" --leaf missing
printf '%s\n' '{"type":"message","id":"x","parentId":"x","message":{"role":"user","content":"cycle"}}' > "$tmp/cycle"
reject 'branch cycle' "$s/pi-session-thread.sh" "$tmp/cycle" --leaf x
check 'bash structured' 'bash execution exit=1' "$s/pi-session-errors.sh" "$f"
check 'nested error' 'nested tool error agent' "$s/pi-session-errors.sh" "$f"
# Repeated matches must never trigger producer SIGPIPE with pipefail enabled.
jq -nc 'range(0;20000) | {type:"message",id:(tostring),parentId:null,timestamp:"2026-01-01T00:00:00.100Z",message:{role:"user",content:"start finish"}}' > "$tmp/large"
check 'large timing' 'duration: 0s' "$s/pi-session-timing.sh" "$tmp/large" --from start --to finish
check 'large head' '| 0 | user' "$s/pi-session-thread.sh" "$tmp/large" --head 2
# Full --data is deliberately unbounded text, unlike human-readable previews.
jq -nc '{type:"custom_message",customType:"long",content:(("x" * 1000) + "FULL_END")}' > "$tmp/full"
check 'full data' FULL_END "$s/pi-session-custom.sh" "$tmp/full" --data
check 'full compact data' FULL_END "$s/pi-session-custom.sh" "$tmp/full" --compact --data
# Text-hint failures that are also isError=true must not be counted twice.
jq -nc '{type:"message",message:{role:"toolResult",toolName:"bash",isError:true,content:[{type:"text",text:"Command exited with code 2"}]}}' > "$tmp/error"
check 'disjoint errors' 'total records: 1' "$s/pi-session-errors.sh" "$tmp/error"
jq -nc '{type:"message",message:{role:"toolResult",toolName:"bash",isError:false,content:[{type:"text",text:"Command exited with code 2"}]}}' > "$tmp/hint"
check 'bash text hint' 'not structured exit status' "$s/pi-session-errors.sh" "$tmp/hint"
printf '%s total checks passed\n' "$checks"
jq -nc '{type:"message",message:{role:"assistant",content:[{type:"toolCall",id:"flag",name:"flag",arguments:{enabled:false}}]}}' > "$tmp/false"
check 'false argument preserved' false "$s/pi-session-toolcalls.sh" "$tmp/false" --field enabled --compact
check 'compact field missing argument metadata' 'arguments unavailable' "$s/pi-session-toolcalls.sh" "$f" --field path --compact
# Without an explicit result, IDs must remain unknown rather than batch ordinals.
jq -c 'select(.id != "tr")' "$f" > "$tmp/no-task-result"
check 'no invented create ID' 'task#unassigned/unknown Build' "$s/pi-session-tasks.sh" "$tmp/no-task-result"
printf '%s final checks passed\n' "$checks"
# Preserve useful metadata from the existing reports while using current tools.
jq -c '
  if .id == "a" then .message.content |= map(
    if .id == "agent1" then .arguments += {run_in_background:true,inherit_context:true}
    elif .id == "task1" then .arguments.tasks[0].description = "Build acceptance details"
    else . end)
  elif .id == "c" then .display = true
  else . end
' "$f" > "$tmp/preserve"
jq -nc '{type:"session_info",name:"Older name"},
  {type:"session_info",name:"Preserved session name"},
  {type:"message",message:{role:"assistant",model:"requested",responseModel:"actual",content:[]}},
  {type:"custom_message",customType:"hidden-notice",display:false,content:"HIDDEN_TEXT"}' >> "$tmp/preserve"
check 'latest session name' 'name: Preserved session name' "$s/pi-session-overview.sh" "$tmp/preserve"
absent 'old session name superseded' 'Older name' "$s/pi-session-overview.sh" "$tmp/preserve"
check 'thinking character count' 'thinking chars: 7' "$s/pi-session-overview.sh" "$tmp/preserve"
check 'recorded tool counts' '4 unique tools, 9 total recorded calls' "$s/pi-session-overview.sh" "$tmp/preserve"
check 'grouped model pairs' '2 requested=requested response=actual' "$s/pi-session-overview.sh" "$tmp/preserve"
check 'background flag preserved' 'bg=true' "$s/pi-session-subagents.sh" "$tmp/preserve"
check 'inherit flag preserved' 'inherit_context=true' "$s/pi-session-subagents.sh" "$tmp/preserve"
check 'task description preserved' 'desc: Build acceptance details' "$s/pi-session-tasks.sh" "$tmp/preserve"
check 'custom displayed metadata' 'display=true | CUSTOM_TEXT' "$s/pi-session-custom.sh" "$tmp/preserve"
check 'custom hidden metadata' 'display=false | HIDDEN_TEXT' "$s/pi-session-custom.sh" "$tmp/preserve" --data --compact
check 'read unique count' '(2 unique files)' "$s/pi-session-files.sh" "$f" --op read
check 'write unique count' '(1 unique files)' "$s/pi-session-files.sh" "$f" --op write
check 'call-only event retained' '[TOOL:agent]' "$s/pi-session-thread.sh" "$f" --no-empty
absent 'thinking-only still omitted' '| thinking |' "$s/pi-session-thread.sh" "$f" --no-empty
jq -nc '{type:"message",message:{role:"toolResult",toolName:"read",isError:true,content:[{type:"text",text:"READ_FAILED"}]}}' > "$tmp/failed-result"
check 'thread preserves tool failure metadata' 'toolResult:read error=true' "$s/pi-session-thread.sh" "$tmp/failed-result" --tools
[[ $failures == 0 ]]
printf '%s checks passed\n' "$checks"
