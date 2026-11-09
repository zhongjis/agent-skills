# Tests

## Parallelism

1. **In-job first**: use every core of the runner (`pytest -n auto` via pytest-xdist, jest workers, `go test -p`, Gradle/Maven parallel forks). No extra setup minutes.
2. **Then shard by timing**: split by historical durations, not file count (`pytest-split --durations-path`, Playwright or jest `--shard`, CircleCI `--split-by=timings`, Knapsack-style splitters). Persist the timing file as an artifact or cache.
3. **Stop adding shards** when per-shard overhead (checkout, cache restore, per-job rounding) exceeds the wall-clock gained. Sharding never lowers billed minutes.

## Selection

Run only the tests a change can affect:

- Package level: `nx affected -t test`, Turborepo `--filter='...[origin/main]'`, Bazel `bazel query 'tests(...)'` over changed targets. See [monorepo](monorepo.md).
- File level: `jest --findRelatedTests`, `pytest --testmon`.
- ML-based test selection services for large mixed-language suites: current options at https://cicdpipelinecost.com/test-optimisation.

Keep the full suite on the default branch or merge queue so selection misses surface within a day.

## Flaky tests

- Retry at test level, capped at 1–2 attempts (`jest.retryTimes`, `pytest-rerunfailures`, Playwright `retries`), never by rerunning whole workflows.
- Record every retried-then-passed test as flaky; track flake rate per test.
- Quarantine: move a flaky test to a non-blocking job with a named owner and a fix-by date; it keeps running so a fix is detected. Flaky-test tooling options: https://cicdpipelinecost.com/test-optimisation.
- Unbounded quarantine is deleted coverage; review the quarantine list with each audit.

## E2E

Run E2E on the merge queue, nightly, or path-scoped to UI changes; PRs keep unit and integration checks. Moving E2E off PRs changes coverage, so it waits for a human.
