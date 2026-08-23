# Deterministic Cleanup in Rust

Part of [zero-cost-safety.md](zero-cost-safety.md).

## 5. Scope Guards — errdefer / Deterministic Cleanup

Zig's `errdefer` runs cleanup only on error paths. Rust's `Drop` always runs, but `scopeguard` gives fine-grained control.

### scopeguard — The errdefer Equivalent

```rust
use scopeguard::{defer, guard};
use std::fs;

fn create_and_process(path: &str) -> std::io::Result<()> {
    let file = fs::File::create(path)?;
    // If anything below fails, clean up the file.
    // This is exactly Zig's errdefer.
    let _cleanup = guard((), |_| {
        let _ = fs::remove_file(path);
    });

    write_data(&file)?;
    validate_data(path)?;

    // Success: defuse the guard so it does NOT run cleanup.
    std::mem::forget(_cleanup);
    Ok(())
}
```

### defer! — Always-Run Cleanup (like Zig's defer)

```rust
use scopeguard::defer;

fn with_temp_dir() -> anyhow::Result<()> {
    let dir = tempfile::tempdir()?;
    defer! {
        // Runs when scope exits, success or failure.
        println!("Cleaning up {}", dir.path().display());
        // dir's Drop also cleans up, but this shows the pattern.
    }

    do_work(dir.path())?;
    Ok(())
}
```

### Drop as RAII Cleanup

```rust
struct TempFile { path: std::path::PathBuf }

impl TempFile {
    fn new(path: impl Into<std::path::PathBuf>) -> std::io::Result<Self> {
        let path = path.into();
        std::fs::File::create(&path)?;
        Ok(Self { path })
    }
}

impl Drop for TempFile {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}

// Usage: file is auto-cleaned when `tmp` goes out of scope.
let tmp = TempFile::new("/tmp/scratch.dat")?;
```

### The errdefer Pattern — Defuse on Success

The key insight from Zig's `errdefer`: you want cleanup on error but NOT on success. In Rust:

```rust
use scopeguard::ScopeGuard;

fn deploy(artifact: &Path) -> Result<(), DeployError> {
    let backup = backup_current()?;

    // errdefer: restore backup if anything fails
    let rollback = guard(backup.clone(), |b| {
        let _ = restore_from_backup(&b);
    });

    upload(artifact)?;
    health_check()?;

    // Success path: defuse the rollback guard
    ScopeGuard::into_inner(rollback);
    Ok(())
}
```

### Cargo.toml

```toml
scopeguard = "1"
tempfile = "3"  # idiomatic RAII temp files/dirs
```

---
