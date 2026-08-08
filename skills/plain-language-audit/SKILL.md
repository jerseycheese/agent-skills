---
name: plain-language-audit
description: >
  Sweeps a codebase's text — comments, docstrings, markdown docs, and user-facing UI copy — for
  jargon that could be plainer, AI writing tells/tropes, and verbose text that could be tightened.
  Auto-fixes unambiguous swaps, surfaces judgment calls for review. Trigger on: "jargon audit",
  "plain language audit", "find jargon", "sounds too technical", "AI tells", "AI slop in the docs",
  "sounds like AI wrote this", "too wordy", "make this more concise", "simplify this copy",
  "plain-language sweep". For code correctness/structure issues (fake fallbacks, dead logic), use
  dead-code-cleanup or code-health-audit instead — this skill is prose/tone only.
---

# Plain Language Audit

A sweep for text that's harder to read than it needs to be — jargon standing in for a plainer word, AI writing tells that make prose sound generated instead of written, and verbosity that says less in more words. Covers code comments, docstrings, markdown docs, and user-facing UI copy/strings.

This is the prose counterpart to `doc-rot` (which fixes docs that are *wrong*) and `code-health-audit` (which fixes code that's *overengineered*) — this one fixes text that's *hard to read*, whether or not it's accurate.

**Developer-facing text** (comments, docstrings, internal docs, PR/issue prose) gets the full treatment: plain language, AI-tell removal, tightening, and — where genuinely a rewrite rather than a mechanical swap — the user's own voice (apply the `voice` skill, canon at `~/.agents/voice.local.md`).

**User-facing UI copy** (button labels, error messages, empty states, in-app strings) gets plain language, AI-tell removal, and tightening only — never the developer-voice rewrite. It's a different audience with its own conventions (see the `design:ux-copy` skill if one's installed); don't impose "sounds like Jack" on a "Forgot password?" link. UI copy findings always go in the judgment-call bucket below, never auto-fixed.

## Pre-flight

Per the user's git workflow: `git fetch && git status`, confirm the right base branch and that it's synced. Then scope it — don't boil the ocean. State what's in range (a directory, a domain, recently-touched files) and confirm before sweeping a whole repo.

Check for an existing audit-memory file (`docs/audit-memory.md` or `.audit-memory.md` — the same file `code-health-audit` uses, just a different section). It records what was already flagged and declined; don't re-surface rejected findings. Create the file at the end if it doesn't exist.

## The three lenses

### 1. Jargon / plain language

If `vale` is installed (`command -v vale`), run it first — Vale can absorb style packages ported from [proselint](https://github.com/amperser/proselint) and [write-good](https://github.com/btford/write-good), which already cover jargon, wordiness, clichés, and hedging mechanically. It's a real deterministic pass, cheap to run before spending a semantic read on the same ground. If it's not installed, don't ask the user to add a new per-project dependency for this — just skip straight to the read.

Either way, follow with a read: unexplained internal jargon (acronyms, domain terms used without context), and technical phrasing where a plainer word does the same job. Vale won't catch project-specific jargon on its own — that's a judgment call regardless of tooling.

### 2. AI tells / tropes

Cheap grep-first pass, then verify each hit in context (a real technical term isn't a tell just because it's on a list):

```bash
# Overused AI vocabulary (source: "Why does ChatGPT delve so much?" + 2026 AI-tell trackers)
grep -rniE '\b(delve|intricate|meticulous|elevate|foster|tapestry|realm|navigate[sd]?|landscape|pivotal|resonate[sd]?|testament|underscore[sd]?|showcas(e|ing)|paramount|unwavering|commendable|compelling)\b' .

# Metaphor-noun pileups
grep -rniE '\b(tapestry|mosaic|ecosystem|symphony|labyrinth|beacon|cornerstone|kaleidoscope|odyssey|cacophony)\b' .

# Hedge-phrase templates
grep -rniE "(it is important to note that|in today's fast-paced|navigating the complexities of|plays a crucial role in|a wide range of)" .

# Em-dash overuse (a handful in a whole file is normal prose; a cluster per paragraph is a tell)
```

Canon, in priority order:
1. `~/.agents/voice.local.md`'s living "AI smell" list, if the file exists — read it, don't copy its private contents into this shared skill file.
2. This skill's own built-in list above, seeded from current (2026) AI-tell trackers, for projects/users without that file.

**Stay current:** do one `WebSearch` per run for recent AI-tell discussion (the trackers that seeded the list above are themselves living pages, worth a re-check) rather than trusting a frozen list indefinitely. If it surfaces a pattern not already on file, propose appending it to `voice.local.md`'s living list — ask before editing that file, it's personal and outside this repo.

### 3. Verbosity

Semantic read pass — no reliable grep for "says less in more words." Measure against `voice.local.md`'s "Length & Density" budgets where the file's available (it gives per-artifact word/paragraph targets); otherwise look for redundant qualifier stacking, filler ("in order to," "it's important to note that," "due to the fact that"), and sentences that could lose a third of their words without losing meaning.

## Categorize and act

**Auto-fix** (unambiguous, meaning fully preserved):
- Mechanical AI-tell phrase removal/swap (e.g. delete "It is important to note that," swap "utilize" → "use").
- Clear redundant filler removal.

**Judgment calls** (propose and confirm):
- Jargon rewrites — picking the plainer word is a judgment call, not mechanical.
- Verbosity trims that risk losing nuance.
- Any tone/voice rewrite that requires rephrasing rather than deletion.
- **All UI copy changes**, regardless of confidence — user-facing, higher-risk to touch unattended.

Present judgment calls as a triaged list — `file:line`, what's wrong, proposed fix — then apply what's approved.

## Verify and commit

Re-run the grep checks after edits to confirm the flagged patterns are actually gone. If the project lints prose (Vale, markdownlint) or comments (eslint jsdoc rules, etc.), run it. Focused commits by category, in the user's voice (apply the `voice` skill):
- `docs: cut AI-tell phrasing and filler from README`
- `docs: plain-language pass on <module> docstrings`

Update the audit-memory file with what shipped and what was declined, so the next run doesn't re-flag it.

## Periodic / scheduled runs

The behavior above is for interactive, on-demand runs — auto-fix is fine because someone's watching. A scheduled/cron run is different: no one's watching, so it should be **report-only**, no auto-fix at all, even for the "unambiguous" bucket. Follow the `weekly-narraitor-code-health` scheduled-task pattern: work from a throwaway clone, rank findings, file one GitHub issue, supersede the prior run's issue. Set this up per project via the `schedule` skill once the on-demand skill's been proven on a manual run against that project — don't stamp out a cron task blind.

## Don't

- Don't rewrite UI copy into developer voice — different audience, different conventions.
- Don't flag a technical term as jargon just because it's technical; flag it when a plainer word exists and loses nothing.
- Don't auto-fix a verbosity trim that changes what a sentence actually claims — that's a judgment call.
- Don't add a Vale dependency to a project that doesn't already have it — use it opportunistically, not as a new requirement.
