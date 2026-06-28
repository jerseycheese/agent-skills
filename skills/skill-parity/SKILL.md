---
name: skill-parity
description: >
  Keeps skills in sync across Claude Code, Codex, Gemini CLI, and shared .agents/skills paths.
  Handles copying, updating, pruning, and verifying parity across all provider locations.
  Trigger on: "sync my skills", "hydrate codex with skills", "copy skill to gemini",
  "add this skill to codex", "update skills across providers", "skill parity check",
  "push skills to all providers", "are my skills in sync", "propagate skill changes".
---

# Skill Parity

Keep skills aligned across Claude Code, Codex, Gemini CLI, and the shared Agent Skills layout. Treat Claude as canon only when the user has made that explicit or recent audit context shows Claude is the cleaned source of truth.

## Canonical source: the agent-skills repo (push-based)

The single source of truth for hand-authored skills is the public repo `jerseycheese/agent-skills` (cloned at `~/Projects/shared/agent-skills`), which is also a Claude Code plugin marketplace (`jack-skills` -> plugin `workflow-skills`). The intended flow is:

1. Edit a skill once in the repo.
2. `git push`.
3. Claude Code picks it up via `claude plugin marketplace update` (or restart) — no manual copy into `~/.claude/skills/`.
4. Codex and Gemini hydrate `~/.agents/skills/` from the same repo via the copy/symlink paths below (or the `find-skills` installer).

So prefer editing in the repo and pushing over hand-copying between provider dirs. The legacy `~/.claude/skills/` copies remain only as a fallback until the marketplace plugin is confirmed loading; once verified, they can be removed to avoid duplicate definitions. The manual copy/prune/hash steps below still apply when working outside the repo or syncing a one-off.

## Research-first rule

Before adding, editing, pruning, or syncing Codex/Gemini skills, verify current official guidance. Do this even if this skill contains advice that seems current.

Primary docs to check:
- Codex Agent Skills: `https://developers.openai.com/codex/skills`
- OpenAI skill-creator guidance: `https://github.com/openai/skills/blob/main/skills/.system/skill-creator/SKILL.md`
- Gemini CLI Agent Skills: `https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills.md`
- Gemini creating skills: `https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/creating-skills.md`
- Gemini skill best practices: `https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills-best-practices.md`

If the docs conflict with this skill, follow the docs and update this skill as part of the same work. If network access is unavailable, say so and avoid changing provider-specific best-practice claims.

## Source and scope

1. Identify the source skill name and scope: user, workspace, admin, system, or extension/plugin.
2. Identify whether the source is canonical, provider-specific, or stale.
3. If the user recently audited one provider, treat that provider as canon for pruning and hydration unless they say otherwise.
4. Do not silently merge divergent skills with the same name. Confirm intentional provider-specific behavior before preserving divergence.

## Provider paths

### Shared Agent Skills layout

Prefer these paths for skills intended to work in both Codex and Gemini CLI:
- User: `$HOME/.agents/skills/<skill-name>/SKILL.md`
- Workspace: `$REPO_ROOT/.agents/skills/<skill-name>/SKILL.md`

Use `.agents/skills` as the shared mirror for Codex/Gemini whenever practical. Do not prune unrelated `.agents/skills` entries unless the user explicitly asks; other tools may own them.

### Claude Code

- User: `~/.claude/skills/<skill-name>/SKILL.md`
- Workspace: `.claude/skills/<skill-name>/SKILL.md`

### Codex

Current docs center the shared Agent Skills layout:
- User: `$HOME/.agents/skills/<skill-name>/SKILL.md`
- Workspace: `.agents/skills/<skill-name>/SKILL.md`
- Admin: `/etc/codex/skills/<skill-name>/SKILL.md` only if requested

Do not mirror to `~/.codex/skills/` — Codex loads both that path and `~/.agents/skills/` simultaneously, which produces duplicates in the loaded prompt. The one exception is `~/.codex/skills/.system/`, which holds Codex's bundled defaults — never touch it.

### Gemini CLI

- User: `~/.agents/skills/<skill-name>/SKILL.md` (preferred), or `~/.gemini/skills/<skill-name>/SKILL.md` only if it already exists
- Workspace: `.agents/skills/<skill-name>/SKILL.md` (preferred), or `.gemini/skills/<skill-name>/SKILL.md` only if it already exists

Gemini uses `.agents/skills` as an interoperable alias. Within the same tier, `.agents/skills` takes precedence over `.gemini/skills`. Default new skills to `.agents/skills`; only touch `.gemini/skills` when an existing install already lives there.

## File and metadata rules

- Entry file is exactly `SKILL.md`; wrong casing can break discovery.
- YAML frontmatter includes `name` and `description`.
- `name` is a stable, hyphenated identifier and should match the directory name.
- `description` is the trigger surface. Front-load likely user words, define when to use the skill, and add boundaries so it does not overlap unrelated skills.
- Keep `description` concise enough to survive truncation in skill lists.
- Keep `SKILL.md` focused on the core procedure. Move detailed reference material, schemas, and long examples into `references/`.
- Use `scripts/` for deterministic or fragile repeated operations. Script output should be concise and LLM-readable.
- Use `assets/` for templates and non-executable resources.
- Avoid hardcoded secrets in instructions, scripts, examples, and assets.

## Platform-specific enhancements

### Codex

- Add or update `agents/openai.yaml` when the skill benefits from Codex UI metadata, invocation policy, or tool dependencies.
- On updates, validate `agents/openai.yaml` still matches `SKILL.md`.
- Include `display_name`, `short_description`, or `default_prompt` when they can be derived from the skill.
- Include optional fields such as icons and brand color only when explicitly provided or already established.
- Use `policy.allow_implicit_invocation: false` only for explicit-only skills.
- Declare required MCP tools under `dependencies.tools` when a skill needs them.

### Gemini CLI

- Prefer `.agents/skills` for new skills. Only write to `.gemini/skills` if an existing install already uses it.
- Validate with `/skills reload` or `gemini skills list` when available.
- If Gemini's creation or validation scripts are available in the local CLI checkout, use them for new skills.
- Remember that Gemini asks for consent before activating a skill and grants access to the whole skill directory after approval.

## Sync workflow

1. Research current official Codex/Gemini guidance first.
2. Normalize the source skill: exact `SKILL.md`, valid frontmatter, focused trigger description, and clean resource folders.
3. Copy the full skill directory, including `scripts/`, `references/`, `assets/`, and provider metadata.
4. Write shared Codex/Gemini copies to `.agents/skills` — this is the canonical mirror for both providers.
5. Do not mirror to `.codex/skills` (causes duplicate skill loads in Codex). Only touch `.gemini/skills` if an existing install already uses it.
6. Prune stale provider mirrors only when the source canon and ownership are clear.
7. Preserve intentional provider-specific deviations only after confirming the reason.
8. Verify inventory and content parity with hashes across every target scope.
9. Tell the user which scopes changed and whether a restart or `/skills reload` is needed.

## Verification checklist

- [ ] Official Codex/Gemini docs checked, or unavailable status reported.
- [ ] Exact `SKILL.md` casing everywhere.
- [ ] `name` and directory name align.
- [ ] `description` has clear triggers and boundaries.
- [ ] Long reference content is moved out of `SKILL.md`.
- [ ] Scripts are deterministic, scoped, and do not expose secrets.
- [ ] Shared `.agents/skills` copy exists when interoperability is intended.
- [ ] No copies written to `~/.codex/skills/` (Codex's `.system/` dir is left untouched).
- [ ] Hash parity verified for all intended mirrors.
