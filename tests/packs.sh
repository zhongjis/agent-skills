#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_status() {
  local label="$1"
  local expected="$2"

  [[ "$runStatus" -eq "$expected" ]] \
    || fail "$label: expected status $expected, got $runStatus: $runOutput"
}

assert_no_calls() {
  local label="$1"

  [[ ! -s "$callsFile" ]] || fail "$label: fake Skills CLI was invoked"
}

assert_calls() {
  local label="$1"
  local expected="$2"
  local actual

  actual="$(cat -- "$callsFile")"
  [[ "$actual" == "$expected" ]] \
    || fail "$label: unexpected Skills CLI calls
expected:
$expected
actual:
$actual"
}

cleanup() {
  if [[ -n "${tempDir:-}" && -d "$tempDir" && "$tempDir" == /*/tmp.* ]]; then
    rm -rf -- "$tempDir"
    [[ ! -e "$tempDir" ]] || fail "temp cleanup failed: $tempDir"
  fi
}

handle_signal() {
  trap - HUP INT TERM
  exit 130
}

write_manifest() {
  local pack="$1"
  shift

  {
    printf '{"schema":1,"skills":['
    local separator=""
    local tuple source name
    for tuple in "$@"; do
      name="${tuple%%:*}"
      source="${tuple#*:}"
      printf '%s{"source":"%s","name":"%s"}' "$separator" "$source" "$name"
      separator=,
    done
    printf ']}\n'
  } >"$packsDir/$pack.json"
}

write_dependent_manifest() {
  local pack="$1"
  local dependencies="$2"
  shift 2

  {
    printf '{"schema":1,"dependsOn":%s,"skills":[' "$dependencies"
    local separator=""
    local tuple source name
    for tuple in "$@"; do
      name="${tuple%%:*}"
      source="${tuple#*:}"
      printf '%s{"source":"%s","name":"%s"}' "$separator" "$source" "$name"
      separator=,
    done
    printf ']}\n'
  } >"$packsDir/$pack.json"
}

write_source_manifest() {
  local pack="$1"
  local source="$2"
  local name="$3"

  printf '{"schema":1,"skills":[{"source":"%s","name":"%s"}]}\n' \
    "$source" "$name" >"$packsDir/$pack.json"
}

reset_fixture() {
  rm -rf -- "$packsDir" "$callerDir"
  mkdir -p -- "$packsDir" "$callerDir"
  : >"$callsFile"
  runPacksDir=""

  write_manifest typescript \
    'typescript-best-practices:https://github.com/0xBigBoss/claude-code' \
    'biome:https://github.com/bobmatnyc/claude-mpm-skills' \
    'pnpm:https://github.com/antfu/skills' \
    'turborepo:https://github.com/vercel/turborepo' \
    'vitest:https://github.com/antfu/skills'
  write_manifest vercel \
    'deploy-to-vercel:https://github.com/vercel-labs/agent-skills' \
    'vercel-react-best-practices:https://github.com/vercel-labs/agent-skills' \
    'vercel-composition-patterns:https://github.com/vercel-labs/agent-skills' \
    'vercel-optimize:https://github.com/vercel-labs/agent-skills'
  write_manifest collision \
    'shared-skill:https://github.com/owner/one' \
    'shared-skill:https://github.com/owner/two'
  write_manifest failfirst \
    'first-skill:https://github.com/owner/failing' \
    'later-skill:https://github.com/owner/later'
  write_manifest foundation 'foundation-skill:https://github.com/owner/foundation'
  write_dependent_manifest shared '["foundation"]' 'shared-skill:https://github.com/owner/shared'
  write_dependent_manifest left '["shared"]' 'left-skill:https://github.com/owner/left'
  write_dependent_manifest right '["shared"]' 'right-skill:https://github.com/owner/right'
  write_dependent_manifest app '["left","right"]' 'app-skill:https://github.com/owner/app'
  write_manifest extra 'extra-skill:https://github.com/owner/extra'
  write_source_manifest https-source 'https://github.com/antfu/skills' 'https-skill'
  write_dependent_manifest missing-middle '["missing-leaf"]' 'middle-skill:https://github.com/owner/middle'
  write_dependent_manifest missing-root '["missing-middle"]' 'root-skill:https://github.com/owner/root'
  write_dependent_manifest cycle-a '["cycle-b"]' 'cycle-a-skill:https://github.com/owner/cycle-a'
  write_dependent_manifest cycle-b '["cycle-a"]' 'cycle-b-skill:https://github.com/owner/cycle-b'
  write_dependent_manifest malformed-root '["malformed-json"]' 'root-skill:https://github.com/owner/root'
  write_manifest deep-one 'deep-conflict:https://github.com/owner/one'
  write_manifest deep-two 'deep-conflict:https://github.com/owner/two'
  write_dependent_manifest deep-root '["deep-one","deep-two"]' 'root-skill:https://github.com/owner/root'
  write_dependent_manifest empty-dependencies '[]' 'empty-skill:https://github.com/owner/empty'
  printf '{"schema":1,"dependsOn":"foundation","skills":[{"source":"https://github.com/owner/root","name":"root-skill"}]}\n' >"$packsDir/invalid-dependency-type.json"
  printf '{"schema":1,"dependsOn":["foundation",42],"skills":[{"source":"https://github.com/owner/root","name":"root-skill"}]}\n' >"$packsDir/invalid-dependency-entry.json"
  printf '{"schema":1,"dependsOn":["../foundation"],"skills":[{"source":"https://github.com/owner/root","name":"root-skill"}]}\n' >"$packsDir/invalid-dependency-name.json"
  printf '{"schema":1,"dependsOn":[],"extra":true,"skills":[{"source":"https://github.com/owner/root","name":"root-skill"}]}\n' >"$packsDir/invalid-manifest-keys.json"
  printf '{"schema":1,"skills":[{"source":7,"name":"bad-source"}]}\n' >"$packsDir/invalid-source-type.json"
  write_source_manifest invalid-source-shorthand 'owner/repo' 'bad-source'
  write_source_manifest invalid-source-http 'http://github.com/antfu/skills' 'bad-source'
  write_source_manifest invalid-source-empty-https 'https://' 'bad-source'
  write_source_manifest invalid-source-no-host 'https:///antfu/skills' 'bad-source'
  write_source_manifest invalid-source-whitespace 'https://github.com/antfu/bad path' 'bad-source'
  write_source_manifest invalid-source-control 'https://github.com/antfu/bad\u0001path' 'bad-source'
  write_source_manifest invalid-source-ftp 'ftp://github.com/antfu/skills' 'bad-source'
  write_source_manifest invalid-source-local '../local/path' 'bad-source'
  write_source_manifest invalid-source-ssh 'git@github.com:antfu/skills' 'bad-source'
  printf '{not-json\n' >"$packsDir/malformed-json.json"
  printf '{"schema":2,"skills":[]}\n' >"$packsDir/malformed-schema.json"
}

run_packs() {
  set +e
  runOutput="$({
    cd -- "$callerDir"
    PACKS_DIR="${runPacksDir:-$packsDir}" \
      PACKS_SKILLS_BIN="$fakeSkills" \
      FAKE_SKILLS_CALLS="$callsFile" \
      FAKE_SKILLS_LOCK_BYTES_FILE="${lockBytesFile:-}" \
      FAKE_SKILLS_FAIL_SOURCE="${failSource:-}" \
      FAKE_SKILLS_FAIL_STATUS="${failStatus:-37}" \
      "$runner" "$@"
  } 2>&1)"
  runStatus=$?
  set -e
}

packs_multi_source_install() {
  reset_fixture
  run_packs typescript vercel --agent pi
  assert_status packs_multi_source_install 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/0xBigBoss/claude-code'$'\t''--skill'$'\t''typescript-best-practices'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/bobmatnyc/claude-mpm-skills'$'\t''--skill'$'\t''biome'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/antfu/skills'$'\t''--skill'$'\t''pnpm'$'\t''--skill'$'\t''vitest'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/vercel/turborepo'$'\t''--skill'$'\t''turborepo'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/vercel-labs/agent-skills'$'\t''--skill'$'\t''deploy-to-vercel'$'\t''--skill'$'\t''vercel-react-best-practices'$'\t''--skill'$'\t''vercel-composition-patterns'$'\t''--skill'$'\t''vercel-optimize'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_multi_source_install "$expected"
}

packs_resolves_dependencies_in_dfs_order() {
  reset_fixture
  run_packs app extra --agent pi
  assert_status packs_resolves_dependencies_in_dfs_order 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/owner/foundation'$'\t''--skill'$'\t''foundation-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/owner/shared'$'\t''--skill'$'\t''shared-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/owner/left'$'\t''--skill'$'\t''left-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/owner/right'$'\t''--skill'$'\t''right-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/owner/app'$'\t''--skill'$'\t''app-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/owner/extra'$'\t''--skill'$'\t''extra-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_resolves_dependencies_in_dfs_order "$expected"
}

packs_forwards_https_source_exactly() {
  reset_fixture
  run_packs https-source --agent pi
  assert_status packs_forwards_https_source_exactly 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/antfu/skills'$'\t''--skill'$'\t''https-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_forwards_https_source_exactly "$expected"
}

packs_accepts_schema_one_with_empty_dependencies() {
  reset_fixture
  run_packs empty-dependencies --agent pi
  assert_status packs_accepts_schema_one_with_empty_dependencies 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/owner/empty'$'\t''--skill'$'\t''empty-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_accepts_schema_one_with_empty_dependencies "$expected"
}

packs_exact_tuple_dedupe() {
  reset_fixture
  run_packs typescript typescript --agent pi
  assert_status packs_exact_tuple_dedupe 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/0xBigBoss/claude-code'$'\t''--skill'$'\t''typescript-best-practices'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/bobmatnyc/claude-mpm-skills'$'\t''--skill'$'\t''biome'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/antfu/skills'$'\t''--skill'$'\t''pnpm'$'\t''--skill'$'\t''vitest'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/vercel/turborepo'$'\t''--skill'$'\t''turborepo'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_exact_tuple_dedupe "$expected"
}

packs_defaults_to_universal_agent() {
  reset_fixture
  run_packs typescript
  assert_status packs_defaults_to_universal_agent 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/0xBigBoss/claude-code'$'\t''--skill'$'\t''typescript-best-practices'$'\t''--agent'$'\t''universal'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/bobmatnyc/claude-mpm-skills'$'\t''--skill'$'\t''biome'$'\t''--agent'$'\t''universal'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/antfu/skills'$'\t''--skill'$'\t''pnpm'$'\t''--skill'$'\t''vitest'$'\t''--agent'$'\t''universal'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/vercel/turborepo'$'\t''--skill'$'\t''turborepo'$'\t''--agent'$'\t''universal'$'\t''--copy'$'\t''-y'
  assert_calls packs_defaults_to_universal_agent "$expected"
}

packs_repository_typescript_catalog() {
  reset_fixture
  runPacksDir="$repoRoot/packs"
  run_packs typescript --agent pi
  assert_status packs_repository_typescript_catalog 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/0xBigBoss/claude-code'$'\t''--skill'$'\t''typescript-best-practices'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/bobmatnyc/claude-mpm-skills'$'\t''--skill'$'\t''biome'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/antfu/skills'$'\t''--skill'$'\t''pnpm'$'\t''--skill'$'\t''vitest'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/vercel/turborepo'$'\t''--skill'$'\t''turborepo'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_repository_typescript_catalog "$expected"
}

packs_repository_vercel_catalog_includes_typescript_dependency() {
  reset_fixture
  runPacksDir="$repoRoot/packs"
  run_packs vercel --agent pi
  assert_status packs_repository_vercel_catalog_includes_typescript_dependency 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/0xBigBoss/claude-code'$'\t''--skill'$'\t''typescript-best-practices'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/bobmatnyc/claude-mpm-skills'$'\t''--skill'$'\t''biome'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/antfu/skills'$'\t''--skill'$'\t''pnpm'$'\t''--skill'$'\t''vitest'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/vercel/turborepo'$'\t''--skill'$'\t''turborepo'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''https://github.com/vercel-labs/agent-skills'$'\t''--skill'$'\t''deploy-to-vercel'$'\t''--skill'$'\t''vercel-react-best-practices'$'\t''--skill'$'\t''vercel-composition-patterns'$'\t''--skill'$'\t''vercel-optimize'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_repository_vercel_catalog_includes_typescript_dependency "$expected"
}

packs_invalid_catalogs_fail_before_cli() {
  local pack
  for pack in unknown malformed-json malformed-schema collision; do
    reset_fixture
    run_packs "$pack" --agent pi
    [[ "$runStatus" -ne 0 ]] || fail "$pack: expected failure"
    assert_no_calls "$pack"
  done
}

packs_reachable_closure_fails_before_cli() {
  local pack
  for pack in missing-root cycle-a malformed-root deep-root; do
    reset_fixture
    run_packs "$pack" --agent pi
    [[ "$runStatus" -ne 0 ]] || fail "$pack: expected closure failure"
    assert_no_calls "$pack"
  done
}

packs_invalid_dependency_and_source_shapes_fail_before_cli() {
  local pack
  for pack in \
    invalid-dependency-type \
    invalid-dependency-entry \
    invalid-dependency-name \
    invalid-manifest-keys \
    invalid-source-type \
    invalid-source-shorthand \
    invalid-source-http \
    invalid-source-empty-https \
    invalid-source-no-host \
    invalid-source-whitespace \
    invalid-source-control \
    invalid-source-ftp \
    invalid-source-local \
    invalid-source-ssh; do
    reset_fixture
    run_packs "$pack" --agent pi
    [[ "$runStatus" -ne 0 ]] || fail "$pack: expected manifest failure"
    assert_no_calls "$pack"
  done
}

packs_invalid_arguments_and_help() {
  reset_fixture
  run_packs --agent pi
  [[ "$runStatus" -ne 0 ]] || fail "missing pack: expected failure"
  assert_no_calls "missing pack"

  reset_fixture
  run_packs typescript --agent ''
  [[ "$runStatus" -ne 0 ]] || fail "empty --agent: expected failure"
  assert_no_calls "empty --agent"

  reset_fixture
  run_packs typescript --agent pi --agent universal
  [[ "$runStatus" -ne 0 ]] || fail "duplicate --agent: expected failure"
  assert_no_calls "duplicate --agent"

  reset_fixture
  run_packs typescript --agent pi --unknown
  [[ "$runStatus" -ne 0 ]] || fail "unknown option: expected failure"
  assert_no_calls "unknown option"

  reset_fixture
  run_packs --help
  assert_status help 0
  assert_no_calls help
}

packs_preserves_cli_lock_bytes() {
  reset_fixture
  lockBytesFile="$tempDir/fake-lock-bytes"
  printf 'fake-written lock bytes\nsecond line without newline' >"$lockBytesFile"
  run_packs typescript --agent pi
  assert_status packs_preserves_cli_lock_bytes 0
  cmp -s -- "$lockBytesFile" "$callerDir/skills-lock.json" \
    || fail "packs_preserves_cli_lock_bytes: caller lock bytes changed"
  lockBytesFile=""
}

packs_cli_failure_stops_later_sources() {
  reset_fixture
  failSource='https://github.com/owner/failing'
  failStatus=37
  run_packs failfirst --agent pi
  assert_status packs_cli_failure_stops_later_sources 37

  local expected
  expected="${callerDir}"$'\t''add'$'\t''https://github.com/owner/failing'$'\t''--skill'$'\t''first-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_cli_failure_stops_later_sources "$expected"
  failSource=""
  failStatus=""
}

run_test() {
  local name="$1"
  printf 'TEST: %s\n' "$name"
  "$name"
}

scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repoRoot="$(cd -- "$scriptDir/.." && pwd -P)"
runner="$repoRoot/packs.sh"
tempDir="$(mktemp -d)"
[[ -n "$tempDir" && -d "$tempDir" && "$tempDir" == /*/tmp.* ]] \
  || fail "unsafe temp directory: $tempDir"
trap cleanup EXIT
trap handle_signal HUP INT TERM

packsDir="$tempDir/packs"
callerDir="$tempDir/caller"
callsFile="$tempDir/calls"
fakeSkills="$tempDir/skills"
lockBytesFile=""
failSource=""
failStatus=""
runOutput=""
runStatus=0
runPacksDir=""

cat >"$fakeSkills" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

: "${FAKE_SKILLS_CALLS:?}"
{
  printf '%s' "$PWD"
  printf '\t%s' "$@"
  printf '\n'
} >>"$FAKE_SKILLS_CALLS"

if [[ -n "${FAKE_SKILLS_LOCK_BYTES_FILE:-}" ]]; then
  cat -- "$FAKE_SKILLS_LOCK_BYTES_FILE" >skills-lock.json
fi

if [[ "${1:-}" == add && "${2:-}" == "${FAKE_SKILLS_FAIL_SOURCE:-}" ]]; then
  exit "${FAKE_SKILLS_FAIL_STATUS:-37}"
fi
FAKE
chmod +x "$fakeSkills"

run_test packs_multi_source_install
run_test packs_resolves_dependencies_in_dfs_order
run_test packs_forwards_https_source_exactly
run_test packs_accepts_schema_one_with_empty_dependencies
run_test packs_exact_tuple_dedupe
run_test packs_defaults_to_universal_agent
run_test packs_invalid_catalogs_fail_before_cli
run_test packs_reachable_closure_fails_before_cli
run_test packs_invalid_dependency_and_source_shapes_fail_before_cli
run_test packs_invalid_arguments_and_help
run_test packs_preserves_cli_lock_bytes
run_test packs_cli_failure_stops_later_sources
run_test packs_repository_typescript_catalog
run_test packs_repository_vercel_catalog_includes_typescript_dependency
printf 'PASS: packs public seam\n'
