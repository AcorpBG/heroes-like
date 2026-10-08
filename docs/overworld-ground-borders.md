# Overworld ground borders (v4)

Slice: `art-overworld-organic-ground-borders-20261008` (owner-approved prototype, 2026-10-08: "ground prototype is accepted, I like it better").

## Problem

The ground shader cross-faded the four nearest tile materials over about half a tile centred on each tile edge, with only about 0.13 tile of wobble. Biome borders therefore ran straight along the tile grid with stair-step corners, and inside the fade both grounds showed at half strength.

## Model (`scenes/overworld/overworld_ground_surface.gdshader`)

- **Bending**: the corner-weight lookup is offset by three octaves of value noise on rotated lattices (`border_warp`; about 0.36 tile broad, plus finer detail), so borders meander and corners round into lobes. The bend fades out within 0.3 tile of every tile centre (`bend`), so each tile's middle keeps its own ground and terrain stays readable per tile.
- **Height and priority blend**: where grounds meet, each candidate material scores its merged corner weight, its border priority and its own painted detail (luminance above the material's average acts as height). The winner shows crisply with a narrow soft zone (`blend_depth`), so blades, pebbles and drifts of one ground fringe the other instead of a ghosted mix.
- **Priority** (`art/overworld/ground_materials.json`, `border_priority` by material slot): snow, grass and forest spill over swamp, plains, rough, dirt, sand and rock; water is lowest.
- **Beach**: the sandy coastal band uses the same bent corner weights, so shores curve too.
- Decals (`docs/overworld-terrain-decals.md`) fade with each ground's final share of the blend, so they never cross a border.

Presentation only: the per-tile lookup, fog, gameplay and saves are unchanged.

## Tuning

Shader uniforms: `warp_tiles`, `warp_frequency`, `warp_detail_tiles` (how far borders wander), `height_strength` (how much a ground's own detail shapes the fringe), `blend_depth` (edge softness). `border_priority` in the ground manifest.

## Validation

Before/after captures of sand/grass, snow/grass, swamp/grass, snow/dirt, dirt/grass and rough/dirt (owner's map and a generated map) and a generated coast were reviewed; `tests/overworld_sandy_shore_regression.py` (53 checks: beach band, tile-centre identity, fog safety, pan stability) and `tests/overworld_ground_materials_contract.py` pass.
