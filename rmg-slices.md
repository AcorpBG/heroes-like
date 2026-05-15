# Native RMG Production Slices

Active slice: `native-rmg-small-h3maped-port-10184`

Current status: `blocked_pending_owner_manual_inspection`

The current native RMG path is production ready only for strict Small 36x36, one-level, land-only generation derived from `/root/Downloads/h3maped.exe` and the recovered h3maped spec. Public generation is allowed only for this supported scope and only behind the native fast structural validator. Water, underground, larger sizes, broader template families, and full HoMM3-style parity remain explicitly blocked.

Latest local boundary: private terrain, towns, mines, rewards, predecessor-chain roads, connection blockers, guards, executable-shaped `cell+0x20` bits16..23 owner-byte state from the `0x4a325d` span-fill path, explicit `0x49aa63` / `0x49a932` generated-cell decoration bit-state, exact-source accounting for `0x4a8c15` / `0x49a962` / `0x4a89da` / `0x4a5767` / `0x4a5a23` / `0x4a4fc5` bit writers, recovered `0x4a4c8e` land-edge writer accounting through `0x49b3fb` runtime-zone relation vectors, `rand_trn` decorative candidate filler, final `0x49b2b6` tile-byte arrays, fast structural validator authority, validator-gated public `generate_random_map()` output, direct `convert_generated_payload()` package/session document adoption, package save/load round-trip, and editor/maps-folder package visibility now materialize for strict Small land configs. Road segments now preserve unique route tiles separately from duplicated segment cells. Package objects now carry body/visit/block pathing masks for towns, mines, rewards, guards, connection blockers, and decorative blockers. The old owner-transition fallback no longer writes bit 26 and remains diagnostic-only. A focused Small-land corpus gate now passes 15 cases across 2/3/4 players and seeds `1..5`. Slice H exposed and fixed two real production blockers: first, decorative-object bodies overlapped road infrastructure because the local `0x41e951` footprint gate accepted partial invalid/occupied masks; second, native start-to-road selection allowed diagonal corner cuts that runtime pathing rejects. The native footprint gate now rejects any invalid/occupied body-mask cell, and the native start reachability selector now matches runtime diagonal blocked-corner semantics while preserving connection blockers and guards as hard gates. Focused runtime acceptance reaches package road tiles, and the 15-case runtime corpus has local green evidence. Template selection is now hard-locked for the strict Small-land path: supported configs normalize to original `h3maped_template_*` source-template authority, explicit translated-template requests are overridden by the h3maped executable RNG, and unsupported profiles/non-numeric seeds return blocked output without map payloads or catalog-auto fallback flags.

The Small-land runtime-corpus acceptance gate previously exposed a hard package/runtime handoff gap: several start towns could not reach their package road after runtime adoption when package blockers were preserved. A rejected local attempt made start-town visit/action cells take precedence over connection-blocker masks; that produced better start exits but weakened the zone-gate contract. The stricter fix keeps runtime starts allowed to clear only removable decorative-obstacle masks, keeps connection blockers and guards as hard zone gates, and aligns native reachability with runtime blocked-corner movement semantics. The public result now advertises `production_ready` only for strict Small 36x36 one-level land.

Latest full strict Small-land gate rerun on 2026-05-15 passed native rebuild, package surface topology, runtime corpus, runtime/editor/renderer acceptance, structural corpus, template hard lock, negative validator, disk package startup, guard/reward package adoption, editor package load, maps-folder browser integration, manual inspection export, h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and the progress helper. The rerun confirms the owner-review package set is green for strict Small land. A follow-up manual-export audit now distinguishes literal artifact objects from artifact-category reward proxies: the three owner-review packages have artifact proxy counts `2/1/2` and literal artifact object count `0/0/0`, so the remaining object-family gap is true artifact/neutral-object breadth proof rather than absence of any artifact-category reward surface.

Current local work target: owner/manual inspection of the exported strict Small-land package pairs, then corrections only for concrete defects found in those packages. Agent-side implementation is blocked until that inspection accepts the baseline or supplies concrete defects. Do not carve per-seed corridors. Do not expand size, water, underground, or template breadth yet.

## Remaining Slices Until Production Ready

This is the authoritative remaining slice order. The current claim is only strict Small 36x36, one-level, land-only readiness pending owner inspection. Full RMG production readiness is not achieved until every supported mode below has its own h3maped-derived implementation, validation, package/editor/runtime adoption, and manual inspection evidence.

1. **Strict Small-land owner acceptance**
   - Scope: 36x36, one-level, land-only, 2/3/4 players.
   - Inspect `manual-strict_small_2p_seed_1`, `manual-strict_small_3p_seed_2`, and `manual-strict_small_4p_seed_3` in the built-in map picker/editor.
   - Use `.artifacts/rmg_small_manual_inspection_summary.md` as the inspection handoff; it lists the exact package ids, acceptance checklist, defect-report format, topology previews, route gates, road edges, and object-family counts.
   - Decide whether towns, starts, zones, roads, blockers, guards, mines, rewards, artifacts, and visible passability are acceptable as the baseline.
   - Output: accepted baseline or concrete defects with package id, seed/player count, and visible symptom.

2. **Strict Small-land defect closure**
   - Fix only concrete inspection defects from Slice 1.
   - Allowed fix sources: h3maped-derived phase logic, final package serialization, final project asset/content adaptation, or runtime/editor package adoption.
   - Forbidden fix sources: per-seed corridors, count fitting, fake guards, proxy blockers, visual-only roads, translated-template authority, catalog-auto fallback, or weakening connection blockers/guards to make pathing pass.
   - Output: every accepted defect has a code/data fix plus a focused regression gate.

3. **Strict Small-land full gate rerun**
   - Rerun the complete strict Small-land bundle after the last defect fix: native rebuild, template hard lock, source-state diagnostics, structural corpus, runtime corpus, negative validator, package surface topology, disk package startup, guard/reward adoption, editor visibility, maps-folder browser integration, manual inspection export, `jq empty ops/progress.json`, `git diff --check`, and maps-folder hygiene.
   - Output: strict Small-land remains green after fixes, with generated `.amap` / `.ascenario` and uploaded `.h3m` evidence left uncommitted.

4. **Strict Small-land object breadth closeout**
   - Finish remaining Small-land object-family proof, especially artifacts and broader neutral-object families.
   - Preserve h3maped provenance, body masks, visit masks, block masks, value bands, zone/global limits, save/load identity, and package provenance.
   - Output: mines, resources, rewards, artifacts, neutral objects, masks, value bands, and package/runtime identity are covered by strict Small-land evidence.

5. **Strict Small-land production declaration**
   - Keep `production_ready == true` scoped only to `strict_small_36x36_one_level_land_only`.
   - Unsupported water, underground, Medium/Large/XL, and broader template-family requests must keep returning explicit blocked output with no generated payload.
   - Output: strict Small land is owner-accepted, gate-green, documented, and safe for the current public generator surface.

6. **Small water/island expansion**
   - Start only after Slice 5.
   - Port the relevant h3maped water/island template selection, terrain shaping, zone semantics, roads/boats if applicable, blockers, guards, towns, mines, rewards, artifacts, validator cases, package save/load, editor adoption, runtime adoption, and manual inspection packages.
   - Output: Small water/island mode reaches the same evidence level as strict Small land.

7. **Small underground/two-level expansion**
   - Start only after Small land is accepted and after the water/island decision is either completed or explicitly deferred.
   - Port two-level template semantics, underground layer generation, inter-layer transitions, zone links, roads, blockers, guards, towns, mines, rewards, artifacts, validator cases, package save/load, editor adoption, runtime adoption, and manual inspection packages.
   - Output: Small two-level mode reaches the same evidence level as strict Small land.

8. **Medium land expansion**
   - Start only after the Small-mode gates are stable.
   - Port Medium h3maped template selection and phase behavior instead of scaling Small output.
   - Output: Medium land has independent structural corpus, runtime corpus, negative validator, package/editor/runtime gates, and manual inspection packages.

9. **Large/XL and broader template-family expansion**
   - Start only after Small and Medium modes prove the generalized h3maped-derived pipeline.
   - Each size/template family must get its own executable-derived phase coverage, performance profile, corpus audit, package save/load audit, editor acceptance, runtime acceptance, negative validator, and manual inspection packages.
   - Output: full RMG production readiness can be claimed only when the supported mode matrix is explicitly green and unsupported gaps are documented.

## Current Next Slices To Production Ready

This is the short production-readiness queue from the current strict Small 36x36 one-level land state. Follow it in order. Do not start water, underground, Medium/Large/XL, or broader template work until this queue is green and owner-accepted.

1. **Owner manual inspection**
   - Status: `active_next`
   - Inspect `manual-strict_small_2p_seed_1`, `manual-strict_small_3p_seed_2`, and `manual-strict_small_4p_seed_3` in the built-in map picker/editor.
   - Use `.artifacts/rmg_small_manual_inspection_summary.md` for the package ids, acceptance checklist, topology previews, route gates, road edges, and object-family counts.
   - Verify that starts are at owned player towns, zones read as separate regions, roads are meaningful route infrastructure, blockers/obstacles/guards physically gate zone links, and mines/rewards/artifacts are reachable only through intended guards.
   - Done when: the packages are accepted as the Small-land baseline or concrete defects are recorded with package id, seed/player count, and visible symptom.

2. **Inspection-driven defect fixes**
   - Status: `pending_manual_findings`
   - Fix only real defects found in those exported packages or their summary/audit data.
   - Valid fixes must come from h3maped-derived phases or the package/runtime boundary.
   - Forbidden fixes: count fitting, per-seed corridors, fake guards, proxy blockers, visual-only roads, translated-template authority, catalog-auto fallback, or weakening connection blockers/guards to make pathing pass.
   - Done when: each accepted defect has a native/data fix and a focused regression gate.

3. **Road infrastructure lock**
   - Status: `green_regression_gate_pending_manual_confirmation`
   - Keep roads as h3maped predecessor-chain route infrastructure: route nodes, route edges, road tile bytes, package route graph, editor rendering, runtime rendering, and movement must agree.
   - Short isolated visual loops are invalid unless explicitly proven executable-derived and recorded.
   - Done when: every accepted Small-land package has road records that connect meaningful h3maped endpoints and survive package save/load/editor/runtime adoption.

4. **Zone gate lock**
   - Status: `green_regression_gate_pending_manual_confirmation`
   - Connection blockers, decorative blockers, guard block masks, guard visit/fight metadata, and protected route links must be physical runtime gates, not just visual objects.
   - No protected zone/town link may have a free unguarded runtime route unless recorded as an executable-derived exception.
   - Done when: package audit, editor inspection, and runtime pathing agree on guarded and blocked zone links.

5. **Small-land object breadth closeout**
   - Status: `pending_after_owner_small_acceptance`
   - Mines and reward value-band/proxy metadata have focused evidence; finish the remaining strict Small-land object-family proof, especially artifacts and neutral object families.
   - Preserve body masks, visit masks, block masks, value bands, zone/global limits, save/load identity, and project asset adaptation only at final package/runtime boundaries.
   - Done when: mines, resources, rewards, artifacts, neutral objects, masks, value bands, and package provenance are covered by strict Small-land evidence.

6. **Full Small-land production gate**
   - Status: `mandatory_before_reclaiming_ready`
   - Required gate after the last fix: native rebuild, template hard lock, source-state/owner-transition diagnostics, structural corpus, runtime corpus, negative validator, package surface topology, disk package startup, guard/reward adoption, editor visibility, manual inspection export, `jq empty ops/progress.json`, `git diff --check`, and maps-folder hygiene.
   - Generated `.amap` / `.ascenario` and uploaded `.h3m` evidence files must remain uncommitted.
   - Done when: the full bundle passes after inspection-driven corrections.

7. **Strict Small-land production declaration**
   - Status: `blocked_until_owner_acceptance_and_gate_green`
   - Keep `production_ready == true` scoped only to `strict_small_36x36_one_level_land_only`.
   - Unsupported modes must keep returning explicit blocked output with no generated payload.
   - Done when: owner inspection accepts strict Small land and the full gate stays green.

8. **Post-Small expansion**
   - Status: `blocked`
   - Expand only after strict Small land is accepted.
   - Initial order: Small water/islands, Small underground/two-level, Medium land, then larger sizes and broader template families.
   - Each expansion needs its own h3maped-derived phase work, native negative cases, structural audit, corpus audit, package save/load audit, editor acceptance, runtime acceptance, and manual inspection packages.

## Objective Completion Audit

Audit date: 2026-05-15.

Objective: continue the limited-scope native RMG GDExtension from `/root/Downloads/h3maped.exe`, with no custom workarounds, no brute-force fitting, no unapproved reset, project assets adapted only at package/runtime boundaries, and a fully working RMG following this file.

### Prompt-To-Artifact Checklist

| Requirement | Evidence artifact | Current result |
| --- | --- | --- |
| Limited-scope native RMG GDExtension remains the active path | `ops/progress.json` current slice `native-rmg-small-h3maped-port-10184`; `PLAN.md`; this file | Active, but blocked pending owner/manual inspection |
| Based on `/root/Downloads/h3maped.exe` and recovered spec | `docs/native-rmg-small-h3maped-reset.md`; `tests/native_rmg_small_h3maped_port_boundary_report.tscn`; source-template metadata in generated packages | Covered for strict Small land only |
| No custom workarounds, brute-force fitting, catalog-auto fallback, or translated-template authority | `tests/native_rmg_small_h3maped_template_selection_hard_lock_report.tscn`; negative cases in `tests/native_rmg_small_h3maped_negative_validator_report.tscn`; forbidden-fix rules in this file | Covered by current gates; keep as regression after every fix |
| Use project assets and structures only at adaptation/package/runtime boundaries | `src/gdextension/src/h3maped_small_rmg.cpp`; `src/gdextension/src/map_package_service.cpp`; package save/load tests; guard/reward adoption tests | Covered for current towns, roads, blockers, guards, mines, rewards, and decorative obstacles |
| Strict Small 36x36 one-level land emits usable packages | `.artifacts/rmg_small_manual_inspection_manifest.json`; `.artifacts/rmg_small_manual_inspection_summary.md`; `maps/manual-strict_small_*` local package pairs | Green local evidence for 2p/3p/4p owner-review packages |
| Player starts are at owned player towns | manual export summary town-start tables; runtime corpus; package topology report | Covered pending manual/editor visual confirmation |
| Roads are real route infrastructure | `tests/native_random_map_package_surface_topology_report.tscn`; runtime acceptance; summary road edges/topology previews | Green regression gate pending manual/editor visual confirmation |
| Zone links are physically guarded/blocked | route gate summary with zero unguarded links; disk startup blocker/guard pathing report; summary topology previews | Green regression gate pending manual/editor visual confirmation |
| Manual owner acceptance is complete | Owner inspection of `maps_package:manual-strict-small-2p-seed-1`, `maps_package:manual-strict-small-3p-seed-2`, `maps_package:manual-strict-small-4p-seed-3` using `.artifacts/rmg_small_manual_inspection_summary.md` | Not complete; active blocker |
| Artifact and broader neutral-object breadth is proven | artifact/object-family gates and strict Small-land evidence after owner acceptance | Not complete; artifact proxies exist `2/1/2`, literal artifact objects are `0/0/0` |
| Water/islands, underground/two-level, Medium, Large/XL, broader template families are production ready | future h3maped-derived mode-specific gates | Not started; explicitly blocked until strict Small land is accepted |
| Fully working RMG following this file | all slices 1-9 in `Remaining Slices Until Production Ready` accepted and green | Not achieved |

1. **h3maped.exe-derived strict Small-land pipeline**
   - Evidence: active slice `native-rmg-small-h3maped-port-10184`; binary anchor `/root/Downloads/h3maped.exe`; original source-template authority in generated packages; native build and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` pass.
   - Status: `covered_for_strict_small_land_only`.
   - Gap: water, underground/two-level, Medium/Large/XL, and broader template families remain explicitly blocked.

2. **No catalog-auto, translated-template, or per-case fitting authority**
   - Evidence: strict Small-land package metadata uses `h3maped_exe_rng`; unsupported profiles return blocked output; `rmg-slices.md` forbids count fitting, fake guards, proxy blockers, visual-only roads, and archived catalog-auto fallback.
   - Status: `covered_by_current_gates`.
   - Gap: keep this as a regression gate after every fix.

3. **Project assets and structures only at package/runtime boundaries**
   - Evidence: generated towns, blockers, guards, roads, mines, rewards, and decorative obstacles are materialized as project package objects with body/visit/block masks; package save/load/editor visibility evidence exists for strict Small land.
   - Status: `covered_for_current_object_families`.
   - Gap: artifact and broader neutral-object family proof is not complete.

4. **Roads and zone links are real gameplay infrastructure**
   - Evidence: manual inspection summary reports route nodes/edges, guarded route links, road tile counts, zero unguarded links, and package-derived topology previews for the three exported packages; runtime-corpus evidence checks start-to-road reachability and blocked-corner semantics.
   - Status: `green_regression_gate_pending_manual_confirmation`.
   - Gap: visual/manual acceptance is still required because roads that pass data checks may still read poorly or incorrectly in the editor.

5. **Starts and town ownership**
   - Evidence: exported 2p/3p/4p packages each have one start town per player slot, owned player towns, route-node runtime-zone handoff fixed, and editor-load status `ok`.
   - Status: `covered_pending_manual_confirmation`.
   - Gap: owner/editor visual inspection still decides whether the baseline is acceptable.

6. **Artifacts and object breadth**
   - Evidence: manual inspection summary reports artifact-category reward proxy counts `2/1/2` for the 2p/3p/4p exported strict Small-land packages, and literal artifact object counts `0/0/0`.
   - Status: `not_complete`.
   - Gap: finish true artifact object semantics and neutral-object breadth only after owner accepts the Small-land baseline or records concrete defects.

7. **Full RMG production readiness**
   - Evidence: strict Small-land scope has focused source-state, package-surface, runtime, corpus, negative-validator, editor, and manual-export evidence.
   - Status: `not_complete`.
   - Gap: the objective is not achieved as a full RMG. Current production-ready claim is scoped only to `strict_small_36x36_one_level_land_only`, pending owner/manual inspection and full gate rerun after any accepted fixes.

## Current Production-Ready Slice Contract

This is the current owner-facing order from the strict Small-land generator to production readiness. It is the source of truth for the next work. Older detailed sections below remain evidence, regression gates, and history; they do not authorize side quests, per-case fitting, or broader map modes.

1. **Inspection summary export**
   - Status: `completed_local_validated`
   - Added a human-readable Markdown summary beside the JSON manifest for the three manual inspection packages.
   - The summary must list, per generated package: zones, player-owned towns, neutral towns, zone links, guarded links, roads, road tiles, guards, blockers, decorative obstacles, mines, rewards, artifacts, editor-load status, start-town contracts, town start tiles, route gates, road edges, and a topology preview generated from loaded package data.
   - Done: `.artifacts/rmg_small_manual_inspection_summary.md` is generated by `tools/rmg_small_manual_inspection_export.tscn`; the latest run reported 3/3 cases ok, 3/3 editor loads ok, 3/3 maps-folder index hits, zero unguarded route links, and validator-gated 36x36 topology previews for all three packages.

2. **Owner manual inspection**
   - Status: `active_pending_owner_review`
   - Inspect `manual-strict_small_2p_seed_1`, `manual-strict_small_3p_seed_2`, and `manual-strict_small_4p_seed_3` in the built-in map picker/editor.
   - Check towns, starts, zones, roads, guarded links, blockers, decorative obstacles, guards, mines, rewards, artifacts, and visible passability.
   - Pre-review package-data correction: route graph town nodes now preserve the same `runtime_zone_index` as their referenced town records; the package topology report gates missing, unknown, and mismatched route-node town zones.
   - Follow-up validation: native rebuild and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the route-node correction.
   - Done when: the packages are accepted as the strict Small-land baseline or concrete defects are recorded with package id, seed/player count, and visible symptom.

3. **Inspection-driven defect fixes only**
   - Status: `pending_manual_findings`
   - Fix only real defects found in the exported strict Small-land packages or their generated summary.
   - Valid fixes must come from the h3maped-derived phase pipeline or the package/runtime boundary.
   - Forbidden fixes: per-seed corridors, count fitting, proxy guards, fake blockers, visual-only roads, translated-template authority, archived catalog-auto fallback, or weakening guards/connection blockers to make pathing pass.
   - Done when: each accepted defect has a native/data fix plus a focused regression gate.

4. **Small-land production gate rerun**
   - Status: `mandatory_after_fixes`
   - Rerun the complete strict Small-land acceptance bundle after any inspection-driven change.
   - Required coverage: native rebuild, template hard lock, source-state/owner-transition diagnostics, structural corpus, runtime corpus, negative validator, package surface topology, disk startup, guard/reward adoption, editor visibility, manual inspection export, `jq empty ops/progress.json`, `git diff --check`, and maps-folder hygiene.
   - Done when: the full bundle passes after the last inspection-driven fix.

5. **Small-land object breadth closeout**
   - Status: `pending_after_owner_acceptance`
   - Close any remaining strict Small-land object-family breadth gaps, especially artifacts and neutral object families, while preserving h3maped phase provenance.
   - Keep project asset ids/content adaptation only at package/runtime boundaries.
   - Done when: mines, resources, rewards, artifacts, neutral objects, value bands, body masks, visit masks, block masks, save/load identity, and package provenance are covered by strict Small-land evidence.

6. **Production-ready strict Small-land declaration**
   - Status: `blocked_until_owner_acceptance_and_gate_green`
   - Keep `production_ready == true` scoped only to `strict_small_36x36_one_level_land_only`.
   - No water, islands, underground/two-level, Medium/Large/XL, or broader template-family payloads may be exposed.
   - Done when: owner inspection accepts strict Small land and the full gate stays green.

7. **Expansion after Small-land**
   - Status: `blocked`
   - Expand only after strict Small land is accepted.
   - Initial expansion order: Small water/islands, Small underground/two-level, Medium land, then larger sizes and broader template families.
   - Each expansion must start from h3maped-derived phase behavior and receive its own structural audit, negative validator cases, corpus audit, package save/load audit, editor acceptance, runtime acceptance, and manual inspection packages.

## Authoritative Next Slices

This is the current production-readiness runway. Treat this list as the decision order; older slice notes below are evidence and regression gates, not permission to broaden scope.

1. **Manual inspection package export**
   - Status: `exported_local_uncommitted_pending_owner_review`
   - Exported a small owner-review set of strict Small 36x36 one-level land `.amap` / `.ascenario` package pairs into `maps/` for local inspection only: `manual-strict_small_2p_seed_1`, `manual-strict_small_3p_seed_2`, and `manual-strict_small_4p_seed_3`.
   - Repeat with `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tools/rmg_small_manual_inspection_export.tscn`.
   - The export manifest is `.artifacts/rmg_small_manual_inspection_manifest.json`; all three cases saved, loaded, reported `production_ready == true` for `strict_small_36x36_one_level_land_only`, appeared in the maps-folder package index, and opened through `MapEditorShell.validation_load_maps_folder_package()`.
   - The manifest includes per-package `inspection_summary` counts for zones, player-owned/human/computer/neutral towns, route links, guarded links, road records, unique/source/segment road cells, guards, connection blockers, decorative obstacles, mines, rewards, artifacts, object totals, and object counts by kind.
   - The same run writes `.artifacts/rmg_small_manual_inspection_summary.md`, a human-readable owner-review handoff with exact package ids, acceptance checklist, defect-report format, package paths, editor-load status, topology previews, towns/starts, guarded and unguarded links, route gates, road edges, and object-family counts.
   - The manifest also includes compact `town_start_summary` and `route_gate_summary` sections. The exporter fails if player-owned towns, start towns, start contract counts, town-start summaries, route-link counts, guarded-link counts, unguarded links, or road records are inconsistent with the strict Small-land case.
   - Do not commit generated `.amap`, generated `.ascenario`, or uploaded `.h3m` evidence.
   - Done when: owner loads the generated packages in the built-in map picker/editor and inspects towns, zones, roads, blockers, guards, mines, rewards, and starts without debug-only interpretation.

2. **Owner inspection corrections**
   - Status: `next_pending_manual_findings`
   - Fix only real defects found in owner/manual inspection that contradict package audit data, runtime behavior, or recovered h3maped behavior.
   - Valid fixes must come from the h3maped/spec phase pipeline or package/runtime boundary adaptation; no per-seed corridors, count fitting, proxy guards, fake blockers, or visual-only roads.
   - Done when: the inspected Small-land packages are acceptable as the baseline for the strict supported scope.

3. **Lock the Small-land acceptance bundle as the release gate**
   - Status: `green_but_must_remain_mandatory`
   - Keep the full strict Small-land bundle mandatory after any RMG change: native rebuild, package surface topology, roads, blocker/guard runtime masks, object economy, negative validator, template hard lock, 15-case structural corpus, 15-case runtime corpus, editor visibility, package save/load, `jq empty ops/progress.json`, `git diff --check`, and maps-folder hygiene.
   - Done when: the bundle is the documented gate for changing or re-claiming `production_ready` on strict Small land.

4. **Broaden Small-land corpus only if inspection exposes variance**
   - Status: `conditional`
   - Add more Small land seeds/player-count cases only to cover a real failure mode, not to tune counts against uploaded examples.
   - The audit remains structural: zones, player-owned towns, neutral towns, zone links, roads, guarded links, blockers, decorative obstacles, mines, rewards, artifacts, object masks, passability, serialization, editor adoption, and runtime pathing.
   - Done when: any newly found Small-land failure has a native/data regression test and the full bundle passes again.

5. **Artifact and neutral-object breadth**
   - Status: `pending_after_owner_small_acceptance`
   - Finish any remaining Small-land object families not yet proven by the focused object-economy gate, especially artifacts and neutral object masks/value bands.
   - Keep project ids/assets adapted only at final package/runtime boundaries after the matching h3maped phase exists.
   - Done when: mines, rewards, artifacts, neutral objects, value bands, body masks, visit masks, block masks, and save/load identity are covered by the Small-land corpus.

6. **Expansion gate**
   - Status: `blocked`
   - Start water/islands, underground/two-level maps, Medium/Large/XL, and broader template families only after strict Small land is owner-accepted and the release gate remains green.
   - Each new mode must get the same h3maped-derived pipeline, negative validator cases, corpus audit, package save/load audit, editor acceptance, and runtime acceptance.
   - Done when: a new mode is production-ready by its own evidence, not inherited from Small land.

## Current Remaining Production Slice Order

This is the remaining path from the current focused Small-land state to production-ready Small 36x36, one-level, land-only RMG. Earlier focused slices stay as regression gates; they are not permission to broaden scope.

1. **Slice G - Small-land corpus audit**
   - Status: focused regression gate passed for the current supported Small-land sample.
   - Run supported Small-land seeds and player counts through the native validator, package conversion, package save/load, and structural audit.
   - Prove zones, player-owned towns, neutral towns, zone links, roads, guards, guarded links, blockers, decorative obstacles, mines, rewards, artifacts, passability, and serialization do not have systemic failures.
   - Fix executable-phase logic only; no seed-specific patches, no count fitting, and no translated-template fallback.

2. **Slice H - Editor/runtime acceptance**
   - Status: focused runtime/editor/renderer acceptance and 15-case runtime-corpus start-to-road reachability have local green evidence; keep both as regression gates.
   - Verify generated packages appear in the map picker, load in the editor, render correctly, and run in game.
   - Runtime pathing must agree with package body/visit/block masks for roads, blockers, guards, towns, mines, rewards, and artifacts.
   - Save/load must preserve map identity, objects, route graph, pathing behavior, and player-start ownership.
   - Current evidence: the focused report now generates, saves, loads, adopts, renders, and paths from the start-town visit tile to a package road tile after the native footprint gate stopped accepting occupied road cells as decorative bodies; the runtime corpus now uses the same blocked-corner semantics as runtime pathing.

3. **Template-selection hard lock**
   - Status: focused hard-lock regression gate passed.
   - Supported Small-land profiles must select from original h3maped template data.
   - Unsupported profiles must return explicit blocked statuses.
   - No archived generator, translated-template behavior, or catalog-auto output can decide production template behavior.

4. **Small-land production readiness gate**
   - Status: strict Small 36x36 one-level land `production_ready` flag enabled in code; post-flag full acceptance bundle passed locally; pending owner manual inspection.
   - `production_ready == true` applies only to `strict_small_36x36_one_level_land_only`.
   - Negative validator coverage, corpus coverage, package save/load, editor visibility, runtime pathing, rendering, and hard-locked template authority must stay green before any broader scope is considered.

5. **Expansion gate**
   - Only after Small one-level land is correct, expand to water/islands, underground/two-level maps, Medium/Large/XL, and broader template families.
   - Each new mode needs the same executable-phase pipeline, negative tests, corpus audit, package save/load audit, editor acceptance, and runtime acceptance.

## Ground Rules

- No archived catalog-auto fallback.
- No translated-template behavior as production authority.
- No count-fitting against a few uploaded maps.
- No proxy blockers, fake guards, visual-only roads, or self-declared validation.
- No runtime package output until terrain, towns, rewards, roads, blockers, guards, and final package serialization are coherent.
- Project/original content ids are adapted only at final object/package boundaries after the matching h3maped phase exists.
- Uploaded `.h3m` evidence maps are inspection data and must not be committed.

## Current Implemented Boundaries

These boundaries are useful progress, but they are not production readiness:

1. H3maped small-template selection is active for the strict reset path.
2. Original h3maped template hydration is used for runtime-zone/link semantics instead of translated-template authority.
3. Terrain repaint, visual selection, and tile-byte candidate phases are materialized as private strict report state.
4. Player towns and starts are synchronized in the package draft.
5. Mine and reward object coordinate records are materialized in the package draft.
6. Road overlay bytes are materialized privately and included in the package draft.
7. Connection blocker and guard records are materialized privately and included in the package draft.
8. The final `0x49b2b6` writeout draft now combines terrain bytes, zero river bytes for the current small-land scope, road bytes, flip flags, and package object payload metadata.
9. A fast native structural validator now checks the package/writeout drafts without launching a Godot report scene.
10. The package/writeout drafts currently contain the small-land core object families.
11. `generate_random_map()` now returns a public Small land package only when the fast structural validator passes; unsupported configs still return explicit blocked status.
12. `convert_generated_payload()` now accepts the validator-gated h3maped Small result directly and produces `MapDocument` / `ScenarioDocument` package-session records without using the archived translated-generator adopter.
13. The adopted h3maped Small map/scenario documents validate, save to temporary `.amap` / `.ascenario` packages, reload, and preserve map hash, object count, and start contract.
14. Validator-gated h3maped Small package pairs save under `maps/`, index as generated package entries, appear in the editor Load Map picker, load as package-backed editor working copies, and stay out of authored JSON/generated-draft registries.
15. H3maped road predecessor chains are now adopted as package route segments with unique road tile counts, segment cell counts, and duplicate segment-cell diagnostics kept separate.
16. Generated package objects now expose body, visit, and blocking tile masks so editor/runtime pathing can reason about towns, mines, rewards, blockers, and guards from package data instead of visual-only object placement.

## Known Current Gap

The current Small land output now has focused evidence for source-state, package-surface topology, road package topology, runtime guard/blocker masks, object economy, negative validator cases, template-selection hard lock, structural corpus coverage, focused runtime/editor acceptance, runtime-corpus start-to-road reachability, and one full Small-land acceptance-bundle pass. The production flag boundary is deliberately scoped to strict Small 36x36 one-level land only; manual inspection confidence and the post-flag full-bundle rerun remain the current verification gate.

The earlier decorative filler fix is still a valid regression gate. It adds a native generated-cell decoration bit-state phase for `0x49aa63` / `0x49a932`, runs the `0x49eb8d -> 0x49e700` decorative filler boundary using recovered `object-decoration-obstacles.csv`, recovered object templates, project blocker ids at the package boundary, and `0x49a932` remaining-candidate lock behavior, then verifies focused package facts for h3maped template `018`.

The old open-corridor failure is no longer the only gap, and the old owner-transition fallback must not come back. The port now isolates the bit-26/bit-27 state before the filler and reports the upstream writer sources separately: focused template `018` has no signed owner-byte cells for the `0x4a8c15 -> 0x49a962` cleanup writer, no source-bucket-3 runtime zones for the `0x4a89da` junction candidate writer, no current border-guard marker cells for the `0x4a5a23` marker path, no source-water cells for the `0x4a4fc5` water-edge writer in the strict land scope, and 120 occupied/no-decoration cells through the `0x49a932` normalization path. The `0x4a4c8e` land-edge writer is now the active land-scope bit-26 source: focused template `018` exposes 10 reciprocal `0x49b3fb` relation records and produces 605 bit-26 candidate writes before later object occupancy. A 45-case diagnostic sample across seeds 1-15 and 2/3/4 player Small-land configs found the removed owner-transition fallback would add zero new bit-26 cells. `exact_upstream_bit_source_claim` is therefore a per-map generated-cell source-state claim gated by a zero diagnostic gap, not a production-ready RMG claim.

The remaining gap is post-flag verification and owner inspection: focused source-state, package-surface, blocker/guard runtime, object-economy, negative-validator, Small-land corpus, runtime-corpus, editor, and renderer reports passed together locally, and `production_ready` is now true only for strict Small 36x36 one-level land. Do not regress this into random overfill, midpoint guards, count fitting, translated-template authority, or per-seed patches.

The `cell+0x20` owner-byte precondition is now live state, not a late derivation from `zone_words`: the focused seed/template reports 1107 assigned owner-byte cells and 189 constructor-sentinel cells, and both connection owner scans and the `0x4a8c15` cleanup source read bits16..23 from that vector. The cleanup source still contributes zero bit-26 cells for the focused seed because the remaining sentinel cells are water-skipped and assigned owner bytes are non-negative, so Slice A remains a regression gate while later slices broaden coverage.

The `0x4a4fc5` water-edge bit-26 writer is now measured separately. In the focused Small land seed it scans all 1296 cells, skips the 189 unassigned constructor-sentinel cells at the owner-low gate, sees zero source-water cells after that gate, and produces zero bit-26 candidates. That means it is not the land-scope replacement for the temporary owner-transition fallback; the next exactness work should stay on land-active writer paths rather than forcing `0x4a4fc5` to explain non-water topology.

The `0x4a4c8e` land-edge writer is now measured and materialized through recovered runtime-zone relation vectors. Focused template `018` exposes 10 reciprocal `0x49b3fb` relation records and zero `Wide` byte-`+8` suppressions. The focused Small land seed scans 1296 cells, evaluates 1107 non-water owner-low cells, probes 8461 neighbors, records 332 exact relation lookup-miss triggers, records 574 relation byte-`+8 == 0` triggers, and produces 605 bit-26 candidate writes before later object occupancy. A 45-case diagnostic sample across seeds 1-15 and 2/3/4 player Small-land configs found the old owner-transition fallback would add zero new bit-26 cells, so the fallback no longer writes bit 26 and now remains only as a diagnostic gap counter. `exact_upstream_bit_source_claim` is now a per-map generated-cell source-state claim gated by that zero diagnostic gap; it is not a production-ready RMG claim. Do not claim production parity until the remaining production slices pass.

## Production-Ready Remaining Slice Checklist

This is the practical remaining path from the current strict Small-land state. It replaces older overlapping “remaining slices” notes: focused reports that already pass are regression gates, not new work items. No broader map size, water, underground, or template-family work starts until this Small 36x36 one-level land baseline is accepted.

1. **Owner manual inspection of exported Small-land packages**
   - Status: `active_next`
   - Inspect the generated `manual-strict_small_2p_seed_1`, `manual-strict_small_3p_seed_2`, and `manual-strict_small_4p_seed_3` packages in the built-in map picker/editor.
   - Inspect zones, owned player towns, neutral towns, roads, guarded links, blockers, decorative obstacles, guards, mines, rewards, artifacts, starts, and obvious pathing breaks.
   - Done when: either the exported strict Small-land maps are accepted as the baseline or concrete defects are recorded with package id, seed/player count, and visible symptom.

2. **Correct only defects found by inspection**
   - Status: `pending_manual_findings`
   - Fix only real Small-land defects that contradict h3maped/spec behavior, package audit data, editor behavior, or runtime behavior.
   - Valid fixes must come from the executable-derived phase pipeline or a package/runtime boundary adaptation.
   - Forbidden fixes: per-seed corridors, count fitting, proxy guards, fake blockers, visual-only roads, translated-template authority, archived catalog-auto fallback, or weakening connection blockers/guards to make pathing pass.
   - Done when: every recorded inspection defect has a native/data fix and a regression gate.

3. **Keep template authority and source-state locked**
   - Status: `green_regression_gate`
   - Supported strict Small-land configs must continue selecting original `h3maped_template_*` source-template authority through the h3maped executable RNG path.
   - Unsupported profiles must continue returning blocked statuses with no map payload.
   - The removed owner-transition bit-26 fallback must stay diagnostic-only; `exact_upstream_bit_source_claim` must remain true for accepted Small-land corpus cases.
   - Done when: source-state, owner-transition diagnostic, and template-selection hard-lock gates remain mandatory after every Small-land change.

4. **Keep zones, towns, starts, and links coherent across package/editor/runtime**
   - Status: `green_regression_gate_pending_manual_confirmation`
   - Player starts must stay at owned player towns.
   - Zone links must match package route graph/link metadata and must not collapse into one open runtime blob.
   - Neutral towns must appear only when executable-derived phases produce them.
   - Done when: package data, saved `.amap` / `.ascenario`, editor load, runtime session state, and pathing agree on zones, owned towns, neutral towns, starts, links, guarded links, and traversal.

5. **Keep roads as real route infrastructure**
   - Status: `green_regression_gate_pending_manual_confirmation`
   - Roads must remain h3maped predecessor-chain route infrastructure with route nodes, route edges, meaningful segment lengths, road tile bytes, package route graph data, editor rendering, runtime rendering, and pathing in agreement.
   - Short disconnected visual loops are invalid unless they are explicitly executable-derived and recorded as such.
   - Done when: every accepted Small-land map has meaningful road infrastructure connecting h3maped endpoints, and runtime movement/rendering matches package road data.

6. **Keep blockers, decorative obstacles, and guards as actual zone gates**
   - Status: `green_regression_gate_pending_manual_confirmation`
   - Connection blockers, decorative blockers, guard block masks, guard visit/fight metadata, and protected route links must match package audit data.
   - No protected zone/town link may have a free unguarded runtime route unless recorded as an executable-derived exception.
   - Done when: manual inspection and runtime/path audits agree that gates are physical, not just decorative.

7. **Finish object-economy breadth inside the Small-land scope**
   - Status: `pending_after_manual_small_acceptance`
   - Mines and reward proxy/value-band metadata have focused evidence; the remaining breadth check is artifacts and neutral object families across supported Small-land cases.
   - Preserve body masks, visit masks, block masks, value bands, zone/global limits, save/load identity, and original-project asset adaptation at package/runtime boundaries.
   - Done when: mines, resources, rewards, artifacts, neutral objects, masks, value bands, and package provenance follow recovered h3maped phase data without count-fitting uploaded examples.

8. **Keep native negative validator coverage ahead of runtime exposure**
   - Status: `green_regression_gate_extend_on_new_failures`
   - Existing native negative fixtures cover missing starts, duplicate placement ids, out-of-bounds objects, missing mines/rewards, missing connection blockers/guards, missing route graph, one-cell fake roads, and bad final tile-byte arrays.
   - Add rejection cases for any new invalid shape found during manual inspection: open cross-zone routes, blocked starts, blocked reward visits, artifact-specific mask failures, package/runtime mask divergence, or malformed road/link records.
   - Done when: known-bad packages fail through native/data validation before editor/runtime exposure, without requiring a full Godot scene for basic package correctness.

9. **Run the full Small-land acceptance bundle as the production gate**
   - Status: `mandatory_before_reclaiming_ready`
   - Required gate: native rebuild, focused runtime acceptance, 15-case runtime corpus, structural corpus, template-selection hard lock, negative validator report, package surface topology report, disk package startup report, object-economy package adoption report, package save/load/editor visibility reports, `jq empty ops/progress.json`, `git diff --check`, and maps-folder hygiene.
   - Generated `.amap` / `.ascenario` and uploaded `.h3m` evidence files must remain uncommitted.
   - Done when: the full bundle passes after inspection-driven corrections.

10. **Hold production readiness to the proven Small-land scope**
    - Status: `strict_small_only`
    - `production_ready == true` means only `strict_small_36x36_one_level_land_only`.
    - Water, islands, underground/two-level maps, Medium/Large/XL, and broader template families stay blocked with no generated payloads.
    - Done when: owner inspection accepts strict Small land and all unsupported modes remain explicitly blocked.

11. **Expansion slices after Small-land acceptance**
    - Status: `blocked`
    - Expand only after items 1-10 are green and owner-accepted.
    - Each new mode must start from the same h3maped-derived phase pipeline and get its own structural audit, native negative cases, corpus audit, package save/load audit, editor acceptance, runtime acceptance, and manual inspection packages.
    - Initial expansion order after Small-land acceptance: Small water/islands, Small underground/two-level, then Medium land, then larger sizes/template families.

## Current Non-Negotiable Gap

The current generator is production ready only for strict Small 36x36 one-level land. Focused Small-land source-state, package-surface, runtime-blocker, object-economy, negative-validator, structural corpus, runtime-corpus, editor/runtime, and the post-flag full-bundle evidence support that narrow boundary; unsupported modes remain blocked and broad production parity must stay false.
