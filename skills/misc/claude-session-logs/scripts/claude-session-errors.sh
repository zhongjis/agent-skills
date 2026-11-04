#!/usr/bin/env bash
# claude-session-errors.sh — Failed or interrupted tool results and API errors.
# Usage: claude-session-errors.sh <session.jsonl> [options]; options are listed in SKILL.md.
set -euo pipefail
# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
