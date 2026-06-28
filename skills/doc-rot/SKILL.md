---
name: doc-rot
description: >
  Sniffs out stale and deprecated documentation — markdown files, code comments, docstrings, and
  commented-out code — then updates or removes it. Grounds every staleness call against the actual
  code before acting: auto-fixes the high-confidence rot, surfaces judgment calls for review.
  Trigger on: "find stale docs", "outdated documentation", "doc rot", "doc sniffer", "clean up docs",
  "are the docs current", "deprecated docs", "fix the README", "stale comments", "remove commented-out code".
---

# Doc Rot

Documentation lies as the code moves on. This skill finds the lies and fixes them — across `*.md` files, inline comments, docstrings, and commented-out code. It's the docs counterpart to `dead-code-cleanup`, and it enforces the comment hygiene rules in the user's CLAUDE.md ("explain WHY not WHAT"; "one canon version per file"; "update existing docs, don't proactively create new ones").

The core discipline: **a doc isn't stale because it looks old — it's stale because it contradicts the code.** Ground every call against the actual codebase before flagging it. A "removed" symbol might just be renamed; a "broken" path might live elsewhere now.

## Pre-flight

Per the user's git workflow: `git fetch && git status`, confirm you're on the right base branch (`develop` if it exists, else `main`) and up to date. Then scope the doc set — don't boil the ocean. List what's in range (a directory, the README, the files a recent change touched) and confirm before sweeping a whole repo.

## What counts as rot

### Doc files (`*.md`)
- **References to things that no longer exist** — files/paths, npm scripts, CLI flags, config keys, env vars, API/function names. Verify each against the code before flagging.
- **Stale setup/usage steps** — install commands, toolchain versions, ports, or workflows the code has moved past.
- **Code examples that wouldn't run** — using removed or renamed APIs, old signatures, deleted imports.
- **Dead links** — broken internal anchors and relative file links (high confidence); external links (flag, don't chase every one).
- **Superseded / duplicate docs** — two docs covering the same thing, or a doc describing a feature that's gone. "One canon version per file" — pick the canonical one, fold or remove the rest.

### Comments & docstrings
- **Contradicts the code below it** — the comment says one thing, the code does another. Highest-value find; almost always a real bug-in-waiting.
- **Docstring drift** — `@param`/`@returns`/documented args that don't match the actual signature.
- **Anti-pattern comments** (per CLAUDE.md): archaeological ("Extracted from X to reduce complexity"), motion-tracking ("Moved from Y on DATE"), obvious ("increment counter" above `counter += 1`).
- **Stale TODO/FIXME** — referencing a closed issue or a condition that's already resolved.

### Commented-out code
- Just delete it. Git remembers. (Already an anti-pattern in CLAUDE.md.)

## Detection (cheap first passes)

```bash
# Commented-out code blocks (tune the comment syntax per language)
grep -rnE '^\s*(//|#)\s*(if|for|while|function|def|class|return|const|let|import)\b' src/

# Anti-pattern comments
grep -rniE '(extracted from|moved from|refactored out|formerly|used to be|as of [0-9])' src/

# Stale TODO/FIXME with issue refs (cross-check against closed issues)
grep -rnE 'TODO|FIXME|XXX|HACK' src/

# Relative links in markdown (then verify each target exists)
grep -rnoE '\]\(([^)]+\.(md|ts|tsx|js|json|sh|py))\)' --include='*.md' .

# Pull the nouns a doc references (paths, scripts, symbols), then grep the code for each
```

For each markdown doc, the real check is semantic: read the doc, extract its factual claims (this command, this path, this flag, this default), and verify each against the code. A bare grep won't catch "the default timeout is 30s" when the code says 10s — you have to read both.

## Validate before acting

This is where most false positives die — mirror the verify-before-acting discipline from `dead-code-cleanup`:

1. **"Gone" vs "moved/renamed."** Before flagging a reference as dead, grep the whole repo for it. A function may have been renamed, a file relocated, a script moved into a workspace package. Renamed → update the doc. Actually gone → remove or rewrite.
2. **Is the comment encoding a non-obvious WHY?** A comment that reads as "obvious" might capture a constraint that isn't visible in the code (a security note, an external-API quirk, a perf bound). Read the surrounding code before deleting. When in doubt, keep.
3. **Is this doc the only record of something still true?** Don't delete accurate-but-unloved docs just because they're old. Old and correct is not rot.
4. **External links** — a 404 might be transient. Flag, don't auto-delete.

## Categorize and act

**High confidence — auto-fix:**
- Commented-out code (delete).
- Archaeological / motion-tracking / obvious comments (delete).
- Broken internal links / references to files that definitively don't exist (fix the path, or remove the line if the target is truly gone).
- Docstring signature mismatches where the correct value is unambiguous (update to match).

**Judgment calls — propose and confirm:**
- Rewriting vs deleting a whole doc section or file.
- Deciding which of two duplicate docs is canon.
- A comment that contradicts the code — surface it; the fix might be the *code*, not the comment (don't silently "fix" the doc over a real bug).
- Anything where the right answer is "the feature changed and the prose needs rethinking," not a mechanical swap.

Present judgment calls as a triaged list with `file:line`, what's wrong, and the proposed action — then apply what's approved.

## Verify and commit

- After edits: re-run the link check; if the project builds its docs, build them; run lint if comments were touched.
- Focused commits by type, in the user's voice (apply the `voice` skill):
  - `docs: fix stale paths and dead links in README`
  - `docs: drop archaeological comments and commented-out code`
  - `docs: correct docstring drift in <module>`
- A comment that contradicts the code and turned out to be a real bug isn't a docs fix — flag it separately so it doesn't get buried in a docs commit.

## Don't

- Don't create new docs to "replace" rot — update in place (CLAUDE.md rule).
- Don't delete a comment whose WHY you can't reconstruct from the code.
- Don't flag a doc stale off a single failed grep — confirm the thing is actually gone, not moved.
- Don't auto-rewrite prose; mechanical fixes auto-apply, wording is a judgment call.
