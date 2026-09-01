---
name: band-aid-finder
description: >
  Scans a change or codebase area for band-aid fixes that suppress a symptom instead of resolving
  the underlying cause, traces each to its actual root cause, and proposes the fix that addresses it.
  Distinguishes a band-aid from a deliberate, documented mitigation (incident hotfix, third-party
  defect, cost-outweighs-benefit) so it doesn't dogmatically demand a root-cause fix. The
  counterweight to KISS: it argues against a fix so simple it only hides the symptom.
  Trigger on: "is this a real fix or a band-aid", "am I treating the symptom", "why does this keep
  happening", "this feels hacky", "find the root cause", "search and destroy quick fixes",
  "is this a workaround".
---

# Band-Aid Finder

A band-aid stops the bleeding without treating the wound: the symptom disappears, the defect stays,
and it resurfaces later or somewhere else. This skill finds those fixes, traces the symptom back to
its cause, and pushes to the fix that actually resolves it — while still allowing a *deliberate,
documented* mitigation when a root-cause fix genuinely isn't the right move right now.

This is the counterweight to `kiss`. KISS argues against a fix more complex than the problem needs;
this skill argues against a fix so simple it only hides the symptom. The target is the simplest fix
that still reaches the cause — neither the smallest diff nor the largest refactor.

## Process

1. **Identify the symptom and the fix.** What visible problem is being addressed, and what does the
   change actually do?
2. **Trace to the root cause.** Follow the symptom back to *why* it occurs. Confirm the cause by
   reproducing it or reading the code path — don't assert it from a guess. (This is squarely
   `evidence-check` territory: "the root cause is X" is an Unverified claim until you've read the
   path or run the repro this session. Naming a plausible cause is not confirming it.)
3. **Classify the fix** against the band-aid signals below.
4. **Judge: band-aid or real fix?** A fix that resolves the traced cause is real, even if small. A
   fix that leaves the cause in place and only hides its effect is a band-aid.
5. **Check for a legitimate mitigation.** Sometimes suppressing the symptom *is* the right call for
   now (see below). If so, it must be documented as deliberate with a follow-up — not left silent.
6. **Propose the root-cause fix** concretely: where the real defect is and the change that resolves
   it, landing in the right layer rather than patched at the call site.

## Band-aid signals

- **Swallowed errors** — `catch`/`except` that logs-and-continues or silently ignores, hiding a
  failure instead of handling or fixing its cause.
- **Defensive guard patches** — a null/undefined check added at the crash site when the real
  question is *why the value is missing* upstream.
- **Special-case hardcoding** — `if (id === 42)` for the one input that breaks, instead of fixing
  the logic that mishandles that class of input.
- **Retry / timeout bumps** — retrying or raising a timeout to paper over a race, deadlock, or slow
  query that has a real cause.
- **Suppression pragmas** — `!important`, `// eslint-disable`, `@ts-ignore`, `@phpstan-ignore`,
  `except: pass` to silence a warning rather than resolve what it flags.
- **UI-layer masking** — hiding or restyling an element to cover a rendering/data bug instead of
  fixing the data or logic behind it.
- **"Temporary" workarounds** — a `// TODO: fix properly` that suppresses the symptom and ships with
  no tracked follow-up.

## Legitimate mitigations (not every quick fix is a band-aid)

A symptom-level fix is defensible when it's a *deliberate, documented* choice:

- **Incident hotfix** — stop the bleeding now, root-cause fix tracked as a follow-up. Legitimate if
  the follow-up actually exists.
- **Third-party defect** — the cause is in a dependency you can't change; a local workaround with a
  link to the upstream issue is the correct fix available to you.
- **Cost outweighs benefit** — the true fix is a large, risky change disproportionate to a low-impact
  symptom; a contained mitigation is a reasonable trade-off.

In all three the mitigation must be **labeled as deliberate** — a comment stating why, plus a tracked
follow-up where warranted. The failure mode isn't the mitigation; it's the *silent* mitigation that
reads like a real fix and buries the defect.

## Output Format

### Symptom & Fix
One line each: the visible symptom, and what the change actually does.

### Root Cause
The traced cause with its evidence (repro, the code path, the failing condition). If you can't
confirm the cause, say so plainly rather than guessing.

### Verdict
One of: **Root-cause fix** (resolves the cause) / **Band-aid** (suppresses the symptom, cause
remains) / **Deliberate mitigation** (symptom-level but a defensible, documented trade-off).

### For a band-aid
- **What it hides:** the defect left in place and where it will resurface.
- **Root-cause fix:** the concrete change that resolves the cause, and the layer it belongs in.
- **If shipping a mitigation instead:** what to document and what follow-up to track.

## Rules

- Trace before you prescribe — a fix for a cause you haven't confirmed is itself a guess.
- Small is not the same as shallow: a one-line change that resolves the cause is a real fix.
- Never let a mitigation ship silently; deliberate is fine, disguised is not.
- The proposal is a recommendation for a human to weigh, not a change to make unprompted.

## When Not to Use

- A diff has simply crept beyond its scope with unrelated extras — that's a `kiss` pass.
- A test is failing and you need to fix it — use `test-fix` (which has its own attempt limit); come
  here only if the "fix" is suppressing the test rather than the defect.

## Related Skills

- **Counterweight to** `kiss` — KISS argues against a fix more complex than the problem needs;
  band-aid-finder argues against a fix so simple it only hides the symptom.
- **Pairs with** `evidence-check` — "the root cause is X" is a claim; confirm it by reproducing or
  reading the code path, don't assert it from a guess.
- **Guards** `test-fix` and `pr-review-fix-pipeline` — a fix that silences a symptom (or a test)
  rather than the defect is exactly what those pipelines should not ship; run this lens on their
  proposed fixes.
- **Complements** `code-health-audit` — the audit sweeps for accumulated cruft; this skill judges
  whether a specific fix reaches its cause.
