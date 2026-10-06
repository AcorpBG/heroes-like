# Pickups and Income Sites

Owner direction, 2026-10-05: streamline map economy objects to the HoMM model. Plan id: `content-homm-pickups-income-20261006`.

## Rules

- Only mines pay daily income: Sawmill 2 wood, Ore Mine 2 ore, Gold Mine 1,000 gold, each rare mine 1 of its resource. The scenario-only multi-resource mines (Orevein Assay Depot, Bellwake Wreck Ledger, Frontier Rare Exchange) and the authored AI helper (Generated Town Supply Cache) keep their income.
- Capturing or recapturing a site pays nothing beyond ownership. Neutral dwellings, faction landmarks, watchtowers and faction outposts pay no capture bonus and no daily income; they keep recruits, vision, response orders and town support.
- A site that stays on the map pays its own claim payload (vault loot, shrine experience, dwelling troops) once per placement. Recapturing it never pays again (`ResourceNodePayloadRules.CLAIM_PAYLOAD_SPENT`).
- The six small producers are weekly visit sites, free, usable again 7 days after the last visit: Charter Countinghouse 1,000 gold, Tide Kiln 500 gold, Orchard Levy Post 500 gold, Wind Press 4 of a rare (3-6 of a rolled rare on random maps), Saw Chain 5 wood, Smelter Annex 5 ore.
- Wood Wagon and Ore Crates are plain one-time pickups and are never placed by the random map generator.

## Random maps

The native H3MapEd port places HoMM3 object types unchanged. `scripts/persistence/GeneratedRewardRules.gd` then turns reward and economy types into original sites with HoMM-style payloads. Every roll is a stable hash of the placement id: no native RNG, placement, mask or link changes.

| HoMM3 object | Becomes | Payload |
| --- | --- | --- |
| Resource: wood, ore, gold | Split Wood Pile, Quarry Chip Hod, Road Writ Purse | 5-10 wood or ore, 500-1,000 gold |
| Resource: mercury, sulfur, crystal, gems | One of the six rare piles | 3-6 of that rare |
| Random Resource | One of the piles above, HoMM odds | as above |
| Treasure Chest | Waystone Cache | choose 1,000 gold or 500 XP, 1,500 or 1,000, or 2,000 or 1,500 |
| Campfire | Wayfarer Camp Cache | 400-600 gold plus 4-6 of one resource |
| Lean-To, Wagon | The pile of a rolled resource | 1-5 and 2-5 |
| Flotsam | Millroad Plank Stack | 5 wood, 5 wood + 200 gold, or 10 wood + 500 gold |
| Sea Chest | Road Writ Purse | 1,500 gold |
| Spell Scroll | Spell Scroll | one spell: tier 1 40%, 2 30%, 3 20%, 4 10% |
| Mine: wood, ore, gold | Sawmill, Ore Mine, Gold Mine | daily income |
| Mine: mercury, sulfur, crystal, gems; Abandoned Mine | One of the six rare mines (Abandoned Mine: any mine) | daily income |
| Water Wheel | Charter Countinghouse or Tide Kiln | weekly gold |
| Windmill | Wind Press, Saw Chain or Smelter Annex | weekly resources |
| Mystical Garden | Orchard Levy Post | weekly gold |

Pool changes in `content/random_map_object_eligibility.json`: Swan Pond, Faerie Ring, both Fountains, Magic Spring, Mermaid, Oasis and Watering Hole become visit sites instead of resource pickups; Corpse and Shipwreck Survivor give an uncommon artifact; Derelict Ship and Shipwreck are guarded reward sites; Water Wheel, Windmill and Mystical Garden use the weekly-producer pool, and the producers are kept out of the general visit-site pool.

Verdant Graft Bundle and Brass Scrip Case are new rare piles with original sprites (`art/overworld/source/generated/pickups/rare_piles_20261005/provenance.json`), so all six rares appear on random maps.
