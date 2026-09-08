# Cobra CLI UX and Testing

Interactive UX, output contracts, error semantics, and command tests.

## Interactive prompts — `huh` from charm

For prompts/forms (`Are you sure?`, "Pick an environment", multi-field forms):

```go
import "github.com/charmbracelet/huh"

var confirm bool
err := huh.NewConfirm().
    Title("Apply migrations to PRODUCTION?").
    Affirmative("Yes, do it").
    Negative("Abort").
    Value(&confirm).
    Run()
```

`huh` replaces `survey` (which is no longer maintained). It composes with `lipgloss` for styling.

---

## Progress / spinners

```go
import "github.com/charmbracelet/huh/spinner"

err := spinner.New().Title("Fetching...").Action(func() {
    // long-running work
}).Run()
```

For determinate progress (downloads, batch processing), use `vbauerster/mpb/v8`:

```go
import "github.com/vbauerster/mpb/v8"

p := mpb.New(mpb.WithWidth(60))
bar := p.AddBar(int64(total), /* decorators */)
for i := 0; i < total; i++ {
    work()
    bar.Increment()
}
p.Wait()
```

---

## Output — JSON vs text

Honor `--output json` for any CLI that scripts will parse:

```go
var outputFmt string

rootCmd.PersistentFlags().StringVar(&outputFmt, "output", "text",
    "output format: text or json")

func render(v any) error {
    switch outputFmt {
    case "json":
        enc := json.NewEncoder(os.Stdout)
        enc.SetIndent("", "  ")
        return enc.Encode(v)
    case "text":
        return renderText(v)
    default:
        return fmt.Errorf("invalid --output %q", outputFmt)
    }
}
```

The `text` format uses `lipgloss` tables or `aquasecurity/table` for nicely-aligned columns. The `json` format is for `jq`-style piping.

---

## Error semantics

- Return errors from `RunE`. Cobra catches them and the `Execute` wrapper logs + exits non-zero.
- `os.Exit(1)` should appear **only in `main.go`**. Anywhere else means a subcommand cannot be tested.
- For graceful early termination ("user cancelled"), return a sentinel and check it in `Execute`:
  ```go
  var ErrCancelled = errors.New("cancelled by user")
  // ... return ErrCancelled
  // in main:
  if errors.Is(err, cmd.ErrCancelled) { os.Exit(130) }  // 128 + SIGINT
  ```

---

## Testing CLI commands

```go
func TestServerCmd_runs_with_default_addr(t *testing.T) {
    // Given
    buf := &bytes.Buffer{}
    rootCmd.SetOut(buf)
    rootCmd.SetErr(buf)
    rootCmd.SetArgs([]string{"server", "--addr", ":0"})

    // When
    ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
    defer cancel()
    err := rootCmd.ExecuteContext(ctx)

    // Then
    require.NoError(t, err)
    require.Contains(t, buf.String(), "starting")
}
```

`SetArgs` + `ExecuteContext` is the canonical pattern. Bind a ctx with a short deadline for tests that would otherwise block.

---

## Sources

- cobra docs: https://github.com/spf13/cobra/blob/main/site/content/user_guide.md
- pflag: https://github.com/spf13/pflag
- huh: https://github.com/charmbracelet/huh
- caarlos0/env: https://github.com/caarlos0/env
- signal.NotifyContext: https://pkg.go.dev/os/signal#NotifyContext
