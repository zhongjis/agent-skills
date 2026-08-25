# Report Format & Critical Review

Consult this during Phase 5 (verify) and Phase 6 (fix). The report is the deliverable; the checklist is the gate that lets you claim CLEAN.

## Critical-review checklist

Walk every item after the quality gates pass. Any item that flips sends the affected file back to Phase 6.

**Safety**

- [ ] No functional logic accidentally removed.
- [ ] All error handling preserved (especially around I/O, network, external APIs).
- [ ] Type hints intact and correct.
- [ ] Imports still valid.
- [ ] No breaking changes to public APIs.

**Behavior**

- [ ] Return values unchanged (verified by Phase 2 regression tests).
- [ ] Side effects unchanged.
- [ ] Exception behavior unchanged.
- [ ] Edge-case handling preserved.

**Quality**

- [ ] Removed changes are genuinely slop, not intentional patterns.
- [ ] Remaining code follows project conventions.
- [ ] No orphaned code or dead references.
- [ ] Performance changes are obviously equivalent (no subtle algorithm shifts).
- [ ] No new abstractions introduced.

## Output template

```text
AI SLOP REMOVAL REPORT
======================

Scope: [branch diff vs merge-base main / explicit file list]
Files: [N files]
  - path/to/file1.ts
  - path/to/file2.py

Behavior Lock:
  - Existing coverage: [N files already covered]
  - Tests added: [M new regression tests at path/to/test_X.py]
  - Baseline status: GREEN

Cleanup Plan:
  - path/to/file1.ts: [ladder: 1 delete (native) + simplify-in-place] -> [dead code -> complexity -> performance]
  - path/to/file2.py: [ladder: all simplify-in-place] -> [comments -> defensive]

Per-File Results (each cut shows what replaces it):
  path/to/file1.ts
    - Ladder/delete: custom DatePicker (48 lines) -> <input type="date"> (native), flatpickr import removed
    - Dead code: 3 removed (lines X-Y, A-B, C) -> nothing (unreachable)
    - Excessive complexity: 1 simplified (nested ternary at L42 -> if/else)
    - Performance: 1 (line N: list scan -> set lookup, O(n^2)->O(n), behavior identical)
    - Skipped (preserved): 2 (defensive null check at boundary; commented WHY at L88)

  path/to/file2.py
    - Obvious comments: 5 removed -> nothing
    - Over-defensive: 1 simplified (redundant isinstance on typed param)

Quality Gates:
  - Regression tests: PASS (12 tests, 0 failed)
  - Lint: PASS
  - Typecheck: PASS (0 new errors on changed files)
  - Unit/integration tests: PASS (45 tests, 0 failed)
  - Static/security scan: N/A (not configured)

Critical Review:
  - Safety: PASS
  - Behavior: PASS
  - Quality: PASS

Issues Found & Fixed:
  - [None] OR [Issue description -> Fix applied]

Net Impact:
  - LOC: -74 (removed 91, added 17)
  - Dependencies: -1 (flatpickr removed; native <input type="date"> used)
  - Files deleted: 1 (src/date-picker-wrapper.ts — platform-native replacement)

Remaining Risks / Deferred (this section is the debt ledger):
  - [None] OR [e.g., "boundary violation in module X flagged but not refactored — needs human judgment"]
  - `debt:` markers kept this pass: [None] OR [file:line — ceiling -> upgrade trigger]

Final Status: CLEAN | ISSUES FIXED | REQUIRES ATTENTION
```

## Quality assurance rules

- NEVER remove code that serves a functional purpose.
- ALWAYS verify changes compile/parse and pass typecheck.
- ALWAYS preserve test coverage; add tests rather than remove them.
- When a tool call fails, retry with adjusted parameters; never silently skip a failed call, and never claim a gate passed without reading its output.
- If uncertain about a change, keep the original code. The default in doubt is SKIP, not GUESS.
