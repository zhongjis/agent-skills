# Rust Sanitizers

Part of [miri-sanitizers-loom.md](miri-sanitizers-loom.md).

## Sanitizers — Where Miri Cannot Reach

Sanitizers are compiler instrumentation passes. They run your actual binary on real hardware with extra checks injected. Use them for FFI, I/O-heavy code, and integration tests.

### AddressSanitizer (ASAN)

Detects: use-after-free, buffer overflow, stack-use-after-return, double-free, memory leaks.

```bash
RUSTFLAGS="-Zsanitizer=address" cargo +nightly test -Zbuild-std --target x86_64-unknown-linux-gnu
```

On macOS:
```bash
RUSTFLAGS="-Zsanitizer=address" cargo +nightly test -Zbuild-std --target aarch64-apple-darwin
```

### ThreadSanitizer (TSAN)

Detects: data races on non-atomic accesses across threads.

```bash
RUSTFLAGS="-Zsanitizer=thread" cargo +nightly test -Zbuild-std --target x86_64-unknown-linux-gnu
```

**When to use over Miri:** Integration tests involving real threads + real I/O + FFI. Miri's data-race detector is superior for pure-Rust code.

### MemorySanitizer (MSAN)

Detects: reads of uninitialized memory.

```bash
RUSTFLAGS="-Zsanitizer=memory -Zsanitizer-memory-track-origins" cargo +nightly test -Zbuild-std --target x86_64-unknown-linux-gnu
```

**When to use over Miri:** FFI code where C/C++ may return uninitialized memory into Rust.

### UndefinedBehaviorSanitizer (UBSAN)

Detects: integer overflow, misaligned access, null dereference, and other C/C++-style UB at the LLVM level.

```bash
RUSTFLAGS="-Zsanitizer=undefined" cargo +nightly test -Zbuild-std --target x86_64-unknown-linux-gnu
```

### Sanitizer Limitations

- Require nightly + `-Zbuild-std` (rebuilds the standard library with instrumentation).
- MSAN requires ALL dependencies (including C libs) to be instrumented — practically hard.
- Cannot catch aliasing violations (that is Miri's domain).
- Significant runtime overhead (2-15x slower).
- Linux has the best support; macOS works for ASAN; Windows support is minimal.

---
