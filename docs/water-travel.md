# Water travel and transit objects

Slice: `feature-water-travel-20261007` (owner direction, 2026-10-07).

A playtest found an "Ash Sluice Lock" standing in open grass by the sea, marked as a transit object, with nothing to do. It was a HoMM3 Shipyard. Random maps had no rule for any HoMM3 transit object, so thirteen object types (boat, shipyard, whirlpool, border guard, border gate, keymaster's tent, garrisons, quest guard, monoliths, subterranean gate) all fell into one pool of 27 transit objects picked by position. The owner chose to build water travel and to turn passage blockers into pay-to-open gates.

## Rules

`scripts/core/WaterTravelRules.gd` owns boats; `OverworldRules` applies them to the active hero's routes.

- **Boats** sit on water tiles (`overworld.boats`: id, tile, level, the hero aboard). A sailing hero carries `boat_id`.
- **Boarding.** A walking hero may end a route on a free boat. Boarding ends the hero's movement for the day, as in HoMM3.
- **Sailing.** A sailing hero moves only on open water (one point per tile, like land), may end a route on a water site (whirlpool, flotsam, sea chest), and cannot pass another boat.
- **Going ashore.** A sailing hero may end a route on open shore or a shore site (a town entrance, a pickup). Stepping off ends the day's movement; the boat stays moored on the last water tile for anyone to take.
- **Shipyard.** A neutral visit building on the coast. Any visiting hero may build a boat for 1,000 gold and 10 wood (the HoMM3 price). The boat appears on the dock: the open water tile next to the visit tile, or next to the body, nearest the visit tile. A full dock refuses before anything is paid.
- **Whirlpool.** A water site. Sailing into it throws the boat out on a free water tile beside another whirlpool on the same level, picked by a stable hash of the source, day and hero. The weakest stack (by total health) loses half its creatures, rounded down, never the army's last creature. A lone whirlpool spins the boat back where it entered.
- **Rendering.** Moored boats use `mapobj_water_boat`; a sailing hero shows as the same boat with the owner's flag at the masthead and the hero's command pennant.

Saves keep `overworld.boats` and each hero's `boat_id`; normalization keeps them consistent (a boat follows the hero aboard; a hero whose boat is gone walks again).

## Random maps

`scripts/persistence/GeneratedRewardRules.gd` translates HoMM3 transit objects by meaning:

| HoMM3 object | Becomes |
| --- | --- |
| Boat (8) | A boat waiting on its water tile |
| Shipyard (87) | Shipyard |
| Whirlpool (111) | Whirlpool |
| Border Guard (9), Border Gate (212), Garrisons (33, 219), Quest Guard (215) | A pay-to-open gate that suits the terrain under it (frost bar on snow, thorn seal or root lease in swamp, ash sluice on lava, brass toll or pressure rail underground and on rough ground, charter bar or toll chain on grass and dirt) |
| Keymaster's Tent (10) | Left off: gates open by payment, so no key is needed |
| Monoliths (43, 44, 45) | Keep their native passage with the Slipgate Mirror art |
| Subterranean Gate (103) | Keeps its native passage with the Basalt Undergate art |

Shipyards and whirlpools only appear where the source map had one. The random-map object table never uses them as stand-ins for other HoMM3 sites: their `water_travel_live` status is excluded from the interactable pool (`water_travel_meaning_placement` in `content/random_map_object_eligibility.json`). Otherwise an inland service could become a shipyard with no water.

Gates now ask before they take payment: visiting one opens a prompt with the gate's story, the price and an Open button; leaving it keeps the passage closed. An opened gate stays open for everyone.

Saves from older random maps are migrated once on load (`overworld.generated_transit_translation_version`): boat sites become boats, shipyards and whirlpools get their sites, keymaster's tents disappear, unopened gates are re-picked for their terrain, opened gates stay open, and portals keep their passage with the new art.

## Content

- `site_shipyard` / `object_shipyard` (visit building, `mapobj_shipyard`), `site_whirlpool` / `object_whirlpool` (visit building on water, `mapobj_whirlpool`), and the boat sprite `mapobj_water_boat`.
- The three sprites are original image-generation art; prompts and references are in `art/overworld/source/generated/resource_sites/water_travel_20261007/provenance.json`.

## Not yet

- **AI heroes do not sail.** Enemy heroes still treat water as blocked and never board boats or build them. AI water travel is the next slice.
- Sea battles, sea movement bonuses (HoMM3 Navigation, sea artifacts) and town shipyards are not modelled.

## Validation

`tests/water_travel_report.tscn` widens a skirmish map, carves a lake and drives the real rules: translation of every transit type, the bridge's boats, the save migration, a shipyard visit that builds a boat and refuses a second, boarding (movement ends), a sailing save round-trip, the sailing route rules, a whirlpool throw with its troop loss, going ashore (movement ends, boat stays moored), a moored save round-trip, boarding again, the map drawing moored boats, and a gate that asks before taking payment.
