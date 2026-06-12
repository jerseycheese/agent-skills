---
name: project-bootstrap
description: Bootstrap a project under ~/Projects with the standard agent scaffolding - a CLAUDE.md from the house template, a starter .claude/settings.local.json, a .claude/launch.json with a free port, and a row in the ~/Projects/CLAUDE.md root map. Use when creating a new project or repo, or when an existing repo is missing its CLAUDE.md. Trigger on "bootstrap this project", "new project setup", "stamp a CLAUDE.md", "set up agent scaffolding", "give this repo a CLAUDE.md".
---

# Project Bootstrap

## Purpose

Every repo should hand an agent the same things up front: what it is, how to run it, how to test it, and what not to break. This skill stamps that scaffolding so cold sessions (and cheaper models) execute instead of rediscovering. The doc is the deliverable - it gets smoke-tested before it counts.

## Inputs

Ask only for what can't be discovered: the project's name and one-line purpose if there's no README. Everything else comes from recon.

## Process

1. **Recon the repo** (skip whatever doesn't exist):
   - `package.json` / `pyproject.toml` / `composer.json` - scripts and deps
   - Server entry: grep for `PORT|listen`; check `.env.example` for required vars
   - Existing docs (README, AGENTS.md, docs/) - the CLAUDE.md points at them, never duplicates them
   - `git log --oneline -15` - recent themes become "Common tasks" candidates
   - `git worktree list` - decides whether the worktrees section applies

2. **Pick a port** (web projects only): read the Active projects table in `/Users/jackhaas/Projects/CLAUDE.md` and pick one nothing else claims. Already taken: 3000 (narraitor, rcv-simulator-va main), 3101, 4173, 4174, 5173, 6006.

3. **Write CLAUDE.md** from the template below. Every section gets exact commands and literal ports/paths, written for a weaker model: imperative, do-X-then-verify-Y, minimal cleverness required of the reader. Target 100-250 lines. No emojis.

4. **Write `.claude/launch.json`** from the starter below with the chosen dev command and port.

5. **Write `.claude/settings.local.json`** from the starter below - only if the file doesn't exist; never overwrite one that does.

6. **Register it**: append a row to the Active projects table in `/Users/jackhaas/Projects/CLAUDE.md` (project path, stack, canonical ports).

7. **Smoke-test the doc**: following ONLY the new CLAUDE.md, start the dev server, hit its verify step, run the test command, then stop anything started. If a step doesn't work as written, fix the doc - not the expectations.

8. **Commit** CLAUDE.md (plus launch.json if the repo tracks `.claude/`) with a message saying what the manual covers. `settings.local.json` stays uncommitted.

## The CLAUDE.md template

```markdown
# CLAUDE.md — <project name>

<2-4 lines: what the app does, stack, who uses it. Context first.>

## Run it
<Exact commands in order. Ports as literals. Env vars and where they live.
End with a verify step: "curl -s localhost:<port> returns HTML".
Rule: check for an already-running server before starting one.>

## Test and lint
<Exact commands. What must pass before any commit. What "passing" looks like.>

## Layout
<Annotated tree - only the 6-12 directories that matter, one line each.>

## Hard rules
<Project-specific never-do / always-do, CRITICAL-marked. Max ~10 bullets.>

## Worktrees and ports        (only if the repo uses worktrees)
<Where worktrees live, how each gets its port, verify against THAT worktree's server.>

## Common tasks
<3-6 recipes: numbered steps with exact commands, each ending in a verify step.>

## Known failure modes
<Symptom -> cause -> fix. Exact error text where known.>

## Pointers
<Paths to deeper docs, local .claude/skills, shared tools. Paths only - no content duplication.>
```

## launch.json starter

```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "dev",
      "runtimeExecutable": "sh",
      "runtimeArgs": ["-c", "<dev command>"],
      "port": <port>,
      "autoPort": true
    }
  ]
}
```

## settings.local.json starter

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run dev:*)",
      "Bash(npm test:*)",
      "Bash(npm run lint:*)",
      "Bash(lsof:*)",
      "Bash(curl -s localhost:*)"
    ]
  }
}
```

Adjust to the stack (python3, composer, etc.) and keep it small - `/fewer-permission-prompts` grows it later from real usage.

## Rules

- Never overwrite an existing CLAUDE.md unasked - present a diff instead.
- Point at existing docs; never paste their content into CLAUDE.md.
- The smoke test is the acceptance test. A CLAUDE.md that hasn't been executed cold doesn't ship.
- If ports or stack change later, update the root-map row too - one canonical port table.
