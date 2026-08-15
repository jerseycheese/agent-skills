---
name: comment-reaper
description: >
  Finds and removes unnecessary code comments - the ones that restate the code, cite an issue
  number, narrate refactor history, or wrap a one-line function in six lines of JSDoc. Sorts every
  find into auto-fix, propose, or never-touch, so the WHY comments survive the sweep.
  Trigger on: "comment reaper", "reap comments", "remove unnecessary comments", "too many comments",
  "verbose comments", "clean up the comments", "strip redundant JSDoc", "comment audit",
  "comment hygiene", "our comments are noise".
  For comments that are WRONG rather than merely unnecessary, use doc-rot. For comments that are
  hard to READ rather than unnecessary, use plain-language-audit.
---

# Comment Reaper

Most comment cleanup fails one of two ways: it deletes a comment that was carrying a constraint nobody could reconstruct, or it stops at commented-out code and calls the job done. This skill exists because the second failure is the common one in a well-kept repo. The obvious rot is already gone; what remains is comments that are *technically accurate and still worthless*.

The rule this enforces is in the user's CLAUDE.md under "Code hygiene: comments & naming": explain WHY, not WHAT. That file names issue/PR citations as "the single most common violation of this section," and until this skill existed nothing looked for them.

The core discipline, inherited from `doc-rot`: **a comment is not reapable because it looks obvious. It is reapable because the code already says it.** Those differ. Read the code under the comment before cutting.

## Sibling skills, so you don't do their job

- `doc-rot` fixes comments that **contradict** the code. If the comment is wrong, that's rot, not bloat - hand it over.
- `plain-language-audit` fixes comments that are **hard to read**. Jargon and verbosity are quality problems; this skill is an existence problem.
- `dead-code-cleanup` removes the code itself. If the function is dead, reap the function, not its docblock.

A comment can qualify for two skills at once. When it does, deletion wins: don't spend a rewrite on a comment that shouldn't exist.

## Pre-flight

1. `git fetch && git status`. Confirm the base branch (`develop` if it exists, else `main`) and that you're current. Auditing a stale checkout is the most common way this work gets wasted.
2. Scope it and say the scope out loud. A directory, a domain, the files a recent change touched. Do not sweep a whole repo in one pass - the diff becomes unreviewable and one bad deletion poisons the whole thing.
3. Get the numbers before you touch anything. If the repo has an audit script (`npm run audit:comments`), run it. Otherwise use the grep block below. You want a before count so the after count means something.

## Detection

Prefer the repo's audit script when one exists. These are the fallback, and the definition of record for what each tier means:

```bash
# Tier 1: issue/PR citations in comments (strip the number, keep the prose)
grep -rnE '^\s*(//|\*|/\*).*#[0-9]{2,5}' src/
grep -rniE '^\s*(//|\*).*(fixes|closes|issue|ticket|PR) #[0-9]+' src/

# Tier 1: section-divider banners
grep -rnE '^\s*//\s*[-=*]{3,}' src/
grep -rnE '^\s*//\s*[-=]+ .* [-=]+\s*$' src/

# Tier 1: malformed JSDoc (doubled terminators)
grep -rnE '\*/\s*\*/' src/

# Tier 2: archaeological comments (verify each - "used to" is usually present tense)
grep -rniE '(extracted from|moved from|refactored out|formerly|previously|used to be|renamed from|as of [0-9])' src/

# Tier 2: single-line JSDoc on a following function (candidate redundant docblock)
grep -rn -A1 -E '^\s*/\*\* [^*]+ \*/\s*$' src/ | grep -B1 -E '(function|const|export|=>)'

# Context: comment density by file, worst first
for f in $(find src -name '*.ts' -o -name '*.tsx'); do
  total=$(wc -l < "$f"); c=$(grep -cE '^\s*(//|\*|/\*)' "$f")
  [ "$total" -gt 40 ] && [ "$c" -gt 0 ] && echo "$((c * 100 / total))% $c/$total $f"
done | sort -rn | head -20
```

**Restating-the-code** is the one pattern grep can't find on its own, and it's usually the biggest bucket. The test: take the comment's content words, take the identifiers on the next non-blank line, and check the overlap. `// Add attribute` above `addAttribute:` is a total match and a certain reap. Do this by reading, or with a script if the repo has one.

## The three tiers

### Tier 1 - reap without asking

Mechanical. No judgment, no context needed, safe to apply in a batch.

- **Bare issue/PR citations.** Strip the `(#1234)`, `Issue #971`, `Fixes #423`. **Keep the surrounding prose.** The number is the violation; the sentence around it is often a genuine WHY. Deleting the whole comment because it contains a number is the most likely way to do damage here.
- **Restating-the-code.** The comment's words are all present in the identifiers below it. Delete the comment. Don't rename the identifier to compensate - if the name is bad, that's a separate change.
- **Section-divider banners.** `// === DATE FORMATTING ===`, `// --- Adopt handlers ------`. A file that needs internal signposting is a file that wants splitting; the banner just hides that. Delete the banner, note the file as a possible split candidate, don't split it here.
- **Malformed comment syntax.** Doubled `*/`, unterminated blocks, JSDoc that isn't attached to anything. These are defects, not style.

### Tier 2 - propose in one batch, then apply what's approved

Present these as a single triaged list with `file:line`, the current text, and the proposed action. Do not drip-feed them one at a time.

- **Redundant JSDoc on functions.** `/** Get client IP address from request headers */` above `getClientIP(request)`. Reap when the name already says it. **Keep** when `@param` or `@returns` documents something the signature can't express: a unit, a range, a nullable contract, a thrown error.
- **Archaeological comments.** Usually reapable, with a real exception: some history is a live constraint wearing a costume. "Every store used to gate this on NODE_ENV alone, which was insufficient because X" is a WHY, and X is still true. Don't delete it - rewrite it in present tense and drop the history.
- **Doc-shrine headers.** A 50-line JSDoc block over six re-export lines, or full `@param`/`@returns`/`@example` treatment on a private helper. Propose collapsing to the load-bearing lines. Never bulk-strip a header: they usually contain one or two real constraints buried in ceremony.
- **File-header blocks** that restate the filename and nothing else.

### Tier 3 - never touch

- **Issue numbers that anchor a regression test's reason for existing.** `Regression test for #1206: markSessionEnded used to call eval(require(...))` is not a citation violation. The number *is* the information; without it the test looks arbitrary and the next person deletes it. This is the single most important carve-out in the skill.
- **Field-level JSDoc on type and interface definitions.** In a repo without a separate data-model spec, these *are* the spec, and IDE hover consumes them. Density there is a feature.
- **The CLAUDE.md "do write" list**: design rationale, `SECURITY:` markers, performance constraints, external-API quirks, and actionable `TODO(#N)` comments that carry a ticket and a consequence.
- **Any comment whose WHY you cannot reconstruct from the code.** Straight from `doc-rot`, and it's the backstop for everything above. When in doubt, keep. An unnecessary comment costs a few seconds of reading. A deleted constraint costs an outage.

## Verify

- Run the audit script again. Report before and after counts per tier - that's the evidence the sweep worked, and it's cheap.
- `npm run lint` (comments can carry eslint directives; deleting one silently re-enables a rule) and `npm run type-check`.
- Full test suite if any file with a `SECURITY:` or constraint comment was touched.
- `git diff` should be **deletions and one-line edits only**. A comment reap that adds lines has turned into a refactor - stop and split it.

## Commit and ship

Focused commits, in the user's voice (apply the `voice` skill):

- `Strip issue-number citations from comments - git blame already has them`
- `Drop comments that restate the line below them`
- `Collapse the toast index docblock - 54 lines of JSDoc over 6 exports`

Run `kiss` on the diff before opening the PR. A comment sweep attracts drive-by fixes, and this is exactly the diff where a smuggled behavior change hides best.

## Don't

- Don't delete a comment because it contains `#1234`. Strip the number, keep the sentence.
- Don't rewrite a comment you could delete. If it's Tier 1, it goes; polishing it is wasted work.
- Don't sweep a whole repo in one PR. Scope by directory and let each one be reviewable.
- Don't touch a comment and its code in the same commit. Deletions are trivially reviewable right up until behavior changes ride along.
- Don't add comments explaining what you removed. Git remembers.
- Don't count success in lines deleted. A sweep that removes 200 noise lines and one constraint is a net loss.
