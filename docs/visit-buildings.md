# Visit buildings

Owner direction 2026-10-06: visit buildings were the largest gap against HoMM3. Every HoMM3 visit building on a random map became one of 35 sites picked by chance, and the field services sold experience for gold. This slice gives each HoMM3 visit role an original building, maps random maps by meaning, and turns the old services and shrines into visit buildings.

Owner decisions taken with the plan:

- Phase 1 (hero growth) and Phase 2 (field boosts and map services) are built. Tavern, Prison and Den of Thieves were implemented on 2026-10-26 (below); the remaining Phase 3 systems need their own designs.
- Momentum stands in for luck. The game has no luck stat, so HoMM3 luck buildings grant momentum.
- Paid experience is retired. No site sells experience.

Plan id: `content-visit-buildings-20261006`.

## Rules

A visit building is a resource site with family `visit_building` and a `visit` block. Rules live in the native `visit_building_rules_*.cpp` and `overworld_rules_site_effects.cpp` ports; the GDScript entry points are thin wrappers. The building is never captured and has no owner; it remembers who visited.

| Cadence | Meaning |
| --- | --- |
| `once_per_hero` | Each hero may visit once. |
| `once_per_side` | Each player (the human side or a computer faction) may use it once; what it reveals stays revealed. |
| `daily_per_hero` | Each hero may visit once per day. |
| `weekly_per_hero` | Each hero may visit once per week (days 1-7, 8-14, ...). |
| `weekly_site` | The first hero each week uses it; the rest wait for the next week. |
| `always` | No limit (the Wayside Exchange). |

The node stores `hero_visits` (`{hero_id or "ai:<faction>": day}`), `side_visits` (`{"player:<id>" or "ai:<faction>": day}`) and `site_last_visit_day`. A computer faction's commanders share one key per faction.

Effects (`visit.effects`, or the picked entry of `visit.choices`):

| Effect | Behaviour |
| --- | --- |
| `stats` | Adds attack, defense, power or knowledge permanently. |
| `experience`, `levels` | Grants experience, or the experience to reach the next level. |
| `spell_tier` | Teaches the site's spell (`learn_spell_id`, or the per-placement spell on random maps). |
| `mana: "refill"` | Refills mana to the maximum. |
| `mana: "week_double"` | Adds the hero's maximum mana again for the rest of the week and refills. It does not stack. |
| `movement` | Adds movement for today. |
| `week_movement` | Adds movement to every day of the current week. |
| `battle_boosts` | Adds cohesion or momentum to the hero's army at the start of its next battle (each capped at 3 per hero). |
| `day7_battle_boosts` | Extra battle boosts when visited on the seventh day of a week. |
| `reveal_radius`, `reveal: "level"` | Reveals a radius, or the whole map level. |
| `resources` | Market trades of the Wayside Exchange. |

`visit.cost` (or a choice's `cost`) is paid from the player's treasury. `visit.required_level` blocks lower-level heroes. Week bonuses live on the hero in `week_bonuses` and clear when a new week starts; battle boosts live in `battle_boosts` and are consumed by `BattleRules.create_battle_payload`.

Random maps can override a placement's `visit` block through `payload_visit` (`ResourceNodePayloadRules.gd`): an Elder Graft Tree rolls free, 2,000 gold or 10 of a rare; a Fountain of Fortune rolls +1 to +3 momentum; spell shrines roll a spell of their tier.

Computer players visit stat, experience, level and spell buildings with their commanders when the faction may still use them (`EnemyAdventureRules._visit_building_by_raid`). Their target value is `VisitBuildingRules.ai_value`. The Wayside Exchange and mana or movement buildings are left to the human player for now.

## Buildings

| HoMM3 role | Our building | Effect | Cadence |
| --- | --- | --- | --- |
| Mercenary Camp | Bell Spire | +1 attack | once per hero |
| Marletto Tower | Drum Cairn | +1 defense | once per hero |
| Star Axis | Clamp Forge | +1 power | once per hero |
| Garden of Revelation | Facet Orrery | +1 knowledge | once per hero |
| Arena | Proving Rostrum | choose +2 attack or +2 defense | once per hero |
| School of War | War College | 1,000 gold, choose +1 attack or +1 defense | once per hero |
| School of Magic | Arcane Collegium | 1,000 gold, choose +1 power or +1 knowledge | once per hero |
| Learning Stone | Lorestone | +1,000 experience | once per hero |
| Tree of Knowledge | Elder Graft Tree | +1 level (random maps may charge 2,000 gold or 10 of a rare) | once per hero |
| Library of Enlightenment | Grand Archive | +2 to every stat, hero level 10 or higher | once per hero |
| Shrines of Magic | Oath Ember, Reedscript Vow, Prism Measure shrines | a spell of tier 1, 2 or 3 | once per hero |
| Magic Well | Ley Well | refill mana | daily per hero |
| Magic Spring | Moonspring | double maximum mana for the week | weekly, first visitor |
| Stables | Remount Stable | +3 movement every day this week | weekly per hero |
| Fountain of Youth, Oasis, Watering Hole | Wayside Rest, Cookfire Rest | +4 movement today, +1 cohesion next battle | weekly per hero |
| Temple | Wayside Chapel | +1 cohesion next battle, +2 on day 7 | weekly per hero |
| Rally Flag | Muster Banner | +2 movement, +1 cohesion and +1 momentum next battle | weekly per hero |
| Buoy | Tide Bell | +1 cohesion next battle | weekly per hero |
| Faerie Ring, Swan Pond, Fountain of Fortune, Idol of Fortune, Mermaid | Fortune Ring | +1 momentum next battle (+1 to +3 for Fountain of Fortune) | weekly per hero |
| Cartographer | Chartmaker | 1,000 gold to reveal the whole map level | once per player |
| Trading Post | Wayside Exchange | trade wood, ore and gold without a town | always |
| Eye of the Magi, Hut of the Magi | Lens Calibration Cart | reveal radius 12 | once per player |
| (no HoMM3 match; not placed on random maps) | Reedboat Supply Stand | +3 movement today | daily per hero |

The Bell Spire, Drum Cairn, Clamp Forge, Facet Orrery, Proving Rostrum, War College, Arcane Collegium, Lorestone, Elder Graft Tree and Grand Archive reuse existing original sprites; the Ley Well and Moonspring have new original sprites (`art/overworld/source/generated/resource_sites/visit_buildings_20261006/provenance.json`). The services and shrines keep their sprites.

The old services' gold-for-experience trades, town recovery and pressure relief, and the shrines' weekly experience are removed.

## Random maps

`src/gdextension/rules/core/port/generated_reward_rules.cpp` maps HoMM3 object types to these buildings by meaning (`kVisitSites`, `kSpellShrines`, `kAdventureServices`). Lighthouses, Redwood Observatories and Pillars of Fire become scouting structures, Signs and Ocean Bottles become signs, Obelisks become faction landmarks. Witch Huts, Universities and Scholars become a stat, experience or tier 1 spell building until skill teaching exists. Tavern, Prison and Den of Thieves have dedicated services below. Other eligible interactable types fall back to a stable pick among the generic visit buildings; dedicated field services do not enter that fallback pool.

## Remaining Phase 3 systems

These need their own designs before any work:

- Field creature upgrades and trades: Hill Fort, Black Market, War Machine Factory, Freelancer's Guild.
- Skill teaching: Witch Hut, University, Scholar. The game has specialties instead of secondary skills.
- Quests and special sites: Seer's Hut, Sanctuary, Altar of Sacrifice, Sirens.


## Field recruitment, rescue and intelligence (2026-10-26)

The owner selected Tavern, Prison and Den of Thieves for live implementation.
Their native rules are `adventure_services.cpp`, shared by human visits and AI
adventure actions. These three source types now have dedicated mappings, outside
of the generic fallback pool. The generator's placements and masks are unchanged.
Previously saved fallback placements keep their original site identities.

- **Wayfarer Lodge (Tavern 95):** hires from the same weekly roster as town
  taverns at the same content-defined price and starting level/army. No town hall
  is required. Hiring spends that roster slot until the next weekly draw.
- **Captive Stockade (Prison 62):** one successful rescue for the entire
  placement, free. It grants one currently available commander of the visiting
  faction, at level one with a starting army. Selection is deterministic against
  placement/player identity and the available roster; it reworks the original
  map-configured prisoner. Failed attempts do not spend the rescue.
- **Whisper Exchange (Den of Thieves 97):** a free kingdom report ranks current
  field armies and garrisons, showing towns, mines, commanders, creature totals
  and gold. It reveals town anchors and entrances on their actual levels. The
  report is a dated snapshot; revisit to refresh it. AI players acquire the same
  map knowledge and refresh at most weekly. Public reports show ranks, not raw
  internal army-power scores.

Both paid and free recruitment enforce the existing four-command cap, globally
unique live roster heroes, current funds and safe adjacent land spawning on the
site's level. Human heroes and AI commanders use their existing native creation
and progression builders. Visiting never changes ownership of these buildings.
Node rescue/visit/report state and AI intelligence locations use the ordinary
session save payload. Existing original sprites are reused for all three sites.
