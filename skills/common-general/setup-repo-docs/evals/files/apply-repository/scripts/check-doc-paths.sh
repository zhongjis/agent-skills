#!/usr/bin/env bash
set -euo pipefail
test -f docs/api.md
test -f docs/deploy.md
test -f docs/cache.md
