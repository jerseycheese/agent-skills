# AI provider routing

<!-- Starter table for the `route` skill. Copy to ~/.agents/ai-routing.md (or wherever
$AI_ROUTING_TABLE points) and fill in your own seats. Keep it on your machine: it describes your
subscriptions and budget, not a project. The phases are the part other skills rely on, so rename
models freely but keep the phase names stable. -->

List which subscriptions cover the work, and which one is scarce and needs protecting. This file
exists so that rationing gets decided once, here, instead of per task.

## The table

Read left to right within a row: first choice, then escalation.

| Phase | First choice | Escalation |
|---|---|---|
| Planning, specs, architecture | <strong reasoning seat> | <premium seat> |
| Simple parallel dispatch (independent agents, pre-specced) | <high-throughput seat> | none (cut lanes instead) |
| Complex orchestration (agents depend on each other, mid-run re-planning) | <premium agentic seat> | none (rationed) |
| Bulk implementation | <high-throughput seat> | <strong reasoning seat> |
| Code review | <strong reasoning seat, different family from the author> | <premium seat> for security, concurrency, or architectural diffs |
| Root-cause debugging | <strong reasoning seat> | <premium seat> |
| Large-context reading and sweeps | <long-context seat> | none |
| Anything unnamed, plus chat | <default workhorse> | none |

## The rules

**Cheapest-capable first.** Each row lists models in ascending scarcity. Escalate only when the
first choice visibly struggles, not preemptively.

**Batches are metered by the 5-hour window, not the weekly.** Compare per-window caps for `/goal`
runs and multi-lane batches.

**One issue per brief on seats that drop work.** Name the seats here, with the dates you saw it.

**Count the recovery, not the dispatch.** A cheap seat whose failures are silent, and whose
recovery lands on an expensive seat, isn't cheap.

**Premium models earn their tokens.** Escalation targets, not defaults. Match the model to the
actual cognitive demand, not the category label.

**Override freely.** Overrides get logged. A row that keeps getting overridden is a wrong row.

## Rate-limit reference card

Per provider: rolling windows, approximate messages per window per model, and the date you last
checked. Mark numbers as observed or published.

## Budget signals

What `read-burn.sh` reports for each seat, where each number comes from, and how far to trust it
(exact, estimate, stale, or unreadable). Say whether it prints percent used or percent remaining.
