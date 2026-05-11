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

## 3. Pre-filter

Skip issues labeled `wontfix`, `duplicate`, `invalid`, or `question`. Skip closed issues (should be excluded by the list query, but double-check).

## 4. Score each issue

For each issue, assess these dimensions. You don't need to output the raw scores — use them internally to reason about rank.

### Value (0-10)

| Factor | Points |
|--------|--------|
| User-facing bug that breaks functionality | +3 |
| User-facing improvement | +2 |
| Internal/no user impact | +0-1 |
| Unblocks multiple other issues | +2 |
| Unblocks one other issue | +1 |
| Aligned with active milestone or roadmap goal | +2-3 |
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
3. Better roadmap alignment

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

## 7. Output format

```
# Issue Priority Analysis

Total open issues analyzed: [N]

## Top 5 Candidates

### 1. #[number] — [title]
Priority score: [X]
- Value/Effort: [ratio and reasoning]
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
```

Leave out emojis. Keep the output scannable — the user will skim it to make a final call.
