#!/usr/bin/env bash
# pi-session-files.sh — Files read, written, and edited in a session
# Usage: pi-session-files.sh <session.jsonl> [--op TYPE] [--unique]
#
# Groups files by operation (read/write/edit) with deduplication per group.
#
# Options:
#   --op TYPE   Filter by operation: read, write, edit (default: all)
#   --unique    Print Nx op1,op2 path per unique file path

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
