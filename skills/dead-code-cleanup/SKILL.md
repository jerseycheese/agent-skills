---
name: dead-code-cleanup
description: >
  Identifies and removes dead/orphaned code, tests, and Storybook stories — including trivial tests
  that check only obvious behavior or rare edge cases with no real value.
  Always validates that code is truly unused before deleting anything.
  Trigger on: "remove dead code", "clean up unused files", "delete orphaned components",
  "find unused exports", "remove trivial tests", "clean up the codebase", "what code can we delete",
  "prune the repo", "remove stale stories".
---

# Dead Code Cleanup

## Overview

Systematically identifies dead, orphaned, and trivial code across the codebase including components, tests, and Storybook stories. Validates that code is truly unused before removal to prevent breaking changes. Also removes stories that provide no documentation value or only demonstrate rare edge cases.

## What Qualifies as Dead/Trivial Code

### Dead/Orphaned Code
- **Components never imported** - React components with no imports anywhere
- **Unused utilities** - Functions/modules with no consumers
- **Orphaned tests** - Tests for deleted/moved components
- **Orphaned stories** - Storybook stories for deleted/moved components
- **Commented-out code** - Code blocks that have been commented out
- **Debug code** - Console logs, debug flags, temporary test utilities

### Trivial Tests
- **Tests that always pass** - Tests with no real assertions or mocked to always succeed
- **Empty render tests** - Tests that only verify component renders without crashing
- **Pointless existence tests** - Tests that check if a component is defined
- **Snapshot-only tests** - Tests with only snapshots and no behavior validation
- **Duplicate tests** - Multiple tests checking the same exact behavior

### Trivial Storybook Stories
- **No-value stories** - Stories that show the exact same thing as another story
- **Default-only stories** - Stories that only render component with no props (when default story exists)
- **Edge case stories** - Stories demonstrating extremely rare scenarios unlikely to occur
- **Duplicate states** - Multiple stories showing identical visual states
- **Over-specification stories** - Stories for every tiny prop variation that adds no documentation value
- **Obvious behavior stories** - Stories showing behavior that's self-evident from the component

**Examples of trivial stories to remove**:
```typescript
// ❌ Trivial - just default with no props (when Default story exists)
export const Empty: Story = {
  args: {},
};

// ❌ Trivial - rare edge case nobody will encounter
export const WithExactly47Characters: Story = {
  args: {
    text: "This string has exactly forty-seven chars!",
  },
};

// ❌ Trivial - duplicate of existing state
export const LoadingState: Story = {
  args: { loading: true },
};
export const IsLoading: Story = {  // Duplicate!
  args: { loading: true },
};

// ❌ Trivial - no documentation value
export const WithPadding5: Story = {
  args: { padding: 5 },
};
export const WithPadding6: Story = {
  args: { padding: 6 },
};
export const WithPadding7: Story = {
  args: { padding: 7 },
};

// ✅ Keep - demonstrates important state
export const ErrorState: Story = {
  args: {
    error: "Failed to load data",
    onRetry: fn(),
  },
};

// ✅ Keep - shows important variant
export const WithLongContent: Story = {
  args: {
    children: "Very long content that tests text wrapping...",
  },
};
```

### Trivial Other Code
- **Empty functions** - Functions that do nothing or only return undefined
- **Duplicate implementations** - Multiple versions of the same functionality
- **Unused types/interfaces** - TypeScript definitions with no references

## Detection Strategy

### Phase 1: Identify Candidates

**For Components**:
```bash
# Find all component files
find src/components -name "*.tsx" -o -name "*.ts"

# For each component, check for imports
grep -r "import.*ComponentName" src/
grep -r "from.*path/to/component" src/
```

**For Tests**:
```bash
# Find all test files
find . -name "*.test.ts" -o -name "*.test.tsx"

# For each test, verify the tested file exists
# Check if test is testing actual behavior (not just rendering)
```

**For Storybook Stories**:
```bash
# Find all story files
find . -name "*.stories.tsx" -o -name "*.stories.ts"

# For each story:
# 1. Verify the component exists (orphaned check)
# 2. Check if story provides meaningful documentation
# 3. Look for duplicate states
# 4. Identify edge case stories
```

### Phase 2: Validation

**Before marking as dead, verify**:
1. No direct imports in src/
2. No dynamic imports (e.g., React.lazy, import())
3. Not exported from index files
4. Not used in type definitions
5. Not referenced in configuration files
6. Not used in Storybook stories
7. Not referenced in documentation

**For tests, verify they're trivial**:
```typescript
// Trivial test patterns
❌ test('renders without crashing', () => { render(<Component />) })
❌ test('exists', () => { expect(Component).toBeDefined() })
❌ test('has correct snapshot', () => { expect(tree).toMatchSnapshot() })
❌ test('renders', () => { render(<Component />); expect(screen.getByRole('button')).toBeInTheDocument() })

// Non-trivial tests
✅ test('displays error when validation fails', () => { ... })
✅ test('submits form with correct data', () => { ... })
✅ test('calls callback when button clicked', () => { ... })
```

**For stories, verify they're trivial**:
```typescript
// Read the story file and check:
// 1. Does it duplicate another story's state?
// 2. Is it an edge case (e.g., exactly N characters, rare prop combination)?
// 3. Does it show obvious behavior?
// 4. Is it just testing every prop value without value?

// Compare stories:
const stories = extractStoriesFromFile(file);
const duplicates = findDuplicateStates(stories);
const edgeCases = findEdgeCaseStories(stories);
const noValue = findNoValueStories(stories);
```

### Phase 3: Categorization

**Organize findings by confidence level**:

**High confidence (safe to remove)**:
- No imports found anywhere
- File created but never used
- Test for deleted component
- Story for deleted component
- Commented-out code blocks
- Stories that exactly duplicate existing stories
- Tests that only check rendering with no assertions

**Medium confidence (needs review)**:
- Only imported in other dead code
- Only used in development/test environments
- Trivial tests that could be replaced
- Duplicate implementations
- Stories showing edge cases or minor variations
- Stories with questionable documentation value

**Low confidence (keep or investigate)**:
- Used in generated code
- Dynamic imports possible
- Part of public API
- Referenced in documentation
- Stories that might demonstrate important variants

## Story Value Assessment

### Questions to Ask

**For each Storybook story, evaluate**:

1. **Does it show a distinct visual state?**
   - ✅ Keep: Shows error state vs success state vs loading state
   - ❌ Remove: Shows padding: 5 vs padding: 6 vs padding: 7

2. **Would a developer need to see this?**
   - ✅ Keep: Interactive states, error handling, edge cases that matter
   - ❌ Remove: Every possible prop combination, trivial variations

3. **Does it document important behavior?**
   - ✅ Keep: Form validation, disabled states, responsive behavior
   - ❌ Remove: Component with exactly 47 characters of text

4. **Is it already covered by another story?**
   - ✅ Keep: First story showing this state
   - ❌ Remove: Duplicate stories showing identical states

5. **Is this a realistic use case?**
   - ✅ Keep: Common scenarios developers will encounter
   - ❌ Remove: Contrived edge cases unlikely to happen

### Story Cleanup Patterns

**Common trivial story patterns**:
```typescript
// Pattern 1: Duplicate states
export const Loading = { args: { isLoading: true } };
export const IsLoading = { args: { isLoading: true } };  // ❌ Remove

// Pattern 2: Micro-variations
export const Small = { args: { size: 'sm' } };
export const SmallWithPadding = { args: { size: 'sm', padding: 2 } };  // ❌ Remove if not meaningful

// Pattern 3: Edge cases
export const With99Items = { args: { items: Array(99).fill({}) } };  // ❌ Remove (why 99?)

// Pattern 4: Every prop value
export const RedButton = { args: { color: 'red' } };
export const BlueButton = { args: { color: 'blue' } };
export const GreenButton = { args: { color: 'green' } };
// ❌ Keep one or two examples, remove the rest

// Pattern 5: No-value empty states
export const Empty = { args: {} };  // ❌ Remove if Default exists
```

**Keep these valuable stories**:
```typescript
// ✅ Shows important interactive state
export const WithValidationError: Story = {
  args: {
    error: "Email is required",
    touched: true,
  },
};

// ✅ Demonstrates realistic use case
export const LongFormWithManyFields: Story = {
  args: {
    fields: realisticFormFields,
  },
};

// ✅ Shows responsive behavior
export const MobileLayout: Story = {
  parameters: {
    viewport: { defaultViewport: 'mobile1' },
  },
};

// ✅ Documents complex interaction
export const WithAsyncValidation: Story = {
  args: {
    onValidate: async (value) => { /* realistic validation */ },
  },
  play: async ({ canvasElement }) => {
    // Demonstrates the interaction
  },
};
```

## Removal Process

### Step 1: Create Removal Plan

Document all findings:
```markdown
## Dead Code Findings

### High Confidence (Safe to Remove)
- [ ] `src/components/OldButton.tsx` - No imports, replaced by shadcn Button
- [ ] `src/components/__tests__/OldButton.test.tsx` - Test for removed component
- [ ] `src/stories/OldButton.stories.tsx` - Story for removed component

### Trivial Tests to Remove
- [ ] `Component.test.tsx:15-18` - "renders without crashing" test
- [ ] `Component.test.tsx:20-23` - Empty snapshot test
- [ ] `Form.test.tsx:45-48` - Duplicate of existing test

### Trivial Stories to Remove
- [ ] `Button.stories.tsx` - "Empty" story (duplicates Default)
- [ ] `Button.stories.tsx` - "WithPadding5/6/7" stories (no value)
- [ ] `Input.stories.tsx` - "With47Characters" story (contrived edge case)
- [ ] `Card.stories.tsx` - "Loading" and "IsLoading" (duplicates)

### Medium Confidence (Review First)
- [ ] `src/lib/oldDateFormatter.ts` - Only used in dead code
- [ ] `Dialog.stories.tsx` - "WithCustomZIndex" (edge case?)
```

### Step 2: Validate with User

**Present findings for approval**:
```
Found the following dead/trivial code:

High Confidence (3 files, 245 lines):
- OldButton component and tests (never imported)
- Legacy date formatter (only used in removed code)

Trivial Tests (12 tests, 156 lines):
- 8 "renders without crashing" tests
- 4 duplicate tests

Trivial Stories (15 stories, 203 lines):
- 6 stories showing micro-variations (padding values)
- 4 duplicate state stories
- 3 contrived edge case stories
- 2 empty/default duplicates

Total potential cleanup: 5 files + 27 test/story removals, 604 lines

Shall I proceed with removal?
```

### Step 3: Safe Removal

**Remove in order**:
1. **Trivial tests first** - Remove pointless tests
2. **Trivial stories second** - Remove no-value stories
3. **Orphaned tests third** - Remove tests for deleted code
4. **Orphaned stories fourth** - Remove stories for deleted code
5. **Implementation last** - Remove actual dead code

**For each removal**:
```bash
# 1. For code: Double-check no imports
grep -r "ComponentName" src/

# 2. For stories: Verify not referenced in docs
grep -r "story-id" docs/

# 3. Check git history to understand why it existed
git log --all --full-history -- path/to/file.tsx

# 4. Remove file or specific exports
# Option A: Remove entire file
rm path/to/file.tsx

# Option B: Remove specific story/test from file
# Use Edit tool to remove the export

# 5. Verify build still works
npm run build

# 6. Verify tests still pass
npm run test

# 7. Verify Storybook builds
npm run storybook
```

### Step 4: Commit Strategy

**Create focused commits**:
```bash
# Separate commits for different types
git commit -m "test: Remove trivial 'renders without crashing' tests"
git commit -m "test: Remove duplicate test cases"
git commit -m "docs: Remove trivial Storybook stories with no documentation value"
git commit -m "docs: Remove edge case stories (WithExactly47Chars, etc)"
git commit -m "test: Remove orphaned tests for deleted components"
git commit -m "docs: Remove orphaned Storybook stories"
git commit -m "refactor: Remove dead OldButton component"
git commit -m "refactor: Remove debug utilities and commented code"
```

## Detection Tools

### Custom Grep Patterns

**Find components with no imports**:
```bash
# For each .tsx component file
for file in $(find src/components -name "*.tsx" ! -name "*.test.tsx" ! -name "*.stories.tsx"); do
  name=$(basename "$file" .tsx)
  imports=$(grep -r "import.*$name" src/ | wc -l)
  if [ "$imports" -eq 0 ]; then
    echo "No imports: $file"
  fi
done
```

**Find trivial tests**:
```bash
# Search for common trivial test patterns
grep -r "renders without crashing" src/
grep -r "toBeDefined()" src/ | grep -i component
grep -r "toMatchSnapshot()" src/ | grep -v "// meaningful snapshot"
grep -r "test('renders'" src/
grep -r "it('renders'" src/
```

**Find potentially trivial stories**:
```bash
# Search for common trivial story patterns
grep -r "export const Empty" **/*.stories.tsx
grep -r "args: {}" **/*.stories.tsx
grep -r "WithExactly" **/*.stories.tsx
grep -r "With[0-9]+" **/*.stories.tsx

# Find story files with many exports (likely over-specified)
for file in $(find . -name "*.stories.tsx"); do
  count=$(grep -c "^export const.*Story" "$file")
  if [ "$count" -gt 10 ]; then
    echo "Many stories ($count): $file"
  fi
done
```

**Find orphaned stories**:
```bash
# For each story file, check if component exists
for story in $(find . -name "*.stories.tsx"); do
  # Extract component import
  component=$(grep "import.*from" "$story" | grep -v "@" | head -1)
  # Check if imported file exists
  # ...validation logic...
done
```

## Safety Checks

### Before Removing Anything

**Required validations**:
- [ ] Run full test suite: `npm run test`
- [ ] Run build: `npm run build`
- [ ] Check Storybook builds: `npm run storybook`
- [ ] Search for dynamic imports: `grep -r "import(" src/`
- [ ] Search for string references: `grep -r "ComponentName" src/`
- [ ] Check configuration files: package.json, next.config.js, etc.
- [ ] Review story file to ensure not removing valuable documentation

### After Removal

**Verification steps**:
- [ ] All tests pass: `npm run test`
- [ ] Build succeeds: `npm run build`
- [ ] Storybook builds: `npm run storybook`
- [ ] No TypeScript errors: `npm run type-check` (if available)
- [ ] No ESLint errors: `npm run lint`
- [ ] Spot-check Storybook to ensure important stories remain

## Common Scenarios

### Scenario 1: Removed Component with Orphaned Files

**Problem**: Deleted a component but forgot to remove tests/stories

**Solution**:
```bash
# Find the component in git history
git log --all --full-history --diff-filter=D -- "**/ComponentName.tsx"

# Find orphaned test
find . -name "*ComponentName.test.tsx"

# Find orphaned story
find . -name "*ComponentName.stories.tsx"

# Remove both
rm path/to/ComponentName.test.tsx
rm path/to/ComponentName.stories.tsx
```

### Scenario 2: Story File with Mix of Good and Trivial Stories

**Problem**: Some stories are valuable, others are trivial variations

**Detection**:
```typescript
// src/stories/Button.stories.tsx

// ✅ Keep - shows important states
export const Default: Story = { args: { children: "Click me" } };
export const Disabled: Story = { args: { disabled: true } };
export const Loading: Story = { args: { loading: true } };

// ❌ Remove - trivial variations
export const WithPadding5: Story = { args: { padding: 5 } };
export const WithPadding6: Story = { args: { padding: 6 } };
export const WithPadding7: Story = { args: { padding: 7 } };

// ❌ Remove - duplicate
export const IsLoading: Story = { args: { loading: true } };  // Same as Loading!

// ❌ Remove - contrived edge case
export const WithExactly42Characters: Story = {
  args: { children: "This button has exactly 42 characters!" },
};
```

**Action**: Use Edit tool to remove only the trivial exports, keep the valuable ones

### Scenario 3: Trivial Tests Adding No Value

**Problem**: Tests that only check component renders

**Detection**:
```typescript
// src/components/__tests__/MyComponent.test.tsx

❌ test('renders without crashing', () => {
  render(<MyComponent />);
  // No assertions!
});

❌ test('component exists', () => {
  expect(MyComponent).toBeDefined();
  // Pointless - TypeScript already ensures this
});

❌ test('renders button', () => {
  render(<MyComponent />);
  expect(screen.getByRole('button')).toBeInTheDocument();
  // Just checking it renders, no behavior tested
});
```

**Action**: Remove these tests, ensure meaningful behavior tests remain

### Scenario 4: Duplicate Implementations

**Problem**: Multiple versions of same utility

**Detection**:
```bash
# Find similar function names
grep -r "function formatDate" src/lib/
grep -r "export.*formatDate" src/

# Compare implementations
# Keep best one, remove duplicates
```

### Scenario 5: Debug Code Left Behind

**Problem**: Console.log, debug flags, test utilities in production code

**Detection**:
```bash
# Find debug statements
grep -r "console.log" src/ | grep -v ".test." | grep -v "// DEBUG:"
grep -r "console.debug" src/
grep -r "debugger;" src/

# Find debug flags
grep -r "DEBUG.*=.*true" src/
grep -r "__DEV__" src/
```

## Edge Cases to Watch For

### Don't Remove

**Even if looks trivial**:
- **Stories documenting complex interactions** - Even if props are simple, the play function might demonstrate important behavior
- **Stories with meaningful parameters** - viewport settings, themes, decorators that show responsive/theme behavior
- **Edge case stories that match real bugs** - If a story was added to prevent regression of a real issue
- **Stories referenced in documentation** - Check docs before removing
- **Foundation stories** - The first story in a file that others reference

### Be Careful With

**Requires extra validation**:
- **Stories with play functions** - May demonstrate interactions even if args look simple
- **Stories with decorators** - May show important context/layout
- **Stories with parameters** - Viewport, theme, background settings provide value
- **Multiple stories showing size variants** - Keep if sizes are meaningfully different (xs, sm, md, lg, xl)
- **Stories in design system** - May need to show all color/variant combinations for documentation

## Metrics

### Track Cleanup Impact

**Before cleanup**:
```bash
# Count files
find src -name "*.tsx" -o -name "*.ts" | wc -l

# Count lines of code
find src -name "*.tsx" -o -name "*.ts" | xargs wc -l | tail -1

# Count test files
find src -name "*.test.tsx" -o -name "*.test.ts" | wc -l

# Count stories
find . -name "*.stories.tsx" -exec grep -c "^export const.*Story" {} + | awk '{s+=$1} END {print s}'
```

**After cleanup, report**:
```
Dead Code Cleanup Results:
- Removed: 8 files
- Lines deleted: 1,247
- Trivial tests removed: 12
- Trivial stories removed: 23
- Orphaned tests removed: 5
- Orphaned stories removed: 3
- Build time: 15% faster
- Bundle size: 8KB smaller
- Storybook: 23 fewer stories, clearer documentation
```

## When to Apply This Skill

### Automatic triggers:
- User asks to "clean up dead code"
- User asks to "remove unused files"
- User asks to "remove trivial tests"
- User asks to "remove trivial stories"
- User mentions "orphaned stories/tests"
- User asks to clean up Storybook

### Proactive use during:
- Large refactoring efforts
- After removing/replacing major features
- Before major releases
- During codebase audits
- After noticing Storybook has too many low-value stories

### Don't use when:
- Making small feature changes
- Working on new features
- User hasn't requested cleanup
- Unclear if code is truly dead
- Unclear if story provides value (ask user)

## Integration with Other Skills

### Works well with:
- **software-engineering-best-practices** - Uses same principles for code quality
- **github-workflow** - Creates clean, focused commits for removals

### Coordinates with:
- Pattern recognition - Identifies when code was replaced
- Test quality review - Distinguishes trivial vs valuable tests
- Refactoring - Often cleanup happens during refactoring
- Documentation review - Ensures removed stories aren't referenced

## Summary

**Dead Code Cleanup Process**:
1. **Identify** - Find candidates using grep/find
2. **Validate** - Verify truly unused/trivial with multiple checks
3. **Categorize** - High/medium/low confidence
4. **Get approval** - Present findings to user
5. **Remove safely** - Trivial tests → Trivial stories → Orphaned files → Dead code
6. **Verify** - Build, test, Storybook, lint all pass
7. **Commit** - Focused commits by type

**Story Evaluation Criteria**:
- Does it show distinct visual state?
- Would a developer need to see this?
- Does it document important behavior?
- Is it already covered by another story?
- Is this a realistic use case?

**Remember**:
- Better to keep questionable code than break something
- Always run full test suite after removal
- Commit removals separately from feature work
- Document why code was removed in commit message
- When unsure if story has value, ask the user
- Keep stories that demonstrate real use cases
- Remove stories that are contrived or micro-variations

**The goal**: Clean, maintainable codebase with only code that serves a purpose, properly tested with meaningful tests that validate behavior, and Storybook stories that provide actual documentation value for developers.
