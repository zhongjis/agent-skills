# Parallel Axes

How to run review axes as isolated passes — the *how*. `SKILL.md` § Execution owns the *when* (required whenever an isolation mechanism — a sub-agent or task tool is the usual one — is available and the risk is not Trivial); if none exists, ignore this file and run the axes sequentially inline in one shared context.

## What to dispatch (fan-out control)

Running one isolated pass per axis re-feeds the diff to eight passes and wastes context. Group into a few passes scaled to risk:

- **Standard risk → two passes:** the judgment-heavy axes (Correctness, Regression, Security) in one, the lighter axes (Standards, Spec, Tests, Observability, Performance) in the other.
- **Risky diff → split the heavy pass further** so no pass carries more than its budget can reason about — e.g. Security alone, Regression + Correctness together.
- **Spec** rides with the light bundle, unless the spec is large — then give it its own pass.

The pass count follows the diff, not a fixed number: give the judgment-heavy axes your strongest reasoning (SKILL.md § Execution), and never split so fine that a pass's budget stretches thin enough to stall.

## Self-contained brief (every pass carries this)

An isolated pass shares none of the main reviewing context, so its brief must stand alone. Include, verbatim:

1. **Diff access** — the exact diff command (`git diff <base>...HEAD`) and the commit list, or the diff contents.
2. **Foundation brief** — the behavior delta and the axis triage from step 3 of the process.
3. **Axis assignment** — which axis or axes this pass owns, with the matching section(s) of `axis-checklists.md` pasted in full; the pass cannot open files the main reviewing context read.
4. **Report contract** — "Report findings for your assigned axis only. Tag each with the axis name, a severity (`[BLOCKER]` / `[MAJOR]` / `[SUGGESTION]` / `[NIT]` / `[KUDOS]`), and a file:line. Quote the code or spec line for each. Write each finding tight — a one-sentence issue plus a fix, active voice, no filler or puffery. Score this axis's confidence 1-5, dropping it by 1 for each risk multiplier this axis owns (SKILL.md § Confidence adjustments). If you find nothing, say so explicitly. Under 400 words per axis."
5. **Budget** — a tool-call ceiling scaled to risk: roughly ~8 for a Standard read, ~15 for a Risky deep pass. Read and reason from the diff and the files it touches; don't run builds or the full test suite unless your axis (Tests, sometimes Correctness) needs execution to judge. A pass that reasons tightly from the code beats one that stalls exploring.

The same brief structure feeds a sequential inline pass — that shared shape is what keeps the two execution modes producing identical review content.

## When a pass stalls or comes back empty

An isolated pass that times out, stalls, or returns empty is not "no findings" — re-run it once, tighter: halve the tool-call ceiling, forbid build and test runs, and point it at the specific file regions to read. If the re-run also fails, fold that axis into your own inline pass, flag the fallback in its output group, and drop its confidence by 1 (SKILL.md § Confidence adjustments), so the axis stays covered and the degraded read never passes as a clean one.

## Aggregation

When the passes return, assemble them per the **Aggregation** rules in `SKILL.md`.

Isolation is the point: because each pass ran in its own context, no axis could see or be colored by another. That separation is already enforced by the isolation — carry it through into the report rather than re-judging across axes. Carrying separation through is not the same as trusting reported severities verbatim: you still validate each finding within its axis (SKILL.md § Aggregation).
