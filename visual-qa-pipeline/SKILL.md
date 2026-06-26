---
name: visual-qa-pipeline
description: >
  Turns a visual QA crawl into shipped work: crawl the running app, triage findings by severity,
  file Major+ findings as GitHub issues with screenshots, batch the small stuff into one roll-up
  issue, and optionally open fix PRs for mechanical design-system violations. Runnable on a schedule.
  Trigger on: "visual QA pipeline", "crawl and file issues", "autonomous visual QA",
  "visual QA to PR", "screenshot the app and open issues", "nightly visual QA", "ship visual fixes".
---

# Visual QA Pipeline

`visual-crawl` finds visual bugs but stops at a report. This skill takes that report the rest of the way — into GitHub issues and, for the safe mechanical stuff, fix PRs. It's the autonomous, schedulable wrapper around the crawl you already run by hand.

It does **not** reinvent screenshotting. The crawl mechanics — `bdg` setup, randomized breakpoints, audit checks, severity buckets — all come from `visual-crawl`. Read that skill and run its crawl as Phase 1 here; this skill is everything that happens after the findings report exists.

## Prerequisites

- Everything `visual-crawl` needs (`bdg` installed, dev server running, route list).
- `gh` authenticated for the target repo.
- For the screenshot-markdown step: the `github-screenshot` skill / `generate-github-image-markdown.sh` helper (it produces `raw.githubusercontent.com` URLs that render in issues and PRs).

## Phase 1 — Crawl

Run the full `visual-crawl` flow (see its SKILL.md). Don't shortcut it — the randomization is what gives cumulative coverage across runs, and its **target-identity guard** matters double here: an unattended pipeline run has no one watching the screenshots, so a `bdg` drift to the wrong tab would silently file issues against the wrong app. Verify `document.title` (or an app-specific selector) before every capture and abort on mismatch. You finish this phase with:
- A screenshot directory (`/tmp/visual-crawl-TIMESTAMP/`).
- A findings report grouped into Critical / Major / Minor / Component-Level / Design System Alignment / Observations.

## Phase 2 — Triage

Map every finding to an action. The crawl's severity buckets already do most of the sorting:

| Severity | Action |
|---|---|
| Critical | File its own issue, label `bug`, flag it in the handoff as needs-attention-now. Do **not** auto-fix — Critical means broken functionality, which needs a human call. |
| Major | File its own issue with before/after screenshots. Eligible for an auto fix PR **only** if it's a mechanical design-system fix (see Phase 4). |
| Minor / Cosmetic / Observation | Batch into a single roll-up issue, one checkbox per item. Don't spam one issue per cosmetic nit. |
| Design System Alignment | Fold into the roll-up issue unless it's a Major (e.g. bespoke UI where a canonical component exists at the wrong breakpoint). |

If a run turns up zero Major+ findings, skip Phases 3-4 and just post the roll-up (or note a clean run in the handoff). Don't open empty issues.

## Phase 3 — File issues

For each Major+ finding, create an issue. Reuse the `gh issue create` pattern and pick from **existing** labels (`gh label list`) — never invent new ones.

```bash
# Get a renderable screenshot URL (see the github-screenshot skill)
# generate-github-image-markdown.sh writes markdown pointing at raw.githubusercontent.com
gh issue create \
  --title "Visual: <page> @ <breakpoint> — <one-line symptom>" \
  --label "<existing-label>" \
  --body "$(cat <<'EOF'
## What

<symptom> on <page> at <breakpoint>.

## Screenshot

<image markdown from generate-github-image-markdown.sh>

## Where to look

<component / selector / file the crawl implicated>

## Severity

Major — <layout break / token violation / a11y failure>

Filed by the visual-qa-pipeline skill (run <timestamp>).
EOF
)"
```

Roll-up issue for the small stuff: one issue titled `Visual polish backlog — <date>`, body is a checklist (`- [ ] <page> @ <bp>: <nit>`), each line linking its screenshot.

Capture every issue number — the handoff lists them.

## Phase 4 — Optional fix PRs (mechanical only)

Only open a PR when the fix is unambiguous and mechanical — the kind `ds-guard` already pattern-matches: a hardcoded color/spacing/font value that should be a design token, a raw `<button>` that should be the canonical `Button`. Anything requiring a judgment call (layout restructure, "is this the right component", responsive redesign) stays an issue, not a PR.

For each eligible fix:
1. Branch off the synced base (`develop` if it exists, else `main`).
2. Apply the token/component swap. Run `ds-guard` on the diff to confirm it's on-system.
3. Verify in-browser at the breakpoint that exposed it — screenshot before/after.
4. Run the project's lint + tests (don't mask exit codes; check `$?`).
5. Open a PR with the repo's PR template filled in (`.github/PULL_REQUEST_TEMPLATE.md`), linking the issue it closes. Drive CI green. Follow the commit/PR conventions in `pr-review-fix-pipeline` and `post-merge`.

Keep PRs one-finding-each so they stay reviewable and revertable. Don't batch unrelated fixes.

## Phase 5 — Handoff report

End with a single summary:

```markdown
# Visual QA Pipeline — <project> — <date>

Run ID: <timestamp> · Pages: <list> · Breakpoints: <list>

## Filed
- #<n> Critical — <symptom> (needs attention)
- #<n> Major — <symptom>
- #<n> Visual polish backlog (<count> items)

## Fix PRs
- #<pr> — <fix>, CI <green/pending>, closes #<issue>

## Clean
- <areas that passed with no findings>
```

## Scheduling

This skill is built to run unattended, but scheduling lives outside it — use the native `/schedule` skill (e.g. "run visual-qa-pipeline on narraitor daily at 9am"). Don't bake cron into the skill. For an unattended run, confirm the dev server and route list up front in the scheduled prompt, since there's no one to ask mid-run.

## Out of scope (v1)

No baseline screenshot diffing. `visual-crawl` finds issues heuristically (computed-style checks, overflow detection, visual inspection), not by comparing against committed baseline images — this pipeline inherits that and needs no baseline store. Pixel-diff regression against a baseline is a possible future phase; don't build it now.

## Gotchas

- Inherit all of `visual-crawl`'s gotchas (shell quoting with `bdg dom eval`, `sleep 1` after resize, no `shuf` on macOS).
- Read screenshots with the `Read` tool before filing — don't file an issue off a programmatic check alone; confirm the bug is real and visible.
- A "finding" from a heuristic check (e.g. a hardcoded inline style) isn't always a bug. Verify it actually looks wrong before spending an issue on it.
- Never auto-fix a Critical. Broken functionality needs a human decision, not a token swap.
