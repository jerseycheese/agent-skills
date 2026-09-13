---
name: prioritize-issues
description: Analyzes all open GitHub issues to identify the highest-priority candidates for implementation. Scores by value, effort, age, and roadmap alignment. Produces a ranked top-5 with detailed technical specs for the top 3. Use when planning what to work on next, triaging a backlog, or preparing for a sprint. Trigger on phrases like "what should I work on", "prioritize my issues", "what's the highest value issue", "triage my backlog", "help me pick the next issue", "what's worth doing next".
---

# Issue Prioritization

## 1. Discover the repo

If the user didn't specify a repo, infer it:

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

## 2. Fetch all open issues

Pull the full backlog — not just recent issues:

```bash
gh issue list --state open --limit 200 --json number,title,labels,createdAt,body,milestone,comments
```

If the repo has more than 200 open issues, paginate. Also fetch any recent comments on the top candidates to catch context updates:

```bash
gh issue view [NUMBER] --json number,title,body,labels,comments,createdAt,milestone
```

### Milestones

An issue's `milestone` field gives you a name, not a status. Fetch the milestone list separately,
because the name alone can't tell you whether that milestone is active, shipped, or aspirational:

```bash
gh api repos/OWNER/REPO/milestones --jq '.[] | "\(.title): open=\(.open_issues) closed=\(.closed_issues) due=\(.due_on)"'
```

The active milestone is the open one with the nearest due date; if none carry due dates, it's the
one with issues closing against it recently. Write down the open/closed split for each — that
split is the input to the scoring rows below, and "1 open of 12" ranks very differently from
"11 open of 12". An issue whose milestone is not the active one gets no milestone credit at all.

## 3. Pre-filter

Skip issues labeled `wontfix`, `duplicate`, `invalid`, or `question`. Skip closed issues (should be excluded by the list query, but double-check).

## 4. Score each issue

Score the whole backlog, not the recent slice of it. Labels are not evidence: `priority:high`
goes stale, `complexity:large` was often guessed at filing time, and an issue filed a year ago
can carry a body that says the fix is now two lines. Ranking off the label soup means old issues
lose on age alone, which is exactly what the age bonus exists to prevent.

So before any issue is ranked OR dismissed, read its body. In practice that means one batched
read over every candidate that survives the pre-filter — pure roadmap-epic entries and obvious
post-MVP wishlist items can be skimmed, but nothing gets a score from its title and labels alone.
Cheap way to do it:

```bash
for n in $(gh issue list --state open --limit 200 --json number --jq '.[].number'); do
  echo "===== #$n ====="
  gh issue view $n --json title,body --jq '"TITLE: \(.title)\n\(.body)"' | head -40
done
```

Two things to watch for that only the body reveals:

- **The issue is already blocked or already decided.** A body that says "this lands with or after
  PR #X" or "this needs a spending decision" is not a batch candidate no matter how it scores.
- **A stale label.** If the body contradicts the label — a `priority:high` that a later comment
  moved post-MVP, a `complexity:large` whose body now describes a one-line fix — score the body
  and say so in the output.

For each issue, assess these dimensions. You don't need to output the raw scores — use them internally to reason about rank.

### Value (0-10)

| Factor | Points |
|--------|--------|
| User-facing bug that breaks functionality | +3 |
| User-facing improvement | +2 |
| Internal/no user impact | +0-1 |
| Unblocks multiple other issues | +2 |
| Unblocks one other issue | +1 |
| Last open issue in the active milestone (closing it closes the milestone) | +4 |
| In the active milestone, 3 or fewer open items left | +3 |
| In the active milestone | +2 |
| Aligned with a roadmap goal, no milestone attached | +1-2 |
| In a milestone that is not the active one | +0 |
| Labels: `critical`, `blocking`, `P0` | +2 |

### Effort (0-10, lower is better)

| Factor | Points |
|--------|--------|
| Major architectural change | +4 |
| Touches many files/systems | +3 |
| Moderate complexity | +2 |
| Simple, well-scoped change | +1 |
| Requires extensive E2E + manual testing | +3 |
| Unit tests only | +1 |
| Breaking changes or migrations | +3 |
| Low-risk, isolated change | +0-1 |
| Labels: `good first issue`, `small`, `quick` | -1 (lower effort) |

### Age bonus

Issues that have been open longer tend to get pushed down unfairly. Apply a small bonus:
- Open 2-8 weeks: +0.1
- Open 2-6 months: +0.3
- Open 6+ months: +0.5

This is a tiebreaker, not a primary driver. A low-value chore open for a year still loses to a critical bug opened yesterday.

### Priority score

```
score = (value * 2) / (effort + 1) + age_bonus
```

## 5. Select top 5

Rank by score. Among ties, prefer:
1. Issues that unblock other work
2. Older issues (age bonus already helps here)
3. Closer to finishing the active milestone (last item beats one of ten)

## 6. Create technical specs for top 3

For each of the top 3 candidates:

**Problem statement** — 1-2 sentences explaining the actual problem.

**Scope boundaries**
- What IS included
- What is NOT included (be explicit about adjacent work that's out of scope)

**Technical approach** — Brief approach that leverages existing patterns in the codebase. Check what's already there before assuming new code is needed.

**Existing code to leverage** — List specific components, utilities, or patterns that apply.

**Implementation plan** — 3-5 concrete steps.

**MVP test plan** — 2-4 tests that directly map to acceptance criteria. No "renders without crashing" tests.

**Files to modify / create** — Based on codebase exploration, not guessing.

**Success criteria** — Checkboxes pulled directly from the issue.

## 7. Work out the parallel batch

The top 5 is a ranked list, not a work order. Before writing the output, decide which of them can run *at the same time* without stepping on each other, so the user can start a batch rather than one issue.

Walk the top 5 in rank order and add an issue to the batch unless one of these disqualifies it:

- **Blocked.** It depends on another issue that isn't done — including one earlier in this same batch. Blocked issues wait; say what they're waiting on.
- **File collision.** Its "Files to modify" overlap another batch member's. Two agents editing the same file in parallel means a merge conflict at best. Check the specs you just wrote, not a guess.
- **Scope-deciding.** A spike or decision whose answer changes another candidate's scope. Run it alone first — that's the whole point of it being a spike.
- **Shared regenerated artifact.** Both would regenerate the same baselines, lockfile, or generated bundle. Serialize those.
- **Needs a decision from the user.** Anything where you flagged an open product call. It isn't runnable until they answer.

One thing argues *for* pairing rather than against. If two candidates are the last open items in
the same active milestone and their files don't collide, batch them. Closing a milestone is worth
more than two unrelated issues of the same score, and it lands on the reviewer as one coherent
chunk rather than two.

Cap the batch at 3. Past that the review load lands on one human and the wall-clock win disappears.

If nothing parallelizes, say so plainly and emit a single-issue goal. A one-item batch is a normal outcome, not a failure.

## 8. Output format

```
# Issue Priority Analysis

Total open issues analyzed: [N]

## Top 5 Candidates

### 1. #[number] — [title]
Priority score: [X]
- Value/Effort: [ratio and reasoning]
- Milestone: [name, open/closed split, and what closing this does to it — or "none"]
- Roadmap alignment: [High/Medium/Low — one sentence]
- Effort: [Small/Medium/Large]
- Dependencies: [list or "none"]

[Repeat for 2-5]

---

## Technical Specs (Top 3)

### #[number]: [title]

**Problem**
[1-2 sentences]

**Scope**
In: [list]
Out: [list]

**Approach**
[Brief technical approach]

**Existing code to leverage**
[List]

**Implementation plan**
1. [step]
2. [step]
3. [step]

**MVP tests**
1. [test and what it validates]
2. [test and what it validates]

**Files**
- Modify: [paths]
- Create: [paths]

**Success criteria**
- [ ] [criterion from issue]

---

[Repeat for other top candidates]

## Recommended next action

Work on #[NUMBER]. [One sentence on why this one over the others right now.]

## Run the batch

[The single /goal command, in its own bash fence.]

Held back: #[N] ([what it's waiting on]).
```

Leave out emojis. Keep the output scannable — the user will skim it to make a final call.

## 9. Handing off to implementation

Always end with **one** `/goal` command covering the whole parallel batch from step 7 — not one command per issue, and not a suggestion to run them manually. `/goal` keeps working across turns until a separate evaluator confirms the condition holds, so the run doesn't need babysitting.

Shape of the command: name every batch issue, give each its own completion condition, and state the isolation requirement.

```bash
claude "/goal \"issues #A, #B, #C each have acceptance criteria met, a PR open against develop, and CI green. Run them in parallel as Agent-tool subagents, each in its own git worktree on its own branch.\""
```

Rules for the command:

- **One command, every batch issue.** Splitting it into three commands loses the whole point — the evaluator should be judging the batch, not each run in isolation.
- **Per-issue completion conditions.** "All three done" is unevaluatable. "Each has acceptance criteria met, PR open, CI green" is.
- **Agent-tool subagents, in worktrees.** Say this explicitly in the goal string. Spawning CLI children (`claude -p`) for parallel work fails; Agent-tool subagents work. Each needs its own worktree so the checkouts don't collide.
- **Name the base branch** if the repo targets something other than the default (e.g. `develop`).
- **Carry the blocked ones separately.** Below the command, list what got held back and what it's waiting on, so the next batch is obvious once the blocker lands.

If the batch is a single issue, emit the single-issue form (`/goal "issue #N acceptance criteria met, PR open, CI green"`) and drop the parallel language rather than dressing up a batch of one.

Watch the runs in Agent View (`claude agents`).
