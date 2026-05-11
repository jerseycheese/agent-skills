---
name: worktree-enhanced
description: >
  Sets up a git worktree for isolated feature work — creates the branch, configures the worktree,
  detects whether a dev server is already running, and handles project-specific setup.
  Trigger on: "create a worktree", "set up a new branch", "start work on issue #X",
  "work on this in isolation", "new worktree for", "start a feature branch",
  "create an isolated environment for", "set up worktree".
---

# Enhanced Worktree Workflow

## When to Use This Skill

Use this skill when:
- Starting work on a new feature or bug fix
- Need isolation from current workspace
- Want parallel development on multiple issues
- Executing implementation plans that require clean state

This skill handles the full worktree setup workflow with:
- Dev server detection and coordination
- Automatic dev server startup option
- Project-specific worktree conventions

## Enhanced Features

### 1. Dev Server Awareness

Before creating worktree, check:
```bash
# Check if dev server is running on port 3000
DEV_SERVER_PID=$(lsof -ti:3000)

if [ -n "$DEV_SERVER_PID" ]; then
  echo "✅ Dev server running (PID: $DEV_SERVER_PID)"
  echo "Worktree will share this dev server"
else
  echo "ℹ️  No dev server detected on port 3000"
  echo "You'll need to start one in the worktree (or main workspace)"
fi
```

### 2. Worktree Creation
```bash
# Standard worktree creation from base skill
git worktree add [path] -b [branch] [base-branch]

# Enhanced: Offer dev server startup
cd [worktree-path]

# Check if package.json exists
if [ -f package.json ]; then
  echo "📦 Found package.json"
  echo ""
  echo "Dev server options:"
  echo "(a) Start dev server now (runs in background)"
  echo "(b) Skip (I'll start it manually later)"
  echo "(c) Use dev server from main workspace"

  # If user chooses (a):
  echo "Starting dev server in background..."
  npm run dev > dev-server.log 2>&1 &
  echo "✅ Dev server started (PID: $!)"
  echo "Logs: tail -f dev-server.log"
fi
```

### 3. Post-Creation Checklist

After worktree created:
```markdown
## Worktree Setup Complete

### ✅ Created
- Path: [worktree-path]
- Branch: [branch-name]
- Base: [base-branch]

### 🚀 Next Steps

#### Before Starting Work
- [ ] Verify dev server is running
      Check: `lsof -ti:3000` or visit http://localhost:3000

- [ ] Install dependencies if needed
      If package-lock.json changed: `npm install`

- [ ] Run tests to establish baseline
      `npm test` to verify clean state

#### During Development
- [ ] NEVER kill or restart dev server
- [ ] Run tests in separate terminal
- [ ] Apply 3-attempt limit for failing tests

#### After Completing Work
- [ ] Run full validation
      `npm run lint && npm run type-check && npm test`

- [ ] Create PR or merge
      Use `/pr-review-fix-pipeline` or manual merge

- [ ] Clean up worktree when done
      `git worktree remove [path]` (only after merged!)

### 🔗 Quick Commands

```bash
# Navigate to worktree
cd [worktree-path]

# Check dev server
lsof -ti:3000

# Start dev server (if needed)
npm run dev

# Run tests (don't kill dev server!)
npm test

# Create PR when ready
gh pr create --fill
```
```

## Dev Server Protection Rules

Critical rules:

**NEVER:**
- Kill the dev server during test runs
- Run commands that stop the dev server
- Restart the dev server unnecessarily
- Start multiple dev server instances

**ALWAYS:**
- Check if dev server is running before tests
- Run tests in separate process from dev server
- Coordinate dev server across worktrees (only one on port 3000)
- Ask user if unclear about dev server state

## Worktree Naming Convention

Naming conventions:

**For issue work:**
```
../[project-name]-issue-[NUMBER]
Branch: issue-[NUMBER]-develop
```

**For feature work:**
```
../[project-name]-feature-[NAME]
Branch: feature/[NAME]
```

**For bug fixes:**
```
../[project-name]-fix-[NAME]
Branch: fix/[NAME]
```

## Integration with Other Skills

### Batch processing

When working on multiple issues in parallel, create a worktree per issue:
```bash
git worktree add ../[project]-issue-123 -b issue-123-develop develop
git worktree add ../[project]-issue-145 -b issue-145-develop develop

# Start dev server in one worktree — others share the same port
```

### With `/test-fix`

In worktree context:
```
1. Verify dev server running
2. Run failing test
3. Apply 3-attempt limit
4. Never kill dev server during debugging
```

### With `/pr-review-fix-pipeline`

After work complete in worktree:
```
1. Push worktree branch
2. Create PR
3. Run `/pr-review-fix-pipeline` on the PR
4. Auto-fixes applied
5. Merge when ready
6. Clean up worktree
```

## Example Workflow

### Starting New Issue

```
User: /worktree-enhanced

Claude: Creating worktree for new work.

What are you working on?
(a) GitHub issue number
(b) Feature name
(c) Bug fix name
(d) Custom branch name

User: a

Claude: Issue number?

User: 123

Claude: [Checks dev server status]

✅ Dev server running on port 3000 (PID: 12345)

Creating worktree:
- Path: ../[project]-issue-123
- Branch: issue-123-develop
- Base: develop

[Creates worktree]

✅ Worktree created

Dev server options:
(a) Use existing dev server from main workspace
(b) Start new dev server in this worktree (will fail - port in use)

User: a

Claude: ✅ Using existing dev server on port 3000

[Presents post-creation checklist]

Ready to start work!
```

### Multiple Worktrees (Batch Processing)

```
User: Create worktrees for issues 123, 145, 167

Claude: Creating 3 worktrees for parallel work...

[Checks dev server]
✅ Dev server running on port 3000

Creating worktrees:
1. ../[project]-issue-123 (issue-123-develop)
2. ../[project]-issue-145 (issue-145-develop)
3. ../[project]-issue-167 (issue-167-develop)

All 3 worktrees will share the dev server on port 3000.

✅ All worktrees created

You can now work on all 3 issues in parallel without conflicts.
```

## Cleanup After Work

When work is merged:
```bash
# Verify branch is merged
git branch --merged | grep issue-123-develop

# Remove worktree
git worktree remove ../[project]-issue-123

# Delete branch (if safe)
git branch -d issue-123-develop
```

**Safety check before removal:**
```
⚠️ Before removing worktree:
- [ ] Verify PR is merged or changes are committed
- [ ] Check for uncommitted changes: `git status`
- [ ] Confirm no valuable work will be lost

Proceed with removal? (y/n)
```

## Notes

- Dev server protection is intentional — running tests while a server is active on the same port risks killing it
- TodoWrite checklist keeps track of worktree state across a session
