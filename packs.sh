#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: packs.sh PACK... [--agent AGENT]

Install named skill packs for one agent. Defaults to shared .agents/skills.
EOF
}

fail() {
  printf 'packs: %s\n' "$*" >&2
  exit 2
}

scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
packsDir="${PACKS_DIR:-$scriptDir/packs}"
skillsBin="${PACKS_SKILLS_BIN:-skills}"
packs=()
agent="universal"
agentCount=0

while (($#)); do
  case "$1" in
    --help)
      (($# == 1)) || fail "--help cannot be combined with other arguments"
      usage
      exit 0
      ;;
    --agent)
      (($# >= 2)) || fail "--agent requires a value"
      ((agentCount += 1))
      ((agentCount == 1)) || fail "--agent must be specified exactly once"
      agent="$2"
      shift 2
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      packs+=("$1")
      shift
      ;;
  esac
done

((${#packs[@]} > 0)) || fail "at least one pack is required"
[[ -n "$agent" && "$agent" != '*' ]] || fail "invalid agent: $agent"

manifestPaths=()
for pack in "${packs[@]}"; do
  [[ "$pack" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
    || fail "invalid pack name: $pack"
  manifest="$packsDir/$pack.json"
  [[ -f "$manifest" ]] || fail "unknown pack: $pack"
  manifestPaths+=("$manifest")
done

manifestFilter='type == "object"
  and (keys | sort) == ["schema", "skills"]
  and .schema == 1
  and (.skills | type) == "array"
  and (.skills | length) > 0
  and all(.skills[];
    type == "object"
    and (keys | sort) == ["name", "source"]
    and (.source | type) == "string"
    and (.source | test("^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$"))
    and (.name | type) == "string"
    and (.name | test("^[A-Za-z0-9][A-Za-z0-9._-]*$")))'

for manifest in "${manifestPaths[@]}"; do
  jq -e "$manifestFilter" "$manifest" >/dev/null 2>&1 \
    || fail "invalid manifest: $manifest"
done

sources=()
names=()
for manifest in "${manifestPaths[@]}"; do
  while IFS=$'\t' read -r source name; do
    duplicate=false
    for index in "${!names[@]}"; do
      if [[ "${names[$index]}" == "$name" ]]; then
        [[ "${sources[$index]}" == "$source" ]] \
          || fail "skill $name has multiple sources"
        duplicate=true
        break
      fi
    done
    if [[ "$duplicate" == false ]]; then
      sources+=("$source")
      names+=("$name")
    fi
  done < <(jq -r '.skills[] | [.source, .name] | @tsv' "$manifest")
done

orderedSources=()
for source in "${sources[@]}"; do
  seen=false
  for orderedSource in "${orderedSources[@]}"; do
    if [[ "$orderedSource" == "$source" ]]; then
      seen=true
      break
    fi
  done
  [[ "$seen" == true ]] || orderedSources+=("$source")
done

for source in "${orderedSources[@]}"; do
  command=("$skillsBin" add "$source")
  for index in "${!names[@]}"; do
    if [[ "${sources[$index]}" == "$source" ]]; then
      command+=(--skill "${names[$index]}")
    fi
  done
  command+=(--agent "$agent" --copy -y)
  "${command[@]}"
done
