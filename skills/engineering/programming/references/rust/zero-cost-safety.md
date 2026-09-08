# Zero-Cost Safety — Reference Index

Rust owns memory safety. These references add explicit allocation control, demand-driven compile-time computation, zero-hidden-cost APIs, bit-level layout, and deterministic cleanup without leaving the Rust toolchain.

## Topics

- [Explicit allocators](explicit-allocators.md) — arenas, allocator-generic containers, stack-first collections.
- [Compile-time computation](compile-time-computation.md) — `const fn`, const generics, proc macros.
- [Zero-allocation APIs](zero-allocation-apis.md) — borrowed inputs, caller-owned buffers, `Cow`, fallible allocation.
- [Bit-level layout](bit-level-layout.md) — `#[repr]`, packed fields, bitfields, `zerocopy`.
- [Deterministic cleanup](deterministic-cleanup.md) — scope guards, `Drop`, defuse-on-success rollback.

## Summary: Zig Advantage → Rust Pattern

| Zig Feature | Rust Equivalent | Difficulty | Reference |
|---|---|---|---|
| Explicit allocator passing | `bumpalo` / `typed-arena` / `allocator_api` | Easy | [explicit allocators](explicit-allocators.md) |
| `comptime` value computation | `const fn` + `const { }` blocks | Easy | [compile time](compile-time-computation.md) |
| `comptime` type generation | proc macros (derive / attribute) | Medium | [compile time](compile-time-computation.md) |
| No hidden allocations | `#![no_std]` / slice-based APIs / `Cow` | Style choice | [zero-allocation APIs](zero-allocation-apis.md) |
| `packed struct` / bitfields | `#[repr(C, packed)]` / `bitfield` / `zerocopy` | Easy | [bit-level layout](bit-level-layout.md) |
| `errdefer` | `scopeguard::guard` + defuse on success | Easy | [deterministic cleanup](deterministic-cleanup.md) |
| `defer` | `scopeguard::defer!` / `Drop` | Easy | [deterministic cleanup](deterministic-cleanup.md) |

All achievable within Rust's single toolchain. You get Zig's explicitness **plus** the borrow checker, lifetime analysis, trait bounds, and `miri`. The combination is strictly more powerful than either alone.

## When NOT to Use These Patterns

- **Arena allocation** overkill for simple CLI tools that allocate once and exit.
- **Zero-alloc APIs** hurt readability when the function naturally produces owned data. Don't force `&mut [u8]` output buffers on a function that logically returns `String`.
- **`#[repr(packed)]`** only for wire formats and FFI. Never for regular domain types.
- **Scope guards** unnecessary when `Drop` on the value itself handles cleanup (e.g., `tempfile::NamedTempFile` already does this).
- **`const fn`** is demand-driven: use it when compile-time callers, const initialization, or a const-generic API needs it. Keep runtime-only functions ordinary; never contort logic solely to add const qualification.

The goal is **visible costs and explicit control**, not asceticism. Use `String` and `Vec` freely when they're the right tool. Reach for these patterns when allocation behavior matters for correctness or performance.
