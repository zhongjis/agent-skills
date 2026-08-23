# Specialized Rust Library Defaults

Part of [libraries.md](libraries.md).

## Time — `jiff`

Use it when its civil time, instant, and span distinctions fit the domain.

```rust
use jiff::{Timestamp, Span, ToSpan, Zoned};

let now: Timestamp = Timestamp::now();
let in_one_hour = now.checked_add(1.hour())?;
let local: Zoned = now.in_tz("Asia/Seoul")?;
let span: Span = local - some_earlier.in_tz("Asia/Seoul")?;
```

Avoid `chrono` (old API, generic-heavy, time zone story still painful), `time` crate (split ecosystem, weaker docs). `jiff` is the post-`chrono` consolidation.

## UUID — `uuid` with v7

```rust
use uuid::Uuid;

// v7 for IDs (sortable, time-ordered, monotonic-ish, RFC 9562)
let id = Uuid::now_v7();
```

v4 is fine for nonces, v7 for primary keys (better index locality). Never v1 (leaks MAC). Cargo features: `uuid = { version = "1", features = ["v4", "v7", "serde"] }`.

## DataFrames / analytics — `polars`

For columnar data, joins, group-by, lazy plans:

```rust
use polars::prelude::*;

let df = LazyCsvReader::new("events.csv")
    .finish()?
    .group_by([col("user_id")])
    .agg([col("amount").sum().alias("total")])
    .sort(["total"], Default::default())
    .collect()?;
```

The Rust API mirrors the Python one. Use the lazy API by default; materialize with `.collect()` at the end.

## Channels

- Single-producer single-consumer or bounded MPSC → `tokio::sync::mpsc` (async) or `flume` (sync + async).
- Broadcast → `tokio::sync::broadcast`.
- Watch (latest-value pubsub) → `tokio::sync::watch`.
- Oneshot → `tokio::sync::oneshot`.

Avoid raw `std::sync::mpsc` (sync only, fewer features), `crossbeam-channel` (good but heavier; use only if you need rendezvous semantics).

## Coordinate spaces / 2D math — `euclid`

```rust
use euclid::{Point2D, Size2D, default::Box2D};
struct ScreenSpace;
struct WorldSpace;

type ScreenPoint = Point2D<f32, ScreenSpace>;
type WorldPoint  = Point2D<f32, WorldSpace>;

let cursor: ScreenPoint = Point2D::new(120.0, 240.0);
let player: WorldPoint  = Point2D::new(3.5, 1.2);

// let mistake = cursor + player; // ❌ type error
```

Generalize the pattern to your own domains (see `references/type-state.md`).

## Property tests — `proptest`

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn parse_roundtrips(s in r"[a-zA-Z0-9_-]{1,50}") {
        let parsed = parse(&s).unwrap();
        let back = parsed.to_string();
        prop_assert_eq!(back, s);
    }
}
```

Avoid `quickcheck` (older, less ergonomic). proptest gives shrinking + regression corpus + integration with `criterion`.

## Snapshot tests — `insta`

```rust
#[test]
fn renders_help() {
    let output = render(&example_input());
    insta::assert_snapshot!(output);
}

#[test]
fn serializes_well() {
    insta::assert_json_snapshot!(serializable_value());
}
```

`cargo insta review` (after `cargo install cargo-insta`) — interactive review of changed snapshots.

## Benchmarks — `criterion`

Stable Rust friendly (no nightly `#[bench]`).

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_parse(c: &mut Criterion) {
    let input = std::fs::read_to_string("samples/large.txt").unwrap();
    c.bench_function("parse_large", |b| b.iter(|| parse(black_box(&input))));
}

criterion_group!(benches, bench_parse);
criterion_main!(benches);
```

Run with `cargo bench`. HTML reports under `target/criterion/`. Pair with `cargo bench -- --save-baseline main` then `--baseline main` for comparison.

## Concurrency model — `loom`

For lock-free or atomic-heavy code (channels, refcounts, hazard pointers). See `references/concurrency.md` for the full pattern.

## Arena allocator — `bumpalo`

```rust
use bumpalo::Bump;

let bump = Bump::new();
let node = bump.alloc(Node { value: 42, next: None });
let s: &str = bump.alloc_str("hello");
// All allocations freed at once when `bump` drops.
```

For parser nodes, AST construction, per-request scratch. Outperforms heap allocation for short-lived owned data by an order of magnitude.

## Web client (browser, WASM-bound) — `gloo` ecosystem

If targeting WASM browser, use `gloo-net` for fetch and `gloo-storage` for localStorage; not `web-sys` directly unless you need DOM-level APIs.

## Lazy statics — `std::sync::LazyLock`

```rust
use std::sync::LazyLock;
static CONFIG: LazyLock<Config> = LazyLock::new(|| Config::load_from_env().unwrap());
```

Avoid `lazy_static!` (macro-heavy, predates std), `once_cell` (now in std as `LazyLock`/`OnceLock`).

## Hash maps — `std::collections::HashMap` + `ahash` for hot paths

```rust
use std::collections::HashMap;
use ahash::RandomState;

type FastMap<K, V> = HashMap<K, V, RandomState>;
let mut counters: FastMap<String, u64> = FastMap::default();
```

`HashMap` defaults to SipHash (DoS-resistant). For internal hot loops where you trust the keys, `ahash` is 2-5x faster.

For sorted iteration, use `BTreeMap`. For small keys with known small N, `Vec<(K, V)>` may beat both.

## File I/O — `tokio::fs` (async) or `std::fs` (sync utility)

```rust
let contents = tokio::fs::read_to_string("data.json").await?;
```

For large files: `tokio::fs::File` + `tokio::io::BufReader`. For random access, `memmap2` (with the unsafe-discipline wrappers).
