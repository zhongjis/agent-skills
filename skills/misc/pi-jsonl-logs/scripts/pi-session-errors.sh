#!/usr/bin/env bash
# pi-session-errors.sh — Extract errors and failed tool calls
# Usage: pi-session-errors.sh <session.jsonl> [--compact]
#
# Shows:
#   - Tool results where isError==true (with tool name and output)
#   - Bash structured failures and explicitly labelled output-text hints
#
# Options:
#   --compact   One line per error (truncated)

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
