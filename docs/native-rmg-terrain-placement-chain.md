# Native RMG TerrainPlacement Chain

Document role: source-backed implementation ledger for the active native TerrainPlacement port.

This file records the recovered H3MapEd TerrainPlacement behavior now implemented in `h3maped_rmg_core` for the current one-level land Small/Medium native RMG chain. It is not a final-map density report and it is not permission to emit public generated maps before later generated-cell mutation phases are source-owned.

## Implemented Source Order

The active shared native core now executes these recovered TerrainPlacement pieces after `0x49b53d` terrain selection and `0x4a3f27` repaint scheduling:

1. `0x4bcff5` visual table/toolkit setup:
   - embeds recovered static visual rows from tables `0x543108`, `0x543380`, `0x5434f0`, `0x5435b0`, and `0x542f88`;
   - preserves the recovered row counts `79/46/24/33/48`, totaling `230` rows;
   - keeps terrain-specific constructor probability behavior for dirt, sand, normal land, water, and rock paths.
2. `0x4bce6d` / `0x4bcfc3` visual row selection:
   - classifies neighboring terrain through the recovered relation/classifier path;
   - builds the recovered `0x4ba868` toolkit range slots from row `shape_class` and row flag A;
   - applies the recovered `0x4ba91d` neighbor probe for complex terrain, where same-terrain neighbors only reduce the mask when the neighbor art row has flag A set;
   - applies the recovered `0x4baa81` simple/rock neighbor probe, which rejects same-terrain continuity for that vtable;
   - applies the recovered `0x4ba938` base-row probability path for full/native cells before the later final-sweep classifier path;
   - consumes `0x4e7276` RNG from the post-`0x49b53d` state.
3. `0x4bad0f` scratch packing:
   - bit `0`: dirty marker;
   - bits `1..4`: terrain id;
   - bits `5..11`: selected visual/art row;
   - bit `12`: terrain flag A;
   - bit `13`: terrain flag B.
4. `0x49acf6` generated-cell writeback:
   - `GeneratedCell+0x24` bits `0..5`: terrain id;
   - `GeneratedCell+0x24` bits `6..13`: selected visual/art row;
   - `GeneratedCell+0x28` bits `15..16`: terrain flags.
5. `0x4bb74b/0x4bc5f0` live feedback:
   - full-map water visual prefill runs first;
   - owner/member-gated terrain repaint writes visual rows and flags;
   - set-A/set-B queue feedback, `0x4bbd01` retouch, `0x4bc988` candidate gates, and `0x4bba59` neighbor seeding run inside the active native core;
   - `0x4bbfcc` final whole-map sweep revisits the full grid and applies the recovered class corrections;
   - final sweep preserves the current scratch visual record through the recovered `0x4bc5a3` path when a corrected class has no direct visual bucket.

## Native Implementation

- `src/gdextension/src/h3maped_rmg_core.cpp`
- `src/gdextension/include/h3maped_rmg_core.hpp`
- `src/gdextension/src/rmg_native_core.cpp`
- `src/gdextension/include/rmg_native_core.hpp`
- `src/gdextension/src/h3maped_rmg_core_selftest.cpp`

## Validation Contract

The focused native selftest now fails if TerrainPlacement regresses to the previous art-row-zero/flag-zero behavior. It checks:

- full-map water visual rows are written;
- post-water TerrainPlacement feedback writes additional visual rows;
- final sweep covers the full grid;
- no visual row bucket is missing;
- corrected final-sweep classes can preserve the current visual record instead of reporting a missing bucket;
- scratch words round-trip into generated-cell `+0x24/+0x28`;
- generated-cell terrain ids match the live terrain code;
- visual/art rows are nonzero for at least some cells;
- visual selection consumes RNG.

## Remaining Checkpoint-2 Blocker

The known terrain toolkit vfunc drift is fixed in the active shared core: native no longer treats every nonzero same-terrain neighbor art row as connectable. This is still not a TerrainPlacement parity claim. The focused same-run Medium comparison continues to block at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`, so any remaining TerrainPlacement queue/final-sweep order drift must be treated as live until phase/private-state comparison proves otherwise.

Checkpoint 2 is still not complete because later relation/object generated-cell mutation caller order is not yet source-owned:

- `0x4a5767/0x49a318` relation reset caller order;
- `0x49aa63/0x49a932/0x49abd6/0x49a85d/0x49a962` candidate, occupied, action, and body caller order;
- `0x49cf34/0x4aa3e9` relation/reward attachment caller order.

Runtime map output remains fail-closed until those later phases are ported in source order and same-run private-state comparison passes.
