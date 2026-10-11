#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-updates.sh [SKILL...] [--diff]

Read-only check of Skills CLI-managed skills in skills-lock.json against
upstream. Each skill is fetched into a temp project and compared with
.agents/skills/<name>. Checks every lock entry when no SKILL is named.
Exit: 0 all current, 1 outdated or failed, 2 usage error.
EOF
}

fail() {
  printf 'check-updates: %s\n' "$*" >&2
  exit 2
}

cleanup() {
  if [[ -n "${tempRoot:-}" && -d "$tempRoot" && "$tempRoot" == /*/tmp.* ]]; then
    rm -rf -- "$tempRoot"
  fi
}

handle_signal() {
  trap - HUP INT TERM
  exit 130
}

scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
rootDir="${CHECK_UPDATES_ROOT:-$scriptDir}"
skillsBin="${CHECK_UPDATES_SKILLS_BIN:-skills}"
requested=()
showDiff=false

while (($#)); do
  case "$1" in
    --help)
      (($# == 1)) || fail "--help cannot be combined with other arguments"
      usage
      exit 0
      ;;
    --diff)
      showDiff=true
      shift
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      requested+=("$1")
      shift
      ;;
  esac
done

lockFile="$rootDir/skills-lock.json"
[[ -f "$lockFile" ]] || fail "missing lock file: $lockFile"
jq -e '.skills | type == "object"' "$lockFile" >/dev/null 2>&1 \
  || fail "invalid lock file: $lockFile"

for name in "${requested[@]}"; do
  jq -e --arg n "$name" '.skills | has($n)' "$lockFile" >/dev/null \
    || fail "skill not in lock: $name"
done

tempRoot=""
trap cleanup EXIT
trap handle_signal HUP INT TERM
tempRoot="$(mktemp -d)"

current=0
outdated=0
failed=0
refresh=()

# ponytail: only github sources are checked; add other sourceTypes by deriving
# their Skills CLI spec in the loop below.
while IFS='|' read -r name source sourceType folder ref; do
  if ((${#requested[@]} > 0)); then
    wanted=false
    for item in "${requested[@]}"; do
      [[ "$item" == "$name" ]] && wanted=true
    done
    [[ "$wanted" == true ]] || continue
  fi

  spec="$source${folder:+/$folder}${ref:+#$ref}"
  sandbox="$tempRoot/$name"
  log="$tempRoot/$name.log"
  localDir="$rootDir/.agents/skills/$name"
  upstreamDir="$sandbox/.agents/skills/$name"
  reason=""
  status=""

  if [[ "$sourceType" != github ]]; then
    reason="unsupported source type $sourceType"
  else
    mkdir -p "$sandbox"
    git -C "$sandbox" init -q
    addStatus=0
    (cd "$sandbox" && "$skillsBin" add "$spec" --skill "$name" --agent universal --copy -y \
      </dev/null >"$log" 2>&1) || addStatus=$?
    if ((addStatus != 0)); then
      reason="$(sed -E $'s/\033\\[[0-9;?]*[A-Za-z]//g; s/\033[^[]//g' "$log" | tr -d '\r' \
        | grep -E '■|✗|rror|No .*found' | tail -n 1 \
        | sed -E 's/^([[:space:]]|■|✗|│|┌|└|├|◇|◆)+//' || true)"
      [[ -n "$reason" ]] || reason="skills add exited $addStatus"
    elif [[ ! -d "$upstreamDir" || ! -d "$localDir" ]]; then
      reason="cannot compare: missing skill directory"
    else
      diffStatus=0
      diff -rq "$upstreamDir" "$localDir" >/dev/null 2>&1 || diffStatus=$?
      case "$diffStatus" in
        0) status=current ;;
        1) status=outdated ;;
        *) reason="cannot compare: diff exited $diffStatus" ;;
      esac
    fi
  fi

  if [[ -n "$reason" ]]; then
    printf 'failed   %s: %s\n' "$name" "$reason"
    ((failed += 1))
  elif [[ "$status" == current ]]; then
    printf 'current  %s\n' "$name"
    ((current += 1))
  else
    printf 'outdated %s\n' "$name"
    ((outdated += 1))
    refresh+=("skills add $spec --skill $name --agent universal --copy -y")
    if [[ "$showDiff" == true ]]; then
      diff -ru "$localDir" "$upstreamDir" \
        | sed -e "s#$localDir#.agents/skills/$name#g" -e "s#$upstreamDir#upstream/$name#g" || true
    fi
  fi
done < <(jq -r '.skills | to_entries | sort_by(.key)[]
  | [.key, .value.source, .value.sourceType,
     (.value.skillPath | sub("/?SKILL\\.md$"; "")), (.value.ref // "")] | join("|")' "$lockFile")

printf '\n%d current, %d outdated, %d failed\n' "$current" "$outdated" "$failed"
if ((outdated > 0)); then
  printf 'Refresh (from repo root):\n'
  printf '  %s\n' "${refresh[@]}"
fi

((outdated == 0 && failed == 0))
