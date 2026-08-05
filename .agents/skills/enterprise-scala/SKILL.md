---
name: enterprise-scala
description: >
  Enterprise Scala guardrails preventing common AI agent mistakes in production codebases.
  Use whenever working in a Scala codebase — editing .scala files, modifying sbt projects,
  writing traits/classes/objects, reviewing pull requests, or refactoring Scala code.
  Triggers on: any .scala file interaction, build.sbt edits, Scala code review, Scala refactoring,
  or any task involving Scala source code in work repositories.
---

# Enterprise Scala

Conservative rules for AI agents modifying enterprise Scala codebases. Every rule exists because AI agents commonly violate it.

**Core principle**: Match the existing codebase. Every change to shared code must have a concrete consumer that requires it. "Might be useful later" is never valid justification.

## Visibility & Scope

Preserve existing access modifiers. Only widen scope when a concrete callsite demands it.

| Change | Requirement |
|--------|-------------|
| `private` → `protected` | Show the subclass method that calls it |
| `private` → `public` | Show the external class that calls it |
| `protected` → `public` | Show the external class that calls it |
| Adding `override` | Verify parent/trait already defines the method |

- Widening visibility "for testability" requires the test to already exist and fail without the change
- If `main` has `private`, keep `private` unless proven otherwise

## Trait Mixins

Only add `with SomeTrait` when the target type directly uses methods from that trait.

**Before adding a mixin to a parent, verify all three:**

1. No subclass already mixes it in independently (redundant at parent level)
2. The parent itself calls methods from that trait (not just passing through)
3. The mixin does not force cascading changes (`override`, `implicit val`, abstract members)

```scala
// WRONG: Mixin at parent forces cascade, subclasses already have it
trait Parent extends Base with SomeTrait
class Child extends Parent with SomeTrait

// CORRECT: Subclasses mix in what they need
trait Parent extends Base
class Child extends Parent with SomeTrait
```

## Companion Objects

Only create companion objects that contain members. Empty companion objects add noise.

```scala
// WRONG
object MyTrait {}

// CORRECT
object MyTrait {
  val DefaultTimeout = 30.seconds
}
```

## Implicit Declarations

Never add `implicit val` to satisfy a mixin you introduced. If a mixin forces implicit members the class doesn't naturally need, the mixin is wrong — remove the mixin instead.

## Method Signatures

Preserve existing method signatures on shared/public APIs. When modifying a method:

| Change | Requirement |
|--------|-------------|
| Adding a parameter | Show callers that will pass it |
| Removing a parameter | Verify no caller uses it |
| Changing return type | Show all callsites handle the new type |
| Adding type parameters | Show the concrete need |

Default parameters are not a free pass — they still change the binary API.

## Cascading Change Detection

If your change triggers any of these, reassess whether the original change is necessary:

- Adding `override` to satisfy a new parent method
- Adding `implicit val` to satisfy a new mixin requirement
- Implementing abstract members introduced by a new mixin
- Widening visibility on multiple methods to support one change

**One change should not cascade.** If it does, the approach is likely wrong.
