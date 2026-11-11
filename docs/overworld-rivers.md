# Overworld rivers

Slice: `art-overworld-rivers-20261015` (owner request, 2026-10-15: "let's implement the rivers"; owner pick D, a narrow stream, from in-game comparison sheets; "rivers don't pool like that in homm3").

## Data

The native generator's river pass writes a river type per tile (`river_path_writeback_0x4ab6ac` / `0x4abd5f`, final art `river_final_write_0x458a2f`), and the map package carries it as the `river_type` / `river_art` terrain layers. The game loaded them but drew nothing. Generated medium maps carry tens of river tiles on the surface (48 and 90 in two samples); small maps and the underground had none in the samples. Types: 1 clear, 2 icy (the generator picks it where the river starts on snow), 3 muddy, 4 lava.

Each water wheel (type 109) starts a river in `0x4ac4ae`. When `0x4ab6ac`'s search from it reaches no bit29 cell, H3MapEd writes no river for that wheel and goes on to `0x4abd5f`: with the queue empty it tests bit29 on the last cell record it loaded, and if that is clear jumps from `0x4ab8f5` to the `0x4ab9dc` cleanup (Ghidra dump `.artifacts/rmg_recovery/ghidra_4aae2f_path_reset_20260710/caller_004ab6ac_FUN_004ab6ac.txt`). Until 2026-10-28 the port stopped the map there. The case where that last record does carry bit29 is not recovered and still stops the map.

## Model

- `OverworldMapView._river_masks_for_level` builds a mask per river tile. A tile joins the river tiles of its type beside it (north, east, south, west), as the generator's own art choice does (`river_neighbor_flags_0x4587f7_0x4bf3f4`).
- Where the river runs two tiles wide, each closed 2x2 block is opened into a path (`_open_river_blocks`): one inner join is dropped and block tiles the river no longer needs are left undrawn, keeping the straightest run between the ways in and out of the block. No pools, no small loops.
- A river end beside water or the map edge runs on into it; any other end is a spring.
- `OverworldGroundSurface` writes the mask into the lookup's blue channel: bits 0-3 the joins, bit 4 a river tile, bits 5-6 the type; bit 7 stays the road flag. Road and river tiles get no ground decals.
- The ground shader (`river_paint`) measures the distance to each river tile's centre-to-edge runs, bent by slow noise so the stream winds off the grid; turns are arcs round the tile corner and springs taper. A narrow channel of calm water (the sea material, desaturated and darkened, with a broken glint down the middle) sits in dark wet banks taken from the ground under it. Icy, muddy and lava rivers tint the water.

Presentation only: rivers do not change movement (as in HoMM3), and the river data and saves are untouched.

## Flow

Slice: `ground-moving-rivers-lava-20261111` (owner request, 2026-11-11: make rivers and lava move too).

- The river data has no direction. `OverworldMapView._set_river_flow_sides` works one out: a river runs to its mouth, a join that leads to no river tile (the sea or the map's edge); from there every tile upstream flows toward the tile it was reached from. A river with no mouth runs to its lowest dead end on the map. The side a tile flows out of (1 + its `RIVER_DIRECTIONS` index) is in bits 8-10 of its mask and goes to the shader in the lookup's alpha, as 255 less that number (alpha 0 still marks impassable land).
- `river_field` also returns how far along its tile's run a point lies, in tiles downstream: -0.5 where the water comes in, 0.5 where it leaves, round a turn by its angle. A tile's 0.5 meets the next one's -0.5, so anything with a whole number of periods a tile runs on unbroken.
- `river_paint` slides lights down the middle of the stream on that coordinate: three to a tile passing at `river_speed` a second and two slower ones under them, each bent and broken by still noise, with the water a little darker between them (`river_lights`). Lava rivers get the same lights in fire colours. Not seen in the game: no sampled map had a lava river.
- Lava ground (`lava_paint`): the crust stands; the fire the painting shows in its cracks swells and fades in slow patches that wander over the field, with a soft glow round it taken from a blurred look at the same painting (`lava_glow`).
- With motion off both stand still.

## Bridges

Slice: `art-overworld-river-bridges-20261015` (owner pick A, a timber bridge, from four in-game looks: timber bridge, stone bridge, stepping-stone ford, shallow ford).

Where a straight road crosses a river (the road joins two opposite sides of the tile and the river joins neither of those sides), `OverworldMapView._road_bridge_axis` gives the road's axis and `_draw_road_bridge` draws a plank deck on end beams with rails, posts and a shadow on the water, over the road. Other road and river overlaps (a road running along the river, or turning on a river tile) keep the road drawn over the water. The ground shader straightens the stream's meander near any tile with both the road and river bits, so the water runs through the tile centre under the bridge. The generator places few such crossings: one on each of the two sampled maps that have them.

Uniforms: `river_half_width`, `river_bank`, `river_meander`, `lava_slot`, `river_speed`, `river_lights`, `lava_glow`.

## Validation

Generated medium map (seed `river-b`) rendered at two river-dense spots before and after, with the owner's comparison sheets; `tests/overworld_sandy_shore_regression.py` (ground shader and lookup) and `tests/overworld_road_style_regression.py` pass (it also checks a bridge is drawn where a road crosses a stream and not where it runs along one); core suite. Bridges: the crossings on seeds `ford-1` (large) and `river-b` (medium) rendered in game in each candidate look.
