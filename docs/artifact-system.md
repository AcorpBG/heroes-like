# Artifact system

The owner reworked the artifacts on 2026-11-11, after the hero menu gave a hero fourteen places to wear them (`docs/hero-screen.md`). It was settled in two drafts on a local plan page (`.artifacts/artifact_plan/artifact_plan.html`, built by `.artifacts/artifact_plan/build/plan.py`; plan pages stay local views, never published). This doc holds the rules, the decisions and the build order. The 150 artifacts and ten sets are in `docs/artifact-system-catalogue.md`.

The 150 artifacts, their icons and their sets' steps are in the game since `artifact-catalogue-switch-20261111`, and the 32 special effects since `artifact-special-effects-20261111`.

## Why

The 69 artifacts were written for five slots. Head and ring had one artifact each for three places. Every artifact gave +1 or +2 to the same seven numbers, one touched spells, none had a drawback, and the four rarities were about equally strong (2.8, 1.6, 2.2 and 3.1 points on average, see Points). On a large generated map 25 of 69 pickups repeated an artifact already placed.

## The owner's decisions

First draft, 2026-11-11:

1. Strength follows rarity: 1, 2, 3 and 5 points, and each epic also bends one rule.
2. Each slot has a character (see Slots).
3. About 150 artifacts.
4. None of the 69 is reused, by name, id or icon.
5. A faction artifact works for any hero and gives one more bonus, its home line, to heroes of its faction.
6. Sets are more inventive than three-piece faction kits, and no set belongs to a faction.
7. Each epic and each full set has one special effect.
8. Six to eight rares give more than their band for a price.
9. Repeats stay as they are: a map may place an artifact twice, and a hero that claims one it holds gets nothing.

Second draft, 2026-11-11: the list is built as drafted (no notes, no special effect struck); six icons are painted as a trial and the rest quoted before the full run; saved games made before the switch lose their old artifacts.

## Points

One point is one rank of a hero specialty (`content/hero_specialties.json`). A hero has six specialties of four ranks, so at most 24 points of its own. A band's budget is exact: the plan page's build refuses an artifact that misses it.

| Band | Points | Lines | In the catalogue |
|---|---|---|---|
| Common | 1 | one | 36 |
| Uncommon | 2 | one or two | 44 |
| Rare | 3 | two or three | 48 |
| Rare with a price | 5, and one drawback | two or three | 7 of the 48 |
| Epic | 5, and one special effect | two to four | 22 |

Rare is the largest band because generated maps place rares most: one large map held 6 common, 21 uncommon, 36 rare and 6 epic pickups.

## Bonuses

An artifact may give anything a specialty gives, and Knowledge. The artifact code read ten kinds of bonus; the rules know the rest through specialties. A bonus on an artifact row uses the specialty's own key, so a new artifact is content, not code.

| On the page | Key in the rules | One point |
|---|---|---|
| Attack, Defense | `battle_attack`, `battle_defense` | +2 of one (a specialty rank gives +1 of both) |
| Power | `battle_power` | +1 |
| Knowledge | `knowledge` (new) | +1 |
| Max mana | `max_mana` | +3 |
| Initiative, cohesion, momentum | `battle_initiative`, `battle_cohesion`, `battle_momentum` | +1 |
| Melee damage, ranged damage | `melee_damage_pct`, `ranged_damage_pct` | +5% |
| Troops take less damage | `damage_taken_pct` (negative) | 4% |
| Defending stacks' Defense | `defend_defense_bonus` | +1 |
| Retaliation damage, damage when assaulting a town | `retaliation_damage_pct`, `siege_damage_pct` | +10% |
| Fallen that recover after a won battle | `victory_recovery_pct` | 5% |
| Creature health | `creature_health_pct` | +3% |
| Spell damage | `spell_damage_pct` | +5% |
| Boosts last longer, curses last longer | `buff_duration_bonus`, `debuff_duration_bonus` | 1 turn |
| Spell resistance, control resistance | `battle_spell_resistance_pct`, `battle_control_resistance_pct` | +5% |
| Mana after a won battle | `mana_after_victory` | 2 |
| A school's damage and healing | `school_potency_pct` | +8% |
| A school's spells cost less | `school_mana_discount` | 1 |
| All spells cost less | `mana_cost_discount` | 1 costs two points |
| Map movement, scouting | `overworld_movement`, `scouting_radius` | +1 |
| Movement kept for the next day | `movement_carry` | 1 |
| Gold a day | `daily_income.gold` | 75 |
| Wood and ore a day | `daily_income.wood`, `.ore` | 1 of each |
| The wearer's faction's rare resource a day | `daily_income.faction_rare_main` | 1 |
| Creature growth and recruit cost | `recruit_growth_multiplier`, `recruit_cost_delta` | +10% growth, 5% cheaper |
| Gold and resources from pickups and won battles | `reward_bonus_pct` | +10% |
| Experience | `experience_bonus_pct` | +5% |

Rules:

- **One sum.** A hero's bonuses are its specialties' and its worn artifacts' added together, read through the same call. A bonus kind the artifact code already summed on its own (Attack, Defense, initiative, movement, scouting, income, the two resistances) is counted once.
- **Knowledge** raises the hero's Knowledge wherever it is read: the mana maximum (8 + 4 a point) and the resistance its side has against enemy spells in battle.
- **A price** is a bonus with the opposite sign on the same row (−1 Knowledge, −2 map movement, troops take 4% more damage). The hero menu shows it apart from what the artifact gives.
- **A home line** is a second list of bonuses on a faction artifact, added only while the wearer's faction is the artifact's.

In `content/artifacts.json` (rules in `artifact_rules.cpp` and `hero_progression_rules.cpp`, since `artifact-bonus-rules-20261111`):

- `bonuses` holds any key of the table. `ArtifactRules.aggregate_bonuses` sums the ten kinds it always did (Attack, Defense, initiative, movement, scouting, the two resistances, a school's resistance, daily income, spell modifiers); every other key is added to the specialties' by `HeroProgressionRules.aggregate_bonuses` (`artifact_rules::worn_specialty_bonuses`), so every reader of a specialty bonus counts it.
- `home_bonuses` is the home line; it applies when the hero's faction is in the row's `faction_affinity`.
- A set piece names its set in `set_id`; a set's steps are its `piece_thresholds`, whose `bonuses` take the same keys.
- `daily_income` may name `faction_rare_main` or `faction_rare_secondary`: the wearer's faction's resources.
- A price is a negative amount (a positive `damage_taken_pct`). Bonus Knowledge never takes a hero's Knowledge below 0.

## Slots

| Slot | Places | Artifacts | Mostly gives |
|---|---|---|---|
| Head | 1 | 12 | Knowledge, mana, experience |
| Neck | 1 | 12 | Power, spell damage, one school's spells |
| Cloak | 1 | 12 | Spell and control resistance, scouting |
| Armor | 1 | 12 | Defense, creature health, less damage taken |
| Hand | 2 | 26 | Weapons: Attack, melee and ranged damage. Instruments: scouting, movement |
| Ring | 2 | 16 | Spell cost, spell length, income |
| Boots | 1 | 10 | Map movement, movement kept for the next day |
| Banner | 1 | 14 | The whole army: initiative, cohesion, momentum, creature growth |
| Trinket | 4 | 36 | Income, rewards, oddities; worn scrolls go here too |

45 of the 150 touch magic. A set piece may cross its slot's character.

## Factions

48 artifacts belong to a faction, eight each: two common, two uncommon, three rare and one epic. The other 102 belong to none. A set piece never belongs to a faction. Income of a rare resource pays the wearer's own faction's resource, whoever made the artifact.

## Sets

Ten sets, 31 pieces, in `docs/artifact-system-catalogue.md`. A set's steps apply while that many of its pieces are worn; the last step is its special effect.

- Three pairs: two rings, a sword and its left-hand blade, a ring and a pendant.
- The Four Chimes fill every trinket place, so their wearer wears no scroll.
- The Regalia of the Empty Throne has five pieces, from an uncommon banner to an epic crown.
- The Penitent's Burden is three rares with a price; worn together the three prices no longer apply.
- Four sets are made mostly of commons and uncommons.

## Special effects

32 in all: one on each of the 22 epics and one for each full set. Each is a small rule of its own; their wording is in the catalogue. All 32 are in the game.

How a row names its rule:

- An artifact's row carries `special_id`, and `ui.special_text` with `ui.special_live` true for the hero menu. A set's last step (the `piece_thresholds` entry all its pieces reach) carries the set's `special_id` and the effect's text as its `summary`.
- `tools/build_artifact_content.py` holds the ids (`SPECIAL_IDS`) and the four granted spells (`GRANTED_SPELLS`, written as `grants_spell_id`). A special effect without an id there is not shown in the game.
- `artifact_rules::worn_special_ids` gives the ids of what a hero wears. A battle keeps each side's ids in its hero payload (`artifact_specials`; `battle_rules::_hero_has_special`), so the battle's rules read them without the hero.
- The Penitent's Burden needs no rule: its last step gives back exactly what its three prices take.

| Effect | Id | Where the rule is |
|---|---|---|
| Twofold Diadem: a second spell in the first round | `second_spell_first_round` | `_mark_commander_spell_cast` (spell_events.cpp) |
| Crown of the Empty Throne: a seventh specialty | `seventh_specialty` | `_specialty_is_available` (enemy_states.cpp) |
| The Unanswered Word: half the enemy hero's Knowledge | `half_enemy_knowledge` | `spell_power_against` (spell_battle.cpp) |
| The Flame: the first spell of a battle is free | `first_spell_free` | `mark_battle_start`, `adjusted_spell_mana_cost` (spell_rules.cpp) |
| Shroud of the Unseen Fleet: shots from more than five hexes do half | `far_shots_halved` | `_artifact_damage_modifier` (damage_modifiers.cpp) |
| The Unbroken Wall: cohesion never below where it began | `cohesion_floor` | `_adjust_stack_cohesion`, `_stack_cohesion_total` |
| Mother-Graft Mail: a heal as each round begins | `round_graft_heal` | `graft_heal_round` (turn_order.cpp) |
| The Last Gate: the enemy cannot retreat or surrender | `no_escape` | `_escape_barred`, `_enemy_may_leave` (turn_order.cpp) |
| Never-Empty Quiver: shots never run out | `endless_shots` | `_consume_shot` (attack_effects.cpp) |
| The Opening Cut: each stack's first strike is not struck back | `first_strike_unanswered` | `strike_back_refused_reason`, `note_blow_for_strike_back` |
| The Open Hand: area spells spare the caster's stacks | `area_spares_own` | Cinder Spray's splash (spell_reach.cpp), Flame Furrow's fire (spell_ground.cpp) |
| Roadeater Boots: roads cost half | `roads_half` | `StepCosts` (spell_map.cpp) |
| Vanguard's Thunder: its side acts first in round 1 | `first_round_first` | `turn_order_score` (turn_order.cpp) |
| The Blood-Drum: 15% more damage to a stack that lost creatures | `blood_scent` | `_artifact_damage_modifier` |
| The Reader's Case: worn scrolls at +2 Power | `scroll_power` | `spell_power` (spell_battle.cpp) |
| The Standing Order: 25% less damage while it has not moved this round | `stand_fast` | `_artifact_damage_modifier`; a stack's `moved_round` (`_set_stack_hex`) |
| Writ of Relief: a defending stack gives +2 Defense to those beside it | `shield_neighbours` | `relief_defense_bonus` (damage_modifiers.cpp) |
| The Prime Lens: boosts cast in round 1 last the battle | `first_round_boosts_last` | `_effect_payload_for` (spell_battle.cpp) |
| Staff of the First Tree, Ring of the Noon Hour, The Ever-Coal, Mirror of the Far Shore: a tier-5 spell as if known | `grants_spell` | `lent_spell_ids` (spell_rules.cpp) |
| Twin Vows: mana comes back twice as fast | `mana_double` | `regain_daily_mana` (day_economy.cpp) |
| Question and Answer: a strike-back at every attack | `endless_strike_back` | `_consume_retaliation` (attack_effects.cpp) |
| Lens and Flame: half the mana back when a spell destroys a stack | `kill_refund` | `_refund_spell_for_kill` (spell_events.cpp) |
| The Four Chimes: one more rank of each school's mastery | `mastery_plus_one` | `spell_mastery_rank` (spell_reach.cpp) |
| Regalia of the Empty Throne: the town its wearer stands in builds twice a day | `second_build` | `mark_town_built` (overworld_rules_town_actions.cpp) |
| The Penitent's Burden: the three prices are lifted | `prices_lifted` | the set's last step |
| Cartographer's Table: sand, swamp, snow, rough ground and lava at grass cost | `flat_ground` | `StepCosts` |
| Camp Kit: +3 map movement after a day without a battle | `rested_march` | `movement_kept_for_day` (hero_command_rules_ai.cpp); a hero's `last_battle_day` |
| Ferryman's Fare: boarding and leaving a ship costs no movement | `free_boarding` | the human's and the computer's shore step, the computer's route search |
| Night Watch: all of a day's unused movement is kept | `keep_all_movement` | `movement_kept_for_day` |

Readings where the wording left room:

- Mother-Graft Mail heals as the Rootbound Ward does: up to one creature's health on the living creatures of the stack that misses most, raising nobody.
- Night Watch keeps what the day's own movement left, not movement already kept from earlier days, so an idle hero has at most two days' movement.
- The Opening Cut covers a stack's first melee strike of the battle; a shot does not spend it.
- The Standing Order counts any change of hex in the round, a pull or a push too.
- The Flame's free spell is the first the hero casts in the battle; the mark lives on the battle's copy of the hero.
- The Unbroken Wall holds a stack's cohesion at its starting value against losses and against curses. The computer's own damage estimates still read the stored value.
- A computer hero keeps unused movement for the next day as a human's does (`movement_carry`), which it did not before this slice.

The computer players wear the artifacts and their rules apply to them, but they do not yet plan around a special effect (a second cast in round 1, a second build): `loadout_values` weigh an artifact by its bonuses.

Four epics, one for each school, let the hero cast that school's tier-5 scroll-only spell as if it knew it (Second Sun, Eternal Noon, Green Return, Hollow Crown); those spells have no other source (`docs/magic-system.md`).

## Getting them

Unchanged: a generated map sorts its artifact pickups into the four bands and draws each on its own from all artifacts of that band, never a scroll. With 150 artifacts the large map above would repeat about 16 of its 69 pickups. A pickup is drawn on the map as the artifact's own icon (`artifact_field_sprites` in `art/overworld/manifest.json`).

Guarded sites, markets and battle salvage draw from their reward lists (`tools/artifact_reward_tables.json` says who draws from each; the content tool fills in the artifacts): neutral commons for small caches; neutral commons, uncommons and rares for ordinary guarded sites; all 22 epics for the heaviest ones, where a hero is offered its own faction's epic and the 16 neutral ones; one faction rare for each of the faction services.

## Saved games

A save made before the switch loses its old artifacts: what its heroes wear and carry, and the pickups still on its map. Nothing is converted: loading drops every artifact the game no longer has (`normalize_hero_artifacts`, `build_artifact_nodes`).

## Build order

1. `artifact-bonus-rules-20261111`: one sum of bonuses for specialties and artifacts, Knowledge as a bonus, the home line, prices. It runs on today's artifacts, which use none of it.
2. `artifact-icons-20261111`: six trial icons, then the rest once the owner approves the quoted cost.
3. `artifact-catalogue-switch-20261111`: the 150 replace the 69 with their icons; the sets' steps; reward lists, sites and markets draw from the new catalogue; old saves drop old artifacts; the hero menu shows an artifact's band, price and home line and a set's progress; the computer players value the new kinds.
4. `artifact-special-effects-20261111`: the 32 special effects.

All four are done.

Measuring balance with a batch of games waits for the owner's ask.

## Content and tools

- `tools/artifact_catalogue.py` is the one copy of the artifacts and sets; the content tool adds the special effects' ids. Change it, then run `python tools/build_artifact_content.py` (writes `content/artifacts.json` and the map's pickup sprites; `--check` fails when they differ) and re-export `docs/artifact-system-catalogue.md`.
- A row's `effect_text` and `ui.effect_lines`, `ui.price_lines` and `ui.home_lines` are the wording the game shows: `ArtifactRules.artifact_effect_summary` returns `effect_text`, the hero menu reads the lines.
- `tools/build_artifact_icons.py` writes the icon sheets' prompts and cuts the sheets.
- The computer players weigh the new kinds by `loadout_values` in `content/ai_hero_weights.json`, on the sum `artifact_rules::worn_specialty_bonuses` gives.
- An artifact's description is the line that says what the object is; stories are not written.
- The 69 old artifacts' icons and map sprites are removed (git history keeps them); a pickup's sprite is its artifact's icon.

## Not in the plan

Repeats on a map and what a second copy gives (decision 9), artifact merchants and their prices, artifacts a hero starts with.
