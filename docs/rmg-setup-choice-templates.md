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
