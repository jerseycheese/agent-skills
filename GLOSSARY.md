# Agent Skills

A collection of agent skills that work across several coding-agent tools. This glossary fixes the words the skills, the README, and the repo's checks use, so a new skill names things the way the existing ones do.

## Language

### Skills and how they load

**Skill**:
A folder under `skills/` with one `SKILL.md`, plus any scripts or templates it ships, that tells an agent when to act and what to do.
_Avoid_: Command, prompt, plugin, tool

**Description**:
The frontmatter field an agent reads to decide whether to invoke a skill. It says what the skill does, when to use it, and three or four trigger phrases.
_Avoid_: Summary, blurb, tagline

**Trigger phrase**:
A quoted example request in a description that should invoke the skill.
_Avoid_: Keyword, hotword, activation phrase

**Model-invoked**:
Run by the agent when a request matches a description, as opposed to picked by the user from a slash-command menu.
_Avoid_: Auto-run, automatic, implicit

**Trigger eval**:
One line in `evals/triggers.tsv`: a request that a named skill must win or, with a leading `-`, must not win. A word-overlap proxy checks it, not the real router.
_Avoid_: Test case, routing test, prompt test

**Provider**:
An agent tool that loads skills, such as Claude Code, Codex, or Antigravity.
_Avoid_: Platform, vendor, host, client

**Provider path**:
The directory a provider reads skills from, at user level (every project) or project level (one repo).
_Avoid_: Install location, skills dir

**Skill parity**:
The state where every provider path holds the same version of each skill.
_Avoid_: Sync status, mirroring

**Marketplace**:
This repo as a Claude Code plugin source, described by `.claude-plugin/marketplace.json`. It ships one plugin that lists every skill.
_Avoid_: Registry, store, catalog

**Canon**:
The one source a skill treats as true when copies or docs disagree, such as a project's design tokens or the single clone providers load skills from.
_Avoid_: Source of truth, master copy, golden copy

### What a skill is allowed to do

**Read-only**:
Said of a skill that reports and never changes files, issues, or branches.
_Avoid_: Report-only, safe mode, dry mode

**Auto-fix**:
A change a skill applies without asking, because the finding is unambiguous and the fix is mechanical.
_Avoid_: Quick fix, safe fix, auto-apply

**Judgment call**:
A finding a skill surfaces for the user to decide instead of fixing, because reasonable people could disagree.
_Avoid_: Manual review item, flag, maybe

**Dry-run**:
A stage's first pass that shows what it would create and waits for an OK before writing anything.
_Avoid_: Preview mode, plan mode, simulation

**Evidence tier**:
How well a claim is backed, strongest first: verified (ran it), confirmed (read the source), inferred, unverified, or assumed.
_Avoid_: Confidence level, certainty score

### Routing work to models

**Seat**:
One paid subscription to a provider, with its own usage windows.
_Avoid_: Account, license, plan, subscription

**Burn**:
How much of a seat's usage window is already spent, as a percent used.
_Avoid_: Usage, consumption, spend, quota left

**Routing table**:
The user's own file that maps each phase of work to a first-choice seat and model, with fallbacks. It lives on their machine, not in this repo.
_Avoid_: Model config, routing rules, model matrix

**Phase**:
The kind of work a task is right now, such as planning, implementation, or code review. It picks the row of the routing table.
_Avoid_: Stage, step, mode, task type

**Model tier**:
A label for how hard an issue is to reason about, which is not the same as how big it is.
_Avoid_: Complexity, size, difficulty score

### Working a milestone with several agents

**Orchestrator**:
The agent session that plans, dispatches, reviews, and tracks a run. It is the only one that may merge, and only where the merge policy says so.
_Avoid_: Dispatcher, coordinator, manager, lead agent

**Lane**:
One agent working one batch on its own branch. Lanes never merge.
_Avoid_: Worker, thread, track, sub-run

**Batch**:
A group of issues that share a domain and a file set, sized to land as one reviewable PR.
_Avoid_: Group, bundle, chunk, cluster

**Wave**:
A set of batches that can run at the same time because none depends on or collides with another.
_Avoid_: Round, tier, sprint, pass

**Brief**:
The written instructions a lane starts from: the issues, the files, the gates to pass, and the trap list.
_Avoid_: Prompt, ticket, spec, task description

**Adapter**:
A small per-repo skill that supplies what the orchestrator can't guess: base branch, gate commands, merge policy, label names, and release convention.
_Avoid_: Config, profile, repo plugin, settings

**Gate command**:
A check a lane must show passing before its PR counts as ready, such as the repo's test or lint script.
_Avoid_: Check, validation step, CI step

**Merge policy**:
The adapter's statement of who may merge which PRs and what must be shown first. With none, only the human merges.
_Avoid_: Merge rules, auto-merge setting, approval policy

**Review gate**:
The point where a PR is judged ready: CI passed on the head commit, a review covers that exact commit, and the PR is mergeable.
_Avoid_: Approval step, sign-off, merge check

**Light review**:
A cheaper review tier for small, low-risk PRs, which the adapter can narrow or turn off.
_Avoid_: Quick review, skim, fast track

**Run tracker**:
The single issue that records a run's waves, batches, owners, and state.
_Avoid_: Status issue, dashboard issue, epic

**Trap list**:
The failure modes lanes have actually hit in a repo, copied into every brief.
_Avoid_: Gotchas, known issues, pitfalls

**Needs-local**:
Said of work that can only be proven on the user's own machine, not in a cloud container.
_Avoid_: Manual, offline, human-only

### Issues and findings

**Roll-up issue**:
One issue that holds several small findings as a checklist, so minor items don't each get their own issue.
_Avoid_: Umbrella issue, catch-all, misc issue

**Seam gap**:
A boundary between two parts of a system that no test crosses with realistic data.
_Avoid_: Integration hole, coverage gap, missing e2e

**Band-aid**:
A fix that hides a symptom without resolving its cause. A deliberate, documented mitigation is not one.
_Avoid_: Hack, workaround, patch

### Sessions

**Handoff**:
A written note that lets a new session continue work an earlier session started.
_Avoid_: Summary, recap, context dump

**Known-issues log**:
A project's running record of CI failures and the fixes already tried, so the same fix isn't tried twice.
_Avoid_: Bug list, troubleshooting doc, FAQ

**Stranded work**:
Commits or uncommitted changes that sit in a branch or worktree with no open PR and no session working on them.
_Avoid_: Orphaned work, abandoned branch, stale work

**Dormant**:
Said of a repo with no recent activity on its base branch and nothing waiting on anyone.
_Avoid_: Dead, inactive, archived
