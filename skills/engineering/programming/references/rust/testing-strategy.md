# Property and Snapshot Test Strategy

Part of [proptest-insta.md](proptest-insta.md).

## Anti-patterns

1. **Snapshots of unstable output.** If `HashMap` iteration order changes per run, snapshots will fail. Switch to `BTreeMap` or sort before snapshotting.
2. **Massive snapshots.** A 10KB JSON dump where you really care about 3 fields. Either narrow to the fields, or accept that any refactor will require re-reviewing 10KB.
3. **Snapshots that bake in implementation details.** "function called 3 times" is not a snapshot - it's a behavior assertion. Use a real assertion.
4. **Skipping `cargo insta review`.** Accepting blind via `cargo insta accept --all` defeats the purpose. Always review.

## Combining proptest + insta

```rust
proptest! {
    #[test]
    fn random_inputs_render_consistently(input: ValidInput) {
        let mut settings = insta::Settings::clone_current();
        settings.set_snapshot_suffix(format!("{}", input.hash()));
        settings.bind(|| {
            insta::assert_snapshot!(render(&input));
        });
    }
}
```

But honestly, this is rarely a fit. Proptest tests properties, insta tests output shape. Don't snapshot random inputs - that defeats both tools.

## CI matrix recommendation

```yaml
- name: Tests
  run: cargo nextest run --all-features

- name: Property regressions (replay)
  run: |
    # The regression files in proptest-regressions/ replay first.
    # Failures here mean a previously-fixed bug came back.
    cargo nextest run --all-features --test-threads 1
```

When a proptest finds a new failure, the regression file appears as a git diff - check it in.

## What proptest cannot do

- Find bugs that require multi-process / multi-network coordination → integration tests + fault injection.
- Find concurrency bugs → use `loom` (see `concurrency.md`).
- Find performance regressions → use `criterion`.

But for any function with a domain (inputs to outputs), proptest can find more bugs than your unit tests. **Write the property first, derive the unit test second.**
