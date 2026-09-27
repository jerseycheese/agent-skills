# Batch brief: {milestone} / {slug}

<!-- Vendor-neutral. For a Claude cloud session, send the /goal line first, then this whole brief.
For Codex or Gemini, paste the whole thing; the goal line becomes the stated finish condition. -->

/goal PR from `batch/{milestone}-{slug}` is open against `{base}`, this session has shown {gate commands} passing on the final commit, CI is green on the PR head, and every review thread is answered

**Lane:** {vendor}/{model}, {cloud|local}

## What this batch does
{one paragraph: the outcome, in plain words}

## Issues
- #{n}: {title}. Done when: {acceptance criteria, or "see issue"}
- ...

## Files
- **You own:** {paths}
- **Don't touch** (another batch owns them): {paths, and which batch}

## How to work
1. Fetch `{base}` from the remote, then branch `batch/{milestone}-{slug}` from it.
2. Read each issue with its comments before writing anything. If an issue turns out to be already
   fixed, blocked, or much bigger than its label, stop working on that issue and say so in the PR.
   Don't force it.
3. Test first where there's logic to test. Keep changes to what the issues ask for.
4. Run the gate: {gate commands}. Show the output.
5. Open one PR against `{base}` with the body rendered from `{pr template}`. Keep every heading, and
   write "Not applicable." where a section doesn't apply. Link each issue with `Closes #n`. Put the
   `Lane:` line under the implementation notes.
6. If anything can only be checked locally, add a **Local check before merge** section with the
   exact commands and steps.
7. Drive CI to green. Answer every review thread: fix it, or explain why not.

## Never
- Merge, approve, or enable auto-merge.
- Push to or target {off-limits branches}.
- Skip, disable, or loosen a test to get green.
- Wait on CI with a notification-wait tool. Poll in a blocking loop, or end the turn.

## Repo traps
{adapter trap list}
