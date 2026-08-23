# Compile-Time Computation in Rust

Part of [zero-cost-safety.md](zero-cost-safety.md).

## 2. Compile-Time Computation — const fn, const generics, proc macros

Zig's `comptime` runs arbitrary code at compile time. Rust splits this across three mechanisms.

`const fn` is demand-driven. Add it when compile-time callers, const initialization, or a const-generic API requires const evaluation. For runtime-only code, prefer an ordinary function unless const qualification serves a concrete API requirement without distorting the implementation.

### const fn — Compile-Time Pure Functions

```rust
const fn fibonacci(n: usize) -> usize {
    match n {
        0 => 0,
        1 => 1,
        _ => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

const FIB_20: usize = fibonacci(20); // computed at compile time: 6765

// Use in array sizes
const LOOKUP: [u8; 256] = {
    let mut table = [0u8; 256];
    let mut i = 0;
    while i < 256 {
        table[i] = (i as u8).wrapping_mul(7);
        i += 1;
    }
    table
};
```

`const fn` supports control flow, references, and mutable locals needed by many compile-time computations. Use `const { }` blocks for inline compile-time assertions.

```rust
fn process<const N: usize>(data: &[u8; N]) {
    const { assert!(N > 0, "N must be positive") }; // compile-time panic if N == 0
    // ...
}
```

### const generics — Type-Level Values

```rust
struct Buffer<const N: usize> {
    data: [u8; N],
    len: usize,
}

impl<const N: usize> Buffer<N> {
    const fn new() -> Self {
        Self { data: [0; N], len: 0 }
    }

    fn push(&mut self, byte: u8) -> Result<(), BufferFullError> {
        if self.len >= N { return Err(BufferFullError); }
        self.data[self.len] = byte;
        self.len += 1;
        Ok(())
    }
}

// Compiler enforces: Buffer<16> and Buffer<32> are distinct types.
let small: Buffer<16> = Buffer::new();
let large: Buffer<1024> = Buffer::new();
```

### proc macros — Code Generation (Zig comptime type creation)

When `const fn` is not enough (generating struct fields, impl blocks, or derive logic), proc macros fill the gap.

```rust
// In a proc-macro crate:
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, DeriveInput};

#[proc_macro_derive(Builder)]
pub fn derive_builder(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let name = &input.ident;
    // ... generate builder struct and impl
    TokenStream::from(quote! {
        impl #name {
            pub fn builder() -> #name##Builder { /* ... */ }
        }
    })
}
```

**Decision tree:**

```
Need compile-time value computation? → const fn
Need type parameterized by value?    → const generics
Need to generate new types/impls?    → proc macro (derive or attribute)
Need compile-time string processing? → proc macro
Need typenum-level arithmetic?       → typenum / generic-array (rare)
```

---
