#!/usr/bin/env bash
# pi-session-tasks.sh — Task lifecycle extraction
# Usage: pi-session-tasks.sh <session.jsonl>
#
# Shows current Task calls (create/update/list/get).
# Tracks: task subjects, status transitions, completion order.

set -euo pipefail

# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
