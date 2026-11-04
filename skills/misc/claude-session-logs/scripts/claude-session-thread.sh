#!/usr/bin/env bash
# claude-session-thread.sh — Interleaved timeline of prompts, assistant text, tool calls, and compactions.
# Usage: claude-session-thread.sh <session.jsonl> [options]; options are listed in SKILL.md.
set -euo pipefail
# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
