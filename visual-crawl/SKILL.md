---
name: visual-crawl
description: >
  Crawls the running app at randomized breakpoints, screenshots visual issues, checks design token
  consistency, and tests interactive elements. Each run covers different ground by design.
  Trigger on: "visual QA", "audit the app visually", "screenshot all the pages",
  "check for visual regressions", "crawl the site for issues", "visual design system audit",
  "responsive check", "screenshot the routes", "look for visual bugs", "check the UI".
---

# Visual Crawl

Randomized visual QA using `bdg` (browser-debugger-cli). Opens the project, crawls pages at varied breakpoints, screenshots issues, and produces a findings report. No two runs cover the same ground.

## Prerequisites

- `bdg` installed globally (`npm install -g browser-debugger-cli@alpha`)
- Project dev server running (know the URL and port)
- AeroSpace users: after `--no-headless`, run `aerospace layout floating` to free viewport

## Invocation

User says `/visual-crawl` or asks for a visual QA pass. Before starting, confirm:
1. **Project URL** (e.g., `http://localhost:4173`)
2. **Route list** — discover from router config or ask the user

For keyboard-navigated apps (sections accessed via key bindings rather than URL routing), ask the user for the key-to-section mapping and use `bdg dom pressKey` to navigate.

## The Crawl

### Phase 0: Setup

```bash
# Check for existing session first
bdg status 2>&1 || true

# Start bdg session (headless by default)
bdg <project-url>

# Create screenshot output directory
OUTDIR="/tmp/visual-crawl-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTDIR"
```

Store `$OUTDIR` path — all screenshots go here.

### Phase 1: Randomize the Run

Each invocation MUST vary. Build the run plan by randomizing THREE axes:

**A) Page order** — shuffle all routes, then pick a random subset (minimum 4 pages, maximum all):
```bash
# macOS doesn't have shuf — use perl instead
# Replace the route list with your project's actual routes
echo "home dashboard settings profile reports help" \
  | tr ' ' '\n' | perl -MList::Util=shuffle -e 'print shuffle(<>)' | head -5
```

**B) Breakpoints per page** — for each page, pick 2-3 breakpoints from this pool (never the same set twice):

| Name | Width | Height | Mobile | Notes |
|------|-------|--------|--------|-------|
| iPhone SE | 375 | 667 | true | Smallest common phone |
| iPhone 14 | 390 | 844 | true | Standard modern phone |
| Pixel 7 | 412 | 915 | true | Android standard |
| iPad Mini | 768 | 1024 | false | Small tablet |
| iPad Pro | 1024 | 1366 | false | Large tablet |
| Laptop | 1280 | 800 | false | Common laptop |
| Desktop | 1440 | 900 | false | Standard desktop |
| Ultrawide | 1920 | 1080 | false | Large monitor |
| Wildcard | RANDOM 500-1600 | RANDOM 600-1000 | false | Catches edge cases |

Always include at least one mobile, one tablet, and one desktop. Always include one Wildcard with truly random dimensions.

**C) Audit focus** — pick 2-3 focus areas per page from this rotating list:
- **Layout integrity** — overflow, clipping, overlap, whitespace collapse
- **Typography** — font-family matches tokens, sizes consistent, no orphan lines
- **Color tokens** — hardcoded colors vs CSS variables, contrast issues
- **Empty states** — what happens with no data / null values
- **Interactive elements** — buttons clickable, hover states, form inputs work
- **Spacing consistency** — padding/margin matches design token scale
- **Responsive behavior** — does layout actually adapt or just shrink
- **Accessibility** — a11y tree makes sense, roles correct, labels present
- **Component consistency** — same component looks same across pages
- **Data display** — numbers formatted, dates localized, no "undefined" or "NaN"
- **Design system alignment** — do visible components map to existing Storybook stories or showcase specimens? Flag orphan patterns (custom one-off UI that should use a canonical component or be promoted to one)

### Phase 2: Execute the Crawl

For each page in the shuffled order:

#### 2a. Navigate to the page
```bash
# For keyboard-navigated apps
bdg dom pressKey "body" "3"  # e.g., key 3 navigates to a specific section

# For URL-routed apps
bdg cdp Page.navigate --params '{"url":"http://localhost:PORT/route"}'
```

Wait for page to settle (check network idle or use a short delay).

#### 2b. For each breakpoint assigned to this page:

**Resize viewport:**
```bash
bdg cdp Emulation.setDeviceMetricsOverride --params '{
  "width": 375, "height": 667, "deviceScaleFactor": 2, "mobile": true
}'
# IMPORTANT: sleep 1 after resize — content needs time to reflow
sleep 1
```

**Take screenshots — mix full-page and component-level:**

For each page+breakpoint combo, randomly decide the screenshot strategy (vary across the run):

```bash
# ALWAYS take the full-page screenshot first
bdg dom screenshot $OUTDIR/PAGE-WIDTHxHEIGHT-full.png
```

Then, for ~50% of page+breakpoint combos, ALSO take 2-4 component-level screenshots. Query for visible components, pick randomly:

```bash
# Discover components on the page — adapt selectors per project
cat > /tmp/find-components.js << 'JSEOF'
Array.from(document.querySelectorAll(
  "section, .card, .collapsible, [class*='panel'], [class*='widget'], " +
  "nav, header, footer, table, form, [role='region'], [role='navigation'], " +
  "[class*='chart'], [class*='stat'], [class*='badge'], [class*='metric']"
)).filter(function(el) {
  var r = el.getBoundingClientRect();
  return r.height > 20 && r.width > 50 && r.top < window.innerHeight * 2;
}).map(function(el, i) {
  var cls = (el.className || "").toString().split(" ").filter(function(c){return c;}).slice(0,3).join(".");
  var r = el.getBoundingClientRect();
  return i + ": " + el.tagName + "." + cls + " (" + Math.round(r.width) + "x" + Math.round(r.height) + ")";
}).slice(0, 20)
JSEOF
bdg dom eval "$(cat /tmp/find-components.js)"

# Pick 2-4 random indices from the results, then screenshot each
# Use bdg dom screenshot with a CSS selector to capture just that component:
bdg dom screenshot --selector ".collapsible:nth-of-type(2)" $OUTDIR/PAGE-WIDTHxHEIGHT-component-NAME.png
# Or by query index:
bdg dom query "section, .card, .collapsible"
bdg dom screenshot --index 3 $OUTDIR/PAGE-WIDTHxHEIGHT-component-3.png
```

**Component screenshot priorities** (pick from these when choosing which to capture):
- **Smallest component on page** — most likely to break at narrow viewports
- **Component with most text content** — typography/overflow issues
- **Interactive component** (button group, form, nav) — functional checks
- **Data display component** (table, chart, stat card) — formatting issues
- **Randomly selected component** — catches unexpected issues

**Review ALL screenshots** (full-page AND component) with the `Read` tool to visually inspect them. Component screenshots reveal issues invisible in full-page shots: truncated text, misaligned icons, broken borders, padding collapse inside cards.

**Run audit checks based on assigned focus areas.**

**CRITICAL: Shell quoting with `bdg dom eval`** — zsh mangles complex JS expressions containing single quotes, `getComputedStyle()`, `!`, and nested function calls. Write JS to a temp file and use `$(cat /tmp/file.js)` to avoid quoting hell:

```bash
cat > /tmp/check.js << 'JSEOF'
Array.from(document.querySelectorAll("button")).filter(function(el) {
  return !el.textContent.trim();
}).map(function(el) { return el.className; }).slice(0, 10)
JSEOF
bdg dom eval "$(cat /tmp/check.js)"
```

Simple expressions with only double quotes work inline: `bdg dom eval "document.title"`

##### Layout integrity
```bash
# Horizontal overflow (inline — simple enough)
bdg dom eval "document.documentElement.scrollWidth > document.documentElement.clientWidth"

# Elements beyond viewport (use temp file)
cat > /tmp/overflow.js << 'JSEOF'
Array.from(document.querySelectorAll("*")).filter(function(el) {
  var r = el.getBoundingClientRect();
  return r.right > window.innerWidth + 5 || r.left < -5;
}).map(function(el) {
  return el.tagName + "." + (el.className || "").toString().split(" ").slice(0,2).join(".");
}).slice(0, 15)
JSEOF
bdg dom eval "$(cat /tmp/overflow.js)"
```

##### Typography check
```bash
# Find elements not using design token fonts — adapt the font name list to your project
cat > /tmp/font-check.js << 'JSEOF'
var PROJECT_FONTS = ["Inter", "Roboto"]; // replace with your project's font families
Array.from(document.querySelectorAll("h1,h2,h3,h4,p,span,div")).filter(function(el) {
  var f = getComputedStyle(el).fontFamily;
  return el.textContent.trim().length > 0
    && !PROJECT_FONTS.some(function(font) { return f.includes(font); });
}).map(function(el) {
  return el.tagName + ": " + getComputedStyle(el).fontFamily.substring(0, 50);
}).slice(0, 10)
JSEOF
bdg dom eval "$(cat /tmp/font-check.js)"
```

##### Color token check
```bash
# Find inline color/background styles (potential hardcoded values)
cat > /tmp/color-check.js << 'JSEOF'
Array.from(document.querySelectorAll("[style]")).filter(function(el) {
  return /color|background/.test(el.getAttribute("style"));
}).map(function(el) {
  var cls = (el.className || "").toString().split(" ").slice(0,2).join(".");
  return el.tagName + "." + cls + " -> " + el.getAttribute("style").substring(0, 80);
}).slice(0, 20)
JSEOF
bdg dom eval "$(cat /tmp/color-check.js)"
```

##### Empty states
```bash
# Check for "undefined", "NaN", "null" rendered as text (inline — simple)
bdg dom eval "document.body.innerText.match(/(undefined|NaN|\\[object Object\\])/g)"

# Visually empty containers
cat > /tmp/empty-check.js << 'JSEOF'
Array.from(document.querySelectorAll("div, section, article")).filter(function(el) {
  var r = el.getBoundingClientRect();
  return r.height < 10 && r.width > 50 && el.children.length > 0;
}).map(function(el) {
  return el.tagName + "." + (el.className || "").toString().split(" ").slice(0,2).join(".");
}).slice(0, 10)
JSEOF
bdg dom eval "$(cat /tmp/empty-check.js)"
```

##### Interactive elements
```bash
# Find all clickable elements
bdg dom query "button, a[href], [role=button]"

# Click by CSS selector (NOT --index flag — use selector or positional index)
bdg dom click ".some-button-class"
# Or by index from previous query result:
bdg dom click 5

# Screenshot after interaction
bdg dom screenshot $OUTDIR/PAGE-interaction-WIDTHxHEIGHT.png
```

##### Accessibility
```bash
# Check for icon buttons missing aria-label
# NOTE: title attribute is NOT a reliable accessible name — prefer aria-label
cat > /tmp/a11y-check.js << 'JSEOF'
Array.from(document.querySelectorAll("button, a, input, select, textarea, [role]")).filter(function(el) {
  return !el.getAttribute("aria-label") && !el.textContent.trim() && !el.getAttribute("aria-labelledby");
}).map(function(el) {
  var cls = (el.className || "").toString().split(" ").slice(0,2).join(".");
  var hasTitle = el.getAttribute("title") ? " (has title only)" : " (NO accessible name)";
  return el.tagName + "." + cls + hasTitle;
}).slice(0, 15)
JSEOF
bdg dom eval "$(cat /tmp/a11y-check.js)"
```

##### Spacing consistency
```bash
# Adapt the selector list to your project's layout components
cat > /tmp/spacing-check.js << 'JSEOF'
Array.from(document.querySelectorAll("section, article, [class*='card'], [class*='panel']")).slice(0, 12).map(function(el) {
  var s = getComputedStyle(el);
  var cls = (el.className || "").toString().split(" ").filter(function(c){return c;}).slice(0,2).join(".");
  return cls + ": p=" + s.padding + " m=" + s.margin + " gap=" + s.gap;
})
JSEOF
bdg dom eval "$(cat /tmp/spacing-check.js)"
```

##### Cross-page component consistency
```bash
# Compare computed styles of shared components across pages
# Navigate to page A, capture styles, navigate to page B, compare
# Adapt the selector to a component that appears on multiple pages in your project
cat > /tmp/comp-check.js << 'JSEOF'
Array.from(document.querySelectorAll("[class*='card-header'], [class*='panel-header'], header")).slice(0, 3).map(function(el) {
  var s = getComputedStyle(el);
  return { text: el.textContent.trim().substring(0, 30), font: s.fontFamily.substring(0, 30), size: s.fontSize, color: s.color, bg: s.backgroundColor, padding: s.padding };
})
JSEOF
bdg dom eval "$(cat /tmp/comp-check.js)"
```

#### 2c. Reset viewport before next page
```bash
bdg cdp Emulation.clearDeviceMetricsOverride
```

### Phase 2.5: Design System Alignment Check

After crawling each page's breakpoints, inventory the visible UI patterns and cross-reference against the project's component library. This catches orphan patterns — bespoke UI that should either use an existing canonical component or be promoted into one.

**How to inventory:** Query the DOM for interactive/structural elements and classify them:

```bash
cat > /tmp/ds-alignment.js << 'JSEOF'
var patterns = [];
// Buttons
document.querySelectorAll("button, [role=button], a.button").forEach(function(el) {
  var cls = (el.className || "").toString();
  patterns.push("BUTTON: " + cls.substring(0, 80) + " | text: " + el.textContent.trim().substring(0, 30));
});
// Cards/containers
document.querySelectorAll("[class*=card], [class*=Card]").forEach(function(el) {
  patterns.push("CARD: " + (el.className || "").toString().substring(0, 80));
});
// Empty states
document.querySelectorAll("[class*=empty], [class*=Empty], [class*=not-found]").forEach(function(el) {
  patterns.push("EMPTY: " + (el.className || "").toString().substring(0, 80));
});
// Forms
document.querySelectorAll("form, [class*=form], [class*=Form]").forEach(function(el) {
  patterns.push("FORM: " + (el.className || "").toString().substring(0, 80));
});
// Badges/tags
document.querySelectorAll("[class*=badge], [class*=Badge], [class*=tag]").forEach(function(el) {
  patterns.push("BADGE: " + (el.className || "").toString().substring(0, 80));
});
// Tables
document.querySelectorAll("table, [class*=table], [class*=Table]").forEach(function(el) {
  patterns.push("TABLE: " + (el.className || "").toString().substring(0, 80));
});
// Navigation
document.querySelectorAll("nav, [class*=nav], [class*=Nav], [role=navigation]").forEach(function(el) {
  patterns.push("NAV: " + (el.className || "").toString().substring(0, 80));
});
patterns.slice(0, 30)
JSEOF
bdg dom eval "$(cat /tmp/ds-alignment.js)"
```

**Cross-reference against canon sources:**
- `src/components/ui/` — shadcn/Radix primitives (Button, Badge, Card, Dialog, Input, etc.)
- `src/components/shared/` — composite components (EmptyState, NotFoundState, PageLayout, TabNavigation, ActionButtonGroup, Hero, wizard system, etc.)
- Storybook stories
- Dev showcase pages (`/dev/design-system*`)

**Classify each element into three buckets:**
- **Should use existing** — bespoke UI where a canon component already exists (e.g., inline empty state div instead of `EmptyState` component, unstyled `<button>` instead of `Button`)
- **New pattern to canonize** — useful pattern not yet in the component library; recommend adding a Storybook story / showcase entry
- **Aligned** — correctly uses the canonical version (positive confirmation)

### Phase 3: Cross-Page Checks

After crawling individual pages, do a few cross-page consistency checks:

1. **Pick 2 pages at random** that both use the same component type (e.g., cards, badges, task items)
2. **Screenshot the same component** on both pages at the same breakpoint
3. **Compare visually** — flag differences in padding, font, color, border-radius

### Phase 4: Dark Mode Spot-Check (if applicable)

First, check if the app actually responds to `prefers-color-scheme`. If it's a dark-only or light-only theme, skip this phase.

```bash
# Test: does toggling scheme change the background color?
bdg dom eval "getComputedStyle(document.body).backgroundColor"
bdg cdp Emulation.setEmulatedMedia --params '{"features":[{"name":"prefers-color-scheme","value":"dark"}]}'
sleep 1
bdg dom eval "getComputedStyle(document.body).backgroundColor"
# If same color both times → app doesn't respond to color scheme → skip
```

If it does respond, pick ONE random page and breakpoint:
```bash
bdg dom screenshot $OUTDIR/PAGE-dark-WIDTHxHEIGHT.png
bdg cdp Emulation.setEmulatedMedia --params '{"features":[{"name":"prefers-color-scheme","value":"light"}]}'
```

### Phase 5: Teardown

```bash
bdg stop
```

## Findings Report

After the crawl, produce a structured findings report. Group by severity:

### Report Format

```markdown
# Browser QA Report — [Project] — [Date]

**Run ID:** [timestamp]
**Pages crawled:** [list]
**Breakpoints tested:** [list per page]
**Focus areas:** [list per page]

## Critical (broken functionality / data errors)
- [page] @ [breakpoint]: [description] — screenshot: [filename]

## Major (layout breaks / design system violations)
- [page] @ [breakpoint]: [description] — screenshot: [filename]

## Minor (cosmetic / polish)
- [page] @ [breakpoint]: [description] — screenshot: [filename]

## Component-Level Findings
- [page] @ [breakpoint] > [component]: [description] — screenshot: [filename]

## Design System Alignment
- [page] > [component]: Should use existing `ComponentName` from `src/components/ui/` — currently bespoke
- [page] > [pattern]: New pattern, recommend adding to Storybook as `StoryName`
- [page] > [component]: Aligned with `ComponentName`

## Observations (not bugs, just notes)
- [page]: [observation]

## Screenshots
Full-page: [list with context]
Component: [list with component name + context]
```

**Severity guide:**
- **Critical**: Functionality broken, data errors (NaN/undefined displayed), interactive elements non-functional
- **Major**: Layout breaks at specific breakpoints, design token violations (hardcoded colors/fonts), empty containers where content expected, accessibility failures
- **Minor**: Spacing inconsistencies, minor alignment issues, cosmetic polish items
- **Observation**: Not a bug — patterns worth noting, areas that could use attention

## Randomization Contract

Every invocation MUST differ from the last. Specifically:
- Page visit order is shuffled
- Breakpoint assignments are randomized (with the mobile/tablet/desktop/wildcard minimums)
- Audit focus areas rotate so different things are checked each time
- At least one interaction test uses a randomly selected element
- The Wildcard breakpoint uses truly random dimensions each time

This ensures cumulative coverage — run it 5 times and you've thoroughly audited the whole app across many viewport combinations.

## Gotchas Learned From Testing

- **Shell quoting is the #1 friction point.** Any `bdg dom eval` with `getComputedStyle()`, `!`, or single quotes WILL break in zsh. Always use the temp file pattern (see audit checks section). Simple double-quote-only expressions work inline.
- **macOS has no `shuf`** — use `perl -MList::Util=shuffle` for randomization.
- **`bdg dom click` syntax**: use `bdg dom click ".selector"` or `bdg dom click 5` (positional index from previous query). NOT `--index N`.
- **Sleep after viewport resize** — `sleep 1` is needed after `setDeviceMetricsOverride` for content to reflow before screenshotting.
- **Screenshots are viewport-only when page exceeds viewport height** — this is normal bdg behavior, not a bug. For full-page, use `bdg dom scroll --bottom` and take multiple screenshots.
- **Component screenshots via `--selector`** — `bdg dom screenshot --selector ".card"` captures just that element's bounding box. If the selector matches multiple elements, it captures the first. Use `--index N` after a `bdg dom query` to target a specific match.
- **Check if dark mode applies before testing it** — compare `document.body` background color before and after toggling `prefers-color-scheme`. Skip if identical.
- **`title` vs `aria-label` on icon buttons** — both technically provide accessible names, but `aria-label` is reliably read by all screen readers while `title` is not. Flag `title`-only buttons as a finding.

## Tips

- Run this after any major UI change or before a release
- Screenshots accumulate in `/tmp/visual-crawl-*` — clean up periodically
- If bdg session is already running, use `bdg status` to check before starting a new one
- For sidebar-based apps: test both expanded and collapsed sidebar states at narrow widths
- Some pages may load data async — wait for content before screenshotting
- Read screenshots with the `Read` tool to visually inspect them — don't just trust the programmatic checks
- For cross-page consistency: use `getComputedStyle()` comparisons (via temp file) — very effective for catching drift
