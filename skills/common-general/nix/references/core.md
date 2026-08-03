# Nix — core commands and language

Running tools without installing, evaluating expressions, hashes, language patterns, and troubleshooting.

## Quick Start

```bash
# Run a package once
nix run nixpkgs#hello

# Create a shell with multiple packages
nix shell nixpkgs#git nixpkgs#vim --command git --version
```

## Running Applications

Run any application from `nixpkgs` without installing it permanently.

```bash
# Run a package with specific arguments
nix run nixpkgs#cowsay -- "Hello from Nix!"

# Run long-running applications: `tmux new -d 'nix run nixpkgs#some-server'`
```

## Formatting

Format Nix files in your project:

```bash
# Format current flake
nix fmt

# Check formatting
nix fmt -- --check
```

## Hash Conversion

Convert hashes between formats (replaces deprecated `nix hash to-sri`/`to-base16`).

```bash
# Convert a nix32 hash to SRI (sha256)
nix hash convert --hash-algo sha256 --from nix32 --to sri 1b8m03r63zqhnjf7l5wnldhh7c134ap5vpj0850ymkq1iyzicy5s

# Convert to nix32 explicitly
nix hash convert --hash-algo sha256 --to nix32 sha256-ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=
```

## Prefetching Hashes

Prefer `nix store prefetch-file` (prints an SRI hash directly). The legacy `nix-prefetch-url` still works but prints a nix32 hash you must convert:

```bash
# Fetch a tarball and print its nix32 hash
nix-prefetch-url --unpack https://example.com/source.tar.gz

# Convert the nix32 hash to SRI for fetchFromGitHub/fetchurl
nix hash convert --hash-algo sha256 --from nix32 --to sri <nix32-hash>
```

## Evaluating Expressions

Since the environment is headless and non-interactive, use `nix eval` instead of the REPL for debugging.

```bash
# Evaluate a simple expression
nix eval --expr '1 + 2'

# Inspect an attribute from nixpkgs
nix eval nixpkgs#hello.name

# Evaluate a local nix file
nix eval --file ./default.nix

# List keys in a set (useful for exploration)
nix eval --expr 'builtins.attrNames (import <nixpkgs> {})'
```

## Searching for Packages

```bash
# Search for a package by name or description
nix search nixpkgs python3
```

## Nix Language Patterns

### Variables and Functions

```nix
# Let binding
let
  name = "Nix";
in
  "Hello ${name}"

# Function definition
let
  multiply = x: y: x * y;
in
  multiply 2 3
```

### Attribute Sets

```nix
{
  a = 1;
  b = "foo";
}
```

## Shebang Scripts

Use Nix as a script interpreter:

```bash
#!/usr/bin/env nix
#! nix shell nixpkgs#bash nixpkgs#curl --command bash

curl -s https://example.com
```

Or with flakes:

```bash
#!/usr/bin/env nix
#! nix shell nixpkgs#python3 --command python3

print("Hello from Nix!")
```

## Troubleshooting

- **Broken Builds**: Use `nix log` to see the build output of a derivation.
- **Dependency Issues**: Use `nix-store -q --references $(which program)` to see what a program depends on.
- **Cache Issues**: Add `--no-substitute` to force a local build if you suspect a bad binary cache.
- **Why Depends**: Use `nix why-depends nixpkgs#hello nixpkgs#glibc` to see dependency chain.
