---
name: test-fix
description: >
  Automatically invoke when any test run produces failures.
  Triggers on: test output showing FAIL, test errors, or assertion failures in unit or E2E suites.
  Applies a strict 3-attempt limit per failure to avoid debugging spirals — stops and escalates if not resolved.
  Do NOT wait for user to ask; invoke immediately when tests fail.
---

## When to invoke (auto-trigger)

Invoke automatically whenever:
- A test run outputs one or more FAIL results
- `npm test`, `jest`, or `playwright` exits with a non-zero code due to test failures (not config errors)
- The user says tests are broken or a CI check is red on tests

Do NOT invoke for: build errors, type errors, lint failures — those are not test failures. Hard stop at 3 attempts; do not loop.

# Test Fix with Attempt Budget

## When to Use This Skill

Use this skill when:
- E2E tests are failing
- Unit tests are failing after code changes
- Tests are flaky or intermittent
- Previous fix attempts haven't worked

## Critical Rule

**Maximum 3 fix attempts per test.** After 3 failures, STOP and present options to the user.

## Fix Attempt Checklist

For each failing test, follow this process:

### Attempt 1: Understand and Fix Obvious Issues

1. **Read the test file**
   - Understand what the test is checking
   - Identify all selectors, assertions, and expectations
   - Note any timing assumptions (waits, animations, async operations)

2. **Identify the failure**
   - Read the error message carefully
   - Determine if it's a selector issue, timing issue, or logic issue
   - Check if the test expects specific DOM state

3. **Apply the most obvious fix**
   - Fix broken selectors
   - Add necessary waits for async operations
   - Update assertions to match current behavior (if behavior is correct)

4. **Run the test**
   - Run ONLY this test, not the full suite
   - Document the result: PASS or FAIL (with error)

### Attempt 2: Investigate Deeper

If Attempt 1 failed:

1. **Read related component source code**
   - Find the component(s) being tested
   - Trace selectors to their definitions
   - Look for race conditions or state dependencies

2. **Check for environmental issues**
   - Is the dev server running? (don't restart it)
   - Are there dependencies on other tests?
   - Are there timing issues with animations or transitions?

3. **Apply the fix addressing root cause**
   - Fix race conditions with proper waits
   - Update test to handle async state changes
   - Fix component code if bug is there, not in test

4. **Run the test again**
   - Document the result: PASS or FAIL (with error)

### Attempt 3: Verify Assumptions

If Attempt 2 failed:

1. **Question your assumptions**
   - Is the test checking the right thing?
   - Has the component behavior changed legitimately?
   - Is the test environment set up correctly?

2. **Try alternative approach**
   - Different selector strategy
   - Different waiting strategy
   - Different assertion method

3. **Run the test one final time**
   - Document the result: PASS or FAIL (with error)

## After 3 Failed Attempts

**STOP. Do not attempt a 4th fix.**

Present this summary to the user:

```markdown
## Test Fix Summary: [TEST_NAME]

### Attempts Made
1. **Attempt 1**: [What you tried]
   - Result: FAIL - [error message]
   - Theory: [What you thought was wrong]

2. **Attempt 2**: [What you tried]
   - Result: FAIL - [error message]
   - Theory: [What you thought was wrong]

3. **Attempt 3**: [What you tried]
   - Result: FAIL - [error message]
   - Theory: [What you thought was wrong]

### Root Cause Hypothesis
[Your best understanding of why this test is failing]

### Options for Next Steps

**(a) Skip the test with a TODO**
- Add `.skip` to the test
- Add TODO comment explaining the issue
- Create a GitHub issue to track fixing it later
- Allows PR to move forward

**(b) Rewrite the test with a different approach**
- Current test may have flawed assumptions
- Could use different testing strategy
- Need your input on what approach to take

**(c) Debug manually (what I'd need from you)**
- [Specific information you could provide]
  - Browser DevTools output
  - Component state inspection
  - Manual test of the flow
- [Specific actions you could take]
  - Run test with headed browser
  - Add debug logging to component
  - Verify test environment

### Recommendation
[Which option (a), (b), or (c) seems most appropriate and why]
```

Then wait for the user's decision.

## Success Case

If any attempt succeeds (test passes):
1. Report success
2. Explain what the issue was
3. Explain what fixed it
4. Suggest running the full test suite to ensure no regressions

## Multiple Failing Tests

If multiple tests are failing:
1. Work on them one at a time
2. Each test gets its own 3-attempt budget
3. Don't let failures from one test influence approach to others
4. If 2+ tests fail after 3 attempts each, suggest grouping the summary

## Dev Server Protection

**NEVER:**
- Kill or restart the dev server during test debugging
- Run commands that would stop the dev server
- Start a new dev server if one is already running

**ALWAYS:**
- Verify dev server is running before running tests
- Run tests in a separate process from the dev server
- Ask user if you need to start the dev server

## Notes

- This skill is based on the user's experience with 10+ iteration spirals on E2E tests
- The 3-attempt limit forces acknowledgment when the approach isn't working
- Presenting options empowers the user to make strategic decisions
- Skipping a test is a valid outcome - it's better than wasting hours
