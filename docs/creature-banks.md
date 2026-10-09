# Creature Banks

Owner direction, 2026-10-09: a HoMM3 creature bank on a random map keeps its levels. It pays gold plus a random artifact where its level holds one, and it is guarded as strongly as the HoMM3 bank. Plan id: `content-creature-bank-levels-20261009`.

## Rules

- The native H3MapEd port places the bank unchanged. `scripts/persistence/GeneratedRewardRules.gd` (`CREATURE_BANKS`) turns it into its original site and rolls one level per placement at HoMM3's odds. The roll is a stable hash of the placement id, so no native RNG, placement, mask or link changes.
- The claim pays that level's gold. On a level that holds an artifact it also draws one random artifact of the HoMM3 class. The draw uses the rarity the random map gives that class (`artifact_rarities_by_source_type` in `content/random_map_object_eligibility.json`) and takes any artifact of that rarity the hero does not hold. There are no resources, experience, troops or scouting, and the claim is one-time.
- The guard fights as the site's own units. Each HoMM3 guard stack becomes its paired unit with the battle power of its native budget: creature AI value × headcount × `power_per_native_value` (0.06, `content/generated_neutral_companies.json`), as generated neutral guards are sized. The guard stands on the site's entrance and must be beaten before the claim. Winning pays the usual strength-based battle reward.
- The per-placement payload (`ResourceNodePayloadRules`: gold, no recruits, no scouting, artifact rarity) and the guard army live in the session. Authored placements of the same sites, and saves made before this change, keep the site definition.

## Crypt → Glassbound Eyrie

HoMM3 data is from `CRBANKS.TXT` and `CRTRAITS.TXT` (Skeleton AI value 60, Walking Dead 98, Wight 252, Vampire 555). Treasure artifacts map to the `common` rarity.

| Level | Chance | HoMM3 guard | Eyrie guard | Power | Reward |
| --- | --- | --- | --- | --- | --- |
| 1 | 30% | 30 Skeletons, 20 Walking Dead | 13 Kitehook Runners, 14 Cliffhawk Wardens | 225 | 1,500 gold |
| 2 | 30% | 25 Skeletons, 20 Walking Dead, 5 Wights | 11 Runners, 14 Wardens, 12 Windglass Slingers | 287 | 2,000 gold |
| 3 | 30% | 20 Skeletons, 20 Walking Dead, 10 Wights, 5 Vampires | 9 Runners, 14 Wardens, 23 Slingers, 4 Galehorn Striders | 508 | 2,500 gold + 1 common artifact |
| 4 | 10% | 20 Skeletons, 20 Walking Dead, 10 Wights, 10 Vampires | 9 Runners, 14 Wardens, 23 Slingers, 8 Galehorn Striders | 672 | 5,000 gold + 1 common artifact |

Power is `AiHeroRules.army_power` without the Roost Captain's +1 attack and defense. Before this change every generated Crypt paid the authored Eyrie's 860 gold, 3 ore, 310 experience, 2 Cliffhawk Wardens, 1 Windglass Slinger, its faction's epic relic and a radius-6 survey, and was guarded by 7 Wardens and 3 Slingers (power 80).

The common pool holds only Trailsinger Boots and Quarry Tally Rod, so a hero holding both draws nothing.

Not carried over: HoMM3's −1 morale for visiting an already looted Crypt.

Other creature banks (Creature Bank subtypes, Derelict Ship, Shipwreck, Dragon Utopia, Pyramid, Warrior's Tomb) still become a random guarded reward site with its authored payload and guard. Each needs its own row in `CREATURE_BANKS`.

Validation: `tests/creature_banks_report.tscn`.
