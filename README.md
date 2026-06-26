# agent-skills

A collection of agent skills usable across Claude Code, Codex, Gemini CLI, and any tool that reads a shared `.agents/skills` directory. Each skill lives in its own directory with a single `SKILL.md` whose frontmatter tells the agent when to invoke it and what to do.

## Skills

- **[analyze-issue](analyze-issue/SKILL.md)** — Read a GitHub issue and produce a technical spec with scope, patterns, and MVP tests.
- **[browser-debugger-cli](browser-debugger-cli/SKILL.md)** — Inspect live pages via the Chrome DevTools Protocol through the `bdg` CLI. Token-efficient alternative to a full page snapshot.
- **[ci-fix-with-memory](ci-fix-with-memory/SKILL.md)** — Auto-invoke when CI is red. Reads handoffs and a known-issues log so the same fix isn't tried twice.
- **[code-health-audit](code-health-audit/SKILL.md)** — The "embarrassing code" / overengineering sweep. Turns vague tech-debt into a short list of measurable, validated simplifications to ship.
- **[cyoa](cyoa/SKILL.md)** — Choose Your Own Adventure mode. Frame the task as a branching story; every fork is a real design decision.
- **[dead-code-cleanup](dead-code-cleanup/SKILL.md)** — Find and remove orphaned code, stale stories, and trivial tests after verifying nothing uses them.
- **[drupal-mental-model](drupal-mental-model/SKILL.md)** — Explain code by mapping framework concepts to Drupal equivalents, for a Drupal/theming background.
- **[ds-guard](ds-guard/SKILL.md)** — Audit styling changes against the project's design tokens and showcase. Flags hardcoded values, Tailwind utilities, and off-system tokens.
- **[github-screenshot](github-screenshot/SKILL.md)** — Generate GitHub-compatible image markdown via `raw.githubusercontent.com` URLs.
- **[kiss](kiss/SKILL.md)** — Strip a diff down to the minimum surface needed for its goal. Drops the "while I'm here" extras.
- **[post-merge](post-merge/SKILL.md)** — After a PR merges: close out linked issues, then recommend the single best next thing to work on.
- **[pr-review-fix-pipeline](pr-review-fix-pipeline/SKILL.md)** — Review a PR and apply fixes for the non-controversial issues in one pass.
- **[prioritize-issues](prioritize-issues/SKILL.md)** — Rank the backlog by value, effort, age, and roadmap fit. Returns a top-5 with specs for the top 3.
- **[project-bootstrap](project-bootstrap/SKILL.md)** — Stamp a new repo's agent scaffolding: a CLAUDE.md from the house template, starter settings, and a launch.json with a free port.
- **[ship-issue](ship-issue/SKILL.md)** — Drive one issue from cold start to merged PR: sync, analyze, minimal fix with a test, PR, CI green, post-merge cleanup, wrap-up.
- **[skill-parity](skill-parity/SKILL.md)** — Keep skills in sync across Claude Code, Codex, Gemini CLI, and shared `.agents/skills` paths.
- **[tdd-implement](tdd-implement/SKILL.md)** — Red-green-refactor. Tests track acceptance criteria, not implementation details.
- **[test-fix](test-fix/SKILL.md)** — Diagnose and fix failing tests with a hard 3-attempt limit per failure to avoid debugging spirals.
- **[test-workflow](test-workflow/SKILL.md)** — Pick and run the right suite (unit, E2E, visual, CSS lint) after a source edit, before commit.
- **[visual-crawl](visual-crawl/SKILL.md)** — Crawl the running app at random breakpoints, screenshot regressions, check token consistency.
- **[visual-qa-pipeline](visual-qa-pipeline/SKILL.md)** — Take a visual crawl all the way to shipped work: triage findings, file Major+ as GitHub issues with screenshots, batch the small stuff, and open fix PRs for mechanical token violations. Schedulable.
- **[worktree-enhanced](worktree-enhanced/SKILL.md)** — Set up a git worktree with branch, dev-server detection, and project-specific setup.
- **[wrap-it-up](wrap-it-up/SKILL.md)** — Close out a chat with a tight summary and a sweep of related context files (memory, plans, status, logs).

## Layout

```
<skill-name>/
  SKILL.md    # frontmatter (name, description) + body (the actual instructions)
```

The `description` field is what the agent reads to decide whether to invoke the skill — keep trigger phrases concrete and current.

## Install

Each agent looks for skills in a specific directory. Copy or symlink the skill folder (the whole thing, not just `SKILL.md`) into the right path for whichever tool you're using.

| Tool | User-level (available everywhere) | Project-level (this repo only) |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<skill-name>/` | `.claude/skills/<skill-name>/` |
| Codex | `~/.agents/skills/<skill-name>/` | `.agents/skills/<skill-name>/` |
| Gemini CLI | `~/.gemini/skills/<skill-name>/` or `~/.agents/skills/<skill-name>/` | `.gemini/skills/<skill-name>/` or `.agents/skills/<skill-name>/` |

The `.agents/skills` path is the interoperable spot — Codex and Gemini both read from it, so it's the path to pick if you want one copy to cover both.

Quick install for a single skill in Claude Code:

```bash
cp -r kiss ~/.claude/skills/
```

Or symlink if you want updates to flow back to this repo automatically:

```bash
ln -s "$(pwd)/kiss" ~/.claude/skills/kiss
```

If you're juggling all three tools, the [skill-parity](skill-parity/SKILL.md) skill handles copying, updating, and pruning across every provider path in one pass — that's the path worth taking if you're maintaining more than a couple of skills.

### Claude Code via marketplace (no manual copy)

This repo is also a Claude Code plugin marketplace, so Claude can install every skill at once and pull updates with a `git push` instead of a manual copy:

```bash
claude plugin marketplace add jerseycheese/agent-skills
claude plugin install workflow-skills@jerseycheese-skills
```

After that, `claude plugin marketplace update` (or a restart) picks up new commits. Codex and Gemini still use the copy/symlink paths above; this repo stays the single source for all of them.

Installed skills are namespaced as `workflow-skills:<name>`. They're model-invoked — Claude runs them automatically when your request matches the skill's description, so they won't show up in the `/` slash-command menu. Browse them with `/skills`, or just describe the task (e.g. "prioritize my issues").

After installing, restart the agent (or run `/skills reload` in Gemini) so the new skill is picked up.
