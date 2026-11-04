#!/usr/bin/env bash
# claude-session-files.sh — Path arguments of file tools (Read, Write, Edit, NotebookEdit, Grep, Glob).
# Usage: claude-session-files.sh <session.jsonl> [options]; options are listed in SKILL.md.
set -euo pipefail
# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
