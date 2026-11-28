---
name: swarm-mind
description: Principles for getting second opinions from external agents on other models. Use when sending a code change, a plan (spec, ticket breakdown) or an open question (repo audit, design question) to other agents, or when judging what they return.
---

# Swarm mind

You are the **caller**: you ask external **reviewers** for a second opinion and judge what comes back. A reviewer is worth its cost only for what you cannot see yourself, so every rule here protects its independence and keeps its output honest. This skill is method only: the calling skill or your harness owns the commands that start, message and record reviewers, and decides how many reviewers to use and what to do with the findings.

- For a code change, read [references/code-review.md](references/code-review.md).
- For a plan (spec, ticket breakdown), read [references/plan-review.md](references/plan-review.md).
- For an open question (repo audit, design question), read [references/consult.md](references/consult.md).

## Principles

- **Different minds.** A model of the author's family shares the author's blind spots; a reviewer runs on another family.
- **Cold start.** A reviewer knows only its brief. Whatever the brief leaves out, the reviewer guesses.
- **One contract.** The brief is the contract: every reviewer gets the same one, and the target stays fixed while they read it.
- **Independence.** Give reviewers the work, not your conclusions; no reviewer sees another's output during a round. A reviewer handed your hypothesis tends to return it confirmed.
- **Evidence over claims.** A finding is a lead until you re-check it. Agreement between reviewers raises priority, never truth; a finding only one reviewer raised is not weaker for that.
- **Authority decides.** Findings are judged against the agreed spec and decisions, never against a reviewer's taste.
- **Reviewers find, the caller decides.**
- **Converge.** Each round must close blockers or find new ones; a round that does neither ends the review. No findings is a valid result.

## Pick reviewers

- A kind or model the user names wins.
- Read the author's family from its current model: `gpt` when the model ID contains `gpt`, `gemini` when it contains `gemini` or the provider starts with `google`, else `claude`. With no author (a consult), the caller is the author.
- Run `scripts/reviewers.sh --not <author family>`, adding `--visual` for a visual target (UI judged against a mock or screenshot). The script owns the reviewer chain and the kind-to-family table: it prints the installed kinds in chain order as `<kind> <family>`, where `any` (Pi, Copilot) runs whichever model is selected. It caches the PATH probe; `--refresh` forces a new one.
- Take the lines in order, skipping a kind with a quota or outage seen this session and, when you use several reviewers, a family already picked.
- An `any` kind starts on its default model; when that model's family is excluded, switch it to an allowed family before the review starts. An `any` kind with no allowed model configured is not eligible.
- When no kind is eligible, ask the user; a same-family review is their decision. When the caller asks for more reviewers than eligible kinds and families allow, use the eligible ones and report the shortfall to the caller.

## Approach

1. **Frame.** Write down the intent of the work, the pinned target (fixed so it cannot drift mid-review), the authority, highest first (agreed spec or ticket; user decisions, in the user's words where they set scope; current behavior), and what is out of scope. **Done when** a stranger could judge the work from the frame alone.
2. **Brief.** The frame, plus:
   - **Hands off:** the reviewer changes no tracked files (ignored caches and build output from its checks are fine) and posts nothing; findings come back to you.
   - **Return shape:** each finding with its location, why it matters against the authority, and whether it claims to block; a claim about runtime behavior carries the command run and its output. End with a verdict.
   - Ask for every issue, efficiency and scope creep included, and say that no findings is a valid answer.
3. **Collect.** Leave the target untouched until every reviewer reports. When one of several reviewers drops out, continue with the rest and say so. A result arriving after you moved on is feedback only.
4. **Judge.**
   - Re-read each cited location and rerun each cited command. Drop what the evidence does not support, and record why.
   - With several reviewers, pool their findings and merge those with one root cause, keeping which reviewers found each and how many each had dropped.
   - A finding **blocks** only with evidence in one of these: a correctness bug; a real runtime, data-loss or security risk; a conflict with the authority; a break in a flow that works today; an unfixed earlier blocker; removal or weakening of an authorization, ownership or isolation check without authority. Everything else is a **note**.
   - **Scope:** work is necessary when the stated goal fails without it and the author can name the requirement it serves, such as a migration the feature needs. Work no requirement needs is **scope creep**, a conflict with the authority; a reviewer's suggestion of new work is scope creep too. Necessary work outside the agreed scope is neither creep nor a blocker: report it to the caller as an item that needs approval.
   - When reviewers contradict each other about what the work should do, the authority is underspecified: settle it with the user or sharpen the frame, then review again. Never average the answers.
5. **Next round.** A later round reviews only what changed since the last reviewed version, and blocks only on earlier blockers still open or new blockers inside the change. Keep to the cap in the target's reference unless the user sets another.
6. **Report.** To whoever reads your result: the reviewers and models, the rounds run, each blocker, findings dropped with the reason, and open questions.
