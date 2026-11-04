#!/usr/bin/env bash
# claude-session-prompts.sh — Human prompts and slash/bash commands; --all adds injected, meta, and summary entries.
# Usage: claude-session-prompts.sh <session.jsonl> [options]; options are listed in SKILL.md.
set -euo pipefail
# shellcheck source=common.bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.bash"
