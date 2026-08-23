# Cargo-Fuzz and UB Tool Selection

Part of [miri-sanitizers-loom.md](miri-sanitizers-loom.md).

## Cargo-Fuzz — Property-Based UB Hunting

Fuzzing generates random inputs to maximize code coverage and find crashes, panics, and UB.

### Setup

```bash
cargo install cargo-fuzz
cargo fuzz init
```

### Fuzz Target

```rust
// fuzz/fuzz_targets/parse_input.rs
#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    // Your parsing/deserialization/processing code here.
    // If it panics or triggers UB, the fuzzer catches it.
    let _ = my_crate::parse(data);
});
```

### Running

```bash
# Run until interrupted
cargo +nightly fuzz run parse_input

# Run with ASAN (catches memory bugs in unsafe code)
cargo +nightly fuzz run parse_input -- -rss_limit_mb=4096

# Minimize a crashing input
cargo +nightly fuzz tmin parse_input artifacts/parse_input/crash-xxxxx
```

### Fuzz + Miri Pipeline

When the fuzzer finds a crashing input:
1. Minimize it with `cargo fuzz tmin`.
2. Add it as a regression test.
3. Run the regression test under Miri to classify whether it is a panic (safe) or UB (must fix).

```bash
# After adding the input as a test case:
cargo +nightly miri test -- test_fuzz_regression_001
```

---

## Tool Selection Decision Tree

```
Start
  │
  ├── Is it pure Rust (no FFI, no I/O)?
  │     YES → Miri (full paranoia flags)
  │     │     └── Also: loom (if atomics/lock-free)
  │     │     └── Also: proptest (if parsing/serialization)
  │     │     └── Also: cargo-fuzz (if untrusted input)
  │     │
  │     NO → Does it involve FFI?
  │           YES → ASAN + MSAN on integration tests
  │           │     └── Miri on the Rust-side handling
  │           │     └── cbindgen in CI for layout verification
  │           │
  │           NO → Is it I/O-heavy?
  │                 YES → TSAN for thread safety
  │                 │     └── Miri with -Zmiri-disable-isolation where possible
  │                 │
  │                 NO → Miri (full paranoia flags)
  │
  └── Always: Miri is the default. Other tools supplement.
```

## The One Rule

> **When in doubt, run Miri.** If Miri cannot run it, write a version it can run, and test that under Miri. Then test the real version under sanitizers. Never ship `unsafe` code that has not passed Miri.
