# Codemap Template

The artifact built in Phase 2 of the [refactor workflow](../SKILL.md). It is the definitive map of what the change touches, built from the Phase 1 analysis, and it drives the plan and the risk assessment. Fill every section before planning any edit.

```
## CODEMAP: <target>

### Core files (direct impact)
- path/to/file.ext:L10-L50   — primary definition
- path/to/file2.ext:L25      — key usage

### Dependency graph
<target>
├── imports from:
│   ├── module-a (types)
│   └── module-b (utils)
├── imported by:
│   ├── consumer-1
│   ├── consumer-2
│   └── consumer-3
└── used by:
    ├── handler (direct call)
    └── service (dependency injection)

### Impact zones
| Zone      | Risk   | Files affected | Test coverage |
|-----------|--------|----------------|---------------|
| Core      | HIGH   | 3 files        | 85% covered   |
| Consumers | MEDIUM | 8 files        | 70% covered   |
| Edge      | LOW    | 2 files        | 50% covered   |

### Established patterns (to follow)
- Pattern A: <description> — used in N places
- Pattern B: <description> — established convention
```

## How to fill it

- **Core files** come from LSP go-to-definition on the target plus find-references for its primary usages. List line ranges, not just files.
- **Dependency graph** comes from find-references (imported by / used by) and the target's own imports. Distinguish direct calls from indirect coupling (dependency injection, dynamic dispatch, reflection).
- **Impact zones** rank the blast radius. Pair each zone with its measured or estimated coverage — low-coverage high-risk zones decide the verification strategy in Phase 3 and are the first candidates to gain characterization tests before you touch them.
- **Established patterns** are the conventions the refactor must match, harvested from the "similar patterns" exploration. A refactor that introduces a new idiom where an established one exists is itself a smell.

## Constraints derived from the codemap

Before leaving Phase 2, state each explicitly:

- **MUST follow** — the established patterns above.
- **MUST NOT break** — critical dependencies and any public contract (exported API, wire format, CLI surface).
- **Safe to change** — isolated zones with no external consumers.
- **Requires migration** — breaking changes and the exact consumers that must move with them.
