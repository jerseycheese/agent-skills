---
name: analyze-issue
description: Analyzes a single GitHub issue and produces a detailed technical specification ready for implementation. Fetches the issue, discovers existing patterns in the codebase, defines scope boundaries, and produces an implementation plan with MVP tests. Use before starting work on an issue to understand it fully. Trigger on "analyze issue #X", "spec out #123", "what does issue #X involve", "break down this issue", "create a tech spec for #X", "plan issue #N".
---

# Issue Analysis

## 1. Get the issue number

The user will provide an issue number. If they described an issue by name instead, find it:

```bash
gh issue list --search "[keywords]" --json number,title | head -5
```

## 2. Fetch full issue context

```bash
gh issue view [NUMBER] --json number,title,body,labels,comments,createdAt,milestone,assignees
```

Read every comment — they often contain updated requirements, implementation constraints, or scope decisions that aren't in the original body.

## 3. Discover existing patterns

Before planning anything, find what already exists in the codebase. Don't assume new code is needed.

```bash
# Find related components by keyword
grep -r "[relevant term]" src/ --include="*.ts" --include="*.tsx" -l | head -10

# Check for similar features
find src/ -name "*.ts" -o -name "*.tsx" | xargs grep -l "[related concept]" | head -5
```

Look for:
- Existing components that could be extended
- Utilities that could be reused
- Types or interfaces to build on
- Patterns established by similar features

## 4. Analyze requirements

From the issue body and comments, extract:
- The core problem being solved
- Explicit acceptance criteria (look for checklists or "should" statements)
- What the user asked for vs what they actually need (they may differ)
- Any constraints mentioned (performance, backwards compatibility, etc.)
- What's explicitly out of scope

If acceptance criteria are vague, infer concrete ones from the description.

## 5. Produce the technical specification

```
# Technical Spec: Issue #[NUMBER] — [title]

## Summary
[2-3 sentences: what problem this solves and why it matters]

Labels: [labels]
Milestone: [milestone or "none"]
Priority: [High/Medium/Low based on issue content]

## Scope

In scope:
- [specific item]
- [specific item]

Out of scope:
- [explicitly excluded item]
- [adjacent work that might seem related but isn't]

## Technical approach
[Concrete approach that leans on existing patterns. Reference specific files or components
found during discovery. Explain key decisions — why this approach over alternatives.]

## Existing code to leverage
- [file/component]: [how it applies]
- [utility]: [what it provides]
- [type/interface]: [what to extend]

## Implementation plan
1. [Step — specific enough to act on]
2. [Step]
3. [Step]
4. [Step, if needed]

## MVP test plan

Write 3-5 tests that map directly to acceptance criteria. No "renders without crashing."

1. [What you're testing] — validates [acceptance criterion]
2. [What you're testing] — validates [acceptance criterion]
3. [What you're testing] — validates [acceptance criterion]

Not testing (save for later or explicitly out of scope):
- [edge case not in acceptance criteria]
- [exhaustive input validation]

## Files to modify
- [path]: [changes]

## Files to create
- [path]: [purpose]

## Success criteria
- [ ] [criterion pulled directly from issue]
- [ ] [criterion]
- [ ] Tests cover acceptance criteria without rigging
- [ ] No duplicate functionality introduced

## Risks
- [Risk]: [Mitigation]

## Estimated effort
[Small / Medium / Large — with a one-sentence rationale]
```

## 6. Flag anything unclear

If the issue has ambiguous requirements, call them out explicitly rather than assuming. Ask the user to clarify before they start implementing — it's cheaper to resolve ambiguity now than mid-implementation.

## 7. Handing off to implementation

Once the spec is confirmed and ambiguity is resolved, suggest driving the build with `/goal` instead of manual turn-by-turn iteration — the success criteria above become the completion condition, e.g. `/goal "issue #N: all success-criteria checkboxes met, tests green, PR open"`. A separate evaluator decides when it's actually done.
