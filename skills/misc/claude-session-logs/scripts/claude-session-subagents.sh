#!/usr/bin/env bash
# claude-session-subagents.sh — Agent calls joined to recorded status and subagent transcript paths.
# Usage: claude-session-subagents.sh <session.jsonl> [options]; options are listed in SKILL.md.
set -euo pipefail
# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
