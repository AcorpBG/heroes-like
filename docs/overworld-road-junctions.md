# Overworld road junctions

Slice: `ux-overworld-road-junctions-20261008` (owner report, 2026-10-08: "two intersecting roads make too many connections, a double connection instead of just a T intersection").

## Cause

Generated roads come from the native generator as one unordered tile set. Where two roads meet or pass side by side, it lays them two tiles wide (the HoMM3 generator does the same; its stored road frames for those tiles draw a fat clump too). The renderer joined every road tile to every orthogonally adjacent road tile, so those clumps drew as ladders and small loops: on the owner's 108x108 map, 7 closed 2x2 blocks around two portal entrances and beside a town.

## Model (`OverworldMapView`)

After the adjacency connections are built, `_simplify_fat_road_clusters` finds every road tile that belongs to a closed 2x2 block and groups them into clumps. For each clump:

- its ports are the clump tiles where a road leaves the clump, plus any clump tile with an object entrance (`OverworldRules.tile_has_route_interaction`), so a road still reaches a portal or gate;
- one tree links the ports, path by path, cheapest first with extra cost for turns (`_road_cluster_path`), so junctions read as a T or a cross and stretches stay straight;
- connections inside the clump that are not on the tree are dropped, and clump tiles off the tree are not drawn (`presentation_hidden`).

Roads outside clumps, real loops around a field and plain crossings are unchanged. Presentation only: roads do not change movement in this game, and the road data and saves are untouched.

## Diagonal steps

Slice: `ux-overworld-road-diagonal-steps-20261015` (owner report, 2026-10-15: "the road is broken").

The native generator also lays roads that step diagonally, from one tile to the next across a shared corner (HoMM3 roads do this too). Only orthogonal neighbours were joined, so the road showed a gap at every step and a lone stub where a step left a single tile. After the clump simplification, `_add_road_corner_steps` joins two diagonal road tiles when no drawn road tile sits beside both (otherwise the orthogonal path already joins them). Each tile draws its half straight to the shared corner, so the halves meet with one direction; a turn from a side into a corner step curves through the tile centre like any other turn. The overlay-art lookup keys stay orthogonal.

## Validation

`tests/overworld_road_junction_report.tscn` builds a yard on a generated small map with a T that has a fat corner, a two-wide stretch between two roads, a ring road and a plain cross, and checks that no closed 2x2 connection is drawn, every road end still connects, junction counts, the cross keeps four arms and the ring stays whole. Before/after captures of the three affected spots on the owner's map were reviewed. `tests/overworld_road_style_regression.py` draws a diagonal step and checks both halves end at the shared corner.
