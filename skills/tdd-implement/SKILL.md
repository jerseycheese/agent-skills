---
name: tdd-implement
description: >
  Implements a feature or fix test-first: write the few failing tests that would catch a real
  regression, make them pass with the least code, then refactor. Plans only essential tests,
  never one per criterion by default. Trigger on:
  "implement with TDD", "write the tests first", "TDD workflow", "red-green-refactor".
---

# TDD Implementation

The goal is to write honest tests that define behavior, implement the minimum code to pass them, then clean up. No rigging tests to pass. No over-engineering beyond what the tests require.

## Step 1: Understand what you're building

Before writing a single test, be clear on:
- What problem does this solve?
- What are the acceptance criteria (from the issue, the user, or both)?
- What already exists in the codebase that you can build on?

- How does this project run its tests, build, and lint? Check its manifest, CI config, and docs. Commands below are examples, so use the project's own and skip any it doesn't define. Stick to one-shot commands, never a dev server or watcher.

```bash
# Discover existing patterns before planning. Extend the pattern for the project's layout.
git ls-files | grep -E '(^|/)(tests?|__tests__)/|[._](test|spec)\.|(^|/)test_'  # How tests are structured here
git grep -n "[relevant term]"
```

No test files here doesn't mean there are no tests. The pattern may have missed the project's layout, so check the test command before planning from scratch.

## Step 2: Define the MVP test plan

Plan the fewest tests that would catch this change breaking: one per distinct behavior the change adds or alters, so a fix plus its new error path is two. Usually that's one or two; more than three needs a reason you can name. A bug fix always gets the regression test that would have caught the bug. Zero is valid only for a copy edit, a config tweak, or a one-line layout fix (see "Some fixes don't warrant a test at all" below). The repo's own test rules win where they're stricter.

A test is essential only if both hold:
- It fails when the behavior it covers is reverted. If it would pass on the old code, it tests nothing new.
- It guards behavior a user or a caller would notice breaking. Name that breakage in one line; if you can't, cut the test.

Plan per behavior, not per acceptance criterion. When one test covers three criteria, write one test. Put edge cases in only when the issue names them or the bug was one.

Before writing any test, run the cut check on the plan: for each test, ask "if I delete this, what bug could ship?" No concrete answer means delete it from the plan.

Tests to avoid:
- "renders without crashing"
- Prop-passing tests
- Checking that a function or mock was called (unless that call is the actual requirement)
- Re-checking what the type system or a schema already enforces
- Pinning a constant, a label, or copy text. A default or fallback that drives behavior is behavior, and a bug in one gets a regression test.
- Several tests that run the same code path with trivially different inputs. Use one, or one table-driven test.
- Testing the framework or a library instead of your code
- Snapshot tests of whole outputs
- Exhaustive edge cases not in the acceptance criteria
- Tests that just re-assert a simple layout/visual fix — a `box-sizing`, padding, or margin tweak guards a value, not behavior, and only bloats the suite

### Some fixes don't warrant a test at all

TDD doesn't mean every change gets a spec. When the entire fix is a one-line CSS/layout change, a config tweak, or a copy edit, a dedicated test (Playwright or unit) that pins a single property value is test bloat, not coverage — it makes the suite slower and noisier without catching a real regression class. For these, verify it live (run the app, observe the behavior) and lean on the existing visual-regression / smoke coverage instead of adding a new spec. Say so plainly ("one-line layout fix — no dedicated test") and move on rather than padding the suite to satisfy a checkbox. Reserve new tests for changes with real behavior a user could notice breaking.

Show the user the test plan and confirm it looks right before writing code.

## Step 3: Write the failing tests (red)

Implement the tests. Run them — they should fail. If they pass without any implementation, the tests aren't testing anything real.

```bash
# Run just the new tests with the project's test command. For example:
npm test -- [test file]
pytest [test file]
go test ./[package] -run [TestName]
```

Confirm they're red before proceeding. Read the output as well as the exit code, because some runners exit 0 when a script fails to load.

## Step 4: Implement the minimum to pass (green)

Write only what's needed to make the tests pass. No extra features, no "while I'm here" additions. If you find yourself writing code that isn't required by a test, stop.

Lean on existing code:
- Extend existing components rather than creating new ones
- Reuse utilities that already exist
- Follow patterns established by similar features in the codebase

Run the new tests with the same command after each meaningful chunk of implementation.

When all tests pass, stop adding code.

## Step 5: Build verification

Run the project's one-shot build or type-check (`npm run build`, `npx tsc --noEmit`, `cargo check`, and `mypy .` are examples). Skip this step if it defines neither.

Fix any type errors or build failures before continuing.

## Step 6: Refactor (still green)

With passing tests as a safety net, clean up:
- Replace any placeholder implementations with proper code
- Extract reusable patterns if the same logic appears in multiple places
- Remove anything that was scaffolding, not production code
- Match the codebase's naming

Run tests after every non-trivial refactor to confirm they're still green.

## Step 7: Cleanup

```bash
# Check changed and new files for debug statements left behind. Add the language's own debug calls.
{ git diff --name-only HEAD; git ls-files -o --exclude-standard; } | tr '\n' '\0' | xargs -0 grep -nE 'console\.log|debugger|breakpoint\(\)' 2>/dev/null
```

Remove:
- Debug statements from production code
- Commented-out code blocks
- TODO comments that were resolved
- Unused imports

## Step 8: Final verification

Run the project's own checks, and skip any it doesn't define:

- The full test suite passes (`npm test`, `pytest`, `go test ./...`, or a script of its own).
- The build is clean, using the same command as Step 5.
- The linter reports no new errors (`npm run lint`, `ruff check`, `golangci-lint run`).

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

The red-green-refactor cycle is a natural fit for `/goal` once the Step 2 test plan is confirmed: the loop has a crisp, evaluator-checkable completion condition, e.g. `/goal "all MVP tests green, the project's build and lint clean, no debug statements left"`. Let it iterate across turns rather than babysitting each red-to-green step — just keep the "never rig a test to pass" rule above as the hard constraint.
