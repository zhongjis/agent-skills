# Explicit Allocators — Arena Pattern

Part of [zero-cost-safety.md](zero-cost-safety.md).

## 1. Explicit Allocators — Arena Pattern

Zig passes `allocator: Allocator` to every function. Rust's stable equivalent: arena crates that make allocation scope visible and bulk-freeable.

### bumpalo — The Default Arena

```rust
use bumpalo::Bump;

fn parse_tokens<'a>(arena: &'a Bump, input: &[u8]) -> Vec<&'a str> {
    // All allocations go into `arena`. Caller controls lifetime.
    // When `arena` drops, everything frees in one shot.
    let token = arena.alloc_str("hello");
    let slice = arena.alloc_slice_copy(&[1u8, 2, 3]);
    vec![token] // Vec itself is on heap; contents point into arena
}

// Usage: caller owns the arena, decides when memory dies.
let arena = Bump::new();
let tokens = parse_tokens(&arena, b"...");
drop(arena); // all arena memory freed, zero individual deallocations
```

**When to use:** parsers, compilers, game frame allocators, request-scoped web handlers, any hot loop where individual `Box`/`Vec` alloc+free overhead matters.

### typed-arena — Homogeneous Arena

```rust
use typed_arena::Arena;

struct AstNode { kind: u8, children: Vec<&'static AstNode> } // simplified

let node_arena: Arena<AstNode> = Arena::new();
let root = node_arena.alloc(AstNode { kind: 0, children: vec![] });
// All nodes share arena lifetime. No individual free.
```

**When to use:** tree/graph structures where all nodes have the same type and same lifetime.

### allocator_api (nightly) — Full Zig Parity

```rust
#![feature(allocator_api)]
use std::alloc::Global;

// Vec parameterized by allocator — exactly like Zig.
let v: Vec<u8, &Bump> = Vec::new_in(&arena);

// Custom allocator for tracking, limiting, or redirecting allocation
struct CountingAlloc { inner: Global, count: AtomicUsize }
unsafe impl Allocator for CountingAlloc { /* ... */ }
```

**When to use:** when you need allocator-generic data structures on nightly. For stable code, prefer `bumpalo` directly.

### Decision Tree

```
Need arena allocation?
├── All items same type, same lifetime → typed-arena
├── Mixed types, same lifetime → bumpalo
├── Need allocator-generic containers → allocator_api (nightly)
└── Just need fewer allocations → SmallVec / ArrayVec / tinyvec (stack-first)
```

### Cargo.toml

```toml
bumpalo = { version = "3", features = ["collections"] }
typed-arena = "2"
smallvec = { version = "1", features = ["union", "const_generics"] }
tinyvec = { version = "1", features = ["alloc"] }
```

---
