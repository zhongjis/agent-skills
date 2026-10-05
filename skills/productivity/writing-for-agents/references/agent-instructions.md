# Agent instructions

The agent/subagent branch of [`writing-for-agents`](../SKILL.md): role/actor-scoped definitions for how one specific agent behaves. Everything else about writing it is the universal reference in `SKILL.md`.

## Facts and policy

The harness owns **facts**: tool results, status reports, limits, and anything it enforces. The prompt owns **policy**: what the agent does with those facts. A prompt line that restates a fact is a cache (see Pruning in `SKILL.md`) and goes stale when the harness changes.

- When an agent misbehaves because the harness reports a wrong fact, fix the harness. The prompt holds policy only, so it never teaches the agent to distrust a fact the harness later reports correctly. Before adding a rule after a failure, find the cause first: a harness cause gets a harness fix; only an agent-behaviour cause earns prompt text.
- Write only rules the agent can act on: it observes the trigger and can take the action. A ban on an action the agent cannot take is a no-op, and an outcome it can never report is a branch no run reaches. Design notes for whoever maintains the harness belong in the harness's own docs.

## Roles

- Put each rule in the prompt of the agent that owns the decision. For example, a worker agent cannot resize its own assignment, so sizing rules live in the orchestrator/parent's prompt; the worker's prompt holds what the worker decides, such as stopping when an input is missing.
- A term used in both the lead's and the worker's prompt needs one definition that both prompts share; each agent reads only its own prompt.

## Description

The description is the context pointer the parent reads to decide when to delegate. Name the task type and its boundary; the body carries how the agent works. The pointer-writing rules in `SKILL.md` apply in full.
