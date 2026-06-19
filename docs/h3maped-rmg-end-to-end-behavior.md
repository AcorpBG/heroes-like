# H3MapEd RMG End-To-End Behavior

Document role: single consolidated source map for recovered H3MapEd random-map-generation behavior, private state, generated-cell words, bit fields, helper functions, and active native ownership.

This file is the coordination document for native RMG work. It replaces scattered verbal claims as the first place to check whether a phase is active in the one native RMG authority, helper-only, historical/private evidence, or still pending active-chain integration.

## Truth Contract

- One native RMG authority: `src/gdextension/src/h3maped_rmg_core.cpp`.
- No new proxy, duplicate generator, diagnostic replay, support implementation, or side surface may count as RMG implementation progress.
- `src/gdextension/src/rmg_native_core.cpp` may parse controlled cases and print blocked no-Godot markers while generation is fail-closed, but it must not own generation behavior.
- Historical/private work is evidence only unless it has been moved into `h3maped_rmg_core` and runs in recovered source order.
- A phase is complete only when the active chain owns the phase inputs, mutations, output buffers, and same-run private-state comparison for the selected scope.
- If this file and a historical note disagree, the status labels in this file win.

## Status Legend

- `ACTIVE_CORE`: implemented in `h3maped_rmg_core` and called by the active source-order chain for Small/Medium one-level land.
- `HELPER_ONLY`: primitive/helper semantics exist in `h3maped_rmg_core`, but recovered caller order is not active.
- `HISTORICAL_PRIVATE`: behavior existed in older private/proxy/diagnostic paths or markdown evidence, but is not current active authority.
- `PENDING_ACTIVE_CHAIN`: recovered or partially recovered behavior still needs to be integrated into `h3maped_rmg_core` in source order.
- `UNSUPPORTED_SCOPE`: outside current Small/Medium one-level land scope.

## Current Supported Scope

- Map sizes: Small `36x36` and Medium `72x72`.
- Levels: one level only.
- Water mode: land/no-water scope only.
- Runtime/public map output: blocked until active generated-cell/object/route/package state is source-owned and same-run validated.
- Windows/Linux product target remains required, but Windows DLL rebuilding is deferred until Linux no-Godot core validation is green for the boundary being changed.

## Source Anchors

- H3MapEd executable: `/root/Downloads/h3maped.exe`.
- SHA-256: `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`.
- Recovered template catalog source: `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json`.
- Active generated catalog: `src/gdextension/src/h3maped_rmg_template_catalog.cpp`.
- Active native core: `src/gdextension/src/h3maped_rmg_core.cpp`.
- Active native core header: `src/gdextension/include/h3maped_rmg_core.hpp`.
- Focused core selftest: `src/gdextension/src/h3maped_rmg_core_selftest.cpp`.

## High-Level Executable Order

The current recovered Small/Medium one-level land order is:

1. Setup object mode: `0x49ecf2`.
2. Template selection and template feed: `0x49f0cd`, `0x4ac597`, `0x4ac552`, `0x4e7276`.
3. Player slot assignment: `0x4ac62a..0x4ac6ec`.
4. Runtime-zone and link seed construction: `0x4a218c`, `0x49b452`, `0x4a1f3b`.
5. Coordinate candidate placement, pruning, and bounding-box rescale: `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, `0x4a19ed`.
6. Source-node footprint construction: `0x4a3a03`, `0x4cc788`, `0x4cc955`, `0x4ccb64`, `0x4ccdfc`, `0x4cca55`.
7. Boundary traversal and span fill: `0x4a2777`, `0x4a2b33`, `0x4a261a`, `0x4a2413`, `0x4a325d`.
8. One-level land footprint/order finalizer: `0x4a3710`, `0x49b61b`, `0x4a3554`.
9. Runtime terrain selection: `0x49b53d`.
10. Terrain repaint/writeout: `0x4a3f27`, `0x4a4025`, `0x4a4082`, `0x4a4142`, `0x4a4150`, `0x4a415a`, `0x4a4163`.
11. TerrainPlacement visual feedback: `0x4bcff5`, `0x4bd099`, `0x4bb681`, `0x4bb74b`, `0x4bad0f`, `0x4bcfc3`, `0x4bce6d`, `0x4bc988`, `0x4bc5f0`, `0x4bbd01`, `0x4bbfcc`, `0x4bc5a3`, `0x49acc5`, `0x49acf6`.
12. Relation/object generated-cell mutation: `0x4a5767`, `0x4a59e2`, `0x49a318`, `0x4a56b6`, `0x4a54a7`, `0x49aa63`, `0x49a932`, `0x49abd6`, `0x49a85d`, `0x49a962`, `0x49cf34`, `0x4aa3e9`.
13. Town/castle object scheduling and placement: `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, `0x49ba89`, `0x540a9c`.
14. Mines, rewards, and object-vector producers: `0x4a9d6a`, `0x4a9911`, `0x4a9641`, `0x4a9c7c`, `0x4aab7e`, `0x4aa354`, `0x4a9f1c`, `0x4aa9b7`, `0x4aa603`, `0x4aa3e9`.
15. Roads/rivers: `0x4ab52a`, `0x4aae7b`, `0x4ab37f`, `0x4b4243`, `0x458a2f`, `0x458893`.
16. Connections, blockers, and guards: `0x4a79a3`, `0x4a79d8`, `0x4a61bc`, `0x4a7605`, `0x4a7312`, `0x4a65a5`, `0x4a5e03`, plus pending `0x4a696b`, `0x4a6cf2`, `0x4a5e73`.
17. Final tile/object writeout: `0x4ad1e3`, `0x49b2b6`, `0x4ad309`, `0x4ad3eb`.

## Phase Ownership Matrix

| Phase | Key functions | Current ownership |
| --- | --- | --- |
| Setup mode | `0x49ecf2` | `ACTIVE_CORE` |
| Template selection/feed | `0x49f0cd`, `0x4ac597`, `0x4ac552`, `0x4e7276` | `ACTIVE_CORE` for catalog selection/feed in current scope |
| Player slots | `0x4ac62a..0x4ac6ec` | `ACTIVE_CORE` |
| Runtime zone/link seeds | `0x4a218c`, `0x49b452`, `0x4a1f3b` | `ACTIVE_CORE` |
| Coordinate placement/rescale | `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, `0x4a19ed` | `ACTIVE_CORE` |
| Source-node footprints | `0x4a3a03`, `0x4ccb64`, `0x4cca55` | `ACTIVE_CORE` |
| Boundary/span fill | `0x4a2777`, `0x4a2b33`, `0x4a261a`, `0x4a2413`, `0x4a325d` | `ACTIVE_CORE` |
| Footprint/order finalizer | `0x4a3710`, `0x49b61b`, `0x4a3554` | `ACTIVE_CORE` for one-level land no-appended-zone behavior; downstream vectors still matter |
| Terrain selection | `0x49b53d` | `ACTIVE_CORE` |
| Terrain repaint | `0x4a3f27`, `0x4a4025`, `0x4a4082`, `0x4a4142`, `0x4a4150`, `0x4a4163` | `ACTIVE_CORE` |
| TerrainPlacement | `0x4bcff5`, `0x4bb74b`, `0x4bad0f`, `0x4bcfc3`, `0x4bce6d`, `0x4bbfcc`, `0x4bc5a3`, `0x49acf6` | `ACTIVE_CORE` |
| Relation/object mutations | `0x4a5767`, `0x49a318`, `0x49aa63`, `0x49a932`, `0x49abd6`, `0x49a85d`, `0x49a962`, `0x49cf34`, `0x4aa3e9` | `HELPER_ONLY` plus historical/private evidence; caller order not active |
| Town objects | `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49ba89` | `HISTORICAL_PRIVATE`; not active package authority |
| Mines/rewards/object vectors | `0x4a9d6a`, `0x4a9911`, `0x4a9641`, `0x4aab7e`, `0x4aa354`, `0x4a9f1c`, `0x4aa9b7`, `0x4aa603`, `0x4aa3e9` | `HISTORICAL_PRIVATE` plus helpers; not active package authority |
| Roads/rivers | `0x4ab52a`, `0x4aae7b`, `0x4ab37f`, `0x4b4243`, `0x458a2f`, `0x458893` | `HISTORICAL_PRIVATE`; current map output blocked |
| Connections/blockers/guards | `0x4a79a3`, `0x4a61bc`, `0x4a7605`, `0x4a7312`, `0x4a65a5`, `0x4a5e03` | `HISTORICAL_PRIVATE`; current active chain blocked before package output |
| Final writeout | `0x4ad1e3`, `0x49b2b6`, `0x4ad309`, `0x4ad3eb` | final-writeout authority known; active output remains blocked by earlier state |

## Private State Inventory

### Generator-Level Fields

| Field | Meaning in current recovery |
| --- | --- |
| `generator+0xed8` | selected color order / player slot setup surface |
| `generator+0xee0` | raw source-owner assignment slots |
| `generator+0xee4` | source-owner to actual player-color mapping |
| `generator+0x10b8` | setup/generator mode written by `0x49ecf2`; drives coordinate pruning and synthetic branch behavior |
| `generator+0x10e0` | runtime-zone vector begin/owner surface in older notes |
| `generator+0x10e4` | runtime source/relation/source-record vector pointer; consumed by relation/object phases |
| `generator+0x10e8` | runtime source/relation/source-record vector end |
| `generator+0x10ec` | runtime source/relation/source-record vector capacity |
| `generator+0x3f4` | boundary-vector append records used by `0x4a2777` |
| `generator+0x14b0` | town/castle coordinate vector consumed by road/river pair-cost phases |
| source zone `+0x41..+0x49` | allowed town mask feeding `0x49b3c1` |
| source zone `+0x84` | terrain-match-to-town flag |
| source zone `+0x85..+0x8c` | allowed terrain mask feeding `0x49b53d` |
| source record `+0x10/+0x14/+0x18` | span seed triple consumed by `0x4a325d` |
| source node raw `+0x00/+0x04` | raw descriptor coordinates |
| source node finalized `+0x1c/+0x20` | finalized descriptor coordinates |

### Active Core Structs

| Struct | Purpose |
| --- | --- |
| `GeneratorSetupModeResult49ecf2` | setup object `+0x44`, mode `+0x10b8`, sentinel-3 RNG handoff |
| `TemplateSelectionRuntimeResult4ac552` | selected template, RNG state, player assignment, runtime seed output |
| `PlayerSlotAssignmentResult4ac62a` | selected colors, raw `+0xee0` slots, mapped `+0xee4` slots |
| `RuntimeZoneSeedInput4a218c` | filtered runtime zone seed with source owner, base size, town/terrain masks |
| `RuntimeLinkSeedInput4a218c` | filtered runtime connection/link seed |
| `CoordinateSeedResult4a218c` | placement steps, bbox rescale, boundary inputs, RNG handoff |
| `RuntimeZoneBoundaryInput4a3a03` | runtime-zone boundary payload plus selected source-record seed |
| `SourceNodeFootprintResult4a3a03` | descriptor nodes, split/bridge/crossing cleanup, per-zone source walks |
| `BoundarySourceCycleHandoff4a2777` | source-cycle handoff into boundary materialization |
| `BoundaryMaterialization4a2777` | private zone words, generated-cell `+0x20`, cell flags, boundary vector, span-fill stats |
| `FootprintFinalizerResult4a3710` | one-level land finalizer/order behavior and relation-vector requirements |
| `RuntimeTerrainSelectionResult49b53d` | per-zone terrain selection and RNG handoff |
| `TerrainRepaintResult4a3f27` | terrain repaint, TerrainPlacement writeback, generated-cell words, terrain scratch |
| `GeneratedCellWordGrid` | six generated-cell word arrays: `+0x10/+0x1c/+0x20/+0x24/+0x28/+0x2c` |

## GeneratedCell Layout And Bits

The generated-cell state is a six-word private grid. It must be treated as one phase-owned private state, not as independent public map fields.

### Initial Values

| Word | Initial/reset behavior |
| --- | --- |
| `+0x10` | `0xffffffff` |
| `+0x1c` | `0x7fbc7fbc` |
| `+0x20` | `0xffff7fbc` before owner/grid mutations |
| `+0x24` | preserved mask `0xc0000548`, value `0x00000548`; later terrain id/art bits are written here |
| `+0x28` | preserves `0x01000000`; default value includes bit 25 and bit 27 |
| `+0x2c` | selected bit 0 cleared by reset |

### Word Meanings And Known Bit Fields

| Word | Known fields |
| --- | --- |
| `+0x10` | projection/coordinate word; reset to `-1`; relation propagation and object projection use it |
| `+0x14` | projection/coordinate word in relation reset helper output, reset to `-1` |
| `+0x18` | projection/coordinate word in relation reset helper output, reset to `-1` |
| `+0x1c` | relation/local gate word; reset by `0x4a5767`; low word can be cleared by `0x49a318`; reset constant `0x7d007d00` after relation reset |
| `+0x20` | zone owner word, local score/projection low word, and owner bytes; `+0x20` byte 2 is used by terrain repaint owner gate; low word is changed by score/projection helpers |
| `+0x24` | terrain id and visual/art row |
| `+0x28` | terrain flags, relation/object action/candidate/occupied bits, member/repaint bits |
| `+0x2c` | bit-0 gate used by candidate/occupied helpers |

### `+0x24` Terrain Fields

| Bits | Meaning |
| --- | --- |
| `0..5` | terrain id written by `0x49acf6` |
| `6..13` | selected visual/art row written by `0x49acf6` |

### `+0x28` Known Bits

| Bit(s) | Constant / meaning |
| --- | --- |
| `12..14` | relation helper bits packed by `0x4a59e2`; mask `0x7 << 12` |
| `15..16` | terrain flags written by `0x49acf6` |
| `22` | `CELL_ACTION_CONTROL_BIT_22`; action/control stamp |
| `25` | `CELL_DECOR_READY_BIT_25`; decor/body readiness/default bit |
| `26` | `CELL_DECOR_CANDIDATE_BIT_26`; decoration candidate bit |
| `27` | `CELL_OCCUPIED_BLOCKED_BIT_27`; occupied/blocked bit |
| `28` | `CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28`; terrain-relation/member eligibility bit |

### `+0x2c` Gate

| Bit | Meaning |
| --- | --- |
| `0` | gate checked by `0x49aa63`, `0x49a932`, and related candidate/occupied helpers; reset clears it |

## Terrain Scratch Word `0x4bad0f`

TerrainPlacement keeps an intermediate scratch word before writing back to generated cells.

| Bits | Meaning |
| --- | --- |
| `0` | dirty marker |
| `1..4` | terrain id |
| `5..11` | selected visual/art row |
| `12` | terrain flag A |
| `13` | terrain flag B |

Final sweep uses `0x4bc5a3` to preserve the current scratch visual record for corrected classes that have no direct bucket.

## Phase Details

### 0. Scope, Size, Water, RNG

Status: `ACTIVE_CORE`.

Functions and helpers:

- `map_width_for_size_class`
- `water_mode_code`
- `size_score`
- `supports_one_level_land_scope`
- `strict_scope_id`
- `strict_scope_label`
- `H3MapedRng::next` / `0x4e7276`

Current behavior:

- Small maps are `36x36`; Medium maps are `72x72`.
- Only one-level land scope is active.
- Unsupported scopes must block without fallback output.

### 1. Setup Mode `0x49ecf2`

Status: `ACTIVE_CORE`.

Function:

- `generator_setup_mode_49ecf2`

Behavior:

- Copies ordinary setup object `+0x44` into `generator+0x10b8`.
- If setup object `+0x44 == 3`, consumes one `0x4e7276` RNG call and stores `rand % 3` as `generator+0x10b8`.
- Hands post-setup RNG state to template selection.

### 2. Template Selection And Runtime Seed Feed

Status: `ACTIVE_CORE` for current scope.

Functions:

- `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b`
- `player_slot_assignment_4ac62a_4ac6ec`
- `runtime_seed_inputs_from_template_records_4a218c_4a1f3b`
- source anchors `0x49f0cd`, `0x4ac597`, `0x4ac552`, `0x4e7276`

Behavior:

- Filters recovered H3MapEd templates by size score, water mode, human/player counts, and source-owner masks.
- Selects from the accepted vector through H3MapEd RNG.
- Builds runtime-zone seeds and link seeds from typed template records.
- Preserves source zone id, source index, H3 zone word id, source bucket, source owner, source base size, town masks, and terrain masks.

### 3. Player Slots `0x4ac62a..0x4ac6ec`

Status: `ACTIVE_CORE`.

Private state:

- `generator+0xed8`: selected color order.
- `generator+0xee0`: raw source-owner assignment slots.
- `generator+0xee4`: mapped source-owner to player-color slots.

Behavior:

- Assigns requested human/total players to source-owner slots based on recovered owner masks.
- Preserves unassigned slots as `-1`.

### 4. Coordinate Placement And Runtime Zone Materialization

Status: `ACTIVE_CORE`.

Functions:

- `coordinate_seed_runtime_zone_boundary_inputs_4a218c_4a1f3b_4a19ed`
- `coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710`
- source anchors `0x4a218c`, `0x49b452`, `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, `0x4a19ed`

Behavior:

- Builds coordinate candidates from runtime links and spacing rules.
- Applies `generator+0x10b8` pruning divisor:
  - mode `0`: divisor `5`;
  - mode `1`: divisor `6`;
  - other modes: divisor `7`.
- Computes prune span from `min(min_source_base_size * map_width, min_source_base_size * map_height)`.
- Selects placement candidates with H3MapEd RNG.
- Rescales placed zones through bounding-box logic.
- During first-pass insertion, executes `0x49b3c1` town choice before coordinate placement:
  - source zone `+0x41..+0x49` gives allowed town mask;
  - if mask is non-empty, one RNG value picks the Nth enabled original H3 town id;
  - if mask is empty, town choice remains `-1`.

### 5. Source-Node Footprints `0x4a3a03 -> 0x4cca55`

Status: `ACTIVE_CORE`.

Functions:

- `build_source_node_footprints_4a3a03_4ccb64_4cca55`
- source anchors `0x4a3a03`, `0x4cc788`, `0x4cc955`, `0x4ccb64`, `0x4ccdfc`, `0x4cca55`

Behavior:

- Initializes recovered source-node rectangle shape.
- Inserts runtime-zone split nodes.
- Performs bridge insertion and crossing cleanup.
- Finalizes descriptor nodes.
- Emits per-zone source walks with:
  - descriptor node indexes;
  - pair/next/previous indexes;
  - raw `+0x00/+0x04` coordinates;
  - finalized `+0x1c/+0x20` coordinates;
  - payload and next-pair payload metadata.

### 6. Boundary Traversal And Span Fill

Status: `ACTIVE_CORE`.

Functions:

- `boundary_cycles_from_source_handoffs_4a2777`
- `materialize_boundary_cycles_4a2777`
- `materialize_boundary_source_handoffs_4a2777_4a325d`
- `materialize_boundary_owner_grid_from_runtime_zone_footprints_4a3a03_4cca55_4a2777_4a325d_4a3710`
- `clip_point_4a2b33`
- `boundary_line_writer_4a261a`
- `boundary_randomized_line_writer_4a2413`
- `apply_line_trace_to_zone_buffer_4a2777`
- `span_fill_4a325d`

Private state:

- `private_zone_words`
- `generated_cell_word_0x20`
- `cell_flags`
- `BoundaryVector4a2777`

Recovered append callsites:

| Callsite | Meaning |
| --- | --- |
| `0x004a28c8` | rectangle vertex 0 |
| `0x004a28dc` | rectangle vertex 1 |
| `0x004a28f3` | rectangle vertex 2 |
| `0x004a2907` | rectangle vertex 3 |
| `0x004a2990` | selected clipped endpoint |
| `0x004a2adc` | wrap/continuation endpoint |
| `0x004a2b1e` | final clipped endpoint |

Behavior:

- Converts source-node walks into boundary cycles.
- Preserves source-record vector index and source-record seed triple.
- Applies recovered owner gate before source-edge writes: if `next_pair_payload <= zone_word`, the segment is skipped.
- Uses clipped source-edge endpoints, not flattened one-point border proxies.
- Writes zone owner into private zone words and generated-cell `+0x20`.
- Tracks repaint/member flags in `cell_flags`.
- Runs span fill from selected source-record `+0x10/+0x14/+0x18` seed.
- Missing source-record seed is a blocker/counter, not a fallback coordinate.

### 7. One-Level Land Footprint/Order Finalizer

Status: `ACTIVE_CORE` for one-level land no-appended-zone behavior; downstream relation-order vectors still matter.

Functions:

- `footprint_finalizer_4a3710`
- source anchors `0x4a3710`, `0x49b61b`, `0x4a3554`

Behavior:

- In current one-level land scope, does not append synthetic runtime zones.
- Resets/rebuilds per-zone ordering required by later relation consumers.
- Does not by itself materialize generated-cell words.

Known active-chain issue:

- Runtime-zone `+0xc4` adjacency/order and `+0x3e8` vectors are not yet fully represented as downstream relation-order state in the current active generated-cell parity claim.

### 8. Runtime Terrain Selection `0x49b53d`

Status: `ACTIVE_CORE`.

Function:

- `runtime_terrain_selection_49b53d`

Data:

- town-to-terrain table `0x540908 = {2, 2, 3, 7, 0, 0, 5, 4, 2}`.
- source zone `+0x84`: match-to-town flag.
- source zone `+0x85..+0x8c`: allowed terrain mask.

Terrain ids:

| ID | Terrain |
| --- | --- |
| `0` | dirt |
| `1` | sand |
| `2` | grass |
| `3` | snow |
| `4` | swamp |
| `5` | rough |
| `6` | cave |
| `7` | lava |
| `8` | water |

Behavior:

- If match-to-town is true, selects terrain from town choice through `0x540908`.
- Otherwise consumes one RNG call and selects among allowed terrain flags.
- Terrain id `6` is eligible only on level `1`.
- If level is `1` and selected terrain is not lava `7`, the selected terrain is forced to `6`.

### 9. Terrain Repaint `0x4a3f27`

Status: `ACTIVE_CORE`.

Function:

- `terrain_repaint_4a3f27`

Source anchors:

- `0x4a3f27`, `0x4a4025`, `0x4a4082`, `0x4a4142`, `0x4a4150`, `0x4a415a`, `0x4a4163`

Behavior:

- Starts with full-map water terrain repaint (`terrain id 8`).
- Skips per-zone repaint for water zones.
- Uses generated-cell `+0x20` byte 2 as owner gate, matching `0x4a4142`.
- Uses generated-cell `+0x28 >> 28 & 1` as member/repaint gate, matching `0x4a4150`.
- Passing cells write terrain id through `0x49acf6`.
- Feeds TerrainPlacement visual row/flag selection.

### 10. TerrainPlacement

Status: `ACTIVE_CORE`.

Functions:

- `0x4bcff5` visual table/toolkit setup.
- `0x4bd099` / `0x4bb681` rectangle/delegated repaint walkers.
- `0x4bb74b` live visual write.
- `0x4bad0f` scratch packing.
- `0x4bcfc3` visual row selection.
- `0x4bce6d` visual row bucket/classifier helper.
- `0x4bc988` candidate gate.
- `0x4bc5f0` queue drain.
- `0x4bbd01` retouch.
- `0x4bbfcc` final sweep.
- `0x4bc5a3` final-sweep current-record preservation.
- `0x49acf6` generated-cell terrain/art/flag writeback.

Recovered static visual row tables:

| Table | Rows |
| --- | --- |
| `0x543108` normal | `79` |
| `0x543380` dirt | `46` |
| `0x5434f0` sand | `24` |
| `0x5435b0` water | `33` |
| `0x542f88` rock | `48` |
| total | `230` |

Behavior:

- Full-map water visual prefill runs first.
- Owner/member-gated terrain repaint writes visual rows and flags.
- Set-A/set-B queue feedback, retouch, candidate gates, and neighbor seeding run inside the active core.
- Final whole-map sweep revisits every cell and applies recovered class corrections.
- If a corrected class has no direct visual row bucket, final sweep preserves the current scratch visual record through `0x4bc5a3`.
- `0x49acf6` writes terrain id/art bits to `+0x24` and terrain flags to `+0x28`.

### 11. Relation/Object Generated-Cell Mutation

Status: `HELPER_ONLY` in active core; caller order is `PENDING_ACTIVE_CHAIN`.

Functions with helper semantics in `h3maped_rmg_core`:

- `generated_cell_4a5767_reset_cell`
- `generated_cell_4a5767_reset_force_word_0x1c`
- `generated_cell_49a318_clear_source_word_0x1c`
- `generated_cell_4a59e2_pack_word_0x1c`
- `generated_cell_4a59e2_pack_word_0x20`
- `generated_cell_4a59e2_pack_word_0x28`
- `generated_cell_4a56b6_projection_word20`
- `deplete_generated_cell_scores_4a54a7`
- `generated_cell_49aa63`
- `generated_cell_49a932`
- `generated_cell_49abd6_action_stamp`
- `generated_cell_49abd6_body_reject_stamp`
- `generated_cell_49a85d_stamp`
- `generated_cell_49a962_word24`
- `generated_cell_49a962_terrain`
- `generated_cell_49cf34_attach_word28`
- `generated_cell_4aa3e9_reward_word28`
- `generated_cell_49a1d8_valid_word24`
- `generated_cell_49a1d8_valid_terrain`

Source anchors:

- `0x4a5767`
- `0x4a59e2`
- `0x49a318`
- `0x4a56b6`
- `0x4a54a7`
- `0x49aa63`
- `0x49a932`
- `0x49abd6`
- `0x49a85d`
- `0x49a962`
- `0x49cf34`
- `0x4aa3e9`

Known mutation surface:

- Resets relation fields in `+0x1c`.
- Propagates source/projection fields in `+0x10/+0x14/+0x18/+0x1c/+0x20/+0x28`.
- Depletes score/distance low-word fields in `+0x20`.
- Sets/clears candidate bit 26 and occupied/blocked bit 27.
- Sets action/control bit 22.
- Uses `+0x2c` bit 0 gates.
- Attaches reward/object mutation bits through `0x49cf34` and `0x4aa3e9`.

What is not complete:

- The active chain does not yet call these helpers through the exact recovered relation/object caller sequence over the live post-TerrainPlacement generated-cell arrays.
- Prior commits contain historical/private relation-vector and bit-state work. That work must be migrated into `h3maped_rmg_core`; it must not remain a separate implementation surface.

### 12. Town/Castle Object Placement

Status: `HISTORICAL_PRIVATE` / `PENDING_ACTIVE_CHAIN` for package authority.

Source anchors:

- `0x4a8d2c`
- `0x4a8db2`
- `0x4a93a2`
- `0x49aa93`
- `0x49a09c`
- `0x49b3c1`
- `0x49ba89`
- `0x540a9c`

Known behavior from prior private evidence:

- Schedules town/castle candidates.
- Projects direct town records against recovered town footprint masks.
- Seeds object vectors and action/body bits through generated-cell helpers.
- Produces town/castle coordinate records consumed by later road vector work.

Current rule:

- Do not expose package towns from this phase until active object-vector producers and generated-cell mutations are owned in `h3maped_rmg_core`.

### 13. Mines, Rewards, Generic Object Vectors

Status: `HISTORICAL_PRIVATE` plus helper semantics; not current public object authority.

Source anchors:

- `0x4a9d6a`
- `0x4a9911`
- `0x4a9641`
- `0x4a9c7c`
- `0x4aab7e`
- `0x4aa354`
- `0x4a9f1c`
- `0x4aa9b7`
- `0x4aa603`
- `0x4aa3e9`
- `0x4ae1fd`
- `0x4ae52a`
- value vfuncs `0x49c54d`, `0x49c64b`, `0x49c849`, `0x49ca8b`, `0x49cb60`, `0x49cd97`
- create vfunc family `0x49c553..0x49cdb1`

Known behavior from prior private evidence:

- Mine phase carries seven mine minimum/density categories.
- Reward phase carries treasure-band scheduler/budget/value selection.
- `0x4a9f1c` scans value-banded candidates and weighted choices through `0x4aa192`.
- `0x4aa9b7..0x4aab7b` scans generated-cell owner/score candidate cells and randomly selects reward coordinates.
- `0x4aa603` filters reward templates.
- `0x4aa3e9` mutates generated-cell/object state for rewards.
- `0x4a54a7` depletes local score fields.

Current rule:

- This phase must be reintroduced as active `h3maped_rmg_core` generation, not as package adoption or final-map tuning.

### 14. Roads And Rivers

Status: `HISTORICAL_PRIVATE` / `PENDING_ACTIVE_CHAIN`.

Source anchors:

- `0x4ab52a`
- `0x4aae7b`
- `0x4ab37f`
- `0x4b4243`
- `0x458a2f`
- `0x458893`
- final tile staging through `0x49b2b6`

Known behavior from prior private evidence:

- Consumes town/castle coordinate vector `generator+0x14b0`.
- Evaluates private pair costs through `0x4aae7b`.
- Uses recovered threshold `0x7530`.
- Road geometry/writeback uses road toolkit behavior and art/flip classifiers.
- One-level land final writeout currently carries zero river bytes unless broader river/water scope is selected.

Current rule:

- Do not treat town-only coordinates or approximate road counts as road parity.

### 15. Connections, Blockers, Guards

Status: `HISTORICAL_PRIVATE` / `PENDING_ACTIVE_CHAIN`.

Source anchors:

- `0x4a79a3`
- `0x4a79d8`
- `0x4a61bc`
- `0x4a7605`
- `0x4a7312`
- `0x4a65a5`
- `0x4a5e03`
- `0x4a5767`
- `0x49a318`
- pending or source-backed exclusion needed: `0x4a696b`, `0x4a6cf2`, `0x4a5e73`

Known behavior from prior private evidence:

- Uses relation projection and generated-cell owner/terrain state to build transition vectors.
- Selects same-level endpoints through `0x4a61bc`.
- Uses second-pass fallback through `0x4a7605` / `0x4a7312`.
- Scales blocker/guard values through `0x4a65a5`.
- Materializes guard records through `0x4a5e03`.

Current rule:

- Package blocker/guard output must come from this active source-order chain. Synthetic package blockers, density gates, or mask trimming are invalid.

### 16. Final Tile/Object Writeout

Status: final writeout authority known; active output remains blocked by earlier private-state gaps.

Source anchors:

- `0x4ad1e3`
- `0x49b2b6`
- `0x4ad309`
- `0x4ad3eb`

Known tile bytes:

| Byte | Meaning |
| --- | --- |
| `0` | terrain id |
| `1` | terrain art/visual row |
| `2` | river byte |
| `3` | river byte / variation |
| `4` | road byte |
| `5` | road byte / variation |
| `6` | flags: terrain flags plus road flip bits |

Current rule:

- Final writeout may be used as comparison authority. It must not hide earlier generated-cell/object-vector drift.

## Current Active Blocker

The current blocker is not missing helper semantics. It is active-chain integration:

1. Move relation/object caller-order behavior into `h3maped_rmg_core` after TerrainPlacement.
2. Apply it to the live generated-cell arrays in recovered source order.
3. Remove unconditional blocker strings only when the active chain executes the phase.
4. Run same-run private-state comparison for checkpoint 2.
5. Only then allow route/object/package consumers to use the generated-cell checkpoint.

## Invalid Work Patterns

- Implementing a phase in `rmg_native_core.cpp` and calling that native RMG progress.
- Adding a new report, gate, snapshot, or diagnostic and calling the phase implemented.
- Reconstructing source behavior from final-map count deltas.
- Using density scalars, brute-force retries, map-output patching, or package-time mask trimming.
- Translating source H3MapEd object semantics into project object categories before the source phase is proven.
- Reclaiming historical private/proxy work as active authority without moving it into `h3maped_rmg_core`.

## Required Next Implementation Slice

The next implementation slice must be:

1. Read prior commits and historical/private evidence for relation/object mutation behavior.
2. Extract only source-backed caller-order behavior.
3. Port it into `h3maped_rmg_core` after TerrainPlacement.
4. Keep one generated-cell state, not a side replay.
5. Validate with the standalone no-Godot CLI and selftest.
6. Commit only after the active chain, not a diagnostic surface, owns the phase.

