---
name: update-routing
description: >
  Refreshes the model roster in the routing table that `route` reads, when new models ship.
  Compares models within each provider, sources and dates every number, and edits only the
  table. Trigger on: "update the routing table", "new models are out", "refresh /route's model
  list", or a shared benchmark chart or model-picker screenshot.
---

# Update routing

Refresh the model roster in the routing table that the `route` skill reads:
`$AI_ROUTING_TABLE`, default `~/.agents/ai-routing.md`. If it's missing, stop and say so; the
starter is `ai-routing.example.md` next to the `route` skill. This is judgment work, not a
find-replace. The comparisons in step 2 are where most of the value is.

## Steps

1. Get current data: a fresh intelligence-vs-cost chart (or an equivalent benchmark) and a
   screenshot of the current model picker for each provider the table routes to. If what the
   user shares is cropped, missing an axis, or otherwise incomplete, ask for the rest rather
   than guessing at it.

2. Compare within each provider only. The table rations flat-rate subscription seats, so a
   chart's dollar-cost axis is pay-per-use API pricing. That's valid for comparing tiers or
   generations *within* one provider, never for ranking across providers: "this model is
   cheaper than that provider's model" isn't a reason to prefer it when both seats are already
   paid for. For each provider, note:
   - Genuine dominance: a newer tier or generation matches or beats an older one on
     intelligence at the same or lower cost. It replaces the old first choice.
   - A real trade-off: cheaper but also less capable. Don't force a swap. List both and say
     which axis moved.
   - Models from a provider the table doesn't list as a seat: mention them if relevant, but
     never route to them.

3. Search the web for current messages-per-5h figures per model. Date and cite every number
   you add. If a figure isn't published for a new model yet (common right after a launch), say
   so: mark it inherited from the slot the previous generation held, or as an estimate. Never
   present a guess as measured.

4. Update only the parts of the table that carry the roster:
   - The main phase table (bare model names, no reasoning-tier suffix).
   - The rate-limit reference card (throughput numbers, sourced and dated).
   - An efficient-settings section, if the table has one (which tier or generation is worth
     spending on, and why).
   Leave worked examples alone unless a model *name* changed. They reference the main table's
   choices by name, so tier-only changes don't touch them.

5. Bump every "Last checked" date you touched to today.

6. Run `/route` once afterward on a real task to check the output still reads right end to
   end.

## What not to do

- Don't overwrite a benchmark citation with a number for a newer model unless that model was
  measured on the same benchmark. A different benchmark measuring a different thing isn't a
  substitute.
- Don't fold a cross-provider cost comparison into the reason for a routing change. It's the
  wrong axis for a flat-rate-seat problem.
- Don't silently drop the prior generation from the rate-limit card while the provider still
  offers it. Note it as the prior generation instead of deleting the row.
