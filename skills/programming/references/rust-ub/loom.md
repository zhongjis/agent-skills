# Loom — Exhaustive Concurrency Testing

Part of [miri-sanitizers-loom.md](miri-sanitizers-loom.md).

## Loom — Exhaustive Concurrency Testing

Loom explores all possible thread interleavings of a bounded concurrent program. It is mandatory for lock-free and wait-free primitives.

### When to Use Loom

- Any `unsafe` code involving atomics with ordering weaker than `SeqCst`.
- Custom lock implementations.
- Lock-free queues, stacks, or other concurrent data structures.
- Any code where you chose `Relaxed`, `Acquire`, or `Release` ordering.

### When NOT to Use Loom

- Code using only `Mutex`/`RwLock` from std or `parking_lot` — the locks are sound, your usage is the question, and Miri + TSAN cover that.
- Async code (loom does not model async runtimes — use `tokio::test` + Miri instead).

### Setup

```toml
[dev-dependencies]
loom = "0.7"
```

### Loom Test Pattern

```rust
#[cfg(loom)]
mod loom_tests {
    use loom::sync::atomic::{AtomicUsize, Ordering};
    use loom::sync::Arc;
    use loom::thread;

    #[test]
    fn concurrent_increment_is_sound() {
        loom::model(|| {
            let counter = Arc::new(AtomicUsize::new(0));

            let threads: Vec<_> = (0..2).map(|_| {
                let c = counter.clone();
                thread::spawn(move || {
                    c.fetch_add(1, Ordering::SeqCst);
                })
            }).collect();

            for t in threads {
                t.join().unwrap();
            }

            assert_eq!(counter.load(Ordering::SeqCst), 2);
        });
    }
}
```

### Conditional Compilation for Loom

```rust
#[cfg(loom)]
use loom::sync::atomic::{AtomicUsize, Ordering};
#[cfg(not(loom))]
use std::sync::atomic::{AtomicUsize, Ordering};
```

### Running Loom Tests

```bash
# Loom tests only (use cfg flag)
RUSTFLAGS="--cfg loom" cargo test --lib -- loom_tests

# With release optimizations (loom is slow)
RUSTFLAGS="--cfg loom" cargo test --lib --release -- loom_tests
```

### Loom + Miri Interaction

Loom and Miri solve different problems:
- **Miri** checks a single execution for UB (aliasing, validity, provenance).
- **Loom** checks all interleavings for correctness (ordering, atomicity).

Run BOTH on lock-free code:
```bash
# Step 1: loom for interleaving correctness
RUSTFLAGS="--cfg loom" cargo test --lib --release -- loom_tests

# Step 2: Miri for UB in each path
cargo +nightly miri test -- concurrent_tests
```

---
