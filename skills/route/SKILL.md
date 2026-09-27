---
name: route
description: Recommend which AI provider and model to use for a task, given your routing table and current subscription burn. Recommends only; never switches anything or starts the work. Use when the user asks where to run something, which model to use, whether to switch providers, or invokes /route. Other skills (backlog-routing) call it once per batch to pick a lane.
---

# Route

Recommend a provider and model for the task at hand. Recommend only. Never switch anything
automatically, and never start the work in place of answering.

## Setup (once per machine)

The routing table and the budget tools are personal, so they live on your machine, not in this
repo.

| What | Where | If it's missing |
|---|---|---|
| Routing table | `$AI_ROUTING_TABLE`, default `~/.agents/ai-routing.md` | Stop and say so. Start one from `ai-routing.example.md` next to this skill. |
| Burn reader | `$AI_BUDGET_DIR/read-burn.sh --human` | Treat every seat's burn as unknown and say so. |
| Route logger | `$AI_BUDGET_DIR/log-route.sh` | Skip logging and say so once. |

In a cloud session none of these exist. Ask the user for their table and a burn reading (a
screenshot or pasted dashboard is fine). If they can't give one, say the call has no usage data
behind it and fall back to the table's first choice for that row.

## Steps

1. Read the routing table and its rules from `$AI_ROUTING_TABLE`.
2. Get current burn: `bash "$AI_BUDGET_DIR/read-burn.sh" --human`.
3. Classify the task into one phase from the table. If it spans phases, pick the phase of the
   immediate next step rather than the whole job.
4. Apply the ladder: name the row's first choice. Escalate only in two cases:
   - the first choice's seat is at or past 90 percent used, in the window the work will actually
     spend
   - the user says the first choice already struggled on this task

   Weekly headroom on its own is never a reason to escalate.
5. Check the brief's shape. If the call lands on a seat that drops multi-issue briefs (see
   "Sizing a brief" below) and the work spans more than one issue, say to split it, one issue
   per brief.
6. Log it: `bash "$AI_BUDGET_DIR/log-route.sh" <app> <phase> <recommended> [chosen]`, where
   `<app>` is the app this is running in. Pass the fourth argument whenever the call departs from
   the row's first choice, so overridden rows surface in the log.

## Output

Exactly three lines. No preamble, no alternatives the user didn't ask for.

```
PHASE:  implementation
GO TO:  Antigravity / Gemini Flash
WHY:    long autonomous run, and this seat refreshes every 5h
```

Add a fourth line only when a seat is genuinely constrained, or when the brief needs splitting:

```
NOTE:   Codex 5h at 91%, resets 14:38
```

```
NOTE:   3 issues — send as 3 briefs, Flash drops all but the first
```

Add a short paragraph only when the call departs from the row's first choice. An unexplained
override can't be audited, and catching wrong rows is the whole point of logging them. Name what
moved the call, then stop.

When another skill calls this for several batches at once, give one three-line block per batch,
headed with the batch name.

## Which window the work spends

Decide this before comparing seats. The seats differ far more on one window than the other.

A `/goal` run, a multi-lane batch, or anything that keeps working across turns spends the
**5-hour message allowance**. Compare 5h windows and per-window message caps, not weekly
balances. A premium reasoning seat can carry as few as 10–100 messages per 5h, so a batch drains
it within minutes however much of its weekly is left. That's why a high-throughput seat leads the
dispatch row: throughput is the resource being spent.

A single request, a review, a spec, or a one-shot fix spends little enough that the weekly
balance is the fair comparison.

If the weekly on the right seat is tight, cut the number of lanes rather than switching seats.
Three lanes on 40 percent weekly is the shape that stalls mid-run. Two lanes on that same
40 percent lands.

If remaining capacity likely won't cover the work and the window resets within two hours,
recommend waiting. Be stricter about this for parallel runs, which multiply the burn rate.

## Sizing a brief

Some seats finish the first issue in a multi-issue brief and silently drop the rest. Gemini Flash
in Antigravity has done this more than once, including when the brief was an explicit written
handoff naming every issue. So for anything spanning several issues on such a seat, recommend one
brief per issue, not one brief listing them all. The routing table's rules name which seats this
applies to.

This is separate from cutting lanes. Cutting lanes is about capacity; this is about brief shape.
Three issues in one brief fail on a full seat just as readily.

Two things follow when the user reports back on a batch:

- **Check for a PR, not branch activity.** A pushed branch with one WIP commit is what an
  abandoned task looks like, not a task in progress. The check is `gh pr list --search` per issue.
- **Count the recovery cost.** When weighing whether the cheap seat was the right call, count the
  takeover sessions the drops cost, not just the dispatch. A silent failure whose recovery lands
  on an expensive seat isn't a cheap seat.

## Reading the burn honestly

- **Some numbers go stale.** Sources that only update while their tool runs (Codex session
  snapshots, for instance) can be out of date. When the reader says STALE, treat that 5-hour
  figure as unknown rather than current, and say so instead of quoting it.
- **Some numbers are estimates.** A figure scored against this machine's own history shows
  pressure, not a real remaining balance. Never present it as a precise allowance.
- **Some seats report nothing.** If the answer depends on a seat that reports nothing, say it's
  unreadable and suggest where the user can check (the tool's own `/usage`, say).
- **Watch the direction of the percentage.** Readers often print percent **used** while provider
  dashboards print percent **remaining**. Convert before comparing, and say which one any quoted
  number is. Reading 81 percent off a dashboard as 81 percent spent inverts the decision.
- **The user's reading wins.** A screenshot or pasted dashboard beats the reader, including a
  STALE line it resolves. When it flips the call, say so plainly rather than quietly switching.
