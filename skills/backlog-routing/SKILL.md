---
name: backlog-routing
description: >
  A milestone-driven system for working a GitHub backlog with several agents at once while a human
  stays the only merge gate. Seven stages, each run only when asked: intake (turn playtest notes,
  screenshots, or findings into labeled issues), shape (propose a milestone's contents and ordered
  plan), plan (split the milestone into collision-free batches, route each to the cheapest capable
  model and vendor, and pick cloud or local), dispatch (start the batches: cloud sessions driven by
  /goal, local task cards, or paste-ready briefs for Codex and Gemini/Antigravity), review gate
  (two-model review before the PR reaches the human), close-out (after each merge), and release
  (when the milestone empties). Repo-specific rules come from an adapter skill. Trigger on:
  "backlog routing", "route the backlog", "plan the milestone", "batch the milestone", "dispatch
  the batches", "intake these findings", "file issues from my playtest notes", "shape vX.Y",
  "what goes in the next milestone", "run the release", "which model should do this issue".
---

# Backlog routing

The job is throughput without losing control. Lots of agents, each on the cheapest model that can
actually do its piece, none of them stepping on each other, and nothing merged until the human
reads the PR.

It's built from skills that already exist. This one decides **what runs where, in what order, on
which model**. The rest is delegated:

| Need | Delegate to |
|---|---|
| Ranking | `prioritize-issues` |
| Labels, dedupe, clustering | `issue-maintenance` |
| Visual finding triage | `visual-qa-pipeline` (its severity ladder) |
| Work inside a lane | `analyze-issue` → `tdd-implement` → `ship-issue` steps 1–5 |
| CI red | `ci-fix-with-memory` |
| After merge | `post-merge` |
| Claims of done | `evidence-check` |

Don't re-implement any of those here.

## 0. The adapter comes first

Every repo that uses this needs an **adapter skill** (for example `<repo>-backlog-routing`). Read it
before any stage. If there's no adapter, stop and write one first, using the contract below. Don't
guess a repo's gate commands or release process.

The adapter supplies:

- **Base branch** and any branch that's off limits (a release-only `main`, say).
- **Gate commands** a lane must show passing, and which extra gates trigger on which kinds of change.
- **Local-only criteria**: what can't be proven in a cloud container (OS-specific visual baselines,
  live API keys that live in the user's browser, a human walking a flow, headful playtests).
- **Milestone and release convention**: how milestones are named, what a release PR contains, which
  release steps belong to the human.
- **Label names** for type, priority, size, model tier, and the two this skill needs (`needs-local`,
  `run-tracker`). Use only labels that exist in the repo.
- **PR template path** and any rule about rendering it.
- **Trap list**: failure modes lanes have actually hit in this repo. It goes into every brief.

## 1. Hard rules (every stage)

- **The human is the only merge gate.** Never merge, never approve, never enable auto-merge. Never
  push to or open PRs against a branch the adapter marks off limits.
- **Each stage runs when asked.** Finishing one stage doesn't start the next unless the user said
  to chain them.
- **Stages that create things are dry-run first.** `intake` and `shape` show what they'd write and
  wait for an OK. `dispatch` shows what it's about to launch.
- **Claims need proof.** "Green", "merged", "done" point at a tool result (a check run, a gate
  output, a diff). See `evidence-check`.

## 2. Stages

Invoke as `backlog-routing <stage> [args]`.

### intake `<notes | screenshots | log | issue list>`

Turn raw findings into issues the later stages can route.

1. Split the input into one finding per problem. Visual and UX findings go through
   `visual-qa-pipeline`'s severity ladder:
   - Critical and Major get their own issue.
   - Minor and cosmetic ones go into one roll-up issue with a checkbox each.
2. Dedupe each finding against open issues (semantic search plus a title search). If it matches an
   existing issue, propose a comment on that issue instead of a new one.
3. Draft each issue with the repo's template (the adapter can name one for playtest findings), plus
   two sections:
   - **Likely files**: grep for the component, route, or class name and list the real paths. `plan`
     uses these for collision checks, so a guess here costs a conflict later.
   - **How to prove it**: the gate or local check that shows it's fixed. If only a local check can
     prove it, add `needs-local`.
4. Labels: type, priority, size, and model tier, using the repo's definitions. Tier is reasoning
   difficulty, not size.
5. Suggest a milestone, or an epic parent, for each.
6. Show the whole batch as a table. File only after the user says so. For an epic parent, attach
   children with the sub-issue API.

### shape `<milestone>`

Propose what goes in a milestone and in what order.

1. Rank candidates with `prioritize-issues`. Put anything the user explicitly named first.
2. Leave out:
   - issues blocked by something outside the milestone
   - issues held in their body ("lands after", "needs a decision")
   - frontier-tier issues, unless the user wants them in and accepts they run in the orchestrator
     or by hand
3. **Epics.** An epic can span milestones. Pull in only the children that are ready, and state the
   epic's progress in the proposal ("#N: 2 of 5 children in this milestone").
4. Draft the milestone description: what it's for, the ordered list of issues, and what's out of
   scope. That description is the contract the later stages plan against.
5. Wait for the OK, then create or update the milestone and set membership.

### plan `<milestone>`

Turn the milestone into waves of batches, and write the run tracker.

1. **Load state.**
   - Open issues in the milestone, with bodies and comments.
   - Open PRs, and branches matching the batch prefix or an issue number. Anything already in
     motion is excluded. A leftover branch or worktree isn't proof it was abandoned: ask.
2. **Dependencies.**
   - Blocked-by and sub-issue order.
   - "Lands with/after" text in bodies.
   - Draft or held PRs.

   Anything whose dependency is still open goes to a later wave.
3. **Collisions.** Intersect the likely-file sets pairwise (re-grep if an issue lacks them). Shared
   templates, shared CSS, and config files are the usual culprits. For each overlap, either:
   - put both issues in one batch, or
   - name one owner, and tell the other batch in writing to leave that file alone.

   Trial merges prove nothing: conflicts show up after the first merge lands.
4. **Batch.** Group issues that share a domain and file set, so each batch is one reviewable PR:
   - Aim for 1–4 issues and a diff a person can read in one sitting.
   - Keep `needs-local` issues together, so the local check happens once.
5. **Route** each batch (section 3): its tier, then a vendor and model, then a run location.
6. **Write the tracker** from `templates/tracker.md`, as an issue labeled `run-tracker` in the
   milestone. For each batch it holds:
   - the waves and the collision owners
   - a brief, rendered from `templates/brief.md`

   The tracker is where the live state lives, so no manifest gets committed per run.
7. If new issues land in the milestone mid-run, re-run `plan`. It re-plans the waves that haven't
   started and leaves running batches alone.

### dispatch `<milestone> [wave]`

Launch a wave. Start only batches whose dependencies are merged, and say which ones are waiting on
what.

- **Cloud (Claude).** One cloud session per batch, created with the routed `model`. The first
  message is `/goal <condition>` followed by the brief. Prefer a session per batch over worktrees
  in one container: each session gets its own disk allowance and rate limits, and several
  parallel `npm ci`s in one container will run out of disk.
- **Local (Claude).** A suggested-task card (or a printed prompt, if the host has no cards)
  carrying the brief. The user starts it on their machine in a worktree. Inside the session, the
  in-harness Agent tool with a `model` override is the lane mechanism. Child `claude -p` processes
  are not.
- **Codex / Gemini (Antigravity or Gemini CLI).** Pin the brief in the tracker as a copy-paste
  block and tell the user which tool and model to paste it into. Those tools can't be launched from
  here, so the batch rejoins the system through its branch name and PR (section 4).
- Record each launch in the tracker: batch, vendor/model, session or card link, time started.

### review gate

Runs on each batch PR once CI is green on its head.

1. Two reviewers from different model families where available:
   - the repo's own review skill (or a `code-review` pass) on a standard-tier Claude model
   - Codex review, if the repo has it
2. Verify every finding yourself before relaying it. Check the finding's commit against the PR
   head, since the lane may already have fixed it. Relay only real findings to the batch, which
   fixes them and pushes.
3. When the PR is green with no unanswered verified findings, add it to the tracker's **Review
   queue**:
   - the link
   - one line on what changed
   - what proves it (the check run, gate output)
   - the **Local check before merge** steps, if any

   Then tell the user. That queue is the human's inbox.

### close-out

Runs after each merge the human makes.

1. `post-merge` for the linked issues: close with a completion comment and tick the acceptance
   criteria.
2. Mark the batch merged in the tracker. Check squash merges by content, not ancestry.
3. Dispatch whatever that merge unblocked, if the user has said to keep the wave rolling.
   Otherwise list what's now ready.
4. Keep a check-in scheduled (roughly hourly) while any batch PR is open. A quiet check-in writes
   nothing.

### release `<milestone>`

Runs when the milestone has no open issues. The tracker counts as open until this stage closes it.

1. Open the release-prep PR the adapter describes (release notes entry, version bump) against the
   base branch.
2. After the human merges it, hand them the adapter's human-only release steps (tag, promoting the
   release branch, publishing the release) as text. **Never run them.**
3. Close the tracker and the milestone. Update epic progress on parents with children in later
   milestones.

## 3. Routing

A batch's tier is the **highest** tier among its issues. If a label contradicts the body, trust
the body and say you overrode it.

| Tier | Claude | Codex | Gemini (Antigravity / CLI) |
|---|---|---|---|
| light: mechanical, narrow, unambiguous | haiku | — | Flash |
| standard: well-scoped, follows an existing pattern | sonnet | default reasoning | Pro |
| advanced: cross-cutting, real tradeoffs | opus | high reasoning | — |
| frontier: architecture-level, high blast radius | not batched: orchestrator or human | — | — |
| browser checks: walk a flow, eyeball a screen | — | — | Antigravity browser agent |

- **Default to Claude cloud.** Use the other vendors for **parallelism** (separate rate limits let
  more batches run at once) and for work that has to happen on the user's machine anyway.
- **Run location** is `local` when a batch has a `needs-local` issue, or when its proof needs
  anything the adapter lists as local-only. Otherwise `cloud`.
- **Cross-vendor review.** A batch written by one model family should be reviewed by another.
- Record the route in the PR body: a `Lane: <vendor>/<model>, <cloud|local>` line, so the human
  can see who did what.

## 4. Conventions every lane follows

- Branch `batch/<milestone>-<slug>` off the adapter's base branch, fresh from the remote. Never a
  stale local checkout.
- One PR per batch, body rendered from the repo's template, with every covered issue linked
  (`Closes #n`).
- The brief's `/goal` condition has to be something the session can **show** in its own output:
  gate commands passing, the check run green, threads answered. It can't be "the code is good".
- No lane uses a notification-wait tool to watch CI. Poll with a blocking loop, or end the turn and
  let the PR subscription wake it.
- A lane that dies after pushing may still have left a PR. Check the branch and PR head before
  re-dispatching, and resume the old session rather than starting fresh.
- Non-Claude tools read `AGENTS.md` (Codex) or `GEMINI.md` (Gemini). When a repo treats
  `CLAUDE.md` as canon, symlink those locally rather than keeping copies. Skills go in
  `.agents/skills/` for those tools; see `skill-parity`.

## 5. Templates

- `templates/brief.md`: the per-batch brief, vendor-neutral, pasteable anywhere.
- `templates/tracker.md`: the run tracker issue body.
- `templates/intake-issue.md`: the extra sections intake adds to every issue.
