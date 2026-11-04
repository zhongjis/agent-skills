#!/usr/bin/env bash
# pi-session-toolcalls.sh — Extract and filter tool calls
# Usage: pi-session-toolcalls.sh <session.jsonl> [--tool NAME] [--field FIELD] [--compact]
#
# Options:
#   --tool NAME    Filter by tool name (regex, case-insensitive)
#   --field FIELD  Extract specific argument field (e.g., "command", "path", "prompt")
#   --compact      One line per call (default: multi-line)
#   --with-results Include tool results after each call
#
# Handles both string and object .arguments automatically.
#
# Examples:
#   pi-session-toolcalls.sh s.jsonl --tool bash --field command
#   pi-session-toolcalls.sh s.jsonl --tool "read|write|edit" --field path
#   pi-session-toolcalls.sh s.jsonl --tool agent --field subagent_type --compact

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
