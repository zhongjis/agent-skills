#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_lines_equal() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nExpected:\n%s\nActual:\n%s\n' \
      "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

cleanup() {
  if [[ -n "${tempDir:-}" && -d "$tempDir" && "$tempDir" == /*/tmp.* ]]; then
    if [[ "${usingNpxFallback:-false}" == true ]]; then
      local configPath

      for configPath in "$npmConfigCache" "$npmConfigUserconfig" "$xdgCacheHome" "$xdgConfigHome"; do
        [[ "$configPath" == "$tempDir/"* ]] \
          || fail "npx fallback path escaped temp project: $configPath"
      done
      printf 'npx fallback paths confined to temp project: yes\n'
    fi
    rm -rf -- "$tempDir"
    [[ ! -e "$tempDir" ]] || fail "temp cleanup failed: $tempDir"
    printf 'cleanup removed temp project: %s\n' "$tempDir"
  fi
}

handle_signal() {
  trap - HUP INT TERM
  exit 130
}

installed_files() {
  local skillsDir="$tempDir/.pi/skills"

  if [[ ! -d "$skillsDir" ]]; then
    return
  fi

  find "$skillsDir" -type f -print \
    | sed "s#^$tempDir/##" \
    | LC_ALL=C sort
}

canonical_installed_files() {
  local skillsDir="$tempDir/.agents/skills"

  if [[ ! -d "$skillsDir" ]]; then
    return
  fi

  find "$skillsDir" -type f -name SKILL.md -print \
    | sed "s#^$tempDir/##" \
    | LC_ALL=C sort
}

all_installed_skill_files() {
  local skillsDir

  for skillsDir in "$tempDir/.agents/skills" "$tempDir/.pi/skills"; do
    if [[ -d "$skillsDir" ]]; then
      find "$skillsDir" -type f -name SKILL.md -print
    fi
  done | LC_ALL=C sort
}

expected_files() {
  local skill

  for skill in "$@"; do
    printf '.pi/skills/%s/SKILL.md\n' "$skill"
  done | LC_ALL=C sort
}

expected_canonical_files() {
  local skill

  for skill in "$@"; do
    printf '.agents/skills/%s/SKILL.md\n' "$skill"
  done | LC_ALL=C sort
}

json_skill_names() {
  sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"(poc-(common|pi)-(general|personal|work))".*/\1/p' \
    | LC_ALL=C sort
}

run_profile() {
  local profile="$1"
  local oppositeCommon="$2"
  local oppositePi="$3"
  local updateSkill="$4"
  local updateMarker="$5"
  shift 5
  local profileSkills=("$@")
  local expected
  local actual
  local listJson
  local listedNames
  local sourceSkillFile
  local installedSkillFile
  local copiedSkillFile
  local beforeUpdateHash
  local afterUpdateHash
  local beforeCopiedUpdateHash
  local afterCopiedUpdateHash
  local updateOutput

  printf 'profile %s expected skills:\n' "$profile"
  printf '%s\n' "${profileSkills[@]}" | LC_ALL=C sort

  "${cli[@]}" add "$updateSourceUrl" \
    --skill "${profileSkills[@]}" \
    --agent pi \
    --copy \
    -y

  expected="$(expected_files "${profileSkills[@]}")"
  actual="$(installed_files)"
  assert_lines_equal "$profile installed file set" "$actual" "$expected"
  [[ ! -e "$tempDir/.pi/skills/$oppositeCommon" ]] \
    || fail "$profile installed opposite common profile skill"
  [[ ! -e "$tempDir/.pi/skills/$oppositePi" ]] \
    || fail "$profile installed opposite Pi profile skill"
  [[ ! -e "$tempDir/.agents/skills/$oppositeCommon" ]] \
    || fail "$profile installed opposite canonical profile skill"
  [[ ! -e "$tempDir/.agents/skills/$oppositePi" ]] \
    || fail "$profile installed opposite canonical Pi profile skill"
  printf 'profile %s exact installed files:\n%s\n' "$profile" "$actual"

  listJson="$("${cli[@]}" list --agent pi --json)"
  printf 'profile %s list JSON:\n%s\n' "$profile" "$listJson"
  listedNames="$(printf '%s\n' "$listJson" | json_skill_names)"
  expected="$(printf '%s\n' "${profileSkills[@]}" | LC_ALL=C sort)"
  assert_lines_equal "$profile list JSON skill set" "$listedNames" "$expected"

  sourceSkillFile="$(find "$updateSource/skills" \
    -path "*/$updateSkill/SKILL.md" -type f -print)"
  [[ -n "$sourceSkillFile" && "$sourceSkillFile" != *$'\n'* ]] \
    || fail "$profile update source skill is not unique"
  installedSkillFile="$tempDir/.agents/skills/$updateSkill/SKILL.md"
  copiedSkillFile="$tempDir/.pi/skills/$updateSkill/SKILL.md"

  updateOutput="$("${cli[@]}" update -p -y)"
  printf 'profile %s update fixture initialization:\n%s\n' \
    "$profile" "$updateOutput"
  [[ "$updateOutput" != *"No project skills to update."* ]] \
    || fail "$profile update fixture was ineligible"
  [[ -f "$installedSkillFile" ]] \
    || fail "$profile canonical installed skill is missing"
  [[ -f "$copiedSkillFile" ]] \
    || fail "$profile copied Pi skill is missing"
  beforeUpdateHash="$(cksum "$installedSkillFile")"
  beforeCopiedUpdateHash="$(cksum "$copiedSkillFile")"

  sed -i.bak "s/$updateMarker/${updateMarker}_UPDATED/" "$sourceSkillFile"
  rm -f -- "$sourceSkillFile.bak"
  grep -q "${updateMarker}_UPDATED" "$sourceSkillFile" \
    || fail "$profile source sentinel did not change"
  git -C "$updateSource" add "$sourceSkillFile"
  git -C "$updateSource" commit --quiet -m "update $updateSkill"

  updateOutput="$("${cli[@]}" update -p -y)"
  printf 'profile %s update output:\n%s\n' "$profile" "$updateOutput"
  [[ "$updateOutput" != *"No project skills to update."* ]] \
    || fail "$profile update was a semantic no-op"
  [[ "$updateOutput" == *"Updated $updateSkill"* ]] \
    || fail "$profile update did not report the sentinel skill"
  afterUpdateHash="$(cksum "$installedSkillFile")"
  [[ "$beforeUpdateHash" != "$afterUpdateHash" ]] \
    || fail "$profile installed sentinel hash did not change"
  grep -q "${updateMarker}_UPDATED" "$installedSkillFile" \
    || fail "$profile installed sentinel did not change"
  afterCopiedUpdateHash="$(cksum "$copiedSkillFile")"
  [[ "$beforeCopiedUpdateHash" == "$afterCopiedUpdateHash" ]] \
    || fail "$profile copied Pi sentinel hash changed during update"
  ! grep -q "${updateMarker}_UPDATED" "$copiedSkillFile" \
    || fail "$profile copied Pi sentinel changed during update"
  printf 'profile %s semantic update: %s -> %s\n' \
    "$profile" "$beforeUpdateHash" "$afterUpdateHash"
  printf 'profile %s observed copy-snapshot behavior: canonical changed; copied Pi leaf unchanged\n' \
    "$profile"

  actual="$(installed_files)"
  expected="$(expected_files "${profileSkills[@]}")"
  assert_lines_equal "$profile post-update file set" "$actual" "$expected"
  actual="$(canonical_installed_files)"
  expected="$(expected_canonical_files "${profileSkills[@]}")"
  assert_lines_equal "$profile post-update canonical file set" "$actual" "$expected"

  "${cli[@]}" remove "${profileSkills[@]}" --agent pi -y
  actual="$(installed_files)"
  assert_lines_equal "$profile Pi leaves after CLI removal" "$actual" ""
  actual="$(canonical_installed_files)"
  expected="$(expected_canonical_files "${profileSkills[@]}")"
  assert_lines_equal "$profile canonical leaves retained after CLI removal" "$actual" "$expected"
  printf 'profile %s CLI removal: Pi projection empty; canonical leaves retained\n' "$profile"
  for skill in "${profileSkills[@]}"; do
    rm -rf -- "$tempDir/.agents/skills/$skill"
  done
  actual="$(all_installed_skill_files)"
  assert_lines_equal "$profile zero installed SKILL.md leaves" "$actual" ""
  printf 'profile %s temp cleanup after CLI removal: all leaves removed\n' "$profile"
}

scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repoRoot="$(cd -- "$scriptDir/.." && pwd -P)"
sourceStatusBefore="$(git -C "$repoRoot" status --porcelain=v1 --untracked-files=all)"

tempDir="$(mktemp -d)"
[[ -n "$tempDir" && -d "$tempDir" && "$tempDir" == /*/tmp.* ]] \
  || fail "unsafe temp directory: $tempDir"
trap cleanup EXIT
trap handle_signal HUP INT TERM
printf 'temp project: %s\n' "$tempDir"

if command -v skills >/dev/null 2>&1; then
  cli=(skills)
else
  cli=(npx skills)
  usingNpxFallback=true
  npmConfigCache="$tempDir/.npm-cache"
  npmConfigUserconfig="$tempDir/.npmrc"
  xdgCacheHome="$tempDir/.xdg-cache"
  xdgConfigHome="$tempDir/.xdg-config"
  export npm_config_cache="$npmConfigCache"
  export npm_config_userconfig="$npmConfigUserconfig"
  export XDG_CACHE_HOME="$xdgCacheHome"
  export XDG_CONFIG_HOME="$xdgConfigHome"
fi

printf 'resolved command: %s\n' "${cli[*]}"
printf 'resolved version: '
"${cli[@]}" --version

allSkills=(
  poc-common-general
  poc-common-personal
  poc-common-work
  poc-pi-general
  poc-pi-personal
  poc-pi-work
)
personalSkills=(
  poc-common-general
  poc-common-personal
  poc-pi-general
  poc-pi-personal
)
workSkills=(
  poc-common-general
  poc-common-work
  poc-pi-general
  poc-pi-work
)

sourceList="$("${cli[@]}" add "$repoRoot" --list)"
printf 'source discovery:\n%s\n' "$sourceList"
sourceNames="$(printf '%s\n' "$sourceList" \
  | sed -nE 's/^[^[:alnum:]]*(poc-(common|pi)-(general|personal|work))[[:space:]]*$/\1/p' \
  | LC_ALL=C sort)"
expectedSourceNames="$(printf '%s\n' "${allSkills[@]}" | LC_ALL=C sort)"
assert_lines_equal "source discovery exact six unique skills" \
  "$sourceNames" "$expectedSourceNames"
printf 'source exact-six: yes\n'

git -C "$tempDir" init --quiet
cd -- "$tempDir"

updateSource="$tempDir/source.git"
mkdir -p "$updateSource/skills"
cp -R "$repoRoot/skills/." "$updateSource/skills/"
git -C "$updateSource" init --quiet
git -C "$updateSource" config user.email poc@example.invalid
git -C "$updateSource" config user.name "Skills CLI PoC"
git -C "$updateSource" add skills
git -C "$updateSource" commit --quiet -m initial
updateSourceUrl="file://$updateSource"
printf 'local update source: %s\n' "$updateSourceUrl"

run_profile personal \
  poc-common-work \
  poc-pi-work \
  poc-common-personal \
  POC_COMMON_PERSONAL \
  "${personalSkills[@]}"
run_profile work \
  poc-common-personal \
  poc-pi-personal \
  poc-common-work \
  POC_COMMON_WORK \
  "${workSkills[@]}"

sourceStatusAfter="$(git -C "$repoRoot" status --porcelain=v1 --untracked-files=all)"
assert_lines_equal "source git status invariant" \
  "$sourceStatusAfter" "$sourceStatusBefore"
printf 'source git status unchanged: yes\n'
