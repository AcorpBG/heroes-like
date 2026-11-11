# Overworld ground borders (v4)

Slice: `art-overworld-organic-ground-borders-20261008` (owner-approved prototype, 2026-10-08: "ground prototype is accepted, I like it better").

## Problem

The ground shader cross-faded the four nearest tile materials over about half a tile centred on each tile edge, with only about 0.13 tile of wobble. Biome borders therefore ran straight along the tile grid with stair-step corners, and inside the fade both grounds showed at half strength.

## Model (`scenes/overworld/overworld_ground_surface.gdshader`)

- **Bending**: the corner-weight lookup is offset by three octaves of value noise on rotated lattices (`border_warp`; about 0.36 tile broad, plus finer detail), so borders meander and corners round into lobes. The bend fades out toward every tile centre (`bend`), so each tile's middle keeps its own ground and terrain stays readable per tile. Since 2026-11-11 it grows with the distance from the centre, nothing at the centre and full at the tile's corners, and the warp is held under `warp_reach` (0.4 tile): slow enough that the bent lookup never folds over itself. Before, it rose from 0.05 to 0.3 tile inside a square and the warp reached 0.67 tile, so a strong warp folded the lookup and left square teeth and holes of a tile's own ground inside its neighbour's, clearest as square notches of water in the beach.
- **Height and priority blend**: where grounds meet, each candidate material scores its merged corner weight, its border priority and its own painted detail (luminance above the material's average acts as height). The winner shows crisply with a narrow soft zone (`blend_depth`), so blades, pebbles and drifts of one ground fringe the other instead of a ghosted mix.
- **Priority** (`art/overworld/ground_materials.json`, `border_priority` by material slot): snow, grass and forest spill over swamp, plains, rough, dirt, sand and rock; water is lowest.
- **Beach** (reworked 2026-11-11, slice `ground-shore-layers-20261111`, owner report): by the share of water round a point (0.5 on a straight tile edge), dry sand comes in over the land (`shore_sand`), darkens to wet sand toward the waterline (`shore_wet`), and the sea is laid over the sand from the waterline out (`shore_sea`), letting the sand show through in the shallows (`shore_shallow`, `shore_deep`). At a shore the grounds compete only among themselves and the sea is not part of that blend, so nothing of the land shows past the sand. Before, the sand faded out over the water side while land and sea still competed underneath by priority and detail: dark lava or grass showed through the half-faded sand as blotches. A shore is found from the four tiles, not their weights (rounding leaves four water tiles a hair under one).
- Decals (`docs/overworld-terrain-decals.md`) fade with each ground's final share of the blend, so they never cross a border.

Presentation only: the per-tile lookup, fog, gameplay and saves are unchanged.

## Border noise: integer lattice hash

Slice: `ground-border-noise-seams-20261111` (owner report, 2026-11-11: the beach to water transition looked bad).

Shores, biome borders and fog edges were cut into straight-edged wedges. The value noise behind `border_warp` (and the fog shader's `fbm`) hashed its lattice points with `fract(p * vec2(123.34, 456.21))`, then a dot product and a second `fract`: products in the thousands, squared, so one bit of rounding changes the result completely. A lattice corner is read by the four cells round it, each through a different expression (`i`, `i + vec2(1, 0)`, ...), and the GPU compiler may fold the constant offset into the multiply. The same corner then got different values in neighbouring cells, the noise jumped along the lattice lines (60, 20 and 75 degrees off the grid, the three rotated lattices), and the sand band, drawn from thresholds on the bent weights, broke there. With the warp at zero the shore was clean, which located it.

`border_hash` and the fog's `hash` now work on integer lattice coordinates (`uvec2`, multiply and xor): the same point gives the same value everywhere. The meander's character and all tuning values are unchanged; the exact shapes of borders differ from before.

## Impassable land: walled void

Slice: `art-overworld-impassable-rock-void-20261015` (owner pick C, thicker, from in-game comparison sheets, 2026-10-15). Rock looked like walkable gravel, so blocked ground could not be told apart from cave floor.

- `OverworldGroundSurface` writes lookup alpha 0 on every tile whose terrain `OverworldRules.terrain_id_is_passable` rejects, except water (it keeps its shore). The material slot alone cannot decide this: `ridge` shares the rock texture but is walkable.
- The shader builds a depth field from those flags (smooth weights between tile centres, 0.5 on the tile edge, 1 inside), bent by a third of the border warp plus fine crag noise. Past the ledge it draws a near-black void.
- A thick rugged ledge of stacked stones (the rock texture, warm-tinted, with lumps and joints) runs on the impassable side of the edge, from depth 0.46 to 0.97, lit on the side facing up-left and falling into shadow toward the void. Walkable tiles keep their own ground with a thin contact shade.
- Inspired by how HoMM3 builds underground rock (black interior tiles plus edge tiles with a cliff rim inside the rock tile). The art is our own shader and rock texture, no HoMM3 frames.

Uniforms: `rock_warp_scale`, `rock_crag`, `rock_ledge_start`, `rock_ledge_end`, `rock_void_color`, `rock_slot` (ledge texture).

## Tuning

Shader uniforms: `warp_tiles`, `warp_frequency`, `warp_detail_tiles` (how far borders wander), `warp_reach` (the most a border is bent), `shore_sand`, `shore_wet`, `shore_sea`, `shore_deep`, `shore_shallow` (the beach), `height_strength` (how much a ground's own detail shapes the fringe), `blend_depth` (edge softness). `border_priority` in the ground manifest.

## Validation

Before/after captures of sand/grass, snow/grass, swamp/grass, snow/dirt, dirt/grass and rough/dirt (owner's map and a generated map) and a generated coast were reviewed; `tests/overworld_sandy_shore_regression.py` (53 checks: beach band, tile-centre identity, fog safety, pan stability) and `tests/overworld_ground_materials_contract.py` pass.
