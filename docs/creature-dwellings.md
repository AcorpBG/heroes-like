# Creature dwellings

Owner direction 2026-10-06: rework adventure-map creature dwellings to the HoMM3 model, all phases. Plan id: `content-creature-dwellings-20261006`.

Before the rework, capturing a dwelling dropped a free batch of 2 to 8 troops into the hero's army once. After that it sent about one creature a week to the nearest town, however far away. Nobody hired at a dwelling, no guard was ever created from the dwelling data, and random maps picked any of 69 dwellings at random.

## Rules

Rules live in `scripts/core/CreatureDwellingRules.gd`. Overworld, battle and AI hooks are in `OverworldRules.gd`, `BattleRules.gd` and `EnemyAdventureRules.gd`.

- **One creature, one week.** A dwelling (family `neutral_dwelling`) makes one base creature. `weekly_recruits` holds that creature at its town growth: tier 1 6-8, tier 2 4-5, tier 3 3-4, tier 4 2-3, tier 5 1-2, tiers 6 and 7 one.
- **Weekly reset.** The population resets at the start of every week. Unhired creatures do not carry over, as in HoMM3 Shadow of Death. The node stores `dwelling_population` and `dwelling_week`.
- **Hire at the dwelling.** A hero visiting a dwelling flags it. Visiting your own dwelling opens the hire window (`OverworldShell._open_dwelling_recruit_dialog`), which has a count and a Max button per creature. Hiring goes through `OverworldRules.hire_from_dwelling`.
- **Prices.** Creatures cost their town price, except tier 1, which is free. Hired creatures join the visiting hero's army.
- **No capture batch.** Flagging a dwelling grants no troops, resources or income. The old town feed, the +12% logistics growth bonus, "Dispatch Relief" response orders, dwelling pressure and the capital's dwelling requirement are gone.
- **Town growth.** Each flagged dwelling adds +1 weekly growth for its creature in every town of the same owner that recruits it (`OverworldRules._add_dwelling_town_growth`). Veterans share their base creature's bonus; neutral creatures have no town dwelling to grow.
- **Guards.** Tier 5+ dwellings are guarded by three weeks of their own unupgraded creature: 3-6 at tier 5, 3 at tiers 6 and 7. Visiting starts a battle against them; the battle is keyed `dwelling_guard:<placement>` and uses the `encounter_dwelling_guard` content encounter.
  - Win, and the guard is beaten for your side for good and the dwelling flies your flag.
  - Lose or retreat, and only the survivors hold it against you until the full guard returns at the start of the next week.
- **Guards per side.** This is the owner's rule; in HoMM3 a flagged dwelling can be re-flagged by visiting. Each side, the human player or a computer faction, must beat a dwelling's guard once. A side that has beaten it never fights it again, but every other side still has to win its own fight. The node keeps `dwelling_guard_beaten` and `dwelling_guard_survivors` per side.
- **AI.**
  - A computer commander must out-muster 90% of the guard to break it, the same test as its other neutral fights.
  - It then flags the dwelling and hires as much of the week as it can pay for and carry, strongest creatures first.
  - It returns to its own dwellings when the week's creatures are worth at least 300 gold.
  - Route grabs never fight a dwelling guard.

## Content

| What | Count |
| --- | --- |
| Dwellings | 95 |
| Single-creature dwellings | 92 |
| Multi-creature dwellings | 2: Three-Gauge Chapter Foundry (the Golem Factory) and Five-Bough Veteran Grove (the Elemental Conflux) |
| Drifters' Camp (Refugee Camp) | 1: a different base creature each week from all neutral and town creatures, at the usual price, never guarded |

The 30 old multi-creature sites keep one creature each. Neutral sites keep the high-tier creature they are named after; faction sites keep the faction tier no other dwelling covers.

23 new faction dwellings with original sprites give every faction at least one dwelling per tier: Scrip Hauler Tally Barn, Exactor Debt Works, Crucible Crawler Pit, Lantern Sapper Lodge, Bargebow Slipway, Writcaster Lockhouse, Beacon Lectory, Reedsnare Warren, Mudglass Sling Pits, Bogplate Wallow, Fenbell Stalking Ground, Drowned Antler Throne, Shard Warden Bastide, Prism Adept Cloister, Mirror Duelist Salle, Zenith Lens Gallery, Aurora Bastion Yard, Stag-Knot Thicket, Bellwake Oar Shed, Maskglass Corsair Den, Undertow Harpoon Jetty, Obituary Scriptorium and Mirror-Keel Drydock. The Drifters' Camp also has a new sprite. Riverwatch Free Company Yard gained a map object using its existing sprite. Provenance: `art/overworld/source/generated/resource_sites/creature_dwellings_20261006/provenance.json`.

## Random maps

`scripts/persistence/GeneratedRewardRules.gd` translates HoMM3 dwellings after generation; the native generator is unchanged.

| HoMM3 object | Becomes |
| --- | --- |
| Creature Generator 1 (type 17), 80 subtypes | A dwelling of the same creature level (`H3M_DWELLING_LEVEL`). Town creatures use the faction of the nearest town when that faction has one; otherwise, and for the 13 neutral subtypes, a neutral dwelling of that tier. |
| Elemental Conflux, Golem Factory (type 20) | The two multi-creature dwellings |
| Refugee Camp (type 78) | Drifters' Camp |
| Random dwelling (216), random dwelling by faction (218) | A rolled tier (25/20/18/15/10/7/5% for tiers 1-7), faction from the nearest town |
| Random dwelling by level (217) | That level, faction from the nearest town |

## Not changed

Authored scenarios still reference their dwellings, but they are obsolete (`docs/authored-scenarios-obsolete.md`); their placement checks were not chased.
