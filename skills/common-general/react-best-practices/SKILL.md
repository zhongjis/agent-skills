---
name: react-best-practices
description: Provides React patterns for hooks, effects, refs, and component design. Covers escape hatches, anti-patterns, and correct effect usage. Use when reading or writing React components (.tsx, .jsx files with React imports).
upstream: https://github.com/0xBigBoss/claude-code/blob/main/.claude/skills/react-best-practices/SKILL.md
---

# React Best Practices

Use this skill for React component architecture, effects, refs, and hook-level decisions. Load `typescript` alongside it for type modeling, runtime validation, and stricter component contracts.

## Core Principle: Effects Are Escape Hatches

Effects are for synchronizing React with external systems. Most component logic should stay in render logic, memoization, or event handlers.

## Use Effects Only For External Synchronization

- Browser APIs such as WebSocket, IntersectionObserver, and resize listeners
- Third-party libraries that manage state outside React
- Window or document event listeners
- Non-React DOM control such as media players or maps
- Data fetching when framework-level or query-layer solutions are not available

## Do Not Use Effects For Internal Data Flow

### Derived state belongs in render

```tsx
const fullName = `${firstName} ${lastName}`;
```

### Expensive calculations belong in `useMemo`

```tsx
const visibleTodos = useMemo(() => getFilteredTodos(todos, filter), [todos, filter]);
```

### User interactions belong in event handlers

```tsx
function handleBuy() {
  addToCart(product);
  showNotification(`Added ${product.name} to cart`);
}
```

### Reset component state with `key`, not an effect

```tsx
function ProfilePage({ userId }: { userId: string }) {
  return <Profile key={userId} userId={userId} />;
}
```

## Effect Dependency Rules

- Never suppress the hooks linter. Fix the dependency problem instead.
- Use updater functions to remove state dependencies where appropriate.
- Move objects and helper functions inside the effect when they only exist for that effect.
- Wrap non-reactive callbacks with `useEffectEvent` when you need fresh values without reconnecting subscriptions.

```tsx
useEffect(() => {
  const connection = createConnection(serverUrl, roomId);
  connection.connect();
  return () => connection.disconnect();
}, [roomId, serverUrl]);
```

## Cleanup Is Part of the Effect

Every subscription, listener, timer, or connection created in an effect should be cleaned up in the returned function.

```tsx
useEffect(() => {
  function handleScroll() {
    console.log(window.scrollY);
  }

  window.addEventListener("scroll", handleScroll);
  return () => window.removeEventListener("scroll", handleScroll);
}, []);
```

## Refs

- Use refs for mutable values that do not affect rendering.
- Do not read from or write to `ref.current` during render.
- Use callback refs for dynamic lists.
- Use `useImperativeHandle` when exposing a limited imperative API to parents.

## Custom Hooks

- Hooks share logic, not state.
- Name a function `useXxx` only if it actually calls hooks.
- Keep hooks focused on concrete use cases.
- Avoid lifecycle-wrapper hooks that hide dependencies and cleanup.

## Component Design

- Prefer controlled components when parent state needs to drive behavior.
- Prefer composition over prop drilling when children can be passed directly.
- Reach for context only for genuinely shared global state.
- Keep business logic outside JSX-heavy components where possible.

## Decision Guide

1. User interaction: event handler
2. Computed value from props or state: render
3. Expensive derived value: `useMemo`
4. Mutable value without re-render: `useRef`
5. External synchronization: `useEffect` with cleanup

## Related Skills

- **typescript**: Type modeling, exhaustive handling, and boundary validation
- **vitest**: Testing React logic and hooks
- **webapp-testing**: Browser-level verification
