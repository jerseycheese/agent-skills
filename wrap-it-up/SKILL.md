---
name: wrap-it-up
description: Close out the current chat with a tight summary and a sweep of the current project's durable context files — memory entries, status and task docs, plan files, and any project-specific reminders — so nothing important dies in the transcript. Trigger on /wrap-it-up, "wrap it up", "wrap up this chat", "close out this conversation", "end of chat", "summarize and clean up", or any end-of-session housekeeping request. Pairs with /handoff (which preps a new chat) — wrap-it-up is the backward-looking bookend.
---

# wrap-it-up

## Purpose

End-of-chat closure ritual. Two jobs: (1) produce a short closing report so the conversation has a clean outcome, and (2) sweep the current project's durable context files — memory, status docs, tasks, plans, and any project-specific reminders — so anything worth keeping makes it out of the transcript, and clear the chat's runtime leftovers (stop dev servers it started, delete its finished plan files) before the chat ends.

This skill is project-aware. It adapts to whatever repo you run it from: it discovers the context files the current project actually uses instead of assuming a fixed layout, and it honors any end-of-session conventions documented in that project's `CLAUDE.md` / `AGENTS.md`. Run it from a code repo and it sweeps that repo's docs and tasks; run it from a personal life-OS or notes repo and it picks up that repo's own conventions.

## What to produce

A short closing report with three parts. Keep it tight — colleague-over-coffee tone, not a meeting recap.

- **Summary** — 3–6 bullets of what was actually accomplished. Outcomes, not narration.
- **Decisions** — anything we decided that future-me will need to know. One bullet each.
- **Loose ends** — anything left unfinished, with a one-line next step. If there are none, say so.

If the chat was mostly exploration with no concrete output, say that. Don't fabricate accomplishments.

## Context-file housekeeping

First, orient to the current project so the rest of the sweep targets the right files:

- Determine the project root (git root, else cwd).
- Read the project's `CLAUDE.md` / `AGENTS.md` for any project-specific end-of-session housekeeping it documents (status files, logs, reminders, task conventions, custom commands). Those instructions take precedence and run alongside the generic sweep below — this is what makes the skill adapt per project. Don't hardcode another project's layout; let the current project's constitution drive its specifics.

Then walk these generic locations. For each, propose changes as **file → what changes → why**, batched into one list before writing.

### Auto-memory

If the project uses Claude Code auto-memory (a `memory/` directory with a `MEMORY.md` index, typically under `~/.claude/projects/<project-slug>/`):

- New durable fact about the user, their preferences, project state, or external references → write a new memory file + add a line to `MEMORY.md`.
- Fact contradicted or proven stale during this chat → update or remove the existing memory file + prune the `MEMORY.md` line.
- Follow the memory-system rules in the user's `~/.claude/CLAUDE.md`: frontmatter (`name`, `description`, `type`), semantic naming, and **Why:** / **How to apply:** lines for `feedback` and `project` types.
- Do NOT save ephemeral conversation state, code patterns derivable from the repo, or anything already in `CLAUDE.md`.

### Project status / docs

- If the chat changed the state of the project (shipped a feature, made an architectural decision, hit a blocker), update the project's own status doc or the relevant existing documentation.
- One canonical surface per fact — don't duplicate the same update into memory and a status doc. Pick the right home.
- Don't proactively create new docs. Update existing files.

### Task tracking

- New tasks emerged this chat → add them wherever the project tracks tasks (a `TASKS.md` / `TODO.md`, an issue tracker, etc.). Add a due date if one is known and the format supports it.
- Tasks completed this chat → check them off or close them.

### Plan files — `~/.claude/plans/`

- Delete the plan file(s) created for this chat's work once the work is done or abandoned — automatically, no confirmation.
- Leave a plan file alone only if it's explicitly still load-bearing for a separate, in-flight effort.

### Dev servers & background processes

- Stop any dev servers or other long-running background processes started during this chat — automatically, no confirmation. Stop the background tasks you launched (or the processes on their ports), then verify the ports are free.
- Leave servers you didn't start in this chat alone (something the user already had running).

### Project-specific conventions

- Apply anything the project's `CLAUDE.md` / `AGENTS.md` flagged in the orientation step — e.g. daily logs, reminder or nudge files, per-domain status files, scoring, custom commands. These vary by project; let the project's own constitution drive them rather than assuming they exist.

### CLAUDE.md

- Only touch the project or user `CLAUDE.md` if a durable behavioral rule emerged that belongs at the constitution level. Rare. Prefer memory.

## Process

1. Skim the chat. Identify outcomes, decisions, loose ends.
2. Orient to the project: find the root, read its `CLAUDE.md` / `AGENTS.md` for end-of-session conventions.
3. Draft the closing report (summary / decisions / loose ends). Show it to the user first.
4. Walk the housekeeping checklist. Batch every proposed file change as **file → what changes → why** before writing anything.
5. Confirm before deletes or destructive edits — EXCEPT the two always-on cleanups, which happen automatically: stopping dev servers started this chat, and deleting this chat's plan files. Additive edits (new memory file, new task line, log append, new reminder) also proceed without confirmation.
6. Apply the agreed changes.
7. Print a final one-liner: `Wrapped. N memory edits, M task additions, K plan files deleted, S servers stopped.`

## Rules

- No emojis anywhere — output, files, or commits.
- Don't fabricate accomplishments. Empty chats get an honest "nothing concrete shipped" closing.
- Don't write memory for ephemeral state — see the "What NOT to save in memory" guidance in the user's `~/.claude/CLAUDE.md`.
- Don't proactively create new docs. Update existing files.
- One canonical surface per fact.
- Keep it tight. The whole closure should fit on one screen.
