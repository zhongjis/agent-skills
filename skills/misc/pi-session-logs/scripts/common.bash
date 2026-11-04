#!/usr/bin/env bash
# Shared argument validation and jq runner for the nine session reports.
set -euo pipefail
fail() { printf 'Error: %s\n' "$*" >&2; exit 2; }
CLI=${0##*/pi-session-}
CLI=${CLI%.sh}
DIR=$(dirname -- "${BASH_SOURCE[0]}")
SESSION='' TOOL='' FIELD='' TYPE='' OP='' LEAF=''
FROM='' TO='' FROM_MODE='' TO_MODE=''
COMPACT=false RESULTS=false DATA=false UNIQUE=false TOOLS=false NOEMPTY=false
MAX=300 PROMPT=200 HEAD=-1 TAIL=-1
value() { [[ $# -ge 2 && -n $2 && $2 != --* ]] || fail "$1 requires a value"; }
number() { [[ $2 =~ ^[0-9]+$ && ${#2} -le 9 ]] || fail "$1 requires a nonnegative integer (at most 9 digits)"; }
while (($#)); do
  case "$CLI:$1" in
    toolcalls:--tool) value "$@"; TOOL=$2; shift 2 ;;
    toolcalls:--field) value "$@"; FIELD=$2; shift 2 ;;
    toolcalls:--with-results) RESULTS=true; shift ;;
    toolcalls:--compact|custom:--compact|errors:--compact) COMPACT=true; shift ;;
    custom:--type|subagents:--type) value "$@"; TYPE=$2; shift 2 ;;
    custom:--data) DATA=true; shift ;;
    subagents:--prompt-len) value "$@"; [[ $2 == -1 ]] || number "$1" "$2"; PROMPT=$2; shift 2 ;;
    files:--op) value "$@"; OP=$2; [[ $OP =~ ^(read|write|edit|grep|find|ls)$ ]] || fail "unknown op: $OP"; shift 2 ;;
    files:--unique) UNIQUE=true; shift ;;
    thread:--leaf) value "$@"; LEAF=$2; shift 2 ;;
    thread:--max-chars) value "$@"; number "$1" "$2"; MAX=$2; shift 2 ;;
    thread:--head) value "$@"; number "$1" "$2"; HEAD=$2; shift 2 ;;
    thread:--tail) value "$@"; number "$1" "$2"; TAIL=$2; shift 2 ;;
    thread:--tools) TOOLS=true; shift ;;
    thread:--no-empty) NOEMPTY=true; shift ;;
    timing:--from|timing:--from-tool|timing:--from-tool-arg)
      value "$@"; [[ -z $FROM_MODE ]] || fail 'use one from endpoint'; FROM_MODE=${1#--from}; FROM_MODE=${FROM_MODE:-text}; FROM=$2; shift 2 ;;
    timing:--to|timing:--to-tool|timing:--to-tool-arg)
      value "$@"; [[ -z $TO_MODE ]] || fail 'use one to endpoint'; TO_MODE=${1#--to}; TO_MODE=${TO_MODE:-text}; TO=$2; shift 2 ;;
    *:--help) printf 'Usage: %s <session.jsonl> (see SKILL.md for report options)\n' "${0##*/}"; exit 0 ;;
    *:-*) fail "unknown flag: $1" ;;
    *) [[ -z $SESSION ]] || fail 'expected one session file'; SESSION=$1; shift ;;
  esac
done
[[ -n $SESSION && -f $SESSION ]] || fail 'expected a readable session.jsonl file'
[[ $CLI != timing || ( -n $FROM && -n $TO ) ]] || fail 'need both from and to endpoints'
# Decimal conversion also accepts leading zeroes without jq JSON-number errors.
[[ $HEAD == -1 || $TAIL == -1 ]] || fail 'use either --head or --tail'
MAX=$((10#$MAX))
[[ $HEAD == -1 ]] || HEAD=$((10#$HEAD))
[[ $TAIL == -1 ]] || TAIL=$((10#$TAIL))
[[ $PROMPT == -1 ]] || PROMPT=$((10#$PROMPT))
jq -rs -L "$DIR" --arg cli "$CLI" --arg tool "$TOOL" --arg field "$FIELD" \
  --arg type "$TYPE" --arg op "$OP" --arg leaf "$LEAF" \
  --arg from "$FROM" --arg to "$TO" --arg fm "$FROM_MODE" --arg tm "$TO_MODE" \
  --argjson compact "$COMPACT" --argjson results "$RESULTS" --argjson data "$DATA" \
  --argjson unique "$UNIQUE" --argjson tools "$TOOLS" --argjson noempty "$NOEMPTY" \
  --argjson max "$MAX" --argjson prompt "$PROMPT" --argjson head "$HEAD" --argjson tail "$TAIL" \
  -f "$DIR/reports.jq" "$SESSION"
