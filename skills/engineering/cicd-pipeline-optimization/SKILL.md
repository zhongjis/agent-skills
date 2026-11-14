---
name: cicd-pipeline-optimization
description: "CI/CD pipeline optimization playbook for cost and speed. Use when CI is slow or expensive: auditing workflow YAML, shortening PR feedback time, diagnosing a CI bill spike, cutting test, cache, or build time, choosing runners (ARM, larger, external, self-hosted), or attributing CI cost per team."
adaptedFrom:
  - "https://cicdpipelinecost.com"
---

# CI/CD pipeline optimization

CI has two currencies: **billed minutes** (`$`, the bill) and **wall-clock** (`⏱`, developer wait). Every lever moves one, both, or trades them; name the currency before recommending it.

- Cuts both: skip work that need not run (paths filters, cancelled superseded runs, affected-only tests, pruned matrices), reuse work (caches, artifacts), right-size runners, bound runaway jobs.
- Free speed: shorten the **critical path**, the longest `needs` chain from trigger to final check. Run independent jobs in parallel, gate expensive jobs on cheap ones, and use every core inside a job before sharding across jobs.
- Bought speed: sharding (more jobs, more setup minutes, less wait) and faster runners (higher rate, shorter duration). Justify these with developer wait time, or with cost per job when speed-up outpaces the rate increase.

Waste follows a **power law**: two or three leaks usually hold most of it. Find those first.

Examples use GitHub Actions; [pipeline](references/pipeline.md) maps the levers to GitLab CI and CircleCI.

## Steps

1. **Baseline both currencies.** Start from billed usage where the account exposes it: the platform's billing usage report and each external runner vendor's usage view. Then break that bill down for the top workflows, from the last ~50 runs: minutes per run and per job, PR wall-clock p50/p90, queue time, critical-path job, rerun rate, cache hit rate. Methods: [cost model](references/cost-model.md). Done when the top three workflows each have both baselines and the source of each figure.
2. **Audit** each top workflow against the leak checklist. Done when every item is marked hit, miss, or n/a per workflow, with `file:line` for hits.
3. **Rank** hits by saving in the currency the user prioritises ÷ effort, priced with the [cost model](references/cost-model.md).
4. **Fix** inside the decision boundary on a branch. Done when inside fixes are committed on the branch and each outside item names the decision it needs.
5. **Verify** by pushing the branch or a draft PR: compare per-run job durations, wall-clock, billed minutes, cache hits, and skipped or cancelled jobs against the step-1 per-run baseline. Fix failures the change caused and rerun.

Handoff: one table (finding | `workflow:line` | lever | currency | estimated saving | effort | applied or proposed), then the verifying run's evidence, then the decisions awaiting a human.

## Leak checklist

In typical impact order. Each item names what to detect and the fix.

1. `$⏱` **No paths filter**: docs edits run full builds. Add `on.<event>.paths`, or gate jobs with `dorny/paths-filter` outputs. A workflow skipped by `paths` never reports its checks, so a required check stays pending and blocks merge; for required checks, gate jobs with `if:` so the workflow still reports.
2. `$` **No concurrency gate**: superseded PR pushes keep running. Key the group by PR number so only PR runs cancel; every other event gets a unique group:

   ```yaml
   concurrency:
     group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }}
     cancel-in-progress: true
   ```

   A shared group without cancellation is no fix: runs wait in line, and a newer pending run replaces an older one.
3. `$` **Duplicate triggers**: `on: [push, pull_request]` runs twice per PR commit. Limit `push` to the default and release branches; skip draft PRs where policy allows.
4. `$⏱` **Missing or broad cache keys**: key on OS + arch + lockfile hash, never a whole-repo hash or `github.sha`. See [caching](references/caching.md).
5. `$⏱` **Full test suite on every PR**: run affected-only tests; move E2E to the merge queue or nightly, or path-scope it to UI. See [tests](references/tests.md).
6. `$⏱` **Serial critical path**: expensive jobs not gated on lint/typecheck/unit, or independent jobs chained by `needs`. See [pipeline](references/pipeline.md).
7. `$⏱` **Rebuilding per job**: test and deploy jobs rebuild what an earlier job built. Build once and pass an artifact.
8. `$⏱` **Rerun-driven minutes**: whole workflows rerun for flaky tests. Retry at test level, quarantine, track flake rate. See [tests](references/tests.md).
9. `$` **No `timeout-minutes`**: a hung job bills until the platform's multi-hour default. Set job and long-step timeouts near 2–3× the p90 duration.
10. `$` **Wrong OS**: macOS or Windows runners for platform-neutral work. Move it to Linux.
11. `$⏱` **Full matrix on every PR**: run one primary cell on PRs and the full matrix on the default branch or merge queue. Flag `fail-fast: false` outside compatibility debugging.
12. `$⏱` **Runner size mismatch**: compare CPU use and cost per job across sizes; see [runners](references/runners.md).
13. `$⏱` **Docker builds without a persisted layer cache**: no `cache-from`/`cache-to`, source copied before the lockfile, no `.dockerignore`. See [caching](references/caching.md).
14. `$` **Schedules**: cron runs more often than anyone reads the result, runs when nothing changed since the last green run, or runs on dormant repositories.
15. `$⏱` **Slow job setup**: full-history clones, LFS or submodules fetched unused, heavy actions downloading tools each run, many sub-minute jobs each paying setup. See [pipeline](references/pipeline.md).
16. `$` **Unread uploads**: upload only what a later job or a human downloads. Inter-job artifacts get `retention-days: 1`, diagnostics upload under `if: failure()`, release artifacts upload on default or release branches only; set retention on every upload.

## Decision boundary

Inside, on a non-default branch, because each change is a reversible YAML or Dockerfile edit proven by the next CI run: paths filters, concurrency gates, trigger narrowing, caches and cache keys, timeouts, `needs` ordering, artifact passing and retention, checkout options, Docker layer order, runner downsizing, and pushing that branch or a draft PR to verify.

Outside, waiting for a human, because each changes coverage, security, settings, vendor, or spend commitments:

- dropping matrix cells, tests, or E2E from PRs; adding or changing required checks, branch protection, rulesets, or merge-queue settings
- switching to ARM before a benchmark passes, larger or external runners, self-hosted runners, platform migration
- deleting caches or artifacts, changing `permissions`, secrets, `cache-mode`, or `pull_request_target`/`workflow_run` workflows
- pushing directly to the default branch

For workflow hardening beyond these interactions, use the `github-actions` skill.

## References

- [cost model](references/cost-model.md) — when baselining, estimating a saving, or computing payback.
- [pipeline](references/pipeline.md) — when restructuring jobs, triggers, checkout, artifacts, or merge queues, or mapping levers to GitLab CI or CircleCI.
- [tests](references/tests.md) — when tests dominate job time or reruns are frequent.
- [caching](references/caching.md) — when adding or fixing dependency, Docker, compiler, or remote build caches.
- [runners](references/runners.md) — when changing `runs-on`: ARM, larger, external, self-hosted, or macOS runners.
- [monorepo](references/monorepo.md) — when one PR triggers CI for packages it did not touch.
- [attribution](references/attribution.md) — when asked which team or workflow costs what, or why the bill jumped.

## Time-sensitive figures

Prices, OS multipliers, plan allowances, platform limits, vendor rosters, lever medians, and break-even thresholds change often; this skill stores none of them. When an estimate or decision needs one, read it from cicdpipelinecost.com and quote it with the page's verification date. When the site is unreachable or older than the vendor's own pricing page, use the vendor page.

- https://cicdpipelinecost.com/github-actions-pricing — GitHub-hosted rates, OS multipliers, included minutes, storage, larger runners.
- https://cicdpipelinecost.com/arm-runners — ARM rates and compatibility.
- https://cicdpipelinecost.com/depot-vs-namespace-vs-blacksmith — external runner providers and rates.
- https://cicdpipelinecost.com/self-hosted-runners — self-hosted fee status and break-even.
- https://cicdpipelinecost.com/platform-comparison — non-GitHub CI platforms.
- https://cicdpipelinecost.com/ — the cost calculator and the optimiser's per-lever medians.
