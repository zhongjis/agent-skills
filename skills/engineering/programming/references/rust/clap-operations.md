# CLI Operations

Part of [clap-stack.md](clap-stack.md).

## Shell completions

Already shown in the `Completions` subcommand above. Distribute completions by adding to the install script:

```bash
mytool completions bash > /etc/bash_completion.d/mytool
mytool completions fish > ~/.config/fish/completions/mytool.fish
mytool completions zsh  > "${fpath[1]}/_mytool"
```

## Signal handling

```rust
// In an async CLI command
use tokio::signal::ctrl_c;

tokio::select! {
    _ = ctrl_c() => {
        tracing::warn!("interrupted, cleaning up");
        cleanup().await?;
        std::process::exit(130);  // standard exit code for SIGINT
    }
    result = long_running_task() => {
        result
    }
}
```

For sync CLIs, install a one-shot handler with `ctrlc` crate:

```rust
let interrupted = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
let i = interrupted.clone();
ctrlc::set_handler(move || i.store(true, std::sync::atomic::Ordering::SeqCst))?;

while !interrupted.load(std::sync::atomic::Ordering::Relaxed) {
    do_step()?;
}
```

## Error reporting with color-eyre

```rust
fn main() -> color_eyre::Result<()> {
    color_eyre::config::HookBuilder::default()
        .display_env_section(false)        // hide SPANTRACE/BACKTRACE env hints by default
        .display_location_section(false)   // hide file:line section
        .panic_section("If this is a bug, please report at https://github.com/me/mytool/issues")
        .install()?;
    real_main()
}
```

Errors with `.wrap_err("...")` from `eyre::WrapErr` (compatible with anyhow's `.context`) show as a numbered chain. `RUST_BACKTRACE=1` shows the full trace; `RUST_SPANTRACE=1` shows tracing spans where the error fired.

## Distribution

- Add `cargo dist init` for prebuilt binary release pipeline (cross-platform tarballs + installers).
- Publish to Homebrew tap, AUR, scoop, Chocolatey via dist.
- Sign Linux binaries with `cosign` if your audience is enterprise.
- Build single static binary on Linux with `--target x86_64-unknown-linux-musl` (or `aarch64-unknown-linux-musl`).
- For wasm-runnable CLIs (`wasi-cli`), add `--target wasm32-wasip1`.

## Common mistakes

1. **Mixing stdout and stderr.** Tool output goes to stdout; logs and progress go to stderr.
2. **No `--non-interactive` flag.** Interactive prompts block automation.
3. **Printing colored output unconditionally.** Honor `NO_COLOR` env var, detect TTY with `console::user_attended()`.
4. **`println!` for errors.** Use `tracing::error!` so logs go to stderr automatically and respect verbosity.
5. **`unwrap()` on `Cli::parse()`.** clap returns clean errors with `--help` text; `parse()` exits on its own.
6. **Long subcommand handlers in `main.rs`.** Split into `src/commands/<name>.rs` per command.
7. **Missing exit code semantics.** Use `std::process::exit(1)` (general error), `2` (usage), `130` (SIGINT) appropriately. Or return `Result` and let main map.

## Testing CLIs

```rust
// tests/cli.rs
use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn shows_help() {
    Command::cargo_bin("mytool").unwrap()
        .arg("--help")
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn rejects_unknown_subcommand() {
    Command::cargo_bin("mytool").unwrap()
        .arg("nope")
        .assert()
        .failure()
        .stderr(predicate::str::contains("unrecognized subcommand"));
}
```

`assert_cmd` builds the binary once per test run and gives a fluent assertion API.
