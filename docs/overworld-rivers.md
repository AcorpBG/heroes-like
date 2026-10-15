# Overworld rivers

Slice: `art-overworld-rivers-20261015` (owner request, 2026-10-15: "let's implement the rivers"; owner pick D, a narrow stream, from in-game comparison sheets; "rivers don't pool like that in homm3").

## Data

The native generator's river pass writes a river type per tile (`river_path_writeback_0x4ab6ac` / `0x4abd5f`, final art `river_final_write_0x458a2f`), and the map package carries it as the `river_type` / `river_art` terrain layers. The game loaded them but drew nothing. Generated medium maps carry tens of river tiles on the surface (48 and 90 in two samples); small maps and the underground had none in the samples. Types: 1 clear, 2 icy (the generator picks it where the river starts on snow), 3 muddy, 4 lava.

## Model

- `OverworldMapView._river_masks_for_level` builds a mask per river tile. A tile joins the river tiles of its type beside it (north, east, south, west), as the generator's own art choice does (`river_neighbor_flags_0x4587f7_0x4bf3f4`).
- Where the river runs two tiles wide, each closed 2x2 block is opened into a path (`_open_river_blocks`): one inner join is dropped and block tiles the river no longer needs are left undrawn, keeping the straightest run between the ways in and out of the block. No pools, no small loops.
- A river end beside water or the map edge runs on into it; any other end is a spring.
- `OverworldGroundSurface` writes the mask into the lookup's blue channel: bits 0-3 the joins, bit 4 a river tile, bits 5-6 the type; bit 7 stays the road flag. Road and river tiles get no ground decals.
- The ground shader (`river_paint`) measures the distance to each river tile's centre-to-edge runs, bent by slow noise so the stream winds off the grid; turns are arcs round the tile corner and springs taper. A narrow channel of calm water (the sea material, desaturated and darkened, with a broken glint down the middle) sits in dark wet banks taken from the ground under it. Icy, muddy and lava rivers tint the water.

Presentation only: rivers do not change movement (as in HoMM3), and the river data and saves are untouched. Roads cross rivers drawn over the water.

Uniforms: `river_half_width`, `river_bank`, `river_meander`, `lava_slot`.

## Validation

Generated medium map (seed `river-b`) rendered at two river-dense spots before and after, with the owner's comparison sheets; `tests/overworld_sandy_shore_regression.py` (ground shader and lookup) and `tests/overworld_road_style_regression.py` pass; core suite.
