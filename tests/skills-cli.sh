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

  find "$skillsDir" -type f -name SKILL.md -print \
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
  sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
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
  [[ -f "$tempDir/.pi/skills/pi-jsonl-logs/scripts/pi-session-overview.sh" ]] \
    || fail "$profile install omitted Pi skill support files"
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
  [[ "$beforeCopiedUpdateHash" != "$afterCopiedUpdateHash" ]] \
    || fail "$profile copied Pi sentinel hash did not change during update"
  grep -q "${updateMarker}_UPDATED" "$copiedSkillFile" \
    || fail "$profile copied Pi sentinel did not change during update"
  printf 'profile %s semantic update: %s -> %s\n' \
    "$profile" "$beforeUpdateHash" "$afterUpdateHash"
  printf 'profile %s observed copy-propagation behavior: canonical and Pi leaf both updated\n' \
    "$profile"

  actual="$(installed_files)"
  # Pi leaves are removed during update -p -y (CLI promotes skills to canonical)
  assert_lines_equal "$profile post-update Pi leaves empty" "$actual" ""
  actual="$(canonical_installed_files)"
  expected="$(expected_canonical_files "${profileSkills[@]}")"
  assert_lines_equal "$profile post-update canonical file set" "$actual" "$expected"

  "${cli[@]}" remove "${profileSkills[@]}" --agent pi -y
  actual="$(installed_files)"
  assert_lines_equal "$profile Pi leaves after CLI removal" "$actual" ""
  for skill in "${profileSkills[@]}"; do
    [[ ! -d "$tempDir/.pi/skills/$skill" ]] \
      || fail "$profile Pi skill directory remained after removal: $skill"
  done
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

if [[ "${SKILLS_CLI_FORCE_NPX:-false}" != true ]] \
  && command -v skills >/dev/null 2>&1; then
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

# skills-lock.json is committed, so `skills add . --list` offers only skills NOT in the
# lockfile (the CLI treats locked skills as already-installed). The 58 vendored skills are
# hidden from discovery; only these 16 authored (unlocked) skills remain discoverable.
discoverableSkills=(
  address-comments
  ast-grep
  code-review
  code-review-v2
  codebase-search
  fd
  find-skills
  gh
  github-pr-management
  pi-jsonl-logs
  rg
  setup-repo-docs
  skill-maintainer
  splunk
  use-open-design-canvas
  zoom-out
)
personalSkills=(
  caveman
  nix
  pi-jsonl-logs
)
workSkills=(
  caveman
  pi-jsonl-logs
  python
)

git -C "$tempDir" init --quiet
cd -- "$tempDir"

sourceList="$("${cli[@]}" add "$repoRoot" --list)"
printf 'source discovery:\n%s\n' "$sourceList"
sourceNames="$(printf '%s\n' "$sourceList" \
  | sed -nE 's/^│    ([[:alnum:]][[:alnum:]-]*)[[:space:]]*$/\1/p' \
  | LC_ALL=C sort)"
expectedSourceNames="$(printf '%s\n' "${discoverableSkills[@]}" | LC_ALL=C sort)"
assert_lines_equal "source discovery exact 16 unlocked skills" \
  "$sourceNames" "$expectedSourceNames"
printf 'source exact-16: yes\n'

updateSource="$tempDir/source.git"
mkdir -p "$updateSource/skills"
cp -R "$repoRoot/.agents/skills/caveman" "$updateSource/skills/"
cp -R "$repoRoot/.agents/skills/nix" "$updateSource/skills/"
cp -R "$repoRoot/.agents/skills/python" "$updateSource/skills/"
cp -R "$repoRoot/.pi/skills/pi-jsonl-logs" "$updateSource/skills/"
git -C "$updateSource" init --quiet
git -C "$updateSource" config user.email poc@example.invalid
git -C "$updateSource" config user.name "Skills CLI PoC"
git -C "$updateSource" add skills
git -C "$updateSource" commit --quiet -m initial
updateSourceUrl="file://$updateSource"
printf 'local update source: %s\n' "$updateSourceUrl"

run_profile personal \
  python \
  mysql-best-practices \
  nix \
  "Package manager and functional language for reproducible environments" \
  "${personalSkills[@]}"
# Reset lock between profile runs (normalizes behavior across CLI versions)
rm -f -- "$tempDir/skills-lock.json"
run_profile work \
  nix \
  mysql-best-practices \
  python \
  "Modern Python development with type hints" \
  "${workSkills[@]}"

sourceStatusAfter="$(git -C "$repoRoot" status --porcelain=v1 --untracked-files=all)"
assert_lines_equal "source git status invariant" \
  "$sourceStatusAfter" "$sourceStatusBefore"
printf 'source git status unchanged: yes\n'
