# Sea content: a deliberate departure from H3MapEd

Document role: design and validation of an owner-approved departure from H3MapEd
(owner decision, 2026-11-09). This is not a parity fix.
Slice: `rmg-sea-content-20261109`.

## Problem

H3MapEd places nothing on the water. The water inventory of 2026-11-09 found that
the game already translates HoMM3's sea objects by meaning (`docs/water-travel.md`),
but no generated map ever had one: islands and normal-water maps offered open sea
with nothing to take, wrecks to fight or whirlpools to use, so a boat only carried a
hero from one shore to the next.

## Decision

After the final writeout, the cut-off town repair and the guard-free route seal
(`docs/rmg-guard-free-route-seal.md`), the generated map gets HoMM3 water objects on
open sea that a shipyard serves. It runs in every normal game
(`H3MapedRmgWorkflowConfig::sea_content`); `AURELION_RMG_H3MAPED_STRICT=1` and the
controlled parity cases (`repair_cut_off_towns = false`) leave it off. Land maps and
seas no shipyard or boat reaches are unchanged.

## Where objects stand

- **Free water**: water tiles no object stands or acts on.
- **Launch tiles**: each shipyard's dock, the water tile nearest its visit tile
  among the neighbours of the visit tile and its body (the same rule as `dock_tile`
  in `water_travel_rules_ai.cpp`), and the free water around a boat. A town's
  harbour (`docs/water-travel.md`, "Town shipyard") is not a launch tile: the
  generator does not know which towns will build a Shipyard.
- **Served**: free water a boat reaches from a launch tile, eight ways, a diagonal
  step closed when both tiles beside it are (the AI route search's corner rule).
- **Open**: served water more than two tiles from every launch tile, so boats are
  built and turn freely.
- Each object's tiles and every tile within its ring of them are open and not
  taken; none of its tiles lies in another new object's ring. Every visit tile is
  reached by boat and no sea route closes.

## What is placed

Per level, from the level's open tiles `N`:

| Group | HoMM3 objects (objects.txt row) | Count | Ring | Spacing |
| --- | --- | --- | --- | --- |
| Whirlpools | Whirlpool 111 (AVXwhrl0) | 4 from 5,000, 2 from 1,200 | 1 | farthest apart |
| Wrecks | Derelict Ship 24 (AVAdlic0) 35%, Shipwreck 85 (AVAwrek0 33%, AVAwre20 32%) | 1 from 300, else N/900 | 2 | 12 |
| Buoys | Buoy 11 (AVSbuoy0) | N/1500 | 1 | 10 |
| Pickups | Flotsam 29 (AVAflot0) 45%, Sea Chest 82 (AVXccht0) 35%, Shipwreck Survivor 86 (AVAsurv0) 20% | 3 from 150, else N/180 | 1 | 5 |

- Picks order the open tiles by a splitmix hash of seed, group and tile, and roll
  the kind with another salt: no generator RNG is drawn, and a seed gives one map.
- Whirlpools go farthest-point, each as far as it can be from the others on the
  level; an odd last one is dropped, so every whirlpool has a peer.
- An object's tiles come from its objects.txt passability and action masks, the
  masks the final writeout writes (`0x4ad3eb`); its source cell (+0x2c/+0x30) is the
  action origin, as for visitable objects (`0x49d471`). The DEF/MSK second qword is
  empty for Flotsam, Survivors and Whirlpools and is not used.

## Commit and checks

Each object is committed through `0x4a54a7` as a generic record (vtable `0x540A74`),
the way `0x49e700` commits a decoration, with its catalog index, copied source record
and score cache. The object stream and payload are written again (`0x4ad309`,
`0x4ad1e3`) and projected. The map is kept only when it holds every old object plus
exactly the new ones, each new object of its type standing on exactly the tiles it
was put on, and no more towns are cut off than before; otherwise the map is
generated again without sea content (`RMG_TRACE_SEA_CONTENT_FAILED`).

`AURELION_RMG_TRACE_SEA_CONTENT=1` prints each object (`RMG_TRACE_SEA_CONTENT_OBJECT`),
the counts (`_DONE`) and why a map got none (`_SKIP reason=no_water|no_launch|no_room|...`).
The package metadata records `sea_content` (`water_tiles` open, `pickups`, `wrecks`,
`buoys`, `whirlpools`).

## What each becomes

`GeneratedRewardRules` (`generated_reward_rules.cpp`):

| Object | Site | Reward |
| --- | --- | --- |
| Flotsam | Drift Wreckage | 5 wood; 5 wood and 200 gold; or 10 wood and 500 gold |
| Sea Chest | Sea Coffer | 1,500 gold, or one in three 1,000 gold and a treasure artifact |
| Shipwreck Survivor | Castaway Raft | an artifact: treasure 50%, minor 30%, major 20% |
| Shipwreck | Wreck Locker | creature bank, light harbor watch guard |
| Derelict Ship | Storm-Bell Wreck | creature bank, heavy harbor watch guard |
| Buoy | Tide Bell | +1 cohesion in the next battle, once per hero each week |
| Whirlpool | Whirlpool | throws the boat to a peer, the weakest stack loses half |

The guard stands on the wreck's visit tile; a sailing hero ends a route there and
fights on the coast battlefield. The three pickups are new sites with original
sprites (`art/overworld/source/generated/resource_sites/sea_content_20261109/`).
Shipwreck Survivor moved from the artifact pool to the resource-pickup pool of
`content/random_map_object_eligibility.json`: the artifact pool would have made it
an artifact node.

## Computer players

They weigh sea sites like any other (`docs/ai-plays-by-player-rules.md`, "Water"):
everything across the water less the boat's price where the route buys one, half a
day more for each boarding or landing. They take their own island first and sail
after: in 8 medium and large islands and two-level normal-water games, 69% of land
pickups and 8% of sea pickups were taken by day 40 (1,082 of 1,570; 12 of 142). The
two large games that ran to day 100 took 28 of 46 and 15 of 37 sea pickups and
cleared 5 of 9 and 4 of 7 wrecks. They do not sail into whirlpools and do not seek
tide bells.

## Validation

- 48 water maps (small to extra large, normal water and islands, one and two
  levels, three seeds each): 32 got sea content, 1,178 objects (70 whirlpools, 162
  wrecks, 91 buoys, 855 pickups) on 220 to 15,344 open tiles; 14 had no shipyard
  dock on open water and 2 no water. No map failed its checks. Every object became
  its site on a water tile. Small islands maps get 3 or 4 objects.
- 16 land maps (all sizes, one and two levels) are identical to the previous
  runner's apart from the package hash, which the new metadata changes.
- 12 AI games (small to large islands, medium two-level normal water) played 40
  days, 8 of them to day 100 or a winner, without errors.
- `rules_selftest`, `h3maped_rmg_core_selftest`, `tests/validate_repo.py` and the
  core suite pass; `tools/rules_parity.py check . . --runner-b` is identical on
  l1, l2, mw, s2, mg-a, mg-b and the islands seed isl-b.
- In the game, small islands seed 2326877977 (Sunvault) shows the Drift Wreckage
  off the start island on day 1.
