# Native RMG Generated-Cell Mutation Chain

Document role: source-backed implementation ledger for the H3MapEd generated-cell mutation chain.

This file exists to stop native RMG checkpoint 2 from being treated as complete before the full H3MapEd cell mutation chain is actually implemented. It is not a parity report and it is not a final-map comparison target.

## Current Conclusion

Native must not emit a comparable pre-`0x4a4c8e` generated-cell checkpoint while it only owns reset words plus boundary owner words.

The generated-cell payload is not just:

1. `0x49a072 -> 0x499ea3` reset all generated-cell words.
2. `0x4a2777 -> 0x4a325d` write zone owner into `+0x20`.

That mixture produces a false surface: `+0x10`, `+0x1c`, `+0x24`, `+0x28`, and `+0x2c` remain reset/default even though H3MapEd mutates some of them before object/relation/route consumers. Native can expose owner-word materialization as a support artifact, but it must not call the combined six-word grid a comparable private-state checkpoint until the phases below are owned end to end.

## Required Source-Order Phases

### 1. Generated-cell reset

Status: source-backed and implemented as a helper.

Addresses:

- `0x49a072`
- `0x499ea3`

Native implementation:

- `src/gdextension/src/h3maped_rmg_core.cpp::generated_cell_grid_reset_0x49a072`
- `src/gdextension/src/h3maped_rmg_core.cpp::generated_cell_initializer_0x499ea3`

Mutation surface:

- Constructs and resets `+0x04/+0x08` as a known-empty object-reference vector.
- Initializes `GeneratedCell+0x10`.
- Initializes `GeneratedCell+0x1c`.
- Initializes `GeneratedCell+0x20`.
- Preserves/initializes selected bits in `GeneratedCell+0x24`.
- Preserves/initializes selected bits in `GeneratedCell+0x28`.
- Clears selected bits in `GeneratedCell+0x2c`.

Implementation rule: reset values are valid only immediately after reset. They are not valid substitutes for later phase-owned values.

### 2. Runtime template/zone setup before cell mutation

Status: source-backed for the current Small/Medium one-level land setup/catalog path, but it is input preparation rather than direct generated-cell mutation.

Addresses:

- `0x49ecf2`
- `0x4ac552`
- `0x4a218c`
- `0x4a1f3b`
- `0x4a19ed`
- `0x4a3a03`
- `0x4ccb64`
- `0x4cca55`

Native implementation:

- `generator_setup_mode_49ecf2`
- `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b`
- `coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710`

Mutation surface:

- Produces runtime-zone seeds, links, source-cycle descriptors, and boundary handoffs consumed by later generated-cell mutation.
- Does not by itself complete generated-cell private-state parity.

Implementation rule: if setup/catalog/runtime-zone inputs are absent, native must block. It must not use stale snapshots, reconstructed seed fallbacks, or compacted runtime-zone substitutes.

### 3. Boundary and span-fill owner-grid materialization

Status: source-backed helper implementation exists, but current output is only an owner-word support artifact.

Addresses:

- `0x4a2777`
- `0x4a325d`
- `0x4a2b33`
- `0x4a261a`
- `0x4a2413`

Native implementation:

- `materialize_boundary_cycles_4a2777`
- `materialize_boundary_source_handoffs_4a2777_4a325d`
- `span_fill_4a325d`

Mutation surface:

- Writes zone ownership into private zone words.
- Writes zone ownership into `GeneratedCell+0x20`.
- Writes the recovered repaint/member marker into `GeneratedCell+0x28` bit 28 when `0x4a261a/0x4a325d` executes the `0x4a2e91` `OR byte ptr [cell+0x2b], 0x10` path.
- Tracks the same reserved-write condition in the local `cell_flags` buffer only as a native support mirror; repaint consumes generated-cell `+0x28`, not the mirror.

Known blocker:

- The owner-grid result alone is not a comparable pre-`0x4a4c8e` generated-cell checkpoint. H3MapEd continues mutating terrain, relation, object, and flag fields after this owner materialization.

Implementation rule: expose this as owner-grid materialization only. Do not combine it with reset `+0x24/+0x28/+0x2c` and call that full private state.

### 4. One-level land footprint/order finalizer

Status: source-backed for the one-level land no-appended-zone branch.

Address:

- `0x4a3710`

Native implementation:

- `footprint_finalizer_4a3710`

Mutation surface:

- For the supported one-level land no-appended-zone path, it does not materialize generated-cell words.
- It resets/rebuilds relation/order vectors required by later relation consumers.

Known blocker:

- Runtime-zone `+0xc4` adjacency/order and runtime-zone `+0x3e8` vectors are not yet materialized as downstream relation-order state.

Implementation rule: running this function proves ordering, not generated-cell parity.

### 5. Terrain selection and terrain repaint/writeout

Status: source-backed terrain id selection/repaint is implemented for the current one-level land Small/Medium chain and feeds the active TerrainPlacement visual row/flag writeback.

Addresses:

- `0x49b53d`
- `0x4a3f27`
- `0x4a4025`
- `0x4a4082`
- `0x4a415a`

Evidence:

- `.artifacts/rmg_recovery/ghidra_phase_frontier_decompile_20260611/target_004a3f27_FUN_004a3f27.txt`
- `src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp::terrain_cell_writeout_4a3f27_report`

Native implementation:

- `runtime_terrain_selection_49b53d`
- `terrain_repaint_4a3f27`
- `docs/native-rmg-terrain-selection-repaint-chain.md`

Mutation surface:

- Consumes the `0x4a325d` zone-word buffer.
- Applies full-map water terrain first.
- Repaints non-water runtime-zone cells.
- Uses an owner-byte gate at `0x4a4142`.
- Uses a repaint/member flag gate at `0x4a4150`.
- Assigns terrain id bits for `GeneratedCell+0x24`.

Known blocker:

- This phase alone is not a full checkpoint because later TerrainPlacement and relation/object phases also mutate generated-cell words. TerrainPlacement is now implemented in the next phase; later relation/object caller order remains pending.

Implementation rule: terrain id repaint may feed TerrainPlacement, but native still keeps `generated_cell_private_state_comparable=false` until later relation/object generated-cell mutation caller order is implemented and same-run validated.

### 6. TerrainPlacement art/flag classifier and generated-cell writeback

Status: source-backed and implemented in the active shared native core for the current one-level land Small/Medium chain.

Addresses:

- `0x4bcff5`
- `0x4bd099`
- `0x4bb681`
- `0x4bb74b`
- `0x4bad0f`
- `0x4bcfc3`
- `0x4bce6d`
- `0x4bc988`
- `0x49acc5`
- `0x49acf6`

Evidence:

- `.artifacts/rmg_recovery/ghidra_private_state_terrain_writer_dump/target_0049acf6_FUN_0049acf6.txt`
- `.artifacts/rmg_recovery/ghidra_visual_selector_dump_20260615/target_004bcff5_FUN_004bcff5.txt`
- `.artifacts/rmg_recovery/ghidra_visual_selector_dump_20260615/target_004bd099_FUN_004bd099.txt`
- `.artifacts/rmg_recovery/ghidra_visual_selector_dump_20260615/caller_004bb74b_FUN_004bb74b.txt`
- `.artifacts/rmg_recovery/ghidra_visual_selector_dump_20260615/caller_004bcfc3_FUN_004bcfc3.txt`
- `.artifacts/rmg_recovery/ghidra_visual_selector_dump_20260615/target_004bce6d_FUN_004bce6d.txt`
- `.artifacts/rmg_recovery/ghidra_visual_selector_dump_20260615/target_004bad0f_FUN_004bad0f.txt`
- `src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp::terrain_cell_writeout_4a3f27_report`
- `docs/native-rmg-terrain-placement-chain.md`

Native implementation:

- embedded recovered visual rows for tables `0x543108`, `0x543380`, `0x5434f0`, `0x5435b0`, and `0x542f88`;
- recovered terrain relation/classifier and row bucket selection;
- recovered `0x4ba868` toolkit range slots, `0x4ba91d` complex neighbor probe, `0x4baa81` simple/rock neighbor rejection, and `0x4ba938` base-row probability selection;
- recovered scratch packing for `0x4bad0f`;
- recovered generated-cell writeback through `0x49acf6`;
- recovered live feedback queue and final sweep surface for `0x4bb74b/0x4bc5f0/0x4bbfcc`;
- recovered final-sweep current-record preservation through `0x4bc5a3` for corrected classes without direct visual buckets;
- focused native selftest coverage in `src/gdextension/src/h3maped_rmg_core_selftest.cpp`.

Mutation surface:

- `0x49acf6` writes `GeneratedCell+0x24` terrain id bits `0..5`.
- `0x49acf6` writes `GeneratedCell+0x24` terrain art bits `6..13`.
- `0x49acf6` writes `GeneratedCell+0x28` terrain flag bits `15..16`.

Known blockers:

- No known row-table/toolkit-vfunc blocker remains for the active one-level land Small/Medium path.
- The focused same-run Medium payload still blocks at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`; remaining TerrainPlacement queue/final-sweep order drift is not ruled out until phase/private-state comparison proves it.
- Full checkpoint parity is still blocked by later relation/object generated-cell mutation caller order in phase 7.

Implementation rule: TerrainPlacement output may be used as active support state, but it still must not be called a comparable pre-`0x4a4c8e` checkpoint until the later relation/object caller order is source-owned and same-run validated.

### 7. Relation/object candidate, occupied, action, and score mutations

Status: the active shared native workflow now owns the source-order `0x4a8c15 -> 0x4a5767` bridge relation-normalization call after the recovered post-`0x4a4c8e` cleanup scan and `0x4a4913` relation-vector loop, the one-level-land `0x4a4fc5` water-edge scan including source-water candidate handling, mine/resource materialization, reward/guard materialization, the source-backed `0x49eb8d -> 0x49e700` decorative dispatch, source-backed `0x4a79a3` connection-tail replay, the source-backed `0x4ab52a` road/river object-adjacency pair scan, the recovered `0x4ab37f -> 0x4b4243` road toolkit, the recovered `0x4ad1e3 -> 0x49b2b6` final tile-cell stream, the recovered generated-object definition/index table prefix, the recovered `0x4ad309/0x4ad318` generated-object count header write, and the recovered `0x4ad3eb` generated-object two-pass order for the focused Small/Medium one-level land cases. The earlier native stop that treated zero successful direct `0x4aa9b7` reward/guard commits as a hard phase gate was a native-only guard; recovered `0x4ac552` continues after `0x4aab7e`, so native now continues while preserving the zero-commit detail as a parity diagnostic. Decorative dispatch now scans recovered `0x54092c` source rows, applies `rand_trn.txt` terrain-score filtering, replays recovered `0x49e1bf` scoring, appends positive candidate/weight entries (`0x49e904`/`0x49e91f`), selects by weighted `0x49e9ad` RNG, allocates/initializes selected objects (`0x5044b1`/`0x49ba89`), carries `0x49b89c` object-record local score-cache storage for source-carried object records, uses that cache for ref-bearing `0x49e1bf` overlap/adjacent score adjustments, and replays the recovered `0x4ae20e/0x4ae23e` coordinate worklist until `0x49eb50` drain. The post-commit rectangle scan now clears bit26 through `0x49eaf1`, appends coordinates through `0x49eb01`, and the `0x49eb8d` pass3 stamps eligible cells through `0x49a932(true)`. Road replay now carries recovered generator `+0x14b0` road-coordinate records from the source-backed `0x4a901a` and `0x4a93a2` allocation callsites, selects the road type RNG in `0x4ab52a`, runs `0x4aae2f` path-state resets, seeds `0x4aae7b` low-word path costs/predecessors, marks road type bits through `0x49aec5`, replays `0x458e61` neighbor/line visits, classifies road shape through `0x458893`, chooses final road art through `0x458a2f` / `0x4e7276`, and stages private `0x49b2b6` road-overlay arrays. Final tile writeout now emits the source seven-byte cell stream from generated-cell `word_0x24` and `word_0x28`; generated object definitions no longer use the old 426-row source-list proxy and now follow recovered `0x4ad1e3` order: two static definitions from generator `+0x4a8/+0x7f8`, then only active descriptor wrappers whose recovered `+0x08` reference count is positive, emitted through the preserved `0xe8` wrapper-bucket order and indexed from `2` onward. Generated object payloads resolve table indexes through selected wrapper identity first, with unique source-record fallback only when that selected wrapper was not carried; final object pass split reads the source-initialized `0x57c648 -> 0x598300` table byte at `type*16+0x0c` from the `0x52fcf0` initializer list and separates the `0x4ad36f` flagged loop from the `0x4ad3b1` unflagged loop. The focused no-Godot Medium seed-10 setup-0 run now reaches ordered final payload assembly, writes 169 definitions (2 static + 167 active wrappers), 9792 definition bytes, 640 generated objects, and 8212 serialized object-payload bytes. It still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile bytes are 36288 vs 36288 with first mismatch offset 1 `native=57` vs `h3maped=54`; generated-object payload remains 8212 vs 17057 bytes with first mismatch offset 0 `native=35` vs `h3maped=2`. Field-backed `0x4ad3eb` serializer bodies encountered by the focused case are ported; unencountered complex serializer bodies still fail closed if reached. The current cache body-mask adoption is bounded to the native catalog's existing `.msk` footprint fields until later same-run/final-payload parity proves whether independent descriptor `+0x3c` separation matters.

Addresses:

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

Native helpers:

- `apply_materialization_bridge_relation_normalization_0x4a5767` in the single `h3maped_rmg_core` driver after `0x4a4913`.
- `materialization_bridge_water_edge_writer_0x4a4fc5` in the single `h3maped_rmg_core` driver after `0x4a5767`.
- `generated_cell_4a5767_reset_cell`
- record-level `generated_cell_4a5767_reset_projection`
- `generated_cell_49a318_clear_source_word_0x1c`
- record-level `generated_cell_49a318_clear_source_projection`
- `relation_high_owner_propagation_49a318` for source-backed relation-owner coordinate seed flood and owner-high byte writes.
- `deplete_generated_cell_scores_4a54a7`
- record-level `generated_cell_49a1d8_valid_record`
- record-level and legacy word-array `generated_cell_49aa63`
- record-level and legacy word-array `generated_cell_49a932`
- record-level and legacy word-array `generated_cell_49abd6_action_stamp`
- record-level and legacy word-array `generated_cell_49abd6_body_reject_stamp`
- `generated_cell_49a85d_stamp`
- `generated_cell_49a962_word24`
- `generated_cell_49a962_terrain`
- `generated_cell_object_reference_removal_0x499ee8`
- `generated_cell_49cf34_attach_word28`
- `generated_cell_4aa3e9_reward_word28`
- `endpoint_materialization_4a5e73` for the recovered explicit-input endpoint helper contract only.
- `object_footprint_commit_4a54a7` for the recovered explicit-call object-footprint commit afterstate only.
- `source_object_descriptor_join_0x4903e8` and `object_materialization_prep_from_descriptor_join_0x4a8db2_0x4a901a` for recovered descriptor/source join prep and explicit copied-source object commit prep only.
- `source_order_object_placement_0x4a93a2` and `source_order_object_dispatcher_0x4a8d2c` for recovered exact-input direct source-order branch/callee behavior only.

Mutation surface:

- Mutates relation/reset fields in `+0x1c`, high/low parts of `+0x20`, and selected `+0x28` bits.
- `0x4a5767` record helper writes projection triple `+0x10/+0x14/+0x18` to `-1`, writes the reset `+0x1c`, packs `+0x20` byte3, and clears `+0x28` bits 12..14 from source words.
- `0x49a318` record helper clears source `+0x1c` low word and resets projection triple `+0x10/+0x14/+0x18` to `-1`.
- `0x49a318` high-owner propagation now seeds from recovered relation-owner coordinates, flood-fills materialized non-rock generated cells in recovered neighbor order, clears the source projection, writes same-owner projection triples and `+0x1c` low words, and writes cross-owner `+0x1c` high words, `+0x28` direction bits, and source owner into `GeneratedCell+0x20` byte3 when crossing low-owner channels. It also resolves `+0x28` bit22 object-reference cells through object-record descriptor type `+0x1c` and the recovered `0x598300` metadata policy bytes `+0/+1/+2`, applying the five-direction source policy and candidate rejection gates before the normal same-owner/cross-owner writes.
- Sets/clears candidate and occupied bits.
- Sets action/control bits.
- Uses `+0x2c` gates.
- Tracks `+0x2b` bit `0x02` knowledge at record level and clears it on recovered `0x49abd6` body-reject behavior.
- Depletes score/distance fields in `+0x20`.
- `0x4a5e73` consumes generator-level endpoint pointer vectors and byte-state/cursor state: a missing `+0xd8/+0xdc` key returns `-1`, a missing `+0xc8/+0xcc` key returns `0`, and the accepted path clears low five bits of repeated generated-cell `+0x2c`, sets `+0x28` bit27, clears bit26, marks `+0x1104[old +0xf5c]`, then advances `+0xf5c` through marked byte-state entries.
- `0x4a606b` explicit-input helper now applies the recovered connection-region writer contract: scan the clipped 3x3 rectangle, consume reset-time known-empty object-reference vectors, call `0x49aa63(true)`, pack the low-nibble source into `+0x2c` bits 1..4 with bit0 set, then clear low five `+0x2c` bits and call `0x49a932(true)` on the projected target cell when the source projection triple is known. Live source-order post-materialization vector contents remain blocked.
- `0x4a5a23` now applies the recovered projected-chain contract in both paths: gate on `+0x1c` low word `(0, 0x7530)`, execute the `+0x2c` bit0 object-materialization branch through `0x4a9e40` source selection, `0x4af785` wrapper/source-pair state, `0x49ba89` `0x540a74` object-record identity, low-five-bit `+0x2c` clear, and `0x4a54a7` vtable-slot `+0x04` commit when generator object state/RNG are supplied; otherwise set bit27/clear bit26 on the mapped cell, optionally clear nearby same-owner `+0x2b` bit `0x04` when cleanup is not suppressed, and follow the projection triple while the next low word remains positive.
- `0x4a54a7` explicit-call helper now applies the recovered object-footprint commit afterstate: append the object record key to generator `+0xec4/+0xecc`, append it to the target cell object-reference vector when prior vector contents are known, increment generator `+0x1110[descriptor+0x1c]`, increment the owning relation vector `+0x44[descriptor+0x1c]` from the descriptor-offset source cell owner byte when that owner is concrete, set target `+0x28` action/occupied bits, and run the descriptor `+0x29` projection score-depletion wave from candidate coordinates minus descriptor `+0x2c/+0x30`. The descriptor-offset source cell is the cell whose `+0x20` low word is cleared directly; the target cell is lowered by the projection wave and only becomes zero when that source cell is also the target cell.
- `0x4a7312` endpoint candidate filtering uses `GeneratedCell+0x20` byte3 as the relation/class gate before the recovered `0x49aa93` eligibility checks. Generic object/reward candidate filtering still uses the lower owner byte path where recovered; the endpoint byte3 gate is separate and is covered by the focused selftest.
- `0x499ee8` record helper now applies the recovered object-reference removal contract for explicit inputs: scan the generated-cell object-reference vector for the object record key, remove the matching entry, and when the vector becomes empty clear `+0x28` bit22, set `+0x28` bit25, and reset the low word of `+0x20` to `0x7fbc` while preserving the high word. The source-order callers `0x4add76` and `0x4af910` are still not ported, so this helper must not be treated as live object materialization parity.
- `0x4903e8` explicit prep now joins recovered target contexts `45/53/54/79` to selected copied `0x4c` source records through `0x4af785`; when that join creates a new `+0xedc` source pair, native preserves descriptor-join context on the pair for later source-order replay. Explicit materialization prep carries that source identity into `0x4a54a7` only when a source-owned object-record key is supplied. Non-`0x4903e8` scan-consumer pairs remain marked without descriptor context.
- `0x4a8db2` source-order scheduler replay now owns recovered exact-input behavior for source-backed preserved `+0xedc` pairs: pair `+0x00/+0x04` payload gating, direct prepass call order over source fields `+0x24/+0x20/+0x34/+0x30`, recovered lane arguments into `0x4a901a`, weighted density order `+0x2c/+0x28/+0x3c/+0x38`, threshold formula, weighted lane score/increment order, tie behavior, and disable-on-false. The active native chain now replays descriptor-joined non-type98 `+0xedc` pairs through this path when their relation/key/anchor context and copied source count/density fields are present. Live descriptor producers/raw field capture for every real source pair remain pending.
- `0x4a901a` weighted candidate scan now owns the recovered local-vector behavior for exact source-backed inputs: generated-cell owner-byte match, low-word value-floor check, `0x49aa93` eligibility, `0x4ae52a` clear when a higher low-word floor is found, `0x4ae1fd` coordinate append, `0x4e7276 % count` selection, `0x4a93a2` allocation, and `0x4a54a7` weighted commit.
- `0x4a8d2c -> 0x4a93a2` direct object placement now owns recovered exact-input branch/callee behavior for source-backed inputs: branch priority over source fields `+0x24`, `+0x20`, `+0x34`, and `+0x30`; direct `0x4a93a2` candidate scan from explicit bounds; owner-byte filtering; nearest-distance local-vector clearing/appending from initial `0x7d00`; `0x49aa93` eligibility; `0x4e7276 % count` selection; `0x540a9c` record allocation; selected index/flag writes; and `0x4a54a7` commit. Descriptor-joined non-type98 `+0xedc` pairs can now reach this direct branch when their copied source fields are known. Complete live source-pair producer/feed coverage and raw `+0x30/+0x34/+0x3c` capture remain pending.
- `0x4a93a2` weighted-record allocation now owns the recovered `generator+0xf44` sequence state: setup initializes it to `1`, allocation increments it, creates a `0x540a9c` weighted record identity, writes recovered record metadata `+0x1c/+0x20/+0x24`, fills the coordinate payload, and feeds the existing `0x4a901a -> 0x4a54a7` weighted commit path. Full source-order caller selection beyond exact-input `0x4a901a` scan remains pending.
- `0x4ab52a` road/river object-adjacency now owns the recovered generator `+0x14b0` coordinate vector for source-backed `0x4a901a`/`0x4a93a2` allocations, the road-type RNG selection, outer/inner coordinate pair order, `0x4aae2f` path-state reset of low-word/predecessor fields, `0x4aae7b` low-word path-cost/predecessor propagation before candidate acceptance, and the downstream `0x4ab37f -> 0x4b4243` road toolkit. The toolkit marks candidate road cells through `0x49aec5`, replays `0x458e61`, classifies road art through `0x458893`, performs `0x458a2f` final art selection with `0x4e7276`, and stages the private `0x49b2b6` road-overlay vectors. Native still does not emit final map output until final writeout is ported.
- D-014 endpoint prep now promotes recovered `0x4a1f3b` `+0xc8/+0xcc` source-endpoint records into generator private state, preserves the `0x49f95a` byte-state relationship, carries the supported one-level-land `+0xd8/+0xdc` compact key count of `8` into concrete `+0x1104/+0x1108` byte-state sizing, records the stale `+0xf5c` rejection against compact keys `0..7`, and keeps live endpoint success disabled rather than deriving it from projection endpoints.

Known blockers:

- Exact caller sequence after the `0x4a5767` bridge is now owned through the focused road toolkit path, but final writeout remains unported.
- Native now carries recovered `0x49b452` relation-owner constructor/default fields plus concrete zeroed `+0x44` descriptor-counter tables, the recovered `0x4a1f3b/0x4a19ed` selected coordinate triple `+0x10..+0x18`, source-zone endpoint vector `+0xc8/+0xcc` contents/count, and `0x4a17f5/0x4a1ad8` coordinate candidate vectors from the source setup path. The active generator private-state builder now continues through source-order relation record replay, route/free-cell `0x4a8260 -> 0x4a4c8e`, the recovered post-`0x4a4c8e` `0x4a8c15 -> 0x49a962` cleanup scan, the recovered `0x4a4913` relation-vector loop, the `0x4a8c15 -> 0x4a5767` full-grid reset / relation scan / `0x49a318` high-owner propagation bridge, the one-level-land `0x4a4fc5` water-edge scan, mine/resource materialization, reward/guard materialization, D-014 endpoint prep, decorative dispatch, source-backed `0x4a79a3` connection-tail replay, and the `0x4ab52a` road-prefix path before exposing the next blocker.
- No-Godot Small seed 10/58 setup3 and Medium 4-player seed 10 setup3 snapshots show the active bridge reset visits both generated-cell planes, applies relation scan consumers for all relation owners, applies `0x49a318` high-owner propagation, applies the one-level-land `0x4a4fc5` scan, runs mine/resource materialization, runs reward/guard materialization, applies decorative coordinate-worklist replay/pass3, applies source-backed connection-tail replay, replays the `0x4ab52a` road object-adjacency path, runs `0x4ab37f -> 0x4b4243`, and then blocks at final writeout. Small seed 10 reaches 4 road records, 6 accepted pairs, 6 toolkit successes, 91 road-overlay cells, and 201 final-art RNG calls. Small seed 58 reaches 4, 6, 6, 115, and 235. Medium seed 10 reaches 7, 21, 21, 418, and 947. All three still have zero successful direct `0x4aa9b7` reward/guard commits, so this is still not parity or final writeout.
- Recovered helper semantics still exist for `0x4a5a23`, `0x4a8db2`, `0x4a901a`, `0x4a8d2c -> 0x4a93a2`, `0x4a54a7`, reward/guard attachment, endpoint helpers, and fallback replay. They are not active workflow progress unless their source-order callers and inputs are owned.
- Native still lacks successful reward/guard coordinate commits from the live `0x4aab7e -> 0x4aa354 -> 0x4aa9b7 -> 0x4aa603/0x4aa3e9` source stream, but recovered caller order does not allow that mismatch to stop downstream phase replay by itself. The current focused no-Godot Small/Medium one-level land blocker is final header/player/sentinel serialization: `0x4ad1e3 -> 0x49b2b6 -> 0x4ad309/0x4ad318 -> 0x4ad3eb` count/pass-order is source-owned through the `0x57c648[type*16+0x0c]` table byte, and the field-backed object payload serializers encountered by focused cases now serialize every object before native fails closed at `0x4ad3de -> 0x4ae09a`. Descriptor counters, full final writeout, and same-run private-state/final-payload comparison remain blocked. The implemented `0x4a5e73`, `0x4a606b`, `0x4a5a23`, `0x4903e8`, exact-input `0x4a8db2`, exact-input `0x4a901a`, exact-input direct `0x4a8d2c -> 0x4a93a2`, exact-prestate fallback replay, direct `0x4a5c07 -> 0x4a5e03`, `0x49b89c` object-record score-cache support, `0x49e700` coordinate worklist replay, `0x4a79a3` connection-tail replay, `0x4ab52a` road adjacency replay, `0x4ab37f -> 0x4b4243` road toolkit replay, `0x4ad309/0x4ad318` object-count header write, `0x4ad3eb` pass split, and explicit `0x4a54a7` prep helpers must not be wired to guessed endpoint/object state or run before their source-order owner phase is complete.
- These helpers must not be called from synthetic native object placement or package adoption as compensation for missing H3MapEd phases.

Implementation rule: keep helpers available, but do not use them to claim pre-object generated-cell parity until their source callers and inputs are ordered and same-run validated.

## Native Implementation Rule From This Ledger

The only 100-percent-safe implementation change from this ledger is to fail closed on the combined generated-cell checkpoint:

- Native may report owner-grid `GeneratedCell+0x20` materialization as an incomplete support artifact.
- Native must not emit a full comparable pre-`0x4a4c8e` generated-cell record set assembled from reset defaults plus owner words.
- Native map output remains blocked until phases 5 through 7 are source-owned for the selected Small/Medium one-level land path.

## Next Native Port Targets

1. Port final header/player/metadata serialization plus `0x4ad3de -> 0x4ae09a` from the now-staged generated-cell/object payload state; if broader seed coverage reaches an unported complex `0x4ad3eb` serializer body, recover and port that body source-backed rather than guessing bytes.
2. Validate whether the native `0x49b89c` body-mask derivation from existing `.msk` footprint fields is exact enough against same-run/final-payload parity; if it diverges, recover and carry an independent descriptor `+0x3c` mask instead of guessing.
3. Fix the live `0x4aab7e -> 0x4aa354 -> 0x4aa9b7 -> 0x4aa603/0x4aa3e9` reward/guard source stream so supported Small/Medium one-level land cases produce source-owned reward/guard commits instead of carrying zero-commit parity debt.
4. Resume descriptor counter replay and same-run private-state/final-payload comparison after final writeout is owned.

Until those are complete, checkpoint 2 is blocked, not almost complete.
