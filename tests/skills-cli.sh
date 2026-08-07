#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains_line() {
  local label="$1"
  local lines="$2"
  local expected="$3"

  printf '%s\n' "$lines" | grep -Fqx -- "$expected" \
    || fail "$label: missing $expected"
}

assert_excludes_line() {
  local label="$1"
  local lines="$2"
  local unexpected="$3"

  if printf '%s\n' "$lines" | grep -Fqx -- "$unexpected"; then
    fail "$label: unexpectedly included $unexpected"
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

json_skill_names() {
  sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
    | LC_ALL=C sort
}

run_cli() {
  (
    cd -- "$targetDir"
    "${cli[@]}" "$@"
  )
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

visibleSkill="visible-fixture"
lockedSkill="locked-fixture"
sourceRepo="$tempDir/source.git"
targetDir="$tempDir/target"
mkdir -p \
  "$sourceRepo/.agents/skills/$visibleSkill/scripts" \
  "$sourceRepo/.agents/skills/$lockedSkill" \
  "$targetDir"

cat >"$sourceRepo/.agents/skills/$visibleSkill/SKILL.md" <<'EOF'
---
name: visible-fixture
description: Synthetic lifecycle fixture.
---

# Visible fixture

fixture-version-1
EOF
cat >"$sourceRepo/.agents/skills/$visibleSkill/scripts/helper.sh" <<'EOF'
#!/usr/bin/env sh
printf 'fixture support file\n'
EOF
chmod +x "$sourceRepo/.agents/skills/$visibleSkill/scripts/helper.sh"
cat >"$sourceRepo/.agents/skills/$lockedSkill/SKILL.md" <<'EOF'
---
name: locked-fixture
description: Synthetic lock-visibility fixture.
---

# Locked fixture
EOF
cat >"$sourceRepo/skills-lock.json" <<EOF
{
  "version": 1,
  "skills": {
    "$lockedSkill": {
      "source": "fixture/origin",
      "sourceType": "github",
      "skillPath": ".agents/skills/$lockedSkill/SKILL.md",
      "computedHash": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
EOF

git -C "$sourceRepo" init --quiet
git -C "$sourceRepo" config user.email fixture@example.invalid
git -C "$sourceRepo" config user.name "Skills CLI Fixture"
git -C "$sourceRepo" add -A
git -C "$sourceRepo" commit --quiet -m initial
git -C "$targetDir" init --quiet
sourceUrl="file://$sourceRepo"

sourceList="$(run_cli add "$sourceUrl" --list)"
printf 'source discovery:\n%s\n' "$sourceList"
sourceNames="$(printf '%s\n' "$sourceList" \
  | sed -nE 's/^│    ([[:alnum:]][[:alnum:]-]*)[[:space:]]*$/\1/p' \
  | LC_ALL=C sort)"
assert_contains_line "source lock visibility" "$sourceNames" "$visibleSkill"
assert_excludes_line "source lock visibility" "$sourceNames" "$lockedSkill"
printf 'lock-aware discovery: unlocked fixture visible; locked fixture hidden\n'

run_cli add "$sourceUrl" \
  --skill "$visibleSkill" \
  --agent pi \
  --copy \
  -y

installedDir="$targetDir/.pi/skills/$visibleSkill"
installedSkillFile="$installedDir/SKILL.md"
installedSupportFile="$installedDir/scripts/helper.sh"
[[ -f "$installedSkillFile" && ! -L "$installedSkillFile" ]] \
  || fail "copied SKILL.md is missing or symlinked"
[[ -f "$installedSupportFile" && ! -L "$installedSupportFile" ]] \
  || fail "support file is missing or symlinked"
[[ ! -e "$targetDir/.agents/skills/$visibleSkill" ]] \
  || fail "copy install created an unexpected canonical projection"
[[ -z "$(find "$targetDir" -type l -print -quit)" ]] \
  || fail "copy install created a symlink"
printf 'explicit copied install: regular files only; support file preserved\n'

listJson="$(run_cli list --agent pi --json)"
listedNames="$(printf '%s\n' "$listJson" | json_skill_names)"
assert_contains_line "Pi list JSON" "$listedNames" "$visibleSkill"
printf 'explicit list: installed fixture visible\n'


beforeRefreshHash="$(cksum "$installedSkillFile")"
sed -i.bak 's/fixture-version-1/fixture-version-2/' \
  "$sourceRepo/.agents/skills/$visibleSkill/SKILL.md"
rm -f -- "$sourceRepo/.agents/skills/$visibleSkill/SKILL.md.bak"
git -C "$sourceRepo" add -A
git -C "$sourceRepo" commit --quiet -m refresh

run_cli add "$sourceUrl" \
  --skill "$visibleSkill" \
  --agent pi \
  --copy \
  -y
afterRefreshHash="$(cksum "$installedSkillFile")"
[[ "$beforeRefreshHash" != "$afterRefreshHash" ]] \
  || fail "scoped copy refresh did not change installed fixture"
grep -Fq 'fixture-version-2' "$installedSkillFile" \
  || fail "scoped copy refresh omitted source change"
[[ -z "$(find "$targetDir" -type l -print -quit)" ]] \
  || fail "scoped copy refresh created a symlink"
printf 'scoped copy refresh: targeted fixture updated without symlinks\n'

run_cli remove "$visibleSkill" --agent pi -y
[[ ! -e "$installedDir" ]] \
  || fail "explicit removal left installed fixture"
if [[ -f "$targetDir/skills-lock.json" ]] \
  && grep -Fq "\"$visibleSkill\"" "$targetDir/skills-lock.json"; then
  fail "explicit removal left fixture lock entry"
fi
[[ -z "$(find "$targetDir/.pi/skills" -type f -name SKILL.md -print 2>/dev/null)" ]] \
  || fail "explicit removal left installed skill leaves"
printf 'explicit removal: copied leaf and lock entry removed\n'

[[ -z "$(git -C "$sourceRepo" status --porcelain=v1 --untracked-files=all)" ]] \
  || fail "fixture source was mutated by Skills CLI"
sourceStatusAfter="$(git -C "$repoRoot" status --porcelain=v1 --untracked-files=all)"
[[ "$sourceStatusAfter" == "$sourceStatusBefore" ]] \
  || fail "repository source tree changed during CLI lifecycle"
printf 'source trees unchanged by Skills CLI: yes\n'
