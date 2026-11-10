#!/usr/bin/env bash
# pi-session-prompts.sh — Human prompts and direct Bash executions with timestamps
# Usage: pi-session-prompts.sh <session.jsonl> [--max-chars N] [--head N] [--tail N]
#
# Options:
#   --max-chars N   Truncate each message to N chars (default: 300, 0=full)
#   --head N        Show first N messages only
#   --tail N        Show last N messages only
#
# Image counts are shown without image bodies; Bash entries show command and exit.

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
