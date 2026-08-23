# Miri — UB Detection

Part of [miri-sanitizers-loom.md](miri-sanitizers-loom.md).

## Miri — The First and Last Line of Defense

### What Miri Is

Miri is an interpreter for Rust's MIR (Mid-level IR). It executes your test suite inside a virtual machine that tracks every byte of memory for validity, provenance, alignment, initialization, and aliasing. It is **deterministic** — same inputs, same result — and it can find UB that no amount of testing on real hardware will ever trigger.

### Why Miri Is Non-Negotiable

- Detects 12 of 14 UB categories (see `ub-taxonomy.md`).
- Catches aliasing violations that compile and run correctly on every platform today but are UB that future compiler optimizations will exploit.
- Catches data races under a configurable scheduling model.
- Catches provenance violations that are impossible to observe on real hardware.
- **Zero false positives** — if Miri says it is UB, it is UB. Period.

### Installation

```bash
rustup install nightly
rustup component add miri rust-src --toolchain nightly
```

Verify:
```bash
cargo +nightly miri --version
```

### Running Miri

**Default run (Stacked Borrows, standard checks):**
```bash
cargo +nightly miri test
```

**Specific test:**
```bash
cargo +nightly miri test -- test_name
```

**Run a binary:**
```bash
cargo +nightly miri run
```

### MIRIFLAGS — The Dial-Up Knobs

These flags are set via the `MIRIFLAGS` environment variable. The agent should use ALL of the strictness flags during a UB audit.

#### Aliasing Model

```bash
# Default: Stacked Borrows (strict)
cargo +nightly miri test

# Tree Borrows (alternate model — use as a second pass)
MIRIFLAGS="-Zmiri-tree-borrows" cargo +nightly miri test
```

**Protocol:** Run Stacked Borrows first. If it fails, fix it. Then run Tree Borrows to confirm. Code that passes Stacked Borrows is sound under both models.

#### Strict Provenance

```bash
MIRIFLAGS="-Zmiri-strict-provenance" cargo +nightly miri test
```

Catches `ptr as usize as *const T` roundtrips where provenance is lost. **Should be ON for every audit.**

#### Symbolic Alignment Checks

```bash
MIRIFLAGS="-Zmiri-symbolic-alignment-check" cargo +nightly miri test
```

Catches alignment UB that happens to be aligned on your machine but is not guaranteed by the type system.

#### Data Race Detection Tuning

```bash
# Increase preemption rate to stress-test race conditions
MIRIFLAGS="-Zmiri-preemption-rate=0.5" cargo +nightly miri test

# Disable preemption (sequential scheduling — fewer races found but deterministic)
MIRIFLAGS="-Zmiri-preemption-rate=0" cargo +nightly miri test
```

#### The Full Paranoia Sweep (Use This for Audits)

```bash
MIRIFLAGS="\
  -Zmiri-strict-provenance \
  -Zmiri-symbolic-alignment-check \
  -Zmiri-preemption-rate=0.1 \
  -Zmiri-backtrace=full \
  -Zmiri-disable-isolation" \
cargo +nightly miri test
```

Then a second pass with Tree Borrows:
```bash
MIRIFLAGS="\
  -Zmiri-tree-borrows \
  -Zmiri-strict-provenance \
  -Zmiri-symbolic-alignment-check \
  -Zmiri-preemption-rate=0.1 \
  -Zmiri-backtrace=full \
  -Zmiri-disable-isolation" \
cargo +nightly miri test
```

#### Isolation and I/O

Miri runs in isolation by default — no file I/O, no network, no system calls. If your tests need the filesystem:
```bash
MIRIFLAGS="-Zmiri-disable-isolation" cargo +nightly miri test
```

Use sparingly — isolation is a feature, not a limitation. Tests that need I/O should have a separate `#[cfg(not(miri))]` path.

### Miri Limitations

| Cannot do | Workaround |
|-----------|-----------|
| Execute FFI / C code | ASAN, MSAN, Valgrind |
| Run I/O-heavy tests (default) | `-Zmiri-disable-isolation` or `#[cfg(not(miri))]` |
| Exhaustive interleaving exploration | loom |
| Find performance bugs | criterion, flamegraph |
| Run inline assembly | skip with `#[cfg(not(miri))]` |
| Test OS-specific behavior | real hardware + sanitizers |

### Miri in CI

```yaml
# GitHub Actions example
miri:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: dtolnay/rust-toolchain@nightly
      with:
        components: miri, rust-src
    - name: Miri test (Stacked Borrows + strict provenance)
      run: |
        MIRIFLAGS="-Zmiri-strict-provenance -Zmiri-symbolic-alignment-check -Zmiri-backtrace=full" \
        cargo +nightly miri test
    - name: Miri test (Tree Borrows)
      run: |
        MIRIFLAGS="-Zmiri-tree-borrows -Zmiri-strict-provenance -Zmiri-symbolic-alignment-check -Zmiri-backtrace=full" \
        cargo +nightly miri test
```

### Miri-Incompatible Test Gating

```rust
#[test]
#[cfg_attr(miri, ignore)]  // Miri cannot run this (FFI, I/O, inline asm)
fn test_requires_real_hardware() {
    // ...
}

// Or conditionally compile the test body:
#[test]
fn test_with_miri_fallback() {
    #[cfg(miri)]
    {
        // Simplified version that avoids FFI
    }
    #[cfg(not(miri))]
    {
        // Full version with FFI
    }
}
```

---
