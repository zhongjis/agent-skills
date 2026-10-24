#!/usr/bin/env bash
# pi-session-files.sh — Files read, written, and edited in a session
# Usage: pi-session-files.sh <session.jsonl> [--op TYPE] [--unique]
#
# Groups files by operation (read/write/edit) with deduplication per group.
#
# Options:
#   --op TYPE   Filter by operation: read, write, edit (default: all)
#   --unique    Just print unique file paths, no grouping

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
