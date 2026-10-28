# agent-skills

A collection of agent skills usable across Claude Code, Codex, Antigravity, and any tool that reads a shared `.agents/skills` directory. Each skill lives in its own directory under `skills/`, with a single `SKILL.md` whose frontmatter tells the agent when to invoke it and what to do.

## Skills

Grouped by type. Each links to its `SKILL.md`.

### Issue & backlog workflow

- **[analyze-issue](skills/analyze-issue/SKILL.md)** — Read a GitHub issue and produce a technical spec with scope, patterns, and MVP tests.
- **[prioritize-issues](skills/prioritize-issues/SKILL.md)** — Rank the backlog by value, effort, age, and roadmap fit. Returns a top-5 with specs for the top 3.
- **[issue-maintenance](skills/issue-maintenance/SKILL.md)** — Periodic maintenance pass over the open-issue backlog: fix labels, re-score priority, fill sizing, clean up prose, and propose merging clusters of small issues. Never touches source files.
- **[ship-issue](skills/ship-issue/SKILL.md)** — Drive one issue from cold start to merged PR: sync, analyze, minimal fix with a test, PR, CI green, post-merge cleanup, wrap-up.
- **[backlog-routing](skills/backlog-routing/SKILL.md)** — Work a milestone with many agents at once: intake findings into issues, shape the milestone, split it into collision-free batches, route each through `route` to the cheapest capable seat (Claude, Codex, Gemini) in cloud or local, review with a second model family (the repo's automated reviewer counts), and merge only as the repo's adapter allows. The default is human-only, with a review queue for the human. Needs a small per-repo adapter skill. Ships a read-only run dashboard (`dashboard/index.html`, `?demo=1` for a sample).
- **[route](skills/route/SKILL.md)** — Recommend which provider and model to run a task on, from your own routing table plus current subscription burn. Recommends only; logs overrides. Ships a starter `ai-routing.example.md`.
- **[update-routing](skills/update-routing/SKILL.md)** — Refresh the model roster in the routing table `route` reads when new models ship. Compares models within each provider only, and sources and dates every number.
- **[post-merge](skills/post-merge/SKILL.md)** — After a PR merges: close out linked issues, then recommend the single best next thing to work on.

### Code review & quality

- **[kiss](skills/kiss/SKILL.md)** — Strip a diff down to the minimum surface needed for its goal. Drops the "while I'm here" extras.
- **[abstraction-finder](skills/abstraction-finder/SKILL.md)** — Scan a codebase or area for recurring patterns that could be extracted into shared, general-purpose code. Proposes the smallest form per cluster with the call sites it replaces; enforces the rule of three. The DRY counterweight to KISS.
- **[band-aid-finder](skills/band-aid-finder/SKILL.md)** — Scan a change or area for fixes that suppress a symptom instead of resolving the cause; trace the root cause and propose the real fix. Allows deliberate, documented mitigations. The counterweight to KISS on the other axis.
- **[code-health-audit](skills/code-health-audit/SKILL.md)** — The "embarrassing code" / overengineering sweep. Turns vague tech-debt into a short list of measurable, validated simplifications to ship.
- **[pr-review-fix-pipeline](skills/pr-review-fix-pipeline/SKILL.md)** — Review a PR and apply fixes for the non-controversial issues in one pass.
- **[evidence-check](skills/evidence-check/SKILL.md)** — Honesty gate for AI claims. Classifies each claim by evidence tier (verified / confirmed / inferred / unverified) and blocks guesses from being stated as fact. State claims default to unverified until a file's been read or a command run.

### Testing

- **[tdd-implement](skills/tdd-implement/SKILL.md)** — Red-green-refactor. Tests track acceptance criteria, not implementation details.
- **[test-fix](skills/test-fix/SKILL.md)** — Diagnose and fix failing tests with a hard 3-attempt limit per failure to avoid debugging spirals.
- **[test-workflow](skills/test-workflow/SKILL.md)** — Pick and run the right suite (unit, E2E, visual, CSS lint) after a source edit, before commit.
- **[test-reaper](skills/test-reaper/SKILL.md)** — Find and remove dead or trivial tests — duplicates and tests that only assert a mock was called — after confirming the suite is green.

### Cleanup — code, comments, docs, prose

- **[dead-code-cleanup](skills/dead-code-cleanup/SKILL.md)** — Find and remove orphaned code, files, and stale stories after verifying nothing uses them.
- **[comment-reaper](skills/comment-reaper/SKILL.md)** — Remove unnecessary comments — the ones that restate the code — after reading the code under each to confirm it's redundant, not load-bearing.
- **[doc-rot](skills/doc-rot/SKILL.md)** — Sniff out stale docs, comments, docstrings, and commented-out code. Grounds every staleness call against the actual code, auto-fixes the safe rot, surfaces judgment calls.
- **[plain-language-audit](skills/plain-language-audit/SKILL.md)** — Sweep comments, docs, and UI copy for jargon, AI writing tells, and verbosity. Auto-fixes the unambiguous stuff, surfaces judgment calls.

### Frontend & visual

- **[ds-guard](skills/ds-guard/SKILL.md)** — Audit styling changes against the project's design tokens and showcase. Flags hardcoded values, Tailwind utilities, and off-system tokens.
- **[visual-crawl](skills/visual-crawl/SKILL.md)** — Crawl the running app at random breakpoints, screenshot regressions, check token consistency.
- **[visual-qa-pipeline](skills/visual-qa-pipeline/SKILL.md)** — Take a visual crawl all the way to shipped work: triage findings, file Major+ as GitHub issues with screenshots, batch the small stuff, and open fix PRs for mechanical token violations. Schedulable.
- **[browser-debugger-cli](skills/browser-debugger-cli/SKILL.md)** — Inspect live pages via the Chrome DevTools Protocol through the `bdg` CLI. Token-efficient alternative to a full page snapshot.
- **[github-screenshot](skills/github-screenshot/SKILL.md)** — Generate GitHub image markdown that renders in private repos (SHA-pinned github.com `?raw=true` links).

### Dev environment, CI & setup

- **[project-bootstrap](skills/project-bootstrap/SKILL.md)** — Stamp a new repo's agent scaffolding: a CLAUDE.md from the house template, starter settings, and a launch.json with a free port.
- **[worktree-enhanced](skills/worktree-enhanced/SKILL.md)** — Set up a git worktree with branch, dev-server detection, and project-specific setup.
- **[ci-fix-with-memory](skills/ci-fix-with-memory/SKILL.md)** — Auto-invoke when CI is red. Reads handoffs and a known-issues log so the same fix isn't tried twice.
- **[skill-parity](skills/skill-parity/SKILL.md)** — Keep skills in sync across Claude Code, Codex, Antigravity, and shared `.agents/skills` paths.

### Session & communication

- **[project-pulse](skills/project-pulse/SKILL.md)** — Read-only status sweep across every git repo under a projects folder, plus recent agent sessions when the agent can read them. Sorts into waiting on you, stranded work, ready to pick up, and dormant, and leads with one next action. Ships a small `collect.sh` that reads origin, never the local checkout.
- **[wrap-it-up](skills/wrap-it-up/SKILL.md)** — Close out a chat with a tight summary and a sweep of related context files (memory, plans, status, logs).
- **[cyoa](skills/cyoa/SKILL.md)** — Choose Your Own Adventure mode. Frame the task as a branching story; every fork is a real design decision.
- **[drupal-mental-model](skills/drupal-mental-model/SKILL.md)** — Explain code by mapping framework concepts to Drupal equivalents, for a Drupal/theming background.

## Layout

```
skills/
  <skill-name>/
    SKILL.md    # frontmatter (name, description) + body (the actual instructions)
```

The `description` field is what the agent reads to decide whether to invoke the skill — keep trigger phrases concrete and current.

Keep descriptions short: what the skill does, when to use it, and three or four trigger phrases. Claude Code caps the total size of its skill list, so long descriptions push other skills out of it, and routing notes like "not for X, use Y" belong in the body. CI runs `.github/scripts/lint-skills.py`, which fails on a description over 400 characters, a `name` that doesn't match its folder, a skill missing from `marketplace.json` or this README, or an absolute `/Users/` path.

After changing a description, run `python3 .github/scripts/eval-triggers.py`. It checks the prompts in `evals/triggers.tsv` (one `skill<TAB>prompt` per line; a leading `-` means that skill must not win) against every description. It's a word-overlap proxy, not the real router, so it catches a dropped trigger phrase but not a subtle misroute. CI runs it too, and it fails when a skill has no line in the file, so a new skill needs at least one request that should pick it. Add a line when a skill misfires.

CI also runs `bash -n` over every script under `skills/`, and `.github/scripts/test-pr-ready.sh`, which drives `pr-ready.sh`'s merge gate against a fake `gh`. If you change that gate, add a case there.

## Install

Each agent looks for skills in a specific directory. Copy or symlink the skill folder (the whole thing, not just `SKILL.md`) into the right path for whichever tool you're using.

| Tool | User-level (available everywhere) | Project-level (this repo only) |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<skill-name>/` | `.claude/skills/<skill-name>/` |
| Codex | `~/.agents/skills/<skill-name>/` | `.agents/skills/<skill-name>/` |
| Antigravity | `~/.gemini/config/skills/<skill-name>/` (CLI only: `~/.gemini/antigravity-cli/skills/<skill-name>/`) | `.agents/skills/<skill-name>/` |

At project level, `.agents/skills` is the interoperable spot: Codex and Antigravity both read it, so one copy covers both. At user level they differ. Codex reads `~/.agents/skills`, but Antigravity doesn't, so a global skill needs a copy in each.

Quick install for a single skill in Claude Code:

```bash
cp -r skills/kiss ~/.claude/skills/
```

Or symlink if you want updates to flow back to this repo automatically:

```bash
ln -s "$(pwd)/skills/kiss" ~/.claude/skills/kiss
```

If you're juggling all three tools, the [skill-parity](skills/skill-parity/SKILL.md) skill handles copying, updating, and pruning across every provider path in one pass — that's the path worth taking if you're maintaining more than a couple of skills.

### Claude Code via marketplace (no manual copy)

This repo is also a Claude Code plugin marketplace, so Claude can install every skill at once and pull updates with a `git push` instead of a manual copy:

```bash
claude plugin marketplace add jerseycheese/agent-skills
claude plugin install workflow-skills@jerseycheese-skills
```

After that, `claude plugin marketplace update` (or a restart) picks up new commits. Codex and Antigravity still use the copy/symlink paths above; this repo stays the single source for all of them.

Installed skills are namespaced as `workflow-skills:<name>`. They're model-invoked — Claude runs them automatically when your request matches the skill's description, so they won't show up in the `/` slash-command menu. Browse them with `/skills`, or just describe the task (e.g. "prioritize my issues").

After installing, restart the agent (or reload skills from Antigravity's skill inventory) so the new skill is picked up.
