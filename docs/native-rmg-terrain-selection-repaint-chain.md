# Native RMG Terrain Selection And Repaint Chain

Document role: executable source-chain ledger for the H3MapEd terrain selection and terrain repaint slice.

This is not a final-map density note. It records the recovered H3MapEd execution order now carried by the shared native RMG core for one-level land Small/Medium scope.

## Implemented Chain

Native now executes this source-backed order:

1. `0x4ac552` selects the recovered H3MapEd template from the recovered catalog.
2. `0x4a218c/0x4a1f3b/0x4a19ed` places runtime zones and rescales their coordinates.
3. During the initial zone insertion loop, `0x49b3c1` is executed before each first-pass coordinate placement:
   - source zone bytes `+0x41..+0x49` are represented by `allowed_town_mask_0x41_0x49`;
   - if the mask is non-empty, one `0x4e7276` RNG value selects the Nth enabled original H3 town index;
   - if the mask is empty, the runtime town choice remains `-1`.
4. `0x4a3a03/0x4ccb64/0x4cca55/0x4a2777/0x4a325d` materialize zone ownership into generated-cell `+0x20`.
5. `0x49b53d` selects one terrain id per runtime zone after coordinate replay:
   - source zone byte `+0x84` is represented by `terrain_match_to_town_0x84`;
   - source zone bytes `+0x85..+0x8c` are represented by `allowed_terrain_mask_0x85_0x8c`;
   - match-to-town uses table `0x540908 = {2, 2, 3, 7, 0, 0, 5, 4, 2}`;
   - otherwise one `0x4e7276` RNG call selects among allowed terrain flags;
   - terrain id `6` is eligible only on level `1`;
   - if level is `1` and selected terrain is not lava `7`, the selected terrain is forced to `6`.
6. `0x4a3f27` terrain repaint runs after owner-grid materialization:
   - full-map water repaint writes terrain id `8`;
   - per-zone repaint skips water zones;
   - owner gate reads generated-cell `+0x20` byte 2, matching `0x4a4142`;
   - member gate reads generated-cell `+0x28 >> 28 & 1`, matching `0x4a4150`;
   - passing cells write terrain id through the recovered `0x49acf6` generated-cell writer.
7. TerrainPlacement visual feedback now runs in the same active core:
   - `0x4bcff5` uses the recovered static visual rows;
   - `0x4bce6d/0x4bcfc3` select exact visual rows from terrain relations and neighbor masks;
   - `0x4bad0f` packs scratch terrain/art/flag bits;
   - `0x4bb74b/0x4bc5f0` queue feedback and `0x4bbfcc` final sweep update live terrain visuals;
   - `0x4bc5a3` preserves the current scratch visual record during final-sweep corrected-class cases without direct row buckets;
   - `0x49acf6` writes both terrain art bits and terrain flag bits into generated-cell `+0x24/+0x28`.

## Native Files

- `src/gdextension/include/h3maped_rmg_core.hpp`
- `src/gdextension/src/h3maped_rmg_core.cpp`
- `tools/generate_h3maped_rmg_template_catalog_cpp.py`
- `src/gdextension/src/h3maped_rmg_template_catalog.cpp`
- `src/gdextension/src/rmg_native_core.cpp`
- `docs/native-rmg-terrain-placement-chain.md`

## Data Mapping

The generated catalog now carries these recovered source fields:

- `allowed_town_mask_0x41_0x49`
- `terrain_match_to_town_0x84`
- `allowed_terrain_mask_0x85_0x8c`

H3 terrain id mapping used by the catalog generator:

- `0`: dirt
- `1`: sand
- `2`: grass
- `3`: snow
- `4`: swamp
- `5`: rough
- `6`: cave
- `7`: lava
- `8`: water, used by full-map repaint

H3 town choice mapping used by `0x49b3c1`:

- `0`: castle
- `1`: rampart
- `2`: tower
- `3`: inferno
- `4`: necropolis
- `5`: dungeon
- `6`: stronghold
- `7`: fortress
- `8`: elemental

## Remaining Non-Parity Piece

Terrain id repaint and TerrainPlacement visual row/flag writeback are implemented, but full pre-`0x4a4c8e` generated-cell private-state parity is still not complete.

Remaining named blocker:

- later relation/object generated-cell mutation caller order after TerrainPlacement.

Native therefore keeps `generated_cell_private_state_comparable=false`. The current generated-cell words are useful support state, not a final parity checkpoint, until the later relation/object mutation phases are implemented in source order and same-run validated.
