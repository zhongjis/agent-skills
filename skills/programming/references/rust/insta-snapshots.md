# Snapshot Testing with insta

Part of [proptest-insta.md](proptest-insta.md).

## Insta — setup

`Cargo.toml`:

```toml
[dev-dependencies]
insta = { version = "1", features = ["yaml", "json", "redactions", "filters"] }

[dependencies.serde_yaml]
version = "0.9"
optional = true
```

Install the CLI:

```bash
cargo install cargo-insta
```

## Insta — basic snapshots

```rust
#[test]
fn renders_default_help() {
    let output = render_help();
    insta::assert_snapshot!(output);
}
```

First run: creates `src/snapshots/mycrate__renders_default_help.snap.new`. Run `cargo insta review`, press `a` to accept, the `.new` extension is dropped. Subsequent runs diff against the committed snapshot; mismatches fail the test.

## Insta — typed snapshots

```rust
#[derive(Debug, serde::Serialize)]
struct Result {
    status: String,
    user: User,
    duration_ms: u64,
}

#[test]
fn json_response() {
    let value = compute();
    insta::assert_json_snapshot!(value);
}

#[test]
fn yaml_response() {
    insta::assert_yaml_snapshot!(value);
}

#[test]
fn debug_repr() {
    insta::assert_debug_snapshot!(value);
}
```

Choose:
- `assert_snapshot!` for `String`/`Display` output (CLI help, error messages, generated code).
- `assert_debug_snapshot!` for `{:?}` (Rust-internal data).
- `assert_json_snapshot!` for structured data crossing process boundaries.
- `assert_yaml_snapshot!` when YAML is easier to read in diffs.

## Insta — redactions and filters

For values that change every run (timestamps, UUIDs, paths):

```rust
#[test]
fn with_redactions() {
    let value = ApiResponse {
        id: uuid::Uuid::now_v7(),
        created_at: jiff::Timestamp::now(),
        body: "hello".into(),
    };
    insta::assert_json_snapshot!(value, {
        ".id" => "[uuid]",
        ".created_at" => "[timestamp]",
    });
}
```

For regex filters applied to all snapshots in a test:

```rust
#[test]
fn with_filters() {
    let mut settings = insta::Settings::clone_current();
    settings.add_filter(r"/tmp/[a-z0-9-]+", "[TMP]");
    settings.add_filter(r"\d+\.\d+ms", "[TIMING]");
    settings.bind(|| {
        let output = run_command();
        insta::assert_snapshot!(output);
    });
}
```

`Settings::bind` scopes filters to the closure.

## Insta workflow

1. Write the test, run it. First run creates `.snap.new`.
2. `cargo insta review` → interactive UI. Show diff, accept/reject.
3. Accepted snapshots commit to the repo.
4. Refactor code. Tests run; mismatches show as diffs.
5. If the new output is correct, `cargo insta accept` (or selective `review`). If wrong, fix the code.

Pair with CI to fail builds when uncommitted `.snap.new` files exist:

```bash
cargo nextest run
if find . -name "*.snap.new" | grep -q .; then
    echo "Pending snapshots, run 'cargo insta review'"
    exit 1
fi
```

## Inline snapshots

```rust
#[test]
fn small_output() {
    let value = compute();
    insta::assert_snapshot!(value, @"hello world");
}
```

The trailing `@"..."` string is the expected snapshot, stored in source. Useful when the value is short enough that pulling out a separate file is overkill. `cargo insta accept` updates them in-place.

## Inline JSON snapshots

```rust
#[test]
fn json_inline() {
    insta::assert_json_snapshot!(value, @r###"
    {
      "status": "ok",
      "count": 3
    }
    "###);
}
```
