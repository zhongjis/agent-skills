# Rust UB Detection — Reference Index

Miri is primary. Sanitizers, Loom, and fuzzing cover execution surfaces Miri cannot reach.

## Topics

- [Miri](miri.md) — installation, supported test commands, strictness flags, CI, test gating.
- [Sanitizers](sanitizers.md) — ASAN, TSAN, MSAN, UBSAN for FFI and real-hardware integration paths.
- [Loom](loom.md) — bounded exhaustive interleaving checks for atomic and lock-free code.
- [Fuzzing and tool selection](fuzzing.md) — cargo-fuzz workflow and fallback decision tree.
