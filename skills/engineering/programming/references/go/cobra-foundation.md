# Cobra CLI Foundation

Tooling, layout, explicit root assembly, logging, and server command construction.

## Toolchain

Pin `cobra-cli` in repository tooling before scaffolding. Generated command files are starting points, not a registration model.

`cobra-cli` scaffolds the `cmd/` package. Edit the result; do not regenerate.

---

## Layout

```
mytool/
├── go.mod
├── main.go                  # ≤ 40 LOC, assembles logger + root command
├── cmd/
│   ├── root.go              # NewRootCmd constructor, persistent flags
│   ├── server.go            # NewServerCmd constructor
│   ├── migrate.go           # NewMigrateCmd constructor
│   └── version.go           # NewVersionCmd constructor
├── internal/
│   ├── config/
│   └── server/
└── Taskfile.yml
```

---

## `main.go`

```go
package main

import (
    "context"
    "log/slog"
    "os"
    "os/signal"
    "syscall"

    "github.com/your-org/mytool/cmd"
)

func main() {
    ctx, stop := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    level := &slog.LevelVar{}
    logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: level}))
    root := cmd.NewRootCmd(logger, level)
    if err := root.ExecuteContext(ctx); err != nil {
        logger.ErrorContext(ctx, "fatal", slog.String("error", err.Error()))
        os.Exit(1)
    }
}
```

`signal.NotifyContext` (Go 1.16+) gives every subcommand a ctx that cancels on Ctrl-C. Subcommands plumb the ctx into their workers.

---

## `cmd/root.go`

```go
package cmd

import (
    "log/slog"

    "github.com/spf13/cobra"
)

func NewRootCmd(logger *slog.Logger, level *slog.LevelVar) *cobra.Command {
    var verbose bool
    var configPath string

    root := &cobra.Command{
        Use:           "mytool",
        Short:         "Short description of mytool",
        SilenceUsage:  true,
        SilenceErrors: true,
        PersistentPreRunE: func(c *cobra.Command, args []string) error {
            if verbose {
                level.Set(slog.LevelDebug)
            }
            return nil
        },
    }
    root.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false,
        "enable debug logging")
    root.PersistentFlags().StringVarP(&configPath, "config", "c", "",
        "path to config file (optional)")
    root.AddCommand(
        NewServerCmd(logger),
        NewVersionCmd(),
        NewCompletionCmd(root),
    )
    return root
}
```

Notes:

- `RunE` / `PersistentPreRunE` (the `E` variants) return errors. Use these; never use `Run` (no error return, encourages `log.Fatal`).
- `SilenceUsage: true` + `SilenceErrors: true` together: cobra stops printing the full `--help` on every command failure (the default behavior is rude in production scripts).
- `ExecuteContext` (cobra 1.8+) plumbs the ctx into every subcommand's `cmd.Context()`.

---

## `cmd/server.go`

```go
package cmd

import (
    "log/slog"

    "github.com/spf13/cobra"
    "github.com/your-org/mytool/internal/server"
)

func NewServerCmd(logger *slog.Logger) *cobra.Command {
    var addr string
    command := &cobra.Command{
        Use:   "server",
        Short: "Run the HTTP server",
        RunE: func(c *cobra.Command, args []string) error {
            logger.InfoContext(c.Context(), "starting", slog.String("addr", addr))
            return server.Run(c.Context(), addr)
        },
    }
    command.Flags().StringVar(&addr, "addr", ":8080", "listen address")
    return command
}
```

The subcommand is a thin shim — flags + log line + delegate to `internal/server`. Anything bigger violates the 250-LOC ceiling and belongs in `internal/`.

---
