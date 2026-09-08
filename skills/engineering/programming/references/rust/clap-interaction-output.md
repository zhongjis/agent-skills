# CLI Interaction and Output

Part of [clap-stack.md](clap-stack.md).

## Progress bars — `indicatif`

```rust
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::time::Duration;

let mp = MultiProgress::new();
let pb = mp.add(ProgressBar::new(files.len() as u64));
pb.set_style(
    ProgressStyle::with_template(
        "{spinner:.green} [{elapsed_precise}] [{wide_bar:.cyan/blue}] {pos}/{len} ({eta}) {msg}"
    )?
    .progress_chars("=>-")
);

for file in files {
    pb.set_message(file.display().to_string());
    process(&file)?;
    pb.inc(1);
}
pb.finish_with_message("done");
```

For unbounded operations:

```rust
let spinner = ProgressBar::new_spinner();
spinner.enable_steady_tick(Duration::from_millis(80));
spinner.set_message("connecting…");
let result = connect().await?;
spinner.finish_and_clear();
```

With multiple parallel tasks:

```rust
let mp = MultiProgress::new();
let bars: Vec<_> = (0..workers).map(|i| {
    let pb = mp.add(ProgressBar::new(unit));
    pb.set_style(ProgressStyle::with_template("worker {prefix}: {pos}/{len}")?);
    pb.set_prefix(i.to_string());
    pb
}).collect();
```

`MultiProgress` keeps bars stacked and redraws cleanly even with concurrent updates from multiple tasks.

When stdout is not a terminal, indicatif silently disables animation. Force on/off with `pb.set_draw_target(ProgressDrawTarget::stdout())` / `hidden()`.

## Interactive prompts — `dialoguer`

```rust
use dialoguer::{theme::ColorfulTheme, Confirm, Input, Password, Select, FuzzySelect, MultiSelect};

let name: String = Input::with_theme(&ColorfulTheme::default())
    .with_prompt("Project name")
    .validate_with(|input: &String| -> Result<(), &str> {
        if input.chars().all(|c| c.is_alphanumeric() || c == '-' || c == '_') {
            Ok(())
        } else {
            Err("alphanumeric, dash, underscore only")
        }
    })
    .interact_text()?;

let secret = Password::with_theme(&ColorfulTheme::default())
    .with_prompt("API key")
    .with_confirmation("Repeat", "passwords don't match")
    .interact()?;

let go: bool = Confirm::with_theme(&ColorfulTheme::default())
    .with_prompt(format!("Delete {}? This cannot be undone.", path.display()))
    .default(false)
    .interact()?;
if !go { return Ok(()); }

let items = ["yes", "no", "maybe"];
let idx = Select::with_theme(&ColorfulTheme::default())
    .with_prompt("Pick one")
    .items(&items)
    .default(0)
    .interact()?;

let picks = MultiSelect::with_theme(&ColorfulTheme::default())
    .with_prompt("Toggle features")
    .items(&["alpha", "beta", "gamma"])
    .defaults(&[true, false, false])
    .interact()?;
```

Detect non-TTY before prompting:

```rust
if !console::user_attended() {
    return Err(anyhow::anyhow!("input required but stdin is not a terminal"));
}
```

For automated tests, expose a `--non-interactive` flag and gate all prompts behind it.

## Structured output

```rust
match cli.format {
    OutputFormat::Json => {
        serde_json::to_writer(std::io::stdout().lock(), &result)?;
        println!();
    }
    OutputFormat::Plain => {
        for row in &result.rows {
            println!("{}\t{}\t{}", row.a, row.b, row.c);
        }
    }
    OutputFormat::Pretty => {
        use console::{style, Term};
        let term = Term::stdout();
        for row in &result.rows {
            term.write_line(&format!(
                "{} {} {}",
                style(&row.a).green(),
                style(&row.b).yellow(),
                style(&row.c).dim(),
            ))?;
        }
    }
}
```

Always offer `--format json` for piping into `jq`, scripts, and other tools.
