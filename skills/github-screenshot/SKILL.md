---
name: github-screenshot
description: >
  Generates GitHub-ready image markdown for screenshots using raw.githubusercontent.com URLs built from the
  git remote, branch, and file path. Use whenever a PR, issue, or doc needs an image. Trigger on:
  "add a screenshot to this PR", "embed image in issue", "attach screenshot", "add screenshot to
  docs".
---

# GitHub Screenshot Helper

## When to Use This Skill

Use this skill when:
- Adding screenshots to PR descriptions
- Including images in GitHub issues
- Documenting features with screenshots
- Creating visual documentation in markdown

## Directory convention

When the image is being committed purely so it can render in an issue/PR body (not an existing app asset the user is pointing you at), commit it under a top-level `github-screenshots/<topic-or-issue>/` directory — e.g. `github-screenshots/hover-text-invisible/before-hover.png`. The name says what these files are for: throwaway evidence for a GitHub body, not app screenshots or fixtures, so they're easy to find and prune later without touching anything else in the repo. Don't reuse a generic `screenshots/` dir for this — that name doesn't self-document, and it collides with whatever ad-hoc convention a given repo might already have for actual app screenshots.

If the target repo already has an established convention for this (check with the user or look for precedent — e.g. `git log --diff-filter=A --name-only --all | grep -iE 'screenshot'`), follow that instead of introducing a second one.

## What This Skill Does

Builds the markdown for an image so it renders in a GitHub body:
- A `raw.githubusercontent.com` URL from the repo's remote, branch, and file path
- Alt text and an optional italic caption
- A fallback to a relative path when there is no GitHub remote

No external script is needed; the steps below use plain `git`.

## Usage Flow

### Step 1: Gather Information

Ask the user for:
1. **Image path** (required) - relative or absolute
2. **Alt text** (optional) - defaults to "Screenshot"
3. **Caption** (optional) - italicized description below image

### Step 2: Build the URL

The image must already be committed and pushed to the branch the URL names, or GitHub will show a broken image.

```bash
REMOTE=$(git remote get-url origin)     # git@github.com:owner/repo.git or https://github.com/owner/repo.git
BRANCH=$(git rev-parse --abbrev-ref HEAD)
REPO_PATH=$(git ls-files --full-name -- "$IMAGE_PATH")   # path relative to the repo root
```

Turn `REMOTE` into `owner/repo` (strip the host prefix and a trailing `.git`), then assemble:

```
https://raw.githubusercontent.com/<owner>/<repo>/<BRANCH>/<REPO_PATH>
```

If `git ls-files` prints nothing, the image isn't tracked yet. Say so and ask whether to commit it first (see the directory convention above). If the remote isn't on github.com, use the relative path and warn, as under Error Handling.

### Step 3: Present the Result

Show the generated markdown to the user:

```markdown
## Generated Screenshot Markdown

```markdown
![Alt Text](https://raw.githubusercontent.com/user/repo/branch/path/image.png)

*Caption text*

<!-- GitHub URL: https://raw.githubusercontent.com/... -->
<!-- Local path: ./github-screenshots/image.png -->
```
```

Then ask: "Should I insert this somewhere, or just copy it?"

### Step 4: Optional Insertion

If user wants it inserted:
- Ask where to insert (e.g., "in the PR description I'm writing")
- Use Edit tool to insert at appropriate location
- Confirm insertion complete

## Example Interaction

**User:** `/github-screenshot`

**Claude:**
```
I'll help you generate GitHub screenshot markdown.

What's the image path?
```

**User:** `./github-screenshots/dashboard-before.png`

**Claude:**
```
Alt text for the screenshot? (default: "Screenshot")
```

**User:** `Dashboard before refactor`

**Claude:**
```
Optional caption? (press enter to skip)
```

**User:** `Shows the original dashboard layout`

**Claude:** *Builds the URL and presents result*
```markdown
## Generated Screenshot Markdown

![Dashboard before refactor](https://raw.githubusercontent.com/user/repo/main/github-screenshots/dashboard-before.png)

*Shows the original dashboard layout*

<!-- GitHub URL: https://raw.githubusercontent.com/user/repo/main/github-screenshots/dashboard-before.png -->
<!-- Local path: ./github-screenshots/dashboard-before.png -->

Would you like me to insert this somewhere?
```

## Error Handling

### File Not Found
If image doesn't exist:
```
❌ Error: Image file not found at ./github-screenshots/missing.png

Please check the path and try again.
```

### Not in Git Repository
If the git remote or repo root can't be found:
```
⚠️ Warning: Couldn't generate GitHub URL (not in a git repository)

Generated markdown with relative path instead:
![Alt Text](./github-screenshots/image.png)

Note: This may not display correctly in GitHub
```

## Common Use Cases

### PR Description with Screenshot
```
User: "Add this screenshot to the PR description"
Claude: [runs skill, gets markdown, inserts into PR description being drafted]
```

### Multiple Screenshots
```
User: "Add 3 screenshots"
Claude: [runs skill 3 times, collecting all markdown, then inserts all at once]
```

### Quick Copy
```
User: "Just generate the markdown, I'll paste it myself"
Claude: [runs skill, presents markdown, doesn't insert anywhere]
```

## Integration with Your Workflow

This skill encodes the full screenshot workflow, so you don't have to remember the URL format or the directory convention.

## Notes

- The URL pattern depends only on the git remote, branch, and tracked path
- Works in any git repository with a GitHub `origin`
