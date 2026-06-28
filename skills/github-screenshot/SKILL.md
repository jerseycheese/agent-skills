---
name: github-screenshot
description: >
  Generates GitHub-compatible markdown for screenshots using raw.githubusercontent.com URLs
  via the generate-github-image-markdown.sh script.
  Trigger on: "add a screenshot to this PR", "embed image in issue", "attach screenshot",
  "paste image into GitHub", "add screenshot to docs", "insert image in markdown",
  "show a screenshot in the PR", "add image to issue".
---

# GitHub Screenshot Helper

## When to Use This Skill

Use this skill when:
- Adding screenshots to PR descriptions
- Including images in GitHub issues
- Documenting features with screenshots
- Creating visual documentation in markdown

## Setup

This skill wraps a local `generate-github-image-markdown.sh` script. Update the path below to match your own installation before using.

## What This Skill Does

Runs your `generate-github-image-markdown.sh` script to:
- Generate proper raw.githubusercontent.com URLs
- Create markdown with alt text and captions
- Handle git repository detection automatically
- Include helpful comments with local paths

## Usage Flow

### Step 1: Gather Information

Ask the user for:
1. **Image path** (required) - relative or absolute
2. **Alt text** (optional) - defaults to "Screenshot"
3. **Caption** (optional) - italicized description below image

### Step 2: Run the Script

Execute:
```bash
~/tools/screenshots/generate-github-image-markdown.sh \
  "$IMAGE_PATH" \
  "$ALT_TEXT" \
  "$CAPTION"
```

**Permission pattern needed** (update path to match your setup):
```
Bash(~/tools/screenshots/generate-github-image-markdown.sh:*)
```

### Step 3: Present the Result

Show the generated markdown to the user:

```markdown
## Generated Screenshot Markdown

```markdown
![Alt Text](https://raw.githubusercontent.com/user/repo/branch/path/image.png)

*Caption text*

<!-- GitHub URL: https://raw.githubusercontent.com/... -->
<!-- Local path: ./screenshots/image.png -->
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

**User:** `./screenshots/dashboard-before.png`

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

**Claude:** *Runs script and presents result*
```markdown
## Generated Screenshot Markdown

![Dashboard before refactor](https://raw.githubusercontent.com/user/repo/main/screenshots/dashboard-before.png)

*Shows the original dashboard layout*

<!-- GitHub URL: https://raw.githubusercontent.com/user/repo/main/screenshots/dashboard-before.png -->
<!-- Local path: ./screenshots/dashboard-before.png -->

Would you like me to insert this somewhere?
```

## Error Handling

### File Not Found
If image doesn't exist:
```
❌ Error: Image file not found at ./screenshots/missing.png

Please check the path and try again.
```

### Not in Git Repository
If script can't detect git repo:
```
⚠️ Warning: Couldn't generate GitHub URL (not in a git repository)

Generated markdown with relative path instead:
![Alt Text](./screenshots/image.png)

Note: This may not display correctly in GitHub
```

### Script Not Found
If the script is missing:
```
❌ Error: Screenshot script not found at expected location.

Please verify the script exists at the path configured in this skill,
or update the path in Step 2 to match your installation.
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

This skill encodes the full screenshot workflow — you just invoke it instead of remembering the script path, argument order, and permission pattern every time.

## Notes

- This skill wraps a local script
- The script handles all the git complexity (remote detection, branch detection, path conversion)
- Permission pattern is encoded in the skill, so you don't need to remember it
- Works in any git repository, automatically detects repo details
