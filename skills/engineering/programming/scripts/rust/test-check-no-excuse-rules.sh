#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
checker="$script_dir/check-no-excuse-rules.sh"
failures=0

implementations=()
for candidate in "$script_dir"/check-no-excuse-rules.sh "$script_dir"/check-no-excuse-rules.py; do
    [ -e "$candidate" ] && implementations+=("$candidate")
done
if [ "${#implementations[@]}" -ne 1 ] || [ "${implementations[0]}" != "$checker" ]; then
    echo "expected check-no-excuse-rules.sh to be the single checker implementation" >&2
    failures=$((failures + 1))
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
cat > "$tmp_dir/lib.rs" <<'RS'
pub fn unchecked(value: Option<u8>) -> u8 {
    value.unwrap()
}
RS

set +e
output=$(bash "$checker" "$tmp_dir/lib.rs" 2>&1)
status=$?
set -e
if [ "$status" -eq 0 ]; then
    echo "expected fixture to trigger checker" >&2
    failures=$((failures + 1))
fi
if ! grep -Fq 'cargo +nightly miri test --all-features' <<<"$output"; then
    echo "expected supported Miri command in failure guidance" >&2
    failures=$((failures + 1))
fi
if grep -Fq 'miri '"nextest" <<<"$output"; then
    echo "obsolete Miri subcommand remains in failure guidance" >&2
    failures=$((failures + 1))
fi

mkdir -p "$tmp_dir/project/src/nested"
printf '%s' 'pub fn fail() { panic!("boom"); }' > "$tmp_dir/project/src/nested/deep.rs"
set +e
directory_output=$(
    cd "$tmp_dir/project"
    bash "$checker" src 2>&1
)
directory_status=$?
set -e
if [ "$directory_status" -eq 0 ]; then
    echo "expected recursive directory fixture to trigger checker" >&2
    failures=$((failures + 1))
fi
if ! grep -Fq 'file=src/nested/deep.rs,line=1::[lib-panic]' <<<"$directory_output"; then
    echo "expected relative nested library panic on final unterminated line" >&2
    failures=$((failures + 1))
fi

mkdir -p "$tmp_dir/count/nested"
printf '%s\n' 'pub fn one() {}' > "$tmp_dir/count/one.rs"
printf '%s\n' 'pub fn two() {}' > "$tmp_dir/count/nested/two.rs"
printf '%s\n' 'ignored' > "$tmp_dir/count/not-rust.txt"
count_output=$(bash "$checker" "$tmp_dir/count/one.rs" "$tmp_dir/count" "$tmp_dir/count/one.rs" 2>&1)
if ! grep -Fq 'no-excuse rules passed for 4 file(s).' <<<"$count_output"; then
    echo "expected actual checked file count with file and duplicate arguments preserved" >&2
    failures=$((failures + 1))
fi

mkdir -p "$tmp_dir/no-rust/empty"
printf '%s\n' 'ignored' > "$tmp_dir/no-rust/readme.txt"
set +e
bash "$checker" \
    "$tmp_dir/no-rust/missing.rs" \
    "$tmp_dir/no-rust/readme.txt" \
    "$tmp_dir/no-rust/empty" \
    > "$tmp_dir/no-rust/stdout" \
    2> "$tmp_dir/no-rust/stderr"
no_files_status=$?
set -e
no_files_stderr=$(<"$tmp_dir/no-rust/stderr")
if [ "$no_files_status" -ne 0 ] || \
   [ -s "$tmp_dir/no-rust/stdout" ] || \
   [ "$no_files_stderr" != 'warning: no .rs files found in the given arguments' ]; then
    echo "expected no-Rust-input warning on stderr with success status" >&2
    failures=$((failures + 1))
fi

mkdir -p "$tmp_dir/rules/src"
cat > "$tmp_dir/rules/src/all.rs" <<'RS'
pub fn violations(value: Option<u64>) -> Result<(), Box<dyn Error>> {
    let _ = value.unwrap();
    let _ = value.expect("required");
    todo!();
    panic!("boom");
    unsafe {}
    #[allow(clippy::pedantic)]
    let _small = 1u64 as u8;
    Ok(())
}
RS
set +e
rules_output=$(bash "$checker" "$tmp_dir/rules/src/all.rs" 2>&1)
rules_status=$?
set -e
if [ "$rules_status" -eq 0 ]; then
    echo "expected all-rule fixture to trigger checker" >&2
    failures=$((failures + 1))
fi
rule_ids=(
    unwrap
    expect
    placeholder-macro
    box-dyn-error
    lib-panic
    unsafe-no-safety-comment
    unjustified-clippy-allow
    narrowing-as-cast
)
for rule_id in "${rule_ids[@]}"; do
    if ! grep -Fq "[$rule_id]" <<<"$rules_output"; then
        echo "expected rule ID: $rule_id" >&2
        failures=$((failures + 1))
    fi
done

mkdir -p \
    "$tmp_dir/exceptions/src/bin" \
    "$tmp_dir/exceptions/src/tests" \
    "$tmp_dir/exceptions/tests" \
    "$tmp_dir/exceptions/benches" \
    "$tmp_dir/exceptions/examples"
cat > "$tmp_dir/exceptions/src/lib.rs" <<'RS'
pub fn annotated(value: Option<u8>) {
    // SAFE-UNWRAP: input contract
    let _ = value.unwrap();
    // SAFE-EXPECT: input contract
    let _ = value.expect("required");
    // SAFETY: fixture does not execute
    unsafe {}
    // CLIPPY-ALLOW: fixture verifies justification
    #[allow(clippy::pedantic)]
}

#[cfg(test)]
mod tests {
    fn exempt(value: Option<u8>) -> Result<(), Box<dyn Error>> {
        let _ = value.unwrap();
        let _ = value.expect("required");
        todo!();
        panic!("test panic");
    }
}
RS
printf '%s\n' 'fn main() { panic!("binary panic"); }' > "$tmp_dir/exceptions/src/main.rs"
printf '%s\n' 'fn main() { panic!("binary panic"); }' > "$tmp_dir/exceptions/src/bin/tool.rs"
test_path_source='fn exempt(value: Option<u8>) { value.unwrap(); value.expect("required"); todo!(); }'
printf '%s\n' "$test_path_source" > "$tmp_dir/exceptions/src/tests/helper.rs"
printf '%s\n' "$test_path_source" > "$tmp_dir/exceptions/tests/case.rs"
printf '%s\n' "$test_path_source" > "$tmp_dir/exceptions/benches/bench.rs"
printf '%s\n' "$test_path_source" > "$tmp_dir/exceptions/examples/example.rs"
printf '%s\n' "$test_path_source" > "$tmp_dir/exceptions/build.rs"
printf '%s\n' "$test_path_source" > "$tmp_dir/exceptions/feature_test.rs"
exception_files=(
    src/lib.rs
    src/main.rs
    src/bin/tool.rs
    src/tests/helper.rs
    tests/case.rs
    benches/bench.rs
    examples/example.rs
    build.rs
    feature_test.rs
)
set +e
exceptions_output=$(
    cd "$tmp_dir/exceptions"
    bash "$checker" "${exception_files[@]}" 2>&1
)
exceptions_status=$?
set -e
if [ "$exceptions_status" -ne 0 ]; then
    echo "expected existing checker exceptions to pass" >&2
    printf '%s\n' "$exceptions_output" >&2
    failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
    exit 1
fi

echo "rust checker regression: passed"
