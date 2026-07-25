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
- Local env file propagation from the main checkout
- Automatic dev server startup option
- Project-specific worktree conventions

## Enhanced Features

### 1. Dev Server Awareness

Every worktree gets its own dev-server port — never assume port 3000 belongs to the worktree you're in. If the project has adopted the per-worktree port pattern (`scripts/worktree-port.cjs`, installed by `install-worktree-port.sh`), resolve the port before checking it:

```bash
# Resolve this checkout's port: the per-worktree script if the project has it
# installed, else the port recorded in .claude/launch.json, else 3000 (the
# main-checkout default)
if [ -f scripts/worktree-port.cjs ]; then
  PORT="$(node scripts/worktree-port.cjs)"
else
  PORT="$(node -p "require('./.claude/launch.json').configurations[0].port" 2>/dev/null || echo 3000)"
fi

DEV_SERVER_PID=$(lsof -ti:"$PORT")

if [ -n "$DEV_SERVER_PID" ]; then
  echo "Dev server already running on port $PORT (PID: $DEV_SERVER_PID)"
else
  echo "No dev server running on port $PORT yet"
fi
```

If the project has no per-worktree port scripts yet, run `install-worktree-port.sh <project-dir>` (in `shared/Development/tools/dev-server/`) before creating more worktrees — otherwise every worktree's `npm run dev` fights over the same port.

### 2. Worktree Creation
```bash
# Standard worktree creation from base skill
git worktree add [path] -b [branch] [base-branch]

# Copy ignored local env files from the main checkout, if present. These files
# stay untracked, but worktrees need the same server-side keys and feature flags.
main_worktree="$(git worktree list --porcelain | awk '
  /^worktree / { path = substr($0, 10) }
  /^branch / && $2 !~ /worktrees/ {
    print path
    exit
  }
')"

for env_file in .env.local .env.development.local .env.test.local; do
  if [ -n "$main_worktree" ] &&
     [ "$main_worktree" != "[worktree-path]" ] &&
     [ -f "$main_worktree/$env_file" ] &&
     [ ! -f "[worktree-path]/$env_file" ]; then
    cp "$main_worktree/$env_file" "[worktree-path]/$env_file"
    echo "Copied $env_file from main checkout"
  fi
done

# Enhanced: Offer dev server startup
cd [worktree-path]

# Check if package.json exists
if [ -f package.json ]; then
  echo "Found package.json"
  echo ""
  echo "Dev server options:"
  echo "(a) Start dev server now (runs in background, on this worktree's own port)"
  echo "(b) Skip (I'll start it manually later)"
  echo "(c) Just point the browser at the main workspace's already-running server"

  # If user chooses (a):
  echo "Starting dev server in background..."
  npm run dev > dev-server.log 2>&1 &
  echo "Dev server started (PID: $!)"
  echo "Logs: tail -f dev-server.log"
fi
```

### 3. Post-Creation Checklist

After worktree created:
```markdown
## Worktree Setup Complete

### Created
- Path: [worktree-path]
- Branch: [branch-name]
- Base: [base-branch]

### Next Steps

#### Before Starting Work
- [ ] Verify dev server is running
      Resolve this worktree's own port first: `node scripts/worktree-port.cjs`
      (if installed) or the port in `.claude/launch.json`, then `lsof -ti:$PORT`
      or visit `http://localhost:$PORT`

- [ ] Install dependencies if needed
      If package-lock.json changed: `npm install`

- [ ] Confirm ignored local env files are present
      Copy `.env.local` / `.env.*.local` from the main checkout if missing;
      never commit them. For Narraitor, `GEMINI_API_KEY` must be available
      server-side before testing real generation.

- [ ] Run tests to establish baseline
      `npm test` to verify clean state

#### During Development
- [ ] NEVER kill or restart another worktree's dev server
- [ ] Run tests in separate terminal
- [ ] Apply 3-attempt limit for failing tests

#### After Completing Work
- [ ] Run full validation
      `npm run lint && npm run type-check && npm test`

- [ ] Create PR or merge
      Use `pr-review-fix-pipeline` or manual merge

- [ ] Clean up worktree when done
      `git worktree remove [path]` (only after merged!)

### Quick Commands

```bash
# Navigate to worktree
cd [worktree-path]

# Check this worktree's dev server (resolve $PORT first, see above)
lsof -ti:$PORT

# Start dev server (if needed) — resolves this worktree's own port automatically
npm run dev

# Run tests (don't kill the dev server!)
npm test

# Create PR when ready
gh pr create --fill
```
```

## Dev Server Protection Rules

Critical rules:

**NEVER:**
- Kill another worktree's dev server during test runs
- Run commands that stop a dev server you didn't start
- Restart a dev server unnecessarily
- Force multiple worktrees onto the same port

**ALWAYS:**
- Resolve this worktree's own port before checking or starting anything
- Run tests in a separate process from the dev server
- Verify changes against the server for THIS worktree, not a stale one from the main tree or another worktree
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

# Each worktree's port is derived from its own path — start a dev server in
# either or both, no coordination needed
```

### With `test-fix`

In worktree context:
```
1. Verify dev server running (this worktree's own port)
2. Run failing test
3. Apply 3-attempt limit
4. Never kill the dev server during debugging
```

### With `pr-review-fix-pipeline`

After work complete in worktree:
```
1. Push worktree branch
2. Create PR
3. Run `pr-review-fix-pipeline` on the PR
4. Auto-fixes applied
5. Merge when ready
6. Clean up worktree
```

## Example Workflow

### Starting New Issue

```
User: set up a worktree for issue 123

Claude: Creating worktree for new work.

What are you working on?
(a) GitHub issue number
(b) Feature name
(c) Bug fix name
(d) Custom branch name

User: a

Claude: Issue number?

User: 123

Claude: [Checks main checkout's dev server]

Main checkout dev server running on port 3000 (PID: 12345)

Creating worktree:
- Path: ../[project]-issue-123
- Branch: issue-123-develop
- Base: develop

[Creates worktree, copies .env.local from the main checkout]

Worktree created. This worktree's own port: 3247 (derived from its path).

Dev server options:
(a) Start a dev server for this worktree on port 3247
(b) Just use the main checkout's server on 3000 for now

User: a

Claude: Dev server started on port 3247 (PID: 12401)

[Presents post-creation checklist]

Ready to start work!
```

### Multiple Worktrees (Batch Processing)

```
User: Create worktrees for issues 123, 145, 167

Claude: Creating 3 worktrees for parallel work...

Creating worktrees:
1. ../[project]-issue-123 (issue-123-develop) -> port 3247
2. ../[project]-issue-145 (issue-145-develop) -> port 3512
3. ../[project]-issue-167 (issue-167-develop) -> port 3089

Each worktree's port is derived from its own path, so there's no collision
and no coordination needed — start a dev server in any or all of them.

All 3 worktrees created.

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
Before removing worktree:
- [ ] Verify PR is merged or changes are committed
- [ ] Check for uncommitted changes: `git status`
- [ ] Confirm no valuable work will be lost

Proceed with removal? (y/n)
```

## Notes

- Dev server protection is intentional — killing another worktree's server mid-test throws away its state and can mask real failures. Always verify against the port for the worktree you're actually in, not whatever happens to be running on 3000.
- TodoWrite checklist keeps track of worktree state across a session
