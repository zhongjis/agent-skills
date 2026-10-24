#!/usr/bin/env bash
# pi-session-subagents.sh — Extract agent/subagent delegations
# Usage: pi-session-subagents.sh <session.jsonl> [--type TYPE] [--prompt-len N]
#
# Options:
#   --type TYPE      Filter by subagent_type (e.g., fuxi, chengfeng, jintong)
#   --prompt-len N   Max chars of prompt to show (default: 200, 0=hide, -1=full)
#
# Handles both string and object .arguments (the common gotcha).

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
