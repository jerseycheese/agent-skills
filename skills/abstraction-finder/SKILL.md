---
name: abstraction-finder
description: >
  Scans a codebase or a named area for recurring patterns that could be extracted into shared,
  general-purpose code, and proposes the smallest form for each — helper, service, base class,
  template, or util — with the exact call sites it would replace. The inverse of a conformance
  check: it discovers duplication worth unifying rather than checking one change against existing
  patterns. Enforces the rule of three and refuses to abstract single-use or surface-similar code.
  Trigger on: "where are we repeating ourselves", "what could be abstracted", "find duplication",
  "is there a shared helper for this", "could this be DRY'd up", "extract a common pattern",
  "find abstraction candidates".
---

# Abstraction Finder

Find repetition that has earned an abstraction, then propose the smallest general-purpose form of
it. Scan the code (whole repo or a named area), cluster genuine duplicates, and for each cluster
propose a shared helper/service/base class/template/util with the concrete call sites it replaces.

The point isn't to list every near-match — it's to surface a short set of extractions that remove
real duplication without over-abstracting. This is the counterweight to `kiss`: `kiss` strips a
change to its minimum and resists new abstractions; this skill argues *for* an abstraction, but only
once the duplication is real and repeated. Hold both — the target is the abstraction the code has
actually earned, not the one you can imagine needing.

## Scope first

State what you're scanning before you scan — the whole repo, a directory, a domain, one feature —
and list it so the user can confirm you're pointed at the right code. A whole-repo scan is noisy; a
scoped scan is actionable. Ask for a scope if the user didn't give one.

## Process

1. **Find repetition.** Search for near-identical logic, duplicated markup, parallel utilities, and
   copy-paste clusters within the scope.
2. **Read the real occurrences.** Surface similarity is not sameness — two functions can look alike
   and differ in a way that matters. Open each candidate before calling it a duplicate. (This is
   `evidence-check` territory: "these are duplicates" and "no existing helper covers this" are
   claims to confirm by reading, not assert from memory.)
3. **Cluster and count.** Group true duplicates and record every call site (`file:line`). Count is
   the primary signal: three or more genuine occurrences is a candidate, two is a watch-item, one is
   not a duplicate.
4. **Check the rule of three and what already exists.** Before proposing anything, confirm the
   language/framework or an existing shared helper doesn't already cover it. Don't reinvent what the
   stack provides. Two occurrences is a coincidence; three is a pattern. The exception: if two known
   sites are already *drifting* (the same fix had to be applied in both, or they've started to
   disagree), unify early — drift is itself a reason.
5. **Propose the smallest form.** For each qualifying cluster: its shape (helper / service / base
   class / template / util), where it lands, a concrete signature, and the call sites it replaces.
6. **Weigh the trade-off.** Name the cost (indirection, coupling, a new thing to maintain) against
   the benefit (call sites removed, single source of truth). Not every duplicate is worth
   collapsing.

## Adapting to the project

If the project documents its stack or conventions (CLAUDE.md, AGENTS.md, a contract file, a
component library), let that shape the proposal:

- **Stack** decides the form an abstraction should take — a service with DI vs. a free function, a
  base class vs. a trait/mixin, a component vs. a duplicated template. Propose only forms the stack
  supports.
- **Canon / component library** decides where a proposed abstraction lands, so it follows the
  conventions of the shared code already there instead of being patched at a call site.

If none of that is documented, propose the language-idiomatic form and say the landing location is a
judgment call.

## Output Format

### Scope
One line: what was scanned and roughly how much.

### Abstraction Candidates
Ranked by strength (occurrence count × divergence risk):

| Candidate | Occurrences | Locations | Proposed form | Lands in |
|-----------|-------------|-----------|---------------|----------|
| [what repeats] | [N] | [file:line, ...] | [helper / service / base class / template / util] | [path] |

### For each candidate
- **What repeats:** the duplicated logic/markup, plainly.
- **Proposed abstraction:** the smallest general-purpose form, with a concrete signature or sketch.
- **Call sites it replaces:** the specific occurrences.
- **Trade-off:** benefit vs. cost, and whether it's worth doing now.

### Watch-items (below the bar)
Clusters with only two occurrences, or duplicates whose divergence makes a shared form awkward. Note
them but recommend waiting for a third occurrence (rule of three).

### Do-not-abstract
Where surface similarity is *not* true duplication — the code looks alike but the cases differ in a
way a shared abstraction would obscure or wrongly couple. Calling these out prevents a bad extraction
as much as proposing a good one earns a good one.

## Rules

- Never propose an abstraction for a single call site ("we might need this later" is not a reason).
- Confirm duplicates by reading them, not by name similarity.
- Prefer what the framework/standard library already provides over a new custom utility.
- A proposal is a candidate for a human to approve, not a change to make unprompted.

## When Not to Use

- Reviewing whether *one specific diff* conforms to the project's existing conventions (naming,
  structure, style) — that's a line-by-line conformance review of a change, not a duplication scan.
  (Note: "is there already a shared helper for this?" is *in* scope — answering it is how this skill
  decides whether to propose an extraction or point at what already exists.)
- When the user wants a simplicity pass on a diff — use `kiss`.
- Mid-feature — finish the feature; an extraction sweep is its own focused pass.

## Related Skills

- **Counterweight to** `kiss` — `kiss` resists new abstractions and trims a change to its minimum;
  this skill argues for an abstraction once duplication is real and repeated. The target is the one
  the code earned.
- **Overlaps with** `code-health-audit` — the audit's "overengineering" category is the mirror image
  (abstraction with one caller); this skill is the DRY side (one abstraction missing under N
  copies). Use the audit for a broad sweep, this for a focused DRY pass.
- **Pairs with** `evidence-check` — "these are duplicates" / "no existing helper" are claims; confirm
  by reading the code.
- **Feeds** `dead-code-cleanup` — collapsing duplicates into one shared form often orphans the old
  copies; clean them up after.
