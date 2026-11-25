---
name: playtest-personas
description: >
  Plays a game as blind personas. A fresh subagent per persona reads only the player manual and a persona card, plays through the game's own UI, and reports what confused, bored or delighted that kind of player. Use before a human playtest. Trigger on: "playtest this as a new player", "run the personas", "who would quit this game and why", "pre-playtest the build".
---

# Playtest personas

Each persona is a kind of player: a kid who taps fast, a skimmer who never reads the manual, a min-maxer hunting for the one best move. A fresh subagent plays that player through the game's real UI, knowing only what a real player would know, and writes down where it got lost, stuck, bored or delighted.

It finds what tests and bot runs can't: a screen nobody can read, a rule the manual states wrongly, a dead end, a choice that doesn't matter. It doesn't replace the human feel call. An agent can't feel reflex timing, can't judge whether the room laughed, and won't have your taste. Say so in every report.

## The adapter

Each game supplies a small adapter skill (`<game>-playtest`) holding what this skill can't know:

| It supplies                  | Example                                                              |
| ---------------------------- | -------------------------------------------------------------------- |
| Build under test             | How to start it, and which port                                      |
| The manual                   | The one file a persona may read about the game                       |
| Surfaces                     | The URLs or windows a player sees, and the size of each              |
| Harness controls             | The few dev controls a persona may use, and why (see below)          |
| Persona cards                | A `personas/` folder, one file per persona                           |
| Evidence folder              | Where logs and screenshots land (gitignored)                         |
| Ruled items                  | Where the owner's rulings live, so a persona doesn't re-report them  |
| What the run can't cover     | Real-time pressure, two-human play, whatever the harness can't do    |

## A persona card

One short file. Plain sentences, in the persona's own terms:

- **Who:** age, gaming habits, who they're playing with.
- **Why they're here:** what they want out of ten minutes.
- **Manual:** reads all of it, skims it, or opens it only when stuck (and says when).
- **Plays like:** the habits that shape every choice.
- **Notices:** what this player sees that others miss.
- **Quits when:** the moment they'd put the game down.
- **Budget:** how many turns, beats or minutes they play.

A card describes a player, never a test. "Taps the first card every time" is a card. "Verify the stamina cost table" is a test, and belongs in a unit test.

### Archetypes

`archetypes/` holds generic cards for player types that most games need: skimmer, careful newcomer, button masher, min-maxer, tinkerer, returning player, edge poker, and low vision, keyboard first. Each one ends with a "Specialize" line. To use one, copy it into the adapter's `personas/` folder and fill in that game's own words, controls and budget. Write a new card from scratch only for a player type the archetypes don't cover, and add it here once a second game needs it too.

## Surfaces that need more care

- **A native window.** Drive it with screenshot-based computer use, granted for that one app. Screenshots cost far more than reading a page's text, so if the game exposes its state any other way (a debug server, a log, a runtime inspector), the adapter names it as a measurement the persona may read. Keep dev flags that change play out of the launch command.
- **A game that calls a paid model.** The adapter sets a spend cap per run and says which mode the run uses. A mock or canned mode costs nothing, but it can't judge the writing, pacing or anything else the model produces, so a mock run reports only on the screens and the rules. A live run notes its spend in the report.
- **A page that throttles when hidden.** A hidden browser pane can draw a few frames a second, or none at all at zero size. If the game steps its simulation once per frame, the adapter supplies a step pump (a harness control that advances the simulation on a timer) and an explicit window size.

## Run it

1. **Prepare.** `git fetch`, build the exact commit under test, start it, and note the commit in the report. Check that the game actually renders and runs at speed on the surface the persona will use. A persona on a stalled or throttled page reports the harness, not the game.
2. **One fresh subagent per persona, one at a time.** A single browser and a single game session can't take two players, unless the adapter says otherwise. Hand each subagent this and nothing else:
   > You are `<persona>`. Read your card at `<path>` and the manual at `<path>`. Those are the only files you may read. Play `<game>` through `<surfaces>` for `<budget>`. Never open the source, other docs, the console or another persona's log. Use only the harness controls `<list>`, and say in your log each time you do. Write `<evidence>/<persona>/log.md` as you go: for each moment that matters, what you tried, what you expected, what happened, and how you felt, in your own voice. Screenshot every finding. Finish by returning the report below as your final message, ending with a "Harness notes" section: anything in these instructions that was wrong or missing, and anything you learned from outside your allowed files.
3. **Collect.** Subagents usually can't write report files, so save the merged report as `report.md` beside the persona logs. Read the log yourself. A report is a claim, so check it against the evidence before it goes any further. Fix the adapter for every harness note before the next run.
4. **Merge.** Group findings across personas. Two personas hitting the same wall is a strong signal. Two personas disagreeing is also signal: report both, don't average them.
5. **File what's real.** Confirm each bug once on a fresh build, then send it through the repo's normal intake, with its existing labels and templates. Skip anything on the adapter's ruled-items list. Confusion that traces to the manual is a docs fix, not a game bug.

## The report

Each persona ends with:

- **Verdict:** would they play again, and would they tell a friend. One sentence each, with the reason.
- **Findings:** one row per item.

| Bucket    | Means                                                                                             | Goes to                          |
| --------- | ------------------------------------------------------------------------------------------------- | -------------------------------- |
| Bug       | The game can't continue, did something wrong, or contradicts the manual                           | Confirm, then file               |
| Confusion | The player couldn't tell what to do or what just happened, even if the game is right              | Fix the screen or the manual     |
| Drag      | It worked, and it was slow, samey or pointless                                                    | Owner decides                    |
| Delight   | Something landed and the player said so                                                           | Keep it, and protect it          |

Every finding carries: what happened, the persona's own words in one line, the moment (turn or beat), and a screenshot. A finding without evidence is marked unconfirmed.

The merged report opens with one line, `N bugs, M confusions, K drags, D delights across P personas`, then the per-persona verdicts, then the findings table, then **What this run can't tell you**.

## Rules

- **Blind means blind, as far as the harness allows.** A persona that has read the source reports what the code does, not what a player sees. A subagent started inside the repo may still receive its instruction files as context. If a persona's log or harness notes show it knew something a player couldn't, discard that finding.
- **Confusion counts even when the game is right.** The manual and the screens are part of the product.
- **A persona never fixes anything.** It plays and reports.
- **Same plan, many matches.** A persona hunting a dominant strategy needs several runs of the same plan before it says "dominant". One win is a story.
- **Say what's observed and what's guessed.** "The button did nothing" is observed. "The player would quit here" is a guess, so label it.
