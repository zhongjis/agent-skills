# Pipeline structure

## Critical path

- Draw the `needs` graph and find the longest chain; only jobs on it set wall-clock.
- Put lint, typecheck, and unit tests first; expensive jobs (integration, E2E, Docker, matrix) `needs:` them, so a cheap failure stops expensive work. Matrix `fail-fast` covers only one matrix; `needs` gives fail-fast across jobs.
- Remove `needs` edges that encode habit rather than data dependency; independent jobs run in parallel.
- Merge sub-minute jobs: each job pays checkout, setup, and per-job minute rounding.

## Build once

Build in one job, upload the output with `actions/upload-artifact` (`retention-days: 1`), and download it in test and deploy jobs. Caches carry dependencies across runs; artifacts carry this run's outputs between jobs.

## Triggers

- Limit `push` to the default and release branches when `pull_request` already covers PR branches.
- Skip draft PRs (`if: github.event.pull_request.draft == false`) where policy allows; run on `ready_for_review`.
- Schedules: lower cron frequency to how often someone reads the result; skip when the head commit already has a green run; disable on dormant repositories.
- Bot PRs: group and schedule Dependabot or Renovate updates so dependency bumps do not each run the full pipeline.
- Self-triggering loops: workflows that push commits with a PAT, or `workflow_run` chains, can retrigger CI indefinitely; the default `GITHUB_TOKEN` does not trigger new runs.

## Checkout

- Keep the default shallow clone unless a step needs history.
- Need history (affected detection, versioning)? Use `fetch-depth: 0` with `filter: blob:none`, or fetch only the base ref.
- Monorepos: `sparse-checkout` the directories a job uses.
- Set `lfs: true` and `submodules` only on jobs that read them; cache LFS objects when they are large and stable.
- Replace actions that download a large tool each run with the runner image's preinstalled tool or a cached, version-pinned, checksum-verified download.

## Merge queue

- Every workflow providing a required check must also trigger `on: merge_group`, or queued PRs wait forever.
- Move expensive suites (full matrix, E2E) from PR runs to `merge_group` runs; PRs keep fast checks.
- Merge-queue runs execute on temporary `gh-readonly-queue/*` branches; caches they save are not reusable, so restore only.
- Enabling or reconfiguring the queue is a repository-settings change, outside the decision boundary.

## Central enforcement

Across many repositories, put shared timeouts, concurrency, and permissions in reusable workflows or org rulesets rather than hand-editing each repository.

## Other platforms

| Lever | GitHub Actions | GitLab CI | CircleCI |
| --- | --- | --- | --- |
| Paths filter | `on.<event>.paths`, `dorny/paths-filter` | `rules: changes:` | dynamic config with path filtering |
| Cancel superseded | `concurrency` + `cancel-in-progress` | `interruptible: true` + auto-cancel redundant pipelines | auto-cancel redundant workflows |
| Job graph | `needs` | `needs` (DAG) | `requires` |
| Dependency cache | setup-action `cache:` | `cache: key: files:` | `save_cache` / `restore_cache` keyed on checksum |
| Test splitting | matrix shards | `parallel:` | `parallelism` + `circleci tests split --split-by=timings` |
