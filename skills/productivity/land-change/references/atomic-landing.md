# Atomic landing

Use when the change cannot land safely as independent layers. Keep review slices without treating them as separate release units.

## Landing and repair ownership

- Keep layer PRs as drafts. Check the repository's CI conditions: some repositories skip test lanes on drafts; draft status alone does not guarantee that behavior.
- Open one landing PR from the top branch to main. Its diff covers the whole change. Verify that every required lane actually runs; compute affected lanes against main, not the layer below. Turborepo supports explicit source-control comparisons such as `--filter=[main...my-feature]`. [1]
- Before any repair fan-out, assign every CI and review repair to the top worker. Fix each valid bug class, including sibling calls through the shared function, rather than dispatching one patch per layer.
- When main moves, merge main into the top branch, then run the landing gates again. Keep review history stable: do not rebase or force-push the atomic landing branch. Perfetto documents this merge-based policy to avoid disrupting GitHub reviews. [2]

## Review budget

Request one review from the review bot, fix each valid bug class, then request one more review. This budget is not permission to land with unresolved findings; report a remaining blocker instead of repeating automatic review rounds.

For CodeRabbit, inspect the repository's effective configuration before relying on manual review cadence. Incremental review is enabled by default; use `@coderabbitai review` to request a review. Draft/base-branch settings also affect automatic review eligibility. This skill does not authorize changing reviewer configuration. [3][4]

## Destructive or production window

Before the window, rehearse destructive steps in a safe environment, including recovery, and record the commands and expected results. Resolve tool, credential, and package-build problems before the freeze rather than discovering them during the window.

1. **Freeze.** Announce a merge freeze with its scope, owner, and end condition. GitHub has no native merge-freeze switch; an enforceable freeze needs a required check or equivalent protection. With Mergify, require its merge-protection check so direct GitHub merges cannot bypass the freeze. If enforcement is unavailable, report that limit rather than treating an announcement as protection. [5]
2. **Pin.** Record main's SHA and the exact landing head that passed all required lanes and review. Immediately before each destructive or production step, re-check both against the live refs. If either differs from the approved, tested pair, stop the step, integrate and retest as needed, and establish a new pair before proceeding.
3. **Handle flakes once.** Rerun a suspected flaky job once. If it fails again, investigate the failure instead of rerunning repeatedly. Retain the result for the pinned head.
4. **Close.** Perform only authorized steps. Verify their result and announce the end of the freeze after the window's completion criteria hold, or hand off an explicit blocker with the freeze state.

## Sources:

[1] Turborepo, Running tasks (https://turborepo.dev/docs/crafting-your-repository/running-tasks)
[2] Perfetto, Developer tools, pinned revision (https://flutter.googlesource.com/third_party/perfetto/+/393ff462b5982e1fff22b0757a2ff4832991ec9d/docs/contributing/developer-tools.md)
[3] CodeRabbit, Automatic review controls (https://docs.coderabbit.ai/configuration/auto-review)
[4] CodeRabbit, Review commands (https://docs.coderabbit.ai/reference/review-commands)
[5] Mergify, Scheduling freezes (https://docs.mergify.com/merge-protections/freeze.md)
