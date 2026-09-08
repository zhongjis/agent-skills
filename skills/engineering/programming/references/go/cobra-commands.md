# Cobra Commands

Arguments, typed flags, environment precedence, versions, and completions.

## Subcommands with arguments

```go
func NewMigrateUpCmd(migrate Migrator) *cobra.Command {
    return &cobra.Command{
        Use:   "up [N]",
        Short: "Apply N migrations (default: all)",
        Args:  cobra.MaximumNArgs(1),
        RunE: func(c *cobra.Command, args []string) error {
            n := -1
            if len(args) == 1 {
                parsed, err := strconv.Atoi(args[0])
                if err != nil {
                    return fmt.Errorf("invalid N: %w", err)
                }
                n = parsed
            }
            return migrate.Up(c.Context(), n)
        },
    }
}
```

Use cobra's argument validators (`cobra.ExactArgs`, `cobra.MaximumNArgs`, `cobra.OnlyValidArgs`). They produce clean help text.

---

## Flag types — typed, not strings

```go
// GOOD
serverCmd.Flags().DurationVar(&timeout, "timeout", 30*time.Second, "request timeout")
serverCmd.Flags().IntVar(&port, "port", 8080, "port")
serverCmd.Flags().StringSliceVar(&hosts, "host", nil, "allowed hosts (repeatable)")

// BAD — manual parsing
serverCmd.Flags().StringVar(&timeoutStr, "timeout", "30s", "")
// ...then later: time.ParseDuration(timeoutStr)
```

`pflag` (cobra's flag lib) has typed variants for every common type. Use them; the parsing and error messages are free.

---

## Bind flags to env vars

cobra + viper is overkill for env binding. Use `caarlos0/env/v11`:

```go
type ServerOpts struct {
    Addr    string        `env:"ADDR"    envDefault:":8080"`
    Timeout time.Duration `env:"TIMEOUT" envDefault:"30s"`
}

func NewServerCmd(runner ServerRunner) *cobra.Command {
    var opts ServerOpts
    command := &cobra.Command{
        Use: "server",
        PersistentPreRunE: func(c *cobra.Command, args []string) error {
            if err := env.Parse(&opts); err != nil {
                return fmt.Errorf("parse server environment: %w", err)
            }
            if c.Flags().Changed("addr") {
                addr, err := c.Flags().GetString("addr")
                if err != nil {
                    return fmt.Errorf("read addr flag: %w", err)
                }
                opts.Addr = addr
            }
            return nil
        },
        RunE: func(c *cobra.Command, args []string) error {
            return runner.Run(c.Context(), opts)
        },
    }
    command.Flags().String("addr", "", "listen address (env: ADDR)")
    command.Flags().Duration("timeout", 0, "request timeout (env: TIMEOUT)")
    return command
}
```

Precedence: **flag (if set) > env > default**. Document the env var in the flag usage string.

---

## Version subcommand — build-injected

```go
// cmd/version.go
package cmd

import (
    "fmt"
    "runtime/debug"

    "github.com/spf13/cobra"
)

// Set by -ldflags at build time, falls back to debug.BuildInfo.
var (
    version = ""
    commit  = ""
    date    = ""
)

func NewVersionCmd() *cobra.Command {
    return &cobra.Command{
        Use:   "version",
        Short: "Print version",
        RunE: func(c *cobra.Command, args []string) error {
            v, revision, builtAt := resolveVersion()
            _, err := fmt.Fprintf(c.OutOrStdout(), "mytool %s (commit %s, built %s)\n",
                v, revision, builtAt)
            return err
        },
    }
}

func resolveVersion() (string, string, string) {
    if version != "" { return version, commit, date }
    info, ok := debug.ReadBuildInfo()
    if !ok { return "dev", "unknown", "unknown" }

    var vcs, hash, time string
    for _, s := range info.Settings {
        switch s.Key {
        case "vcs.revision": hash = s.Value
        case "vcs.time":     time = s.Value
        case "vcs":          vcs  = s.Value
        }
    }
    return info.Main.Version, hash, time + " (" + vcs + ")"
}
```

Build with version injection:

```bash
go build \
  -ldflags="-X 'github.com/your-org/mytool/cmd.version=v1.2.3' -X 'github.com/your-org/mytool/cmd.commit=$(git rev-parse --short HEAD)' -X 'github.com/your-org/mytool/cmd.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)'" \
  -o bin/mytool ./
```

The `debug.BuildInfo` fallback means a `go install`'d binary also has version info — no manual `-ldflags` needed.

---

## Shell completions

```go
func NewCompletionCmd(root *cobra.Command) *cobra.Command {
    return &cobra.Command{
        Use:                   "completion [bash|zsh|fish|powershell]",
        Short:                 "Generate shell completion",
        Args:                  cobra.ExactValidArgs(1),
        ValidArgs:             []string{"bash", "zsh", "fish", "powershell"},
        DisableFlagsInUseLine: true,
        RunE: func(c *cobra.Command, args []string) error {
            switch args[0] {
            case "bash":
                return root.GenBashCompletionV2(c.OutOrStdout(), true)
            case "zsh":
                return root.GenZshCompletion(c.OutOrStdout())
            case "fish":
                return root.GenFishCompletion(c.OutOrStdout(), true)
            case "powershell":
                return root.GenPowerShellCompletion(c.OutOrStdout())
            default:
                return fmt.Errorf("unsupported shell %q", args[0])
            }
        },
    }
}
```

User:

```bash
mytool completion zsh > "${fpath[1]}/_mytool"
```

---
