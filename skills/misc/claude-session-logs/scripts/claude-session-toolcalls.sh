#!/usr/bin/env bash
# claude-session-toolcalls.sh — Tool calls filtered by name or input regex, with optional results.
# Usage: claude-session-toolcalls.sh <session.jsonl> [options]; options are listed in SKILL.md.
set -euo pipefail
# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
