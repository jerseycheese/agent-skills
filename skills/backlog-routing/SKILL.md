---
name: backlog-routing
description: >
  A milestone-driven system for working a GitHub backlog with several agents at once while a human
  stays the only merge gate. Seven stages, each run only when asked: intake (turn playtest notes,
  screenshots, or findings into labeled issues), shape (propose a milestone's contents and ordered
  plan), plan (split the milestone into collision-free batches, route each through the `route`
  skill to the cheapest capable seat, and pick cloud or local), dispatch (start the batches:
  paste-ready briefs for tools that can't be launched from the orchestrator, local agent sessions,
  or cloud agent sessions driven by a goal condition), review gate
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
| Which provider and model | `route` (your routing table plus current burn) |
| Ranking | `prioritize-issues` |
| Labels, dedupe, clustering | `issue-maintenance` |
| Visual finding triage | `visual-qa-pipeline` (its severity ladder) |
| Work inside a lane | `analyze-issue` → `tdd-implement` → `ship-issue` steps 1–5 |
| CI red | `ci-fix-with-memory` |
| After merge | `post-merge` |
| Claims of done | `evidence-check` |

Don't re-implement any of those here.

**Requirements.** GitHub for issues, milestones, sub-issues and PRs (`gh`, or a GitHub MCP
server). Any agent host works for the orchestrator. Where this skill names a specific tool (Claude
Code, Codex, Antigravity), it's an example of a kind of lane, not a requirement.

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
   - Open issues in the milestone, with bodies and comments. The `run-tracker` issue isn't work:
     leave it out of batching, and if one already exists, update it in place instead of making
     another.
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
5. **Route** each batch through `route` (section 3). That gives each batch a seat, a brief shape
   (one brief, or one per issue), and a run location. It also gives each wave a lane count that
   fits the 5-hour window. If `route` says to wait for a reset, the wave waits.
6. **Write the tracker** from `templates/tracker.md`, as an issue labeled `run-tracker` in the
   milestone. For each batch it holds:
   - the waves and the collision owners
   - a brief, rendered from `templates/brief.md`

   The tracker is where the live state lives, so no manifest gets committed per run. Fill in its
   `backlog-routing:state` block too (section 6).
7. If new issues land in the milestone mid-run, re-run `plan`. It re-plans the waves that haven't
   started and leaves running batches alone.

### dispatch `<milestone> [wave]`

Launch a wave. Start only batches whose dependencies are merged, and say which ones are waiting on
what.

Before launching, show the `route` block for each batch in the wave and wait for the user's OK.
`route` recommends; the user decides. Then, by seat:

- **Paste-brief lanes** (tools the orchestrator can't launch, such as Antigravity or the Codex CLI).
  Pin the brief (or briefs) in the tracker as copy-paste blocks, and tell the user which tool and
  model to paste each into. On a seat that drops multi-issue
  briefs, a batch of N issues becomes N briefs run one after another on the same branch, each
  naming one issue. Those tools can't be launched from here, so the batch rejoins the system
  through its branch name and PR (section 4).
- **Local agent sessions.** A task the user starts on their machine in a worktree, carrying the
  brief. Use a suggested-task card if the host has them, otherwise a printed prompt. In Claude Code,
  sub-lanes inside a session use the in-harness Agent tool with a `model` override; child
  `claude -p` processes don't work as lanes.
- **Cloud agent sessions.** One cloud session per batch, created with the routed model, whose
  first message sets the goal condition and then gives the brief (`/goal <condition>` in Claude
  Code). Prefer a session per batch over worktrees in one container, so parallel installs don't
  run out of disk. A cloud session spends the same subscription window as local use of that
  provider. Use one only when `route` puts the batch on that provider and its proof doesn't need
  anything local-only.
- **Record each launch** in the tracker (batch, seat, session or card link, time started), and set
  the batch's `status` to `dispatched` with `dispatchedAt` in the state block. Log each
  route with `route`'s logger, passing the chosen seat whenever it differs from the recommendation.

### review gate

Runs on each batch PR once CI is green on its head.

1. Two reviewers from different model families where available:
   - the seat `route` picks for the code review phase, which must not be the family that wrote
     the batch
   - an automated reviewer the repo already runs (Codex review, say)

   Security, concurrency, and architectural diffs get the table's escalation seat.
2. Verify every finding yourself before relaying it. Check the finding's commit against the PR
   head, since the lane may already have fixed it. Relay only real findings to the batch, which
   fixes them and pushes.
3. When the PR is green with no unanswered verified findings, add it to the tracker's **Review
   queue**:
   - the link
   - one line on what changed
   - what proves it (the check run, gate output)
   - the **Local check before merge** steps, if any

   Set the batch's `pr` and `status` in the state block, and `localCheck` if one is needed. Then
   tell the user. That queue is the human's inbox.

### close-out

Runs after each merge the human makes.

1. `post-merge` for the linked issues: close with a completion comment and tick the acceptance
   criteria.
2. Mark the batch merged in the tracker and its state block. Check squash merges by content, not
   ancestry.
3. **Check every issue actually shipped.** For each issue the batch named, confirm the merged PR
   closes it and its diff touches that issue's files. On a seat known to drop work, a batch can
   merge with one issue silently skipped. Put any dropped issue back into `plan`, and note what
   the recovery cost in the tracker, so the routing table's recovery rule has data behind it.
4. Dispatch whatever that merge unblocked, if the user has said to keep the wave rolling.
   Otherwise list what's now ready.
5. Keep a check-in scheduled (roughly hourly) while any batch PR is open. A quiet check-in writes
   nothing.

### release `<milestone>`

Runs when the only open issue left in the milestone is the `run-tracker` issue. This stage closes
the tracker at the end.

1. Open the release-prep PR the adapter describes (release notes entry, version bump) against the
   base branch.
2. After the human merges it, hand them the adapter's human-only release steps (tag, promoting the
   release branch, publishing the release) as text. **Never run them.**
3. Close the tracker and the milestone. Update epic progress on parents with children in later
   milestones.

## 3. Routing

**`route` makes the call, not this skill.** Your routing table (see the `route` skill's setup)
already says which seat leads each phase of work, and `route` adds current burn. Keeping a second
table here would drift from yours. So for each batch, pass `route` the phase and the shape:

| Stage or work | Phase to pass `route` |
|---|---|
| `intake`, `shape`, `plan` | planning, specs, architecture |
| a batch of independent issues | bulk implementation |
| a wave of independent batches | simple parallel dispatch |
| batches that depend on each other, or need re-planning mid-run | complex orchestration |
| review gate | code review |
| a batch whose CI stays red | root-cause debugging |
| `close-out`, `release`, tracker upkeep | anything unnamed |

Also pass: how many issues the batch holds, how many batches run at once, and whether it's a
autonomous goal run. Those decide which usage window the work spends and whether a brief has to be split.

**Rules that stay here:**

- **Lane count comes from the window.** When `route` says the right seat is tight, run fewer lanes
  in the wave rather than moving batches to a scarcer seat.
- **Run location.** `local` when a batch has a `needs-local` issue, when its proof needs anything
  the adapter lists as local-only, or when `route` puts it on a local-only tool (Antigravity,
  Codex CLI). Otherwise `cloud`.
- **Keep the orchestrator light.** The stages here are mostly mechanical, so run them on the
  table's default seat, and escalate only for a genuinely hard `plan`. Run them where `route` can
  read burn, usually the user's machine. A cloud orchestrator has to ask for a burn reading.
- **Cross-family review.** The family that wrote a batch doesn't review it.
- **Record the lane** in the PR body with a `Lane: <provider>/<model>, <cloud|local>` line, so the
  human can see who did what.

**Fallback, only when `route` can't run at all** (no table on this machine, no reading from the
user). Use the issue's model-tier label, say the pick has no usage data behind it, and prefer the
highest-throughput seat for implementation:

| Tier label | Fallback seat |
|---|---|
| light, standard | the table's bulk-implementation seat, one issue per brief |
| advanced | a strong reasoning seat |
| frontier | not batched: the orchestrator or the human |

## 4. Conventions every lane follows

- Branch `batch/<milestone>-<slug>` off the adapter's base branch, fresh from the remote. Never a
  stale local checkout.
- One PR per batch, body rendered from the repo's template, with every covered issue linked
  (`Closes #n`).
- The brief's goal condition has to be something the session can **show** in its own output:
  gate commands passing, the check run green, threads answered. It can't be "the code is good".
- No lane uses a notification-wait tool to watch CI. Poll with a blocking loop, or end the turn and
  let the PR subscription wake it.
- **One issue per brief on seats that drop work.** A multi-issue batch on such a seat runs as one
  brief per issue on the shared branch. Each brief says which issues earlier briefs already
  handled, and names its own issue only.
- A lane that dies after pushing may still have left a PR. Check the branch and PR head before
  re-dispatching, and resume the old session rather than starting fresh.
- Each tool reads its own instruction file (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, and so on).
  Keep one canonical file and symlink the others locally rather than keeping copies. Shared skills
  go in `.agents/skills/`; see `skill-parity`.

## 5. Templates

- `templates/brief.md`: the per-batch brief, vendor-neutral, pasteable anywhere.
- `templates/tracker.md`: the run tracker issue body.
- `templates/intake-issue.md`: the extra sections intake adds to every issue.

## 6. Dashboard

`dashboard/index.html` is a read-only board for a run: one self-contained page, no build step, no
backend. It reads the tracker's `backlog-routing:state` block, then layers live GitHub state on
top: PR state, CI on the PR head, review decisions, unresolved threads, and milestone progress.
It flags what needs a look:

- a batch dispatched more than 6 hours ago with no PR (possibly dropped)
- red CI or a merge conflict
- a merged batch whose issues are still open
- a `batch/<milestone>-*` PR the tracker doesn't know about
- a state block that hasn't been updated in 2 hours while batches are open

Every card links out to GitHub. Reviewing and merging still happen there.

**Keeping it accurate.** Every stage that edits the tracker rewrites the state block in the same
edit, and bumps `updated`. The block must stay valid JSON; the page shows a parse error rather
than guessing.

**Opening it.**
- Locally: open the file with
  `?repo=owner/name&milestone=vX.Y` on the end. `?demo=1` shows a sample run.
- Hosted: turn on GitHub Pages for the repo that holds this skill, and open
  `…/skills/backlog-routing/dashboard/?repo=…&milestone=…`, from a phone too.

**Token.** Optional, pasted into Settings, stored only in that browser. Use a fine-grained,
read-only token with Issues, Pull requests and Checks (or Commit statuses) read access on the repo.
Without one, the page works on public repos only (about 60 requests an hour, manual refresh) and
can't count unresolved review threads.

