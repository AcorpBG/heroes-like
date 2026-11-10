# Army size bands

Slice: `ui-army-size-bands-20261110` (owner decision, 2026-11-10: hide the exact
numbers of units behind ranges; the ranges were left to the agent).

On the adventure map the player is no longer told how many creatures another
side's stack holds. It reads a word for a range.

| Word | Creatures | In a sentence |
| --- | --- | --- |
| Few | 1 to 3 | a few River Guard |
| Handful | 4 to 8 | a handful of River Guard |
| Squad | 9 to 15 | a squad of River Guard |
| Band | 16 to 30 | a band of River Guard |
| Company | 31 to 60 | a company of River Guard |
| Host | 61 to 120 | a host of River Guard |
| Multitude | 121 to 250 | a multitude of River Guard |
| Legion | 251 to 500 | a legion of River Guard |
| Countless | 501 or more | countless River Guard |

Each band is about twice the one before, so a word narrows a stack to a factor
of two and no closer, at every size a game reaches. The first bands are narrow
because a few high-tier creatures differ a great deal one by one.

The table is `kSizeBands` in `overworld_rules_encounter_text.cpp`;
`overworld_rules::army_size_band(count)` returns the word, its lead and its range,
`army_size_phrase(count, what)` the sentence form, and the screens call
`OverworldRules.army_size_band`.

## Where the bands replace counts

- The hover and the right-click report (`docs/overworld-tile-description.md`): an
  army reads "4 groups"; each stack in the report reads "Charcoal Mauls · Band (16
  to 30)". The report shows the range beside the word so nobody has to learn the
  table by heart.
- The rules' own army line (`_encounter_army_surface`: "4 groups | a band of
  Charcoal Mauls, ..."), which the battle prompt, the scout report line and the
  selected-tile panel reuse.
- The readiness line: "Numbers: enemy outnumbers" and "Readiness: your 2 groups
  against 4; enemy outnumbers." The two headcounts are gone; which side is larger
  stays.
- A creature dwelling's guard: "guarded by a squad of Beacon Lectors".
- An enemy town's garrison in the town line: "Garrison: a band of troops in 2
  companies", and the garrison Read Tracks shows in the report.
- A computer player's hero taking a town's garrison: "gathers a company of troops
  at Riverwatch Hold."

## What stays exact

The player's own armies, garrisons and recruits; every stack inside a battle and
in its aftermath; the creatures a dwelling offers for hire. The strength word
(Much weaker to Much stronger) still compares the real armies, and a battle's
reward is still told, so both hint at size without giving it.

## Validation

Medium land seed 4103 as Embercourt, map revealed: for four armies the hover, the
report and every rule text were read beside the real stacks (16, 15, 15 and 17
read Band, Squad, Squad, Band) and none holds a count; a dwelling's guard and the
enemy town's garrison read as bands. The band edges 3/4, 8/9, 15/16, 30/31, 60/61,
120/121, 250/251 and 500/501 fall as the table says.
