---
name: kiss
description: Apply KISS principles to a diff or set of changes. Trims the change to the minimum surface required to achieve the stated goal — removes refactors, cleanup, style fixes, and "while I'm here" additions that aren't strictly necessary. Use when a diff has crept beyond its original scope or when you want to commit the smallest possible change.
---

# KISS — Keep It Minimal

## Purpose

Given a diff or staged changes, strip everything down to the smallest set of modifications that achieves the stated goal. Nothing more.

## What to remove or simplify

- Refactors or restructuring not required by the fix
- Variable/function renames that aren't part of the stated goal
- Comment additions or edits beyond the changed lines
- Import reordering or cleanup
- Whitespace normalization unrelated to the change
- "While I'm here" fixes — flag these as separate tasks instead
- New abstractions or helpers not required by the change
- Extra test coverage beyond what directly tests the change
- Style or formatting changes outside the modified logic

## What to simplify (overengineering)

- Constants or data structures that wrap what could be inline literals
- Helper functions called only once — inline them
- Intermediate variables that just rename what they hold
- Multi-step logic that can be a single expression
- Generic/parameterized code where one concrete case exists
- Abstractions built for hypothetical future callers
- Overly defensive null checks or fallbacks for impossible states
- Tests with elaborate setup for simple assertions — simplify the fixture

## Process

1. **Identify the stated goal** — what is this change trying to do? One sentence.
2. **Read the full diff** — `git diff HEAD` or `git diff --staged`
3. **For each hunk, ask**: is this hunk strictly required to achieve the goal? If no, mark it for removal.
4. **Separate the extras** — list anything removed with a one-line reason; offer to file each as a standalone task.
5. **Apply the trimmed diff** — edit files to remove the extras, keeping only what's necessary.
6. **Verify** — run tests on the trimmed change to confirm it still achieves the goal.

## Rules

- Prefer editing one line over editing a function; prefer editing a function over editing a file.
- A change that touches N files should touch N-1 files if possible.
- If in doubt about whether something is necessary, remove it and note it.
- Never introduce new patterns or dependencies in a KISS pass.
- Flagged extras go into a list at the end — never silently dropped.
