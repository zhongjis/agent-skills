#!/usr/bin/env bash
# pi-session-custom.sh — Extract custom and custom_message entries
# Usage: pi-session-custom.sh <session.jsonl> [--type TYPE] [--data] [--compact]
#
# Shows custom/custom_message entries grouped by customType.
#
# Options:
#   --type TYPE   Filter by customType (regex, case-insensitive)
#   --data        Show .data fields (custom) or .content (custom_message)
#   --compact     One line per entry

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
