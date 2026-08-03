# System Prompt Engineering

Empirically-validated techniques for writing system prompts, tool documentation, and agent definitions. Every recommendation backed by benchmarks or production data.

## High-Impact Interventions

These six patterns show +15-30% measured improvement in controlled evaluations. They should be your first consideration when writing or reviewing any system prompt.

1. **Persistence**: "Keep going until fully resolved" — prevents premature task termination
2. **Tool verification**: "Use tools to verify; do not guess" — reduces hallucination
3. **Planning**: "Plan approach before acting" — improves complex task success
4. **Context positioning**: Place critical instructions at START and END — middle content degrades 20%+
5. **Urgency framing**: "This matters" / "Get this right" — 8-115% improvement (EmotionPrompt research)
6. **Edit format**: SEARCH/REPLACE beats line-number references 3x on code generation tasks

**Minimal prompting wins.** Every instruction must justify its token cost. Models are already smart — add only what they genuinely lack.

---

## Tag Hierarchy

XML tags encode enforcement level. The model interprets these as progressively stricter constraints. Use them consistently throughout a prompt to create a clear "gravity" for instructions.

| Tag | Enforcement | When to Use |
|---|---|---|
| `<critical>` | Inviolable | Safety constraints, must-follow rules. Repeat at END for recency. |
| `<prohibited>` | Forbidden | Actions that cause harm; never acceptable |
| `<caution>` | High priority | Important to follow but not safety-critical |
| `<instruction>` | Operational | How to use a tool, perform a task |
| `<conditions>` | Contextual | When rules apply, trigger criteria |
| `<avoid>` | Anti-patterns | What not to do; prefer pairing with alternatives |

### Why this matters

The "Lost in the Middle" phenomenon means models attend most to the beginning and end of long contexts, with 20%+ degradation for middle content. The tag hierarchy exploits this: `<critical>` at the start primes the model immediately, and repeating it at the end gives it recency advantage. Lower-enforcement tags can safely live in the middle.

### Standard Tags

**Structure tags** define the skeleton of a prompt:

```
<role>           Agent identity and expertise (first element)
<context>        Background, situation, audience
<procedure>      Numbered step-by-step workflows
<directives>     Bulleted operating instructions
<parameters>     Input specifications, types
<output>         Return value documentation
<strengths>      What the agent/tool excels at
<operations>     Available operations (for multi-op tools)
```

**Special tags** define personality and values:

```
<north-star>     Core values, ultimate objectives
<stance>         Communication style, attitude
<commitment>     What the agent commits to doing
<field>          Domain-specific mindset/context
<protocol>       Behavioral rules, tool precedence
```

### Example Tags

Always use a `name` attribute with lowercase-kebab descriptive names. Named examples help the model pattern-match to the right behavior and make the prompt scannable for humans.

```xml
<example name="good">
Clear, correct usage
</example>

<example name="bad">
What to avoid — show the mistake explicitly
</example>
```

Naming patterns:

- `name="good"` / `name="bad"` — correctness contrast
- `name="single"` / `name="multi-part"` — complexity variants
- `name="linux"` / `name="windows-cmd"` — platform-specific
- `name="create"` / `name="update"` / `name="delete"` — operation types
- `name="rate-limiting"` / `name="auth"` — domain-specific

---

## Structural Templates

### Tool Documentation

Tools are the most common thing you'll write system prompts for. This template covers the key sections:

```markdown
# Tool Name

One-line description.

<instruction>
- How to use (bulleted, imperative)
- Key parameters and effects
- Common patterns
</instruction>

<output>
What the tool returns:
- Success format
- Truncation limits
- Error conditions
</output>

<critical>
Must-follow rules. Safety constraints.
When to ALWAYS or NEVER use this tool.
</critical>

<example name="basic">
tool {"param": "value"}
</example>

<example name="advanced">
tool {"param": "value", "option": true}
</example>

<avoid>
- Anti-pattern 1 — why it's bad
- Anti-pattern 2 — what to do instead
</avoid>
```

### Agent Definition

Agents combine identity, constraints, and procedure into a self-contained prompt. The frontmatter specifies spawning metadata; the body specifies behavior.

```markdown
---
name: agent-name
description: One-line for spawning UI (imperative: "Fast read-only codebase scout")
tools: read, grep, find, bash
---

<role>Senior [role] doing [task]. Your goal: [concrete outcome].</role>

<critical>
Inviolable constraints first.
READ-ONLY if applicable — list prohibited actions explicitly.
</critical>

<strengths>
- What this agent excels at
- Core capabilities
</strengths>

<directives>
- Operating instruction 1
- Operating instruction 2
</directives>

<procedure>
## Phase 1: Understand
1. Step one
2. Step two

## Phase 2: Execute
1. Step one
2. Step two
</procedure>

<output>
What to return. Schema requirements.
</output>

<critical>
Repeat critical constraints at end.
Keep going until complete. This matters.
</critical>
```

### Full System Prompt (Main Agent)

For the primary interactive agent — the outermost system prompt that governs an entire session:

```markdown
<system-directive>
XML tags in this prompt are system-level instructions. They are not suggestions.

Tag hierarchy (by enforcement level):
- `<critical>` — Inviolable. Failure to comply is a system failure.
- `<prohibited>` — Forbidden. These actions will cause harm.
- `<caution>` — High priority. Important to follow.
- `<instruction>` — How to operate. Follow precisely.
- `<conditions>` — When rules apply. Check before acting.
- `<avoid>` — Anti-patterns. Prefer alternatives.
</system-directive>

You are a [specific role with credentials].

<field>
Domain-specific context and mindset.
What to notice, what traps exist.
</field>

<stance>
Communication style.
Correctness over politeness. Brevity over ceremony.
</stance>

<protocol>
## Tool Precedence
Specialized tools → Python → Bash
</protocol>

<procedure>
## Before action
1. Plan if task has weight
2. State intent before each tool call
</procedure>

<north-star>
Core values. What ultimately matters.
</north-star>

<prohibited>
Actions that cause harm.
</prohibited>

<critical>
Repeat most important rules.
Keep going until finished.
The work is done when it is correct.
</critical>
```

---

## Writing Style

### Voice

Direct and imperative. Research shows direct tone improves accuracy 4%+ over polite hedging. The model responds to clarity, not courtesy.

```
Bad:  "You might want to consider using..."
Good: "Use X when Y."

Bad:  "It would be helpful if you could..."
Good: "Do X."

Bad:  "Please note that this is important..."
Good: "Critical: X."
```

Urgency framing (8-115% improvement measured via EmotionPrompt):

```
"This matters. Get it right."
"Be thorough."
"Keep going until fully resolved."
```

### Normative Language (RFC 2119)

Prescriptive prose that governs behavior benefits from RFC 2119 keywords in **full caps**. This removes ambiguity about whether an instruction is absolute or advisory.

| Keyword | Meaning | Replaces |
|---|---|---|
| **MUST** / **REQUIRED** | Absolute requirement | "always", "make sure", "ensure" |
| **MUST NOT** / **PROHIBITED** | Absolute prohibition | "never", "do not", "don't" |
| **SHOULD** / **RECOMMENDED** | Strong preference; deviation allowed with known tradeoffs | "prefer", "recommend" |
| **SHOULD NOT** / **NOT RECOMMENDED** | Strong discouragement; deviation allowed with known tradeoffs | "avoid", "try not to" |
| **MAY** / **OPTIONAL** | Truly optional | "can", "may", "you could" |

```
Bad:  "Never edit from a grep snippet alone"
Good: "You MUST NOT edit from a grep snippet alone"

Bad:  "Prefer unit tests over mocks"
Good: "You SHOULD prefer unit tests over mocks"
```

Only convert prescriptive prose. Leave factual/descriptive sentences (what a tool returns, what a parameter does), code blocks, examples, and schema definitions as-is.

### Positive Framing

Models process "Always do Y" better than "Don't do X." When negation is necessary, pair it with the positive alternative:

```
Bad:  "Don't use grep via bash"
Good: "ALWAYS use Grep tool for search — NEVER invoke grep via Bash"

Bad:  "Don't guess"
Good: "Use tools to verify; do not guess"
```

### Specificity

Vague instructions produce inconsistent behavior. Quantify constraints wherever possible.

**Role specificity** (effectiveness increases →):

```
"You are a lawyer"
    ↓
"You are a corporate M&A lawyer"
    ↓
"You are General Counsel at a Fortune 500 tech company, 15 years in SaaS licensing"
```

**Constraint specificity**:

```
Bad:  "Keep it short"
Good: "3 bullets, <50 words each"

Bad:  "Be careful with large files"
Good: "Truncated at 50KB or 2000 lines, whichever comes first"
```

### Formatting

```
# H1 for tool/agent name only
## H2 for major sections
### H3 sparingly

- Bullets for unordered lists inside tags
1. Numbers for ordered procedures

| Tables | For | Structured reference data |

`inline code` for commands, paths, parameters, values
```

Always specify language in code blocks.

---

## Technique Reference

### Chain of Thought

**Use when**: Multi-step reasoning, math, analysis, complex decisions.
**Avoid when**: Simple extraction tasks, reasoning models (o1/o3 do internal CoT — explicit CoT conflicts with it, measured -36%).

```xml
<instruction>
Before answering:
1. Identify the core question
2. List relevant constraints
3. Consider 2-3 approaches
4. Select best with rationale

Then provide your answer.
</instruction>
```

**Token-efficient variant** (Chain of Draft): "Think step-by-step, keeping only 5-word notes per step. Output final answer after `####`."

### Few-Shot Examples

**Use when**: Enforcing specific output format, classification, smaller models.
**Avoid when**: Advanced models (Claude 3.5+, GPT-4+) on clear tasks — few-shot adds noise on tasks the model already handles well.

When using: 3-5 diverse examples covering edge cases.

```xml
<example name="simple">
Input: X
Output: Y
</example>

<example name="edge-case">
Input: X'
Output: Y'
</example>
```

### Long Context Handling

The "Lost in the Middle" problem: beginning and end of context retain well; middle degrades 20%+.

1. Place documents at TOP, instructions AFTER
2. Use quote grounding: "Quote relevant passages in `<quotes>`, then analyze"
3. Place critical instructions at START and END
4. For >100K tokens: chunk → process in parallel → synthesize

```xml
<documents>
{{LONG_CONTENT}}
</documents>

<instructions>
1. Find and quote passages relevant to {{QUERY}} in <quotes>
2. Analyze based on quoted evidence in <analysis>
</instructions>
```

### Verification Patterns

Self-correction without external feedback does not work — detection is the bottleneck, not correction.

**Effective:**
```
1. Generate solution
2. Execute verification (tests, lint, typecheck)
3. On failure: analyze error → fix → re-verify
4. Iterate until pass
```

**Ineffective:**
```
1. Generate solution
2. "Critique your solution"      ← detection is the bottleneck
3. "Improve based on critique"   ← feels productive, doesn't help
```

### Prompt Chaining

**Use when**: Single prompt drops steps, distinct phases exist, verification needed between stages.

```
Prompt 1: Analyze → <analysis>
Prompt 2: <analysis> → Plan → <plan>
Prompt 3: <plan> → Execute → <result>
Prompt 4: <result> → Verify → final
```

---

## Anti-Patterns (Measured Degradation)

These patterns have been empirically shown to hurt performance:

| Pattern | Problem |
|---|---|
| "Would you be so kind..." | +perplexity, -4% accuracy |
| "I'll tip $2000" | No improvement, sometimes worse |
| Explicit CoT on reasoning models (o1/o3) | -36%, conflicts with internal reasoning |
| Few-shot on advanced models + clear tasks | Introduces noise/bias |
| "Always end with Progress/Questions" | Degrades task performance |
| "Be efficient with tokens" | Causes premature task abandonment |
| "Don't do X" without positive alternative | "Always do Y" processes better |
| Verbose explanations of obvious concepts | Context bloat; model already knows |
| Self-critique without external feedback | Detection is bottleneck, not correction |
| Critical instructions only in middle | 20%+ degradation vs start/end placement |

---

## Complete Examples

### Tool Documentation

```markdown
# Grep

Fast regex search built on ripgrep.

<instruction>
- Full regex: `log.*Error`, `function\\s+\\w+`
- Filter: `glob` (e.g., `*.js`) or `type` (e.g., `js`, `py`)
- Cross-line: `multiline: true` for patterns like `struct \\{[\\s\\S]*?field`
</instruction>

<output>
Depends on `output_mode`:
- `content`: Lines with paths and line numbers (default limit: 100)
- `files_with_matches`: Paths only
- `count`: Match counts per file

Truncated results reference `artifact://<id>` for full output.
</output>

<critical>
ALWAYS use Grep for search — NEVER invoke `grep` or `rg` via Bash.
</critical>

<example name="regex">
grep {"pattern": "function\\s+\\w+", "glob": "*.ts"}
</example>

<example name="multiline">
grep {"pattern": "struct \\{[\\s\\S]*?field", "multiline": true}
</example>

<avoid>
- Open-ended searches requiring multiple rounds — use Task tool
- Raw bash grep/rg invocation
</avoid>
```

### Agent Definition

```markdown
---
name: explore
description: Fast read-only codebase scout returning compressed context for handoff
tools: read, grep, find, bash
---

<role>File search specialist. Investigate codebase, return structured findings for handoff.</role>

<critical>
READ-ONLY. You are STRICTLY PROHIBITED from:
- Creating, editing, deleting files
- Using redirect operators (>, >>)
- Running state-changing commands (git add, npm install)
</critical>

<strengths>
- Rapid file discovery via find patterns
- Regex search with grep
- Tracing imports and dependencies
</strengths>

<directives>
- Spawn parallel tool calls wherever possible
- Return absolute paths
- Communicate findings directly — do NOT create files
</directives>

<procedure>
1. grep/find to locate relevant code
2. Read key sections (not entire files)
3. Identify types, interfaces, key functions
4. Note dependencies between files
5. Call `submit_result` with findings
</procedure>

<critical>
Read-only. Call `submit_result` when done. This matters.
</critical>
```

---

## Deployment Checklist

Before shipping a system prompt, verify:

- [ ] **Tag hierarchy**: Enforcement level matches content severity?
- [ ] **Critical at edges**: Most important rules at START and END?
- [ ] **Named examples**: All `<example>` tags have descriptive `name` attribute?
- [ ] **Positive framing**: "Do Y" not just "Don't X"?
- [ ] **Direct tone**: No hedging, no filler, urgency where it matters?
- [ ] **Specificity**: Exact formats, limits, constraints — not vague?
- [ ] **Token efficiency**: Each sentence justifies its cost?
- [ ] **Verification**: External feedback loop if correctness matters?
- [ ] **RFC 2119 language**: All prescriptive sentences use MUST/SHOULD/MAY in caps?
- [ ] **Persistence**: "Keep going until complete" for complex tasks?

---

## Quick Reference

### Tag Names

```
Enforcement:  <critical> <prohibited> <caution> <instruction> <conditions> <avoid>
Structure:    <role> <context> <procedure> <directives> <parameters> <output>
Capability:   <strengths> <tools> <operations>
Examples:     <example name="kebab-case-name">
Data:         <environment> <data> <documents>
Special:      <north-star> <stance> <commitment> <field> <protocol>
```

### Task → Technique

| Task | Primary | Secondary |
|---|---|---|
| Simple extraction | Clear constraints | Prefilling |
| Classification | 3-5 examples | XML structure |
| Complex analysis | Structured reasoning | Role + urgency |
| Code generation | SEARCH/REPLACE | Verification loop |
| Long document | Docs at top, quote-then-analyze | XML structure |
| Multi-step workflow | Prompt chaining | Planning instruction |
| Domain expertise | Specific role + credentials | Examples |
