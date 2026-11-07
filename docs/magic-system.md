# Magic system

The owner reworked magic on 2026-11-06 and 2026-11-07, settling it draft by draft on a local plan page (`.artifacts/magic_atlas/magic_plan.html`, built by `.artifacts/magic_atlas/build/plan.py`; magic pages stay local views, never published). This doc holds the rules and the build order. The 139 spells and 138 mechanics are in `docs/magic-system-spells.md`. Nothing here is in the game yet: today's magic is still the one in `docs/magic-system-expansion-foundation.md` and `docs/battle-spell-effects.md`, which this doc replaces at the switch (`magic-switch-20261107`).

## Why

The owner found seven schools too many and today's spells bad: their review of 2026-10-09 said buffs were confusing and most spells "do the same thing". None of today's 119 spells is reused, by name, id or effect.

## The shape

- **Tiers.** Tier 1 holds 15 basic spells with no school and no mastery; every hero can learn them, and they grow with spell power only. The four schools start at tier 2 with 9 guild spells each, then 9 at tier 3, 6 at tier 4 and 3 at tier 5, so the top tier has the fewest. Each school also has one scroll-only spell at each of tiers 2 to 5. In all: 15 basic, 108 school guild spells and 16 scroll-only spells, 139.
- **Schools.** Four schools are shared by all factions. Each has a method that shows in every kind of spell it has:

| School | Words | Method | Best at | Weak |
|---|---|---|---|---|
| Furnace | fire, forge, pressure | Power now, paid for later: Heat that builds until it bursts, forged plates and brass constructs, strength with a price. | damage, boost, ward | Heals badly (its heals carry a cost) and controls only by force. |
| Root | growth, soil, grafts | Patience: what it binds holds tighter every turn, what it plants grows, what it grafts shares one life. | control, healing, field | Slow: little speed or turn order; its damage leans on stacks it has already bound. |
| Beacon | light, signal, crystal | Coordination: it decides who acts when, marks targets, bends beams through crystal, reflects and purifies. | boost, healing, ward | No summons and little lasting damage; it wins by timing, not attrition. |
| Veil | fog, mire, the dead | Attrition and deceit: it drains, curses and frightens, hides stacks in murk, sinks them in mire and raises the fallen. | damage, control, field | Protects by hiding and dodging, never by armour; heals only by taking. |

- **Kinds.** Seven: damage, control, boost, ward, healing, field (walls, hazards, fog, crystals, summoned and moved stacks) and map. Every school has spells of each. Each kind but map is the flavour of two schools; a flavour spell does about a third more for the same mana, and a school has 5 or 6 spells of each flavour kind and 2 or 3 of the others.
- **One job low, more at the top.** A basic spell does one plain thing. From tier 2 a spell does its one thing in its school's way; from tier 3 most spells add a second effect; the top tier reaches every stack or the whole battle.
- **The hero casts.** A spell is the hero's, not the acting stack's: a helpful spell can pick any of the hero's stacks and a harmful one any enemy stack; some pick hexes, a destroyed stack or the whole battle. Area spells can still hit the caster's own stacks (Cinder Spray and Fog Mind keep that price).

## Spell power and resistance

- Every spell grows with its caster's spell power: damage or healing, turns, hexes, shares or counts. The notation (`{a+bP}`, `{a+bE}`, `{a+P/d}`) is explained at the top of `docs/magic-system-spells.md`; damage and healing follow the bands there.
- A lasting effect gets one more turn per 4 spell power, with no limit (today's limit of 3 more turns goes). A summoned stack stays a number of rounds set the same way.
- The enemy hero's Knowledge is the resistance: against an enemy hero's stacks a spell's harmful numbers and turns work at the caster's spell power less all of that hero's Knowledge, never below 0. At power 8 against Knowledge 6 it works at power 2; against Knowledge as high as the power, only the flat part and the base turns are left. A neutral army's leader and a heroless town's captain are not heroes, so there only the creatures resist. Knowledge no longer gives a percentage of spell or control resistance; items and specialties keep theirs.
- Creatures keep their own resistances on top of Knowledge. General spell and control resistance stay; resistance to Furnace, Root, Beacon and Veil stays as it is; Lens resistance becomes Beacon (30 creatures), Mire becomes Veil (30) and the one Old Measure resistance (Galehorn Striders) becomes Beacon. No creature has both of a merged pair. Basic spells meet only general spell resistance.

## Masteries

Four school masteries replace the seven; basic spells have none. A mastery strengthens its school's spells as today: rank 1 +8% damage and healing; rank 2 +16% and 1 mana less; rank 3 +24%, 1 mana less and one more turn; rank 4 +32%, 2 mana less and one more turn. From mastery 2 or 3, 29 spells also reach the stacks next to the target or every stack, as their Mastery column says.

## Guilds and learning

When the map is made, every town draws its own guild: at each level, a third of that tier's guild spells. Two towns of one faction get different draws, and a captured town keeps its draw. It is a plain weighted draw, with no guarantee at any level.

| Guild level | Tier | Guild spells | Scroll-only, never drawn | Drawn per town |
|---|---|---|---|---|
| 1 | 1 | 15 basic | 0 | 5 |
| 2 | 2 | 36, 9 per school | 4 | 12 |
| 3 | 3 | 36, 9 per school | 4 | 12 |
| 4 | 4 | 24, 6 per school | 4 | 8 |
| 5 | 5 | 12, 3 per school | 4 | 4 |

A full guild offers 41 of the 123 guild spells. Each spell of the town faction's preferred school (`preferred_spell_school_id` in `factions.json`) is twice as likely to be drawn as any other. A town keeps its draw (`guild_spell_ids` in its state) through captures and saves; a save from before the draws draws on load, from the game's seed and the town's placement like a new game. Until the switch the draw runs on today's 119 spells and each faction's school today (Lens for Sunvault, Mire for Mireclaw), with the third rounded to the nearest spell: 12, 7, 9, 6 and 5 of 36, 22, 26, 19 and 16. The exact odds of a draw without replacement, as spells of one school per town:

| Weight | Level 2 (12 drawn) | Level 3 (12) | Level 4 (8) | Level 5 (4) | Levels 2 to 5 (36) | Level 5 has none of it |
|---|---|---|---|---|---|---|
| ×1, no preference | 3.0 | 3.0 | 2.0 | 1.0 | 9.0 | 25% |
| ×2, the owner's answer | 4.4 | 4.4 | 2.9 | 1.5 | 13.2 | 9% |

Learning stays free: a hero in an own town learns everything its guild offers up to the hero's level, and shrines and other map sites teach guild spells of their tier.

## Scrolls

- The 16 scroll-only spells never appear in a guild. About 1 scroll in 3 found on the map holds one.
- A scroll teaches nothing. A hero casts a scroll's spell, for mana as usual, only while the scroll is worn in one of its two trinket slots, like a charm, so a hero wears at most two, in place of charms. The scroll is not used up and can be handed to another hero like any item.
- Generated maps keep placing scrolls by tier as they do today.
- Each spell has one scroll item, which the content store adds to `artifacts.json` as it reads the file: `artifact_scroll_<spell id without spell_>`, a trinket of class `spell_scroll` naming its `spell_id`, with no bonus. Rarity follows the tier: 1 common, 2 uncommon, 3 rare, 4 and 5 epic. It shows the spell's icon.
- A scroll site (`site_spell_scroll`, `gives_spell_scrolls`) hands its scroll to the hero, worn at once when a trinket slot is free, else carried. A hero holds one copy of each scroll; a second copy of one it holds is lost. Shrines and Pandora-style sites still teach, and only guild spells.
- A spell marked `scroll_only` in `spells.json` never enters a guild draw, a shrine or a Pandora's lesson. Where a tier has both kinds, a map scroll holds a scroll-only spell 1 time in 3.
- Scrolls are found only as scroll sites: placed artifacts, merchants, the field market and the collection count leave scroll items out, so generated maps place the same artifacts as before.
- The spellbook lists a worn scroll's spell after the learned ones, in battle, on the map and on the hero sheet. Two heroes meeting teach each other only learned spells.
- Computer players walk to scrolls whose spell they lack, as they valued scroll sites before, and wear a scroll when it beats a charm: `loadout_scroll_spell_tier_value` (8 per tier of a spell they have not learned) in `content/ai_hero_weights.json`. Their battle and strength estimates count lent spells.

## Mana and casting limits

- One hero spell per side per round in battle, as a free action; one map spell per hero per day.
- The maximum stays 8 + 4 × Knowledge. A hero gets back a fifth of its maximum each day (rounded up) instead of all of it, and all of it on a day that starts in an own town with a guild. The Ley Well, the Moonspring and the Calibration Court work as today.

## Faction preference

No faction owns a school. Each prefers the school its spells, town library and creatures belong to today, moved to the four:

| Faction | Prefers | Today |
|---|---|---|
| Embercourt | Beacon | 24 of its heroes' 35 starting spells, 5 of 8 library spells; 25 of 27 creatures resist Beacon. Next best: Furnace. |
| Sunvault | Beacon | Its school, Lens, joins Beacon: 32 of 34 starting spells are Lens or Beacon. |
| Mireclaw | Veil | Its school, Mire, joins Veil: 23 of 35 starting spells. |
| Veilmourn | Veil | 19 of 33 starting spells are Veil or Mire. |
| Brasshollow | Furnace | 23 of 33 starting spells. |
| Thornwake | Root | 18 of 33 starting spells. |

The bonus, by the owner's answers:

- In the faction's towns each spell of that school is twice as likely to be drawn (the table above).
- The faction's heroes cast every spell of it, guild or scroll, in battle and on the map, at 1 more spell power.
- They start with mastery 1 in it, which takes one of the hero's 6 specialty slots like any mastery. Today all 66 heroes start with one specialty and none with a mastery, so a faction hero starts with two and chooses the other 4.
- A hero's faction is the one it belongs to, whoever hires it.

Together, a faction hero's preferred-school spell does about a fifth to a quarter more than another hero's at spell power 5. It does more against an enemy hero whose Knowledge is close to the caster's power, because the extra point is not resisted: about 37% more damage at power 8 against Knowledge 6.

## What changes

Counted from the content at d6d472702.

- **Content.**
  - `spells.json`: today's 119 spells go and the 139 come in, each with a new id.
  - `heroes.json`: 203 starting spells on 66 heroes get new picks, and each hero gains its faction's mastery. `encounters.json`: 250 starting spells on 116 neutral commanders get new picks.
  - `towns.json`: the 45 fixed library spells go; guild draws replace them. `factions.json`: each faction names its preferred school.
  - `resource_sites.json`: 72 taught spells on 36 sites move to tier picks. `random_map_generator_data_model.json` names 38 spell ids and `homm3_re_reward_object_proxy_catalog.json` names 1.
  - `hero_specialties.json`: seven school masteries become four. `units.json`: 61 creatures' school resistances move. `artifacts.json`: Trailsinger Boots and Choir Tuning Fork name a school.
  - `spell_icons.json` (119 icons; 51 entries on Lens, Mire or Old Measure), `battle_vfx_manifest.json` (97 spell cues), `audio_production_banks.json` (119 entries) and `animation_event_cues.json` follow the new spells.
  - Spell scrolls on the map and in rewards become worn items.
- **Native rules** (`src/gdextension/rules/core/port/`): `spell_rules*.cpp`, `spell_battle.cpp`, `spell_events.cpp`, `battle_ai_spell_choice.cpp`, `battle_ai_spell_scores.cpp`, `commander_payload.cpp`, `content_validate.cpp`, the day's mana in `day_economy.cpp`, guilds in the town rules, scrolls in `artifact_rules.cpp`, `generated_reward_rules.cpp` and `overworld_rules_site_rewards.cpp`, and the screens' data in `human_registry.cpp`. The 112 new battle mechanics include 25 new statuses; there are 14 new map mechanics. `SpellRules.gd` stays a thin wrapper.
- **Screens.** The spellbook (`SpellbookView.gd`), battle casting and target picking (`BattleShell.gd`, `BattleBoardView.gd`), the town guild (`TownShell.gd`, `TownBuildingPanelView.gd`), map casting (`OverworldShell.gd`), the hero sheet and exchange (worn scrolls, masteries). Spell texts show their numbers at the caster's power.
- **Computer players.** A battle value for every new mechanic and target choice among all stacks; map values for the map spells; wearing and fetching scrolls.
- **Art and sound.** An icon for each of the 139 spells (none of today's reused), battle effects and sounds for each, badges for the 25 new statuses; the four school sigils stay.
- **Saves.** Each learned spell in an old save becomes a new spell of the same tier and kind, from the school its school moves to; towns get their guild draws on load; heroes get their faction's mastery on load.
- **Tests and docs.** The core case `magic_spell_schema_report` and the content check's spell domains follow the new spells. At the switch this doc replaces `docs/magic-system-expansion-foundation.md` and `docs/battle-spell-effects.md`; `docs/shared-spellbook-and-town-learning.md`, `docs/spell-effect-variety.md`, `docs/spell-system-player-balance-audit.md` and `docs/magic-school-availability-strategic-influence-report.md` describe today's magic and are updated or archived with it.

## Build order

Each slice is in `PLAN.md` and `ops/progress.json`. Rule changes go into the native rules core, with one six-seed native check against main for battle and day changes and `battle_sim_cli` rebuilt after battle changes (`AGENTS.md`).

1. `magic-power-mana-20261107`: spell power against Knowledge, turns per 4 power and the slower mana, on today's spells first.
2. `magic-guild-draws-20261107`: each town draws its guild, weighted to the faction's preferred school; it runs on today's spells and home schools until the switch.
3. `magic-worn-scrolls-20261107`: scrolls become worn trinket items that lend their spell; scroll-only spells never enter guilds.
4. `magic-basic-tier-20261107`: the hero casts on any stack; the 12 basic battle spells and their mechanics.
5. `magic-tier2-spells-20261107`: the 36 tier-2 battle spells and the 36 new mechanics they need, and mastery shapes.
6. `magic-tier3-spells-20261107`: the 36 tier-3 battle spells and their 36 new mechanics.
7. `magic-tier45-spells-20261107`: the 39 tier-4 and tier-5 battle spells and their 36 new mechanics.
8. `magic-map-spells-20261107`: the 16 map spells of every tier and the 16 map mechanics.
9. `magic-art-audio-20261107`: icons, battle effects, sounds and status badges, before or with the switch.
10. `magic-switch-20261107`: today's spells go and the new ones go live, with the four schools, masteries, the preference's hero bonuses, moved resistances, new picks in content, save conversion, tests and docs.

Slices 1 to 3 change today's game and stay. Slices 4 to 8 add the new spells to `spells.json` marked unreleased: the content check, the battle simulator and the focused checks use them, while guilds, hero and commander starts, rewards and sites leave them out. The switch removes today's spells and that mark together. A spell enters content in the slice that brings the last mechanic it needs; the Mechanics column of the spells doc says which.

## Owner decisions

- 2026-11-06: four schools shared by all factions instead of seven; each faction prefers one, with a small bonus decided after the system; every kind of effect in every school, with each school's flavour kinds stronger.
- 2026-11-07, first draft: tier 1 is basic spells with no school; the top tier is smallest; the hero casts on any stack; each town draws a third of each tier for its guild, weighted to the faction's preferred school; none of today's spells is reused; higher tiers combine effects; some spells come only from scrolls.
- 2026-11-07, marks on the second draft: 139 spells as drafted, with field as a seventh kind and the flavours as they are; every spell grows with spell power, and the enemy hero's Knowledge is the resistance; mastery can widen a spell; summons last rounds set by spell power; scrolls are worn, never learned, and about 1 in 3 is scroll-only; much slower mana; Molten Deluge toned down; vision spells reveal more than a hero or town already does; a plain weighted guild draw; friendly fire stays.
- 2026-11-07, answers on the third draft: all of the enemy hero's Knowledge counts; one more turn per 4 spell power, no limit; creatures keep their school resistances on top of Knowledge; a fifth of the maximum mana back each day, all of it on a day that starts in an own town with a guild; scrolls are worn in a trinket slot.
- 2026-11-07, faction preference: the schools above; guild odds ×2; its heroes cast it at 1 more spell power and start with mastery 1 in it, in a specialty slot like any mastery.
