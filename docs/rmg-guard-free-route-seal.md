# Guard-free route seal: a deliberate departure from H3MapEd

Document role: design and validation of an owner-approved departure from H3MapEd
(owner decision, 2026-11-04). This is not a parity fix.
Slice: `rmg-guard-free-route-seal-20261104`.

## Problem

In the 1,200-game AI batch of 2026-11-04 (`.artifacts/ai_batch_20261104_allsizes_land_L12_1200`)
four small 2-player games were won on day 2 or 3 by a hero walking into the enemy
capital without a fight (m936, m762, m944, m1089). Every template link between the
start zones is guarded, yet the maps left a way around the guards:

- m936: a resource pile and one diagonal step beside the 14 Titans that guard the
  start zones' link.
- m762, m1089: gaps beside weak link guards on ring templates.
- m944: a four-tile-wide road gap between zones 0 and 1, the guard standing elsewhere.

The maps are H3MapEd's own: the same seed in H3MapEd shows the same layout, and the
owner confirmed the gap on m936 in HoMM3 itself. Eight-way walking without a corner
rule is H3's movement and stays.

## Decision

The generated map closes every fight-free walk between zones whose template link is
guarded. It runs after the final writeout of every normal game, also after the
cut-off town repair (`docs/rmg-cut-off-town-repair.md`), and changes only maps that
have such a walk. `AURELION_RMG_H3MAPED_STRICT=1` and the controlled parity cases
(`repair_cut_off_towns = false`) leave it off; the connection tail's bookkeeping is a
no-op there.

## What counts as a guard-free route

- **Groups.** The connection tail (`0x4a79a3`) records, for each template link, its
  two zones and the guard objects its dispatches committed
  (`ZoneLinkGuardRecordDeparture`). Zones joined by a link without a guard form one
  group: a fight-free walk between them is the template's.
- **The walk.** Eight-way steps, rock and water closed (a sea route is the
  template's), object bodies closed, entrances open, monolith and gate peers joined.
  A guard's 3x3 is a fight. Mines block their game footprint.
- **Holding an area.** A group holds a guard-free component when one of its towns
  stands in it or its zones have at least 16 tiles there. A component held by two
  groups or more is a guard-free route between them. This counts a town that stands
  in a pocket its own zone reaches only past a guard (m391, m1129), and a small hub
  zone's town (m210), but not a few border tiles of another zone.

## Rock seals

For each route the seal finds the cheapest set of tiles that separates one group's
tiles from the others' in that component, a minimum vertex cut (Edmonds-Karp on the
split-vertex graph; at most 16 tiles):

- Cost per tile: 12 minus its closed neighbours, plus 30 on a road, 40 for a
  pickup, 10 beside an object. Entrances, towns and tiles no one-tile obstacle fits
  cannot be cut.
- Each cut tile gets a one-tile decorative obstacle of the `0x54092c` buckets that the
  tile's terrain takes (terrain score above `0x49e700`'s -5000 reject), the smallest
  that fits, picked by terrain score with a hash of seed and tile; no generator RNG
  is drawn. It is committed through `0x4a54a7` the way `0x49e700` commits a
  decoration, and the object stream and payload are written again
  (`0x4ad309`, `0x4ad1e3`).
- A pickup (resource, artifact, chest, campfire, scroll, Pandora's box, scholar) on
  a cut tile moves to the nearest free plain tile of its zone, within ten steps, off
  roads and not beside an object or a seal. The search crosses seals, so a border
  pickup goes back into its own zone.

A cut is refused, and the next narrowest tried, when:

- an object or a town would lose the walking area it is reached from (guards
  passable, portals joined): the map would split even for an army that fights;
- a zone's own area, the ground it reaches through its own group, would split,
  beyond four tiles without objects.

The first pass keeps every tile on its own zone's side. A second pass, for what the
first could not close, lets tiles within two steps of the other group's ground end
up on either side (towns never): on m868 a zone-0 mine and a zone-3 object face each
other across the gap, and any cut keeping both on their own side would have to block
an entrance.

## Guard moves

Where rock cannot close a route without splitting the map, the gap is the only way
between the two sides and the link guard meant to hold it stands where it holds
nothing. On m128 (large, underground) zone 9's guard to zone 10 stands beside a
two-tile pocket, while zone 9's town reaches the rest of the map only through a
diagonal corridor into zone 0. Then a link guard of the route's zones, nearest first
and not yet moved, moves into the gap: the fewest tiles separating the two sides
(towns excluded) must fit its 3x3, on a free tile without an entrance, out of other
guards' reach and not beside a town gate. The move is kept only when the map has
fewer guard-free routes afterwards; rock then tries again on what is left.

## Checks on the written map

After the commit, the map the game reads is projected again and must show: no more
cut-off towns than before; every new obstacle blocking exactly its sealed tile and
nothing else; every moved pickup and guard on its new tile. Otherwise the map is
generated again as H3MapEd made it (`RMG_TRACE_ROUTE_SEAL_FAILED`).

The map's metadata records `guard_free_route_seal`: `routes_before`, `routes_after`,
`obstacles`, `pickups_moved`, `guards_moved`. `AURELION_RMG_TRACE_ROUTE_SEAL=1`
traces the groups, every cut and refusal, the seal tiles and guard moves.

## Validation

All 1,200 maps of the 2026-11-04 batch plan (300 per size, 2-6 players, one and two
levels, weak, normal and strong guards, land) were generated in the match scene's
prepare mode with the seal on and checked by an independent walker that reads only
the written map package (block and visit tiles, guards' 3x3, rock, water, gate and
portal pairs from `native_transit`) and the zone grid and link traces.

| Size | Maps with a route (pairs) | Left open | Obstacles | Pickups moved | Guards moved |
|---|---|---|---|---|---|
| Small | 180 (341) | 0 | 561 | 10 | 0 |
| Medium | 193 (415) | 3 | 719 | 10 | 0 |
| Large | 241 (970) | 3, on 2 maps | 1,577 | 16 | 2 |
| Extra large | 252 (1,430) | 6 | 2,618 | 25 | 2 |

- No seal failed its checks on the written map, so no map fell back to H3MapEd's.
- Fight-free town pairs between groups: none on any map (12 on the first 28 traced
  small maps before the town and pocket rules).
- Town pairs unreachable even with fights: the same before and after the seal on
  every map. None on small and extra large; medium m269 has 7 (a town the cut-off
  repair itself reports cut off) and large m800 13 (a town reached by boat, which the
  walker does not model).
- The four day-2 maps: m936 two obstacles at (14,15) and (15,15) beside the Titans,
  the resource pile moved from (15,15) to (18,15); m762 three obstacles, zone 4's
  enclave mine now behind the Imps; m944 a six-tile wall from (26,21) to (28,24)
  across the four-wide road gap, the pickup on (28,23) moved, and one obstacle at
  (16,18); m1089 three obstacles at (19,31), (19,32) and (20,32).
- Guard moves: large m128 (79,56) to (99,72) underground and m776 (77,49) to
  (101,97); extra large m367 (48,131) to (20,140) and m883 (126,99) to (120,132).
- Time, 48 maps per size generated 12 at once: the seal takes a median 44 ms (at most
  96 ms) on extra large maps and 3.5 ms (at most 8 ms) on small ones, about 0.7% and
  1.2% of each map's generation (at most 1.4% and 2.7%).

What stays open: 12 routes on 11 maps (medium m027, m326, m620; large m398 and m776,
two there; extra large m150, m232, m358, m367, m446, m962). Each joins a pocket of one
zone (17-148 tiles, no town of its own) to another group's ground, where the pocket's
only way in is that ground, the gap is wider than one guard's 3x3, and rock would wall
the pocket's objects in. None of them joins two groups' towns: a hero still has to
fight to reach any town of another group.
