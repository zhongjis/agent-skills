# Zero-Allocation API Design

Part of [zero-cost-safety.md](zero-cost-safety.md).

## 3. Zero-Allocation API Design — No Hidden Costs

Zig's philosophy: no operator overloading, no hidden allocation, every cost visible. Rust achieves this with discipline.

### Slice-Based APIs — Caller Owns Memory

```rust
// BAD: hidden allocation in return type
fn process(input: &str) -> String {
    input.to_uppercase() // allocates
}

// GOOD: caller provides output buffer, zero allocation
fn process(input: &[u8], output: &mut [u8]) -> usize {
    let len = input.len().min(output.len());
    for i in 0..len {
        output[i] = input[i].to_ascii_uppercase();
    }
    len // returns bytes written
}

// GOOD: return borrowed data when possible
fn find_token<'a>(input: &'a str) -> Option<&'a str> {
    input.split_whitespace().next() // no allocation — borrows from input
}
```

### try_* APIs — Fallible Allocation

```rust
// Allocation can fail explicitly (like Zig's allocator returning error)
let mut v = Vec::new();
v.try_reserve(1_000_000)?; // returns Result, not panic

// For Box:
let b = Box::try_new(42)?; // nightly, or use allocator_api
```

### SmallVec / ArrayVec — Stack-First Collections

```rust
use smallvec::SmallVec;
use arrayvec::ArrayVec;

// SmallVec: stack for small counts, heap spillover for large
let mut tags: SmallVec<[u8; 8]> = SmallVec::new();
tags.push(1); // on stack if <= 8 elements

// ArrayVec: purely stack, fixed capacity, no heap ever
let mut buf: ArrayVec<u8, 64> = ArrayVec::new();
buf.try_push(42).map_err(|_| "full")?; // returns error instead of panic
```

### Cow — Defer Allocation Until Mutation

```rust
use std::borrow::Cow;

fn normalize(input: &str) -> Cow<'_, str> {
    if input.contains('\t') {
        Cow::Owned(input.replace('\t', "    ")) // allocates only when needed
    } else {
        Cow::Borrowed(input) // zero-cost pass-through
    }
}
```

### The #![no_std] Discipline

For maximum allocation control, go `#![no_std]`:

```rust
#![no_std]
extern crate alloc; // opt-in to heap when needed

use alloc::vec::Vec;      // explicit: I chose to allocate
use alloc::string::String; // explicit: I chose to allocate
```

Even in `std` code, the *mindset* applies: prefer `&[T]` over `Vec<T>` in function signatures, `&str` over `String`, `&Path` over `PathBuf`.

### Clippy Lints for Hidden Allocations

```toml
# Cargo.toml — catch accidental allocations
[lints.clippy]
# These warn on patterns that allocate when a borrow would suffice:
unnecessary_to_owned = "warn"       # .to_string() / .to_vec() when borrow works
redundant_clone = "warn"            # .clone() that's immediately consumed
large_stack_arrays = "warn"         # accidental large stack usage
vec_init_then_push = "warn"         # Vec::new() + push instead of vec![]
```

---
