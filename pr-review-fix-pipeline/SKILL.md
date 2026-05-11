---
name: pr-review-fix-pipeline
description: >
  Autonomous PR review that also applies fixes for non-controversial issues — combines review,
  fix, test, and commit into a single pipeline. Unlike a read-only review, this writes code.
  Only use on feature branches where you're comfortable with automatic edits.
  Trigger on: "review and fix PR", "auto-fix the PR", "clean up this PR automatically",
  "review PR #X and fix issues", "fix whatever's wrong in this PR", "run the review pipeline".
---

# Autonomous PR Review & Fix Pipeline

## When to Use This Skill

Use this skill when:
- You want both review AND automatic fixes in one workflow
- PR has blocking issues that need immediate resolution
- You trust Claude to apply non-controversial fixes (typos, lint errors, obvious bugs)
- You want to minimize back-and-forth between review and implementation

## ⚠️ Important Notes

This is an **autonomous workflow** that will:
- Review the PR
- Apply fixes for blocking issues
- Run tests and lint
- Commit changes
- Push to the PR branch

**Only use this when:**
- You're comfortable with Claude modifying code without asking
- The PR is on a feature branch (not main/develop)
- You can review the resulting diff before merging

## Pipeline Steps

### Step 1: Fetch and Analyze

1. **Get PR information**
   ```bash
   gh pr view [NUMBER] --json headRefName,baseRefName,title,body
   ```

2. **Fetch the diff (never cached)**
   ```bash
   gh pr diff [NUMBER]
   ```

3. **Checkout the PR branch**
   ```bash
   git fetch origin [HEAD_REF]
   git checkout [HEAD_REF]
   ```

### Step 2: Categorize Issues

Analyze every file change and categorize issues:

- **[BLOCKING]**: Must be fixed before merge
  - Bugs and logic errors
  - TypeScript errors
  - Breaking changes
  - Security issues
  - Missing error handling

- **[RECOMMENDATION]**: Should be fixed but not critical
  - Performance improvements
  - Better patterns available
  - Code style issues

- **[NIT]**: Nice-to-have improvements
  - Whitespace, formatting
  - Comment improvements
  - Variable naming

### Step 3: Auto-Fix Blocking Issues

For each **[BLOCKING]** issue:

1. **Create a Task sub-agent** to implement the fix
   ```
   Task: Fix [specific issue]
   Context: [issue description and location]
   Constraint: Only fix this specific issue, don't refactor
   ```

2. **Wait for sub-agent completion** before proceeding to next issue

3. **Track fixes** with TodoWrite for visibility

### Step 4: Run Validation (with Dev Server Protection)

**Critical**: Verify dev server status BEFORE running tests

```bash
# Check if dev server is already running
lsof -ti:3000 || echo "No dev server"

# If dev server needed but not running, start it in background
# If dev server already running, leave it alone

# Run validation suite
npm run lint
npm run type-check
npm run lint:css
npm test
```

### Step 5: Handle Test Failures

If tests fail after fixes:

1. **Apply 3-attempt limit per test** (use test-fix skill principles)
2. **If test fails after 3 attempts**, flag it for human review
3. **Continue with other tests** (don't block entire pipeline)

### Step 6: Commit and Push

1. **Create a single commit** with all fixes
   ```bash
   git add -u
   git commit -m "fix: auto-applied blocking issue fixes from code review

   - [list of fixes applied]

   Applied via autonomous PR review pipeline"
   ```

2. **Push to PR branch**
   ```bash
   git push origin [HEAD_REF]
   ```

### Step 7: Report Results

Present this summary:

```markdown
## Autonomous PR Review & Fix Pipeline Results

### Original Review Findings

#### 🔴 Blocking Issues (Auto-Fixed)
[List each blocking issue and how it was fixed]

#### 🔴 Blocking Issues (Flagged for Human Review)
[List issues that couldn't be auto-fixed]

#### 🟡 Recommendations (Not Auto-Fixed)
[List recommendations for user to consider]

#### 🟢 What Looks Good
[Positive observations]

### Fixes Applied

**Commit**: [commit hash]
**Files Modified**: [list of files]

[Detailed list of what was changed]

### Final CI Status

- **Lint**: [PASS/FAIL]
- **Type Check**: [PASS/FAIL]
- **CSS Lint**: [PASS/FAIL]
- **Tests**: [PASS/FAIL - with details on any flagged tests]

### Next Steps

- [ ] Review the auto-applied fixes: `git diff [BASE]..[HEAD]`
- [ ] Address flagged blocking issues (if any)
- [ ] Consider recommendations
- [ ] Merge when ready
```

## Safety Guardrails

### Never Auto-Fix

Do NOT automatically fix:
- Architectural decisions
- API contract changes
- Feature behavior changes
- Test expectations (unless test is clearly wrong)
- Anything that changes user-facing behavior

If in doubt, flag for human review instead of auto-fixing.

### Dev Server Protection

**NEVER:**
- Kill or restart the dev server
- Run commands that interfere with running processes
- Assume dev server state

**ALWAYS:**
- Check if dev server is running before running tests
- Run tests in separate process
- Ask user if you need to start dev server

### Commit Safety

**Before committing:**
- Verify no merge conflict markers
- Verify no debug code introduced
- Verify all auto-fixes are intentional
- Run full lint and test suite

## Rollback Instructions

If the pipeline produces bad results:

```bash
# Reset to state before pipeline ran
git reset --hard origin/[HEAD_REF]

# Or revert the commit
git revert [COMMIT_HASH]
git push origin [HEAD_REF]
```

## Example Usage

User says: "Auto-review and fix PR #123"

Pipeline:
1. Fetches PR #123 diff
2. Finds 5 blocking issues: 3 lint errors, 1 TypeScript error, 1 missing await
3. Spawns 5 Task agents to fix each issue in parallel
4. After fixes, runs lint/test suite
5. All tests pass
6. Commits: "fix: auto-applied blocking issue fixes from code review"
7. Pushes to PR branch
8. Reports what was fixed and final status

Total time: 3-5 minutes (vs. 15-30 minutes of back-and-forth)

## When NOT to Use This Skill

Don't use this skill if:
- PR changes architectural patterns
- PR has controversial design decisions
- You want to review fixes before they're applied
- You're working on main/develop branch directly

In those cases, do a manual review instead.

## Notes

- Uses Task tool for parallel sub-agents (Claude Code's native parallelization)
- Combines review, implementation, and CI checking into one atomic operation
