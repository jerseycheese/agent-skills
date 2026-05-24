---
name: code-health-audit
description: >
  Kicks off a recurring code-health audit — the "embarrassing code" / overengineering sweep that
  turns vague tech-debt anxiety into a short list of measurable, validated simplifications to ship.
  Bakes in the pre-flight discipline (sync the correct base branch, confirm the active worktree and
  its dev server, list files in scope) so the audit never runs against stale or wrong-worktree code.
  Trigger on: "embarrassing code audit", "overengineering audit", "code health audit",
  "find simplification candidates", "what can we simplify", "tech debt sweep", "audit the codebase",
  "find overengineered code", "what's embarrassing in this repo".
---

# Code Health Audit

A repeatable sweep for dead code, overengineering, and embarrassing/inconsistent patterns. The point isn't to list everything wrong — it's to ship a handful of high-value, low-risk simplifications with a net-negative line count and a green test suite.

The distinctive value of this skill is the pre-flight (Phase 0). Most audit rework comes from auditing the wrong branch or a stale worktree copy, then building changes that were already merged or that don't match the live code. Do Phase 0 first, every time — don't skip it because you "know" the state.

## Phase 0: Pre-Flight — Get the Working State Right

### 1. Sync the correct base branch

Audits run against the integration branch, not whatever happens to be checked out. Confirm the base (usually `develop`; `main` if there's no `develop`) and sync it:

```bash
git fetch --prune
git rev-parse --abbrev-ref HEAD          # what am I on?
git checkout [BASE_BRANCH]
git pull --ff-only
git rev-list --count HEAD..origin/[BASE_BRANCH]   # 0 == up to date
```

If that count isn't 0 after a pull, stop and sort out why before auditing. Never audit or build against a stale local checkout — that's the single most common way this work gets wasted.

### 2. Confirm the active worktree and its dev server

If the repo uses git worktrees, know which one you're in and which dev server is actually live — verification later has to hit the checkout you're editing, not a stale server from another worktree:

```bash
pwd
git rev-parse --show-toplevel            # the worktree you're editing
git worktree list
lsof -i -P | grep LISTEN | grep node     # which dev server(s) are up, on which ports
```

Make sure the dev server you'll verify against is serving this worktree. If it's serving a different checkout, restart it here or note the right URL.

### 3. List the files in scope and confirm

Before scanning, state what you're auditing (a directory, a domain, the whole `src/`) and list the files so the user can confirm you're pointed at the right code. A one-line scope check here prevents a whole audit aimed at the wrong area.

### 4. Check audit memory

If the project has an audit-memory file (e.g. `docs/audit-memory.md` or `.audit-memory.md`), read it. It records what was shipped and — more importantly — what the user already looked at and **declined**. Don't re-flag rejected items. If no such file exists, you'll create one at the end.

## Phase 1: Surface Candidates

Ask for a target count if the user didn't give one (default: at least 15). Surface candidates across three categories:

**Dead code** — unused exports, orphaned tests/stories, commented-out blocks, debug leftovers. For the deep removal mechanics and safety checks, defer to the `dead-code-cleanup` skill rather than reinventing them here.

**Overengineering** — abstraction with one caller, config/flags for cases that can't happen, defensive handling of impossible states, a class where a function would do, a factory/strategy/wrapper that adds indirection without payoff, premature generalization. The `kiss` skill is the lens here: what's the minimum surface that achieves the actual goal?

**Embarrassing / inconsistent** — copy-paste that drifted, naming that fights the rest of the codebase, a pattern that contradicts an established one two files over, magic numbers, dead conditionals, TODO/FIXME that are actually done or actually broken.

For each candidate note: file:line, category, what's wrong in one line, and a rough sense of risk and line-count impact.

## Phase 2: Self-Verify

Before anything reaches the user, kill the false positives. For each candidate:

- "Unused" → grep for dynamic imports, string references, index re-exports, config references, and test usage before believing it.
- "Overengineered" → confirm there's genuinely one caller / impossible case; an abstraction with three real callers stays.
- "Inconsistent" → confirm the thing you'd align it *to* is actually the established pattern, not just another one-off.

Drop anything you can't stand behind. Then sort the survivors by confidence (high = safe and obvious, low = needs a human call).

## Phase 3: Pick and Present

Pick the top N (default 5) by value-to-risk — the simplifications that remove the most complexity for the least chance of breakage. Present them as a short approval list: file, the change, expected LOC delta, risk. One line each. Let the user cut any before you start.

## Phase 4: Ship

For the approved set:

1. Make the changes (smallest diff that does the job — lean on `kiss`).
2. Verify for real: full test suite green, type-check and lint clean, and — if it's previewable — exercise it in the browser against the worktree's own dev server (from Phase 0), not just a passing build.
3. Keep commits focused by category, or bundle into one PR with a net-negative LOC summary (e.g. "-212 across 19 files, all 2,134 tests passing").
4. Open the PR against the base branch you synced in Phase 0 and drive CI to green.

## Phase 5: Update Audit Memory

Append to the audit-memory file: what shipped, and what the user declined and why. This is what makes the next run faster and stops you from re-surfacing rejected patterns. Create the file if it doesn't exist yet.

## When Not to Use

- Mid-feature work — finish the feature first; don't fold an audit into it.
- When the user wants a single targeted cleanup (a known dead file) — just do it, or use `dead-code-cleanup` directly.
- When you can't verify changes (no tests, no way to run it) — say so before shipping, don't claim success blind.
