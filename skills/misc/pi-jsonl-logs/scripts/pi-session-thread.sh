#!/usr/bin/env bash
# pi-session-thread.sh — Conversation thread with timestamps
# Usage: pi-session-thread.sh <session.jsonl> [--max-chars N] [--head N] [--tail N] [--tools] [--no-empty] [--leaf ID]
#
# Options:
#   --max-chars N   Truncate each message to N chars (default: 300)
#   --head N        Show first N messages only
#   --tail N        Show last N messages only
#   --tools         Include tool results (call markers are always shown)
#   --no-empty      Skip assistant messages with empty content (thinking-only or blank)
#   --leaf ID       Select the parentId path to an entry (raw history, not context)
#
# Each history entry is collapsed to a single line, so --head/--tail count messages.

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
