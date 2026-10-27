---
name: project-bootstrap
description: >
  Stamps a project under your projects folder with the standard agent scaffolding from the starter kit: a
  house-template CLAUDE.md, core config, an optional stack layer, and a row in the root map. Use
  for a new repo or one missing its CLAUDE.md. Trigger on: "bootstrap this project", "new project
  setup", "stamp a CLAUDE.md", "set up agent scaffolding".
---

# Project Bootstrap

## Purpose

Every repo should hand an agent the same things up front: what it is, how to run it, how to test it, and what not to break. This skill stamps that scaffolding from one source of truth - the starter kit - so cold sessions (and cheaper models) execute instead of rediscovering. The CLAUDE.md is the deliverable; it gets smoke-tested before it counts.

## The starter kit (single source of truth)

This skill needs a starter kit directory: a folder of template files you maintain. It does not ship one. Resolve the kit path in this order:

1. The `STARTER_KIT` environment variable, if set.
2. `~/Projects/shared/Development/templates/starter-kit/`, if it exists.
3. Otherwise stop and tell the user the skill has no kit to copy from. Do not write the scaffolding inline.

The layout below is what the skill expects the kit to contain. Copy files from the kit and fill the placeholders.

- `core/` - stamped into every project, any stack:
  - `CLAUDE.md.template`, `README.md.template` - filled with judgment from recon
  - `.editorconfig` - copied verbatim
  - `gitignore` (or `.gitignore` in older kit checkouts) - copied to `.gitignore` in the project. The kit stores it without the dot so it isn't a live ignore inside the kit's own repo.
  - `.claude/settings.json` - copied verbatim (committed canon: minimal safe permissions)
  - `.claude/settings.local.json.template` - copied to `settings.local.json`, adjusted to stack; only if absent
  - `.claude/launch.json.template` - filled with dev command + port
  - `scripts/worktree-port.cjs` - copied verbatim (stable per-worktree dev port)
- `layers/<stack>/` - opt-in, applied over the core; each has its own README with steps:
  - `frontend-vite` - React + Vite + TS + current Storybook + design-token enforcement (ready)
  - `js-ts`, `python`, `static-11ty` - planned; skip if the directory isn't there yet

## Inputs

Ask only for what can't be discovered: the project's name and one-line purpose if there's no README. Everything else comes from recon.

## Process

1. **Recon the repo** (skip whatever doesn't exist):
   - `package.json` / `pyproject.toml` / `composer.json` - scripts and deps (these also tell you the stack -> which layer, if any)
   - Server entry: grep for `PORT|listen`; check `.env.example` for required vars
   - Existing docs (README, AGENTS.md, docs/) - the CLAUDE.md points at them, never duplicates
   - `git log --oneline -15` - recent themes become "Common tasks" candidates
   - `git worktree list` - decides whether the worktrees section applies

2. **Pick a port** (web projects only): read the Active projects table in the projects map (see step 5) and pick one nothing else claims. If there is no map, check `.claude/launch.json` and the dev-server config of sibling projects, and avoid common defaults (3000, 5173, 6006).

3. **Stamp the core** from `starter-kit/core/`:
   - Copy verbatim: `.editorconfig`, `.claude/settings.json`, `scripts/worktree-port.cjs`.
   - `.gitignore`: the kit file is `gitignore` (fall back to `.gitignore` if the kit still has the dotted name). Copy it to `.gitignore` if the repo has none; if it already has one, ensure the kit's `.claude` commit-canon block is present.
   - **Write CLAUDE.md** by filling `CLAUDE.md.template`: every section gets exact commands and literal ports/paths, written for a weaker model - imperative, do-X-then-verify-Y, minimal cleverness required of the reader. Target 100-250 lines. No emojis. (Never overwrite an existing CLAUDE.md - diff instead.)
   - **Write `README.md`** from `README.md.template` only if the repo has none.
   - **Write `.claude/launch.json`** from `launch.json.template` with the chosen dev command and port.
   - **Write `.claude/settings.local.json`** from `settings.local.json.template`, adjusted to the stack (python3, composer, etc.) - only if it doesn't already exist. Keep it small; `/fewer-permission-prompts` grows it later from real usage.

4. **Apply a stack layer** (only if one matches the project): for a React + Vite frontend, follow `layers/frontend-vite/README.md` - scaffold the baseline with the official tools, then overlay the layer's files. Skip this step if the project's stack has no layer yet.

5. **Register it**: the projects map is `$PROJECTS_MAP` if set, else `~/Projects/CLAUDE.md`. If that file exists, append a row to its Active projects table (project path, stack, canonical ports). If it doesn't, skip this step and say so.

6. **Smoke-test the doc**: following ONLY the new CLAUDE.md, start the dev server, hit its verify step, run the test command, then stop anything started. If a step doesn't work as written, fix the doc - not the expectations.

7. **Commit** CLAUDE.md (plus the tracked `.claude/` canon and core files, if the repo tracks them) with a message saying what the manual covers. `settings.local.json` stays uncommitted.

## Rules

- The starter kit is the one source of truth - copy from it, never re-author scaffolding inline. If a template needs improving, fix it in the kit, not here.
- Never overwrite an existing CLAUDE.md unasked - present a diff instead.
- Point at existing docs; never paste their content into CLAUDE.md.
- The smoke test is the acceptance test. A CLAUDE.md that hasn't been executed cold doesn't ship.
- If ports or stack change later, update the root-map row too - one canonical port table.
