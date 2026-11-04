#!/usr/bin/env bash
# Shared argument validation and jq runner for the claude-session-* reports.
set -euo pipefail
fail() { printf 'Error: %s\n' "$*" >&2; exit 2; }
CLI=${0##*/}
CLI=${CLI#claude-session-}
CLI=${CLI%.sh}
DIR=$(dirname -- "${BASH_SOURCE[0]}")
SESSION='' TOOL='' MATCH='' FIELD='' TYPE='' OPF='' SINCE='' UNTIL=''
ALL=false TOOLS=false RESULTS=false COMPACT=false UNIQUE=false
MAX=300 PROMPT=200 HEAD=-1 TAIL=-1
value() { [[ $# -ge 2 && -n $2 && $2 != --* ]] || fail "$1 requires a value"; }
number() { [[ $2 =~ ^[0-9]+$ && ${#2} -le 9 ]] || fail "$1 requires a nonnegative integer (at most 9 digits)"; }
while (($#)); do
  case "$CLI:$1" in
    toolcalls:--tool) value "$@"; TOOL=$2; shift 2 ;;
    toolcalls:--match) value "$@"; MATCH=$2; shift 2 ;;
    toolcalls:--field) value "$@"; FIELD=$2; shift 2 ;;
    toolcalls:--with-results) RESULTS=true; shift ;;
    toolcalls:--compact) COMPACT=true; shift ;;
    subagents:--type) value "$@"; TYPE=$2; shift 2 ;;
    subagents:--prompt-len) value "$@"; [[ $2 == -1 ]] || number "$1" "$2"; PROMPT=$2; shift 2 ;;
    files:--op) value "$@"; OPF=$2; [[ $OPF =~ ^(read|write|edit|grep|glob)$ ]] || fail "unknown op: $OPF"; shift 2 ;;
    files:--unique) UNIQUE=true; shift ;;
    prompts:--all|thread:--all) ALL=true; shift ;;
    thread:--tools) TOOLS=true; shift ;;
    prompts:--head|thread:--head) value "$@"; number "$1" "$2"; HEAD=$2; shift 2 ;;
    prompts:--tail|thread:--tail) value "$@"; number "$1" "$2"; TAIL=$2; shift 2 ;;
    overview:--since|overview:--until) fail "unknown flag: $1" ;;
    *:--since) value "$@"; SINCE=$2; shift 2 ;;
    *:--until) value "$@"; UNTIL=$2; shift 2 ;;
    *:--max-chars) value "$@"; number "$1" "$2"; MAX=$2; shift 2 ;;
    *:--help) printf 'Usage: %s <session.jsonl> (see SKILL.md for report options)\n' "${0##*/}"; exit 0 ;;
    *:-*) fail "unknown flag: $1" ;;
    *) [[ -z $SESSION ]] || fail 'expected one session file'; SESSION=$1; shift ;;
  esac
done
[[ -n $SESSION && -f $SESSION ]] || fail 'expected a readable session .jsonl file'
[[ $HEAD == -1 || $TAIL == -1 ]] || fail 'use either --head or --tail'
# Decimal conversion also accepts leading zeroes without jq JSON-number errors.
MAX=$((10#$MAX))
[[ $HEAD == -1 ]] || HEAD=$((10#$HEAD))
[[ $TAIL == -1 ]] || TAIL=$((10#$TAIL))
[[ $PROMPT == -1 ]] || PROMPT=$((10#$PROMPT))
# Subagent transcripts live beside the session: <session>/subagents/agent-<id>.{jsonl,meta.json}.
SUBDIR="${SESSION%.jsonl}/subagents"
METAS='[]'
if compgen -G "$SUBDIR/*.meta.json" > /dev/null; then
  METAS=$(jq -c '. + {agentId: (input_filename | capture("agent-(?<id>[^/]+)\\.meta\\.json$").id),
    file: (input_filename | sub("\\.meta\\.json$"; ".jsonl"))}' "$SUBDIR"/*.meta.json | jq -s .)
fi
jq -rs -L "$DIR" --arg cli "$CLI" --arg tool "$TOOL" --arg match "$MATCH" --arg field "$FIELD" \
  --arg type "$TYPE" --arg opf "$OPF" --arg since "$SINCE" --arg until "$UNTIL" --arg subdir "$SUBDIR" \
  --argjson all "$ALL" --argjson tools "$TOOLS" --argjson results "$RESULTS" \
  --argjson compact "$COMPACT" --argjson unique "$UNIQUE" --argjson metas "$METAS" \
  --argjson max "$MAX" --argjson prompt "$PROMPT" --argjson head "$HEAD" --argjson tail "$TAIL" \
  -f "$DIR/reports.jq" -- "$SESSION"
