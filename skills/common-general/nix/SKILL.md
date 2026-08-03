---
name: nix
description: "Unified Nix toolkit — running packages without installing, evaluating expressions and debugging derivations, flakes (build/devShell/lock/check), nh system switching and store cleanup, authoring patterns (overlays, unfree, binary overlays, devShells), and choosing the narrowest ad-hoc execution path. Use whenever working with Nix: running a tool one-off, evaluating a Nix expression, converting or prefetching hashes (SRI), nix or flake commands, editing flake.nix or shell.nix, nh os/home/darwin switch, garbage collection, overlays, unfree packages, or running a missing command without polluting the host."
adaptedFrom:
  - "https://github.com/knoopx/pi/tree/main/agent/skills/tools/nix"
  - "https://github.com/knoopx/pi/tree/main/agent/skills/tools/nix-flake"
  - "https://github.com/knoopx/pi/tree/main/agent/skills/tools/nh"
  - "https://github.com/0xbigboss/claude-code/tree/main/.claude/skills/nix-best-practices"
---

# Nix

Package manager and functional language for reproducible environments. This skill bundles the
whole Nix workflow so it occupies a single slot. Start here, then open the one reference that
matches your task — the references hold the depth so this file stays small and loads cheaply.

## Pick the right reference

| Task | Reference |
|------|-----------|
| Run a tool one-off, eval expressions, convert/prefetch hashes, language patterns, troubleshooting | `references/core.md` |
| Choose how to run an ad-hoc or missing command (develop vs run vs shell vs uv vs npx) | `references/ad-hoc.md` |
| Flake commands and `flake.nix` structure — build/run/lock/check, devShells | `references/flakes.md` |
| Authoring patterns: overlays, unfree packages, binary-overlay repos, devShell recipes, direnv | `references/best-practices.md` |
| Switch or build NixOS / Home Manager / nix-darwin configs; clean the store | `references/nh.md` |

## Quick commands

```bash
# Run a package once, or open a shell with several
nix run nixpkgs#hello
nix shell nixpkgs#git nixpkgs#jq --command sh -c 'git --version'

# Evaluate an expression (headless — prefer eval over the REPL)
nix eval --expr '1 + 2'
nix eval nixpkgs#hello.name

# Flakes — always prefix local paths with path:
nix build path:.
nix develop path:. --command make build
nix flake update && nix flake check

# Switch this repo's configs / clean the store (nh)
nh darwin switch .
nh os switch .
nh clean all --keep-since 7d

# Search
nix search nixpkgs ripgrep
```

## Related MCP tools

- **nixos.nix** — query nixpkgs packages, NixOS / Home Manager / Darwin options, and flakes
- **nixos.nix_versions** — package version history (NixHub)
