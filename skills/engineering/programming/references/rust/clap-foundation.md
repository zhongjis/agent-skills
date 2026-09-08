# CLI Foundation with clap

Part of [clap-stack.md](clap-stack.md).

## Cargo.toml

```toml
[package]
name = "mytool"
version = "0.1.0"
edition = "2024"

[dependencies]
clap = { version = "4", features = ["derive", "env", "wrap_help", "color", "unicode"] }
clap_complete = "4"
color-eyre = "0.6"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "fmt"] }
anyhow = "1"
indicatif = { version = "0.17", features = ["tokio"] }
dialoguer = { version = "0.11", features = ["fuzzy-select"] }
console = "0.15"
tokio = { version = "1", features = ["macros", "rt-multi-thread", "fs", "process", "signal"] }

[profile.release]
opt-level = 3
lto = "fat"
codegen-units = 1
strip = "symbols"
panic = "abort"
```

## Command structure

```rust
// src/cli.rs
use clap::{Parser, Subcommand, ValueEnum};
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(
    name = "mytool",
    author,
    version,
    about = "A short description",
    long_about = "A longer description that appears in --help",
    arg_required_else_help = true,
)]
pub struct Cli {
    /// Configuration file path
    #[arg(short, long, env = "MYTOOL_CONFIG", default_value = "config.toml", global = true)]
    pub config: PathBuf,

    /// Increase verbosity (-v info, -vv debug, -vvv trace)
    #[arg(short, long, action = clap::ArgAction::Count, global = true)]
    pub verbose: u8,

    /// Suppress all non-error output
    #[arg(short, long, global = true, conflicts_with = "verbose")]
    pub quiet: bool,

    /// Force colored output even when stdout is not a terminal
    #[arg(long, global = true, value_enum, default_value_t = ColorChoice::Auto)]
    pub color: ColorChoice,

    /// Output format
    #[arg(short, long, global = true, value_enum, default_value_t = OutputFormat::Pretty)]
    pub format: OutputFormat,

    #[command(subcommand)]
    pub command: Command,
}

#[derive(Debug, Clone, ValueEnum)]
pub enum ColorChoice { Auto, Always, Never }

#[derive(Debug, Clone, ValueEnum)]
pub enum OutputFormat { Pretty, Json, Plain }

#[derive(Debug, Subcommand)]
pub enum Command {
    /// Build the thing
    Build(BuildArgs),
    /// Watch and rebuild
    Watch(WatchArgs),
    /// Generate shell completions
    Completions { #[arg(value_enum)] shell: clap_complete::Shell },
}

#[derive(Debug, clap::Args)]
pub struct BuildArgs {
    /// Target directory
    #[arg(short, long, default_value = "target")]
    pub target: PathBuf,
    /// Build mode
    #[arg(short, long, value_enum, default_value_t = Mode::Release)]
    pub mode: Mode,
    /// Specific files to build (default: all)
    pub files: Vec<PathBuf>,
}

#[derive(Debug, clap::Args)]
pub struct WatchArgs {
    /// Glob pattern to watch
    #[arg(short, long, default_value = "**/*.rs")]
    pub pattern: String,
}

#[derive(Debug, Clone, ValueEnum)]
pub enum Mode { Debug, Release }
```

Key clap derive patterns:

- `env = "VAR"` — falls back to env var if flag not given.
- `global = true` — flag inherits to subcommands.
- `arg_required_else_help = true` — running with no args prints help instead of erroring.
- `value_enum` on an enum — case-insensitive parsing + auto-completion.
- `action = clap::ArgAction::Count` — `-v` is 1, `-vv` is 2, etc.
- `conflicts_with` — incompatible flags.

## Main + tracing init

```rust
// src/main.rs
use clap::Parser;
use mytool::cli::{Cli, Command, ColorChoice};
use tracing::Level;
use tracing_subscriber::EnvFilter;

fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;
    let cli = Cli::parse();
    init_tracing(&cli);

    if matches!(cli.color, ColorChoice::Always) {
        console::set_colors_enabled(true);
    } else if matches!(cli.color, ColorChoice::Never) {
        console::set_colors_enabled(false);
    }

    match cli.command {
        Command::Build(args) => mytool::commands::build::run(&cli, args),
        Command::Watch(args) => mytool::commands::watch::run(&cli, args),
        Command::Completions { shell } => {
            let mut cmd = <Cli as clap::CommandFactory>::command();
            clap_complete::generate(shell, &mut cmd, "mytool", &mut std::io::stdout());
            Ok(())
        }
    }
}

fn init_tracing(cli: &Cli) {
    let level = if cli.quiet {
        Level::ERROR
    } else {
        match cli.verbose {
            0 => Level::WARN,
            1 => Level::INFO,
            2 => Level::DEBUG,
            _ => Level::TRACE,
        }
    };
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(format!("mytool={level}")));
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .without_time()
        .compact()
        .with_writer(std::io::stderr)
        .init();
}
```

Tracing on a CLI:
- **Write to stderr.** stdout is for the tool's actual output (which the user might pipe). Logs and progress bars go to stderr.
- **Verbosity from `-v`, not from `RUST_LOG`.** Users expect `-v` on a CLI; `RUST_LOG` is a developer escape hatch (kept, but secondary).
