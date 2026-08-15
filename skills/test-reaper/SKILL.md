---
name: test-reaper
description: >
  Finds and removes dead or trivial tests - duplicates, tests that only assert a mock was called,
  render checks that prove nothing, and suites whose name promises behavior they never observe.
  Distinguishes a test that tests nothing from one that tests the wrong thing, because those need
  opposite fixes.
  Trigger on: "test reaper", "reap tests", "remove trivial tests", "dead tests", "useless tests",
  "our tests don't test anything", "prune the test suite", "test audit", "which tests are worthless",
  "tests that always pass".
  For tests that are FAILING, use test-fix. For removing tests because their source is dead, use
  dead-code-cleanup.
---

# Test Reaper

A test suite rots differently than source. Nothing goes red, nothing gets flagged, the count keeps climbing, and confidence quietly decouples from coverage. The tests that hurt most are not the broken ones - they're the ones that pass no matter what you do to the code.

`dead-code-cleanup` already covers the classic markers: snapshot-only tests, `renders without crashing`, `.skip`, orphaned files. In a repo that has been kept up, those all return zero, and the sweep stops there having found nothing. This skill starts where that one runs out.

The distinction that drives every decision here: **a test that asserts nothing and a test that asserts the wrong thing are different problems.** The first is dead weight and gets reaped. The second is a coverage gap wearing a passing test as a disguise, and reaping it silently drops the intent. Never treat them the same.

## Sibling skills, so you don't do their job

- `test-fix` repairs failing tests, with a 3-attempt limit. Red tests are its problem, not this skill's.
- `dead-code-cleanup` removes tests whose *subject* is gone. If the component was deleted, that's a dead-code sweep.
- `kiss` trims test coverage added beyond the scope of a change. That's a diff-level lens; this is a suite-level one.

## Pre-flight

1. `git fetch && git status`. Right base branch, up to date.
2. **Confirm the suite is green before you start.** Reaping into a red suite makes it impossible to tell what your deletion broke. If it's red, that's `test-fix`'s job first.
3. Scope it. One domain or directory per pass.
4. **Read the test setup file.** This is the step people skip and it invalidates the whole audit. A global `jest.mock()` in `jest.setup.ts` means whole suites run against auto-mocks, and a test that looks like it "only asserts mocks" may have no other option available to it. Know what's globally mocked before you judge a single test.
5. Get the before count: total files, total cases, and the per-pattern counts below.

## Detection

```bash
# Volume baseline
find src -name '*.test.ts*' -o -name '*.spec.ts*' | wc -l
grep -rhoE '\b(it|test)\(' src --include='*.test.ts*' | wc -l

# Classic markers (often zero in a maintained repo - confirm, don't assume)
grep -rn 'toMatchSnapshot\|renders without crashing' src --include='*.test.ts*'
grep -rn '\.skip\|xit(\|xdescribe(\|\.todo(' src --include='*.test.ts*'
grep -rn '\.only(' src --include='*.test.ts*'   # must be zero; a leaked .only silently skips the suite

# Duplicate test names within one file
for f in $(find src -name '*.test.ts*'); do
  dup=$(grep -oE "^\s*(it|test)\(['\"\`][^'\"\`]+" "$f" | sed -E "s/^\s*(it|test)\(['\"\`]//" \
        | sort | uniq -d)
  [ -n "$dup" ] && echo "=== $f" && echo "$dup"
done

# Mock-assertion-only candidates: every expect targets a mock and only checks call-ness
grep -rn 'toHaveBeenCalled\|toHaveBeenCalledWith\|toHaveBeenCalledTimes' src --include='*.test.ts*' | wc -l

# Name/behavior mismatch: suites promising integration or persistence
find src -name '*integration*.test.ts*' -o -name '*persistence*.test.ts*'
```

The two judgments grep can't make, which you make by reading:

- **Is every assertion in this case a mock call-check?** If so it can only fail if the wiring changes, never if the behavior does.
- **Does the test name promise something the body never observes?** A case called `should persist state changes to IndexedDB` that asserts an adapter mock was called has not observed persistence. That gap is the single strongest signal in this skill.

## The three tiers

### Tier 1 - reap without asking

- **Duplicate test names in one file.** Read both. If they assert the same thing, delete one. If they assert different things, the name is wrong - rename it, don't delete it. Six cases sharing one name is always the first, and it's usually a copy-paste block where the names never got updated.
- **Self-duplicating assertions.** A case that re-asserts exactly what an earlier case in the same describe already covered, often visible from a comment like `// Should still render without crashing` sitting above an assertion that the name renders. Delete the later one.
- **Leaked `.only`.** Not a reap, a bug: it silently skips every other case in the file. Remove it and re-run the suite, because whatever it was hiding is about to surface.
- **The classic markers, if present.** Snapshot-only cases, bare `expect(Component).toBeDefined()`, `renders without crashing` with no other assertion.

### Tier 2 - propose in one batch

Present as one triaged list: `file:line`, current name, what it actually asserts, and **rewrite or delete** as the proposed action. The user picks per item.

- **Mock-assertion-only cases.** Flag as *rewrite or delete, your call*. Never auto-delete. Rank them by name/behavior mismatch, worst first: a file named `*.persistence.test.ts` or `*.integration.test.ts` that observes neither is the top of the list, because the name is a standing claim that the suite covers something it doesn't. For each, say what the honest version would assert - read the real state back, assert on the observable output - so "rewrite" is a concrete option and not just a deferral.
- **Single-assertion render checks.** One `render()` plus one `toBeInTheDocument()`. In isolation this is often correct, so only flag where a file is *mostly* these. A file of eight cases that each render the component and check one different string is one parameterized case wearing eight hats.
- **Wrong-target tests.** Tests pinned to things that aren't behavior: UI polish (colors, spacing, class names), dev-tooling internals, implementation details that break on any refactor, over-mocked integration patterns. These fail on healthy changes and pass on broken ones.

### Tier 3 - never touch

- **Anything that can fail for a real reason.** The bar is not "is this test interesting," it's "could this catch a regression." A boring test that guards a boring invariant stays.
- **Regression anchors.** A test whose comment cites the bug it guards is doing exactly its job, however odd the assertion looks. The odd assertion is usually the point.
- **Tests that look trivial because the setup is global.** Back to pre-flight step 4: if `jest.setup.ts` auto-mocks the module, a mock assertion may be the only observation available. Judge it against what the harness makes possible.
- **The last remaining test for a module.** Even a weak one is a smoke test. Rewrite it rather than leaving the module bare.

## Verify

This is the part that matters most, because a deleted test can't fail to tell you it was needed.

1. **Full suite green after every batch.** Not the scoped file, the whole suite.
2. **Prove the survivors still bite.** For each file you reaped, break the source deliberately (flip a boolean, return early, change a string) and confirm something goes red. If nothing does, the reap removed the only real coverage and you need to restore or rewrite it. Undo the deliberate break.
3. `npm run type-check` and `npm run lint` - deleted tests often orphan imports and fixtures.
4. Report the case count before and after, plus the count of files that lost their last meaningful assertion (that number should be zero).

Step 2 is not optional. Everything else in this skill is a heuristic; this is the only step that produces evidence.

## Commit and ship

Focused commits, in the user's voice (apply the `voice` skill):

- `Collapse six identically-named cases in mockStoreFactories`
- `Delete render checks that duplicate the case above them`
- `Rewrite worldStore persistence tests to read state back instead of asserting on the mock`

Deletions and rewrites go in **separate commits**. A reviewer can skim a deletion; a rewrite needs reading, and mixing them means neither gets the attention it needs.

## Don't

- Don't delete a mock-only test to make a number go down. It's a coverage gap, and deleting it hides the gap instead of closing it.
- Don't judge a store or hook test without reading the global test setup first.
- Don't reap into a red suite.
- Don't skip the deliberate-break check because the suite is green. Green after deleting tests is the expected result whether you did it right or wrong.
- Don't rename a test to match what it actually asserts and call that a fix. It just makes the coverage gap harder to find later.
- Don't count success in cases removed. The goal is a suite where a passing run means something.
