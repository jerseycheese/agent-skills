---
name: issue-maintenance
description: >
  Periodic and on-demand maintenance pass over a repo's open GitHub issue backlog. Re-labels
  miscategorized or unlabeled issues (bug/enhancement/question/invalid/duplicate) and bug
  lifecycle labels (needs-repro/needs-info) following the same decision logic as Anthropic's own
  dogfooded triage-issue command; re-scores every open issue with prioritize-issues' value/effort/
  age rubric and writes the resulting priority:high/medium/low/post-mvp label; fills in missing
  sizing labels (complexity/model-power or the repo's equivalent) where the repo documents a
  convention for them; applies mechanical
  plain-language fixes (AI-tell swaps, filler removal) to issue title/body via the
  plain-language-audit skill and surfaces jargon/verbosity/tone judgment calls for review; clusters
  granular open issues that share a domain, keyword, or parent reference and, once a maintainer
  approves a specific batch, merges them into one appropriately-sized consolidated ticket and closes
  the originals into it — proposal-only until approved, distinct from duplicate detection.
  Auto-applies high-confidence changes, flags ambiguous ones in a single tracking issue. Unlike
  prioritize-issues (read-only ranked report) or analyze-issue (single-issue technical spec), this
  skill WRITES to issues. Needs no repo clone — GitHub issue metadata only, via gh. Trigger on:
  "run issue maintenance", "maintain the issue backlog", "clean up and re-prioritize issues",
  "issue maintenance pass", "tidy the backlog", "weekly issue maintenance", "re-label and
  re-prioritize open issues", "group similar issues", "cluster related issues", "combine similar
  issues into one ticket", "consolidate small issues".
---

# Issue Maintenance

`prioritize-issues` reports; `analyze-issue` specs out one issue for implementation. This skill
maintains — it mutates the backlog: labels, priority, and issue text. Five passes, one report.

## 0. Prerequisites

- `gh` authenticated for the target repo. If `gh` isn't installed (some hosted/cloud sessions),
  every step below has a GitHub MCP equivalent (`mcp__github__list_issues`, `issue_read`,
  `issue_write`, `get_label`) — same data, different transport. Say which you used in the report.
- No repo clone. Everything here is issue metadata (title, body, comments, labels) via `gh issue`
  — skip the `mktemp -d` / `gh repo clone` step entirely, unlike `code-health-audit`'s and
  `plain-language-audit`'s scheduled pattern. This skill never touches source files. The one
  exception is the label-convention doc in §4b, which is a single API file read, not a clone.

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

### 2b. Establish how this repo types its issues

Pass 2 groups label coverage **by issue type**, so the run needs to know what a "type" is here
before it can group anything. Two mechanisms exist and repos use one or the other:

- **GitHub native issue types** (Bug / Feature / Task and custom ones). There is no
  `gh issue type` subcommand — since `gh` 2.94.0 issue types ride on the ordinary commands
  (`--type` on create/edit, a type field on `list`/`view`), and before that they were reachable
  only through the API. Detect them with `gh api repos/{owner}/{repo}/issue-types` or
  `mcp__github__list_issue_types`. A 404 means this repo has none, which is the ordinary answer
  for a personal-account repo — issue types are configured at organization level. If the repo does
  have them, that is the typing mechanism: fetch the type per issue in the §2 bulk call.
- **A type label convention** — `epic`, `bug`, `enhancement`, `user-story`, `documentation`, and
  so on. The convention doc from §4b usually names these outright (Narraitor's `.github/labels.md`
  has a `## Type Labels` section listing exactly six). Use that list as the type mapping rather
  than inventing one from whatever labels happen to look type-ish.

Don't guess the JSON field name for native types — it arrived in `gh` 2.94.0 and older versions
don't carry it at all. Run `gh issue list --json` with no value and `gh` prints the valid field
names for the installed version; pick the type field from that list. Via MCP, check what
`list_issues` exposes and fall back to per-issue reads if the bulk call doesn't carry it.

**State the mechanism in the report**, once: "types read from native issue types" or "types read
from the label convention: `epic`, `bug`, …". A run that can't determine either **skips Pass 2's
coverage grouping entirely** and says so — it can still fill in labels that are missing from an
individual issue, but it must not claim a whole type is exempt, because it can't identify types.

## 3. Issue selection — who gets the deep-dive

Pass 4 (priority) always scores the *entire* open backlog every run — tiers are relative
(terciles), so closing or opening other issues shifts tier boundaries even for issues that didn't
themselves change. That data comes free from the bulk list call above; no extra cost.

Pass 2 (sizing) also sweeps the *entire* backlog, for a different reason: detecting a **missing**
label is a set-difference over the bulk fetch, not a judgment, so restricting it to recently-touched
issues would miss exactly the stale ones it exists to catch. Deciding the *value* for a missing
label does need the body — which the bulk fetch already carries.

Pass 1 (labels) and Pass 3 (wording) don't need a full re-check every run — an issue's own label
or text doesn't depend on the rest of the backlog, and re-fetching comments plus re-running triage
on an issue nobody touched since last week is pure waste. Build the deep-dive set as:

- Every issue whose `updatedAt` (or newest comment) is after the `Last run:` timestamp recorded in
  the prior tracking issue (see §8) — these are the issues that plausibly changed.
- **Minus the issues the previous run wrote to itself.** `updatedAt` moves when *anything* on the
  issue changes, including this skill's own `--add-label` calls, so a run that labels 15 issues
  guarantees its successor re-deep-dives all 15 for no reason. The prior tracking issue lists what
  it wrote (see §8); subtract that set. Only skip the subtraction if the issue changed again
  *after* the prior run finished — compare against the write, not just the run.
  A live example of the cost: a Narraitor run saw 23 issues past the cursor and only 10 had
  genuinely changed; the other 13 were the previous run's own label writes.
- Plus a small random sample (~5) of the issues with the *oldest* `updatedAt` among everything not
  already selected — a drift-catcher. Pure incremental selection would never revisit an issue that
  got mislabeled once and never received a new comment again; this bounds that risk without
  re-scanning the whole backlog every time.
  **Rotate against a cumulative history, not just the previous run.** Excluding only the last
  cohort doesn't actually rotate on a mostly-static backlog: sample the oldest five, then the next
  five, and by the third run the first five are the oldest again while the only exclusion is
  cohort two — so the sweep alternates between two cohorts forever and never reaches the rest of
  the backlog. Carry every issue sampled since the last reset (§8 records the running set) and
  exclude all of them. When the accumulated set has covered the backlog, clear it, start the cycle
  again, and note the reset in the report.
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
  categories, or between adding a lifecycle label and not → skip, flag in §8.

Apply: `gh issue edit [N] --add-label "x" --remove-label "y"`.

## 4b. Pass 2 — Sizing labels (complexity / model-power)

Many repos carry sizing label families beyond priority — `complexity:*` (how much time/scope) and
`model-power:*` (how much reasoning difficulty) are the common pair. These drift the same way
priority does: freshly-filed issues get a category and a priority and then nobody comes back for
the sizing ones.

**Only run this pass if the repo documents what the tiers mean.** Look for a label-convention doc
— `.github/labels.md` is the usual home, sometimes `CONTRIBUTING.md` — and read it via the API
(`gh api repos/{owner}/{repo}/contents/.github/labels.md --jq .content | base64 -d`, or
`mcp__github__get_file_contents`). No clone needed. If no such doc exists, **skip this pass
entirely** and say so once in the report. Guessing what a repo means by `complexity:medium` from
the label name alone is exactly the false positive the conservative bias exists to prevent.

When the doc exists, follow it literally, including any statement that the families are
independent. A doc that says complexity and model-power are orthogonal means a `complexity:small`
issue can legitimately be `model-power:frontier` — a one-file change that is a genuine design call
with no clear right answer. Don't collapse the two axes into one size.

**Infer per-family exemptions from the backlog itself before filling anything in.** Some families
deliberately don't apply to some issue types. Count coverage per family, split by issue type —
using the typing mechanism established in §2b, not an ad-hoc reading of whatever labels look
type-ish. If §2b couldn't determine one, skip this grouping and say so; an ungrouped run may still
fill in labels missing from individual issues, but it cannot conclude that a type is exempt.

- A family absent on *every* issue of a type (e.g. `model-power` on 10 of 10 epics) **may** be a
  convention — containers carry no size, their children do — but zero coverage cannot establish
  that on its own. A family that was only just introduced, or one drifting untouched in exactly
  the way this pass exists to repair, also reads as 0 of N. Those states are indistinguishable
  from a coverage count, so a clean zero is not permission to skip silently.
- A family *mostly but not always* present on a type (e.g. `complexity` on 6 of 10 epics) is
  ambiguous for the same reason.
- Treat both the same way: **one question per family per type**, covering every gap at once —
  never one flag per issue, and never a silent skip.
- Everything else — a non-exempt issue with the label simply missing — is the auto-apply case.

Either of these promotes a suspected exemption to a real one, and skips the question:

- The convention doc says the family doesn't apply to that type.
- The type's **closed** issues show the same clean zero — historical evidence the labels were
  never used there, which a snapshot of open issues alone can't tell apart from drift.

Once the maintainer answers, record the answer in the tracking issue so later runs read it as
settled instead of asking again.

**Scope**: unlike the priority pass, this one only fills in *missing* labels. Re-litigating an
existing `complexity:medium` down to `small` is a judgment call against someone's own estimate of
their own codebase, so an existing value is only ever flagged, never overwritten — and only when
the issue body flatly contradicts it (a body that says "one-line change" under `complexity:large`).

## 5. Pass 3 — Plain-language pass on title+body only (never comments)

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

## 6. Pass 4 — Re-prioritization

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
- Existing label is `priority:high`/`medium`/`low` and its tier ≠ computed tier → **flag** in §8,
  don't overwrite — someone may have set it for a reason not visible in the score. Matching tiers
  need no action.
- Existing label is `priority:post-mvp`, **or the repo carries a plain `post-mvp` topic label and
  the issue has it** → **don't compare it against the computed tier at all.**
  Post-mvp is an intentional roadmap-sequencing override, not a score bucket — flagging every
  post-mvp issue whose formula score happens to land in a higher tercile is noise, not signal (a
  first live run on Narraitor's 93-issue backlog flagged 51 mismatches this way, only ~4 of which
  were real). Instead, flag a post-mvp issue only when its own title or body text directly
  contradicts the deferral — an explicit severity/priority claim ("High priority", "critical") or
  MVP-scope language ("MVP approach", "(MVP)") sitting on an issue labeled post-mvp. That's a
  narrower, higher-signal check: the issue is telling on itself, not just scoring differently than
  expected.

## 6b. Pass 5 — Similarity grouping: consolidate granular issues into one batch ticket

A backlog with many granular issues accumulates ones small enough, and similar enough, that they're
better worked as one ticket than tracked (and reviewed, and PR'd) as N separate ones. This pass finds
those clusters and, once approved, **merges them into a single new consolidated issue sized like a
normal ticket** — not an epic that collects children, and not sub-issue re-parenting. The distinct
originals get closed into it once the consolidated ticket exists. **It is not duplicate detection**:
a duplicate is the same issue filed twice and gets closed outright (§4 handles the rare one that
surfaces incidentally; a dedicated sweep stays out of scope, see §9). A consolidation candidate is
two or more genuinely distinct, small issues that are cheaper to deliver and review as one unit of
work than as separate ones.

Runs over the full open backlog from §2 — title, labels, and type from §2b are already in hand, no
deep-dive needed to find candidates. Cluster on these signals, strongest first:

- **Explicit parent reference** — an issue's body says "part of #N" / "child of #N" / "see #N" for
  an issue that reads as a container. This usually means the container issue itself is a better
  consolidation seed than a two-issue cluster of its children.
- **Shared domain/component label plus overlapping title keywords** — two or more issues carrying
  the same domain label whose titles share 2+ non-stopword terms (e.g. three separate "world
  creation: step 3 validation" issues).
- **Same type, same active milestone, adjacent scope** — several `enhancement`s in the active
  milestone that read as incremental pieces of one feature rather than independent work.

Label identity alone is never enough (every `bug` isn't a cluster) — a cluster needs the keyword,
domain, or parent-reference overlap on top of shared labels.

**Size the batch before proposing it.** The whole point is a ticket of *appropriate* size, not a
mega-issue that swaps five small review cycles for one unreviewable one. Estimate each candidate's
effort using `prioritize-issues`'s effort rubric (0-10, reusing the sizing labels from §4b where
present instead of re-deriving effort from scratch). Group issues into a batch only while the summed
effort stays within what one well-scoped ticket should be — roughly the "moderate complexity"
ceiling, effort sum around 5-6 — and cap every batch at 5 issues regardless of effort sum, since
review load doesn't scale linearly with ticket count once you're skimming five issues' worth of
context in one sitting. A cluster larger than that splits into multiple appropriately-sized batches,
not one oversized ticket — say so explicitly when a cluster gets split this way.

**Never auto-executes the first time.** Filing the consolidated ticket and closing originals into it
is a structural, hard-to-undo-cleanly change — the individual issues stop being independently
trackable — so it's always a maintainer call before the first execution:

- Surface each proposed batch in the tracking issue (see §8) as a checklist line: the issue numbers,
  the shared signal, the estimated combined effort, and the proposed consolidated title.
- The one exception: once a prior run's tracking issue recorded a maintainer-approved batch via a
  `Settled:` line, **execute it**:
  1. `gh issue create` with a title summarizing the batch and a body that: lists each original issue
     (number, title, link) under its own subheading; preserves each original's acceptance criteria
     verbatim as a nested checklist under that subheading; and adds one combined "Consolidated
     acceptance criteria" section only if the maintainer's approval comment supplied one — don't
     invent a merged criteria list the maintainer didn't ask for.
  2. Apply the category, priority, and sizing labels to the new ticket the normal way (§4/§4b/§6),
     scored against the *consolidated* body, not carried over from any one original.
  3. Close each original with `gh issue close [N] --comment "Consolidated into #<new>."` — this
     preserves the original's full text and history for anyone following an old link; nothing is
     deleted.
  Every other batch, however obvious it looks, stays a proposal until it's settled the same way.
- **Carry unresolved batch proposals forward instead of re-suggesting them as new.** A batch proposed
  in a prior run and left unaddressed is still valid signal — reference the prior tracking issue's
  mention rather than presenting it as a fresh finding, so the maintainer can see it's a repeat and
  weigh that. Re-estimate its combined effort each run — closing or filing other issues can shift
  which cluster is still worth consolidating.

Skip this pass on backlogs under ~15 open issues and say so once — at that size the maintainer
already holds the whole backlog in their head, and clustering noise dominates any real signal.

## 7. Confidence policy — what auto-applies vs what's flagged

| Change | Auto-apply | Flag instead |
|---|---|---|
| Category label | unlabeled or clearly miscategorized | genuinely ambiguous between two |
| Lifecycle label | clear presence/absence of repro/env info | partial or unclear signal |
| Plain-language | exact mechanical swap from the unambiguous bucket | any jargon/verbosity/tone call |
| Priority | no existing priority label | existing label's tier ≠ computed tier |
| Sizing (complexity / model-power) | label missing, repo documents the tiers, issue type isn't exempt | no convention doc; family absent or patchy across a whole issue type; existing value the body contradicts |
| Similarity grouping (consolidation) | one previously-approved batch recorded via a prior `Settled:` line — creates the ticket and closes the originals | every new batch proposal, always |

One more rule that cuts across every row: **don't re-flag a label the maintainer set within the
last few days.** A fresh label is a deliberate triage decision made with more context than the
formula has, and flagging it reads as the sweep second-guessing work someone just did. Suppress
those, but list them with reasons in the report rather than dropping them silently, so the
suppression stays auditable. The same goes for anything a previous run's tracking issue explicitly
dismissed — read the prior issue's comments, not just its body, and honour the decisions in them.

**Getting "fresh" right needs the labeled event, not `updatedAt`.** A label object carries no
timestamp, and the issue's `updatedAt` moves for any reason at all — one unrelated comment makes
every label on the issue look fresh. Read the timeline instead, and only for the handful of issues
where a suppression is actually being considered (it's a per-issue call, so don't sweep the
backlog with it):

```bash
gh api repos/{owner}/{repo}/issues/{N}/timeline --paginate \
  --jq '.[] | select(.event=="labeled" or .event=="unlabeled")
        | {event, label: .label.name, actor: .actor.login, at: .created_at}'
```

**The actor matters as much as the timestamp**, and this is the part the rule missed: suppress a
label the *maintainer* applied recently, because that is the deliberate decision the rule exists
to respect. Do **not** suppress on a label a previous run of this skill applied — that is this
skill's own guess, and treating it as fresh human triage means every guess it ever makes becomes
permanently self-confirming. If the timeline is unavailable, say in the report that freshness was
inferred from the prior tracking issue's record rather than measured, and don't present the
suppression as though it rested on a timestamp.

## 8. Reporting — one tracking issue per run

- Find the prior run: `gh issue list --state open --search "Issue maintenance run in:title"`,
  confirm it's genuinely still open via `gh issue view [N] --json state` (search index can lag).
- Title: `Issue maintenance run — <YYYY-MM-DD>`.
- Body sections: summary counts; **Auto-applied** (checklist, one line per issue with the change,
  including any batch consolidated this run: new ticket number, originals closed into it);
  **Flagged for review** (checklist, one line per issue with the specific call and the two
  options); **Proposed consolidations** (checklist, one line per batch: issue numbers, shared
  signal, estimated combined effort, proposed consolidated title — mark carried-forward batches as
  such rather than re-presenting them as new, and say when a cluster was split into more than one
  batch to stay within the size cap); **Repo notes** (labels not configured, anything skipped); a
  `Last run: <ISO timestamp>` line — the cursor §3's incremental selection reads on the next run; a
  link to the superseded run.
- **Four machine-readable lines the next run depends on.** §3, §6b, and §7 are only as good as what
  the previous run wrote down, so end the body with these even when a section is empty:
  - `Wrote labels to: #N, #N, …` — every issue this run changed. §3 subtracts this set from the
    `updatedAt` delta so the next run doesn't re-dive this run's own writes.
  - `Drift sampled (cumulative): #N, #N, …` — every issue sampled since the last cycle reset, not
    just this run's five. §3 excludes the whole set; a one-run-deep list makes the sample alternate
    between two cohorts instead of rotating through the backlog. Say so when the set wraps and
    resets.
  - `Settled: <question> — <answer>` — one line per exemption or dismissal the maintainer resolved
    (typically in a comment on this issue). §4b's coverage questions, §6b's approved batches, and
    §7's dismissals all read this; without it, every run re-asks a question that was already
    answered.
  - `Consolidations proposed (carried): #N+#M+#P (signal, effort ~X), …` — every proposed batch not
    yet settled, across every run since it first appeared, not just this run's new ones. §6b reads
    this so an unaddressed batch is presented as a repeat, not a fresh finding, and a batch drops off
    the list once its `Settled:` line resolves it (approved and executed, or explicitly declined).
- Label the tracking issue from the existing set if one genuinely fits (e.g. `documentation`);
  otherwise leave it unlabeled rather than inventing a `maintenance` label.
- Close the prior run once confirmed still open: `gh issue close [N] --comment "Superseded by
  #<new>."`.
- First run: no prior issue exists — skip the supersede step, note "first run" in the body.

Batch deep-dive `gh` calls in chunks of ~20 with a brief pause between chunks if a run gets large
(a big incoming batch of new issues, or the first run) — no need for anything fancier than that to
stay clear of GitHub's secondary rate limits.

## 9. Out of scope for v1

Dedicated duplicate-detection sweeps (§6b's similarity grouping is a distinct, in-scope pass — see
§6b for the boundary between the two), stale-issue auto-closing, and cross-repo runs. These are
reasonable future extensions but not part of this pass — don't build them in speculatively.
