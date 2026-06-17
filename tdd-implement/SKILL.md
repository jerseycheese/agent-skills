---
name: tdd-implement
description: Implements a feature or fix using Test-Driven Development — write failing tests first, then implement just enough to make them pass, then refactor. Keeps tests focused on acceptance criteria rather than implementation details. Use when building something new with TDD, or when the user wants to start from tests rather than code. Trigger on "implement with TDD", "use TDD for this", "write the tests first", "TDD workflow", "red-green-refactor".
---

# TDD Implementation

The goal is to write honest tests that define behavior, implement the minimum code to pass them, then clean up. No rigging tests to pass. No over-engineering beyond what the tests require.

## Step 1: Understand what you're building

Before writing a single test, be clear on:
- What problem does this solve?
- What are the acceptance criteria (from the issue, the user, or both)?
- What already exists in the codebase that you can build on?

```bash
# Discover existing patterns before planning
find src/ -name "*.test.*" -o -name "*.spec.*" | head -5  # How tests are structured here
find src/ -name "*.ts" -o -name "*.tsx" | xargs grep -l "[relevant term]" | head -5
```

## Step 2: Define the MVP test plan

Write down 3-5 tests before touching implementation code. Each test should:
- Map directly to a specific acceptance criterion
- Test user-observable behavior, not internal implementation
- Answer: "Would a user notice if this broke?"

Tests to avoid:
- "renders without crashing"
- Prop-passing tests
- Checking that a function was called (unless it's the actual requirement)
- Exhaustive edge cases not in the acceptance criteria
- Tests that just re-assert a simple layout/visual fix — a `box-sizing`, padding, or margin tweak guards a value, not behavior, and only bloats the suite

### Some fixes don't warrant a test at all

TDD doesn't mean every change gets a spec. When the entire fix is a one-line CSS/layout change, a config tweak, or a copy edit, a dedicated test (Playwright or unit) that pins a single property value is test bloat, not coverage — it makes the suite slower and noisier without catching a real regression class. For these, verify it live (run the app, observe the behavior) and lean on the existing visual-regression / smoke coverage instead of adding a new spec. Say so plainly ("one-line layout fix — no dedicated test") and move on rather than padding the suite to satisfy a checkbox. Reserve new tests for changes with real behavior a user could notice breaking.

Show the user the test plan and confirm it looks right before writing code.

## Step 3: Write the failing tests (red)

Implement the tests. Run them — they should fail. If they pass without any implementation, the tests aren't testing anything real.

```bash
# Run just the new tests
npm test -- --testPathPattern="[feature name]"
# or: npx jest [test file]
# or: whatever the project's test command is
```

Confirm they're red before proceeding.

## Step 4: Implement the minimum to pass (green)

Write only what's needed to make the tests pass. No extra features, no "while I'm here" additions. If you find yourself writing code that isn't required by a test, stop.

Lean on existing code:
- Extend existing components rather than creating new ones
- Reuse utilities that already exist
- Follow patterns established by similar features in the codebase

Run tests after each meaningful chunk of implementation:

```bash
npm test -- --testPathPattern="[feature name]"
```

When all tests pass, stop adding code.

## Step 5: Build verification

```bash
npm run build
# or: npx tsc --noEmit  (TypeScript check without full build)
```

Fix any type errors or build failures before continuing.

## Step 6: Refactor (still green)

With passing tests as a safety net, clean up:
- Replace any placeholder implementations with proper code
- Extract reusable patterns if the same logic appears in multiple places
- Remove anything that was scaffolding, not production code
- Ensure naming is consistent with the rest of the codebase

Run tests after every non-trivial refactor to confirm they're still green.

## Step 7: Cleanup

```bash
# Check for debug statements left behind
git diff --name-only | xargs grep -n "console\." 2>/dev/null
```

Remove:
- `console.log` / debug statements from production code
- Commented-out code blocks
- TODO comments that were resolved
- Unused imports

## Step 8: Final verification

```bash
npm test          # all tests pass
npm run build     # clean build
npm run lint      # no new lint errors
```

If any of these fail, fix the root cause — don't suppress warnings or skip checks.

---

## If a test won't pass

When a test is failing and you're not sure why:

1. Is the implementation wrong? Fix the implementation.
2. Is the test expectation wrong? Fix it only if it doesn't match the acceptance criteria.
3. Is the acceptance criterion itself unclear? Ask before assuming.

Never modify a test just to make it pass. A passing test that doesn't validate the right thing is worse than a failing one — it gives false confidence.

---

## Running the loop with `/goal`

The red-green-refactor cycle is a natural fit for `/goal` once the Step 2 test plan is confirmed: the loop has a crisp, evaluator-checkable completion condition, e.g. `/goal "all MVP tests green, build clean, lint clean, no debug statements left"`. Let it iterate across turns rather than babysitting each red-to-green step — just keep the "never rig a test to pass" rule above as the hard constraint.
