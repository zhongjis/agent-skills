#!/usr/bin/env bash
# pi-session-overview.sh — One-shot session summary
# Usage: pi-session-overview.sh <session.jsonl>
#
# Outputs: entry type breakdown, message roles, tool frequency,
#          full-session cost & tokens, model, thinking stats,
#          session duration.

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
