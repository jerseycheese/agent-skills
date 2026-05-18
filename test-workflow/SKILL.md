---
name: test-workflow
description: >
  Automatically run after editing source files to select and run the appropriate test suite.
  Triggers on: any src/ file edit before a commit, or when the user says "run tests", "check tests", or "make sure tests pass".
  Selects unit, E2E, visual regression, or CSS lint based on what changed. Protects running dev servers.
  Do NOT wait for user to ask after a code change — run proactively before committing.
---

## When to invoke (auto-trigger)

Invoke automatically whenever:
- Source files under `src/` have been edited and a commit is about to happen
- The user asks to verify, check, or run tests without specifying which suite
- Tests are mentioned as a blocker ("make sure tests pass before merging")

Do NOT invoke for: documentation-only edits, config-only changes, or when the user explicitly says to skip tests.

# Intelligent Test Workflow Coordinator

## When to Use This Skill

Use this skill when:
- You've made code changes and need to run tests
- Unsure which test suite is appropriate (unit, E2E, visual, all?)
- Want smart test selection based on changed files
- Need coordinated test execution with dev server awareness

## What This Skill Does

Analyzes your changes and intelligently runs the appropriate test suite(s):
- **Unit tests** for logic, utilities, hooks
- **E2E tests** for user flows and integration
- **Visual regression** for UI component changes
- **CSS lint** for style changes
- **Full suite** for widespread changes

## Usage Flow

### Phase 1: Analyze Changes

Detect what changed:
```bash
# Get changed files (staged or unstaged)
git diff --name-only HEAD
git diff --cached --name-only

# Or compare against branch
git diff develop...HEAD --name-only
```

Categorize changes:
```
📝 **Changed Files Analysis**

Component files: 3
- src/components/UserProfile.tsx
- src/components/Dashboard.tsx
- src/components/common/Button.tsx

Test files: 2
- src/components/UserProfile.test.ts
- src/components/Dashboard.test.ts

Style files: 1
- src/styles/dashboard.css

Utility files: 0

E2E test files: 0
```

### Phase 2: Recommend Test Strategy

Based on changes:

```markdown
## Recommended Test Strategy

### Why This Strategy

You've changed:
- 3 component files → Need unit tests + E2E tests
- 1 CSS file → Need CSS lint + visual regression
- Modified existing tests → They'll run automatically

### Recommended Test Suite

**Primary (Must Pass):**
1. Unit tests for changed components
2. CSS lint validation
3. TypeScript type check

**Secondary (Highly Recommended):**
4. E2E tests that use these components
5. Visual regression for Button component

**Optional (If Time Permits):**
6. Full test suite (confidence check)

### Execution Plan

```bash
# Phase 1: Quick validation (< 1 minute)
npm run type-check
npm run lint:css

# Phase 2: Unit tests (1-2 minutes)
npm test -- UserProfile Dashboard Button

# Phase 3: E2E tests (2-3 minutes)
npm run test:e2e:critical

# Phase 4: Visual regression (3-5 minutes)
npm run test:visual -- Button

# Total estimated time: 7-11 minutes
```

Proceed with:
(a) Recommended strategy (all phases)
(b) Quick validation only (phase 1)
(c) Skip E2E/visual (phases 1-2 only)
(d) Full test suite (everything)
(e) Custom (I'll ask which tests)
```

### Phase 3: Dev Server Coordination

**Critical check before running tests:**

```bash
# Check dev server status
DEV_SERVER_PID=$(lsof -ti:3000)

if [ -n "$DEV_SERVER_PID" ]; then
  echo "✅ Dev server running (PID: $DEV_SERVER_PID)"
  echo "Tests will use existing server"
  NEED_SERVER=false
else
  echo "❌ No dev server found"
  echo "E2E and visual tests require dev server"
  NEED_SERVER=true
fi
```

If dev server needed:
```
⚠️ Dev server required for E2E/visual tests

Options:
(a) Start dev server now (I'll wait for it)
(b) Skip E2E/visual tests for now
(c) You start the server, then I'll continue

Which option?
```

**Never:**
- Kill existing dev server
- Start multiple dev servers
- Proceed with E2E/visual tests without dev server

### Phase 4: Execute Tests

Run tests in phases, reporting after each:

#### Phase 1: Quick Validation

```bash
echo "Phase 1: Quick Validation"
echo "========================="

# Type check
npm run type-check
TYPE_CHECK_STATUS=$?

# CSS lint
npm run lint:css
CSS_LINT_STATUS=$?

# ESLint
npm run lint
LINT_STATUS=$?
```

Report:
```markdown
## Phase 1 Results: Quick Validation

✅ Type Check: PASS
✅ CSS Lint: PASS
✅ ESLint: PASS

Time: 32 seconds
```

#### Phase 2: Unit Tests

```bash
echo "Phase 2: Unit Tests"
echo "==================="

# Run specific test files
npm test -- UserProfile Dashboard Button --coverage
UNIT_TEST_STATUS=$?
```

Report:
```markdown
## Phase 2 Results: Unit Tests

✅ UserProfile.test.ts: 12/12 passed
✅ Dashboard.test.ts: 8/8 passed
✅ Button.test.ts: 15/15 passed

Coverage:
- Statements: 87% (target: 80%)
- Branches: 76% (target: 75%)
- Functions: 92% (target: 85%)

Time: 1m 23s
```

#### Phase 3: E2E Tests

```bash
echo "Phase 3: E2E Tests"
echo "=================="

# Verify dev server still running
if ! lsof -ti:3000 > /dev/null; then
  echo "❌ Dev server not running! Cannot proceed."
  exit 1
fi

# Run E2E tests
npm run test:e2e:critical
E2E_STATUS=$?
```

**If E2E test fails:** Apply `/test-fix` skill (3-attempt limit)

Report:
```markdown
## Phase 3 Results: E2E Tests

✅ Login flow: PASS
✅ Dashboard navigation: PASS
⚠️  User profile edit: FAIL (1 test)

Failed Test: user-profile-edit.spec.ts
Error: Timeout waiting for save button

Applied test-fix skill (attempt 1/3)...
Fixed: Added explicit wait for API response
Re-run: ✅ PASS

Time: 2m 45s
```

#### Phase 4: Visual Regression

```bash
echo "Phase 4: Visual Regression"
echo "=========================="

# Run visual tests for changed components
npm run test:visual -- Button
VISUAL_STATUS=$?
```

Report:
```markdown
## Phase 4 Results: Visual Regression

✅ Button component: All snapshots match

Snapshots tested: 8
- Default state
- Hover state
- Disabled state
- Loading state
- Primary variant
- Secondary variant
- Small size
- Large size

Time: 4m 12s
```

### Phase 5: Final Report

```markdown
## Test Workflow Complete

### ✅ All Tests Passed

**Phase 1:** Quick Validation ✅ (32s)
**Phase 2:** Unit Tests ✅ (1m 23s)
**Phase 3:** E2E Tests ✅ (2m 45s)*
**Phase 4:** Visual Regression ✅ (4m 12s)

*1 test fixed using test-fix skill

### 📊 Summary

- **Total time:** 8m 52s
- **Tests run:** 43 tests
- **Tests passed:** 43/43 (100%)
- **Coverage:** 87% statements, 76% branches
- **Visual snapshots:** 8/8 matched

### 🎯 Next Steps

All tests passing! Ready to:
- Commit changes: `git add . && git commit`
- Create PR: `/pr-review-fix-pipeline`
- Push: `git push`

### 💡 Insights

Based on this run:
- Unit tests are fast and comprehensive ✅
- One E2E test needed fixing (race condition with API)
- Visual regression caught no UI breaks ✅
- Consider adding E2E test for error states (gap in coverage)
```

## Test Suite Reference

From your project:

### Unit Tests
```bash
npm test                           # All unit tests
npm test -- [FILE]                 # Specific file
npm run test:coverage              # With coverage
npm run test:prompt-templates      # Specific suite
```

### E2E Tests
```bash
npm run test:e2e:critical          # Critical path only
npm run test:visual                # Visual regression
npm run test:visual:headed         # With browser visible
npm run test:visual:debug          # Debug mode
```

### Linting
```bash
npm run lint                       # ESLint
npm run lint:css                   # Stylelint
npm run type-check                 # TypeScript
```

## Smart Test Selection Rules

### When to Run Unit Tests
- Changed any `.ts`, `.tsx`, `.js`, `.jsx` files
- Modified utilities, hooks, components
- Always run (fast, comprehensive)

### When to Run E2E Tests
- Changed user-facing components
- Modified routes or navigation
- Updated API integration
- Changed authentication logic
- **Only if dev server is running**

### When to Run Visual Regression
- Changed component styles
- Modified CSS files
- Updated design tokens
- Changed layout or spacing
- **Only if dev server is running**

### When to Run CSS Lint
- Modified any `.css` files
- Changed style-related code
- Updated design system

### When to Run Full Suite
- Before merging to main/develop
- After major refactoring
- Before releasing
- Periodic confidence check

## Integration with Other Skills

### With `/test-fix`
When test fails:
```
1. Apply test-fix skill (3-attempt limit)
2. If fails 3 times, flag for review
3. Continue with other tests
4. Report flagged tests in final summary
```

### With `/pr-review-fix-pipeline`
After tests pass:
```
1. Tests validated ✅
2. Create/update PR
3. Run pr-review-fix-pipeline
4. Merge when approved
```

### With `/worktree-enhanced`
In worktree context:
```
1. Verify dev server running
2. Run appropriate test suite
3. Never kill dev server
4. Report results
```

## Error Handling

### Dev Server Not Running (E2E/Visual Needed)
```
❌ Dev server required but not running

Options:
(a) Start dev server now: npm run dev
(b) Skip E2E/visual tests
(c) Exit (you start server first)

Recommendation: (a) - I'll start the server and wait
```

### Test Failure After 3 Attempts
```
⚠️ Test failed after 3 fix attempts

Test: user-profile-edit.spec.ts
Applied: test-fix skill (3 attempts)

Failed fixes:
1. Added wait for button → still timeout
2. Increased timeout → still failed
3. Changed selector → element not found

Flagging for manual review.

Continue with remaining tests? (y/n)
```

### Multiple Test Failures

Work through them one at a time using the `test-fix` skill (3-attempt limit each). If 3+ tests each fail after 3 attempts, present a consolidated summary and ask the user how to proceed — skip with TODOs, rewrite the tests, or investigate a shared root cause.

## Success Metrics

Track these outcomes:
- Test selection accuracy (were recommended tests sufficient?)
- Time saved by smart selection vs. full suite
- Test fix success rate (% fixed within 3 attempts)
- Dev server coordination (no accidental kills)

## Notes

- Intelligent test selection saves significant time — a focused run on changed files beats the full suite for day-to-day work
- Dev server protection prevents a common class of test environment failures
- Integration with the `test-fix` skill prevents debugging spirals
- **macOS tiling window managers**: When running headed visual tests (`test:visual:headed`), tiling window managers (AeroSpace, yabai, Amethyst, etc.) will constrain the browser window's viewport. Float the window after it appears using the WM's float command to prevent viewport-dependent test failures from mismatched breakpoints.
