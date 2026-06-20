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
- Tracks repaint/member flags in the local `cell_flags` buffer.

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

- No TerrainPlacement-specific blocker remains for the active one-level land Small/Medium path.
- Full checkpoint parity is still blocked by later relation/object generated-cell mutation caller order in phase 7.

Implementation rule: TerrainPlacement output may be used as active support state, but it still must not be called a comparable pre-`0x4a4c8e` checkpoint until the later relation/object caller order is source-owned and same-run validated.

### 7. Relation/object candidate, occupied, action, and score mutations

Status: helper semantics are partially source-backed; caller order and complete phase ownership are not.

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
- `generated_cell_49cf34_attach_word28`
- `generated_cell_4aa3e9_reward_word28`
- `endpoint_materialization_4a5e73` for the recovered explicit-input endpoint helper contract only.
- `object_footprint_commit_4a54a7` for the recovered explicit-call object-footprint commit afterstate only.
- `source_object_descriptor_join_0x4903e8` and `object_materialization_prep_from_descriptor_join_0x4a8db2_0x4a901a` for recovered descriptor/source join prep and explicit copied-source object commit prep only.

Mutation surface:

- Mutates relation/reset fields in `+0x1c`, high/low parts of `+0x20`, and selected `+0x28` bits.
- `0x4a5767` record helper writes projection triple `+0x10/+0x14/+0x18` to `-1`, writes the reset `+0x1c`, packs `+0x20` byte3, and clears `+0x28` bits 12..14 from source words.
- `0x49a318` record helper clears source `+0x1c` low word and resets projection triple `+0x10/+0x14/+0x18` to `-1`.
- `0x49a318` high-owner propagation now seeds from recovered relation-owner coordinates, flood-fills materialized non-rock generated cells in recovered neighbor order, and writes source owner into `GeneratedCell+0x20` byte3 when crossing low-owner channels.
- Sets/clears candidate and occupied bits.
- Sets action/control bits.
- Uses `+0x2c` gates.
- Tracks `+0x2b` bit `0x02` knowledge at record level and clears it on recovered `0x49abd6` body-reject behavior.
- Depletes score/distance fields in `+0x20`.
- `0x4a5e73` consumes generator-level endpoint pointer vectors and byte-state/cursor state: a missing `+0xd8/+0xdc` key returns `-1`, a missing `+0xc8/+0xcc` key returns `0`, and the accepted path clears low five bits of repeated generated-cell `+0x2c`, sets `+0x28` bit27, clears bit26, marks `+0x1104[old +0xf5c]`, then advances `+0xf5c` through marked byte-state entries.
- `0x4a606b` explicit-input helper now applies the recovered connection-region writer contract: scan the clipped 3x3 rectangle, consume reset-time known-empty object-reference vectors, call `0x49aa63(true)`, pack the low-nibble source into `+0x2c` bits 1..4 with bit0 set, then clear low five `+0x2c` bits and call `0x49a932(true)` on the projected target cell when the source projection triple is known. Live source-order post-materialization vector contents remain blocked.
- `0x4a5a23` explicit-input helper now applies the recovered no-object projected-chain contract: gate on `+0x1c` low word `(0, 0x7530)`, stop instead of guessing the `+0x2c` bit0 object-materialization branch, set bit27/clear bit26 on the mapped cell, optionally clear nearby same-owner `+0x2b` bit `0x04` when cleanup is not suppressed, and follow the projection triple while the next low word remains positive.
- `0x4a54a7` explicit-call helper now applies the recovered object-footprint commit afterstate: append the object record key to generator `+0xec4/+0xecc`, append it to the target cell object-reference vector when prior vector contents are known, increment generator `+0x1110[descriptor+0x1c]`, clear the target cell `+0x20` low word, set target `+0x28` action/occupied bits, and run the descriptor `+0x29` projection score-depletion wave from candidate coordinates minus descriptor `+0x2c/+0x30`.
- `0x4903e8` explicit prep now joins recovered target contexts `45/53/54/79` to selected copied `0x4c` source records through `0x4af785`, and explicit materialization prep carries that source identity into `0x4a54a7` only when a source-owned object-record key is supplied.
- D-014 endpoint prep now promotes recovered `0x4a1f3b` `+0xc8/+0xcc` source-endpoint records into generator private state, preserves the `0x49f95a` byte-state relationship, and keeps `+0xd8/+0xdc` plus `+0xf5c` blocked rather than deriving them from projection endpoints.

Known blockers:

- Exact caller sequence from terrain/relation/object phases into these helpers is not fully owned as a single source-order native chain.
- Record-level helper semantics do not yet mutate the live generated-cell grid in complete recovered source order.
- Native now applies the recovered `0x4a5767` full-grid projection reset over the live generated-cell grid, runs source-backed `0x49a318` high-owner byte propagation, carries reset-time known-empty object-reference vectors, and exposes explicit-call `0x4a54a7` object-vector/object-reference/descriptor-counter mutations, but still lacks source-order object materialization callers, `0x4a1f3b` scan-bounds/scan-consumer updates, the `0x49a318` object-metadata branch, and downstream relation/object caller replay.
- Native now carries recovered `0x49b452` relation-owner constructor/default fields plus the recovered `0x4a1f3b/0x4a19ed` selected coordinate triple `+0x10..+0x18`, source-zone endpoint vector `+0xc8/+0xcc` contents/count, `0x4a17f5/0x4a1ad8` coordinate candidate vectors consumed by `0x4a1f3b`, and the recovered `0x49f95a` endpoint byte-state vector zero-init relationship to endpoint pointer vector `+0xd8/+0xdc`. The remaining relation-owner/private-state gap is the `0x4a1f3b` scan-bounds updates, endpoint pointer-vector contents/count required for concrete byte-state contents, and later source-order scan consumers.
- Native still lacks source-owned generator-level `+0xd8/+0xdc` vector contents, the live `+0xf5c` cursor producer, source-owned weighted object-record-key callers, and the downstream live `0x4a606b` / `0x4a696b` / fallback materialization caller order. The implemented `0x4a5e73`, `0x4a606b`, no-object `0x4a5a23`, `0x4903e8`, and explicit `0x4a54a7` prep helpers must not be wired to guessed endpoint/object state.
- These helpers must not be called from synthetic native object placement or package adoption as compensation for missing H3MapEd phases.

Implementation rule: keep helpers available, but do not use them to claim pre-object generated-cell parity until their source callers and inputs are ordered and same-run validated.

## Native Implementation Rule From This Ledger

The only 100-percent-safe implementation change from this ledger is to fail closed on the combined generated-cell checkpoint:

- Native may report owner-grid `GeneratedCell+0x20` materialization as an incomplete support artifact.
- Native must not emit a full comparable pre-`0x4a4c8e` generated-cell record set assembled from reset defaults plus owner words.
- Native map output remains blocked until phases 5 through 7 are source-owned for the selected Small/Medium one-level land path.

## Next Native Port Targets

1. Port `0x4a1f3b` scan-bounds/scan-consumer updates and the remaining `0x49a318` object-metadata branch before route/object/package consumers run.
2. Port the source-order candidate, occupied/action, score, and reward attachment callers into the active shared native chain.
3. Run same-run private-state comparison before allowing route/object/package consumers to use the generated-cell checkpoint.

Until those are complete, checkpoint 2 is blocked, not almost complete.
