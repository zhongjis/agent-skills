#!/usr/bin/env bash
# claude-session-skills.sh — Skill tool calls and slash commands, with totals.
# Usage: claude-session-skills.sh <session.jsonl> [options]; options are listed in SKILL.md.
set -euo pipefail
# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
