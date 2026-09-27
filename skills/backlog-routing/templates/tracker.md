# {milestone} run

<!-- Issue body for the run tracker. Label: run-tracker. Milestone: {milestone}.
The orchestrator edits this in place. The human reads "Review queue" and "Needs you". -->

<!-- backlog-routing:state
{
  "milestone": "{milestone}",
  "base": "{base}",
  "updated": "{ISO 8601 timestamp of this edit}",
  "needsYou": [],
  "batches": [
    {
      "slug": "{slug}",
      "wave": 1,
      "issues": [123],
      "seat": "{provider} / {model}",
      "where": "local",
      "briefs": 1,
      "status": "waiting",
      "dispatchedAt": null,
      "pr": null,
      "localCheck": null
    }
  ]
}
-->
<!-- The block above is what the dashboard reads (dashboard/index.html). Keep it valid JSON and
rewrite it in the same edit as the tables below. status: waiting | dispatched | pr-open |
in-review | merged | dropped. where: local | cloud. pr: the PR number once one exists.
localCheck: the local check the human still has to run, or null. needsYou: short strings. -->

**Milestone:** {link} · **Base:** `{base}` · **Last updated:** {timestamp}

## Review queue
<!-- Green PRs with no unanswered verified findings, oldest first. -->
| PR | Batch | What changed | Proof | Local check before merge |
|---|---|---|---|---|

## Needs you
<!-- Decisions, local checks, blocked items. One line each, with what's needed. -->

## Waves
| Wave | Batch | Issues | Tier → lane | Where | Owns | Status |
|---|---|---|---|---|---|---|
<!-- Status: waiting on #n · dispatched {link} · PR open {link} · in review · merged -->

## Collisions
<!-- file → owning batch; which batches were told to leave it alone -->

## Out of this run
<!-- Issues in the milestone that no batch covers (frontier, blocked, human-only), and why. -->

## Briefs
<details><summary>{slug}: {vendor}/{model}</summary>

{rendered brief}

</details>
