---
name: ship-issue
description: End-to-end conductor that drives a single GitHub issue all the way to a merged PR. Chains the issue-workflow skills — sync the base branch, analyze the issue, implement a minimal fix with a test, open a PR, drive CI to green, confirm the merge, run post-merge cleanup, and wrap up. Use to take one issue from a cold start to merged in a single command. Trigger on "ship issue #X", "ship #123", "take #N to merge", "do issue #X end to end", "full issue loop for #N", "run the whole issue #X".
---

# Ship Issue

Drive a single issue from a cold start to a merged PR and a clean handoff. This is a conductor: each step leans on an existing skill or native control rather than re-implementing it. Apply a minimal, root-cause fix — don't patch a symptom or pad the change past the issue's scope.

Take the issue number from the user (e.g. "ship issue #326"). If they named an issue instead of numbering it, find it:

```bash
gh issue list --search "[keywords]" --json number,title | head -5
```

## The loop

1. **Pre-flight — sync and locate.** Run `git fetch && git status`. Get onto the right base branch (`develop` if it exists, else `main`) and up to date. If you're working in a worktree, confirm it's the right one and that its dev server points at it. Never build or test against a stale checkout — that's where most rework comes from.

2. **Analyze.** Run the `analyze-issue` skill: fetch the issue, discover existing patterns in the codebase, set scope boundaries, and produce an implementation plan with MVP-level tests. Diagnose the root cause before writing any code.

3. **Implement.** Apply the smallest fix that resolves the root cause. Reuse existing patterns before introducing new ones. Add or update one MVP-level test that actually covers the change — use `tdd-implement` for the test-first loop. Run the test suite and linter locally; never rig a test to pass.

4. **Open the PR.** Push the branch and open a PR that links the issue (`Closes #N`). Keep the title and description tight: lead with context, say what changed and why, skip the fluff.

5. **Drive CI to green.** Watch the checks. When something fails, use `ci-fix-with-memory` so you don't repeat a fix that already failed. Re-push until green. If the same failure resists three or more different fixes, stop and summarize — ask whether to skip, defer, or rethink the approach.

6. **Confirm the merge.** Once CI is green and the PR is approved and merged, take "merged" as ground truth — don't re-verify without a concrete reason.

7. **Post-merge cleanup.** Run the `post-merge` skill: it syncs the base branch, deletes the merged branch and its worktree, closes the linked issue (completion comment and acceptance criteria checked), and scores the best next issue to pick up.

8. **Wrap up.** Run `wrap-it-up` to close the chat with a tight summary and a sweep of durable context (memory, plans, status), so the next session — or a parallel agent — can pick up cleanly.

## Notes

- Pin a concrete, evaluator-checkable success criterion up front (e.g. a goal like "issue #N acceptance criteria met, PR open, CI green") and let the evaluator decide done, not self-judgment.
- Each step is a thin pointer to a dedicated skill. If a step needs more depth, open that skill directly rather than duplicating its logic here.
