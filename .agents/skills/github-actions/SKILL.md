---
name: github-actions
description: GitHub Actions workflow authoring, review, debugging, security, and version management. Use when creating or editing .github/workflows/*.yml, reusable workflows, composite actions, action version updates, CI/CD hardening, workflow permissions, matrix jobs, caches, artifacts, OIDC, or when tasks mention "actions/", "uses:", "workflow", "GitHub Actions", or ".github/workflows".
upstream: "https://github.com/dalestudy/skills/tree/main/skills/github-actions"
---

# GitHub Actions

Use this skill for GitHub Actions workflow YAML design, review, and debugging.
For running workflows, inspecting runs, downloading artifacts, or using GitHub APIs, also use the `gh` skill.
For YAML edits, also use the `yq` skill when structured manipulation is safer than text edits.

## Core checklist

Before writing or changing a workflow:

1. Confirm trigger: `push`, `pull_request`, `workflow_dispatch`, `schedule`, `release`, or `workflow_call`.
2. Set least-privilege `permissions` at workflow or job level.
3. Pin action versions deliberately: current major tag for trusted first-party actions, commit SHA for sensitive third-party actions.
4. Avoid direct expression interpolation inside shell commands; pass untrusted data through `env`.
5. Use caches only when cache key correctness is clear.
6. Add `concurrency` when duplicate runs waste resources or race deployments.
7. Prefer reusable workflows for repeated CI/CD logic across repos.

## Anti-patterns

### 1. Stale action versions

```yaml
# Bad: stale or guessed version
- uses: actions/checkout@v3

# Better: verify latest supported major version first
- uses: actions/checkout@v{N}
```

Check latest release before updating:

```bash
gh release view --repo actions/checkout --json tagName --jq '.tagName'
gh release view --repo actions/upload-artifact --json tagName --jq '.tagName'
```

For security-sensitive workflows or low-trust third-party actions, prefer SHA pinning:

```yaml
- uses: owner/action@a1b2c3d4e5f6...
```

### 2. Hardcoded secrets

```yaml
# Bad
env:
  API_KEY: "sk-example"
  DATABASE_PASSWORD: "password123"

# Good
env:
  API_KEY: ${{ secrets.API_KEY }}
  DATABASE_PASSWORD: ${{ secrets.DATABASE_PASSWORD }}
```

Secrets belong in repository, environment, or organization secrets.

### 3. Script injection via GitHub context

Do not place untrusted event fields directly inside shell commands.

```yaml
# Bad
- run: echo "${{ github.event.issue.title }}"

# Good
- env:
    ISSUE_TITLE: ${{ github.event.issue.title }}
  run: echo "$ISSUE_TITLE"
```

Treat issue titles, PR titles, comments, branch names, and user-controlled inputs as untrusted.

### 4. Misusing `pull_request_target`

`pull_request_target` runs with trusted context and may access secrets. Never check out and execute fork code in that context.

```yaml
# Dangerous
on: pull_request_target
jobs:
  test:
    steps:
      - uses: actions/checkout@v{N}
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: ./scripts/test.sh
```

Use `pull_request` for testing fork code. Reserve `pull_request_target` for metadata-only actions like labeling or commenting, with strict permissions.

### 5. Over-installing runner tools

GitHub-hosted runners already include common tools. Avoid setup steps unless the workflow needs a specific version.

Common preinstalled tools on Ubuntu runners include: Node.js, npm, npx, Python, pip, Ruby, Go, Docker, git, gh, curl, jq, and yq.

Often not preinstalled or version-sensitive: Bun, Deno, pnpm, Poetry, Ruff, Zig, Rust toolchains.

Check runner image docs when in doubt:

- Ubuntu: https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md
- macOS: https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md
- Windows: https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md

## Recommended workflow shape

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - uses: actions/checkout@v{N}

      - name: Run tests
        run: ./scripts/test.sh
```

## Common events

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
  schedule:
    - cron: "0 0 * * 1"
  release:
    types: [published]
  workflow_call:
```

## Common permissions

```yaml
permissions:
  contents: read        # checkout, CI reads
  contents: write       # commits, tags, releases
  pull-requests: write  # PR comments/reviews/labels
  issues: write         # issue comments/labels
  packages: write       # package publishing
  id-token: write       # OIDC cloud auth
```

Use the narrowest permission set possible. Prefer job-level permissions when only one job needs elevated access.

## Common actions

Verify current major versions before use:

```yaml
steps:
  - uses: actions/checkout@v{N}
  - uses: actions/cache@v{N}
  - uses: actions/download-artifact@v{N}
  - uses: actions/upload-artifact@v{N}
```

## Debugging commands

```bash
# List recent runs
gh run list --limit 10

# View failed run details
gh run view {run-id} --log-failed

# Watch run
gh run watch {run-id}

# Trigger workflow
gh workflow run ci.yml --ref main

# Download artifacts
gh run download {run-id} --dir artifacts
```
