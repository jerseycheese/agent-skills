# AGENTS.md

A public collection of agent skills for Claude Code, Codex, Antigravity, and any tool that reads a shared `.agents/skills` directory. Each skill is a folder under `skills/` with one `SKILL.md`. README.md has the full list, the layout, and install paths.

## Checks

Run these before opening a PR. CI (`.github/workflows/lint-skills.yml`) runs the same four.

```bash
python3 .github/scripts/lint-skills.py      # frontmatter, description length, README and marketplace.json entries
python3 .github/scripts/eval-triggers.py    # every skill wins its lines in evals/triggers.tsv
find skills -name '*.sh' -print0 | xargs -0 -n1 bash -n
bash .github/scripts/test-pr-ready.sh       # the merge gate in backlog-routing's pr-ready.sh
```

## Rules

- This is a working toolbox first. Don't add a new skill unless someone asks for it in an issue. Fixing and testing the existing skills comes first.
- Skills stay generic. Other people install them, so nothing in a skill names one person's machine, projects, or private files. Machine-specific values come from the user's own config or a repo adapter.
- A new skill needs a row in README.md, an entry in `.claude-plugin/marketplace.json`, and at least one line in `evals/triggers.tsv`.
- Keep a description under 400 characters: what the skill does, when to use it, and three or four trigger phrases.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, worked through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one `GLOSSARY.md` at the repo root, with ADRs under `docs/adr/` once a decision is recorded. See `docs/agents/domain.md`.
