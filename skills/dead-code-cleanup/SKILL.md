---
name: dead-code-cleanup
description: >
  Finds and removes dead or orphaned code, files, and Storybook stories. Validates that code is
  truly unused before deleting anything. Trigger on: "remove dead code", "find unused exports",
  "what code can we delete", "prune the repo".
---

# Dead Code Cleanup

## Overview

Finds code, files, and stories whose subject is gone or that nothing uses, and removes them only after proving nothing depends on them. Validate first, delete second.

Trivial or weak tests (snapshot-only, `renders without crashing`, `toBeDefined`, duplicates, negative reference scans) belong to `test-reaper`. This skill only removes a test when its subject is gone (an orphaned test).

## What Qualifies

### Dead/orphaned code
- **Components never imported** - no imports anywhere
- **Unused utilities** - functions/modules with no consumers
- **Unused types/interfaces** - TypeScript definitions with no references
- **Duplicate implementations** - several versions of the same functionality
- **Empty functions** - do nothing or only return undefined
- **Commented-out code** - blocks that have been commented out
- **Debug code** - console logs, debug flags, temporary utilities
- **Orphaned tests and stories** - for components that were deleted or moved

### Trivial Storybook stories
- **Duplicate states** - two stories showing the identical state
- **Default-only stories** - `args: {}` when a Default story exists
- **Edge case stories** - contrived scenarios nobody will hit (exactly 47 characters)
- **Micro-variations** - a story per prop value (padding 5, 6, 7)
- **Obvious behavior** - self-evident from the component

```typescript
// Remove: empty args when Default exists
export const Empty: Story = { args: {} };

// Remove: contrived edge case
export const WithExactly47Characters: Story = {
  args: { text: "This string has exactly forty-seven chars!" },
};

// Remove: duplicate of LoadingState
export const IsLoading: Story = { args: { loading: true } };

// Remove: micro-variations (keep one or two examples at most)
export const WithPadding5: Story = { args: { padding: 5 } };
export const WithPadding6: Story = { args: { padding: 6 } };

// Keep: demonstrates an important state
export const ErrorState: Story = {
  args: { error: "Failed to load data", onRetry: fn() },
};
```

## Story Value Assessment

Ask of each story:

1. Does it show a distinct visual state? (error vs success vs loading: yes; padding 5 vs 6: no)
2. Would a developer need to see it? (interactive states, validation, responsive behavior: yes)
3. Does it document important behavior?
4. Is another story already covering it?
5. Is it a realistic use case?

Keep stories with play functions, decorators, or meaningful parameters (viewport, theme, background), even if the args look simple. Keep stories added for a real regression, stories referenced in docs, foundation stories others build on, and size or color variants in a design system where the full set is the documentation. When unsure if a story has value, ask.

## Detection

### Phase 1: Find candidates

```bash
# Components with no imports
for file in $(find src/components -name "*.tsx" ! -name "*.test.tsx" ! -name "*.stories.tsx"); do
  name=$(basename "$file" .tsx)
  imports=$(grep -r "import.*$name" src/ | wc -l)
  [ "$imports" -eq 0 ] && echo "No imports: $file"
done

# Orphaned tests and stories: does the subject still exist?
find . -name "*.test.ts*" -o -name "*.stories.ts*"

# Suspect stories
grep -r "export const Empty" --include="*.stories.tsx" .
grep -r "args: {}" --include="*.stories.tsx" .
grep -rE "With[0-9]+|WithExactly" --include="*.stories.tsx" .

# Over-specified story files (many exports)
for file in $(find . -name "*.stories.tsx"); do
  count=$(grep -c "^export const.*Story" "$file")
  [ "$count" -gt 10 ] && echo "Many stories ($count): $file"
done

# Debug leftovers
grep -r "console.log" src/ | grep -v ".test." | grep -v "// DEBUG:"
grep -r "debugger;" src/
grep -r "DEBUG.*=.*true" src/
```

### Phase 2: Validate before marking dead

For each candidate, check all of these:

1. No direct imports in `src/`
2. No dynamic imports (`React.lazy`, `import()`)
3. Not re-exported from index files
4. Not used in type definitions
5. Not referenced in config files (package.json, next.config.js, etc.)
6. Not used in Storybook stories
7. Not referenced in docs
8. No string references: `grep -r "ComponentName" src/`

### Phase 3: Categorize

**High confidence (safe to remove)**
- No imports anywhere
- Test or story for a deleted component
- Commented-out code blocks
- Stories that exactly duplicate another story

**Medium confidence (needs review)**
- Only imported by other dead code
- Only used in dev/test environments
- Duplicate implementations (keep the best one)
- Stories showing minor variations or edge cases

**Low confidence (keep or investigate)**
- Used in generated code
- Possible dynamic imports
- Part of a public API
- Referenced in docs
- Stories that might demonstrate important variants

## Removal Process

### Step 1: Write the plan

```markdown
## Dead Code Findings

### High Confidence
- [ ] `src/components/OldButton.tsx` - no imports, replaced by shadcn Button
- [ ] `src/components/__tests__/OldButton.test.tsx` - test for removed component
- [ ] `src/stories/OldButton.stories.tsx` - story for removed component

### Stories to Remove
- [ ] `Button.stories.tsx` - "Empty" (duplicates Default)
- [ ] `Input.stories.tsx` - "With47Characters" (contrived edge case)

### Medium Confidence (Review First)
- [ ] `src/lib/oldDateFormatter.ts` - only used in dead code
```

### Step 2: Get approval

Present findings by confidence level with file and line counts, then ask before removing anything. Trivial-test findings you notice along the way go in a one-line pointer to `test-reaper`, not in this plan.

### Step 3: Remove safely

Order matters: orphaned tests, orphaned stories, trivial stories, then the implementation last.

For each removal:

```bash
# 1. Double-check references
grep -r "ComponentName" src/
grep -r "story-id" docs/

# 2. Check history for why it existed
git log --all --full-history -- path/to/file.tsx

# 3. Remove the file, or just the specific export (Edit tool)
rm path/to/file.tsx

# 4. Verify
npm run build && npm run test && npm run storybook
```

### Step 4: Commit

Focused commits by type, so each is easy to review or revert:

```bash
git commit -m "docs: Remove trivial Storybook stories with no documentation value"
git commit -m "test: Remove orphaned tests for deleted components"
git commit -m "docs: Remove orphaned Storybook stories"
git commit -m "refactor: Remove dead OldButton component"
git commit -m "refactor: Remove debug utilities and commented code"
```

## Common Scenarios

**Removed component, orphaned files.** Find the deletion in history, then the leftovers:
```bash
git log --all --full-history --diff-filter=D -- "**/ComponentName.tsx"
find . -name "*ComponentName.test.tsx" -o -name "*ComponentName.stories.tsx"
```

**Story file with a mix of good and trivial stories.** Use Edit to remove only the trivial exports (duplicates, micro-variations, contrived edge cases). Keep the ones showing distinct states.

**Duplicate implementations.** Find similar names (`grep -r "export.*formatDate" src/`), compare, keep the best one, repoint callers, remove the rest.

## Safety Checks

**Before removing:** full test suite, build, and Storybook build pass; searched for dynamic imports and string references; checked config files; read the story to make sure you're not losing real documentation.

**After removing:** tests, build, and Storybook build pass; `npm run type-check` and `npm run lint` are clean (if available); spot-check Storybook to confirm important stories remain.

## Reporting

Track before/after counts (files, lines, stories) and report what was removed:

```
Dead Code Cleanup Results:
- Removed: 8 files, 1,247 lines
- Orphaned tests removed: 5
- Orphaned stories removed: 3
- Trivial stories removed: 23
```

## When to Apply

Use when the user asks to clean up dead code, remove unused files, prune orphaned tests or stories, or tidy Storybook. Also useful after large refactors, after replacing a major feature, before a release, and during codebase audits.

Don't use it for small feature changes, new feature work, or when it's unclear whether code is dead or a story has value (ask first).

## Related Skills

- `test-reaper` - trivial, duplicate, and over-mocked tests whose subject still exists
- `code-health-audit` - broader sweep that defers here for removal mechanics

## Remember

- Better to keep questionable code than break something
- Always run the full test suite after removal
- Commit removals separately from feature work, and say why in the message
- When unsure if a story has value, ask the user
