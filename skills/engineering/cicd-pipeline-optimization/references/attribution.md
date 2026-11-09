# Spend analysis

## Attribution

1. **Extract.** Use the billing usage report (Settings → Billing → Usage, exportable), which breaks usage down by repository and workflow where the plan provides it. Without billing access, measure per-workflow minutes from run and job data as in [cost model](cost-model.md).
2. **Own.** Map each workflow to a team. Cheapest convention: prefix the workflow `name:` with the team (`team-backend/build-api`), then group by prefix. Renaming breaks `on.workflow_run.workflows` triggers and status badges that reference the old name; search for both first, or keep names and use CODEOWNERS or a mapping file.
3. **Price.** Multiply minutes per runner label by current rates (https://cicdpipelinecost.com/github-actions-pricing); report included-minute drain separately from overage dollars.
4. **Report.** Start with showback (teams see their cost, no budget charge). Move to chargeback only where FinOps practice already exists, since it adds budget transfers and disputes.

A daily script writing team totals to CSV covers most orgs. A cloud cost platform adds value only when CI cost belongs in the same dashboard as cloud spend.

Review monthly: each team's top workflow by minutes, audited against the leak checklist in [SKILL.md](../SKILL.md).

## Bill spike

1. Diff usage by day and by workflow; find the first day and the workflow that jumped.
2. Check that workflow's history (`git log -p -- .github/workflows/<file>`) around that day. Usual causes, most common first:
   - a new macOS workflow
   - E2E moved onto every PR
   - an expanded matrix
   - a new Docker build without a layer cache
   - a new or more frequent schedule
   - a self-retriggering loop (PAT pushes, `workflow_run` chains)
   - crossing the plan's included minutes into overage
3. Confirm with the run count and per-run minutes before and after; then fix through the leak checklist.
