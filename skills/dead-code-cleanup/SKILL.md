---
name: dead-code-cleanup
description: >
  Finds and removes dead or orphaned code, files, and tests in any stack. Validates that code is
  truly unused before deleting anything. Trigger on: "remove dead code", "find unused exports",
  "what code can we delete", "prune the repo".
---

# Dead Code Cleanup

## Overview

Finds code and files whose subject is gone or that nothing uses, and removes them only after proving nothing depends on them. Validate first, delete second.

This skill works in any language. Commands and names below are examples, so swap in the project's own.

Trivial or weak tests and stories (snapshot-only, `renders without crashing`, `toBeDefined`, duplicates, negative reference scans) belong to `test-reaper`. This skill only removes a test or story when its subject is gone (an orphan).

## What Qualifies

- **Modules and components never used** - nothing imports, loads, or instantiates them
- **Unused functions, classes, and constants** - no consumers
- **Unused types and interfaces** - definitions with no references
- **Duplicate implementations** - several versions of the same functionality
- **Empty functions** - do nothing or only return a default
- **Commented-out code** - blocks that have been commented out
- **Debug code** - debug prints, debug flags, temporary utilities
- **Orphans** - tests, stories, fixtures, and assets for something deleted or moved

## Detection

### Phase 1: Find candidates

Start with the project's own tooling. Check its manifest and docs for a dead-code or unused-import check, then consider the usual tool for the stack (`knip` for JS/TS, `vulture` for Python, `deadcode` for Go, the compiler's unused warnings where it has them). These tools report candidates, not proof, so Phase 2 still applies.

Fall back to a search where no tool covers the code:

```bash
# References to a candidate, across every tracked file
git grep -nw "candidate_name"

# Test, story, and fixture files whose subject may be gone (extend for the project's layout)
git ls-files | grep -E '(^|/)(tests?|__tests__|fixtures)/|[._](test|spec|stories)\.|(^|/)test_'

# Debug leftovers (a print is often intentional, so read each hit)
git grep -nE 'console\.log|debugger|breakpoint\(\)|DEBUG *= *[Tt]rue'
```

### Phase 2: Validate before marking dead

For each candidate, check all of these:

1. No direct imports or calls
2. No dynamic loading (lazy imports, reflection, plugin registries, names built from strings)
3. Not re-exported or part of a public API
4. Not used in type definitions
5. Not referenced in config or build files (manifests, framework config, CI, scripts)
6. Not used by a test, story, or tool that should stay
7. Not referenced in docs
8. No string references, including templates, scenes, and data files: `git grep -w "candidate_name"`

### Phase 3: Categorize

**High confidence (safe to remove)**
- No references anywhere
- Test, story, or fixture for a deleted subject
- Commented-out code blocks

**Medium confidence (needs review)**
- Only used by other dead code
- Only used in dev or test environments
- Duplicate implementations (keep the best one)

**Low confidence (keep or investigate)**
- Used in generated code
- Possible dynamic loading
- Part of a public API
- Referenced in docs

## Removal Process

### Step 1: Write the plan

```markdown
## Dead Code Findings

### High Confidence
- [ ] `src/old_button.tsx` - no references, replaced by `src/button.tsx`
- [ ] `tests/old_button.test.tsx` - test for removed component

### Medium Confidence (Review First)
- [ ] `src/old_date_format.py` - only used in dead code
```

### Step 2: Get approval

Present findings by confidence level with file and line counts, then ask before removing anything. Trivial-test or trivial-story findings you notice along the way go in a one-line pointer to `test-reaper`, not in this plan.

### Step 3: Remove safely

Order matters: orphaned tests and other orphans first, then the implementation last.

For each removal:

1. Double-check references: `git grep -w "candidate_name"`.
2. Check history for why it existed: `git log --all --full-history -- path/to/file`.
3. Remove the file with `rm`, or just the specific symbol with the Edit tool.
4. Verify with the project's own build, test, and other one-shot checks, and skip any it doesn't define. Include a docs or component-catalog build if the project has one. Never start a dev server or watcher to verify, because it never exits.

### Step 4: Commit

Focused commits by type, so each is easy to review or revert:

```bash
git commit -m "Remove orphaned tests for deleted modules"
git commit -m "Remove dead OldButton component"
git commit -m "Remove debug utilities and commented-out code"
```

## Common Scenarios

**Removed module, orphaned files.** Find the deletion in history, then the leftovers:
```bash
git log --all --full-history --diff-filter=D -- "**/old_module.*"
git ls-files | grep -i "old_module"
```

**Duplicate implementations.** Find similar names (`git grep -n "format_date"`), compare, keep the best one, repoint callers, remove the rest.

## Safety Checks

**Before removing:** full test suite and build pass; searched for dynamic loading and string references; checked config files.

**After removing:** the same checks pass, and the project's type-check and lint are clean if it has them.

## Reporting

Track before/after counts and report what was removed:

```
Dead Code Cleanup Results:
- Removed: 8 files, 1,247 lines
- Orphaned tests, stories, and fixtures removed: 8
```

## When to Apply

Use when the user asks to clean up dead code, remove unused files, or prune orphaned tests or stories. Also useful after large refactors, after replacing a major feature, before a release, and during codebase audits.

Don't use it for small feature changes, new feature work, or when it's unclear whether code is dead (ask first).

## Related Skills

- `test-reaper` - trivial, duplicate, and over-mocked tests and trivial stories whose subject still exists
- `code-health-audit` - broader sweep that defers here for removal mechanics

## Remember

- Better to keep questionable code than break something
- Always run the full test suite after removal
- Commit removals separately from feature work, and say why in the message
- When unsure if something is dead, ask the user
