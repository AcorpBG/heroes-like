# Creature Banks And Other HoMM3 Guarded Objects

Owner direction, 2026-10-09:
- A HoMM3 creature bank on a random map keeps its levels, pays its HoMM3 reward and is guarded as strongly as the HoMM3 bank.
- This covers every HoMM3 guarded object, not only the Crypt.
- Our units are weaker than HoMM3's, so guards and the creatures a bank grants convert by battle power, not by headcount.

Plan ids: `content-creature-bank-levels-20261009` (the Crypt) and `content-homm3-guarded-objects-20261009` (every other bank, Pandora's Box and the Warrior's Tomb).

HoMM3 numbers come from `CRBANKS.TXT` and `CRTRAITS.TXT` in the local install's `H3bitmap.lod`.

## Rules

- **Placement.** The native H3MapEd port places each object unchanged. `scripts/persistence/GeneratedRewardRules.gd` turns it into one fixed original site (`CREATURE_BANKS`, keyed `type:subtype` or `type`).
- **Level.** Each placement rolls one level at HoMM3's odds. Every roll is a stable hash of the placement id, so no native RNG, placement, mask or link changes.
- **Reward.** The claim pays that level's HoMM3 reward and nothing of the site's own rewards, recruits, spell, scouting or experience. It is one-time, and no faction holds the site afterwards.
  - Gold, wood and ore are paid as is.
  - HoMM3's mercury, sulfur, crystal and gems become four distinct rares of our six, in an order shuffled per placement.
  - Creatures join as our units with the same battle power.
  - Each HoMM3 artifact class draws one artifact the hero lacks (see Artifact classes).
- **Battle power.** A HoMM3 stack is worth creature AI value × headcount × `power_per_native_value` (0.06, `content/generated_neutral_companies.json`), as generated neutral guards are sized. `GeneratedNeutralEncounterRules.stacks_for_native_budget` pools the power of a unit's stacks, makes it whole creatures of that unit (`AiHeroRules.army_power`, at least one), then shares them out by budget. Each unit lands within half a creature of its budget.
- **Guard.** The guard stands on the site's entrance and must be beaten before the claim.
  - A single-creature guard stands in five stacks.
  - Where the creature has an upgrade, half the placements field one of the five upgraded, which adds its larger budget.
  - The guard shows its strongest unit in its overworld idle pose (`with_lead_unit_art`).
  - Winning pays the usual strength-based battle reward.
- **Session state.** The per-placement payload and the guard army live in the session (`ResourceNodePayloadRules`). Authored placements of the same sites keep the site definition.
- **Random stand-ins.** The Wyrmcrown Hoard and Hushlock Casket stand only for their HoMM3 objects. The random guarded-reward and pickup pools exclude them (`homm3_translation_meaning_placement` in `content/random_map_object_eligibility.json`).

## Artifact classes

`ArtifactRules.H3M_ARTIFACT_CLASS_RARITIES` maps each HoMM3 class to our rarities:

| HoMM3 class | Our rarity |
| --- | --- |
| Treasure | common or uncommon |
| Minor | uncommon |
| Major | rare |
| Relic | epic, then rare once the hero holds every epic |

A level that holds several classes draws distinct artifacts (`select_live_source_rewards`). Saves made with the earlier Crypt payload keep their single rarity (`payload_artifact_rarity`).

## Banks

Power is `AiHeroRules.army_power` of the guard, for levels 1 to 4. Rares are counts of our rares.

| HoMM3 object | Site | Guard as | Guard power | Reward by level |
| --- | --- | --- | --- | --- |
| Cyclops Stockpile (16:0) | Brasswake Depot | Gaugecoil Orewyrms | 1,532 / 2,298 / 3,141 / 3,907 | 4 / 6 / 8 / 10 wood, ore and four rares |
| Dwarven Treasury (16:1) | Barrow Vault | Kilnward Mallets | 412 / 623 / 825 / 1,371 | 2,500 / 4,000 / 5,000 / 7,500 gold + 2 / 3 / 5 / 10 of a rare |
| Griffin Conservatory (16:2) | Glassbound Eyrie | Cliffhawk Wardens | 1,052 / 2,225 / 3,337 / 4,208 | 5 / 10 / 16 / 21 Noonshard Prism Kites (HoMM3: 1–4 Angels) |
| Imp Cache (16:3) | Furnace Vault | Charcoal Mauls | 313 / 470 / 627 / 903 | 1,000 / 1,500 / 2,000 / 3,000 gold + 2 / 3 / 4 / 6 of a rare |
| Medusa Stores (16:4) | Drowned Reliquary | Mireglass Belltoads | 631 / 962 / 1,232 / 1,593 | 2,000 / 3,000 / 4,000 / 5,000 gold + 5 / 6 / 8 / 10 of a rare |
| Naga Bank (16:5) | Amber Reliquary | Fenmirror Gallowshells | 1,308 / 1,961 / 2,615 / 3,923 | 4,000 / 6,000 / 8,000 / 12,000 gold + 8 / 12 / 16 / 24 of a rare |
| Dragon Fly Hive (16:6) | Hive of Reeds | Bogbell Mauls | 566 / 844 / 1,122 / 1,688 | 6 / 9 / 11 / 17 Miremoon Crownmaws (HoMM3: 4–12 Wyverns) |
| Derelict Ship (24) | Storm Bell Wreck | Tideglass Skyrays | 357 / 562 / 766 / 1,123 | 3,000 / 3,000 / 4,000 / 6,000 gold; treasure on 2–3, minor on 4 |
| Dragon Utopia (25) | Wyrmcrown Hoard (new art) | Rootvault Barkhulks, Deepforge Vaultwyrms, Quenchbell Ironbacks, Gloambell Wake-Mantas | 5,285 / 6,591 / 7,629 / 10,066 | 20,000 / 30,000 / 40,000 / 50,000 gold + 4 artifacts (see below) |
| Pyramid (63) | Mirror Archive | Basalt Wardens, Sumpstone Guards | 2,373 (one level) | one tier-5 spell |
| Crypt (84) | Prism Ossuary | Veilmourn's Knellwake Wardens, Gravetide Anchors, Lastlight Keepers, Duskpass Revenants | 225 / 293 / 507 / 662 | 1,500 / 2,000 / 2,500 / 5,000 gold; treasure on 3–4 |
| Shipwreck (85) | Wreck Locker | Tidepool Cutters | 153 / 225 / 378 / 755 | 2,000 / 3,000 / 4,000 / 5,000 gold; treasure on 3, minor on 4 |

Notes on the table:
- **Odds.** Every bank but the Pyramid rolls its levels 30/30/30/10%.
- **Dragon Utopia artifacts.** By level, from CRBANKS: treasure, minor, major, relic; then minor, major, relic, relic; then major and three relics; then four relics.
- **Pyramid.** It guards 40 Gold Golems and 20 Diamond Golems, as HoMM3's does.
- **Glassbound Eyrie.** It translated the Crypt in the first change. It now stands for the Griffin Conservatory, whose griffins it matches, and the Crypt moved to the Prism Ossuary.
- **One-time sites.** The Dwarven Treasury and Naga Bank use one-time sites, because the Slag Purse Vault and Lantern Crown Nave are held by a faction for town support.

## Pandora's Box → Hushlock Casket

The native generator already rolls each box's contents. `h3maped_rmg_core.cpp` decodes them from the box's object record, and `map_package_service.cpp` exports them as `h3m_pandora_contents`: experience, the seven resources, spells with their level and school mask, and creatures with their level and AI value.

The box becomes a one-time Hushlock Casket pickup (new art):
- **Experience.** It is worth the same hero level, counted from level 1 and rounded to 50: 5,000 → 2,100, 10,000 → 4,450, 15,000 → 6,800, 20,000 → 9,000.
- **Resources.** As for banks.
- **Spells.** The casket teaches every spell of the box's levels. When the box held one HoMM3 school, it teaches only one of our seven schools, rolled per placement.
- **Creatures.** They join as a neutral unit of the creature's tier with the same battle power.
- **Guard.** It fights no guard of its own. The native guard beside it stays.
- **Older packages.** A package from before the contents were exported pays HoMM3's smallest gold box, 5,000 gold.

## Warrior's Tomb → Basalt Oath Tomb

One artifact of a class rolled 30/50/15/5% (treasure, minor, major, relic), and nothing else. It fights no guard of its own.

## Computer heroes

- A computer hero's claim gains every artifact the site holds, every spell it teaches and its experience.
- The AI values a guarded site's troops and artifacts as well as its resources.
- A hero comes home to a threatened town only when it can beat the threat or is the main or a field army that holds the gate. A lesser hero too weak for the threat no longer walks in each morning and out again.

## Not carried over

- HoMM3's −1 morale for visiting a looted Crypt or robbing a Warrior's Tomb.
- The Altar of Sacrifice (type 2) still becomes a random guarded site.
- The common artifact pool holds only 2 artifacts, so treasure draws are mostly uncommon.

Validation: `tests/creature_banks_report.tscn`.
