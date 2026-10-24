#!/usr/bin/env bash
# pi-session-timing.sh — Measure time between events in a session
# Usage: pi-session-timing.sh <session.jsonl> --from PATTERN --to PATTERN
#
# Match modes (use one per endpoint):
#   --from/--to PATTERN       Match text content (user/assistant messages)
#   --from-tool/--to-tool NAME  Match by tool name
#   --from-tool-arg/--to-tool-arg 'NAME:PATTERN'  Match tool call where arg JSON contains PATTERN
#
# Examples:
#   pi-session-timing.sh s.jsonl --from-tool-arg 'agent:fuxi' --to 'skip fuxi'
#   pi-session-timing.sh s.jsonl --from 'plannotator never' --to 'skip fuxi'
#   pi-session-timing.sh s.jsonl --from-tool agent --to-tool get_subagent_result

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
