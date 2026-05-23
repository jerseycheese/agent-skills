---
name: wrap-it-up
description: Close out the current chat with a tight summary and a sweep of related context files — adds, updates, or removes memory entries, JackOS project/task/log files, plan files, and nudges so nothing important dies in the transcript. Trigger on /wrap-it-up, "wrap it up", "wrap up this chat", "close out this conversation", "end of chat", "summarize and clean up", or any end-of-session housekeeping request. Pairs with /handoff (which preps a new chat) — wrap-it-up is the backward-looking bookend.
---

# wrap-it-up

## Purpose

End-of-chat closure ritual. Two jobs: (1) produce a short closing report so the conversation has a clean outcome, and (2) sweep the durable context files — memory, project status, tasks, nudges, plans — so anything worth keeping makes it out of the transcript before the chat ends.

## What to produce

A short closing report with three parts. Keep it tight — colleague-over-coffee tone, not a meeting recap.

- **Summary** — 3–6 bullets of what was actually accomplished. Outcomes, not narration.
- **Decisions** — anything we decided that future-me will need to know. One bullet each.
- **Loose ends** — anything left unfinished, with a one-line next step. If there are none, say so.

If the chat was mostly exploration with no concrete output, say that. Don't fabricate accomplishments.

## Context-file housekeeping

Walk these locations in order. For each, propose changes as **file → what changes → why**, batched into one list before writing.

### Auto-memory — `~/.claude/projects/-Users-jackhaas-JackOS/memory/`

- New durable fact about Jack, his preferences, project state, or external references → write a new memory file + add a line to `MEMORY.md`.
- Fact contradicted or proven stale during this chat → update or remove the existing memory file + prune the `MEMORY.md` line.
- Follow the memory-system rules in `~/.claude/CLAUDE.md`: frontmatter (`name`, `description`, `type`), semantic naming, **Why:** / **How to apply:** lines for `feedback` and `project` types.
- Do NOT save ephemeral conversation state, code patterns derivable from the repo, or anything already in CLAUDE.md.

### JackOS project files — `~/JackOS/projects/*.md`

- If the chat touched an active project (Narraitor, D&D Campaign Tools, Boot Hill GM Rebuild, Office Munchkin, MealPlanShop, Email Migration, JobSearch), update its status file with what changed.
- One canonical surface per fact — don't duplicate the same update into memory + project file. Pick the right home.

### Tasks — `~/JackOS/TASKS.md`

- New tasks emerged this chat → append to `TASKS.md`. Add `[due:YYYY-MM-DD]` if a date is known.
- Tasks completed this chat → check them off.

### Daily log — `~/JackOS/life-coach/daily-logs/YYYY-MM-DD.md`

- Append a one-liner only if something log-worthy happened (decision, action taken, win). Skip routine chat.

### Nudges — `~/JackOS/life-coach/nudges.md`

- If Claude assigned Jack an action this chat, add it as a nudge. This is non-optional per memory rule `feedback_assigned_actions_become_nudges.md`.

### Plan files — `~/.claude/plans/`

- If a plan file was created for this chat's work and the work is now done or abandoned, offer to delete it.
- Leave plan files alone if they're still load-bearing for future chats.

### CLAUDE.md — `~/.claude/CLAUDE.md` or `~/JackOS/CLAUDE.md`

- Only touch if a durable behavioral rule emerged that belongs at the constitution level. Rare. Prefer memory.

## Process

1. Skim the chat. Identify outcomes, decisions, loose ends.
2. Draft the closing report (summary / decisions / loose ends). Show it to Jack first.
3. Walk the housekeeping checklist. Batch every proposed file change as **file → what changes → why** before writing anything.
4. Confirm with Jack before deletes or destructive edits. Additive edits (new memory file, new TASKS.md line, daily-log append, new nudge) can proceed without confirmation.
5. Apply the agreed changes.
6. Print a final one-liner: `Wrapped. N memory edits, M task additions, K plan files closed.`

## Rules

- No emojis anywhere — output, files, or commits.
- Don't fabricate accomplishments. Empty chats get an honest "nothing concrete shipped" closing.
- Don't write memory for ephemeral state. See the "What NOT to save in memory" section in `~/.claude/CLAUDE.md`.
- Don't proactively create new docs. Update existing files.
- One canonical surface per fact.
- Keep it tight. The whole closure should fit on one screen.
