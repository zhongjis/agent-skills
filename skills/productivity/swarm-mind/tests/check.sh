#!/usr/bin/env bash
# Offline checks for swarm-mind's scripts against a fake PATH of dummy agents.
set -euo pipefail

scripts=$(realpath "$(dirname -- "${BASH_SOURCE[0]}")/../scripts")
tmp=$(realpath "$(mktemp -d)")
trap 'rm -rf "$tmp"' EXIT

# The reviewer chain reads installed kinds from PATH and caches them per PATH.
agents="$tmp/agents"
mkdir -p "$agents"
for kind in claude pi agy; do printf '#!/bin/sh\n' > "$agents/$kind"; chmod +x "$agents/$kind"; done
chain_path="$agents:$(dirname -- "$(command -v bash)"):$(dirname -- "$(command -v cksum)")"
chain() { env -i HOME="$HOME" XDG_RUNTIME_DIR="$tmp/run" PATH="$chain_path" "$scripts/reviewers.sh" "$@"; }
[[ $(chain) == $'claude claude\npi any\nagy gemini' ]]
[[ $(chain --visual) == $'agy gemini\nclaude claude\npi any' ]]
[[ $(chain --not claude) == $'pi any\nagy gemini' ]]
# A cached probe survives an install until PATH changes or --refresh.
printf '#!/bin/sh\n' > "$agents/codex"; chmod +x "$agents/codex"
[[ $(chain) != *codex* ]]
[[ $(chain --refresh) == $'claude claude\ncodex gpt\npi any\nagy gemini' ]]
rm "$agents/codex"
chain_path="$chain_path:$tmp/empty"
[[ $(chain) != *codex* ]]
# A missing --not value is a usage error.
set +e
err=$("$scripts/reviewers.sh" --not 2>&1); status=$?
set -e
[[ $status -eq 1 && $err == *usage* ]]

printf 'swarm-mind checks passed\n'
