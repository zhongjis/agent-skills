---
name: research
description: Research questions against high-trust primary sources. Use for factual investigations, documentation or API research, and reading legwork; offer deep research for broad, contradictory, high-stakes, or independently verified questions.
---

# Research

Choose the smallest research path that fits the question.

## Ordinary research

Use this default path for bounded questions without a need for independent verification:

1. Start one background agent to investigate the question.
2. Require primary sources: official documentation, source code, specifications, or first-party APIs. Trace each claim to its owning source.
3. Return one cited Markdown report.

Research authorizes investigation only. Return findings in the response unless the user separately authorizes creating, saving, rendering, or publishing them. When persistence is authorized, save exactly one cited Markdown file in the repository's existing research location; if none exists, choose a sensible location and report it.

## Deep research

Offer this path when the question is broad, contradictory, high-stakes, or needs independent verification. Explain that it runs the saved multi-agent `deep-research` workflow. A request for deep research alone is not workflow execution opt-in; ask for explicit permission to run the workflow or multi-agent orchestration.

After explicit opt-in, collect these inputs before launch:

- A nonblank question.
- One to six distinct, disjoint, independently verifiable coverage requirements; decompose broad input before launch.
- Nonblank evidence context, including known sources, constraints, and uncertainties.
- A live read-only agent selector. Check the current Agent roster and its configured permissions; it must permit only read-only work. No suitable selector is a blocker.
- Bounds: `maxRounds` from 1 through 3.

For deep discovery, prompts MUST request atomic, one-fact claims scoped to one assigned requirement and directly supported by cited excerpts. NEVER request compound/report-shaped claims, embedded citation numbering, cross-requirement leakage, or unsupported synthesis.

Verify that `SubagentWorkflow`, the saved `deep-research` workflow, and the permission-checked selector are available. Then invoke:

```js
SubagentWorkflow({
  name: "deep-research",
  args: {
    question,
    requirements,
    evidenceContext,
    readOnlyAgentType,
    maxRounds,
  },
})
```

For an explicit deep-workflow request, named workflow resolution failure, provider/schema failure, or evidence-quality rejection MUST fail visibly and remain distinct. NEVER silently downgrade to ordinary research. Diagnose asynchronous provider failures from retained child transcript/details, NEVER missing summary results alone.

Before conclusions, inspect `accepted`, `stopReason`, verified coverage, `citedFindings`, gaps, and rejections. Only claims in `citedFindings` mapped to verified coverage MAY be presented as verified conclusions; `accepted: false`, rejected claims, and contested claims MUST remain visible as failures or gaps. When a rerun remains authorized after a provider/schema repair, run one canary on the intended selector/provider before the full rerun.

Workflow execution authorizes neither writing nor publication. Treat its returned bundle as research evidence only; obtain separate explicit authorization before persisting, rendering, or publishing it.
