---
name: land-change
description: Land a change that spans several PRs or must deploy as one unit. Choose independently landable GitHub stacks or one atomic landing before dispatching CI and review repairs.
---

# Land change

Choose the landing shape before splitting work or dispatching repairs. This skill chooses topology and fix ownership; it does not grant publication, merge, deployment, or history-rewrite authority.

## Can each layer land on main alone?

Ask this of the actual change, not its review-sized slices. A layer qualifies only when main remains safe and deployable without the layers above it, often behind a feature flag. Independently landable increments support frequent integration; a branch that waits to land as one unit defers merge risk. [1][2][3]

- **Yes: GitHub stack.** Keep normal per-PR CI and review, with each branch based on its prerequisite. Merge bottom-up. All lower PRs must be approved and green before a selected upper PR can merge. For commands and stack restrictions, read the `gh` skill's `references/stacked-prs.md`. [4]
- **No: atomic landing.** Keep layer PRs as drafts and use one landing PR from the top branch to main. Decide before any fan-out that fixes go on top only. Read [atomic-landing.md](references/atomic-landing.md) for CI scope, stable updates, review rounds, and the destructive or production window.

If independent landing is unknown, establish it from the dependencies before choosing a stack. Reviewability alone is not evidence that a layer can land alone.

## Done

The plan names its landing shape, branches and bases, repair owner, and required CI/review gates. When executing, completion requires the authorized landing result at its verified head, plus any window evidence required by the atomic reference. Report remaining blockers without bypassing gates.

## Sources:

[1] Gearflow, Making a Version of Stacked Diffs Work for a GitHub Org (https://gearflow.com/blog/making-a-version-of-stacked-diffs-work-for-a-github-org)
[2] DORA, Trunk-based development (https://dora.dev/capabilities/trunk-based-development/)
[3] Martin Fowler, FeatureBranch (https://martinfowler.com/bliki/FeatureBranch.html)
[4] GitHub, Merging stacked pull requests (https://docs.github.com/en/enterprise-cloud@latest/pull-requests/how-tos/merge-and-close-pull-requests/merging-stacked-pull-requests)
