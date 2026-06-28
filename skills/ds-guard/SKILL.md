---
name: ds-guard
description: >
  Automatically run after any edit to a .css, .tsx, .ts, .jsx, or .js file that contains styling.
  Triggers on: new CSS rules, className changes, style props, token usages, or any visual/layout change.
  Checks the diff against the project's design system token inventory and living style guide (canon, if one exists).
  Flags hardcoded values, off-system tokens, Tailwind utility classes, and patterns not established in the living style guide.
  Run this before every commit that touches styles or components.
---

## When to invoke (auto-trigger)

Invoke this skill automatically whenever:
- Any `.css` file is edited
- A `.tsx` / `.jsx` file is edited and the diff contains `className`, `style=`, or CSS custom properties
- A new component is created
- A new CSS class is introduced

Do NOT wait for the user to ask. Run as part of the normal post-edit flow for any styling change.

A `PostToolUse` hook (`~/.claude/hooks/ds-guard-trigger.py`, wired in `~/.claude/settings.json`) now fires deterministically on every styling-file edit and injects a reminder, so the trigger no longer depends on this description matching. Effort gating: at `high`/`xhigh`/`max` run the full audit against the token inventory and showcase (Steps 1+); at lower effort a quick spot-check of the diff's hardcoded values is enough.

# DS Guard — Design System Enforcement

## Purpose

Audit a diff or set of files to ensure every styling decision goes through the project's design system token layer. Catch violations before they land.

## Step 1 — Discover the token inventory

Find the project's token source files:
- Look for `src/lib/theme/themes/*.css`, `tokens.css`, `design-tokens.*`, or similar
- Extract all defined `--*` custom property names
- Note the token namespaces in use (e.g. `--color-*`, `--space-*`, `--font-*`, `--radius-*`)

If no token files are found, ask the user where the design system is defined before proceeding.

## Step 2 — Discover the living style guide (canon, if one exists)

Look for a **living style guide** — a page that renders the real production components as the reference, so it can't drift from the app. Projects also call it a pattern library, component catalog, design-system page, showcase, or Storybook. Do NOT assume one exists. Common locations: `src/app/design-system/`, `src/pages/ds/`, `src/app/ds*/`, `/design-system*`, storybook `stories/` dirs.

**If a living style guide exists**, treat it as canon:
- Any component pattern, spacing, color usage, or variant shown there takes precedence over what the diff introduces.
- A diff that introduces a new pattern absent from it → flag it (add it to the living style guide first, or reuse an existing pattern).
- A diff that contradicts it (e.g. a button style differing from the canon button) → violation.

**If none exists**, skip the canon-relative checks (this step and the "Living-style-guide-local component skinning" check below) — the token-hygiene checks still apply. Don't invent one or demand one; you may note its absence once if the project looks like it would benefit, but never block a diff for lacking it.

## Step 3 — Read the diff

`git diff HEAD` or `git diff --staged` — look at every changed `.css`, `.tsx`, `.ts`, `.jsx`, `.js` line that contains styling.

## Step 3 — Check for violations

### Hardcoded values (always a violation)
- Hex colors: `#fff`, `#1a1a1a`, `#3b82f6`, etc.
- Named colors: `red`, `blue`, `white`, `black`, etc. in CSS properties
- Literal `rgb()` / `hsl()` / `oklch()` values that aren't inside a token definition file
- Hardcoded `px` spacing values for margin/padding/gap/width/height when a `--space-*` token exists for that role
- Hardcoded `font-family` strings when `--font-*` tokens are available
- Hardcoded `border-radius` values when `--radius-*` tokens are available

### Off-system tokens (check against discovered inventory)
- `var(--color-something)` where `--color-something` is NOT in the token inventory — likely a typo or stale name
- `var(--space-7)` where the token set only goes to `--space-6` — off the scale

### Tailwind utility classes (violation if project has migrated off Tailwind)
- `className` strings containing utility classes: `text-sm`, `bg-gray-100`, `p-4`, `flex`, `gap-2`, `rounded-md`, etc.
- `cn()` / `clsx()` calls mixing utility classes with BEM classes
- If the project is still on Tailwind, skip this check — confirm with user first

### Inline styles (flag, don't auto-fail)
- `style={{ color: '...' }}` or `style={{ padding: '...' }}` — flag for review; inline styles bypass the token layer but are sometimes necessary

### Living-style-guide-local component skinning (canon violation)

(Only applies if the project has a living style guide — see Step 2. Skip otherwise.) Step 2 treats it as canon — but that only holds if it RENDERS the real production components AND their styling lives in production (so the app inherits it). The inverse failure is the living style guide re-skinning a real component with guide-local classes: the guide looks right while the app's own component ships unstyled. This is a violation even when every value is on-token (so the checks above pass it cleanly).

When the diff touches the living style guide, flag:
- A component-specific styling prop (e.g. `overlayClassName`, `contentClassName`, `panelClassName`, `footerClassName`, or other `*ClassName` props the project's primitives expose) passed to an imported production component — those props exist only on the real components, so using them here means a component is being skinned guide-locally.
- A `className` on an imported production component pointing to a class defined only in the guide's own stylesheet.
- A section that hand-builds a look-alike (raw elements + bespoke classes) for something that already exists as a real component.

Fix: move the base styling into the PRODUCTION component (token-driven) so the app and the guide render the same thing; the guide then renders the real component unskinned. If the project has a deterministic canon check (a CI lint scanning the guide for these props), don't bypass it; if it has none, recommend adding one.

The app must never be the canon source for component styling, primitives, or layout — canon lives in the component and flows downstream to both the showcase and the app.

## Step 4 — Report

List violations ordered by severity:

**Error** (must fix): hardcoded color values, off-system `var()` references, Tailwind classes in a post-Tailwind codebase  
**Warning** (should fix): hardcoded spacing/radius/font values, inline styles  
**Info** (consider): magic numbers close to token values (e.g. `0.875rem` when `--font-size-sm` exists)

Format: `file:line — description — suggested token`

Example:
```
src/app/workshop.css:142 — hardcoded color `#3b82f6` — use var(--color-accent)
src/components/Foo.tsx:28 — Tailwind class `text-sm` — use var(--font-size-sm) or .text-technical
src/app/bar.css:9 — unknown token var(--color-muted) — did you mean var(--color-text-muted)?
```

## Step 5 — Fix

For each error-level violation, apply the fix directly. For warnings, propose the change and wait for confirmation. For info-level, report only.

## Rules

- Never introduce new token names — only use tokens already in the inventory.
- A value of `transparent`, `inherit`, `currentColor`, `0` does not need a token.
- `1px solid` border widths don't need a token unless the DS defines one.
- Exceptions require an explicit comment explaining why the hardcoded value is intentional.
- Do not change token definitions themselves — only usages.
