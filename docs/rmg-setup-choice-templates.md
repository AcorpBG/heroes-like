# Setup-choice map templates

Owner decision, 2026-11-06: five original templates go into the game as choices on the skirmish setup screen. They are never in H3MapEd's template roll, so the recovered template selection over its 53 templates stays exact. This is a deliberate departure from H3MapEd, like the cut-off town repair (`docs/rmg-cut-off-town-repair.md`).

## The five

They were proposed on 2026-11-06 from a survey of the 53 recovered templates: eight shapes, the rules their numbers follow, and the setups where few templates have exactly as many starts as players.

| Template | Shape | Size score | Players | Zones / links at the smallest and largest count |
|---|---|---|---|---|
| Cartwheel | rich hub with a rim of shared treasure zones between neighbouring starts | 9-32 (large to extra large two-level) | 3-6 | 7/9 to 13/18 |
| Inner Keeps | ring of starts around an inner ring of rich keeps | 9-32 | 3-6 | 6/12 to 12/24 |
| Pilgrim Roads | one long road per player (start, waystation, far reach) to a guarded crossroads and its prize | 9-32 | 3-6 | 11/10 to 20/19 |
| Trefoil Fields | three duel lanes: each start between two town zones and a contested field | 4-18 (medium to large two-level) | 3 | 12/15 |
| Five Gates | gated hub: each start has a private pocket, the hub reaches five gated zones | 16-32 (extra large) | 5 | 16/15 |

The growing templates follow Ring's player-filter rule: start k and its zones appear from k players, and a link that closes a ring exists only at its own count (min and max total both k), so the ring always closes. Every start is a human start, as the generator makes every seat human-or-computer (owner decision, 2026-10-29).

Templates with exactly n starts, one human (before and after): medium 3P 5 to 6, large 3P 3 to 7, large 4P 10 to 13, extra large 5P 3 to 7, extra large 6P 7 to 10.

## Where they live

- `content/random_map_template_catalog.json`: each is a template marked `"selection": "setup_choice"`, with a `summary`, and a profile, in the catalog's schema (game names for factions, terrains and resources). `scripts/tools/import_random_map_template_catalog.py` carries setup-choice templates over on a re-import.
- The setup screen's Map layout picker offers Random layout (H3MapEd's roll, the default) and the setup choices that fit the chosen size, levels and water (H3MapEd's size score: width x height x levels / 0x510, halved on islands). A chosen layout sets the player counts the setup offers. `ScenarioSelectRules.random_map_setup_choice_templates` lists them.
- A chosen template's config carries `template_selection.mode = "setup_choice"` and the template in `profile.template_id`; `_random_map_public_h3maped_launch_config` keeps it instead of rebuilding the setup for the roll.
- `tools/ai_match_batch.py --map-template ID` plays every match of a batch on one; it refuses a template that does not fit a group's size, levels, water or players. `bin/match_sim_cli` and `tests/ai_versus_ai_match_report.gd` take `HEROES_AI_MATCH_TEMPLATE`.

## How the generator builds one

`map_generation.cpp` (`chosen_template_records`) turns the catalog template into the rows H3MapEd's template catalog holds (the encoding of `tools/generate_h3maped_rmg_template_catalog_cpp.py`): zone type, bucket, owner, base size, player filter, town and monster masks, terrain flags, town rules, mine minimums and densities, three treasure bands; link ends, guard value, wide, border guard and player filter. Faction, terrain and resource names map back to H3MapEd's codes, the inverse of the importer's tables (a faction stands for every H3 town the importer gives it).

`chosen_template_selection_and_runtime_seed_inputs` (`h3maped_rmg_template_catalog.cpp`) stands in for 0x4ac552's roll: it keeps the roll's one RNG draw, so every later phase starts from the RNG state it would, and builds the runtime seed through the same owner masks, player slot assignment and runtime seed build. A chosen template whose filtered links split its zones, or that does not fit the size or players, blocks generation instead of being re-picked. Everything after the selection is the recovered generator and its departures (cut-off town repair, guard minimum, treasure spacing, guard-free route seal).

Package metadata names the template (`source_template_authority` `setup_choice`, `source_template_id` the catalog id) and claims no H3MapEd parity (`full_parity_claim` false). The maps folder launches such packages like rolled ones.

## Adding another

Write the template and its profile into the catalog with `"selection": "setup_choice"`, every start a `human_start` with an `owner_slot`, and the fields above. Check it connects at every player count it offers (`_random_map_template_active_graph_connected` drops counts where it does not) and generate a map at each fitting size. It needs no native change.

## AI games on the five, 2026-11-06

The owner asked for 100 AI games on each. They ran on d6e8e3fbd with `--map-template`: weak, normal and strong guards, one and two levels, land, balanced line-ups. They are compared with the 1,200-game batch on c7dad2e4e, which had the same guard and level mix on maps H3MapEd's roll chose. All 500 games were decided; none reached the day cap and none failed (2 of the 1,200 were capped). Day, first elimination and winner's gold are medians; towns, captures and fights are means per game.

| Setup | Map | Games | Towns | Day median (q1-q3) | First out | Captures (no defender) | Guard / hero / town fights | Winner's gold |
|---|---|---|---|---|---|---|---|---|
| 3P M | Rolled | 180 | 6.4 | 55 (44-67) | 37 | 20.8 (7.0) | 102 / 21 / 13 | 12,451 |
| 3P M | Trefoil Fields | 50 | 9.0 | 74 (58-88) | 51 | 35.1 (10.8) | 153 / 28 / 23 | 37,297 |
| 3P L | Rolled | 120 | 9.7 | 80 (64-101) | 53 | 37.9 (11.4) | 259 / 30 / 25 | 40,400 |
| 3P L | Cartwheel | 25 | 5.0 | 87 (68-94) | 61 | 26.6 (9.6) | 261 / 22 / 16 | 38,803 |
| 3P L | Inner Keeps | 25 | 6.0 | 72 (67-88) | 52 | 21.1 (8.2) | 242 / 17 / 12 | 19,859 |
| 3P L | Pilgrim Roads | 25 | 6.0 | 103 (82-124) | 79 | 27.1 (7.1) | 395 / 27 / 19 | 148,695 |
| 3P L | Trefoil Fields | 50 | 9.0 | 94 (80-108) | 70 | 45.1 (13.0) | 312 / 33 / 31 | 67,278 |
| 4P L | Rolled | 180 | 10.2 | 84 (69-108) | 46 | 45.0 (14.1) | 301 / 41 / 29 | 61,159 |
| 4P L | Cartwheel | 25 | 6.0 | 88 (74-99) | 46 | 37.0 (12.8) | 268 / 32 / 23 | 53,009 |
| 4P L | Inner Keeps | 25 | 8.0 | 73 (57-95) | 36 | 25.2 (8.4) | 236 / 25 / 16 | 23,577 |
| 4P L | Pilgrim Roads | 25 | 8.0 | 109 (98-132) | 68 | 38.0 (10.4) | 439 / 40 / 27 | 248,520 |
| 5P XL | Rolled | 150 | 14.5 | 116 (96-134) | 50 | 99.9 (33.7) | 575 / 76 / 63 | 114,460 |
| 5P XL | Cartwheel | 25 | 7.0 | 106 (95-119) | 51 | 60.4 (21.7) | 498 / 49 / 37 | 140,204 |
| 5P XL | Five Gates | 100 | 10.3 | 93 (85-110) | 39 | 63.5 (21.5) | 378 / 58 / 40 | 103,600 |
| 5P XL | Inner Keeps | 25 | 10.0 | 106 (83-131) | 35 | 43.7 (13.6) | 526 / 39 / 29 | 188,758 |
| 5P XL | Pilgrim Roads | 25 | 10.0 | 130 (118-165) | 73 | 63.6 (17.4) | 762 / 63 / 44 | 400,889 |
| 6P XL | Rolled | 150 | 14.6 | 123 (98-139) | 41 | 114.2 (39.7) | 580 / 90 / 72 | 151,661 |
| 6P XL | Cartwheel | 25 | 8.0 | 108 (92-118) | 42 | 69.3 (24.6) | 497 / 62 / 42 | 179,069 |
| 6P XL | Inner Keeps | 25 | 12.0 | 98 (90-108) | 36 | 53.8 (18.3) | 450 / 51 / 34 | 161,736 |
| 6P XL | Pilgrim Roads | 25 | 12.0 | 139 (120-163) | 62 | 100.1 (32.7) | 744 / 87 / 65 | 445,738 |

- **Fewer towns.** Cartwheel, Inner Keeps and Pilgrim Roads carry fewer towns than the rolled maps: 5-8 on large against about 10, and 7-12 on extra large against 14.5. Their rims, waystations and far reaches hold no towns, so there are fewer captures. Trefoil Fields has more on medium (9 against 6.4).
- **Pilgrim Roads plays slowest.** Compared with rolled maps:
  - the first elimination comes 15-26 days later;
  - games run 15-29 days longer;
  - there are about a third more guard fights;
  - the winner's unspent gold is three to four times as high.
- **Inner Keeps and Five Gates play fastest.** Games are 8-25 days shorter and the first elimination comes up to 15 days earlier.
- **Cartwheel** runs about as long as rolled maps on large and 10-15 days shorter on extra large, with the fewest towns.
- **Trefoil Fields** runs longer than rolled maps (74 against 55 days on medium, 94 against 80 on large), with more captures and town fights.
- **Factions.** Place points stay within ±2 sd in most batches. On Pilgrim Roads, Brasshollow and Mireclaw are above the band and Embercourt is below it; on Inner Keeps, Embercourt is above. That is one bank of 100 maps per template, not a balance finding.
