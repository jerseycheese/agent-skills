---
name: ci-fix-with-memory
description: >
  Automatically invoke when CI checks fail on a PR. Do NOT wait for the user to ask; invoke as
  soon as a CI failure is confirmed. Reads session handoffs and a known-issues log so failed fixes
  aren't retried. Trigger on: "CI is failing", "red checks", "GitHub Actions failed", "fix CI".
---

## When to invoke (auto-trigger)

Invoke automatically whenever:
- The user mentions CI is failing, red, or blocked
- `gh pr checks` shows a failure
- A push triggers a failed workflow run

Do NOT invoke for: local test failures (use `test-fix` instead), lint-only failures with an obvious single-line fix.

# Self-Healing CI Pipeline with Handoff Memory

## When to Use This Skill

Use this skill when:
- CI checks are failing on a PR
- You want to avoid repeating previously failed fix attempts
- You need systematic CI debugging with context preservation
- Multiple CI check types are failing (lint, tests, build, etc.)

## Critical Setup

This skill requires a `.handoff/` directory structure:

```
.handoff/
├── latest.md          # Most recent session handoff
└── known-issues.md    # Persistent log of failed approaches
```

If these don't exist, the skill will create them on first run.

## Pipeline Steps

### Phase 1: Ingest Context (Before ANY Action)

1. **Read the handoff file**
   ```bash
   cat .handoff/latest.md
   ```

   This contains:
   - What was tried in the previous session
   - What worked and what didn't
   - Current branch state
   - Open questions or blockers

2. **Read the known issues log**
   ```bash
   cat .handoff/known-issues.md
   ```

   This contains:
   - Approaches that have been tried and failed
   - Specific commands or fixes that don't work
   - Patterns to avoid
   - Environmental quirks

3. **Acknowledge context**
   Present a brief summary:
   ```markdown
   ## Context Loaded

   ### From Previous Session
   [Key points from latest.md]

   ### Known Failed Approaches
   [List from known-issues.md]

   ### Starting Fresh Investigation
   ```

### Phase 1b: Read the project's scripts

Before running anything, list the scripts the project defines (`scripts` in `package.json`, or the repo's equivalent such as a Makefile or `pyproject.toml`). Map lint, lint-fix, test, and build to the script that does each job. Script names differ between projects, so every command in this skill is an example. If a job has no matching script, skip that phase and say so in the report. Never run a script name you haven't confirmed exists.

### Phase 2: Get Current CI Status

1. **Fetch current CI check status**
   ```bash
   gh pr checks [PR_NUMBER]
   ```

2. **For each failing check, get its log**
   ```bash
   # Find the failing run's ID (the number in the check's URL, or from this list)
   gh run list --branch [BRANCH] --limit 5

   # Print only the failed steps' output
   gh run view [RUN_ID] --log-failed
   ```

3. **Create TodoWrite checklist**
   ```
   - [ ] Fix lint failures
   - [ ] Fix TypeScript errors
   - [ ] Fix test failures
   - [ ] Fix build errors
   ```

### Phase 3: Cross-Reference Against Known Issues

For each failure:

1. **Check if this exact error was seen before**
   - Search known-issues.md for error message
   - Search latest.md for previous attempts

2. **If found in known-issues.md**
   ```markdown
   Known Issue Detected

   Failure: [error message]
   Previously Tried: [approach from known-issues.md]
   Result: Failed

   Skipping this approach. Trying alternative: [different approach]
   ```

3. **If NOT found**
   ```markdown
   New failure detected: [error message]
   No prior attempts recorded.
   Proceeding with standard fix approach.
   ```

### Phase 4: Fix Failures (Priority Order)

**Fix in this priority order:**

1. **Build failures first** (they may cascade to other failures)
2. **Lint failures second** (fix all in one pass)
3. **Test failures third** (individual tests, one at a time)
4. **Type errors fourth** (often caused by other fixes)

**For Each Failure Type:**

Script names below are examples. Substitute the project's own from Phase 1b, and skip any step it has no script for.

#### Lint Failures
```bash
# Get all lint errors
npm run lint 2>&1 | tee lint-errors.txt

# Apply fixes
npm run lint:fix
npm run lint:css:fix

# Verify
npm run lint && npm run lint:css
```

**Update checklist**: Mark lint item as done if passed

#### Test Failures
```bash
# Get the real failures: run the files CI named in its log (Phase 2),
# or the whole suite if the log doesn't name them
npm test -- [failing-test-files] 2>&1 | tee test-failures.txt

# Fix one test at a time
npm test -- [specific-test-file]

# Apply 3-attempt limit per test (use test-fix principles)
```

**Update checklist**: Mark each test as done when fixed

#### Build Failures
```bash
# Get build errors
npm run build 2>&1 | tee build-errors.txt

# Fix errors
[apply fixes]

# Verify
npm run build
```

**Update checklist**: Mark build as done if passed

### Phase 5: Dev Server Protection

**Critical checks before running tests:**

Find this checkout's dev-server port first: the dev server's entry in `.claude/launch.json`, the port in its dev script, or a `PORT` in its env. Don't assume 3000; in a worktree or another app, 3000 is usually someone else's server.

```bash
# PORT comes from the project (see above). No fallback: a guess reports the wrong server.
if [ -z "$PORT" ]; then
  echo "No dev-server port found for this checkout"
elif DEV_SERVER_PID=$(lsof -ti:"$PORT"); [ -n "$DEV_SERVER_PID" ]; then
  echo "Dev server running on port $PORT (PID: $DEV_SERVER_PID)"
  echo "Tests will use existing server"
else
  echo "No dev server on port $PORT"
  echo "Ask user: Should I start dev server?"
fi
```

**Never:**
- Kill the dev server
- Restart the dev server
- Run commands that interfere with its port

### Phase 6: Commit Safety

**Before committing, verify:**

```bash
# Check for merge conflict markers
git diff --check

# Check the changed lines for common mistakes
git diff -U0 | grep -E '^\+.*(<<<<<<<|>>>>>>>)' && echo "Merge conflicts found" || echo "No merge conflicts"
git diff -U0 | grep -E '^\+.*console\.log' && echo "Debug code found" || echo "No debug code"
git diff -U0 | grep -E '^\+.*debugger' && echo "Debugger statements found" || echo "No debugger"
```

**If all checks pass:**

```bash
git add -u
git commit -m "fix: resolve CI failures

[List of what was fixed]"

git push origin [BRANCH]
```

### Phase 7: Update Memory Files

1. **Update .handoff/latest.md**
   ```markdown
   # Session Handoff: [DATE]

   ## PR Context
   - PR #[NUMBER]: [TITLE]
   - Branch: [BRANCH_NAME]
   - Status: [CI status after fixes]

   ## What Was Done
   - [List of fixes applied]
   - [Commands run]
   - [Tests that passed/failed]

   ## What Worked
   - [Successful approaches]

   ## What Didn't Work
   - [Failed approaches - add to known-issues.md]

   ## Current State
   - Lint: [PASS/FAIL]
   - Tests: [PASS/FAIL]
   - Build: [PASS/FAIL]
   - Type Check: [PASS/FAIL]

   ## Open Questions
   - [Any blockers or unclear issues]

   ## Next Steps
   - [What should happen next]
   ```

2. **Update .handoff/known-issues.md**
   ```markdown
   # Known Issues Log

   ## [DATE] - [Issue Category]

   **Error**: [exact error message]
   **Attempted Fix**: [what was tried]
   **Result**: Failed
   **Why It Failed**: [explanation]
   **Alternative Approach**: [what to try instead]

   ---

   [Previous entries...]
   ```

### Phase 8: Report Status

Present final summary:

```markdown
## CI Fix Pipeline Results

### Context Used
- Loaded previous session handoff
- Cross-referenced [N] known failed approaches
- Avoided repeating [specific approaches]

### Fixes Applied
- Fixed: [List of successful fixes]
- Failed: [List of failed fixes with reasons]
- Skipped: [List of skipped issues]

### Final CI Status
- **Lint**: [PASS/FAIL]
- **Type Check**: [PASS/FAIL]
- **Tests**: [PASS/FAIL - with count]
- **Build**: [PASS/FAIL]

### Memory Updated
- Updated .handoff/latest.md with session details
- Added [N] new entries to .handoff/known-issues.md

### Next Steps
[What user should do next]

### Handoff for Next Session
[Key context to carry forward]
```

## Example Known Issues Log Entry

```markdown
## 2025-01-15 - E2E Test Timeout

**Error**: `Timeout waiting for element: [data-testid="submit-button"]`
**Attempted Fix**: Added `page.waitForSelector('[data-testid="submit-button"]', { timeout: 10000 })`
**Result**: Failed - timeout still occurred
**Why It Failed**: Button exists but is covered by a loading overlay during test
**Alternative Approach**: Wait for overlay to disappear before clicking
**Reference**: See `.handoff/latest.md` from 2025-01-15 session

---

## 2025-01-12 - Lint Rule Conflict

**Error**: `Unexpected var, use let or const instead (no-var)`
**Attempted Fix**: Ran `eslint --fix` to auto-convert var to let
**Result**: Failed - introduced scope bugs in loop
**Why It Failed**: var has function scope, let has block scope - not always safe to auto-convert
**Alternative Approach**: Manually review each var and decide let vs const based on reassignment

---
```

## Example Handoff Entry

```markdown
# Session Handoff: 2025-01-15 14:30

## PR Context
- PR #89: Fix async form submission race condition
- Branch: `fix/form-submit-timing`
- Status: CI failing (2 of 4 checks)

## What Was Done
- Fixed lint errors in `SubmitButton.tsx` and `FormContext.tsx`
- Attempted to fix E2E test `form-submit.spec.ts` (3 attempts, failed)
- Updated TypeScript types for form state

## What Worked
- Lint fixes: Changed `var` to `const` manually (not auto-fix)
- Type fixes: Added proper typing for `FormState` interface

## What Didn't Work
- E2E test still timing out on submit button click
- Root cause: Loading overlay covers button before it becomes interactive
- Tried: Waiting for selector (failed), adding explicit delay (failed), clicking with force (failed)

## Current State
- Lint: PASS
- Tests: FAIL (1 test: form-submit.spec.ts)
- Build: PASS
- Type Check: PASS

## Open Questions
- Should we dismiss the overlay programmatically in test setup?
- Is this a timing issue in the component or the test?

## Next Steps
- May need browser DevTools inspection to confirm overlay z-index
- Consider checking if overlay has a data-testid we can wait on
```

## Success Metrics

Track these outcomes:
- Number of repeat fix attempts avoided
- Time saved by checking known-issues log first
- How many handoffs actually helped next session
- Patterns discovered through known-issues tracking

## Notes

- Addresses context loss between sessions (cached state, unknown file locations)
- Prevents "merge-conflict-markers-left-in-files" class of errors
- Known-issues log becomes useful project documentation over time
