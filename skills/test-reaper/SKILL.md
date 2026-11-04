---
name: test-reaper
description: >
  Finds and removes dead or trivial tests: duplicates, mock-only asserts, render checks that prove
  nothing. Also finds over-mocked tests and seam gaps, where no test sends a realistic payload
  across a boundary. Trigger on: "reap tests", "our tests don't test anything", "too much
  mocking", "why didn't tests catch this".
---

# Test Reaper

A test suite rots differently than source. Nothing goes red, nothing gets flagged, the count keeps climbing, and confidence quietly decouples from coverage. The tests that hurt most are not the broken ones - they're the ones that pass no matter what you do to the code.

`dead-code-cleanup` only removes tests whose subject is gone (orphaned files). This skill owns the classic markers too: snapshot-only tests, `renders without crashing`, `toBeDefined`, `.skip`. In a repo that has been kept up, those all return zero, and a sweep that stops there finds nothing. The sections below go further.

Also watch for a newer kind of dead weight: a test added after deleting stale text/config/CSS that reads a file and asserts the old string is gone. Those tests feel like regression coverage, but most of them only make the deletion permanent in the narrowest possible way. If the old reference comes back, the real question is whether behavior broke; if no behavior is observed, the test is just a grep with a Jest wrapper.

The distinction that drives every decision here: **a test that asserts nothing and a test that asserts the wrong thing are different problems.** The first is dead weight and gets reaped. The second is a coverage gap wearing a passing test as a disguise, and reaping it silently drops the intent. Never treat them the same.

There's one more failure this skill has to look for, and you can't see it by reading tests one at a time: **the seam gap.** The page test mocks the API client. The route test feeds the handler a hand-rolled 300-byte fixture. The E2E spec opens the dialog and never submits it. Each test is honest about its own half, and every one of them is green. Still, nothing ever sends a realistic payload across the real boundary, so a payload-size limit or a missing field ships without anyone noticing. A sweep that only judges individual tests will call this suite clean. Judge the seams too.

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

# Negative source/reference guards: read a file/string and only assert retired text is absent
rg -n "readFileSync|readFile|not\\.toContain|not\\.toMatch|not\\.toHaveProperty|does not|no longer|retired|removed|dead|dropped" \
  src scripts __tests__ tests -g '*.test.*' -g '*.spec.*'

# Name/behavior mismatch: suites promising integration or persistence
find src -name '*integration*.test.ts*' -o -name '*persistence*.test.ts*'

# Mock density: files mocking many modules (a triage pointer, not a finding)
for f in $(find src -name '*.test.ts*'); do
  c=$(grep -c 'jest\.mock(' "$f"); [ "$c" -ge 6 ] && echo "$c $f"
done | sort -rn

# Promised collaborator mocked: integration/persistence files that mock a local module
grep -lE "jest\.mock\(['\"](\.{1,2}|@)/" $(find src -name '*integration*.test.ts*' -o -name '*persistence*.test.ts*')

# Mocked everywhere: for each local module that gets mocked, which tests import it for real?
grep -rhoE "jest\.mock\(['\"]@/[^'\"]+" src --include='*.test.ts*' | sed -E "s/jest\.mock\(['\"]//" \
  | sort | uniq -c | sort -rn
# then, per module: grep -rlE "from ['\"]<module>['\"]" src --include='*.test.ts*' | xargs grep -L "jest.mock('<module>'"

# Stub children: component tests that replace a child component with a stub
grep -rlE "jest\.mock\(['\"]\.{1,2}/[A-Z][A-Za-z]+['\"]" src --include='*.test.tsx'

# Size/count/time gates in source: each one needs a test that actually crosses it
grep -rnE '[0-9]+ ?\* ?1024|MAX_[A-Z_]+|_LIMIT\b|_BYTES\b|timeout' src --include='*.ts' | grep -v test
```

The judgments grep can't make, which you make by reading:

- **Is every assertion in this case a mock call-check?** If so it can only fail if the wiring changes, never if the behavior does.
- **Is the case only a negative reference guard?** Source/content is read, a retired string/selector/key is asserted absent, and no positive behavior or output is observed. If yes, treat it as delete-or-rewrite, not automatic coverage.
- **Does the test name promise something the body never observes?** A case called `should persist state changes to IndexedDB` that asserts an adapter mock was called has not observed persistence. That gap is the single strongest signal among single-test checks.
- **Is the asserted value just the stub coming back?** If a case sets `mockReturnValue(x)` and then asserts the result equals `x`, all it proves is that the code passed the stub through. The exception is a wrapper or facade whose contract is to return the collaborator's result unchanged. There, the echo is the behavior, and it catches a dropped return or the wrong collaborator.
- **For each mocked boundary, does any test drive the other side with the payload the caller really sends?** Seam checks work per boundary, not per test. Give that question its own pass (see "Over-mocking and seam gaps" below).

## Over-mocking and seam gaps

A call-check can be precise and still prove only half of a contract. `expect(api.generate).toHaveBeenCalledWith({ world })` shows the caller built the right argument. It says nothing about whether the far side accepts that argument at its real size and shape. Don't clear a mocked-collaborator test because its payload assertion is detailed. First check whether the other half of the contract is tested somewhere.

Shapes to look for:

- **Mock plus filler.** Every assertion is either a call-check or an existence-only filler (`toBeDefined`, `toBeTruthy`, `not.toBeNull`). A `toBeInTheDocument` on specific copy is a real observation, not filler. It's mock-only with padding. The padding is the only reason a strict "every assertion is a call-check" rule misses it.
- **Mock echo.** The case stubs a return value and then asserts the result equals that stub. It can only fail if the code stops passing values through. Skip it when pass-through is the unit's job (see "Pass-through contracts" under the keep list).
- **Promised collaborator mocked.** A file named `*integration*` or `*persistence*` that `jest.mock`s the local module its name promises to integrate with. It's the name/behavior mismatch at file scale, and it outranks any single mismatched case.
- **Stub-child render.** A component test replaces a child with a stub and then only asserts the stub rendered. That's wiring, not behavior.
- **Mocked everywhere.** A local module that's `jest.mock`ed in several files, where every test that imports it for real uses a hand-rolled fixture. On paper its seam is covered from both sides. In practice nothing has ever crossed it.
- **Unrealistic fixtures at a gated branch.** The source has a size, count, or time gate (a payload limit, pagination, a timeout, an oversize code path). The fixtures are orders of magnitude below it, or leave out fields the real type carries (an image, a nested list). If no test crosses the threshold, that branch is untested no matter how many green tests sit around it. When one gate like this is untested, check the sibling routes that share it. The same bug tends to come back one route over.

Mock density on its own is a pointer, not a finding. An orchestrator that mocks 15 collaborators to test sequencing, abort handling, and ordering can be a very good test. Read what it asserts before judging it.

## The three tiers

### Tier 1 - reap without asking

- **Duplicate test names in one file.** Read both. If they assert the same thing, delete one. If they assert different things, the name is wrong - rename it, don't delete it. Six cases sharing one name is always the first, and it's usually a copy-paste block where the names never got updated.
- **Self-duplicating assertions.** A case that re-asserts exactly what an earlier case in the same describe already covered, often visible from a comment like `// Should still render without crashing` sitting above an assertion that the name renders. Delete the later one.
- **Leaked `.only`.** Not a reap, a bug: it silently skips every other case in the file. Remove it and re-run the suite, because whatever it was hiding is about to surface.
- **The classic markers, if present.** Snapshot-only cases, bare `expect(Component).toBeDefined()`, `renders without crashing` with no other assertion.
- **Pure negative reference guards after a deletion.** If a test reads docs/source/CSS/config and only asserts a removed string, selector, key, or literal is absent, delete it when there is no corresponding positive invariant. Examples: "does not reference the removed template step", "does not carry retired selector X", or "has dropped old marketing phrase Y" with no behavior-level assertion.

### Tier 2 - propose in one batch

Present as one triaged list: `file:line`, current name, what it actually asserts, and **rewrite or delete** as the proposed action. The user picks per item.

- **Seam gaps. Rank these first.** A boundary where every test on one side mocks the other side, or where the real side only ever sees toy fixtures below a gate that production crosses. List it by seam, not by test: name the caller's test, the callee's test, and the payload or threshold neither one exercises. The action is always "add the crossing test." Nothing here gets deleted. The mocked tests are fine as unit tests, they just aren't the whole story.
- **Promised collaborator mocked.** An `*integration*` or `*persistence*` file that mocks the module its name promises. Rank it above single mismatched cases, because the whole file's name is the false claim.
- **Mock-assertion-only cases**, including mock-plus-filler and mock-echo cases. Flag as *rewrite or delete, your call*. Never auto-delete. Rank them by name/behavior mismatch, worst first: a file named `*.persistence.test.ts` or `*.integration.test.ts` that observes neither is the top of the list, because the name is a standing claim that the suite covers something it doesn't. For each, say what the honest version would assert - read the real state back, assert on the observable output - so "rewrite" is a concrete option and not just a deferral.
- **Single-assertion render checks.** One `render()` plus one `toBeInTheDocument()`. In isolation this is often correct, so only flag where a file is *mostly* these. A file of eight cases that each render the component and check one different string is one parameterized case wearing eight hats.
- **Negative migration guards with a real policy hiding underneath.** Some source scans should become a smaller positive policy test instead of being deleted. A CSS-token migration test that forbids literal values across the tree may be a real linter-like invariant; a one-off `not.toMatch(/old-class/)` usually is not. Keep the policy, remove the archaeology.
- **Wrong-target tests.** Tests pinned to things that aren't behavior: UI polish (colors, spacing, class names), dev-tooling internals, implementation details that break on any refactor, over-mocked integration patterns. These fail on healthy changes and pass on broken ones.

### Tier 3 - never touch

- **Anything that can fail for a real reason.** The bar is not "is this test interesting," it's "could this catch a regression." A boring test that guards a boring invariant stays.
- **Regression anchors.** A test whose comment cites the bug it guards is doing exactly its job, however odd the assertion looks. The odd assertion is usually the point.
- **Security/privacy redaction checks.** Negative assertions like `not.toContain(secret)` or `not.toHaveProperty('apiKey')` can be the behavior. Do not lump them in with deleted-reference guards.
- **Tests that look trivial because the setup is global.** Back to pre-flight step 4: if `jest.setup.ts` auto-mocks the module, a mock assertion may be the only observation available. Judge it against what the harness makes possible.
- **The last remaining test for a module.** Even a weak one is a smoke test. Rewrite it rather than leaving the module bare.
- **Orchestrator tests that mock collaborators on purpose.** If the unit under test is the sequencing (what runs first, what blocks on what, what gets skipped on abort), mocking the steps is the right design. These count as good when they also assert on the orchestrator's own output.
- **Callback-prop contracts.** For a controlled component, `onChange` / `onSave` / `onCancel` is the public API. A call-check that deep-checks the callback's argument observes exactly what a consumer would see. Don't flag it just because the matcher is `toHaveBeenCalledWith`.
- **Subscription and registration APIs.** For a pub/sub or event-registration module, "the handler was called with X" is the behavior itself.
- **Pass-through contracts.** A wrapper, facade, or adapter that has to hand back its collaborator's result unchanged. A mock-echo test is the right test there: it fails if the wrapper returns `undefined`, transforms the value, or calls the wrong collaborator.

## Honest rewrites

A rewrite suggestion has to be concrete, or "rewrite" turns into "never." Pick the recipe that fits:

- **Mock at the boundary, not the neighbor.** Stub the thing you don't own: `fetch`, the AI provider, the clock, the filesystem. Keep your own client, serializer, and store real. A page test that mocks `fetch` instead of your API client still exercises serialization.
- **Read the state back.** For a store or persistence claim, use the real store (or an in-memory backend) and assert on `getState()` or a fresh read after the action. Don't assert that the setter mock was called.
- **Cross the seam once.** Build the request body the way the real client does, hand it to the real route handler (`await POST(new Request(url, { method: 'POST', body }))`), and assert on the response status and shape. One such test per seam is usually enough.
- **Use production-shaped fixtures at gates.** Build the fixture from the shared factory, or from a captured real payload, and push at least one case past each size/count/time threshold in the source. A 1x1 image stub or a short asset path does not count for a code path that exists because real images are megabytes.
- **Delete the stub-child mock.** Render the real child, unless it drags in a network or provider dependency. In that case, stub that dependency instead.

## Verify

This is the part that matters most, because a deleted test can't fail to tell you it was needed.

1. **Full suite green after every batch.** Not the scoped file, the whole suite.
2. **Prove the survivors still bite.** For each file you reaped, break the source deliberately (flip a boolean, return early, change a string) and confirm something goes red. If nothing does, the reap removed the only real coverage and you need to restore or rewrite it. Undo the deliberate break.
3. **Confirm over-mock and seam findings by breaking the mocked side.** Break the real implementation of the module the test mocks (make the store setter a no-op, make the route reject large bodies, drop a field in the serializer) and run the tests. Undo the break afterwards. Until you've done this, label findings PLAUSIBLE.
   - **Over-mock finding (one test):** run the flagged file. Green means CONFIRMED, since that test can't see the module. Red means the finding was wrong, so drop it.
   - **Seam gap (a boundary):** run the whole relevant suite, not just the flagged file. The flagged file stays green by design, because it mocks the module. The seam gap is CONFIRMED only if every test stays green. If any other test goes red, something does cross the seam, so drop the seam-gap finding. The flagged test can still be an over-mock finding on its own.
4. Lint and type-check with the project's own scripts (`npm run type-check` and `npm run lint` are examples; skip any it does not define) - deleted tests often orphan imports and fixtures.
5. Report the case count before and after, plus the count of files that lost their last meaningful assertion (that number should be zero).

Steps 2 and 3 are not optional. Everything else in this skill is a heuristic; this is the only step that produces evidence.

## Commit and ship

Focused commits, in the user's writing style (apply their style skill or config if they have one):

- `Collapse six identically-named cases in mockStoreFactories`
- `Delete render checks that duplicate the case above them`
- `Rewrite worldStore persistence tests to read state back instead of asserting on the mock`

Deletions and rewrites go in **separate commits**. A reviewer can skim a deletion; a rewrite needs reading, and mixing them means neither gets the attention it needs.

## Don't

- Don't delete a mock-only test to make a number go down. It's a coverage gap, and deleting it hides the gap instead of closing it.
- Don't add a test whose only job is proving a deleted reference stayed deleted. If there is a real invariant, test the generated output, rendered UI, parser result, or reusable policy. If there is not, delete the stale reference and move on.
- Don't judge a store or hook test without reading the global test setup first.
- Don't reap into a red suite.
- Don't skip the deliberate-break check because the suite is green. Green after deleting tests is the expected result whether you did it right or wrong.
- Don't rename a test to match what it actually asserts and call that a fix. It just makes the coverage gap harder to find later.
- Don't count success in cases removed. The goal is a suite where a passing run means something.
- Don't clear a mocked-collaborator test because its call-check is detailed. Find the test for the other half of the contract first.
- Don't call a sweep clean because every test passed the one-at-a-time checks. A suite with no weak tests can still have a seam nothing crosses.
