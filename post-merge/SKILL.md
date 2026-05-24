---
name: post-merge
description: Runs the post-merge workflow after a PR is merged. Phase 0 syncs the correct base branch and deletes the merged branch and its worktree so later work never starts from stale state. Phase 1 closes the loop on linked GitHub issues (posts a completion comment, marks acceptance criteria done, closes the issue if fully addressed). Phase 2 recommends the single best next issue to work on, scoring all open issues by value, effort, and age. Invoke whenever the user says a PR was merged — "merged PR #42", "just merged the auth fix", "PR is merged", "I merged #123".
---

# Post-Merge Workflow

Three phases: sync and clean the working tree, tidy up the issues the PR addressed, then recommend what to do next.

## Phase 0: Sync and Clean the Working Tree

Do this first. Most post-merge rework comes from the next task starting against a stale base branch or a leftover feature branch/worktree — clean it up now while you have the context.

### 1. Find the base and head branches

Don't assume `main`. Read what the PR actually merged into:

```bash
gh pr view [NUMBER] --json number,title,baseRefName,headRefName,mergedAt
```

`baseRefName` is the branch to sync (often `develop` or `main`); `headRefName` is the merged feature branch to delete.

### 2. Sync the base branch

```bash
git fetch --prune
git checkout [BASE_BRANCH]
git pull --ff-only
```

If your current checkout is a worktree pinned to the merged feature branch, you can't switch it to the base — leave it and handle the worktree in step 3.

### 3. Delete the merged branch and its worktree

```bash
git worktree list                    # find any worktree holding the feature branch
git worktree remove [WORKTREE_PATH]  # only if it lives in a worktree
git branch -d [HEAD_BRANCH]          # safe delete — refuses if not actually merged
```

Use lowercase `git branch -d`; it only deletes branches that are fully merged. Don't reach for `-D` unless you've confirmed the work really landed. `git worktree remove` refuses to drop a worktree with uncommitted changes — don't `--force` past that without checking what's there first. If the project has a prune-merged-branches helper, use it (dry-run, then apply); those scripts typically skip `develop`/`main`/`release/*` and worktree-held branches.

### 4. Confirm clean state

```bash
git status
git branch --show-current
```

You want to be on the synced base branch, working tree clean, with the feature branch gone. Now move to Phase 1.

---

## Phase 1: Issue Cleanup

### 1. Get the PR

If the user gave you a PR number, use it. If they described it by name, find it:

```bash
gh pr list --state merged --limit 10
```

Then pull the details:

```bash
gh pr view [NUMBER] --json number,title,body,mergedAt,headRefName,closingIssuesReferences
```

### 2. Find linked issues

Check two places:

- `closingIssuesReferences` from the JSON above (GitHub auto-detects closing keywords)
- Scan the PR body manually for patterns: `closes #N`, `fixes #N`, `resolves #N`, `related to #N`

If the user mentioned a specific issue in their message, include that too.

### 3. Update each linked issue

For each issue:

**a) Get current state:**
```bash
gh issue view [ISSUE_NUMBER] --json number,title,body,state,labels
```

**b) Post a completion comment** — keep it short, link the PR:
```
Addressed in PR #[NUMBER] — merged [date].
```

**c) Update acceptance criteria checkboxes** — if the issue body has a checklist and the PR clearly addressed specific items, edit the body to check them off. Only check what was actually delivered; leave unchecked items alone. Use `gh issue edit [NUMBER] --body "..."` with the updated text.

**d) Close the issue** if it's fully addressed (all checklist items done, or no checklist and the PR directly resolves it):
```bash
gh issue close [ISSUE_NUMBER] --comment "Closed by #[PR_NUMBER]."
```

If the issue is only partially addressed, leave it open — just post the comment and check the relevant boxes.

### 4. Report what you did

One short summary: which issues were updated, which were closed, which were left open and why.

---

## Phase 2: What's Next

### 1. Pull all open issues

```bash
gh issue list --state open --limit 100 --json number,title,labels,createdAt,body,milestone
```

If there are more than 100, paginate:
```bash
gh issue list --state open --limit 100 --json number,title,labels,createdAt,body,milestone --skip [N]
```

### 2. Score each issue

For each issue, assess these dimensions — you don't need to output scores, just use them to reason:

**Value (higher = do sooner)**
- Bug that breaks existing functionality → high
- Blocks other issues or unlocks a milestone → high
- User-facing improvement → medium
- Internal refactor / chore with no user impact → lower
- Labels like `critical`, `blocking`, `P0` → boost

**Effort (lower = do sooner, all else equal)**
- Labels like `good first issue`, `small`, `quick` → low effort
- Labels like `epic`, `large`, `needs-design` → high effort
- Issue body describes a narrow, well-scoped change → low
- Issue body is vague or touches many systems → high

**Age bonus**
- Issues that have been open longer tend to get deprioritized unfairly. Give a small bonus to issues open more than a few weeks, and a bigger one for anything over a couple of months. This isn't a tiebreaker — a low-value chore open for 6 months still loses to a critical bug opened yesterday.

**Context from the merged PR**
- If the merged PR unblocks something specific (e.g., a dependency, an API, a design token), boost any issue that was waiting on it.
- Issues in the same area of the codebase as the just-merged work may be good to batch — you're already in context.

### 3. Pick one

Give a single recommendation. Not a ranked list — one issue, with 2-4 sentences explaining why it's the right call right now. The reasoning should be concrete: "this is a bug that affects X, it's well-scoped, and the PR you just merged sets up the infrastructure it needs" — not "high value, low effort."

If there's a genuinely close second worth knowing about, mention it in one sentence. Don't list the whole top 5.

### 4. Format

```
Next: #[NUMBER] — [title]

[2-4 sentence reasoning. Be specific about why now, why this one over the alternatives.]

(Alternatively: #[NUMBER] — [one sentence if there's a close second])
```

Keep it tight. The goal is a quick decision, not a planning session.
