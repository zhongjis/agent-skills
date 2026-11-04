#!/usr/bin/env bash
# claude-session-overview.sh — One-shot summary: metadata, entry/user kinds, tools, deduped tokens, cost, compactions, subagents.
# Usage: claude-session-overview.sh <session.jsonl> [options]; options are listed in SKILL.md.
set -euo pipefail
# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
