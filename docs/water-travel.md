# Water travel and transit objects

Slice: `feature-water-travel-20261007` (owner direction, 2026-10-07).

A playtest found an "Ash Sluice Lock" standing in open grass by the sea, marked as a transit object, with nothing to do. It was a HoMM3 Shipyard. Random maps had no rule for any HoMM3 transit object, so thirteen object types (boat, shipyard, whirlpool, border guard, border gate, keymaster's tent, garrisons, quest guard, monoliths, subterranean gate) all fell into one pool of 27 transit objects picked by position. The owner chose to build water travel and to turn passage blockers into pay-to-open gates.

## Rules

`scripts/core/WaterTravelRules.gd` owns boats; `OverworldRules` applies them to the active hero's routes.

- **Boats** sit on water tiles (`overworld.boats`: id, tile, level, the hero aboard). A sailing hero carries `boat_id`.
- **Boarding.** A walking hero may end a route on a free boat. Boarding ends the hero's movement for the day, as in HoMM3.
- **Sailing.** A sailing hero moves only on open water (1.5 points a tile since 2026-11-08; water is Veilmourn's home ground, at grass cost), may end a route on a water site (a sea pickup, a wreck, a tide bell, a whirlpool), and cannot pass another boat.
- **Going ashore.** A sailing hero may end a route on open shore or a shore site (a town entrance, a pickup). Stepping off ends the day's movement; the boat stays moored on the last water tile for anyone to take.
- **Shipyard.** A neutral visit building on the coast. Any visiting hero may build a boat for 1,000 gold and 10 wood (the HoMM3 price). The boat appears on the dock: the open water tile next to the visit tile, or next to the body, nearest the visit tile. A full dock refuses before anything is paid.
- **Town shipyard** (owner decision, 2026-11-09). A town has a harbour when open sea lies within 6 steps of its gate: free water (nothing stands or acts on it) joined eight ways into a body of at least 20 tiles, reached on foot around buildings and scenery; guards do not count. Each town's harbour is searched once, when the game starts or an older save loads, and kept on the town (`harbor`: the launch tile and the steps; empty when there is none; towns on a level without water carry no entry). A harbour town may build the Shipyard (`building_dev_shipyard`: 2,000 gold and 20 wood, needs the Town Hall); other towns never show it. A built Shipyard launches a boat on the harbour tile for the neutral shipyard's price (`boat_cost`, 1,000 gold and 10 wood) with or without a hero in town, and refuses while a boat or a hero already lies there. Both numbers are `kHarborReach` and `kSeaTiles` in `water_travel_rules_ai.cpp`. Veilmourn's towns are the exception (owner decision, 2026-11-10): every one with a harbour stands with the Shipyard built from the start, also in saves from before the rule, and launches boats at half price, 500 gold and 5 wood, for whoever holds the town (`harbor_building_ids` and `boat_cost_percent` on the town template in `content/towns.json`; `town_boat_cost`). The town paintings have no shipyard plot yet (the town art rework will add them): the built Shipyard opens from its slot on the construction board, and its "Build a boat" order is also listed among the town's services.
- **Whirlpool.** A water site three tiles wide and two deep, the six sea tiles HoMM3's whirlpool takes; one swirl is painted flat over all of them (the `lies_flat` tag of `object_whirlpool`) and a boat sails in on any of them (owner decision, 2026-11-11). Sailing into it throws the boat out on a free water tile beside another whirlpool on the same level, picked by a stable hash of the source, day and hero; the tile is one beside that whirlpool's first tile if any is free, else beside another of its tiles. The weakest stack (by total health) loses half its creatures, rounded down, never the army's last creature. A lone whirlpool spins the boat back where it entered.
- **Rendering.** Moored boats use `mapobj_water_boat`; a sailing hero shows as the same boat with the owner's flag at the masthead and the hero's command pennant. A computer player's hero aboard shows as the boat with its player's flag.
- **Computer players** sail under the same rules (`AiHeroRules._search`, `_cross_shore`, `_launch_boat`): they board free boats, buy boats at shipyards they stand at, sail and go ashore, and boarding or going ashore ends their day. `docs/ai-plays-by-player-rules.md` ("Water") has how they weigh it.

Saves keep `overworld.boats` and each hero's `boat_id`; normalization keeps them consistent (a boat follows the hero aboard; a hero whose boat is gone walks again).

## Random maps

`GeneratedRewardRules` (native, `generated_reward_rules.cpp`) translates HoMM3 transit and water objects by meaning:

| HoMM3 object | Becomes |
| --- | --- |
| Boat (8) | A boat waiting on its water tile |
| Shipyard (87) | Shipyard |
| Whirlpool (111) | Whirlpool |
| Border Guard (9), Border Gate (212), Garrisons (33, 219), Quest Guard (215) | A pay-to-open gate that suits the terrain under it (frost bar on snow, thorn seal or root lease in swamp, ash sluice on lava, brass toll or pressure rail underground and on rough ground, charter bar or toll chain on grass and dirt) |
| Keymaster's Tent (10) | Left off: gates open by payment, so no key is needed |
| Monoliths (43, 44, 45) | Wayring (two-way), Waygate (one-way entrance) and Wayfall (one-way exit), each network in its own colour; see `docs/portal-networks.md` |
| Subterranean Gate (103) | Keeps its native passage with the Basalt Undergate art |
| Flotsam (29), Sea Chest (82), Shipwreck Survivor (86) | Drift Wreckage, Sea Coffer, Castaway Raft: one-time pickups on the water |
| Shipwreck (85), Derelict Ship (24) | Wreck Locker and Storm-Bell Wreck, creature banks; their fights use the coast battlefield |
| Buoy (11) | Tide Bell |

Shipyards appear only where the source map had one. H3MapEd places nothing on the water itself; since 2026-11-09 generated maps add whirlpools, wrecks, buoys and pickups on open water that a shipyard serves, a deliberate departure (`docs/rmg-sea-content.md`). The random-map object table never uses shipyards or whirlpools as stand-ins for other HoMM3 sites: their `water_travel_live` status is excluded from the interactable pool (`water_travel_meaning_placement` in `content/random_map_object_eligibility.json`). Otherwise an inland service could become a shipyard with no water.

Gates now ask before they take payment: visiting one opens a prompt with the gate's story, the price and an Open button; leaving it keeps the passage closed. An opened gate stays open for everyone.

Saves from older random maps are migrated once on load (`overworld.generated_transit_translation_version`): boat sites become boats, shipyards and whirlpools get their sites, keymaster's tents disappear, unopened gates are re-picked for their terrain, opened gates stay open, and portals keep their passage with the new art (version 2 revisits portals only; `docs/portal-networks.md`).

## Content

- `site_shipyard` / `object_shipyard` (visit building, `mapobj_shipyard`), `site_whirlpool` / `object_whirlpool` (visit building on water, `mapobj_whirlpool`), and the boat sprite `mapobj_water_boat`.
- The three sprites are original image-generation art; prompts and references are in `art/overworld/source/generated/resource_sites/water_travel_20261007/provenance.json`.
- The sea pickups `site_drift_wreckage`, `site_sea_coffer` and `site_castaway_raft` (with `object_*` map objects and `mapobj_*` sprites; prompts in `art/overworld/source/generated/resource_sites/sea_content_20261109/provenance.json`).

## Not yet

- Computer heroes do not sail into whirlpools: its six tiles are blocked sea for them, never a site a boat could cross or rest on.
- Sea battles and sea movement bonuses (HoMM3 Navigation, sea artifacts) are not modelled.
- Town harbours are not launch tiles for the generator's sea content (`docs/rmg-sea-content.md`): a sea only a town harbour reaches stays empty.

## Validation

`tests/water_travel_report.tscn` widens a skirmish map, carves a lake and drives the real rules: translation of every transit type, the bridge's boats, the save migration, a shipyard visit that builds a boat and refuses a second, boarding (movement ends), a sailing save round-trip, the sailing route rules, a whirlpool throw with its troop loss, going ashore (movement ends, boat stays moored), a moored save round-trip, boarding again, the map drawing moored boats, and a gate that asks before taking payment.

Town shipyards (`feature-town-shipyards-20261109`) were checked without a report scene. On 48 generated water maps (small to extra large, normal water and islands, one and two levels, three seeds each) the stored harbours equal an independent script's walk of the same rule: 56 of 353 towns, a third of the islands towns, and no entry on a level without water. In the game, small islands seed 262531087 as Veilmourn: the start town's board offers the Shipyard in its Harbor column, it builds for 2,000 gold and 20 wood, opens from the slot, launches one boat for 1,000 gold and 10 wood on the harbour 4 steps from the gate, and refuses a second while that one waits. In ten islands games between computer players (five small with two players, five medium with three) three players built a Shipyard between days 8 and 15, after an army ran out of things to do on its start island, and two of them bought boats at the town's harbour and sailed; the third lacked the wood for a boat by day 28. Veilmourn's start (`feature-veilmourn-harbor-shipyards-20261110`): on small islands seed 262531087 all three Veilmourn towns stand with the Shipyard on day 1 and the player's sells a boat for 500 gold and 5 wood; in twelve short games between computer players the Veilmourn towns with a harbour start with it (12 of 20), no other town does, Veilmourn pays 500 at its towns and 1,000 at a neutral shipyard, and a player that takes a Veilmourn town pays 500 there. Since 2026-11-10 a computer player builds one only for its main army, weighed against its other builds, and never in the first week (`docs/ai-plays-by-player-rules.md`, "Water", with the paired batch that led to it).
