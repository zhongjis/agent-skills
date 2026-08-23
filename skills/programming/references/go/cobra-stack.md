# CLI Stack — cobra + slog + caarlos0/env + signal handling

Canonical CLI patterns, split by topic:

- [Foundation](cobra-foundation.md) — layout, explicit command assembly, injected logging, and server commands.
- [Commands](cobra-commands.md) — arguments, typed flags, environment precedence, versions, and completions.
- [UX and testing](cobra-ux.md) — prompts, progress, output contracts, errors, and command tests.

Construct command trees explicitly; command packages must not register through `init` hooks.
