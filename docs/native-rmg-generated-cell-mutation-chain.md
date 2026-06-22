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

Status: the active shared native workflow now owns the source-order `0x4a8c15 -> 0x4a5767` bridge relation-normalization call after the recovered post-`0x4a4c8e` cleanup scan and `0x4a4913` relation-vector loop, the one-level-land `0x4a4fc5` water-edge scan including source-water candidate handling, and the `0x4a79a3` connection-tail invocation. Small supported-land cases advance past `0x4a4fc5`, invoke `0x4a79a3`, and fail closed because the source-backed `0x4a7605/0x4a5e03` fallback record feed is missing for the current scopes. Medium seed 10 advances past `0x4a4fc5`, reaches the recovered `0x4a7605/0x4a5e03` fallback records, and fails closed because record 0's source cell `+0x20` does not match the recovered H3MapEd prestate. Downstream object/reward/guard, road/river, and final-writeout caller order remain unowned.

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
- `0x499ee8` record helper now applies the recovered object-reference removal contract for explicit inputs: scan the generated-cell object-reference vector for the object record key, remove the matching entry, and when the vector becomes empty clear `+0x28` bit22, set `+0x28` bit25, and reset the low word of `+0x20` to `0x7fbc` while preserving the high word. The source-order callers `0x4add76` and `0x4af910` are still not ported, so this helper must not be treated as live object materialization parity.
- `0x4903e8` explicit prep now joins recovered target contexts `45/53/54/79` to selected copied `0x4c` source records through `0x4af785`; when that join creates a new `+0xedc` source pair, native preserves descriptor-join context on the pair for later source-order replay. Explicit materialization prep carries that source identity into `0x4a54a7` only when a source-owned object-record key is supplied. Non-`0x4903e8` scan-consumer pairs remain marked without descriptor context.
- `0x4a8db2` source-order scheduler replay now owns recovered exact-input behavior for source-backed preserved `+0xedc` pairs: pair `+0x00/+0x04` payload gating, direct prepass call order over source fields `+0x24/+0x20/+0x34/+0x30`, recovered lane arguments into `0x4a901a`, weighted density order `+0x2c/+0x28/+0x3c/+0x38`, threshold formula, weighted lane score/increment order, tie behavior, and disable-on-false. The active native chain now replays descriptor-joined non-type98 `+0xedc` pairs through this path when their relation/key/anchor context and copied source count/density fields are present. Live descriptor producers/raw field capture for every real source pair remain pending.
- `0x4a901a` weighted candidate scan now owns the recovered local-vector behavior for exact source-backed inputs: generated-cell owner-byte match, low-word value-floor check, `0x49aa93` eligibility, `0x4ae52a` clear when a higher low-word floor is found, `0x4ae1fd` coordinate append, `0x4e7276 % count` selection, `0x4a93a2` allocation, and `0x4a54a7` weighted commit.
- `0x4a8d2c -> 0x4a93a2` direct object placement now owns recovered exact-input branch/callee behavior for source-backed inputs: branch priority over source fields `+0x24`, `+0x20`, `+0x34`, and `+0x30`; direct `0x4a93a2` candidate scan from explicit bounds; owner-byte filtering; nearest-distance local-vector clearing/appending from initial `0x7d00`; `0x49aa93` eligibility; `0x4e7276 % count` selection; `0x540a9c` record allocation; selected index/flag writes; and `0x4a54a7` commit. Descriptor-joined non-type98 `+0xedc` pairs can now reach this direct branch when their copied source fields are known. Complete live source-pair producer/feed coverage and raw `+0x30/+0x34/+0x3c` capture remain pending.
- `0x4a93a2` weighted-record allocation now owns the recovered `generator+0xf44` sequence state: setup initializes it to `1`, allocation increments it, creates a `0x540a9c` weighted record identity, writes recovered record metadata `+0x1c/+0x20/+0x24`, fills the coordinate payload, and feeds the existing `0x4a901a -> 0x4a54a7` weighted commit path. Full source-order caller selection beyond exact-input `0x4a901a` scan remains pending.
- D-014 endpoint prep now promotes recovered `0x4a1f3b` `+0xc8/+0xcc` source-endpoint records into generator private state, preserves the `0x49f95a` byte-state relationship, carries the supported one-level-land `+0xd8/+0xdc` compact key count of `8` into concrete `+0x1104/+0x1108` byte-state sizing, records the stale `+0xf5c` rejection against compact keys `0..7`, and keeps live endpoint success disabled rather than deriving it from projection endpoints.

Known blockers:

- Exact caller sequence after the `0x4a5767` bridge is not fully owned as a single source-order native chain.
- Native now carries recovered `0x49b452` relation-owner constructor/default fields plus concrete zeroed `+0x44` descriptor-counter tables, the recovered `0x4a1f3b/0x4a19ed` selected coordinate triple `+0x10..+0x18`, source-zone endpoint vector `+0xc8/+0xcc` contents/count, and `0x4a17f5/0x4a1ad8` coordinate candidate vectors from the source setup path. The active generator private-state builder now continues through source-order relation record replay, route/free-cell `0x4a8260 -> 0x4a4c8e`, the recovered post-`0x4a4c8e` `0x4a8c15 -> 0x49a962` cleanup scan, the recovered `0x4a4913` relation-vector loop, the `0x4a8c15 -> 0x4a5767` full-grid reset / relation scan / `0x49a318` high-owner propagation bridge, the one-level-land `0x4a4fc5` water-edge scan, and the `0x4a79a3` connection-tail invocation. Small supported-land cases now fail closed inside `0x4a79a3` because the source-backed `0x4a7605/0x4a5e03` fallback record feed is missing for the current scopes. Medium seed 10 reaches the recovered fallback records and fails closed because the source-cell prestate at `0x4a7605` record 0 does not match recovered H3MapEd. It does not run `0x4a9d6a` mine/resource, reward/guard, connection/decorative, roads/rivers, or final writeout until the bridge tail is source-owned.
- No-Godot Small seed 58 setup3 and Medium seed 10 setup3 snapshots show the active bridge reset visits and changes every generated-cell record (`1296/1296` and `5184/5184`), applies relation scan consumers for all relation owners, and applies `0x49a318` high-owner propagation. Small seed 58 setup3 applies the zero-source-water `0x4a4fc5` scan. Medium seed 10 setup3 applies the source-water-aware `0x4a4fc5` scan, reaches `0x4a79a3`, and blocks on fallback source-cell prestate. That is still a prefix, not parity.
- Recovered helper semantics still exist for `0x4a5a23`, `0x4a8db2`, `0x4a901a`, `0x4a8d2c -> 0x4a93a2`, `0x4a54a7`, reward/guard attachment, endpoint helpers, and fallback replay. They are not active workflow progress unless their source-order callers and inputs are owned.
- Native still lacks the source-backed `0x4a7605/0x4a5e03` fallback record feed needed for Small supported-land `0x4a79a3` to apply, and Medium seed 10 still has an upstream generated-cell mutation/order mismatch before the recovered fallback record can commit. Downstream `0x4a9d6a` mine/resource, reward/guard coordinate commits from `0x4aab7e -> 0x4aa9b7 -> 0x4aa3e9`, downstream connection/decorative caller order, generic supported-land fallback payload feed/caller order after target-mode-excluded `0x4a606b` / `0x4a696b` paths, roads/rivers, and final writeout remain blocked behind that bridge. The implemented `0x4a5e73`, `0x4a606b`, `0x4a5a23`, `0x4903e8`, exact-input `0x4a8db2`, exact-input `0x4a901a`, exact-input direct `0x4a8d2c -> 0x4a93a2`, exact-prestate fallback replay, and explicit `0x4a54a7` prep helpers must not be wired to guessed endpoint/object state or run before their source-order owner phase is complete.
- These helpers must not be called from synthetic native object placement or package adoption as compensation for missing H3MapEd phases.

Implementation rule: keep helpers available, but do not use them to claim pre-object generated-cell parity until their source callers and inputs are ordered and same-run validated.

## Native Implementation Rule From This Ledger

The only 100-percent-safe implementation change from this ledger is to fail closed on the combined generated-cell checkpoint:

- Native may report owner-grid `GeneratedCell+0x20` materialization as an incomplete support artifact.
- Native must not emit a full comparable pre-`0x4a4c8e` generated-cell record set assembled from reset defaults plus owner words.
- Native map output remains blocked until phases 5 through 7 are source-owned for the selected Small/Medium one-level land path.

## Next Native Port Targets

1. Recover/provide the source-backed Small supported-land `0x4a79a3` fallback record feed for `0x4a7605/0x4a5e03`.
2. Fix the upstream Medium generated-cell mutation/order that leaves recovered `0x4a7605` record 0's source cell `+0x20` different from the H3MapEd prestate.
3. Resume `0x4a9d6a`, relation/object caller order, and reward/guard only after the `0x4a8c15` bridge private-state boundary through `0x4a79a3` is owned.
4. Run same-run private-state comparison before allowing route/object/package consumers to use the generated-cell checkpoint.

Until those are complete, checkpoint 2 is blocked, not almost complete.
