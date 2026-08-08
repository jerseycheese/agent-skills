---
name: issue-maintenance
description: >
  Periodic and on-demand maintenance pass over a repo's open GitHub issue backlog. Re-labels
  miscategorized or unlabeled issues (bug/enhancement/question/invalid/duplicate) and bug
  lifecycle labels (needs-repro/needs-info) following the same decision logic as Anthropic's own
  dogfooded triage-issue command; re-scores every open issue with prioritize-issues' value/effort/
  age rubric and writes the resulting priority:high/medium/low/post-mvp label; applies mechanical
  plain-language fixes (AI-tell swaps, filler removal) to issue title/body via the
  plain-language-audit skill and surfaces jargon/verbosity/tone judgment calls for review.
  Auto-applies high-confidence changes, flags ambiguous ones in a single tracking issue. Unlike
  prioritize-issues (read-only ranked report) or analyze-issue (single-issue technical spec), this
  skill WRITES to issues. Needs no repo clone — GitHub issue metadata only, via gh. Trigger on:
  "run issue maintenance", "maintain the issue backlog", "clean up and re-prioritize issues",
  "issue maintenance pass", "tidy the backlog", "weekly issue maintenance", "re-label and
  re-prioritize open issues".
---

# Issue Maintenance

`prioritize-issues` reports; `analyze-issue` specs out one issue for implementation. This skill
maintains — it mutates the backlog: labels, priority, and issue text. Three passes, one report.

## 0. Prerequisites

- `gh` authenticated for the target repo.
- No repo clone. Everything here is issue metadata (title, body, comments, labels) via `gh issue`
  — skip the `mktemp -d` / `gh repo clone` step entirely, unlike `code-health-audit`'s and
  `plain-language-audit`'s scheduled pattern. This skill never touches source files.

## 1. Discover the repo

```bash
gh repo view --json nameWithOwner -q .nameWithOwner   # if not specified
```

## 2. Fetch the backlog and the real label set

```bash
gh issue list --state open --limit 200 --json number,title,labels,createdAt,updatedAt,body,milestone,comments
gh label list
```

Paginate past 200. Cache the label list — every `--add-label` below must come from it verbatim.
Never invent a label. If a label this workflow wants (`needs-repro`, `needs-info`, `duplicate`,
any `priority:*`) doesn't exist in this repo, skip that operation for the whole run and say so
once in the report ("not configured in this repo") — don't repeat the note per issue.

## 3. Issue selection — who gets the deep-dive

Pass 4 (priority) always scores the *entire* open backlog every run — tiers are relative
(terciles), so closing or opening other issues shifts tier boundaries even for issues that didn't
themselves change. That data comes free from the bulk list call above; no extra cost.

Pass 3 (labels) and Pass 5 (wording) don't need a full re-check every run — an issue's own label
or text doesn't depend on the rest of the backlog, and re-fetching comments plus re-running triage
on an issue nobody touched since last week is pure waste. Build the deep-dive set as:

- Every issue whose `updatedAt` (or newest comment) is after the `Last run:` timestamp recorded in
  the prior tracking issue (see §6) — these are the issues that plausibly changed.
- Plus a small random sample (~5) of the issues with the *oldest* `updatedAt` among everything not
  already selected — a drift-catcher. Pure incremental selection would never revisit an issue that
  got mislabeled once and never received a new comment again; this bounds that risk without
  re-scanning the whole backlog every time.
- First run: no `Last run:` timestamp exists yet. Deep-dive the whole backlog once — this run will
  look bigger than steady-state, that's expected (see §7 in the parent plan / verification step).

Deep-dive = `gh issue view [N] --json number,title,body,labels,comments` for each selected issue.

## 4. Pass 1 — Label triage

For each selected issue, decide against the cached label list from §2:

- **Category label** — exactly one of `bug`/`enhancement`/`question`/`invalid`/`duplicate`. Only
  touch it if the issue is unlabeled or clearly miscategorized — don't relitigate a plausible
  existing label. `duplicate` applies only when an obviously-duplicate open issue surfaces
  incidentally during triage; this is not a duplicate-detection sweep (out of scope, see §9).
- **Lifecycle labels** (bugs only) — `needs-repro` if no reproduction steps, error text, or logs
  are present anywhere in body+comments; `needs-info` if environment/version/follow-up details are
  missing. Remove either once a comment supplies what was missing.
- **Never comment on the issue about a label change** — silent labeling only, matching Anthropic's
  own triage-issue command.
- **Conservative bias**: a false positive is worse than a miss. Genuinely torn between two
  categories, or between adding a lifecycle label and not → skip, flag in §6.

Apply: `gh issue edit [N] --add-label "x" --remove-label "y"`.

## 5. Pass 2 — Plain-language pass on title+body only (never comments)

Same selected set as Pass 1. Apply `plain-language-audit`'s three lenses to the issue's title and
body:

- **Auto-fix** — only its "unambiguous" bucket (mechanical AI-tell phrase swaps like deleting "It
  is important to note that" or "utilize"→"use", and clear redundant filler removal). Preserve
  everything else in the body verbatim — checklists, formatting, all of it.
- **Judgment calls** — jargon rewrites, verbosity trims, and any tone rewrite stay flagged, never
  auto-applied, exactly as `plain-language-audit` treats them everywhere else.
- **Never apply the `voice` skill's rewrite here**, even for judgment calls someone approves later.
  Issue title/body is frequently someone else's authored report, not the maintainer's own prose —
  a deliberately tighter restraint than `plain-language-audit`'s default for repo docs.

Apply: `gh issue edit [N] --body "..."` (and `--title "..."` if the pattern is in the title).

## 6. Pass 3 — Re-prioritization

Reuse the value/effort/age-bonus rubric verbatim from `prioritize-issues`:

```
score = (value * 2) / (effort + 1) + age_bonus
```

(See `prioritize-issues`'s SKILL.md for the full value/effort/age-bonus point tables — don't
duplicate them here, just apply them.)

Score every open issue from §2's bulk fetch (no deep-dive needed — title/body/labels/age are
already in hand). Rank the backlog and split into terciles: top third → `priority:high`, middle
third → `priority:medium`, bottom third → `priority:low`. Override with `priority:post-mvp`
regardless of score when the issue shows an explicit deferral signal (body/title says
"post-MVP"/"v2"/"later", or its milestone targets a future phase).

- No existing `priority:*` label → apply the computed tier directly (high confidence).
- Existing label's tier ≠ computed tier → **flag** in §7, don't overwrite — someone may have set
  it for a reason not visible in the score. Matching tiers need no action.

## 7. Confidence policy — what auto-applies vs what's flagged

| Change | Auto-apply | Flag instead |
|---|---|---|
| Category label | unlabeled or clearly miscategorized | genuinely ambiguous between two |
| Lifecycle label | clear presence/absence of repro/env info | partial or unclear signal |
| Plain-language | exact mechanical swap from the unambiguous bucket | any jargon/verbosity/tone call |
| Priority | no existing priority label | existing label's tier ≠ computed tier |

## 8. Reporting — one tracking issue per run

- Find the prior run: `gh issue list --state open --search "Issue maintenance run in:title"`,
  confirm it's genuinely still open via `gh issue view [N] --json state` (search index can lag).
- Title: `Issue maintenance run — <YYYY-MM-DD>`.
- Body sections: summary counts; **Auto-applied** (checklist, one line per issue with the change);
  **Flagged for review** (checklist, one line per issue with the specific call and the two
  options); **Repo notes** (labels not configured, anything skipped); a `Last run: <ISO
  timestamp>` line — the cursor §3's incremental selection reads on the next run; a link to the
  superseded run.
- Label the tracking issue from the existing set if one genuinely fits (e.g. `documentation`);
  otherwise leave it unlabeled rather than inventing a `maintenance` label.
- Close the prior run once confirmed still open: `gh issue close [N] --comment "Superseded by
  #<new>."`.
- First run: no prior issue exists — skip the supersede step, note "first run" in the body.

Batch deep-dive `gh` calls in chunks of ~20 with a brief pause between chunks if a run gets large
(a big incoming batch of new issues, or the first run) — no need for anything fancier than that to
stay clear of GitHub's secondary rate limits.

## 9. Out of scope for v1

Duplicate-detection sweeps, stale-issue auto-closing, and cross-repo runs. These are reasonable
future extensions but not part of this pass — don't build them in speculatively.
