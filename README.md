# agent-skills

A collection of agent skills usable across Claude Code, Codex, Gemini CLI, and any tool that reads a shared `.agents/skills` directory. Each skill lives in its own directory with a single `SKILL.md` whose frontmatter tells the agent when to invoke it and what to do.

## Skills

- **[analyze-issue](analyze-issue/SKILL.md)** — Read a GitHub issue and produce a technical spec with scope, patterns, and MVP tests.
- **[browser-debugger-cli](browser-debugger-cli/SKILL.md)** — Inspect live pages via the Chrome DevTools Protocol through the `bdg` CLI. Token-efficient alternative to a full page snapshot.
- **[ci-fix-with-memory](ci-fix-with-memory/SKILL.md)** — Auto-invoke when CI is red. Reads handoffs and a known-issues log so the same fix isn't tried twice.
- **[cyoa](cyoa/SKILL.md)** — Choose Your Own Adventure mode. Frame the task as a branching story; every fork is a real design decision.
- **[dead-code-cleanup](dead-code-cleanup/SKILL.md)** — Find and remove orphaned code, stale stories, and trivial tests after verifying nothing uses them.
- **[ds-guard](ds-guard/SKILL.md)** — Audit styling changes against the project's design tokens and showcase. Flags hardcoded values, Tailwind utilities, and off-system tokens.
- **[github-screenshot](github-screenshot/SKILL.md)** — Generate GitHub-compatible image markdown via `raw.githubusercontent.com` URLs.
- **[kiss](kiss/SKILL.md)** — Strip a diff down to the minimum surface needed for its goal. Drops the "while I'm here" extras.
- **[post-merge](post-merge/SKILL.md)** — After a PR merges: close out linked issues, then recommend the single best next thing to work on.
- **[pr-review-fix-pipeline](pr-review-fix-pipeline/SKILL.md)** — Review a PR and apply fixes for the non-controversial issues in one pass.
- **[prioritize-issues](prioritize-issues/SKILL.md)** — Rank the backlog by value, effort, age, and roadmap fit. Returns a top-5 with specs for the top 3.
- **[skill-parity](skill-parity/SKILL.md)** — Keep skills in sync across Claude Code, Codex, Gemini CLI, and shared `.agents/skills` paths.
- **[tdd-implement](tdd-implement/SKILL.md)** — Red-green-refactor. Tests track acceptance criteria, not implementation details.
- **[test-fix](test-fix/SKILL.md)** — Diagnose and fix failing tests with a hard 3-attempt limit per failure to avoid debugging spirals.
- **[test-workflow](test-workflow/SKILL.md)** — Pick and run the right suite (unit, E2E, visual, CSS lint) after a source edit, before commit.
- **[visual-crawl](visual-crawl/SKILL.md)** — Crawl the running app at random breakpoints, screenshot regressions, check token consistency.
- **[worktree-enhanced](worktree-enhanced/SKILL.md)** — Set up a git worktree with branch, dev-server detection, and project-specific setup.

## Layout

```
<skill-name>/
  SKILL.md    # frontmatter (name, description) + body (the actual instructions)
```

The `description` field is what the agent reads to decide whether to invoke the skill — keep trigger phrases concrete and current.

## Use

Copy or symlink a skill directory into the agent's skills path. To propagate the same skill across Claude Code, Codex, Gemini CLI, and `.agents/skills` in one pass, use [skill-parity](skill-parity/SKILL.md).
