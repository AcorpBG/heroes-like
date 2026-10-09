# Hero specialties

Slice: `content-hero-specialty-catalog-20261008` (owner request, 2026-10-08: "4 ranks, and not 7 but a lot more specialities"; owner chose six specialties per hero and the proposed 35-specialty catalog).

## Catalog

`content/hero_specialties.json` holds the catalog (it replaced the seven-entry constant in `HeroProgressionRules.gd`). Each specialty has a group (adventure, command, magic), a command path it leans to (any, might, magic), four ranks I-IV with their own text and bonuses (each rank lists its total, not an increment), and an insignia cell.

| Group | Specialties |
|---|---|
| Adventure and economy (9, any path) | Wayfinder's Instinct, Border Warden's Watch, Ledgerkeeper's Oath, Prospector's Assay, Alchemist's Retort, Muster Captain's Call, Night March, Plunderer's Eye, Scholar's Patience |
| Command and battle (12, might) | Armsmaster's Temper, Drillmaster's Cadence, Vanguard Drill, Marksman's Eye, Shieldwall Oath, Retinue Drill, Counterstroke, Banner of Resolve, Fortune's Favour, Siegecraft, Field Surgeon, Hardened Ranks |
| Magic (14, magic) | Spellwright's Reserve, Arcane Focus, Sorcery, Lingering Weave, Ward of Refusal, Iron Will, Ley Channeler, and a mastery for each school: Beacon, Mire, Lens, Root, Furnace, Veil, Old Measure |

The seven original ids are kept, so saved heroes keep their specialties; their values were reworked for four ranks (for example Wayfinder +1 / +2 / +4 / +6 movement, Ledgerkeeper now gold only with wood and ore moved to Prospector). Changes from the proposal shown to the owner: Pathfinder's Stride became Night March (map movement costs 1 per tile on every ground, so cheaper rough ground would do nothing); Banner, Fortune and Lingering Weave got a gain at every rank; Alchemist gives the faction's second rare resource from rank II.

## Rules

- **Six different specialties per hero**, each up to rank IV (`max_specialties_per_hero`). Heroes from older saves that already hold more keep them and can only rank them up.
- **Offers**: each level-up still offers three. The first is an upgrade of a held specialty and the second a new one (while the hero has room), the third the next best. Candidates are ordered by a weighted draw seeded by the hero's growth seed and the level (`HeroProgressionRules._offer_order`), so saves and re-reads never change a choice. Weights: the hero's own focus specialties 4, specialties of its command path 2.5, others 1. In the focused test a might hero is offered command specialties 55% of the time, a magic hero magic ones 58%.
- **Computer commanders** pick their focus specialties first, then their path's, battle and magic over adventure ones, and ranking up over starting new (`EnemyAdventureRules._preferred_enemy_specialty_id`).
- **Experience**: Scholar's bonus applies to every earned award (`add_experience`); hires and other levels set directly (`advance_to_level`) are exact.

## Where each effect applies

| Effect | Code |
|---|---|
| Map movement, scouting, raid losses, recruit growth (tiers 1-6; T7 keeps the town's growth) and cost (rounded up), daily gold, wood, ore and rare resources, max mana, mana cost | existing hooks (`HeroCommandRules`, `OverworldRules`, `SpellRules`, `HeroProgressionRules.adjusted_mana_cost`); rare resources resolve to the hero's faction `town_resources` |
| Night March | `OverworldRules._refresh_all_player_heroes_for_new_day` stores `movement_carry` (unused movement up to the rank); `HeroCommandRules.movement_max_for_hero` adds it to that day |
| Plunderer's Eye | `OverworldRules.apply_reward_bonus` on won battles and site pickups (not explicit reward choices) |
| Melee, ranged, retaliation and siege damage; damage taken; defend bonus | `BattleDamageRules.hero_damage_multiplier` and the defend bonus in `BattleRules._damage_modifier` and the battle AI estimate |
| Starting cohesion, momentum, creature health | `BattleRules._apply_specialty_battle_starts` when a battle is created, for both sides |
| Field Surgeon, Ley Channeler | `_apply_victory_recovery` and `_apply_victory_mana` for the winner (player victory; enemy on a player defeat, retreat or surrender) |
| Spell power, spell damage, school potency and mana, spell durations | `SpellRules.spell_power`, `_battle_spell_damage`, `_battle_spell_recovery_amount`, `spell_duration_rounds` (buffs and debuffs separately) |
| Spell and control resistance | the hero battle payload (existing) |

Momentum a stack brings into a battle (Fortune's Favour, visit-building boosts) now lasts through round 1 and fades from round 2; before, it faded at the start of round 1.

Open: computer commanders' economy ignores specialty income (as it already did for Ledgerkeeper), so the AI weighs adventure specialties low; Night March and Plunderer reach only player heroes; fights the AI resolves among its own heroes do not run Field Surgeon or Ley Channeler.

## Insignia

35 icons in a 7x5 atlas of 28 px cells (`art/heroes/runtime/specialties/hero_specialty_insignia_atlas.png`). Row 1 keeps the seven originals; the 28 new ones were generated as two sheets in their style (sources and prompts in `art/heroes/source/generated/specialties/`, manifest v2) and packed by `tools/pack_hero_specialty_insignia.py` (`--check` verifies).

## Validation

`tests/hero_specialty_catalog_report.tscn` (152 checks): the catalog, rank texts and every insignia; Wayfinder by rank; the six-specialty limit and mastered specialties; offers (upgrade then new, seeded, path lean); a level-24 recruit's build; AI picks; each adventure, magic and battle effect, the battle ones on a generated small map.
