# Cost model

Measure first; estimate only what cannot be measured yet. Rates come from the pages listed under "Time-sensitive figures" in [SKILL.md](../SKILL.md).

## Billed usage first

- GitHub-hosted: `gh api "organizations/<org>/settings/billing/usage?year=<y>&month=<m>"` returns minutes, gross and net amounts per SKU and day.
- External runners (Blacksmith, Depot, Namespace and similar): read the vendor's usage page, grouped by workflow, job, runner type and outcome. It usually needs a signed-in browser.
- Project a month from the daily rate, weekends included.

## Measure

Per top workflow, sample the last ~50 runs:

```bash
gh run list -w <workflow-file> -L 50 --json databaseId,event,conclusion,createdAt,attempt
gh api "repos/{owner}/{repo}/actions/runs/<run-id>/jobs?filter=all" --paginate \
  --jq '.jobs[] | {name, labels, run_attempt, created_at, started_at, completed_at, conclusion}'
```

| Metric | From the jobs data |
| --- | --- |
| Job minutes | `completed_at − started_at`, rounded up to whole minutes per job, summed per runner label |
| Queue time | `started_at − created_at` per job; report p50/p90 |
| Wall-clock | last `completed_at` − first `created_at` per run; report PR p50/p90 |
| Critical path | the latest-finishing job, traced back through `needs` |
| Rerun rate | share of runs with `attempt > 1` |
| Cache hit rate | `gh run view <run-id> --log` lines for cache restored versus not found, per cache step |

When neither source is available, estimate monthly minutes as per-run minutes × runs/month for each runner label. Public repositories and self-hosted runners have zero billed minutes; their cost is compute, maintenance, and wall-clock.

## Price

```text
monthly_cost = Σ over runner labels (monthly_minutes[label] × rate[label])
```

Included plan minutes drain at per-OS multipliers before overage applies; read both from the pricing page. Report included-minute drain separately from overage dollars.

## Estimate a lever

- **Prefer a trial**: apply the fix on a branch, measure per-run minutes and wall-clock, and project per-run savings × runs/month.
- **Before a trial**: use the optimiser's per-lever medians from https://cicdpipelinecost.com/ as a labelled prior, never as a measurement.
- **Stack multiplicatively**: apply each lever to the minutes left after the previous one; never add percentages.
- **Runner changes**: cost per job ∝ rate ratio ÷ speed-up. A faster runner lowers the bill only when its speed-up exceeds its rate ratio.
- **Caching**: credit only the measured restore-versus-install difference on hit runs, scaled by hit rate. Cache hits do not remove whole job minutes.

## Payback

```text
monthly_saving = baseline_cost − projected_cost
payback_months = effort_hours × hourly_rate / monthly_saving
wait_hours_saved/month ≈ PR runs/month × wall-clock minutes saved / 60   # upper bound: assumes every wait blocks someone
```

Ask the user for the hourly rate, or label the assumption used. Report bought-speed levers by wait hours saved, since they can raise the bill.

## Human cross-check

The cost calculator at https://cicdpipelinecost.com/#calculator models the same arithmetic from platform, OS mix, minutes per run, runs per day, working days, team size, and cache hit %. It treats cache hit % as removing that share of all minutes, so its figure runs low for cached pipelines. Offer it to a human who wants to explore scenarios; base the handoff on measured runs.
