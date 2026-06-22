# heroes-like Tactical Implementation Plan

Task: #10184
Document role: tactical execution plan
Source strategy: `project.md`
Reset date: 2026-04-27
Compacted date: 2026-05-26
Operational tracker: `ops/progress.json`

## Purpose

This plan turns `project.md` into executable work slices. It is not a history log, worker diary, evidence dump, or progress tracker.

Rules:
- Keep strategy in `project.md`.
- Keep detailed requirements, audits, and evidence in `docs/*.md` or `.artifacts/*`.
- Keep current state, completion evidence, worker notes, and validation records in `ops/progress.json`.
- A slice is complete only when implementation/content/tooling changes satisfy the referenced requirements and validation gates.
- Documentation-only and report-only work must stay distinct from implemented gameplay/system/content completion.
- Do not continue ad hoc UI cue/performance/content work unless it is selected here and tracked in `ops/progress.json`.
- Test, report, audit, and export tooling should be Python-owned. GDScript should be reserved for live game/runtime behavior, not validation/report launchers.

## Current Tactical State

Current phase: **Phase 5 - Playable Alpha Baseline**.

- Current implementation slice: `native-rmg-source-order-h3maped-alignment-10184` / tracker slice `rmg-small-generalization-hardening-10184` is in progress. The active work is native C++ implementation alignment to the H3MapEd one-level land authority behavior for supported Small/Medium maps. Recovery-ledger closure is not the active work item.
- Single H3MapEd RMG recovery ledger: `docs/h3maped-rmg-end-to-end-behavior.md`. Use it as the first source map for recovered H3MapEd phase order, private state, generated-cell words, bit fields, helper behavior, and final writeout evidence before touching native RMG code. It is not native implementation status.
- Native adapter drift audit: `docs/native-rmg-core-h3maped-drift-audit.md` marks where `src/gdextension/src/rmg_native_core.cpp` and its header still diverge from the recovery ledger. Treat those drift IDs as the current native-port backlog, not as completed implementation.
- Latest native RMG implementation update: `h3maped_rmg_core` now matches the recovered `0x49cf34` source-order candidate filtering by erasing `wrapper+0x3c..+0x40` candidates in reverse in place instead of rebuilding a forward filtered vector. `h3maped_rmg_core_selftest` covers the reverse `0x49d2e0` execution order and surviving original candidate order. No-Godot controlled snapshots still fail closed before final writeout at `reward_guard_materialization_0x4aab7e_zero_successful_0x4aa9b7_commits_before_connection_tail`: Small seed 10 is still blocked inside `0x49cf34 -> 0x49d2e0` by `0x49d2e0_neighbor_policy_plus_2_zero_reject`; Small seed 58 reaches `0x4aa9b7` but rejects all candidates through `0x4aa603_0x49a6f9_footprint_existing_bit26_rejected`; Medium seed 10 has three surviving attach candidates but rejects the coordinate scan through `0x4aa603_0x49a6f9_secondary_mask_terrain_rejected`. This is still not parity and not final map output. The next behavior work is source-backed input/state parity for the live reward/guard wrapper/source-relation/object-record feed, not final-map tuning.
- Latest native RMG implementation update: `h3maped_rmg_core` keeps the single `run_h3maped_rmg_entry_to_writeout_workflow()` authority and now removes the non-source-order post-reward generic `0x4a8d2c/0x4a8db2` replay gate. Recovered `0x4ac552` order remains: early source-record replay, route/free-cell `0x4a8260/0x4a4c8e`, post-`0x4a4c8e` cleanup, `0x4a4913`, relation normalization/scan/high-owner propagation, one-level-land `0x4a4fc5`, mine/resource materialization, reward/guard materialization, then post-reward `0x49eb8d`/road-river/final-writeout phases only after reward/guard commits are source-owned. No-Godot Small seed 10, Small seed 58, and Medium seed 10 still fail closed at `reward_guard_materialization_0x4aab7e_zero_successful_0x4aa9b7_commits_before_connection_tail` before decorative dispatch, road/river, or final writeout run. Current observed attempts are Small seed 10 = 144, Small seed 58 = 90, and Medium seed 10 = 126, with zero successful `0x4aa9b7` commits and `last_projection_order_invoked_0x4ad7f7=0` in all three snapshots. The direct-stream blocker remains `0x49cf34/0x49d2e0` attach filtering and `0x4aa603/0x49a6f9` generated-cell feasibility against current bit/owner/terrain state. This is still not parity and not final map output; the next implementation slice is successful source-owned reward/guard commits in the recovered source order.
- Previous native RMG implementation update: `h3maped_rmg_core` carries recovered relation-owner reward/guard treasure bands `+0xa0/+0xa4/+0xa8` through `+0xc0`, terrain policy `+0x0c`, stale supported-land cursor `+0xf5c = 0x7a1befdf`, zeroed `+0xf60/+0xf64` terrain-pressure state, recovered `0x57cea0` monster terrain rows, and `0x531cc4` type-17 subtype-to-monster rows. The selected-candidate `0x4ac552 -> 0x4a218c` relation-vector producer is now owned by the shared workflow instead of being prebuilt during setup, and no-Godot snapshots expose its candidate-vector, selected-template, relation-vector, and relation-owner counts. Active workflow progress is blocked later at reward/guard materialization zero successful `0x4aa9b7` commits.
- Previous native RMG implementation update: `h3maped_rmg_core` exposes `run_h3maped_rmg_entry_to_writeout_workflow()` as the ordered entry-to-current-blocker workflow owner. `rmg_native_core.cpp` delegates native workflow phase/status/final-writeout state to that shared result and adapts its diagnostic owner-grid payload from the already-executed shared workflow instead of replaying setup/template/coordinate/object state locally. This removes the duplicate native workflow owner, but it is not parity or final map output.
- Previous native RMG implementation update: shared C++ replays descriptor-joined generic non-type98 `+0xedc` source pairs into the recovered source-order object paths. When a preserved source pair carries `0x4903e8` descriptor context, relation/key/anchor context, relation scan bounds, and copied `0x4c` source count/density fields, native reconstructs the source descriptor join and calls the existing recovered `0x4a8d2c` direct dispatcher and `0x4a8db2` scheduler. Pairs without that context fail closed and are counted as missing descriptor/relation/source-field blockers. This is not full generic object parity: live descriptor producers/raw source-field capture for all real non-type98 pairs, live reward/guard feed, fallback caller order, roads/rivers, and final payload generation remain unported.
- Previous native RMG implementation update: shared C++ now ports recovered reward/guard filters for source-backed helper inputs: `0x49cf34` calls the recovered `0x49d2e0` attach candidate filter, and `0x4aa9b7` now calls a recovered `0x4aa603` feasibility filter instead of a prevalidated coordinate allow-list. `0x4aa603` now checks selected-member body offsets through the `0x49a6f9` footprint gate, attached-wrapper bit22/type-`0x36` rejection, direction-policy cells, `0x49a09c` contour validation, and wrapper/generated-cell overlap bit26 rejection. This is not live reward/guard parity: live `0x4adb72/0x4ad7f7` caller feed still must construct the wrapper/source-relation/object-record inputs with descriptor body offsets, terrain policy, object-reference descriptor resolution, and real object keys; generic non-type98 materialization feed, fallback caller order, roads/rivers, and final payload generation remain unported.
- Native parity reality: native still diverges before object/route/package consumers. Checkpoint 2 remains the active implementation blocker until the native pre-`0x4a4c8e` generated-cell words match H3MapEd private state in Python-owned comparisons. Shared core owns the record-level `0x4a5767`/`0x49a318` projection helpers, `0x4a1f3b` non-sentinel relation scan bounds from generated-cell owner-byte rectangles, recovered `0x4a5767` scan-consumer projection-chain replay over those bounds including the source-backed `0x4a5a23` bit0 object-materialization branch through `0x4a9e40`, `0x4af785`, `0x49ba89`, and `0x4a54a7`, source-backed `0x49a318` high-owner propagation from relation-owner coordinate seeds including source projection clear, same-owner projection/`+0x1c` low-word writes, and cross-owner `+0x1c` high-word/`+0x28` direction/`+0x20` owner-byte writes, reset-time known-empty object-reference vectors from `0x499e65/0x499ea3`, recovered `0x499ee8` object-reference removal/empty-cell reset helper behavior, recovered explicit-input `0x4a606b` connection-region writing, no-object `0x4a5a23` projection-chain behavior, recovered explicit-call `0x4a54a7` object-footprint commit afterstate including descriptor-offset source-cell projection semantics and relation-local `+0x44[descriptor+0x1c]` counter increments, recovered `0x4903e8` descriptor/source join prep for contexts `45/53/54/79`, `0x4af785` resolver wiring into that prep, copied `0x4c` source-record identity through explicit object commit prep, recovered `0x4a93a2` weighted-record allocation / generator `+0xf44` sequence ownership, recovered `0x4a8db2` weighted scheduler density-lane threshold state and source-backed direct-prepass/weighted-lane replay, live type-98 runtime-zone `0x4a8db2` scheduler replay from source-zone town/castle count and density fields, source-backed weighted `0x4a901a` local candidate-vector scan/selection with value-floor clearing, source-backed weighted `0x4a93a2 -> 0x4a901a -> 0x4a54a7` type-98 record-tail commit behavior for recovered `0x540a9c` records, explicit-input reward/guard `0x4aa9b7 -> 0x4aa3e9` coordinate scan/wrapper commit behavior with recovered `0x4aa603` feasibility filtering, recovered reward/guard wrapper construction/reset/attach/final-marker helpers `0x49ce04/0x49ce64/0x49cf34/0x49cefb` plus source-backed empty-vector `0x49d7c3` contour rebuild for source-backed inputs, and recovered D-014 projection/exclusion/prep state for endpoint/connection materialization including supported one-level-land `+0xd8/+0xdc` compact key count, derived `+0x1104/+0x1108` byte-state sizing, stale `+0xf5c` rejection, disabled live endpoint success path, and exact-prestate `0x4a7605 -> 0x4a5e03` fallback replay through `0x4a54a7` for the two recovered seed-controlled records. The recovered `0x49a318` bit22 object-metadata policy branch is now ported; remaining `0x49a318` work is exact call-site order and same-run private-state comparison, plus live descriptor producers/raw source-field capture for every generic non-type98 pair feeding the now-partial `0x4a8d2c/0x4a8db2` replay bridge, generic object materialization producer/selection order beyond source-owned weighted records and the scan-consumer branch, live reward/guard wrapper/source-relation caller feed into the ported `0x49ce04/0x49cf34/0x49d2e0/0x49d7c3/0x4aa9b7/0x4aa603 -> 0x4aa3e9` path, generic live `0x4a7605 -> 0x4a5e03` fallback payload feed/caller order, roads/rivers, and final writeout are still unported.
- Current source-order object materialization status: weighted `0x4a901a`, direct exact-input `0x4a8d2c -> 0x4a93a2 -> 0x4a54a7`, source-backed `0x4a8db2` direct-prepass/weighted-lane scheduler replay, explicit-input reward/guard `0x4aa9b7 -> 0x4aa3e9` scan/commit with recovered `0x4aa603` feasibility filtering, explicit reward/guard wrapper attach/finalizer helpers `0x49ce04/0x49ce64/0x49cf34/0x49cefb`, recovered `0x49d2e0` candidate filtering, and the recovered empty-vector `0x49d7c3` wrapper contour rebuild exist in shared C++ for source-backed inputs. The selected-candidate relation-vector handoff is now executed in source order before relation-pointer replay; it is no longer a setup-time proxy from flat runtime seeds. This is still not full live object parity: native still needs live descriptor producers/raw source-field capture for all generic non-type98 source pairs, live reward/guard wrapper/source-relation caller feed that produces successful `0x4aa9b7` commits, fallback materialization caller feed, downstream caller order, and final payload writer.
- Source-first rule for this slice: inspect native RMG implementation in phase order, patch only source-backed divergences, then run no-Godot native verification. Do not use final-map deltas, density scalars, brute-force retries, GDScript reports, or Godot exports as substitutes for implementing the source behavior.
- Native RMG alignment checkpoints, in execution order:
  1. Final writeout authority: complete. Native final-writeout comparison now uses the H3MapEd `0x4ad1e3 -> 0x49b2b6 -> 0x4ad309/0x4ad3eb` tile/object stream as authority; current mismatches are attributed to pending earlier native checkpoints, not package-draft parity.
  2. Private generated-cell grid: make pre-`0x4a4c8e` native generated-cell words match H3MapEd private state before route/object consumers run.
  3. Reward/object identity: carry source records/descriptors through selection and materialization instead of resolving final identity through placeholder object ids. The recovered `0x49da08` object source-record catalog, metadata `+0x08` `0xe8` `0x49db76` wrapper-bucket lane layer, sampled `0x4af785` wrapper reuse/copy/create support model, sampled `0x4af89f`/`0x4a9e40` selector mechanics, recovered `0x4903e8` descriptor/source join prep for contexts `45/53/54/79`, copied `0x4c` source-record identity, explicit prepared `0x4a54a7` object commit path including relation-local `+0x44` counter mutation, recovered `0x4a93a2` weighted-record allocation / generator `+0xf44` sequence ownership, recovered `0x4a8db2` density-lane threshold argument and direct-prepass/weighted-lane scheduler replay, live type-98 runtime-zone scheduler-source feed, recovered `0x4a901a` weighted candidate scan/selection over generated-cell low-word value floors and `0x49aa93` eligibility, source-backed weighted type-98 `0x4a93a2` record-tail commit through `0x4a901a -> 0x4a54a7`, explicit-input reward/guard `0x4aa9b7 -> 0x4aa3e9` scan/selection/wrapper commit with recovered `0x4aa603` feasibility filtering, explicit reward/guard wrapper construction/reset/attach/final-marker helpers `0x49ce04/0x49ce64/0x49cf34/0x49cefb`, recovered `0x49d2e0` filtering, and source-backed empty-vector `0x49d7c3` wrapper contour rebuild are now exposed in shared C++ and mirrored through the native wrapper where live callers exist. Full live weighted/materialization parity still waits on live descriptor producers/raw source-field capture for all generic non-type98 source pairs, live reward/guard wrapper/source-relation/object-record-key caller feed, and downstream relation/reward/guard/object caller order.
     Direct `0x4a8d2c -> 0x4a93a2` exact-input placement is also exposed for source-backed inputs: branch priority is `+0x24`, `+0x20`, `+0x34`, then `+0x30`; selected candidates use nearest-distance local-vector behavior with initial `0x7d00`, `0x49aa93` eligibility, `0x4e7276 % count` selection, `0x540a9c` allocation, and `0x4a54a7` commit. Generic non-type98 descriptor-joined `+0xedc` replay is partially ported; live producer/feed coverage for every real pair and downstream caller order remain blockers.
  4. Metadata claim correction: complete. Exact/adopted phase claims that still have lower-level blockers are downgraded and must only be restored after comparison evidence passes.
  5. Route/free-cell replay: active blocker. `0x4a8260` route replay mechanics exist only as recovered helper/diagnostic evidence in the active native work. The live shared workflow must port the source-order center feed and `0x4a4c8e` candidate/relation boundary before relation/object/reward consumers can run.
  6. Road vector/bit source: port endpoint vector and generated-cell bit inputs before treating road topology as exact.
  7. Connection blockers/guards: replace synthetic package blocker/guard construction with source-backed object payload, body, and control semantics.
  8. Decorative scoring/vector replay: replace placeholder `0x49e1bf` scoring and manually seeded object snapshots with relation/scoring and object-vector state.
- Current checkpoint-2 finding: no runtime/native/GDScript generation surface is allowed to emit comparable pre-`0x4a4c8e` generated-cell words until the shared H3MapEd-aligned state chain owns every mutating phase listed in `docs/native-rmg-generated-cell-mutation-chain.md`. The no-Godot CLI emits the blocked marker `rmg_native_batch_export_cli_shared_h3maped_state_chain_blocked_v1` for `--phase-snapshot-only`; it feeds runtime-zone seeds and links from the recovered 53-template H3MapEd catalog through `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b()` only after the recovered `0x49ecf2` setup step has been resolved. If `setup_object_0x44` is supplied, `generator_setup_mode_49ecf2()` copies ordinary modes directly, randomizes sentinel value `3` with one `0x4e7276` RNG call and `% 3`, hands the post-setup RNG state to template selection, then executes the shared coordinate-to-owner-grid support path when the remaining inputs are present. If setup is not supplied, the same-run catalog/runtime-zone feed is blocked with `rmg_setup_object_0x44_before_0x49ecf2_template_selection`; the resolver no longer assumes template selection starts from the raw seed. The Python wrapper no longer accepts `--shared-runtime-input-snapshot`; stale phase snapshots cannot be mined for runtime-zone/link inputs. Missing inputs remain explicit blockers and are not synthesized. The duplicate plain-C++ phase/native-map reconstruction body has been deleted from `src/gdextension/src/rmg_native_core.cpp`; that file now owns controlled-case parsing/filtering, blocked shared-chain marker output, same-run recovered setup/catalog feed resolution, and the call into `h3maped_rmg_core`. The standalone native-core public header does not declare reconstructed phase/native-map writers, the CLI does not call a native-map JSON writer, and `--native-map-json-only` writes only a blocked manifest with `native_map_json_public_api_removed=true` and `legacy_native_generation_surface_removed=true`. H3MapEd Small/Medium validator-gated package/session adoption is also removed from the live runtime authority path: `MapPackageService::generate_random_map` returns a direct exact-state-chain blocked result for supported H3MapEd scopes; runtime H3MapEd scope/status classification calls `h3maped_rmg_core` directly; unsupported runtime output returns a local blocked result; both native and GDScript `convert_generated_payload` paths fail closed; `build_h3maped_small_package_session_adoption` and `build_native_package_session_adoption` return blocked results; the old proxy/reconstruction sources have been renamed to `src/gdextension/src/archived_h3maped_small_rmg_legacy_proxy_20260618.cpp` and `src/gdextension/src/archived_h3maped_small_rmg_embedded_data_legacy_proxy_20260618.cpp`; their headers have moved out of public `include/` into archived source-only headers; and `inspect_h3maped_small_rmg_port` / negative-validator are not declared, bound, advertised, or stubbed by native or the GDScript shim. The GDScript compatibility shim no longer advertises foundation-generation/adoption capabilities and returns blocked instead of generating a fallback map. `NativeRandomMapPackageSessionBridge.gd` no longer reads `native_proxy_*` package fields, and `tests/validate_repo.py` now forbids those bridge tokens and the old active legacy filenames. The shared core now owns recovered RNG, recovered `0x49ecf2` generator-mode setup, Small/Medium one-level-land scope, water-mode code, strict scope labels, size-score calculation, the recovered generated-cell reset `0x49a072 -> 0x499ea3` for words `+0x10/+0x1c/+0x20/+0x24/+0x28/+0x2c`, the recovered `0x49acf6` terrain/art/private-flag helper bit mutation, the recovered low-level boundary helpers for `0x4a2b33` clipping, `0x4a261a` deterministic line writing, `0x4a2413` randomized line writing, owner-word application, and `0x4a325d` span fill, plus a typed `boundary_cycles_from_source_handoffs_4a2777` / `materialize_boundary_source_handoffs_4a2777_4a325d` handoff API that accepts recovered source-node finalized fields and selected `0x4a3a03` source-record `+0x10/+0x14/+0x18` seeds, then materializes selected connector, border wrap/final segments, rectangle fallback, generator `+0x3f4` boundary-vector append records, generated-cell owner-word mutations, and recovered `0x4a325d` seed relocation/span-fill into the shared grid shape. That handoff now preserves the `0x4cca55` source-cycle descriptor indexes, raw `+0x00/+0x04` coordinates, and finalized `+0x1c/+0x20` coordinates instead of flattening the cycle to finalized x/y only. The shared core also exposes typed source-record producer functions for `0x4ac62a..0x4ac6ec` player-slot assignment, `0x4a218c/0x4a1f3b` runtime-zone/link seed construction from template zone/link records, and recovered catalog selection/feed. The shared coordinate seed now carries recovered source-zone town/terrain bytes, interleaves `0x49b3c1` town choice before each initial zone placement, runs `0x49b53d` runtime terrain selection from same-run town choice/source terrain flags, and applies `0x4a3f27` terrain-id repaint and runs TerrainPlacement visual row/terrain flag selection through `0x4bb74b/0x4bad0f/0x4bcfc3/0x4bce6d` into generated-cell `+0x24/+0x28` support words. This is still not parity: later relation/object caller order remains blocked. Downstream terrain, object, relation, route, and package consumers stay blocked until the full generated-cell mutation chain is implemented from source and same-run validated.
- TerrainPlacement final-sweep detail: native now preserves current scratch visual records through the recovered `0x4bc5a3` path for corrected-class `0x4bbfcc` cases that have no direct visual row bucket.
- Current checkpoint-2 snapshot surface: the blocked no-Godot shared-chain snapshot emits only a partial generated-cell surface. It now carries the recovered generator-object private-state shape for generated-cell buffer `+0x14`, dimensions `+0x18/+0x1c/+0x20`, accepted candidate vector `+0x10d4/+0x10d8`, preserved `+0xedc` source-pair payload contents from `0x4af785` including `0x4903e8` descriptor-join context where that path created the pair, source-owner/player-slot counts and actual `+0xed8/+0xee0/+0xee4` arrays, active relation-vector count from selected `0x4ac552 -> 0x4a218c` owner adoption, recovered `0x49b452` relation-owner constructor/default fields plus concrete zeroed `+0x44` descriptor-counter tables and `0x4a1f3b` non-sentinel relation scan bounds from generated-cell owner-byte rectangles, recovered `0x4a5767` scan-consumer projection-chain counters over those bounds including `0x4a5a23` object-branch attempt/commit counters, recovered `0x4a1f3b/0x4a19ed` relation-owner selected coordinate triple `+0x10..+0x18`, source-zone endpoint vector `+0xc8/+0xcc` contents/count for `0x4a1f3b`, supported one-level-land endpoint cursor vector `+0xd8/+0xdc` compact key count `8`, `0x4a17f5/0x4a1ad8` coordinate candidate vectors per relation owner, recovered reciprocal `0x49f7c4` relation-owner records from selected runtime links, recovered `0x4a5767` full-grid projection reset, source-backed `0x49a318` projection/high-owner word mutations and counters, reset-time known-empty generated-cell object-reference vectors from `0x499e65/0x499ea3`, recovered `0x499ee8` object-reference removal/empty-cell reset helper behavior, setup-zeroed endpoint field `+0xf58` while leaving `+0xf5c` unclaimed, recovered `0x49f95a` endpoint byte-state vector `+0x1104/+0x1108` zero-init relationship to endpoint pointer vector `+0xd8/+0xdc` with concrete supported-land count, recovered stale `+0xf5c` rejection for compact keys `0..7`, the recovered static `0x4a5e73` endpoint helper contract for explicit inputs, recovered explicit-input `0x4a606b` 3x3 connection-region writing, recovered `0x4a5a23` projection-chain occupancy/cleanup and object-branch materialization behavior, recovered explicit-call `0x4a54a7` object-footprint commit afterstate including descriptor-offset source-cell projection semantics and relation-local descriptor-counter increments, recovered exact `0x4a7605 -> 0x4a5e03` fallback payload commit helper for the two sampled seed-controlled records, recovered `0x4903e8` descriptor/source join prep for contexts `45/53/54/79`, copied `0x4c` source-record identity through explicit object commit prep, recovered `0x4a93a2` weighted-record allocation / generator `+0xf44` sequence ownership, recovered `0x4a8db2` weighted scheduler density-lane threshold list and source-order replay state, exact-input weighted `0x4a901a` and direct `0x4a8d2c -> 0x4a93a2` object-placement candidate/selection/commit state, D-014 endpoint projection/exclusion/caller-prep state, descriptor counter table `+0x1110` zero initialization from `0x49ecf2` (`0x3a0` bytes / 232 dwords), recovered stride-`0x30` record shape, reset/owner/terrain word overlays, partial `+0x2b` bit-knowledge reporting, the recovered `0x49da08` object source-record catalog identity summary, the recovered metadata `+0x08` `0xe8` `0x49db76` wrapper-bucket summary, sampled `0x4af785` wrapper reuse/copy/create behavior, and sampled `0x4af89f`/`0x4a9e40` source selector behavior. Live relation/object caller order, exact `0x49a318` call-site order/same-run private-state comparison around the now-ported bit22 object-metadata policy branch, live source-order object materialization caller order/object-reference appends/removals beyond the scan-consumer/weighted/direct exact-input paths and descriptor-joined non-type98 replay bridge, complete live source-record `+0x30/+0x34/+0x3c` capture, live source-order fallback `0x4a7605 -> 0x4a5e03` payload feed/caller order, source-order descriptor counter increment/decrement replay beyond explicit prepared calls, and downstream source-order relation/object caller mutations are still not source-owned by the live chain. It reports owner-grid materialization counts, `generated_cell_private_state_comparable=false`, and the missing mutating phases from `docs/native-rmg-generated-cell-mutation-chain.md`. The active source-order chain still calls the recovered one-level land `0x4a3710` finalizer after `0x4a2777 -> 0x4a325d`, but this proves only ordering/owner-grid support; it does not prove checkpoint-2 parity or authorize runtime map output.
- Default proxy-surface fence: the active-source `MapPackageService` implementation has been replaced with a slim package service plus fail-closed RMG normalization/identity/blocked responses. The old reconstruction helper entrypoints (`generate_zone_layout`, `generate_player_starts`, `generate_road_network`, `generate_river_network`, `generate_object_placements`, `generate_town_guard_placements`, `generate_connection_payload_resolution`, and `generate_terrain_grid`) and the `AURELION_ENABLE_ARCHIVED_NATIVE_RMG_RECONSTRUCTION` compile-time escape hatch have been removed from active source. `generate_random_map` now has only fail-closed H3MapEd-exact-chain blocked results until the recovered shared chain owns payload generation. The GDScript compatibility shim no longer carries private `_generate_*` reconstruction helpers, no longer exposes the archived reconstruction blocker helper, and no longer advertises the disabled native RMG placement/provenance schema ids. The old Godot `RmgNativeBatchExportRunner` class/source/header and `tools/rmg_native_batch_export_native.tscn` launcher have been removed, are not linked into the GDExtension, and are guarded by `tests/validate_repo.py`; RMG export tooling is the standalone no-Godot CLI only, which currently fails closed instead of producing maps. This is a guardrail only, not parity progress: successful runtime map generation stays blocked until the exact recovered descriptor/source-cycle/seed producer owns the live payload.
- Shared coordinate/source-node/owner-grid chain port: `h3maped_rmg_core` now owns the recovered `0x49ecf2` generator-mode setup surface, `0x4ac62a..0x4ac6ec` player-slot assignment surface, `0x4a218c/0x4a1f3b` runtime-zone/link seed construction from typed template records, recovered 53-template catalog selection/feed through `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b()`, the `0x4a218c -> 0x4a1f3b -> 0x4a19ed` coordinate seeding surface, including the recovered `generator+0x10b8` mode-to-prune-divisor behavior, the recovered `0x4a3a03 -> 0x4ccb64 -> 0x4cca55` source-node footprint producer, the `0x4a2777 -> 0x4a325d` owner-grid/span-fill materializer, and the source-order `0x4a3710` one-level land no-appended-zone finalizer surface. The shared core exposes `generator_setup_mode_49ecf2()`, `runtime_seed_inputs_from_template_records_4a218c_4a1f3b()`, `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b()`, and `coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710()`, which let source-order C++ flow start from recovered setup/catalog records instead of a prior phase snapshot. Missing setup/generator-mode input remains observable when no same-run setup object `+0x44` value is supplied, source payload fields are preserved, the recovered `0x4a2777` descriptor owner gate (`next_pair_payload <= zone_word`) is applied before source-edge writes, source edges use the recovered two-endpoint shape (`from_clip` / `to_clip`), and the finalizer explicitly blocks non-land/multilevel or appended-zone adjacency paths instead of guessing them. `bin/h3maped_rmg_core_selftest` proves setup sentinel `3` RNG handoff, Small reference catalog selection, Medium catalog feed availability, player assignment, template-record seed/link construction, coordinate seeding with mode `0` divisor `5` and mode `2` divisor `7`, source handoff consumption, coordinate-output RNG handoff, recovered `0x4a3710` finalizer order, and generated-cell owner word production without Godot or map export. This still does not complete checkpoint 2: private-state comparison and live payload ownership must be implemented before any map output can consume owner words.
- Supersession note: earlier `native-rmg-medium-h3maped-land-*` runtime-adoption/public-UI completion evidence is historical support evidence only. It is not current runtime authority for Small/Medium H3MapEd generation after the exact-state-chain fail-closed correction.
- Current guardrails: do not add density scalars/gates/brute-force retries/final-map tuning, do not use GDScript for reports/exports, and do not launch Godot/headless Godot for native RMG export on this memory-constrained host. `tools/rmg_native_batch_export.py` now only supports the standalone no-Godot `bin/rmg_native_batch_export_cli` path for blocked private-state diagnostic snapshots; the wrapper refuses to run while a Godot process is already active, and the wrapper unconditionally refuses native map JSON/full `.amap` output attempts before spawning the CLI. `--phase-snapshot-only` may write diagnostic files, but it is not a successful generation/export trigger and exits blocked until final payload generation is owned by the shared H3MapEd-aligned RMG core instead of duplicate CLI logic. Do not treat the initial generated-cell grid, post-boundary owner-word grid, boundary-vector append-order diagnostics, post-terrain-writeout grid, post-relation-eligibility grid, post-live-feedback grid, template/runtime-zone summary, link-seed summary, coordinate replay summary, synthetic append summary, source-node summary, boundary/span-fill summary, runtime terrain summary, terrain-cell writeout summary, terrain-relation eligibility summary, or terrain live-feedback summary as pre-`0x4a4c8e` parity; exact same-run compares still mismatch. Do not build Windows `.dll` outputs until Linux `.so` parity checks reach the final boundary.
- Paused/in-progress evidence slice: `strategic-ai-medium-long-run-seed-matrix-10184` remains paused/in-progress and is not the selected immediate work.
- Latest completed slice: `native-rmg-medium-h3maped-land-public-ui-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-runtime-adoption-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-phase-port-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-template-authority-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-reference-corpus-10184`.
- Latest completed slice: `strategic-ai-rmg-medium-generalization-probe-10184`.
- Latest completed slice: `native-rmg-medium-runtime-generation-unblock-10184`.
- Latest completed slice: `strategic-ai-medium-rmg-unblock-routing-10184`.
- Latest completed slice: `strategic-ai-medium-rmg-blocker-classification-10184`.
- Latest completed slice: `strategic-ai-baseline-staged-evidence-adoption-10184`.
- Latest completed slice: `strategic-ai-residual-diagnostic-hardening-10184`.
- Latest completed slice: `strategic-ai-staged-100-evidence-aggregation-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset0-count3-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset98-count2-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset93-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset88-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset83-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset78-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset73-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset68-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset63-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset58-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset53-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset48-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset43-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset38-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset33-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset30-count3-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset29-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset28-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset27-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset26-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset25-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset24-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset23-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset18-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset13-10184`.
- Latest completed slice: `strategic-ai-seed13-route-pressure-execution-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset8-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset3-10184`.
- Latest completed slice: `strategic-ai-broader-handoff-generalization-10184`.
- Latest completed slice: `strategic-ai-tactical-pressure-march-10184`.
- Latest completed slice: `strategic-ai-natural-battle-handoff-matrix-10184`.
- Latest completed slice: `strategic-ai-generated-town-battle-handoff-proof-10184`.
- Latest completed slice: `strategic-ai-generated-battle-handoff-behavior-10184`.
- Latest completed slice: `strategic-ai-generated-battle-handoff-coverage-10184`.
- Latest completed slice: `strategic-ai-generated-regroup-target-integrity-10184`.
- Latest completed slice: `strategic-ai-headless-resource-task-persistence-10184`.
- Latest completed slice: `battle-ai-spell-conservation-tactical-order-10184`.
- Latest completed slice: `battle-ai-shared-spell-tactical-order-10184`.
- Latest completed slice: `strategic-ai-active-front-support-launch-10184`.
- Latest completed slice: `strategic-ai-active-raid-launch-budget-10184`.
- Latest completed slice: `strategic-ai-active-front-event-surface-10184`.
- Latest completed slice: `strategic-ai-long-run-seed-sharding-10184`.
- Latest completed slice: `battle-ai-immediate-threat-targeting-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-roster-sync-10184`.
- Latest completed slice: `battle-ai-overkill-target-discipline-10184`.
- Latest completed slice: `battle-ai-recovery-target-filter-10184`.
- Latest completed slice: `strategic-ai-path-distance-field-efficiency-10184`.
- Latest completed slice: `battle-ai-side-payload-fallback-continuity-10184`.
- Latest completed slice: `battle-rules-commander-payload-fallback-continuity-10184`.
- Latest completed slice: `battle-ai-tactical-order-payload-merge-continuity-10184`.
- Latest completed slice: `battle-ai-force-sync-payload-continuity-10184`.
- Latest completed slice: `battle-ai-outcome-payload-continuity-10184`.
- Latest completed slice: `battle-ai-normalized-payload-preservation-10184`.
- Latest completed slice: `battle-ai-rich-payload-spellbook-merge-10184`.
- Latest completed slice: `battle-ai-live-spell-template-cast-sync-10184`.
- Latest completed slice: `battle-ai-spell-template-spellbook-fallback-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-template-fallback-10184`.
- Latest completed slice: `strategic-ai-risk-commander-template-fallback-10184`.
- Latest completed slice: `battle-ai-tactical-commander-template-fallback-10184`.
- Latest completed slice: `battle-ai-spell-role-template-fallback-10184`.
- Latest completed slice: `battle-ai-commander-spell-role-valuation-10184`.
- Latest completed slice: `strategic-ai-spell-study-template-role-fallback-10184`.
- Latest completed slice: `battle-ai-tactical-order-commander-state-fallback-10184`.
- Latest completed slice: `battle-ai-battle-state-enemy-hero-fallback-10184`.
- Latest completed slice: `strategic-ai-path-surface-fingerprint-cache-10184`.
- Latest completed slice: `strategic-ai-indexed-path-search-10184`.
- Latest completed slice: `strategic-ai-path-distance-efficiency-10184`.
- Latest completed slice: `strategic-ai-long-run-progress-telemetry-10184`.
- Latest completed slice: `battle-ai-tactical-order-commander-payload-10184`.
- Latest completed slice: `battle-ai-spell-report-payload-bridge-10184`.
- Latest completed slice: `battle-ai-enemy-hero-payload-bridge-10184`.
- Latest completed slice: `battle-ai-commander-withdrawal-personality-10184`.
- Latest completed slice: `strategic-ai-long-run-configurable-matrix-10184`.
- Latest completed slice: `battle-ai-engaged-melee-attack-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-tiebreak-10184`.
- Latest completed slice: `strategic-ai-task-fit-spell-study-10184`.
- Latest completed slice: `battle-ai-lethal-spell-priority-10184`.
- Latest completed slice: `battle-ai-lethal-action-priority-10184`.
- Latest completed slice: `battle-ai-commander-buff-target-selection-10184`.
- Latest completed slice: `battle-ai-cleanse-recovery-urgent-filter-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-commander-fit-10184`.
- Latest completed slice: `battle-ai-damage-status-rider-targeting-10184`.
- Latest completed slice: `battle-strategic-ai-resistance-aware-spell-tuning-10184`.
- Latest completed slice: `strategic-ai-global-commander-task-assignment-10184`.
- Latest completed slice: `strategic-ai-post-recruit-surplus-mobilization-10184`.
- Latest completed slice: `strategic-ai-town-defense-commander-continuity-10184`.
- Latest completed slice: `strategic-ai-post-capture-town-support-continuation-10184`.
- Latest completed slice: `strategic-ai-neutral-town-assault-grouping-10184`.
- Latest completed slice: `strategic-ai-surplus-garrison-mobilization-10184`.
- Latest completed slice: `strategic-ai-artifact-front-support-10184`.
- Latest completed slice: `strategic-ai-site-claim-recruits-10184`.
- Latest completed slice: `strategic-ai-opportunistic-town-resupply-10184`.
- Latest completed slice: `strategic-ai-opportunistic-spell-site-learning-10184`.
- Latest completed slice: `strategic-ai-active-town-runway-source-support-10184`.
- Latest completed slice: `strategic-ai-empire-build-arbitration-10184`.
- Latest completed slice: `strategic-ai-rare-resource-targeting-10184`.
- Latest completed slice: `strategic-ai-town-spell-study-10184`.
- Latest completed slice: `strategic-ai-spell-site-learning-10184`.
- Latest completed slice: `strategic-ai-personality-regroup-threshold-10184`.
- Latest completed slice: `strategic-ai-same-turn-launch-movement-10184`.
- Latest completed slice: `strategic-ai-midmove-hero-reaction-10184`.
- Latest completed slice: `strategic-ai-route-opportunistic-pickups-10184`.
- Latest completed slice: `strategic-ai-site-event-task-transition-10184`.
- Latest completed slice: `strategic-ai-duplicate-task-reservation-recovery-10184`.
- Latest completed slice: `strategic-ai-risk-regroup-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-target-selection-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-faction-scoped-hero-route-vision-10184`.
- Latest completed slice: `strategic-ai-player-hero-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-post-move-scouting-memory-10184`.
- Latest completed slice: `strategic-ai-multihero-spawn-occupancy-10184`.
- Latest completed slice: `strategic-ai-defensive-threat-known-hero-gating-10184`.
- Latest completed slice: `strategic-ai-convoy-interception-known-world-gating-10184`.
- Latest completed slice: `strategic-ai-hero-front-support-sighting-gate-10184`.
- Latest completed slice: `strategic-ai-active-hero-target-known-gating-10184`.
- Latest completed slice: `strategic-ai-lost-hero-task-reconciliation-10184`.
- Latest completed slice: `strategic-ai-stale-hero-hunt-revalidation-10184`.
- Latest completed slice: `strategic-ai-ordinary-scouting-memory-10184`.
- Latest completed slice: `strategic-ai-persistent-exploration-task-board-10184`.
- Latest completed slice: `strategic-ai-neutral-town-known-world-gating-10184`.
- Latest completed slice: `strategic-ai-no-known-target-exploration-10184`.
- Latest completed slice: `strategic-ai-known-nonhero-target-gating-10184`.
- Latest completed slice: `strategic-ai-no-omniscient-empty-target-fallback-10184`.
- Latest completed slice: `strategic-ai-fresh-launch-commander-fit-10184`.
- Latest completed slice: `strategic-ai-known-world-memory-10184`.
- Latest completed slice: `strategic-ai-post-objective-raid-continuation-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-recruitment-prep-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-launch-10184`.
- Latest completed slice: `strategic-ai-spell-aware-task-launch-10184`.
- Latest completed slice: `strategic-ai-resource-defense-battle-handoff-10184`.
- Latest completed slice: `strategic-ai-resource-defender-stationing-10184`.
- Latest completed slice: `strategic-ai-resource-front-support-consolidation-10184`.
- Latest completed slice: `strategic-ai-live-commander-role-adoption-10184`.
- Latest completed slice: `strategic-ai-threat-recovery-reinforcement-10184`.
- Latest completed slice: `strategic-ai-nearby-threat-avoidance-10184`.
- Latest completed slice: `strategic-ai-commander-risk-tolerance-10184`.
- Latest completed slice: `strategic-ai-planned-launch-host-template-lock-10184`.
- Latest completed slice: `strategic-ai-post-regroup-target-resumption-10184`.
- Latest completed slice: `strategic-ai-commander-outcome-adaptation-10184`.
- Latest completed slice: `strategic-ai-defended-town-capture-stationing-10184`.
- Latest completed slice: `strategic-ai-neutral-town-post-capture-garrison-10184`.
- Latest completed slice: `strategic-ai-planned-task-build-prep-10184`.
- Latest completed slice: `strategic-ai-recruitment-market-coverage-10184`.
- Latest completed slice: `strategic-ai-opportunistic-hero-intercept-10184`.
- Latest completed slice: `strategic-ai-destination-aware-recruitment-10184`.
- Latest completed slice: `strategic-ai-commander-personality-task-fit-10184`.
- Latest completed slice: `strategic-ai-site-contest-event-surfacing-10184`.
- Latest completed slice: `strategic-ai-planned-task-ready-launch-10184`.
- Latest completed slice: `strategic-ai-rmg-small-turn-health-10184`.
- Latest completed slice: `strategic-ai-defended-neutral-town-assault-10184`.
- Latest completed slice: `strategic-ai-neutral-town-expansion-10184`.
- Latest completed slice: `strategic-ai-resource-front-support-10184`.
- Latest completed slice: `strategic-ai-multi-origin-task-planner-10184`.
- Latest completed slice: `strategic-ai-coordinated-task-planner-10184`.
- Latest completed slice: `strategic-ai-long-run-seed-matrix-10184`.
- Latest completed slice: `strategic-ai-threat-arbitration-10184`.
- Latest completed slice: `strategic-ai-battle-task-outcome-lifecycle-10184`.
- Latest completed slice: `strategic-ai-risk-stall-withdrawal-10184`.
- Latest completed slice: `strategic-ai-hero-hunt-support-grouping-10184`.
- Latest completed slice: `strategic-ai-town-defender-rotation-10184`.
- Latest completed slice: `strategic-ai-proactive-risk-regroup-10184`.
- Latest completed slice: `strategic-ai-post-move-assault-grouping-10184`.
- Latest completed slice: `strategic-ai-defense-overcommit-control-10184`.
- Latest completed slice: `strategic-ai-target-aware-spawn-point-selection-10184`.
- Latest completed slice: `strategic-ai-town-rebuild-garrison-safety-10184`.
- Latest completed slice: `strategic-ai-regroup-garrison-aware-routing-10184`.
- Latest completed slice: `strategic-ai-regroup-failure-rebuild-10184`.
- Latest completed slice: `strategic-ai-unreachable-route-recovery-10184`.
- Latest completed slice: `strategic-ai-shared-support-task-reservations-10184`.
- Latest completed slice: `strategic-ai-support-overcommit-control-10184`.
- Latest completed slice: `strategic-ai-active-front-support-10184`.
- Latest completed slice: `strategic-ai-guarded-claim-resumption-10184`.
- Latest completed slice: `strategic-ai-guarded-object-claim-routing-10184`.
- Latest completed slice: `strategic-ai-encounter-arrival-risk-gating-10184`.
- Latest completed slice: `strategic-ai-hero-intercept-risk-gating-10184`.
- Latest completed slice: `strategic-ai-town-assault-risk-gating-10184`.
- Latest completed slice: `strategic-ai-commander-assault-consolidation-10184`.
- Latest completed slice: `strategic-ai-adventure-objective-progression-10184`.
- Latest completed slice: `strategic-ai-town-defender-lifecycle-10184`.
- Latest completed slice: `strategic-ai-town-defense-arrival-10184`.
- Latest completed slice: `strategic-ai-artifact-equipment-10184`.
- Latest completed slice: `strategic-ai-scouting-spell-execution-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-execution-10184`.
- Latest completed slice: `strategic-ai-local-recruitment-support-10184`.
- Latest completed slice: `strategic-ai-regroup-task-board-10184`.
- Latest completed slice: `strategic-ai-hero-hunt-task-board-10184`.
- Latest completed slice: `strategic-ai-artifact-task-board-10184`.
- Latest completed slice: `strategic-ai-encounter-objective-task-board-10184`.
- Latest completed slice: `strategic-ai-task-retask-cancellation-10184`.
- Latest completed slice: `strategic-ai-spawn-saved-task-commander-selection-10184`.
- Latest completed slice: `strategic-ai-task-resumption-10184`.
- Latest completed slice: `strategic-ai-task-actor-lifecycle-10184`.
- Latest completed slice: `strategic-ai-task-lifecycle-reconciliation-10184`.
- Latest completed slice: `strategic-ai-persistent-hero-task-board-10184`.
- Latest completed slice: `battle-layout-smoke-followup-10184`, expanded by owner direction into the battle presentation runtime slice.
- Latest completed slice: `combat-mireclaw-packhunter-trait-trim-10184`.
- Previous completed slice: `combat-mireclaw-half-anti-ranged-shielding-10184`.
- Previous completed slice: `combat-mireclaw-t6-t7-hp-revert-10184`.
- Previous completed slice: `battle-benchmark-all-live-hero-matrix-10184`.
- Previous completed slice: `hero-roster-live-diversity-10184`.
- Previous completed slice: `combat-mireclaw-late-anti-ranged-counter-10184`.
- Previous completed slice: `combat-mireclaw-late-tank-buff-10184`.
- Previous completed slice: `combat-thornwake-week2-buff-10184`.
- Previous completed slice: `combat-thornwake-t6-ranged-balance-10184`.
- Previous completed slice: `combat-sunvault-t6-melee-balance-10184`.
- Previous completed slice: `magic-resistance-countercontrol-10184`.
- Previous completed slice: `battle-spell-valuation-counterplay-followup-10184`.
- Previous completed slice: `battle-spell-parity-counterplay-10184`.
- Previous completed slice: `magic-town-study-full-tier-access-10184`.
- Previous completed slice: `magic-spell-tier-power-bands-10184`.
- Paused slice: `combat-faction-pair-stat-tuning-10184` remains needs-tuning; broad stat tuning is paused while the owner-selected battle presentation runtime slice improves player-readable combat flow.
- Previous completed slice: `battle-benchmark-no-round-cap-10184`.
- Previous completed slice: `combat-feel-balance-pass-10184`.
- Earlier completed slice: `battle-fast-faction-benchmark-10184`.
- Earlier completed slice: `economy-native-rmg-required-source-support-10184`.
- `ops/progress.json` remains the operational source of truth for completed evidence, validation commands, and paused/superseded slice state.
- RMG test/report/export work is Python-owned. Do not add or run GDScript report/export launchers for RMG validation; GDScript remains for live in-game runtime behavior.

Latest economy/town evidence:
- Runtime-inclusive economy/town scorecard: 30/30.
- Deterministic economy/town scorecard: 15/15.
- Authored town development completion: day 28-30.
- Strict Small Native RMG package adoption report: passing for all nine live resource sources, generated town source routes, guarded rare-source pressure, player/enemy/neutral generated town runway pacing, and seven-tier town recruitment within 36x36 one-level land scope.
- Current player-balance finding: Brasshollow, Thornwake, and Veilmourn have the clearest economy identity; Embercourt, Mireclaw, and Sunvault still need deeper identity beyond rare-resource pressure.
- Current rare-cost model: every town uses all six rare resources in high-tier development. The faction signature rare remains highest pressure, one secondary rare is about half pressure, and each remaining rare is about one-third pressure.
- Authored rare-source breadth is paused for this balance slice. The owner-selected balance surface is Native RMG generated maps, not authored scenario/source placement.
- Strict Small generated-map economy evidence is scoped to 36x36 one-level land packages. It is authoritative for this balance slice, but not broad RMG economy approval for larger sizes, water, underground, or broad template families.

Current product focus:
- Keep building toward a playable alpha baseline.
- Prefer player-readable, live-loop improvements over adding new report gates.
- Current strategic AI target: build from the baseline KPI audit into production behavior. Live commander/raid target choices now write normalized `enemy_states[].hero_task_state`, reuse saved active tasks for later target selection, reserve exclusive targets across active task boards, complete captured resource and artifact tasks, reconcile saved tasks against current target ownership/existence, suspend or invalidate saved tasks whose commander actor is missing, recovering, or unable to deploy, reactivate suspended saved tasks once their commander is deployable again, make new raid spawning prefer deployable commanders with reachable saved tasks before falling back to roster rotation, preserve explicit cancelled history when a commander is retasked to a different objective, persist objective-front encounter targets as first-class durable tasks, close live battle tasks from actual combat outcomes instead of battle queueing, arbitrate competing ready battles by strategic value instead of nearest-only ordering, give Native RMG/generated skeletal enemy configs runtime strategic AI defaults for raid pressure, spawn points, and encounter pools, add an executable generated-map long-run seed-matrix runner, seed coordinated pre-deployment task plans, and keep all of that continuity without a save-version bump.
- Latest strategic AI completed slice: `strategic-ai-neutral-town-expansion-10184` makes generated-map/skirmish AI empires identify and capture reachable empty neutral towns as expansion objectives instead of only attacking player towns and resource/object sites. This is a live behavior slice, not a broad report-only gate or a full production-readiness claim.
- Latest strategic AI completed slice: `strategic-ai-defended-neutral-town-assault-10184` extends neutral-town expansion from empty towns into defended neutral towns by routing ready AI assaults through the live town battle system, risk-gating weak hosts, capturing the town without applying player-collapse consequences to neutral defenders, and letting active retake armies override planned reservations for urgent player-captured town recovery.
- Latest strategic AI completed slice: `strategic-ai-rmg-small-turn-health-10184` makes supported strict-Small Native RMG AI turns execute in the baseline by default and makes generated-map raid deployment expose player-facing target-assignment threat events instead of only pressure summaries.
- Latest strategic AI completed slice: `strategic-ai-planned-task-ready-launch-10184` lets prepared saved commander tasks launch from readiness instead of waiting for generic raid pressure, while unplanned raids still obey pressure thresholds.
- Latest strategic AI completed slice: `strategic-ai-site-contest-event-surfacing-10184` makes resolved encounter/objective-site arrivals emit compact public `ai_site_contested` events instead of silently mutating encounter/task state.
- Latest strategic AI completed slice: `strategic-ai-commander-personality-task-fit-10184` makes the live task planner score targets per commander archetype, command stats, specialty focus, and battle traits so enemy heroes stop acting like interchangeable target consumers.
- Latest strategic AI completed slice: `strategic-ai-destination-aware-recruitment-10184` makes enemy town recruitment pick units for the chosen destination: garrison defense, active raids, commander rebuilds, and planned commander tasks now use different unit-priority profiles.
- Latest strategic AI completed slice: `strategic-ai-opportunistic-hero-intercept-10184` makes active non-defensive raids retarget nearby exposed player heroes when the intercept is reachable and passes existing hero-risk readiness, while preserving defense/support/objective/guarded-claim priorities.
- Latest strategic AI completed slice: `strategic-ai-recruitment-market-coverage-10184` makes enemy town recruitment use live town-market coverage for wood/ore unit costs, consuming market caps when gold-backed recruitment buys missing materials.
- Latest strategic AI completed slice: `strategic-ai-planned-task-build-prep-10184` moves same-turn commander task planning ahead of town construction and gives objective-supporting buildings an explicit planned-task preparation score/reason, so AI towns build toward live commander goals before recruiting for them.
- Latest strategic AI completed slice: `strategic-ai-neutral-town-post-capture-garrison-10184` makes empty neutral-town expansion transfer the capturing host into the new town garrison, station the commander as defender, and retire the field raid instead of leaving a bare ownership flip.
- Latest strategic AI completed slice: `strategic-ai-defended-town-capture-stationing-10184` makes AI commanders that win defended town assaults consolidate into the captured town as active defenders with survivor-garrison continuity instead of entering generic post-assault recovery.
- Latest strategic AI completed slice: `strategic-ai-commander-outcome-adaptation-10184` makes commander target-selection fit adapt from live outcome memory: repeated success at a target kind increases future task fit for that kind, while defeats reduce it, without a save-version bump or public debug leakage.
- Current strategic AI follow-up: use the new long-run progress telemetry to reduce the strict Small Native RMG enemy-turn bottleneck now measured inside `OverworldRules.end_turn`/enemy turn execution, then broaden the generated-map runner from focused smoke into the full 100-seed eight-week matrix and continue deeper generated-map army/economy timing, retreat/personality, Medium/generalized generated-map behavior, and live-client pacing review. Guarded object routing, encounter-arrival risk, hero-intercept risk, town-assault risk, defended-town capture stationing, adaptive commander outcome memory, coordinated pre-deployment task planning, task-board recruitment prep, multi-origin planning, resource-front support, neutral-town expansion, neutral-town post-capture garrisoning, Small generated-map turn health, planned-task ready launch, site contest event surfacing, commander personality task fit, destination-aware recruitment, recruitment market coverage, planned-task build preparation, and focused long-run smoke are not a full strategic AI release-readiness claim.
- Current battle-presentation target: battle resolution should emit a readable event stream for movement, strikes, shots, spell casts, damage, healing, status changes, resisted/immune outcomes, deaths, retaliation, morale/cohesion, and momentum; the battle scene should consume that stream with normal/fast/instant playback controls while keeping combat math unchanged.
- Use the fast battle-balance benchmark evidence to tune faction-pair combat spread now that fake round-cap outcomes have been removed, the public benchmark report uses side-neutral `side_a`/`side_b` terminology, and spell-enabled benchmark availability follows the same Native RMG week surface as army snapshots.
- Before more broad unit-stat nudges, strengthen the magic system as a strategic layer: spell availability, school coverage, field-magic access, and player-readable town/generated-map spell study should improve before trying to balance magic-focused heroes against raw-combat heroes.
- Latest magic follow-up: resistance and counter-control mechanics now run in live battle and in the fast benchmark before remaining spell-enabled benchmark outliers are treated as pure faction/unit imbalance.
- Campaign production remains deferred until explicitly selected in a later phase.

## Selectable Near-Term Work

Before starting any item, add or select a concrete slice in `ops/progress.json`, mark it `in_progress`, and keep validation evidence there.

Recommended next slices:
- `strategic-ai-long-run-seed-matrix-10184`: expand strategic AI validation from focused fixtures into multi-week generated-map seed matrices once task ownership is durable enough to measure.
- `strategic-ai-multi-origin-task-planner-10184`: make coordinated task-board planning evaluate all owned towns/spawn origins and persist the selected origin on planned tasks.
- `strategic-ai-same-turn-task-prep-10184`: make the live enemy turn plan commander objectives before town recruitment so same-turn recruitment can prepare newly planned tasks.
- `strategic-ai-planned-task-recruitment-prep-10184`: make town recruitment prepare durable planned commander objectives before those objectives spawn as active raids, with emergency garrison and true rebuild priority preserved.
- `combat-faction-pair-stat-tuning-10184`: tune unit stats, growth, and ability power from the full benchmark outlier rows to reduce deterministic faction-pair win-rate spread.
- `battle-spell-valuation-counterplay-followup-10184`: tune spell AI valuation and counterplay from the spell-enabled benchmark evidence, especially heavy control preference, before treating the new outlier set as pure unit-stat imbalance.
- `battle-layout-smoke-followup-10184`: continue battle layout smoke only if the prior manual stop left actionable evidence or a reproducible UI/runtime issue.
- `strategic-ai-quality-pass-10184`: selected for the baseline KPI harness/audit. Do not treat it as full strategic AI production readiness.
- `rmg-small-generalization-hardening-10184`: harden strict Small generated-map evidence without claiming larger sizes, water, underground, or broad template parity.
- `ux-polish-player-comprehension-10184`: improve onboarding, tooltips, town planning clarity, battle intent feedback, save/load confidence, and reduce debug-like seams.
- `packaging-platform-readiness-followup-10184`: continue clean Windows/Linux packaging and smoke-test hardening.
- `headless-balance-harness-next-10184`: expand automated balance harness depth before scaling content.

Do not select:
- campaign/scenario production breadth unless the owner explicitly changes priority;
- broad RMG parity claims from strict Small evidence;
- final art direction, final audio, or release packaging claims from generated/runtime placeholder layers;
- new validation gates that merely make reports pass without improving player-readable game behavior.

## Magic Availability And Strategic Influence Target

The immediate magic slice should improve what players can learn and do with magic without pretending that magic-focused heroes and raw-combat heroes are balanced yet.

Target shape:
- the live authored spell catalog should stay above a 100-spell floor before balance work treats magic variety as credible;
- every live magic school should have broad authored spell presence, with at least a dozen schema-valid spells per school;
- overworld magic should have at least 20 authored spells across movement and scouting support;
- spell tiers must carry real numeric meaning: tier 1 spells are cheap and limited, tiers 2-3 are useful/strong midgame tools, tier 4 spells are major swings, and tier 5 spells are expensive very-strong effects;
- tier scaling should apply to mana costs, damage and power scaling, wounded bonuses, buff/control duration, modifier magnitude, recovery, movement restoration, and scouting radius;
- every authored town should reach tier 5 spell study through its full development tree without extending the existing town-development day target;
- every authored spell should be reachable through fully developed town study access, not left as catalog-only content;
- Native RMG/generated spell rewards should include tier 1-5 candidates across all schools, even though town development remains the primary full-catalog access path;
- town study should expose faction school access plus Old Measure access by spell tier instead of relying only on short hand-authored per-town lists;
- town study should expose more than faction-flavored battle buffs/damage, especially field scouting and route tools;
- Native RMG/generated reward pools should include multiple spell-access candidates instead of only Beacon Path;
- new field effects must mutate bounded strategic state directly, not just add another report surface;
- no rare-resource spell-cast costs, caster-unit system, school mastery, or final magic-vs-might balance claim is part of this work.

## Economy Rare-Resource Target

The current economy identity pass moves towns away from a one-signature-rare model. Balance evidence for map-source access must be based on Native RMG generated packages for this slice, not authored scenario maps.

Target cost-pressure model for every town template:
- Every rare resource should appear in at least one town-development cost.
- The town faction's signature rare resource should remain the highest-pressure rare and should still define the core late-game faction bottleneck.
- One secondary rare resource should create about half as much pressure as the faction signature rare.
- Each remaining rare resource should create about one-third as much pressure as the faction signature rare.
- `gold`, `wood`, and `ore` should remain the dominant common-resource development shape; multi-rare costs should not turn the economy into all-rare-only pricing.
- Rare-resource use should create meaningful player choices in different building categories, not just append small costs to arbitrary filler buildings.
- Native RMG generated-package support, guarded access, AI town development, and player-facing town UI must be updated with the cost model so every required rare can be acquired through play.

Example pressure interpretation if a faction's signature rare target remains near the current 28-30 total spend:
- faction signature rare: roughly 28-30 total pressure;
- secondary rare: roughly 14-15 total pressure;
- each remaining rare: roughly 9-10 total pressure.

Implemented target at this point:
- signature rare: 28-30 total pressure depending on existing faction-specific upgrade costs;
- secondary rare: 14 total pressure;
- each remaining rare: 9 total pressure;
- all six rare resources appear in high-tier unit-building costs for every faction ladder.

## Battle Balance Benchmark Target

The selected battle-balance slice is a fast Python benchmark, not a final combat tuning claim. It should use current content and port the live battle math closely enough to make faction matchup iteration cheap before wider tactical tuning.

Required benchmark shape:
- pure Python, no Godot runtime for normal benchmark runs;
- live `content/*.json` faction, unit, hero, spell, town, and building data;
- hero spellbooks should include starting battle spells plus Native-RMG week-tier town-study battle spells from faction school access; authored representative-town build timing must not shape the faction matrix;
- reports should expose per-week spellbook coverage and actual spell-cast summaries by school, tier, effect, and faction;
- ordered non-self faction matrix for all six factions;
- deterministic seed count, with `--quick`, `--seeds`, `--weeks`, `--json`, and `--gate` options;
- week 1 army snapshots: initial starting growth plus one recruited week capped at T1-T3;
- week 2 snapshots: initial starting growth plus week-one T1-T4 and week-two T1-T5 recruitment;
- week 3 snapshots: initial starting growth plus week-one T1-T4, week-two T1-T5, and week-three T1-T7 recruitment;
- week 4 snapshots: initial starting growth plus week-one T1-T4, week-two T1-T5, and week-three/week-four T1-T7 recruitment with fully developed growth for final full-tier ticks;
- JSON report rows for win rates, average rounds, action mix, casualties by tier, battle consequences, pair summaries, week summaries, and outliers.

Initial target bands:
- faction-pair dominant win rates should land within 45-55% before the combat-balance goal is complete;
- ordered faction rows, outcomes, casualties, and week side-bias summaries should use `side_a`/`side_b`, not scenario ownership labels;
- army snapshots should use Native RMG-suitable faction/unit growth rather than authored representative-town build logs;
- side bias should stay low;
- no fake stalemate outcome should exist in benchmark data; emergency simulation guard hits are structural failures;
- average rounds should remain readable, and later-week battles should take more turns on average than early battles.

The first benchmark should report outliers as tuning evidence. Do not tune away failures blindly just to make the initial benchmark look green.

## Magic Resistance And Counter-Control Target

The current magic slice turns resistance and counter-control from artifact/theme metadata into live battle mechanics.

Target shape:
- units define bounded `spell_resistance_pct`, `control_resistance_pct`, `spell_school_resistance_pct`, and `status_immunity_ids`;
- T1-T3 units have no general natural resistance, T4-T5 gain light spell resistance, T6-T7 gain stronger spell and control resistance, and faction-school units gain modest own-school resistance;
- hero knowledge contributes bounded incoming spell/control resistance through battle payloads;
- artifacts can add live spell, control, and school resistance bonuses, starting with Choir Tuning Fork;
- cleanse/countermagic spells grant temporary immunity to the statuses they cleanse;
- spell damage is mitigated but still lands for at least one damage, while status/control riders can be resisted or blocked by immunity;
- mana is consumed even when the target resists or is immune;
- guard/status control tiles and tactical status effects remain engagement metadata, not a replacement for body blocking or damage resolution;
- Battle AI and the fast benchmark value expected resisted damage and control success chance instead of assuming all spells land fully;
- the fast benchmark reports resisted spells, immunity blocks, prevented damage, and top resisted spell ids.

Non-goals:
- do not claim final magic-vs-might or faction battle balance from this slice;
- do not add caster-unit spellbooks, rare-resource spell-cast costs, or school mastery;
- do not add broad new report gates beyond one focused resistance/counter-control runtime report.

## Slice Status Model

Each executable slice should map to one `ops/progress.json` entry with:
- `id`: stable slice id ending in `-10184`.
- `phase`: project phase.
- `purpose`: why the slice exists.
- `sourceDocs`: source requirements or evidence docs.
- `implementationTargets`: expected files/systems/content/tooling/report surfaces.
- `baselineChecks`: generic health checks required before completion.
- `sliceEvidence`: focused proof that the slice requirement was met.
- `completionCriteria`: objective completion bar.
- `nonGoals`: explicit boundaries when scope is risky.

Valid operational statuses:
- `pending`: planned, not started.
- `in_progress`: active implementation or review.
- `blocked`: cannot proceed; blocker must be named.
- `completed`: implementation and validation meet criteria.
- `docs_ready`: requirements/design/report exists; implementation is not complete.
- `paused`: intentionally delayed until selected again.
- `pending_after_implementation`: review/gate slice waiting for implementation output.
- `superseded`: replaced by a later accepted slice/path.

## Work Selection Gates

Before starting any worker:
1. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like`.
2. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like`.
3. Confirm or create the selected slice with source docs, implementation targets, validation, completion criteria, and forbidden-scope boundaries.
4. Mark the selected slice `in_progress` in `ops/progress.json`.
5. On completion, record validation/evidence in `ops/progress.json`; do not paste the evidence block into this file.

If a requested task is not represented by a valid slice, first add or reconcile a compact slice entry. Do not invent untracked ad hoc implementation work.

## Phase Roadmap

### Phase 0 - Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

State: complete unless document/process drift reappears.

### Phase 1 - Manual Scenario Proof

Goal: preserve the manually proven River Pass loop without overstating product readiness.

State: complete as proof history. Reopen only for regressions or explicit owner direction.

### Phase 2 - Deep Production Foundation

Goal: build the foundation needed before broad campaign/skirmish production or final polish.

State: foundation evidence is broad but not product completion. Completed implementation/report evidence lives in `ops/progress.json` and `docs/`.

### Phase 3 - HoMM3-Style Random Map Generator Rework

Goal: translate HoMM-style random-map structure into original content and systems.

Current boundary:
- Strict Small 36x36 one-level land package/session evidence exists.
- The H3MapEd recovery ledger is prerequisite evidence only. It does not mean the native generator has achieved true end-to-end RMG parity.
- Immediate RMG work is native adoption/porting from the recovered private-state replay, followed by Python-owned native-vs-H3MapEd comparison for land-only Small/Medium outputs.
- Larger sizes, water, underground, broad template families, final reward ecology, and true native end-to-end parity remain incomplete.
- Native/generated package adoption evidence must remain scoped and must not be presented as broad RMG production readiness or as a recovery-ledger completion proxy.

### Phase 4 - Headless AI Agent Balance Harness

Goal: run scenarios, economy loops, battles, AI turns, and balance checks faster than manual UI play.

State: meaningful harness/report foundations exist. Further work should make balance changes cheaper and more player-relevant, not merely add pass/fail surfaces.

### Phase 5 - Playable Alpha Baseline

Goal: a small coherent alpha that can be played repeatedly without developer interpretation.

Current emphasis:
- economy and town development are strongly validated but still need deeper faction identity;
- battle and strategic AI need quality and balance passes;
- UX should prioritize player comprehension over debug/report visibility;
- Native RMG generated Small-map source support and guard pressure are the selected economy balance surface;
- authored rare-source breadth is deferred until authored-map work is explicitly selected again.

Exit criteria remain:
- multiple scenarios/skirmish setups work end-to-end;
- at least two factions are meaningfully playable and distinct;
- town, battle, overworld, save/load, AI, economy, and UI loops hold together under repeated play;
- major UX surfaces are understandable without debug/report panels.

### Phase 6 - Production Alpha Layer

Goal: expand alpha into a production-shaped game slice.

Do not enter broadly until Phase 5 playable-alpha evidence is stable and owner-approved.

### Phase 7 - Broad Production Breadth

Goal: expand into a broad original fantasy strategy package with the systemic breadth, density, and replayability expected from classic Heroes-style strategy games.

Do not reopen Phase 7 work until Phase 5/6 evidence supports it or the owner explicitly changes priorities.

## Progress Reconciliation

Use this after PLAN/progress changes:

```bash
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like
```

Expected shape:
- `project.md` contains durable strategy and current strategic focus.
- `PLAN.md` contains compact tactical state, selection rules, and near-term slice candidates.
- `ops/progress.json` contains operational status, detailed evidence, validation history, and completed-slice records.
