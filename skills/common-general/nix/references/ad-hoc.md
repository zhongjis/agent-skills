# Nix — ad-hoc execution

Choose the narrowest temporary execution path without polluting the host.

## Selection Order

1. **Project environment first**
   - If the repo has `flake.nix`, prefer `nix develop` for project work.
   - If the project already uses a local package manager workflow, use that instead of creating a parallel one.

2. **Choose the narrowest tool**
   - Need the repo's development environment -> `nix develop`
   - Need one package's default executable with direct arguments -> `nix run`
   - Need ad-hoc tools, arbitrary commands, shell pipelines, non-default executables, or multiple packages -> `nix shell`
   - Need temporary Python libraries -> `uv run --with ...`; otherwise use `nix shell` with a Python environment
   - Need a Node.js tool in project context -> `npx ...`; if Node.js is missing, use `nix shell nixpkgs#nodejs --command npx ...`

## Quick Examples

```bash
nix develop
nix run nixpkgs#hello
nix shell nixpkgs#jq nixpkgs#yq --command sh -c 'jq ... | yq ...'
uv run --with requests python3 script.py
npx tsx script.ts
```

## Guardrails

- Do not mutate the host environment unless the user explicitly asks for a persistent setup change.
- Prefer project-scoped or ephemeral execution over system-wide changes.
- Avoid `pip install`, `pip install --user`, `npm install -g`, `sudo npm install -g`, and similar global mutable installs as the default answer.
