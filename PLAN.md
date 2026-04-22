# PLAN.md

Task: #10184

Reality reset date: 2026-04-16

## Strategy
We are building toward a full, original, release-bound fantasy strategy game, but the current repository is a prototype / pre-alpha foundation, not a playable product and not close to HoMM2/3 parity.

The planning story now changes from "many completed release-facing slices" to "prove one playable scenario, then grow breadth." Existing architecture is useful, but every feature claim must be tied to live-client behavior a real player can exercise.

## Locked Stack
- engine: Godot 4 stable series
- gameplay code: GDScript
- content source of truth: JSON files in `content/`
- save format: versioned JSON snapshots
- primary validation target: the live client, supported by automated checks

## Architecture Guardrails
- Keep simulation and serialization logic outside scene controllers.
- Use stable content ids instead of embedding authored data in saves.
- Autoloads are for cross-cutting services, not for hiding gameplay rules.
- Preserve a clean split between overworld, battle, town, AI, economy, save/load, UI, and content pipeline.
- Treat JSON-authored content as the scalable boundary for factions, heroes, units, spells, artifacts, towns, map objects, scenarios, encounters, and campaigns.
- Keep scenic and play surfaces primary. Do not solve missing usability by stacking text panels over the game.
- Every slice must be judged by live-client player flow, not just by data existence, rule coverage, or smoke-test routing.
- River Pass has now cleared the manual play gate per AcOrP's 2026-04-18 report; expand breadth in a controlled alpha-facing way instead of jumping straight to broad campaign sprawl.

## Current Implementation Slice: Map Editor Zoom Compromise
Status: completed on 2026-04-22 as a narrow editor-only view-framing correction.

Purpose:
- Correct the 48-tile editor preview zoom-out after AcOrP reported it made the in-project map editor laggy and unusable.
- Keep the editor zoomed out beyond gameplay, but only to a moderate 24-tile span so large scenario editing stays practical.
- Preserve normal overworld gameplay framing and large-map tactical zoom.
- Keep the shared `OverworldMapView` renderer path intact by preserving the explicit opt-in visible-tile-span override for editor scenes instead of changing global gameplay constants.

Implemented:
- Preserved the exported large-map visible-tile-span override on `OverworldMapView`.
- Reduced the editor scene override from a 48-tile span to a 24-tile span, two times the gameplay tactical default of 12.
- Updated focused smoke coverage to prove the editor override is active at the moderate span while gameplay Ninefold framing stays on the default span.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not a terrain renderer rewrite, gameplay camera redesign, map data change, save-format change, panning behavior rewrite, or global overworld zoom change.

## Completed Implementation Slice: HoMM3 Mixed-Corner Class Reason Payload Parity
Status: completed on 2026-04-22 as a narrow active validation/inspector payload correction.

Purpose:
- Make the live/editor `class_reason` payload for accepted relation classes 17 and 18 match the web prototype's mixed-corner trigger text.
- Preserve relation-class selection, selected frame ids, flip flags, selected frame blocks, terrain ownership, roads, objects, pathing, save data, editor tools, and asset staging.
- Avoid treating this as a broader HoMM3 terrain parity claim.

Implemented:
- `TerrainPlacementRules._classify_relations` now reports `E=1,S=1,SW=2; mixed corner block` for class 17 and `E=1,S=1,NE=2; mixed corner block` for class 18, matching the accepted web prototype.
- Map-editor smoke coverage now seeds exact class-17 and class-18 relation rings through the shared editor/live preview payload and asserts both `homm3_class_reason` and `homm3_web_prototype_class_reason`.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not whole HoMM3 terrain parity, a rendered frame choice change, visual old-frame retention modeling, water shoreline topology, rock/void topology, terrain art replacement, gameplay/pathing change, save-format change, or exact original executable lookup recovery.
- The next visually meaningful parity gap still requires fresh live/editor visual evidence rather than inferring from dead metadata alone.

## Current Implementation Slice: HoMM3 Selected Frame Block Payload Truth
Status: completed on 2026-04-22 as a narrow active validation-payload correction.

Purpose:
- Make the live/editor `selected_frame_block` payload describe the atlas frame block that the active relation-class selector actually chose.
- Preserve the accepted web prototype relation-class frame selection, direct water/rock fallback signal, and quadrant reprojection payloads.
- Avoid changing terrain ownership, row-bucket selection, rendered frame ids, roads, objects, pathing, save data, editor tools, or asset staging.

Implemented:
- `TerrainPlacementRules.visual_selection_payload` now reports fallback selected-frame blocks from the full/interior rows that were actually chosen instead of the missing requested transition class.
- Water full/interior row selections now report the grammar-backed `open_water_interiors` block id, and rock full/interior row selections now report the active `rock_black_void` frame block used by the relation-class row table.
- Map-editor smoke coverage now asserts the unmaintained water/rock class-24 fallback cases expose the selected frame block matching the chosen fallback rows.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not whole HoMM3 terrain parity, a water shoreline topology rewrite, a rock/void topology rewrite, terrain art replacement, gameplay/pathing change, save-format change, visual old-frame retention modeling, or exact original executable lookup recovery.

## Current Implementation Slice: HoMM3 Web Prototype Quadrant Reprojection Parity
Status: completed on 2026-04-22 as a narrow active validation/inspector parity correction.

Purpose:
- Preserve the accepted web prototype's cardinal quadrant reprojection alongside the relation-class selected terrain frame.
- Keep the direct water/rock fallback truth signal inspectable through material, normalized, visual, and display quadrant payloads instead of only through relation-ring metadata.
- Avoid changing terrain ownership, frame row selection, roads, objects, pathing, save data, editor tools, or asset staging.

Implemented:
- `TerrainPlacementRules.visual_selection_payload` now includes the accepted web prototype's owner-footprint, material, normalized/count, visual, and display quadrant projections alongside relation class, row group, frame, flags, and fallback metadata.
- `OverworldMapView` now exposes those projection fields through the live-overworld and map-editor terrain validation payload.
- Map-editor smoke coverage now asserts the direct water/rock fallback case preserves the accepted projection output on both the water receiver and rock receiver sides.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not whole HoMM3 terrain parity, a water shoreline topology rewrite, a rock/void topology rewrite, terrain art replacement, gameplay/pathing change, save-format change, or exact original executable lookup recovery.
- Quadrant reprojection remains a validation/inspector parity surface; the selected atlas frame remains the active terrain visual.

## Current Implementation Slice: HoMM3 Direct Water/Rock Contact Fallback Parity
Status: completed on 2026-04-22 as a narrow active selector parity correction.

Purpose:
- Preserve the accepted web prototype relation-class behavior that marks direct water/rock adjacency as an explicit unresolved fallback while still exposing the selected relation-class placeholder frame.
- Keep the post-8c96465 relation-class row-bucket selector as the active Godot terrain frame path.
- Avoid reviving legacy receiver-stamp/corner heuristics or changing roads, objects, pathing, save data, editor object tools, or terrain placement ownership rules.

Implemented:
- `TerrainPlacementRules.visual_selection_payload` now detects direct water/rock neighbor contact, marks the selected visual payload as fallback, and appends the accepted unresolved fallback reason without hiding the relation ring, class, row group, frame, or flags.
- `OverworldMapView` now exposes the direct water/rock fallback truth signal through live-overworld and map-editor validation payloads.
- Map-editor smoke coverage now seeds an actual water/rock adjacency and asserts both sides report the direct-contact fallback while retaining relation-class diagnostics.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not whole HoMM3 terrain parity, a water shoreline topology rewrite, a rock/void topology rewrite, terrain art replacement, gameplay/pathing change, save-format change, or exact original executable lookup recovery.
- The direct water/rock contact remains explicitly unresolved, matching the accepted web prototype's truth-preserving fallback behavior.

## Current Implementation Slice: HoMM3 Web Prototype Terrain Selection Parity
Status: completed on 2026-04-22 as a proper active renderer selection rewrite.

Purpose:
- Replace the active Godot HoMM3 terrain visual-selection path with the accepted web prototype's settled-owner relation-class and row-bucket selector.
- Preserve the HoMM3 owner queue, paint-order, and final-normalization placement path while eliminating the renderer drift caused by source-anchored stamp/corner heuristics in active frame selection.
- Keep roads, towns, objects, pathing, save schema, editor object tools, and unrelated presentation systems unchanged.

Implemented:
- Added the accepted web prototype/recovered HoMM3 relation classifier, final correction probes, row tables, special/full-row selection, rock row lookup, deterministic frame hashing, and relation-grid diagnostics to `TerrainPlacementRules`.
- Routed `OverworldMapView` terrain frame selection through that shared relation-class payload for live overworld and map-editor preview, with legacy receiver-stamp fields cleared from the active frame path.
- Updated terrain grammar and art manifest metadata so full receiver stamp lookup is marked reference-only for the active HoMM3 visual path.
- Updated map-editor, live-overworld, and Ninefold smoke coverage to assert relation class, row group, selected frame block, deterministic frame, flip flags, and preserved diagnostic source relationships for screenshot-style dirt/sand/swamp/water/rock parity cases.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is still a local HoMM3 reference/prototype renderer path, not shippable terrain art or a license-clean final asset pipeline.
- Visual frame retention from the web prototype's in-browser old-frame cache is intentionally not modeled because the Godot renderer evaluates from settled map state without that browser paint-cache object.
- Water/rock special systems now use the same row-bucket selector, but broader terrain art replacement, passability/pathing, road rendering, town/object presentation, and save schema are unchanged.

## Completed Implementation Slice: HoMM3 Sand-Heavy Corner Ownership Regression
Status: completed on 2026-04-22 as a narrow renderer/validation correction.

Purpose:
- Fix the reported Godot terrain-rendering regression where sand/grass corner transition tiles chose grass-heavy quadrant ownership, rendering as 3 grass + 1 sand instead of the expected 1 grass + 3 sand.
- Preserve the HoMM3 owner queue, rewrite, and final-normalization terrain placement path while correcting shared `OverworldMapView` frame selection for the specific sand-heavy two-cardinal-plus-corner topology.
- Keep roads, towns, objects, pathing, save schema, content schema shape, and unrelated renderer systems unchanged.

Implemented:
- Added data-driven sand `cardinal_corner_entries` to the full-receiver native-to-sand stamp table for the four N+E, E+S, S+W, and N+W sand-heavy corner orientations.
- `OverworldMapView` now detects a full-receiver land tile with two same-bridge cardinal sand sources plus the matching diagonal sand source and selects the sand-heavy corner stamp with the proper flip, instead of falling back to the first single-edge cardinal stamp.
- Added focused map-editor smoke coverage for all four sand-heavy corner orientations, asserting the selected `grastl` native-to-sand frame, source offset/direction, transform, and non-reserved sand-heavy ownership metadata.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not a broader terrain rewrite, road change, water/rock rewrite, terrain asset replacement, gameplay/pathing change, save-format change, town/object editing change, or exact original executable lookup recovery.
- Existing simple cardinal sand edge entries, dirt bridge entries, lower/source-cell suppression, water shoreline handling, rock handling, and editor owner queue placement remain intact.

## Completed Implementation Slice: HoMM3 Editor Terrain Placement Lower-Edge Regression
Status: completed on 2026-04-22 as a narrow renderer/validation correction.

Purpose:
- Fix the reported Godot map-editor terrain placement regression where the lower/source cells in a HoMM3 owner-queue painted dirt/sand cluster resolved as transition receivers against surrounding full-receiver land.
- Preserve the new HoMM3 owner queue, rewrite, and final-normalization placement path while making the shared preview honor source-cell base/interior ownership.
- Keep roads, towns, objects, pathing, save schema, content schema, and unrelated renderer systems unchanged.

Implemented:
- `OverworldMapView` now suppresses full-receiver-land neighbor contacts when the evaluated receiver tile is a sand base/decor material, and suppresses fallback reduced dirt receiver contacts against full-receiver land unless an explicit direct bridge pair owns that relation.
- Added a focused map-editor smoke regression that paints single sand and dirt source clusters through the HoMM3 owner queue and asserts the lower/source cells stay on interior/base frames while adjacent full-receiver grass still carries the transition.
- Updated the existing editor restamp expectation so the painted sand source tile reports the sand base interior block rather than a receiver-style base-context transition.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`

Limits:
- This is not a broader terrain rewrite, road change, water/rock rewrite, terrain asset replacement, gameplay/pathing change, save-format change, town/object editing change, or exact original executable lookup recovery.
- The existing direct dirt/swamp and dirt/sand bridge resolver cases remain intact; this only prevents source dirt/sand cells from acting like full-receiver transition tiles against ordinary full-receiver land.

## Completed Implementation Slice: HoMM3 Editor Terrain Placement
Status: completed on 2026-04-22 as a narrow editor-path behavior port.

Purpose:
- Move the recovered HoMM3 terrain ownership propagation, queue/rewrite behavior, and final-normalization reporting into the actual Godot map editor terrain paint/update flow.
- Keep the editor's terrain preview parity with the shared `OverworldMapView` renderer, while making the logical map mutation itself use the accepted placement model instead of a one-tile preview approximation.
- Preserve roads, gameplay/pathing, save format, object logic, town logic, and authored scenario schema.

Implemented:
- Added `scripts/core/TerrainPlacementRules.gd` as the shared core owner/queue/final-normalization rules module for map-editor terrain writes.
- Routed single-tile terrain paint, flood fill, terrain line, and terrain rectangle tools through the HoMM3 owner queue/rewrite path before refreshing the shared editor preview.
- Exposed terrain placement payloads in map-editor validation snapshots, including changed owner cells, queue guard state, and final-normalization summary.
- Kept hidden logical terrain ids available for validation/setup while preserving the curated HoMM3-style base terrain picker.
- Updated terrain grammar, overworld manifest metadata, shared renderer restamp metadata, and validation coverage to document that editor logical writes now use `homm3_owner_queue_rewrite_final_normalization.v1`.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not a road rewrite, gameplay/pathing change, save-format change, object/town editing change, original-art replacement, export/writeback path, water/rock topology rewrite, or full terrain renderer replacement.
- Final normalization currently reports the settled editor owner-map classification for validation; the renderer remains responsible for visual frame selection through the existing shared `OverworldMapView` path.

## Completed Implementation Slice: HoMM3 Solid Region Interior Stability
Status: completed on 2026-04-21 as a narrow renderer bug-fix slice.

Purpose:
- Stop full-receiver land interiors inside contiguous same-family snow/grass regions from selecting dirt/sand transition stamp frames through diagonal or second-ring sources.
- Keep the expected renderer rule simple and testable: solid interiors/base frames inside the region, oriented dirt/sand transition frames only on true outer cardinal boundaries.
- Preserve true edge transitions, shared live-overworld/map-editor preview validation, bridge material resolution, water/rock special systems, roads, gameplay/pathing, fog, panning, selection, save data, object logic, and town logic.

Implemented:
- `OverworldMapView` full-receiver land selection now keeps diagonal-only and second-ring dirt/sand contacts from selecting transition stamp frames; cardinal contacts still drive transition stamps.
- `content/terrain_grammar.json` and repo validation now document the cardinal-boundary-only full-receiver rule.
- Map-editor and live-overworld smoke fixtures now cover grass and snow regions surrounded by dirt: interior tiles stay on solid interior/base frames while outer cardinal edges still select oriented dirt stamp frames.
- Editor restamp coverage now verifies diagonal-only restamp receivers stay interior instead of projecting dirt/sand propagated stamps.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not a gameplay/pathing rewrite, save-format change, object/town logic change, exact original executable lookup recovery, water/rock rewrite, terrain art replacement, road change, or editor data-model change.

## Completed Implementation Slice: HoMM3 Full Land Receiver Stamp Lookup
Status: completed on 2026-04-21 as the next narrow renderer rewrite slice.

Purpose:
- Replace the remaining receiver-centered mask shortcuts for full receiver land families with source-visible, data-driven stamp-table behavior.
- Keep mixed junction ranges `00_40..00_48` and `00_77..00_78` reserved/unresolved while exposing truthful metadata when a fixture enters those shapes.
- Preserve the already validated bridge material resolver, water shoreline system, rock/void system, dirt/sand boundary behavior, roads, gameplay/pathing, fog, panning, selection, save data, and object logic.

Implemented:
- `content/terrain_grammar.json` now declares `land_receiver_stamp_lookup` with provisional source-anchored dirt and sand stamp tables, frame ranges, source offsets, source levels, array-reconstruction fallback metadata, and reserved mixed-junction ranges.
- Full receiver land families now opt into the shared stamp-table path and no longer carry per-family receiver-centered `bridge_mask_lookup`, bridge-family override, or propagated-stamp shortcut tables.
- The local prototype now includes the source-backed `rougtl` rough full receiver family in grammar, asset staging, and validation coverage.
- `OverworldMapView` resolves bridge material first, selects full receiver land transition frames from the stamp table, and reports stamp table id, source direction/offset, selected frame, transform/flip state, source levels, and mixed-junction reservation metadata through the shared live/editor validation payload.
- Map-editor, live-overworld, Ninefold, and repository validation coverage now assert full receiver stamp payloads for direct dirt contact, routed swamp/dirt behavior, preferred full-receiver dirt routing, subterranean provisional fallback, and sand propagation.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is still a local HoMM3 reference prototype and does not make the pushed game visibly HoMM3-complete or shippable.
- Exact original paint-history offsets, reserved mixed-junction table semantics, water inlet topology, rock topology/passability, `subbtl` bridge class, and original variant-selection policies remain unresolved.
- This is not an editor restamp model, original-art replacement, gameplay/pathing change, save-format change, or editor-schema change.

## Current Implementation Slice: HoMM3 Bridge Material Resolver
Status: completed on 2026-04-21 as the next narrow renderer rewrite slice.

Purpose:
- Split bridge material selection into an explicit data-driven resolver before frame lookup, while keeping the existing HoMM3 local prototype path intact.
- Prove direct dirt/sand material contacts, preferred bridge-class routing, grass/swamp routed through dirt behavior, and the provisional subterranean fallback through live/editor validation payloads rather than screenshot claims.
- Preserve gameplay/pathing/fog/panning/selection/save-version/object logic and the existing road overlay behavior.

Implemented:
- `content/terrain_grammar.json` now declares `bridge_material_resolver.data_driven_bridge_material_resolver.v1` with rule order, direct material contacts, preferred class routes, and the subterranean unresolved fallback.
- `OverworldMapView` loads bridge classes and resolver rules, resolves bridge material metadata before frame-block selection, and reports bridge class, rule id, source level, target frame block, resolver model, and provisional status through the shared validation payload.
- Direct full-receiver dirt/sand contacts, dirt receiving sand through `dirttl`, water/rock preferred sand routing, full receiver dirt preference, grass/swamp via dirt routing, and subterranean unresolved fallback are all data-driven.
- Map-editor and live-overworld smoke fixtures now validate each bridge-source kind through payload metadata while continuing to use the same renderer path.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not the full land stamp lookup rewrite, editor restamp model, water shoreline rewrite, rock/void rewrite, original-art replacement plan, gameplay/pathing change, save-format change, or editor-schema change.
- Existing receiver-centered frame tables remain in place until the later full land receiver stamp lookup slice.
- The subterranean bridge policy remains explicitly provisional and data-driven.

## Current Implementation Slice: HoMM3 Terrain Renderer Data Contract Groundwork
Status: completed on 2026-04-21 as a renderer/data-contract groundwork pass.

Purpose:
- Start the HoMM3 terrain renderer rewrite from the reconstruction plan by making atlas roles, bridge classes, frame blocks, special systems, and provisional unknowns explicit in the local prototype data contract.
- Keep live overworld and `MapEditorShell` preview parity through the shared `OverworldMapView` validation path while avoiding gameplay/pathing, save-format, editor-schema, and asset-pipeline changes.

Implemented:
- `content/terrain_grammar.json` now declares `homm3_renderer_data_contract.v1`, atlas-role metadata, bridge-class metadata, source-level frame blocks, direct bridge pairs, routed bridge rules, and provisional/unresolved fallback policies.
- `sandtl`, `watrtl`, and `rocktl` are no longer treated as generic land edge-mask sources. Sand is base/decor bridge material, water stays on the shoreline system, and rock stays on the rock/void special-system path.
- Grass/sand metadata now names the `grastl` native-to-sand block directly instead of implying a separate extracted `tgrs` source.
- `OverworldMapView` now loads routed bridge rules, separates receiver-family payload metadata from frame lookup, reports atlas role/source-level/bridge-source/special-system fields in validation payloads, and keeps the existing local prototype lookup path alive.
- Map-editor and live-overworld smoke coverage now asserts the new metadata contract for sand base context, grass/sand propagation, water shoreline metadata, and rock special-system metadata.
- Fixed malformed indentation from the first rewrite attempt in `OverworldMapView.gd` and `tests/overworld_visual_smoke.gd` so Godot can load the scripts and the smoke scenes no longer cascade.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not the full stamp/restamp rewrite, exact original lookup-table recovery, gameplay/pathing change, save-format change, editor-schema change, or shippable terrain-art replacement.
- Receiver-centered transition shortcuts still exist for currently covered land masks until later slices replace them with data-driven stamp tables.
- Exact land stamp offsets, mixed junction topology, water inlet topology, rock topology/passability, `subbtl` preferred bridge class, and original variant-selection policies remain unresolved and must stay data-driven.

## Current Implementation Slice: HoMM3 Terrain Renderer Rewrite Plan
Status: completed on 2026-04-21 as a planning/specification pass.

Purpose:
- Turn the mature HoMM3 terrain reconstruction evidence into a concrete renderer rewrite sequence without changing renderer code, tests, runtime assets, terrain grammar behavior, gameplay/pathing, save data, or editor schema in this pass.
- Preserve the live overworld and `MapEditorShell` preview parity contract by requiring both surfaces to keep using the same `OverworldMapView` validation path in future implementation slices.

Implemented:
- Added `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/terrain-renderer-rewrite-plan.md` as the source-driven rewrite plan.
- The plan explicitly separates land receiver-family lookup, bridge material selection, special `watrtl` water shoreline handling, special `rocktl` rock/void handling, stamp footprint/repaint-order behavior, road overlay preservation, and data-driven provisional unknowns.
- The future slice order starts with data contract audit and receiver-family interior lookup before bridge material routing, full land stamp lookup, editor restamp behavior, water, rock, dirt/sand tightening, road regression, and original-art replacement planning.
- The plan records current prototype mismatches to correct later, including receiver-centered mask shortcuts, stale grass-sand extraction wording, normal-family treatment of rock, and provisional `subbtl` bridge-class assumptions.

Validation:
- Passed `python3 -m json.tool ops/progress.json`
- Passed `git diff --check`

Limits:
- This is not a renderer rewrite, terrain grammar runtime change, runtime asset change, gameplay/pathing/save/editor-schema change, test change, or claim that the original HoMM3 executable's hidden lookup tables have been recovered.
- Exact land stamp offsets, terrain priority ordering, mixed junction topology, water inlet ownership, rock topology/passability, `subbtl` preferred class, and original variant-selection policies remain unresolved and must stay data-driven.

## Current Implementation Slice: HoMM3 Terrain Reconstruction Lookup Spec
Status: completed on 2026-04-21 as an evidence/specification pass.

Purpose:
- Convert the gathered HoMM3 terrain frame labels, transform-equivalence audit, analysis sheets, and AcOrP editor observations into a reconstruction-ready lookup specification for a later renderer rewrite.
- Keep the work out of renderer code, terrain grammar behavior, runtime art staging, and smoke-test expectations.

Implemented:
- Added `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/terrain-reconstruction-spec.json` with explicit fact, editor-observation, inference, provisional, and unresolved source levels.
- Covered terrain family classes, bridge classes, atlas roles, grass receiving dirt/sand as shared behavior, grass/swamp routed through dirt bridge logic, anchored directional paint-stamp behavior, road topology transforms, shoreline topology transforms, unresolved offset tables, and renderer rewrite order.
- Added a small cross-reference in `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/terrain-system-reconstruction.md`.

Validation:
- Passed `python3 -m json.tool /root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/terrain-reconstruction-spec.json`

Limits:
- This is not a renderer change, terrain grammar change, runtime asset change, gameplay/pathing/save/editor-schema change, or claim that the original HoMM3 executable's exact hidden lookup table has been recovered.
- Exact land-transition offset tables, multi-family priority ordering, grass/swamp bridge composition, rock/void topology, water inlet topology, and original variant-selection policies remain unresolved.

## Current Implementation Slice: HoMM3 Terrain Evidence Labeling
Status: completed on 2026-04-21 as a documentation/evidence pass.

Purpose:
- Follow AcOrP's corrected order: label extracted HoMM3 terrain assets from source evidence first, account for rotations/variations second, and reconstruct the terrain-system narrative before any further renderer work.
- Keep this pass out of `OverworldMapView`, terrain grammar behavior, runtime art staging, and smoke-test expectations.

Implemented:
- Replaced the speculative terrain reconstruction artifact in `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/terrain-system-reconstruction.md` with source-driven frame-block labels.
- Added `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/terrain-frame-labels.json` as a machine-readable reference for later renderer work.
- Generated local enlarged contact sheets under `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/analysis-sheets/` to support frame-block inspection.
- Corrected prior assumptions: `rougtl` is a real 79-frame terrain DEF; `sandtl` reads as sand interiors/decor, not a generic edge-mask atlas; no separate extracted grass-sand DEF/JSON exists in the artifact tree; `rocktl` needs separate rock/void treatment.

Validation:
- Passed `python3 -m json.tool /root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/terrain-frame-labels.json`

Limits:
- This is not a renderer change, terrain grammar change, runtime asset change, gameplay/pathing/save/editor-schema change, or claim that the original executable lookup table has been recovered.
- Exact terrain priority, transition offset tables, and some rock/junction cases remain unknown.

## Current Implementation Slice: HoMM3 Sand Transition Propagation
Status: completed on 2026-04-21 as a narrow corrective terrain pass.

Purpose:
- Retarget AcOrP's single-sand-in-grass repro after the prior one-ring-only assumption was corrected.
- Keep the map editor preview and live overworld renderer on the same `OverworldMapView` HoMM3 local-reference selection path.
- Ground the change in the extracted local HoMM3 evidence already present in the task artifacts, especially the `grastl` native-to-sand transition block at frames `00_20` through `00_39`.

Implemented:
- Removed the fake one-ring cap and the discarded self-contained sand receiver policy from the local HoMM3 prototype contract.
- Added an explicit grass/sand direct bridge-pair route and a sand-specific grass edge lookup so direct grass receivers use `grastl` native-to-sand frames instead of generic dirt bridge frames.
- Added a compact 5x4 grass-sand propagated stamp grid with axis flips, so diagonal/corner receivers and farther stamp-covered receivers can select rotated `grastl` native-to-sand frames where the lookup provides them.
- Extended `OverworldMapView` validation payloads to expose propagated transition sources, source offsets, source distance, second-ring use, and frame flips for both editor preview and live overworld tests.
- Replaced the previous one-ring smoke assertions with editor/live coverage for center sand transition lookup, grass-sand edge frames, rotated diagonal stamp frames, second-ring propagation, and no propagation outside the explicit stamp lookup.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`

Limits:
- This remains local reference/prototype work using ignored extracted HoMM3 frames, not shippable terrain art.
- This is not a gameplay/pathing, save-format, map-editor data-model, object/town rendering, or terrain-family rewrite.
- The stamp table is an explicit prototype interpretation of the extracted local frames, not a claim that the original executable's hidden terrain editor logic has been fully recovered.

## Current Implementation Slice: HoMM3 Terrain Base Selection Tightening
Status: completed on 2026-04-21 as a narrow corrective terrain pass.

Purpose:
- Address AcOrP's feedback that the HoMM3 local terrain prototype still reads as a fake repeated interior tile quilt.
- Keep direct dirt/swamp transition resolution on the direct dirt bridge-pair path instead of allowing the generic sand bridge path.
- Keep the map editor preview and live overworld rendering on the same `OverworldMapView` validation surface.

Scope:
- Stop HoMM3 interior frame selection from using the old deterministic 3x3 patch variant cycle.
- Add an explicit direct dirt/swamp bridge-pair override before the generic dirt/sand bridge fallback.
- Extend repo, overworld, map-editor, and ninefold smoke coverage for the stable interior base and direct dirt/swamp transition path.

Implemented:
- `OverworldMapView` now selects a single stable HoMM3 interior base frame rather than cycling interior frames by 3x3 patch hash.
- `content/terrain_grammar.json` declares a direct dirt/swamp bridge-pair override, and the renderer resolves that direct pair before falling back to the generic receiver bridge family.
- Live and map-editor validation payloads now report the stable interior selection model, no interior variant cycling, and the direct bridge-pair resolution model.
- Map-editor smoke covers controlled dirt->swamp and swamp->dirt preview transitions; ninefold smoke covers a natural swamp/dirt transition; overworld/ninefold smoke cover stable interior base reporting; repo validation covers the grammar/manifest contract.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

Limits:
- This is not a terrain architecture rewrite, gameplay/pathing/save/editor schema change, object/town/UI pass, or shippable asset change.
- Existing editor base terrain option narrowing remains intact.

## Current Implementation Slice: HoMM3 Base Terrain Picker Options
Status: completed on 2026-04-21 as a narrow map editor option-surface correction.

Purpose:
- Stop the map editor terrain picker from exposing the full authored logical terrain grammar as base terrain choices.
- Align the visible/editable base terrain family surface with the active HoMM3 local terrain prototype: Water, Snow, Grass, Sand, Dirt, Lava, Swamp, and Rock/None.
- Preserve existing authored logical terrain ids in scenarios, tests, renderer lookup, save/runtime data, and direct compatibility validation paths.

Implemented:
- `content/terrain_grammar.json` now declares `editor_base_terrain_options` as the curated map-editor base terrain picker contract.
- `MapEditorShell` builds the terrain picker from that curated contract and exposes validation payloads for the option ids, labels, HoMM3 families, atlases, and hidden authored terrain ids.
- Hidden logical terrain ids such as `forest`, `mire`, `hills`, `ridge`, `ash`, `frost`, `coast`, and `shore` are no longer selectable through the picker validation surface, while direct authored-map compatibility remains intact.
- The curated Sand, Dirt, and Rock/None options reuse existing logical terrain representatives mapped to `sandtl`, `dirttl`, and `rocktl` rather than adding fake terrain ids.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a terrain schema migration, map rewrite, save-format change, gameplay/pathing change, or removal of richer logical terrain ids.
- Existing scenario content can still contain the broader logical ids and the HoMM3 renderer mapping remains responsible for presenting them through the local prototype families.

## Current Implementation Slice: HoMM3 Transition Orientation Correction
Status: completed on 2026-04-21 as a narrow visual regression fix.

Purpose:
- Correct AcOrP's screenshot finding that some local HoMM3 terrain transition tiles read horizontally reversed.
- Keep the fix inside the table-driven HoMM3 terrain lookup and smoke validation, with editor preview continuing to use the same `OverworldMapView` path as live overworld play.
- Preserve square-grid gameplay/pathing/save/editor data, object/town rendering, and the existing 4-neighbor road overlay behavior.

Scope:
- Correct only the horizontal bridge-mask frame mapping for the local-reference HoMM3 terrain prototype.
- Add smoke coverage for east-side and west-side grass/plains transitions in both live overworld and map-editor preview validation.
- Do not add or track original HoMM3 assets; the existing ignored local prototype asset root remains local-reference only.

Implemented:
- Corrected the local HoMM3 bridge-mask lookup so east-side bridge transitions use a right-side source frame and west-side bridge transitions use a left-side source frame.
- Added validator coverage to keep the horizontal bridge-mask table from regressing.
- Added live-overworld and map-editor preview smoke coverage for east-side and west-side grass/plains transition orientation.

Validation:
- Passed `python3 tests/validate_repo.py`
- Passed `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- Passed `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- Passed `git diff --check`

## Current Implementation Slice: HoMM3 Local Terrain Prototype
Status: completed on 2026-04-21 as a local-only renderer prototype.

Purpose:
- Replace the Rubberduck/original quiet terrain feel-test path with a truthful HoMM3-style terrain and road rendering prototype using locally extracted original HoMM3 DEF frames.
- Prove the architecture direction for table-driven neighbor-aware terrain lookup, dirt/sand bridge/base resolution, shoreline-specific water selection, and 4-neighbor road overlays.
- Preserve the logical square-grid map, current map editor working-copy model, gameplay/pathing, save format, object/town rendering, and town occupancy/pathing.

Implemented:
- `tools/build_overworld_terrain_tiles.py` now stages extracted HoMM3 terrain and road DEF frames into ignored local runtime PNGs under `art/overworld/runtime/homm3_local_prototype/`.
- `content/terrain_grammar.json` records a local-only HoMM3 prototype section with explicit terrain-family mappings, bridge/shoreline mask lookup tables, and a 4-neighbor road mask lookup.
- `OverworldMapView` now prefers the HoMM3 prototype lookup table for terrain base-frame selection and road overlay-frame selection, while retaining grammar/procedural fallback paths for unsupported cases.
- Water/coast terrain uses shoreline-specific lookup when adjacent to land; land-family conflicts resolve through the configured dirt or sand bridge/base family rather than generic all-to-all blending.
- Dirt roads now rebuild presentation connections from orthogonal same-type neighbors only; diagonal neighboring road tiles no longer create diagonal road links.
- The logical `forest` terrain limitation is explicit: HoMM3 forest is primarily object-layer art, so the local terrain prototype maps this logical terrain id to the grass atlas and reports that degradation in validation payloads.
- The map editor preview uses the same renderer and validation payloads as live overworld play.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is local prototype/reference work only. The extracted HoMM3 frames are not shippable or redistributable game assets.
- This is not a gameplay/pathing, save-format, map-editor data-model, object/town rendering, or town occupancy/pathing change.
- The frame-index tables are explicit and defensible prototype lookup tables, not a claim that the original HoMM3 executable's exact hidden lookup table has been recovered.

## Current Implementation Slice: Rubberduck Grassland Cohesion Correction
Status: completed on 2026-04-21 as a narrow corrective terrain-art pass.

Purpose:
- Correct AcOrP's live-view finding that same-family grassland areas read as visible square color patches after the Rubberduck feel test.
- Keep the Rubberduck terrain direction under evaluation, but make grass/plains base variants read as one coherent grasslands family.
- Preserve the existing 64x64 runtime tile-bank contract, renderer behavior, 3x3 patch-cohesive variant selection, projection/layout, gameplay/pathing, save format, map editor schema, road topology, object/town art, and town occupancy/pathing.

Scope:
- Tighten the generated Rubberduck-adapted grass/plains base tile palette/value range so variant patches stop reading like different terrain classes.
- Leave forest on the Rubberduck feel-test path if it continues to read well.
- Leave mire/swamp, hills/ridge/highland, roads, terrain grammar schema, gameplay, pathing, save/load, editor data, object rendering, and town occupancy/pathing unchanged.

Implemented:
- `tools/build_overworld_terrain_tiles.py` now normalizes only Rubberduck-derived grass/plains base variants to a tight shared grasslands palette/value range while preserving subdued source texture.
- Rebuilt only the six grass/plains runtime base PNGs; forest, mire/swamp, hills/ridge/highland, edge overlays, roads, renderer behavior, terrain grammar schema, map data, gameplay/pathing, save data, editor schema, object/town rendering, and town occupancy/pathing were left unchanged.
- The six grass/plains variants now sit in a narrow luma band around 88-90, so existing patch-cohesive selection no longer presents loud square color blocks across same-family grassland.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is a visual cohesion correction only, not a rollback of the Rubberduck feel test, a terrain schema change, a renderer/projection change, a movement/pathing change, a save-format change, an object/town art pass, or a town 3x2 occupancy/pathing slice.

## Current Implementation Slice: Rubberduck Terrain Surface Feel Test
Status: completed on 2026-04-21 as a narrow overworld terrain-art feel test.

Purpose:
- Let AcOrP judge whether the adventure map reads better when the most visible terrain surfaces use the locally downloaded Rubberduck OpenGameArt terrain pack.
- Keep this as a reversible terrain-surface pass through the existing 64x64 runtime tile bank rather than a projection, renderer, grammar, editor, save, pathing, object, town, or road rewrite.
- Prioritize grass/plains/forest surfaces, and leave terrain families unsupported by the pack on the current original quiet tile bank.

Scope:
- `tools/build_overworld_terrain_tiles.py` unwraps selected Rubberduck 128x64 isometric diamond cells into the existing 64x64 square runtime base-tile contract for grass, plains, and forest.
- Matching grasslands and forest edge overlays may use the same adapted source material so neighbor-aware transitions do not feel detached from the new surfaces.
- Mire/swamp, hills/ridge/highland, dirt-road topology/art, object sprites, town rendering, projection/layout, gameplay pathing, save format, map editor schema, and town 3x2 occupancy/pathing stay unchanged.

Implemented:
- Rebuilt only the existing runtime PNG paths for grass, plains, forest, and their grasslands/forest transition overlays from the local Rubberduck pack.
- Kept the primary renderer contract as `original_quiet_tile_bank` so existing validation, patch-cohesive variant selection, transition selection, and road overlay behavior continue to work.
- Recorded the mixed Rubberduck/original procedural source basis in the terrain grammar, art manifest, and repo validator.
- Left mire/swamp, hills/ridge/highland, and all road overlay art on the previous original quiet procedural output because the pack does not cleanly support those terrain families.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is a visual feel test, not final terrain art, a legal/source-pack ingestion policy, a projection/layout change, a save-format change, a gameplay/pathing change, a map-editor schema change, an object/town asset pass, or a town 3x2 occupancy/pathing slice.

## Current Implementation Slice: Map Editor Terrain Rectangle Painting
Status: completed on 2026-04-20 as the next narrow in-project map editor working-copy slice.

Purpose:
- Let `MapEditorShell` paint a compact terrain rectangle between two selected corner tiles using the active terrain id.
- Keep authored JSON immutable, save data unchanged, and the existing editor working copy/runtime preview as the only mutation surface.
- Preserve existing single-tile terrain paint, terrain line paint, road path, and terrain flood fill while making broad biome blockouts faster.

Implemented:
- Added a compact Terrain Rect tool beside the existing editor terrain tools.
- First terrain-rectangle click sets a pending corner tile; the second paints the inclusive axis-aligned rectangle to the clicked opposite corner.
- The rectangle rule is explicit and deterministic: inclusive axis-aligned rectangle between corner tiles, reported in row-major top-left to bottom-right tile order for validation.
- Terrain rectangle painting mutates only the in-memory working-copy map array with the active terrain id from the existing terrain grammar picker.
- Validation hooks expose the rectangle rule, bounds, tile order, rectangle tiles, changed tiles, previous terrain ids, and live tile inspection/preview state.
- Editor smoke coverage proves the intended rectangular area changes, nearby outside tiles remain unchanged, the real `OverworldMapView` preview reads the painted terrain, and a repeat paint no-ops cleanly.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not an authored JSON exporter/writeback path, save-format change, terrain schema change, projection/layout change, pathing/gameplay rewrite, or town 3x2 occupancy/pathing change.
- Terrain rectangles mutate only the in-memory working-copy map array that the existing editor preview and Play Copy path already consume.

## Current Implementation Slice: Map Editor Terrain Line Painting
Status: completed on 2026-04-20 as the next narrow in-project map editor working-copy slice.

Purpose:
- Let `MapEditorShell` paint a compact terrain line between a selected start tile and an end tile using the active terrain id.
- Keep authored JSON immutable, save data unchanged, and the existing editor working copy/runtime preview as the only mutation surface.
- Preserve existing single-tile terrain paint and terrain flood fill while making terrain-shaping experiments faster.

Implemented:
- Added a compact Terrain Line tool beside the existing editor tools.
- First terrain-line click sets a pending start tile; the second paints the line to the clicked end tile.
- The path rule is explicitly deterministic: Manhattan L line, horizontal first, then vertical.
- Terrain line painting mutates only the in-memory working-copy map array with the active terrain id from the existing terrain grammar picker.
- Validation hooks expose the rule, active terrain id, ordered line tiles, changed tiles, previous terrain ids, and live tile inspection/preview state.
- Editor smoke coverage proves the intended L-shaped tiles change, nearby off-line tiles remain unchanged, the real `OverworldMapView` preview reads the painted terrain, and a repeat paint no-ops cleanly.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not an authored JSON exporter/writeback path, save-format change, terrain schema change, projection/layout change, pathing/gameplay rewrite, or town 3x2 occupancy/pathing change.
- Terrain lines mutate only the in-memory working-copy map array that the existing editor preview and Play Copy path already consume.

## Current Implementation Slice: Map Editor Road Path Painting
Status: completed on 2026-04-20 as the next narrow in-project map editor working-copy slice.

Purpose:
- Let `MapEditorShell` add or remove a compact contiguous dirt-road path between a selected start tile and an end tile.
- Keep authored JSON immutable, save data unchanged, and the existing editor working copy/runtime preview as the only mutation surface.
- Preserve the existing single-tile road toggle while making road-shape experiments faster.

Implemented:
- Added a compact Road Path tool beside the existing editor tools.
- First road-path click sets a pending start tile; the second applies the path to the clicked end tile.
- The path rule is explicitly deterministic: Manhattan L path, horizontal first, then vertical.
- Toggle behavior is truthful: if every tile on the path already has a road, the path removes those road tiles from the working copy; otherwise it adds only missing road tiles to the editor working-road layer.
- Validation hooks expose the path rule, resolved add/remove action, ordered path tiles, changed tiles, and live tile inspection/preview state.
- Editor smoke coverage proves the intended L-shaped tiles are affected, off-path tiles are untouched, the real `OverworldMapView` preview renders the added road overlay, and a second toggle removes the same path.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not an authored JSON exporter/writeback path, save-format change, road schema change, projection/layout change, pathing/gameplay rewrite, or town 3x2 occupancy/pathing change.
- Road paths mutate only the in-memory working-copy terrain-layer road arrays that the existing editor preview and Play Copy path already consume.

## Current Implementation Slice: Map Editor Terrain Flood Fill
Status: completed on 2026-04-20 as the next narrow in-project map editor working-copy slice.

Purpose:
- Let `MapEditorShell` fill a contiguous selected-tile terrain region with the active terrain id.
- Keep authored JSON immutable, save data unchanged, and the existing editor working copy/runtime preview as the only mutation surface.
- Preserve the existing single-tile terrain brush while making terrain and transition experiments faster.

Implemented:
- Added a compact Fill Terrain command beside the other map-editor working-copy commands.
- Flood fill reads the selected tile's current terrain id as the source region and replaces only cardinally contiguous matching tiles with the active terrain id.
- Differing terrain ids bound the fill; non-matching boundary tiles are left unchanged.
- Matching active terrain on the selected tile returns a clean no-op result instead of touching the map.
- Added validation hooks and editor smoke coverage proving a bounded multi-tile fill, non-leakage into adjacent non-source terrain, live preview updates, and clean no-op behavior.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not an authored JSON exporter/writeback path, save-format change, undo stack, terrain schema change, projection/layout change, pathing/gameplay rewrite, or town 3x2 occupancy/pathing change.
- Fill is cardinally contiguous by terrain id and mutates only the in-memory working-copy map array that the existing editor preview and Play Copy path already consume.

## Current Implementation Slice: Map Editor Selected Tile Restore
Status: completed on 2026-04-20 as the next narrow in-project map editor working-copy slice.

Purpose:
- Let `MapEditorShell` restore the currently selected working-copy tile from the authored scenario baseline without resetting the whole map.
- Keep authored JSON immutable, save data unchanged, and the editor working copy/runtime preview as the only mutation surface.
- Preserve unrelated in-memory edits except where the single global hero-start position must return to the authored start when the selected tile is the authored hero-start tile or the moved current hero-start tile.

Implemented:
- Added a compact Restore Tile command to `MapEditorShell` that reads a fresh authored baseline session through `ScenarioFactory` and copies only selected-tile state back into the active editor working copy.
- Restores the authored terrain id and selected-tile road presence, removing editor-only road tiles on that coordinate and adding back authored road membership for that coordinate.
- Restores supported runtime-shaped authored placements on that coordinate for towns, resource sites, artifacts, and encounters, including moved, removed, rethemed, property-edited, or source-blocked authored placements.
- Removes working-copy-only supported placements currently on the selected tile while leaving unrelated moved/duplicated placements elsewhere intact unless they are the same authored placement id being returned to the selected tile.
- Keeps Play Copy / return coherent because the restored tile mutates the same in-memory working copy that live preview and Play Copy already consume.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a bulk reset, exporter, authored JSON writeback path, undo stack, save-format change, projection/layout change, gameplay/pathing rewrite, or town 3x2 occupancy/pathing change.
- Restore is selected-tile scoped; duplicated copies elsewhere remain part of the working copy unless they are physically on the restored tile.

## Current Implementation Slice: Neighbor-Aware Terrain Transitions
Status: completed on 2026-04-20 as the next narrow overworld terrain presentation slice.

Purpose:
- Correct the terrain transition contract toward neighboring-tile-aware terrain relationships rather than isolated per-tile borders.
- Keep logical map coordinates, pathing, save data, editor schema, and object systems unchanged.
- Reuse the existing terrain grammar, runtime tile bank, edge overlays, and map-editor live preview path.

Implemented:
- `OverworldMapView` now builds an explicit 8-neighbor transition payload for each explored tile.
- Cardinal transition edges are selected from higher-priority neighboring terrain intruding into the lower-priority receiver tile, with same-terrain-group seams suppressed.
- Diagonal higher-priority neighbors now produce procedural corner hints when no adjacent cardinal source from the same group already covers the relationship.
- Existing edge-overlay art is reused from the selected source terrain; procedural strips and corner wedges remain fallback treatments when authored art is missing.
- Validation payloads now expose transition source terrain ids/groups, receiver priority, edge/corner masks, source dictionaries, and the calculation model for both overworld play and the editor preview.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is still not a full rich transition atlas, water/coast art expansion, movement/pathing change, save-format change, or authored JSON exporter.
- The slice deliberately keeps the existing logical map and editor working-copy schema; it only improves how terrain presentation chooses visible blends from neighbors.

## Current Content Design Slice: Overworld Content Bible
Status: design source drafted after the six-faction scaffold slice, with HoMM3 map-editor research used as inspiration rather than a copy target.

Purpose:
- Define the basic grammar for the adventure map layer: biomes, pickups, flaggable economy, dwellings, shrines, banks, route-control structures, blockers, transit, landmarks, and decoration sets.
- Give future scenarios a stronger overworld vocabulary than the current narrow River Pass object set.
- Keep biome and object expansion original, faction-aware, and production-minded.

Design sources:
- `docs/overworld-content-bible.md`
- `docs/factions-content-bible.md`

Hard constraints:
- Do not turn the map into a generic HoMM clone object soup.
- Terrain-specific silhouettes and route grammar should matter at least as much as reward tables.
- Flaggable economy, scouting, transit, and guarded reward sites should be clearly separated from one-shot pickups.
- New breadth must not be described as playable breadth until scenarios, AI, save/load, and manual play prove it.

Acceptance criteria for this design slice:
- The repo has a written design source for overworld biomes, map-object families, resource logic, strategic buildings, lane grammar, and implementation order.
- The design explicitly audits the current narrow coverage and identifies what is still missing.
- The plan and progress tracker point future implementation toward biomes plus stronger overworld object families instead of only more faction JSON.

## Current Implementation Slice: Map Editor Object Retheming
Status: completed on 2026-04-20 as the next narrow editor working-copy slice.

Purpose:
- Let the in-game map editor change an existing runtime object's authored content id in place without removing and recreating the placement.
- Preserve the placement id and existing runtime state while mutating only the relevant content-id field for supported runtime placement arrays.
- Keep the retheme in memory and avoid authored JSON writeback, save-format changes, editor-only schemas, broad gameplay rewrites, and town multi-tile occupancy/pathing changes.

Implemented:
- Added a compact Retheme Object tool to `MapEditorShell` that reuses the existing object family and authored content-id pickers as replacement choices.
- Scoped retheming to the runtime arrays live play already consumes: `towns`, `resource_nodes`, `artifact_nodes`, and `encounters`.
- Mutated only the existing placement's family-specific content field: `town_id`, `site_id`, `artifact_id`, or `encounter_id`.
- Preserved placement id, coordinates, owner, difficulty, collected state, collection metadata, combat seed, and other runtime fields already present on the placement.
- Extended validation hooks and the editor smoke so tile inspection, validation snapshots, live preview, Play Copy, and editor return all expose the reassigned object state.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not an authored JSON exporter/writeback path, a save-format change, or a parallel scenario/editor schema.
- This does not implement multi-select retheming, object ownership reassignment beyond the existing property editor, or broad object authoring.
- Town 3x2 occupancy/pathing remains future work; retheming a town still changes only its existing runtime anchor placement.

## Current Implementation Slice: Map Editor Object Duplication
Status: completed on 2026-04-20 as the next narrow editor working-copy slice.

Purpose:
- Let the in-game map editor duplicate an existing runtime object placement from one tile onto a new empty destination tile.
- Preserve the source object's runtime state by deep-copying the existing working-copy placement and changing only its `placement_id`, `x`, and `y`.
- Keep duplication in memory and avoid authored JSON writeback, save-format changes, editor-only schemas, broad gameplay rewrites, and town multi-tile occupancy/pathing changes.

Implemented:
- Added a compact Duplicate Object tool to `MapEditorShell`: first click selects a supported object placement, second click duplicates it to the destination tile.
- Scoped duplication to the runtime arrays live play already consumes: `towns`, `resource_nodes`, `artifact_nodes`, and `encounters`.
- Reused the one-supported-object-per-tile editor rule so duplicates cannot be placed onto another town/site/artifact/encounter.
- Generated fresh unique editor duplicate placement ids while preserving content id, owner, difficulty, collected state, collection metadata, combat seed, and any other existing placement fields from the source runtime dictionary.
- Extended tile inspection and validation snapshots with duplicated-object coordinates and pending duplicate detail so duplication is visible and testable.
- Extended the editor smoke to duplicate one town, resource node, artifact node, and encounter while proving source preservation, fresh placement ids, preserved state, live preview, Play Copy, and editor return snapshot behavior.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not an authored JSON exporter/writeback path, a save-format change, or a parallel scenario/editor schema.
- This does not implement undo, drag duplication, multi-select duplication, object ownership reassignment, or broad object authoring.
- Town 3x2 occupancy/pathing remains future work; duplicating a town still creates another runtime town anchor on one empty editor tile.

## Current Implementation Slice: Map Editor Object Movement
Status: completed on 2026-04-20 as the next narrow editor working-copy slice.

Purpose:
- Let the in-game map editor relocate existing runtime object placements from one tile to another.
- Preserve the moved object's runtime state by mutating only its `x`/`y` coordinates in the existing working-copy placement arrays.
- Keep the move in memory and avoid authored JSON writeback, save-format changes, editor-only schemas, broad gameplay rewrites, and town multi-tile occupancy/pathing changes.

Implemented:
- Added a compact Move Object tool to `MapEditorShell`: first click selects a supported object placement, second click moves that same runtime object to the destination tile.
- Scoped relocation to the runtime arrays live play already consumes: `towns`, `resource_nodes`, `artifact_nodes`, and `encounters`.
- Reused the existing one-supported-object-per-tile editor rule so moves cannot stack a town/site/artifact/encounter onto another supported placement.
- Extended tile inspection and validation snapshots with moved-object coordinates and pending move detail so movement is visible and testable.
- Extended the editor smoke to move one town, resource node, artifact node, and encounter while proving placement ids, owner/difficulty/collection metadata, combat seed, live preview, Play Copy, and editor return snapshot remain intact.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not an authored JSON exporter/writeback path, a save-format change, or a parallel scenario/editor schema.
- This does not implement undo, drag interaction, multi-select movement, placement ownership reassignment, or broad object authoring.
- Town 3x2 occupancy/pathing remains future work; moving a town still changes only its current single authored/runtime anchor tile.

## Current Implementation Slice: Map Editor Play Copy Return
Status: completed on 2026-04-20 as the previous editor/play-flow slice.

Purpose:
- Preserve the in-memory map editor working copy across the Play Copy test loop so scenario iteration does not rebuild from authored JSON after every play probe.
- Keep Play Copy using the normal overworld shell and runtime session structures rather than an editor-only play surface.
- Keep the slice honest: returning from Play Copy restores the editor working-copy launch snapshot, not the fully mutated live play state.

Implemented:
- `MapEditorShell` now stores the current editor working-copy snapshot in `SessionState` before Play Copy, then launches the normal overworld shell on a duplicate of that snapshot.
- Editor-launched play sessions carry explicit `editor_working_copy` and `editor_return_model: launch_snapshot` metadata.
- `AppRouter.return_to_main_menu_from_active_play()` now detects editor Play Copy sessions and routes back to `MapEditorShell` instead of the main menu, while normal campaign/skirmish menu routing remains unchanged.
- Returning to the editor consumes the in-memory launch snapshot, restores the mutable scenario state, reveals the map for editing again, and clears the active playable session.
- The editor smoke now validates the round trip by proving edited terrain and hero-start state reach the overworld, then proving a later live play mutation is not imported back into the editor.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not authored JSON writeback/export, a save-format change, a parallel editor scenario schema, or a live-play-state import system.
- The returned editor state is the exact editor launch snapshot kept in memory; gameplay changes made after Play Copy launch are intentionally discarded on return.
- Town 3x2 occupancy/pathing remains future work.

## Current Implementation Slice: Map Editor Object Property Editing
Status: completed on 2026-04-20 as the next narrow editor working-copy slice.

Purpose:
- Let the in-game map editor adjust mutable runtime properties on the currently selected overworld object in the working copy.
- Keep the edits in memory and in the existing runtime state shape that live preview and Play Copy already consume.
- Avoid authored JSON writeback, save-format changes, editor-only schemas, and broad gameplay rewrites.

Implemented:
- Added a compact selected-object property box to `MapEditorShell` for the current supported placement families.
- Scoped editable fields to existing runtime fields: town `owner`, encounter `difficulty`, and resource/artifact node `collected` state with existing collection metadata.
- Extended tile inspection and validation snapshots with `selected_property_object`, `property_key`, `editable_properties`, and live owner/difficulty/collection details.
- Extended the editor smoke to prove property edits update the working copy, affect live preview, launch through Play Copy into the normal overworld shell, and survive the editor return snapshot.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/map_editor_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not authored JSON export/writeback, a save-format change, a parallel scenario/editor schema, or a full object authoring panel.
- The edit surface is dev-facing and only targets currently supported runtime families and fields.
- Town 3x2 occupancy/pathing remains future work.

## Current Implementation Slice: Map Editor Object Placement Editing
Status: completed on 2026-04-20 as an earlier narrow editor slice.

Purpose:
- Let the in-game map editor mutate overworld object placements on the existing scenario working copy instead of only terrain, roads, and hero start.
- Reuse the same runtime placement arrays that live play already consumes: towns, resource nodes, artifact nodes, and encounters.
- Keep authored JSON immutable and avoid introducing an exporter, writeback path, or second scenario schema.

Implemented:
- Added a compact object palette to `MapEditorShell` with family selection for towns, resource sites, artifacts, and encounters plus authored content-id selection from the existing content JSON domains.
- Added object placement and removal tools that mutate only the in-memory working copy, generating unique editor placement ids and building runtime-shaped town/resource/artifact/encounter records through existing rules/helpers.
- Improved tile inspection with placement id, content id, family/status, owner, difficulty, and structured validation details so placement edits are immediately visible.
- Extended static repo validation and the map editor smoke test to place, preview, inspect, and remove one object from each supported family.

Limits:
- This is still not an exporter, content-pipeline writer, undo stack, occupancy/pathing editor, owner/difficulty editor, or full scenario validation UI.
- The editor currently blocks stacking supported overworld placements on the same tile; moving or reassigning existing placements can be handled by remove-then-place in this slice.
- Campaign/skirmish/save gameplay still uses authored content unless the editor's Play Copy route explicitly launches the mutated working copy.

## Current Implementation Slice: In-Game Map Editor Shell
Status: first slice implemented on 2026-04-20 as a dev-facing scenario iteration tool.

Purpose:
- Put a thin map editor inside the running game before further overworld polish so map behavior can be tested interactively.
- Reuse the live overworld map renderer and scenario bootstrap instead of forking map presentation or building a Godot editor plugin.
- Keep authored content immutable unless a future export/writeback slice is deliberately scoped.

Implemented:
- Added `scenes/editor/MapEditorShell.tscn` and `MapEditorShell.gd` as an in-game editor shell reachable from the main menu and `AppRouter`.
- Loaded authored scenarios through `ScenarioFactory` into an in-memory mutable working copy.
- Reused `OverworldMapView` for live map preview, including existing terrain art, road overlays, object rendering, panning, and validation metadata.
- Added first-slice tools for terrain painting, dirt-road toggling through terrain layers, hero-start repositioning, and tile/object inspection.
- Added a "Play Copy" route that sends the current working copy through the normal overworld shell without changing campaign/skirmish authored semantics or writing content JSON.
- Added focused validator and Godot smoke coverage for the editor shell.

Limits:
- This is not a full production map editor, exporter, undo stack, object palette, terrain-cost editor, map validation UI, or Godot editor plugin.
- Edits are intentionally in-memory only; authored JSON writeback needs a separate content-pipeline slice.
- Deeper placement workflows such as move/reassign, owner/difficulty tuning, validation overlays, and authored writeback remain future work.

## Current Implementation Slice: Overworld Content Foundation
Status: completed on 2026-04-18 as the first real implementation pass from the overworld bible.

Purpose:
- Turn the overworld bible's first implementation step into checked-in content domains and runtime support.
- Keep existing scenario gameplay stable while giving future maps a richer authored grammar than pickups, dwellings, outposts, and shrines.

Implemented:
- Added `content/biomes.json` with nine biome families, terrain tile mappings, passability, movement-cost metadata, battle terrain hooks, encounter palette tags, route roles, and allowed site families.
- Added `content/map_objects.json` as the canonical overworld object vocabulary for pickups, mines, scouting structures, guarded reward sites, transit objects, repeatable service buildings, blockers, and faction landmarks.
- Expanded `content/resource_sites.json` with a first meaningful set of new site families: mines, scouting structures, guarded reward sites, transit objects, and repeatable service buildings.
- Wired `ContentService.gd` to load and validate biomes, map objects, and expanded resource-site families.
- Wired `OverworldRules.gd` and `ScenarioRules.gd` to use authored biome labels/passability and expanded site-family labels, action text, support defaults, scouting visibility summaries, and repeatable service cooldown/cost hooks.
- Extended overworld map rendering fallback colors/patterns for the new terrain ids.
- Extended `tests/validate_repo.py` so the new content layer is enforced.

Limits:
- This is content foundation and runtime support, not a claim that current scenarios have HoMM3-class adventure-map density.
- Transit objects are authored and validated as route-control content, but paired transit traversal is still a future scenario/system slice.
- Guarded reward sites are authored with guard profiles and reward grammar; full encounter-linked bank resolution remains future work.

## Current Implementation Slice: Neutral Dwelling And Neutral Unit Foundation
Status: completed on 2026-04-18 as the first real neutral-content implementation slice.

Purpose:
- Add neutral units and neutral dwelling families that can exist outside the six faction ladders.
- Let neutral recruit sources and neutral encounters use real neutral rosters without creating a seventh playable faction or borrowing faction armies.
- Keep current scenario disruption narrow; this slice changes only the generic Free Company Yard and Fenhound Kennels into neutral-roster sites while preserving River Pass's scenario-specific Riverwatch relief yard.

Implemented:
- Added `content/neutral_dwellings.json` as a family layer for neutral recruit sites, map objects, guard armies, and neutral encounters.
- Added neutral unit records with `affiliation: "neutral"` and no faction id.
- Added neutral army groups and neutral encounters for Roadward Lodge and Fenhound Kennels guards.
- Wired ContentService, OverworldRules, BattleRules, and validation around neutral affiliations, neutral rosters, neutral dwelling family labels, neutral battle payloads, and neutral recruit musters.
- Added focused core-system smoke coverage proving a neutral dwelling site can grant neutral claim recruits, feed neutral weekly musters, and produce a battle payload whose enemy army and stacks remain neutral.

Limits:
- This is a first neutral dwelling/unit slice, not a complete neutral ecology.
- Guarded dwelling encounters are authored and battle-ready, but existing scenarios do not yet place a full guarded-neutral-dwelling flow as route-critical content.
- Broader neutral banks, wandering monsters, surrender/recruit diplomacy, and biome-wide neutral ecology are future slices.

## Current Implementation Slice: Neutral Dwelling Breadth Expansion
Status: completed on 2026-04-18 as a breadth content slice after the first neutral dwelling foundation.

Purpose:
- Expand neutral dwelling families from the first two examples to a broad authored set of 25 families in the content layer.
- Keep the work as real JSON content across neutral dwelling families, neutral units, neutral-scoped sites, map objects, guard army groups, and neutral encounters.
- Preserve current scenarios instead of pretending this breadth has been scenario-played, tuned, or manually proven.

Implemented:
- Expanded `content/neutral_dwellings.json` to 25 authored neutral dwelling families.
- Added 46 additional neutral units, bringing the neutral roster to 50 units outside the six faction ladders.
- Added matching neutral dwelling resource-site definitions, map-object silhouettes, guard army groups, and neutral guard encounters for each new family.
- Opened highland, ash, and underways biome palettes to neutral dwelling content where the new authored families live.
- Tightened repo validation so the 25-family/50-unit breadth target and per-family site/object/guard/encounter links are enforced.

Limits:
- This is breadth scaffolding, not a balance pass.
- None of the new 23 families are placed in current scenarios yet.
- Guard encounters and recruit sources are internally coherent content records, but they are not claimed to be manually scenario-played or tuned.

## Current Implementation Slice: Six-Faction Biome Scenario Breadth
Status: completed on 2026-04-18 as a large authored scenario breadth slice.

Purpose:
- Add one explicitly 64x64 authored scenario that exercises the breadth now present in content rather than leaving the new scaffold only in isolated JSON domains.
- Keep the slice honest: this is scenario placement and loading coverage, not tuning, balance, route proof, or manual-play proof.

Implemented:
- Added `ninefold-confluence` / `Ninefold Confluence` to `content/scenarios.json` as a skirmish-only 64x64 map.
- Represented all six faction ids through the player start, six faction towns, hostile pressure fronts, controlled logistics nodes, and script pressure hooks.
- Represented all nine authored biome families in the actual scenario map layout.
- Placed all 25 neutral dwelling families as resource-site placements, with validation checking each dwelling remains in one of its authored biome families.
- Placed newer overworld site families beyond dwellings: pickups, mines, scouting structures, guarded reward sites, transit objects, repeatable services, faction outposts, and frontier shrines.
- Added narrow supporting army groups and encounters for Thornwake, Brasshollow, and Veilmourn so their scenario fronts can spawn faction-specific pressure instead of borrowing legacy armies.
- Added a focused repo validator and Godot smoke for the new scenario's 64x64 loading/overworld snapshot.

Limits:
- This is not a tuning pass and not a manual-play pass.
- Transit objects are placed as authored route-control content, but paired transit traversal is still not proven as route-critical gameplay.
- Blocker and faction-landmark map objects remain content-vocabulary records; the current scenario schema still places gameplay through resource sites, towns, artifacts, and encounters rather than raw map-object placements.

## Current Implementation Slice: Overworld Fixed Tactical Framing
Status: completed on 2026-04-18 as a narrow live-play presentation bugfix after the first Ninefold Confluence audit.

Purpose:
- Fix the large-map overworld presentation regression where 64x64 scenarios could open zoomed out far enough to read like a whole-map atlas instead of a tactical adventure view.
- Preserve the existing small-map behavior where River Pass-scale maps fit fully inside the overworld panel.
- Keep the fix inside the overworld presentation layer and validation snapshot surface rather than changing scenario data or overworld rules.

Implemented:
- Changed `OverworldMapView.gd` so maps at or under the 12x12 small-map threshold still fit fully, while larger maps use a hero-centered tactical viewport targeting roughly a 12x12 tile area in the current rectangular map surface.
- Added viewport metrics to the map view and surfaced them through `OverworldShell.validation_snapshot()`.
- Extended the Ninefold Confluence smoke so the 64x64 shell must not report full-map visibility and must stay within a bounded tactical visible-tile budget.
- Extended the River Pass overworld visual smoke so small-map fit behavior remains guarded.

Limits:
- This is a default framing fix, not a full overworld camera feature. Manual panning/zoom controls remain future work if large-map navigation needs them.
- Ninefold Confluence still needs manual route, balance, and readability passes before it can be treated as a proven playable map.

## Current Implementation Slice: Player-Visible Latency Reduction
Status: completed on 2026-04-19 as a narrow latency fix after profiling the post-d2bf14a / post-6bc9bc4 hot paths.

Purpose:
- Reduce remaining perceived waits on large scenarios by measuring end-to-end scene/refresh routes instead of only average refresh numbers.
- Keep the fix surgical: avoid broad town, battle, or rules rewrites while removing repeat work that was still happening behind mostly collapsed UI.

Implemented:
- Added SaveService slot-summary caching keyed by slot file state, with runtime saves seeding exact saved-payload summaries so unchanged large save files are not reread and renormalized on every scene refresh.
- Deferred expensive overworld Frontier/commitment detail summaries while those panels are collapsed; the collapsed frontier indicator stays cheap and full objective/threat/risk text is populated when the Frontier drawer opens.

Measured result:
- Ninefold Confluence populated save-surface refresh dropped from multi-second waits to roughly 8-13 ms in the focused latency probe.
- Ninefold Confluence battle refresh after populated saves dropped from about 5.2 s to about 23 ms.
- Ninefold Confluence overworld idle refresh dropped from about 1.5-1.6 s to about 0.36 s by deferring hidden detail summaries.

Limits:
- Ninefold Confluence town entry still has a separate visible town-refresh cost: direct town entry measured about 3.6 s in the temporary probe, with town refresh about 0.78 s and the visible command ledger as the largest measured town summary. That is a follow-up diagnosis, not part of this save/frontier fix.
- Opening the Frontier drawer intentionally pays the cost of building full objective, threat, and next-day risk summaries at the moment the player asks for that detail.

## Current Implementation Slice: Overworld Usability Follow-Up
Status: completed on 2026-04-19 as a narrow response to AcOrP's overworld usability findings.

Purpose:
- Make already-scouted overworld information easier to use after it leaves the current scout net.
- Let large 64x64 maps be inspected beyond the initial hero-centered tactical viewport.
- Let owned towns be opened from map selection even when the active field hero is not standing on the town tile.

Implemented:
- Remembered, explored-but-not-visible towns, sites, artifacts, and rememberable encounters now keep dimmed object markers and remembered context text instead of disappearing into generic mapped terrain.
- Large overworld maps now expose manual camera panning through drag, mouse wheel, Shift+arrow/WASD, validation hooks, and a Home/focus route back to the active hero.
- Owned town selection can expose and activate Visit Town remotely; town rules now respect a validated active town visit context and clear that context when returning to the overworld.
- Focused smoke coverage was extended for remembered owned-town readability, remote town routing, and Ninefold Confluence large-map panning/refocus behavior.

Limits:
- This is a targeted usability patch, not a broad overworld polish pass.
- Host-side validation passed, but no full manual proof is claimed for Ninefold Confluence or for every supported runtime resolution.
- Remote town entry is limited to owned, explored towns; hostile or neutral town interactions still require their normal scenario/system rules.

## Current Implementation Slice: Overworld Readability Contrast Pass
Status: completed on 2026-04-19 as a narrow visual/readability follow-up after AcOrP confirmed panning works but important overworld objects still blend into terrain.

Purpose:
- Make towns, the active hero/current selection, resource sites, artifacts, and encounters read faster against terrain on both River Pass-scale and large 64x64 maps.
- Make remembered objects distinguishable from visible objects without reducing them to faint, ambiguous terrain mush.
- Preserve the map-first presentation: no heavy permanent labels, broad panels, debug overlays, or chrome covering the play surface.

Implemented:
- Tuned `OverworldMapView` marker shapes, scale, outlines, shadow plates, and focus rings for towns, active hero/current selection, resource sites, artifacts, and encounters.
- Added a distinct remembered-object treatment with stronger ghost color, visible outline, small contrast plate, and memory echo ticks while keeping the markers non-label, map-first, and compact.
- Extended focused overworld and Ninefold Confluence smoke coverage through marker-readability validation metadata for visible objects, remembered owned-town markers, active hero/selection emphasis, and large-map resource/town markers.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a full overworld art pass, new camera feature, or shell redesign.
- Existing remembered-state rendering, panning, and remote owned-town entry behavior from the previous slice must remain intact.
- Automated smoke coverage guards presentation metadata and route behavior; no broad manual visual proof is claimed.

## Current Implementation Slice: Overworld Explored Terrain Visibility Follow-Up
Status: completed on 2026-04-19 as a narrow fog-presentation correction after AcOrP clarified the remaining issue.

Purpose:
- Keep terrain that has already been scouted/explored fully visible even after it leaves the current scout net.
- Preserve unexplored tiles as dark/hidden.
- Keep the existing panning, remote town entry, and compact remembered-object marker behavior from the recent overworld usability/readability slices.

Implemented:
- Removed the explored-but-not-currently-visible terrain dimming path from `OverworldMapView`; remembered terrain now uses the same terrain fill and pattern detail as currently visible explored terrain.
- Preserved remembered object marker treatment for towns, sites, artifacts, and fixed remembered encounters where that distinction remains useful.
- Added focused overworld presentation validation metadata and smoke assertions proving explored terrain outside scout range stays fully visible while unscouted terrain stays hidden.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is only a fog terrain presentation fix, not another marker readability pass or broad overworld UI redesign.
- Object-specific remembered marker styling still exists; the change is that explored terrain itself no longer darkens into a remembered state.

## Current Implementation Slice: Overworld Diagonal Movement
Status: completed on 2026-04-19 as a narrow movement follow-up requested by AcOrP.

Purpose:
- Allow heroes to move diagonally on the overworld through the same normal movement, click-routing, and route-preview surfaces as cardinal movement.
- Preserve the simple current movement economy where each overworld step, including a diagonal step, costs exactly one movement point.
- Keep recent fog, panning, and object-readability behavior intact.

Implemented:
- Added diagonal directions to overworld path building and shell keyboard movement handling, using Q/E/Z/C and numpad diagonals for direct movement while preserving Shift-modified panning behavior.
- Changed adjacent tile acceptance so map clicks can target any of the eight neighboring tiles when terrain is not blocked.
- Added focused core and visual smoke coverage for rules-side diagonal movement cost, route preview/advance behavior, and adjacent diagonal map-click movement.
- Fixed the visual smoke fixture so Godot parses the new typed locals cleanly and chooses an object-free diagonal lane for the route assertion.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/core_systems_regression_smoke.tscn`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is only the diagonal overworld movement slice, not a broader pathfinding, movement-cost, terrain-cost, or camera redesign.
- Diagonal movement currently uses the existing one-point step economy; any future terrain-weighted or corner-cutting rule should be a separate documented slice.

## Current Implementation Slice: Generated Source Terrain Art Replacement
Status: completed on 2026-04-20 as a narrow visual correction after AcOrP rejected the synthetic local tile style.

Purpose:
- Replace the bad-looking synthetic terrain tile pieces with checked-in runtime PNGs cut and adapted from the previously generated overworld source terrain images.
- Preserve the existing authored terrain grammar and `OverworldMapView` renderer contract: 64x64 base variants, directional biome-edge overlays, and structural `road_dirt` overlay pieces.
- Keep scope to the terrain families already covered by the first art slice: grass/plains, forest, mire/swamp, hills/ridge/highland, road overlays, and edge transitions.

Implemented:
- Replaced `tools/build_overworld_terrain_tiles.py` with a source-driven builder that cuts, grades, edge-softens, and writes the renderer's existing 64x64 runtime tile paths from the generated terrain source sheets.
- Rebuilt the checked-in base tiles for grass/plains, forest, mire/swamp, and hills/ridge/highland from generated source patches while avoiding the source sheets' oversized painted road strokes in base terrain.
- Rebuilt directional biome-edge overlays as compact feathered source-art strips instead of synthetic bands.
- Rebuilt `road_dirt` center and connector overlays from generated road material with much narrower masks, and reduced the renderer/grammar fallback road width from 0.22 to 0.14.
- Updated the overworld art manifest and terrain grammar summary to record that the active runtime tile pieces are cut/adapted from generated terrain source art.
- Left object sprite mappings and procedural object fallbacks unchanged.
- Did not use `/root/.openclaw/workspace/tmp/nanobanana2-menu-try/`; inspection showed menu images, not relevant terrain source art.

Validation:
- `python3 -m py_compile tools/build_overworld_terrain_tiles.py`
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a full overworld art pass for water/coast, badlands, ash/lava, snow/frost, cavern/underway, object footprints, or road movement rules.
- Visual quality still needs manual live-client review after the checked-in source-derived tiles land.
- Superseded on 2026-04-20 by the original quiet terrain correction after AcOrP clarified that generated-source per-cell tiling is the wrong primary model.

## Current Implementation Slice: Overworld Original Terrain Correction
Status: completed on 2026-04-20 as a corrective slice after AcOrP rejected generated-source terrain tiling as the primary approach.

Purpose:
- Stop treating generated painterly source terrain as the main per-cell tile source.
- Keep the terrain grammar and structural road layer, but move the art approach toward original quiet biome bases, macro readability, jagged transitions, and connection-aware roads.
- Use the local HoMM3 reference pack only for rules and taxonomy: quiet terrain at map scale, many specialized pieces, structural roads, and intentional transitions. Do not copy assets.

Implemented:
- Replaced `tools/build_overworld_terrain_tiles.py` with a local procedural builder that writes original 64x64 base variants, jagged edge overlays, and `road_dirt` connector pieces to the existing runtime paths.
- Rebuilt the checked-in grass/plains, forest, mire/swamp, hills/ridge/highland, edge, and road PNGs from restrained local palettes instead of source-image crops.
- Updated `content/terrain_grammar.json` and `art/overworld/manifest.json` to record `original_quiet_tile_bank` as the primary base model and mark generated terrain sheets deprecated for primary bases.
- Extended `OverworldMapView` validation metadata so smokes can distinguish original quiet tile-bank rendering, generated-source non-primary status, jagged transition overlays, and road connection-piece overlays.

Validation:
- `python3 -m py_compile tools/build_overworld_terrain_tiles.py`
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is still a first correction over the covered terrain families, not the final shipped terrain atlas.
- Water/coast, badlands/wastes, ash/lava, snow/frost, cavern/underway, object footprints, and road movement rules remain future slices.
- Automated smokes can prove the renderer path and metadata; manual visual review is still required before treating the terrain direction as broadly proven.

## Current Implementation Slice: Overworld Grounded Marker Presentation
Status: completed on 2026-04-20 as a narrow corrective slice after AcOrP reported the post-a827e04 overworld still read like a board with pasted-on UI markers.

Purpose:
- Make towns, resource sites, artifacts, encounters, mapped object sprites, and the active hero feel seated on the terrain instead of floating on generic dark badges.
- Reduce boardgame/UI-badge read while preserving strong visible/remembered object clarity and current selection/focus clarity.
- Keep the new original quiet terrain direction, structural roads, fog behavior, tactical framing, panning, pathing, and object sprite mappings/fallbacks unchanged.

Implemented:
- Replaced the filled circular marker plate drawing path in `OverworldMapView` with terrain-tinted oval footprint anchors, lower contact shadows, and small ground tie marks.
- Removed the extra circular badge outline from mapped overworld object sprites and added a soft offset sprite shadow so mapped objects still separate from terrain without reading as UI medallions.
- Reduced overworld grid alpha enough to quiet the board read while keeping movement/path readability and route overlays intact.
- Updated validation metadata, smokes, and the overworld art manifest to describe `ghosted_sprite_with_ground_anchor` and guard against a return to UI badge plates.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a full object-art pass, town-sprite pass, camera redesign, or movement/pathfinding change.
- The fallback procedural silhouettes remain intentionally compact and icon-like where no real object sprite exists; the correction is their terrain grounding and removal of the generic black badge.
- Manual visual review is still needed before treating overworld presentation as broadly polished.

## Current Implementation Slice: Overworld Object-First Presence
Status: completed on 2026-04-20 as the next narrow rendering nudge after AcOrP reported the post-c98de5d overworld still read too much like symbols/markers on a board.

Purpose:
- Push key overworld things toward placed world objects with presence and footprint, while keeping the current quiet terrain, road direction, fog, pathing, panning, tactical framing, and selection clarity intact.
- Improve procedural fallback object rendering instead of replacing it with a fake-complete art pass.
- Start using authored map-object footprint metadata as presentation guidance without changing gameplay occupancy or movement rules.

Implemented:
- `OverworldMapView` now builds resource-site object profiles from `content/map_objects.json`, including authored footprint size, family, passability, visitability, and roles where available.
- Mapped resource/artifact sprites now use footprint-scaled placement, a slightly lifted world-object draw position, a stronger soft shadow, and a foreground ground lip so they sit into the terrain instead of floating as square sprites on an anchor.
- Procedural fallback markers now branch into family-specific world silhouettes for dwellings/services/outposts, mines, scouting towers, guarded ruins, transit structures, shrines, pickups, artifacts, encounters, towns, and the active hero.
- Towns, encounters, artifacts, and the hero now draw as small placed silhouettes with ground-lip occlusion cues instead of only abstract symbols.
- Validation metadata and smokes now guard the object-first presence model, footprint dimensions, foreground occlusion lip, mapped-sprite settlement model, and family-specific fallback silhouettes.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final town/object art, a complete overworld object atlas, or true multi-tile object occupancy.
- Footprints currently guide presentation scale and grounding only; movement, blocking, visit targets, and pathing behavior are unchanged.
- Procedural fallbacks are more object-like, but authored sprites are still needed for important towns, encounters, and many site families before the map can be considered visually mature.

## Current Implementation Slice: Overworld Depth Contact Cues
Status: completed on 2026-04-20 as the next narrow presentation-only renderer slice after the first object-first presence pass.

Purpose:
- Deepen the terrain contact for towns, sites, dwellings, encounters, mapped sprites, and active hero presence without changing gameplay occupancy, pathing, fog, panning, tactical framing, selection, or sprite mappings.
- Add a real depth cue beyond the existing footprint anchor and foreground ground lip.
- Keep the correction presentation-only and smoke-validated rather than claiming final overworld object art.

Implemented:
- `OverworldMapView` now draws a footprint-scaled directional cast shadow below each object anchor before the terrain ellipse, so placed objects read with a consistent terrain-side shadow instead of only a flat support mark.
- The existing foreground ground lip now includes small base occlusion pads drawn over object feet/bases, improving the sense that procedural silhouettes, mapped sprites, towns, encounters, and the hero are partially seated into the terrain.
- Mapped sprite validation now reports the deeper contact cue model alongside the existing footprint-scaled sprite settlement and ground-lip occlusion model.
- Focused overworld and Ninefold smoke coverage now guards the cast-shadow/base-occlusion depth model for visible objects, large-map objects, mapped sprites, and active hero presence.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a new object atlas, town-art pass, camera change, pathfinding change, or true multi-tile occupancy implementation.
- The cues are still renderer-level presentation hints; authored object footprints remain presentation scale hints only.
- Automated validation guards the presentation contract and metadata, but broad visual polish still needs manual review across more maps, biomes, resolutions, and eventual final art.

## Current Implementation Slice: Overworld Footprint Placement Beds
Status: completed on 2026-04-20 as a narrow presentation-only follow-up after the contact-depth cue slice.

Purpose:
- Add local terrain quieting directly under towns, sites, dwellings, encounters, mapped sprites, and active hero presence so placed world objects read faster against busy terrain.
- Keep the treatment as subtle footprint-aware ground presentation, not generic UI plates or loud markers.
- Preserve gameplay occupancy, pathing, fog, panning, selection logic, save data, and existing object mappings.

Implemented:
- `OverworldMapView` now passes tile context into the existing marker/anchor draw path and renders a terrain-tinted organic footprint clearing beneath each object anchor before contact shadows, anchors, silhouettes, sprites, and foreground base occlusion are drawn.
- Placement beds scale from the same authored/default object footprints already used for presentation, including towns, resource-site families, mapped sprites, artifacts, encounters, and the active hero.
- The bed color is derived from the local terrain base/detail colors and uses muted alpha plus broken edge scuffs so it suppresses terrain texture noise without becoming a badge plate.
- Updated overworld art manifest metadata and focused smoke validation payloads/assertions for `footprint_terrain_quieting_bed` on visible, remembered, large-map, procedural fallback, mapped-sprite, and hero-present objects.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final overworld object art, a town sprite pass, a terrain atlas expansion, a camera change, or a gameplay footprint/occupancy system.
- Footprints still guide presentation only; movement, blocking, visit targets, fog, save data, and object mappings are unchanged.
- Manual visual review is still needed before treating the overworld as polished or HoMM3-class.

## Current Implementation Slice: Overworld Upper-Mass Backdrop Cues
Status: completed on 2026-04-20 as a narrow presentation-only follow-up after the footprint placement-bed slice.

Purpose:
- Add subtle rear upper-mass separation behind towns, sites, dwellings, encounters, mapped sprites, and active hero presence so taller placed objects read above busy terrain instead of only as grounded markers.
- Keep the cue as a family-scaled terrain-depth wash and vertical mass shadow, not a UI halo, badge plate, selection marker, or gameplay footprint.
- Preserve gameplay occupancy, pathing, fog, panning, selection logic, save data, and existing object mappings.

Implemented:
- `OverworldMapView` now draws a low-alpha, tapered rear backdrop wash behind object upper bodies after footprint placement/contact cues and before silhouettes, mapped sprites, town markers, encounters, artifacts, and hero figures.
- The backdrop dimensions are keyed by object family and authored/default footprint so broad towns and dwellings get wider mass separation while towers, shrines, transit shapes, artifacts, pickups, encounters, and heroes remain compact.
- A paired subtle vertical mass shadow gives the upper object body a rear depth cue without adding bright glow halos, badge plates, permanent labels, or UI overlays.
- Focused overworld and Ninefold smoke coverage now guards the `family_scaled_rear_backdrop_wash` model, behind-body placement, subtle alpha range, vertical mass shadow, and non-UI-halo/non-badge contract for visible, remembered, large-map, mapped-sprite, and hero-present objects.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final object/town art, a new sprite atlas, terrain expansion, camera change, or true multi-tile object implementation.
- The cue is renderer-level presentation only; movement, blocking, visit targets, fog, save data, and object mappings are unchanged.
- Manual visual review is still required before claiming the overworld is polished or near HoMM3-class readability.

## Current Implementation Slice: Overworld Town And Encounter Placeholder Assets
Status: completed on 2026-04-20 as a narrow asset-readability slice using the newly approved generated candidates.

Purpose:
- Replace the most player-facing remaining procedural silhouettes for towns and unresolved encounters with the first credible repo-local placeholder sprites.
- Keep the slice deliberately narrow: one default town sprite and one default hostile-camp encounter sprite, not a broad object-family atlas.
- Preserve the existing object grounding, footprint placement beds, contact shadows, upper-mass backdrop cues, fog, pathing, panning, selection, save data, and gameplay object logic.

Implemented:
- Adapted the selected 2026-04-20 town candidate into `frontier_town` runtime/source overworld asset paths.
- Adapted the selected 2026-04-20 encounter-camp candidate into `hostile_camp` runtime/source overworld asset paths.
- Added manifest-backed default town and encounter sprite ids, with procedural town/encounter silhouettes retained as renderer fallbacks if the assets fail to load.
- Wired `OverworldMapView` so towns and unresolved rememberable encounters use the same footprint-scaled sprite settlement, placement-bed, contact-depth, upper-mass backdrop, remembered-sprite, and foreground-lip treatment already used by mapped overworld sprites.
- Kept owner readability for town sprites through a compact renderer pennant instead of reverting to colored procedural town bodies.
- Extended repo validation plus River Pass and Ninefold Confluence smokes to guard the new default town and encounter sprite path.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final town art, final encounter art, faction-specific town variants, encounter-family variants, or a complete object atlas.
- The generated candidates are approved as first placeholder source only; manual live-client review is still needed before treating the overworld object art direction as polished.
- Town and encounter sprites remain presentation only; movement, blocking, visit targets, fog, save data, and battle/object logic are unchanged.

## Current Implementation Slice: Overworld Town Footprint Presentation
Status: completed on 2026-04-20 as a narrow presentation-first readability slice.

Purpose:
- Make overworld towns present as the intended larger world object footprint instead of a compact 2x2-ish marker.
- Keep the existing town coordinate truthful as the actual visit approach tile while exposing the intended 3x2 presentation footprint around it.
- Avoid pretending the current movement/pathing model supports true multi-tile occupancy.

Implemented:
- Changed the town presentation profile in `OverworldMapView` from a 2x2 scale hint to a 3x2 world-object profile.
- Defined the existing town coordinate as the bottom-row middle `bottom_middle_visit_approach` tile for presentation and validation.
- Added a subtle gate/apron cue on the approach tile, with the town sprite rendered against the larger footprint rect where the footprint is in bounds.
- Added footprint underlay cues so non-entry town footprint cells read as blocked/non-entry in the presentation model.
- Exposed town footprint metadata through tile presentation snapshots and `town_presentation_profiles`, including entry tile, origin, footprint cells, blocked non-entry cells, and off-map clipped cells.
- Extended repo validation plus River Pass and Ninefold smokes to guard the 3x2 town footprint, bottom-middle entry role, blocked non-entry metadata, and large-map in-bounds footprint profile.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a core movement, pathfinding, save-schema, town-entry, or true multi-tile occupancy slice.
- Non-entry footprint tiles are blocked only in the presentation/validation model. The underlying overworld rules still treat towns as single-tile interactions until a future occupancy/pathing slice is designed.
- Edge-placed legacy towns can have off-map clipped presentation cells; the validation metadata reports those honestly instead of moving scenario towns inside this slice.

## Current Implementation Slice: Overworld Town Grounding Correction
Status: completed on 2026-04-20 as a narrow visual correction to the town object presentation.

Purpose:
- Remove the town-specific base ellipse, filled footprint underlay, directional cast shadow, base occlusion pads, and upper-mass shadow/backdrop that made towns read as staged markers instead of placed world objects.
- Preserve the useful part of the previous slice: towns still present as 3x2 world objects with the existing town coordinate as the bottom-middle approach/visit tile.
- Keep gameplay untouched: no movement, pathing, save, battle, town-entry, or true occupancy changes.

Implemented:
- Split town sprite drawing off the shared mapped-object plate/shadow path in `OverworldMapView`.
- Replaced the filled town footprint underlay with sparse non-entry wall cues plus a narrower, lower-alpha bottom-middle entry approach cue.
- Removed town cast-shadow, base-occlusion-pad, placement-bed, and vertical-mass-shadow metadata from validation payloads while leaving the shared treatment intact for other object families.
- Updated the overworld art manifest, repo validator, and River Pass/Ninefold smokes to guard the town-specific no-ellipse/no-underlay/no-cast-shadow model.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final town art, a sprite replacement, a broad object-renderer rollback, or a gameplay footprint system.
- Other overworld object families still use their shared terrain grounding, placement-bed, contact-shadow, and backdrop cues from earlier slices.
- Manual visual review is still needed before treating the town presentation as polished across every biome and resolution.

## Current Implementation Slice: Overworld Town Helper Cue Removal
Status: completed on 2026-04-20 as a narrow AcOrP screenshot-feedback correction.

Purpose:
- Remove the remaining editor/helper-looking town footprint and entry cues from the overworld presentation path.
- Preserve the town 3x2 presentation model, bottom-middle entry/visit metadata, and non-entry footprint contract for validation.
- Keep gameplay untouched: no movement, pathing, visit logic, ownership, roads, hero rendering, mapped sprite grounding, terrain, save/load, or rules changes.

Implemented:
- Made the town footprint-underlay and entry-approach draw paths render no visible helper marks.
- Changed town presentation metadata from sparse visible wall/entry cues to a cue-free 3x2 contract.
- Updated the art manifest, repo validator, and River Pass/Ninefold smoke assertions so they reject visible town helper glyphs, entry aprons/wedges, gate helpers, and helper circles while preserving the bottom-middle entry contract.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final town art, faction-specific town art, true multi-tile occupancy, pathing, movement, save/load, town logic, or ownership logic.
- The 3x2 town footprint still exists as presentation/validation metadata only; non-entry cells remain a presentation contract rather than gameplay blocking.

## Current Implementation Slice: Overworld Hero Presence Correction
Status: completed on 2026-04-20 as a narrow visual correction to the active hero presentation.

Purpose:
- Make the active hero read more like a placed world figure and less like a staged badge/marker.
- Preserve active-hero clarity, current selection readability, and the existing tile focus ring.
- Keep the correction hero-specific instead of rolling back the shared object renderer or touching gameplay rules.

Implemented:
- Split active-hero drawing in `OverworldMapView` away from `_draw_marker_plate`.
- Replaced the hero's filled footprint bed, base ellipse, marker ring, and upper-mass backdrop with compact foot-contact shadow, terrain scuffs, boot-level foreground occlusion, and a larger outlined standing figure/banner silhouette.
- Added hero-specific validation metadata for the placed world-figure model, no-base-ellipse/no-shared-marker support, foot-contact depth cues, and tile-focus selection source.
- Extended River Pass and Ninefold Confluence visual smokes to guard the hero-specific presence correction while leaving town no-ellipse validation and non-hero object grounding intact.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final hero art, animation, movement, pathing, fog, save/load, battle routing, town logic, or hero-rule work.
- The active hero remains a procedural placeholder silhouette until authored hero overworld sprites are added.
- Manual visual review is still needed before treating hero presentation as polished across every biome and resolution.

## Current Implementation Slice: Overworld Terrain And Road Tile Correction
Status: completed on 2026-04-20 as an AcOrP-priority terrain/road correction after feedback that the base tiles and roads were still breaking immersion.

Purpose:
- Improve the actual original quiet base terrain tile bank and structural dirt-road overlay pieces, not town/hero/site marker polish.
- Keep the existing authored autotile layer contract: runtime 64x64 PNGs, `original_quiet_tile_bank`, jagged edge overlays, and `road_dirt` structural overlays.
- Preserve gameplay, pathing, fog, save, object, town, hero, and site logic.

Implemented:
- Updated `tools/build_overworld_terrain_tiles.py` so base tiles use deterministic multi-scale ground grain instead of near-flat per-pixel noise, with stronger terrain-specific tufts, canopy clusters, reed pools, worn streaks, contours, and scree details.
- Rebuilt the checked-in grass/plains, forest, mire/swamp, and hills/ridge/highland runtime base PNGs from the revised original builder.
- Rebuilt `road_dirt` center and connector PNGs as softer rutted dirt beds with muted earth colors, organic center masks, slight connector wobble, grit, and rut lines, reducing the stamped bright center-bead read.
- Updated terrain grammar and art manifest wording to record the corrected map-scale ground grain and soft rutted structural road connectors while retaining the original quiet tile-bank status.

Validation:
- `python3 -m py_compile tools/build_overworld_terrain_tiles.py`
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is still a narrow covered-family correction, not a final terrain atlas or artist-authored complete overworld tileset.
- Water/coast, badlands/wastes, ash/lava, snow/frost, cavern/underway, and road movement-cost/pathfinding behavior remain future slices.
- Automated validation proves the runtime contract and smoke surfaces; manual visual review is still needed before treating the terrain and road look as broadly solved.

## Current Implementation Slice: Overworld Terrain Feedback Correction
Status: completed on 2026-04-20 as a narrow terrain/road-only correction after AcOrP feedback on checkerboard grass/plains, artificial borders, and road center overlap.

Purpose:
- Make grass/plains read as one consistent grasslands family instead of alternating high-contrast cells.
- Make terrain edge overlays softer and less like stamped borders while keeping the authored terrain grammar and transition priorities.
- Fix road center/intersection stamping without changing road movement, pathing, fog, save data, or object presentation.

Implemented:
- Tuned the terrain builder so grass and plains share a closer palette, lower contrast ground grain, fewer sharp grass marks, and patch-cohesive low-frequency tile variant selection in `OverworldMapView`.
- Rebuilt grass/plains runtime base PNGs plus all covered directional edge overlays and `road_dirt` pieces from the deterministic builder.
- Changed edge overlay generation from hard dark strips to feathered jagged intrusion masks with reduced line/highlight alpha.
- Changed road art rendering so connector pieces draw first and the center cap is only stamped on endpoints, bends, isolated tiles, and true junctions, instead of every straight road tile.
- Extended smoke-test presentation metadata for cohesive grasslands variants, softened edge treatment, and connection-aware road joint caps.

Validation:
- `python3 -m py_compile tools/build_overworld_terrain_tiles.py`
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is a correction to the current procedural tile bank and renderer contract, not a final terrain atlas or broad art pass.
- Unsliced terrain families still use grammar fallback colors/patterns until their own authored tile art lands.
- Road overlays remain visual presentation only; movement cost and pathfinding still do not treat roads specially.

## Current Implementation Slice: Overworld Visible Terrain Seam Correction
Status: completed on 2026-04-20 as a narrow presentation-only correction after AcOrP feedback that black grid lines still showed between visible explored tiles.

Purpose:
- Remove the explicit per-tile black rectangle grid over explored overworld terrain.
- Preserve map readability through terrain art, roads, route lines, selection/current-tile rings, and a limited fog-boundary hint.
- Keep the unexplored hidden-ground wireframe treatment intact.

Implemented:
- Removed the explicit per-tile black grid rectangle from explored terrain rendering in `OverworldMapView`.
- Added a limited explored-terrain fog-boundary hint only where mapped terrain touches unexplored ground.
- Kept unexplored hidden tiles on the existing wireframe treatment.
- Extended smoke metadata/assertions so explored terrain reports `fog_boundary_only` grid behavior with no inter-explored tile seams, while unexplored terrain still reports its wireframe.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a terrain palette, road art, fog-of-war, pathing, save, object, town, hero, or site behavior change.
- Manual visual review is still needed before treating all supported viewports and biomes as polished.

## Current Implementation Slice: Overworld Procedural Object Grounding
Status: completed on 2026-04-20 as a narrow presentation-only correction after resource/artifact/encounter fallbacks still read like staged marker medallions.

Purpose:
- Move unmapped procedural resource-site, artifact, and unresolved encounter objects off the shared marker-plate, rear-backdrop, and foreground-lip path.
- Keep mapped overworld sprites, town grounding, hero presence, terrain, roads, fog, panning, pathing, and gameplay behavior unchanged.
- Prefer family-specific grounding and material color cues over a broad renderer rollback.

Implemented:
- Added a fallback-only grounding path in `OverworldMapView` with thin terrain contact disturbance, localized contact shadows, small contact marks, and family-specific resource material tinting.
- Removed the shared marker plate/ring, upper-mass backdrop, vertical mass shadow, foreground ground lip, and base occlusion pads from procedural resource, artifact, and encounter fallback drawing.
- Kept mapped object sprites on the existing footprint-scaled sprite settlement path and kept town/hero no-ellipse corrections intact.
- Updated overworld art manifest metadata and River Pass/Ninefold smoke presentation assertions to distinguish mapped sprites from no-plate procedural fallbacks.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final object art or a new sprite atlas.
- Procedural fallback silhouettes remain compact placeholders; this slice only changes how they are grounded into the map surface.
- No movement, pathing, fog, save/load, battle, town, resource-site, artifact, encounter, terrain, road, or seam behavior changed.

## Current Implementation Slice: Overworld Mapped Sprite Grounding
Status: completed on 2026-04-20 as a narrow presentation-only correction after mapped resource/artifact/encounter sprites still read like staged support-stack markers.

Purpose:
- Move mapped resource-site, artifact, and unresolved encounter asset sprites off the shared support-stack composition.
- Keep towns on their dedicated quiet town path and keep procedural fallbacks on their already-corrected no-plate grounding path.
- Preserve hero presence, terrain, roads, fog, panning, pathing, save/load, battle, town, resource-site, artifact, and encounter gameplay behavior.

Implemented:
- Split mapped resource/artifact/encounter sprites in `OverworldMapView` onto a mapped-sprite-specific local contact anchor.
- Removed the broad terrain quieting bed, filled marker plate/ring, upper-mass backdrop wash, vertical mass shadow, duplicate offset sprite shadow, foreground ground lip, and base occlusion pads from mapped sprite drawing.
- Added compact terrain contact disturbance and localized contact shadows so mapped sprites stay readable on terrain without visible helper plates.
- Updated overworld art manifest metadata plus River Pass and Ninefold smoke assertions to guard the no-support-stack mapped sprite contract while preserving the town-specific no-helper-cue path.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not final object art, a new sprite atlas, or a broad object renderer rewrite.
- Mapped sprite footprints remain presentation scale hints only; movement, blocking, visit targets, save data, and scenario rules are unchanged.

## Current Implementation Slice: Overworld Diagonal Road Tiling
Status: completed on 2026-04-20 as a narrow road-presentation correction after AcOrP feedback that diagonal roads still read like smeared strokes and joined awkwardly at turns.

Purpose:
- Make diagonal dirt-road chains read as deliberate tile pieces with clean joins rather than center-crossing connector strokes.
- Stop diagonal-to-cardinal turns from gaining unintended extra diagonal connections purely because nearby road tiles touch at a corner.
- Keep the slice visual/presentation-only: no road movement costs, pathing, fog, save/load, battle, town, object, mapped-sprite, or terrain-base behavior changes.

Implemented:
- Changed `OverworldMapView` road connectivity so each road tile records directions from ordered `content/terrain_layers.json` road paths, merging true shared-tile intersections while suppressing unordered adjacent-road overpaint.
- Added terrain-grammar support and generated PNG art for full-tile NE/SW and NW/SE diagonal straight road pieces.
- Updated road validation metadata to expose ordered connection source, connection count, straight diagonal piece use, and center-cap behavior.
- Extended the Ninefold smoke to guard a straight diagonal road tile, a diagonal-to-cardinal join, and the following cardinal segment.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is still generated placeholder road art, not a final road atlas.
- The fix relies on authored road paths sharing an actual tile for intersections; adjacent road tiles no longer imply a diagonal join by themselves.
- Manual visual review is still needed before treating every diagonal-road composition and supported viewport as polished.

## Current Implementation Slice: Overworld HoMM-Style Road Topology
Status: completed on 2026-04-20 as a narrow road-presentation correction after AcOrP clarified that roads should be built from same-type neighboring road tiles with different vertical and horizontal placement rules.

Purpose:
- Move road presentation away from treating every segment as a centerline stroke.
- Rebuild dirt-road tile connections from adjacent same-type road tiles.
- Make vertical road runs sit through the tile center while horizontal road runs ride on a lower tile-edge lane.
- Keep the slice visual/presentation-only: no road movement costs, pathing, fog, save/load, battle, town, object, mapped-sprite, or terrain-base behavior changes.

Implemented:
- Changed `OverworldMapView` road connectivity to collect road tiles first, then derive connection directions from adjacent road tiles with the same overlay id.
- Added road-lane metadata and validation payload fields for same-type adjacency, centered vertical lanes, edge-riding horizontal lanes, and HoMM-style piece composition.
- Updated the procedural fallback drawing path and regenerated the primary dirt-road PNGs so E/W road pieces use the lower edge lane while N/S pieces remain centered.
- Updated terrain grammar and manifest metadata to document the same-type adjacency, centered-vertical, edge-horizontal road topology contract.
- Replaced the previous diagonal-only smoke assertions with coverage for vertical straight, horizontal straight, mixed intersection, and diagonal-straight road tiles.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is still placeholder road art, not a final road atlas or full HoMM3-equivalent road system.
- Diagonal-road art remains narrow coverage; the important correction in this slice is the topology/lane model and adjacency-derived piece selection.
- Manual visual review is still needed before treating every road composition and supported viewport as polished.

## Current Implementation Slice: Overworld Art Asset Integration
Status: completed on 2026-04-19 as a narrow integration pass for the generated overworld asset cut.

Purpose:
- Move the newly processed overworld terrain and object assets into repo-local art paths that Godot can load directly.
- Use the art where semantic matches are clear enough, without pretending the generated asset set covers the whole overworld vocabulary.
- Preserve the existing procedural marker system as the fallback for unmapped or uncertain object families.

Implemented:
- Added `art/overworld/` with a clear runtime/source split: runtime terrain textures, 512-canvas runtime object sprites, trimmed source object cuts, the generated source manifest, and a repo-local mapping manifest.
- Wired `OverworldMapView` to load `art/overworld/manifest.json`, sample terrain textures for grass/plains, forest, mire/swamp, and hills/ridge/highland, and fall back to the existing color/pattern rendering for unsupported terrain ids such as water, snow, ash, badlands, and cavern.
- Wired selected resource-site and artifact sprites through explicit best-effort mappings: timber wagon, ore crates, waystone cache/ruined obelisk, selected neutral dwellings, shrines, watchtower, sawmill, quarry, and a generic artifact bundle.
- Preserved procedural markers for towns, encounters, unsupported resource sites, and every unmapped object/site family; remembered mapped objects use a ghosted sprite over the existing memory plate treatment.
- Extended repo validation and overworld smokes to guard asset paths, manifest mappings, texture terrain activation, mapped sprite activation, remembered sprite treatment, and procedural fallback for unmapped sites.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- The generated assets are imperfect and semantically partial; mappings are intentionally conservative and recorded in `art/overworld/manifest.json`.
- As of the 2026-04-20 terrain-foundation slice, the generated terrain textures are no longer the primary overworld terrain model; they are retained as source history while object sprite mappings remain active.
- This is not a complete overworld art pass, town art pass, encounter art pass, or object-footprint system.
- Automated smokes prove runtime loading and presentation metadata, not manual visual polish across every object, biome, and resolution.

## Current Implementation Slice: Overworld Terrain Grammar Foundation
Status: completed on 2026-04-20 as a terrain-system replacement for the chopped sampled-texture direction.

Purpose:
- Stop using per-tile sampled painterly terrain PNGs as the main overworld terrain model.
- Introduce an authored, autotile-ready terrain grammar that can support clear base terrain, biome edges, transition masks, authored variants, and structural road overlays.
- Make the current overworld read more like a strategic map surface while preserving existing object sprite mappings and procedural object fallbacks.

Implemented:
- Added `content/terrain_grammar.json` with authored terrain classes for grass/plains, forest, mire/swamp, hills/ridge/highland, plus current supporting terrain ids, transition priority, terrain groups, style ids, pattern roles, road support, and the first `road_dirt` overlay grammar.
- Added `content/terrain_layers.json` with authored structural road overlays for River Pass and Ninefold Confluence instead of baking road marks into terrain art.
- Wired ContentService validation/loading, ScenarioFactory session seeding, and OverworldRules legacy normalization for terrain layers without a save-version bump.
- Replaced `OverworldMapView`'s sampled terrain texture path with deterministic grammar-driven base fills, readable terrain detail patterns, neighbor edge-transition masks, and road overlay connector drawing.
- Updated `art/overworld/manifest.json` to mark sampled overworld terrain textures as deprecated-not-primary while keeping object sprite mappings and fallback behavior.
- Updated repo validation and overworld smokes to require authored terrain grammar, non-sampled terrain presentation, edge-transition metadata, and structural road overlay metadata.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`

Limits:
- This is a foundation and first readable presentation slice, not final overworld art.
- Road overlays are presentation/grammar structure only; they do not yet change movement cost or pathfinding.
- This slice was superseded visually by the first authored terrain tile-art slice; the grammar remains the content boundary for that art.

## Current Implementation Slice: Overworld Authored Terrain Tile Art
Status: completed on 2026-04-20 as the first narrow real overworld terrain tile-art slice after the grammar foundation.

Purpose:
- Replace the procedural-looking grammar fills for the first terrain families with repo-local static tile art used directly by `OverworldMapView`.
- Keep the slice narrow and honest: cover grass/plains, forest, mire/swamp, hills/ridge/highland, dirt roads, and biome edge overlays without claiming full-world terrain art completeness.
- Preserve existing overworld object sprite mappings and procedural fallbacks for unmapped sites, towns, encounters, and unsliced terrain ids.

Implemented:
- Added `tools/build_overworld_terrain_tiles.py` as a deterministic source builder for the first 64x64 authored PNG tile pieces.
- Added `art/overworld/runtime/terrain_tiles/` with base terrain variants for grass/plains, forest, mire/swamp, hills/ridge/highland; directional edge overlays for grasslands, forest, mire, and highland groups; and structural `road_dirt` center/connector pieces.
- Extended `content/terrain_grammar.json` so the first terrain classes and the `road_dirt` overlay reference actual tile-art paths, while non-sliced terrain ids continue to use grammar color/pattern fallback.
- Wired `OverworldMapView` to render loaded terrain tile textures, edge overlay textures, and road connector textures first, with the previous grammar patterns and procedural road drawing retained as fallbacks.
- Extended ContentService warnings, repo validation, and overworld smokes to prove authored tile art, edge-transition art, and road overlay art are present and used.

Validation:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path . res://tests/overworld_visual_smoke.tscn`
- `godot4 --headless --path . res://tests/ninefold_scenario_smoke.tscn`
- `git diff --check`

Limits:
- This is not a complete overworld tileset. Water/coast, badlands/wastes, ash/lava, snow/frost, cavern/underway, towns, encounters, and most map-object families still need future art slices or existing fallbacks.
- Road overlays remain visual/structural presentation only; movement cost and pathfinding still do not treat roads specially.
- The source builder gives repeatable checked-in PNGs for this slice; a broader artist-facing atlas/import workflow remains future work.

## Phase 0: Honest Reset / Parity Ledger / Stop Fake-Complete Language
Status: active reset now becomes the baseline for future work.

Purpose:
- Replace stale implied-completion docs with an honest pre-alpha roadmap.
- Keep the long-term ambition while clearly separating foundations from playability.
- Establish a parity ledger that prevents future docs from claiming parity without evidence.

Execution order:
1. Rewrite `project.md` around the true current state, retained architecture, and staged delivery strategy.
2. Rewrite this plan around phases that start with River Pass manual completion rather than broad release claims.
3. Reset `ops/progress.json` to in-progress status with the active slice focused on River Pass playability and battle/town/UI recovery.
4. Create or maintain a parity ledger in planning docs before future scope expansion. The ledger should track:
   - implemented system
   - live-client usable state
   - manual-play evidence
   - automated coverage
   - known blockers
5. Stop using these labels until proven: release-ready, release-facing, fully playable, HoMM2 parity, HoMM3 parity, complete campaign, complete faction, shippable UX.

Acceptance criteria:
- Docs clearly state the project is prototype / pre-alpha.
- Docs do not claim release readiness.
- The immediate milestone is River Pass manually completable by a real player.
- Progress tracking is no longer marked completed.
- Valid architecture decisions remain visible and usable.

## Phase 1: River Pass Manually Completable End-To-End
Status: accepted as passed from AcOrP's manual play report on 2026-04-18; keep parity notes and cleanup follow-ups, but this gate is no longer the blocker for alpha content work.

Purpose:
- Make one scenario, River Pass, honestly playable from start to finish in the live client.
- Recover the actual player loop before adding more breadth.

Primary scenario target:
- River Pass, also referred to by existing campaign content as Reedfall River Pass where applicable.

Current save/resume focus:
- Town manual-save resume route truthfulness is verified: the fresh routed live-flow blocker was a harness final-frame scene-detection race, not a product route failure.
- Preserve the existing useful coverage for selected manual save identity, resume target, scenario id, town state restoration, and downstream overworld/battle routing.
- Continue proving any remaining River Pass save/resume surfaces through live-client routes before treating the save/resume milestone as complete.
- Recently completed slice: overworld selected-site primary action usability added a primary selected-site order path with Enter/Space activation and routed live validation coverage.

Current display/layout focus:
- Recently completed slice: the first OverworldShell structural wireframe pass changes the screen grammar away from a dashboard by making the adventure map the direct dominant BodyRow surface, moving the old top strip and contextual Event/Order/Notice cards into one carved right-side command spine, removing the map-embedded summary strip, and compressing resources/date/core orders/save/menu controls into a 74px footer ribbon. Secondary context actions now live in the right-spine Tile tab instead of growing the footer. Focused overworld visual smoke, shell heraldry smoke, repo validation, and diff whitespace checks are green. No manual visual proof is claimed.
- Recently completed follow-up: AcOrP's overworld right-rail screenshot feedback is addressed structurally by removing the cramped right-rail `TabContainer`/tab strip, replacing squeezed `HeroActions` and other rail action chips with full-width vertical command rows, and keeping Tile, Command, and Frontier sections stacked inside one readable command spine. Focused overworld visual smoke now guards against a returned right-rail tab strip, narrow action-chip collapse, and visible vertical-text-shaped labels while preserving map dominance. Focused overworld visual smoke, shell heraldry smoke, and repo validation are green. No manual visual proof is claimed.
- Recently completed follow-up: AcOrP's overworld right-rail text-density feedback is addressed narrowly by changing the visible Log, Order, Tile, Command, Frontier, hero, and notice labels to clipped no-wrap rail summaries while leaving longer source detail available through tooltips and validation data. The visible rail now leads with one compact line per minor row and at most two lines for order/tile/notice/hero summaries, and focused overworld visual smoke guards those line budgets, clipping behavior, and absence of `+ more` report fragments. Focused overworld visual smoke, shell heraldry smoke, and repo validation are green. No manual visual proof is claimed.
- Recently completed follow-up: AcOrP's overworld declutter feedback is addressed as a coherent usability iteration rather than a full redesign: the Order/commitment board is hidden by default and folded into current-action feedback/tooltips, Tile detail now appears only as selection context instead of a permanent right-rail section, Command and Frontier are explicit compact buttons that open hidden drawer panels, Frontier keeps only a tiny status indicator while collapsed, and the footer no longer carries the permanent movement explainer or directional march buttons. Save, end-turn, menu, resources, date/status, and the primary selected-site action remain accessible. Focused overworld visual smoke now guards that the old permanent drawers, map hint, and footer march controls cannot silently return; shell heraldry smoke and repo validation are green. No manual visual proof is claimed.
- Recently completed slice: the Godot project display baseline now targets 1920x1080 with `canvas_items` / `expand` stretch, repo validation guards that display contract, and battle layout smoke promotes 1920x1080 as the primary viewport while retaining compact 1280x720 and 1024x600 regression coverage. The audit found the remaining 1280x720 coupling was test-side; at 1080p the battle board validation now reports when neighboring stack hit-shape overlap is geometrically impossible instead of treating that compact-layout edge case as a failure. Focused menu/outcome, overworld, town/battle, battle layout, and repo validation are green; no manual visual proof is claimed.
- Recently completed slice: Settings now has durable runtime resolution controls for the approved 16:9 desktop set (`1280x720`, `1600x900`, `1920x1080`, `2560x1440`) while keeping the Godot project baseline at 1920x1080. `SettingsService` persists and applies the selected resolution through the presentation settings path, the MainMenu Settings tab exposes a compact picker and summary, repo validation guards exact 16:9 options up to 1440p, and the menu/outcome smoke exercises the picker integration. No manual visual proof is claimed.
- Recently completed slice: AcOrP's main-menu shell feedback is addressed narrowly: the painted backdrop now keeps only light global washes while the right command gutter is darker and quieter, the main right rail is titled `Menu`, and `Menu`/`Quit` system commands live in a separate titled `Command` block below the navigation buttons. Focused menu/outcome smoke now guards the shade/gutter and command-block grouping, shell heraldry smoke paths are aligned with current scene layouts, and repo validation is green. No manual visual proof is claimed.
- Recently completed follow-up: AcOrP's residual main-menu shadow finding is addressed narrowly by removing the full-width `TopShade`/`BottomShade` scene layers and the `MainMenuHeroView.gd` painted-backdrop wash drawing, leaving the right-side gutter shade as the only broad backdrop darkening behind the command spine. Focused menu/outcome smoke now fails if those broad veil sources return, shell heraldry smoke is unchanged and green, and repo validation is green. No manual visual proof is claimed.
- Recently completed slice: AcOrP's first-view main-menu composition direction is addressed narrowly by replacing the generated command-spine panel with five painted-backdrop plaque hotspots only: Campaign, Skirmish, Load, Settings, and Quit. Continue Latest, Guide, Menu, the separate right shade, and the campaign/save status box are removed from the first-view shell while the secondary Campaign, Skirmish, Saves/Load, and Settings boards remain available after clicking the matching plaque. Focused menu/outcome smoke, shell heraldry smoke, and repo validation are green. No manual visual proof is claimed.
- Recently completed follow-up: AcOrP's screenshot feedback on the art-mapped main menu hotspot pass is addressed narrowly: only the lower Load, Settings, and Quit hotspot anchors were tightened/re-centered against the painted plaque interiors, and plaque hover/active feedback now changes text color without drawing a rounded hotspot rectangle. The painted backdrop command system is preserved and the old command spine/status box remains absent. Focused menu/outcome smoke, shell heraldry smoke, repo validation, and diff whitespace checks are green. No manual visual proof is claimed.

Current battle focus:
- Recently completed slice: the live battle board now reflects the landed hex legality model by showing legal movement and legal attack targets distinctly, marking selected-but-blocked targets as blocked, and keeping button previews aligned with the same rule checks that execute actions.
- Recently completed follow-up: target cycling, board-click focus, validation target alignment, and compact action/target summaries now prefer legal attack targets when any exist and explicitly call out selected targets that are blocked from the current hex.
- Recently completed follow-up: board clicks on legal enemy targets now dispatch the matching player attack order directly through the normal `strike` or `shoot` path, blocked enemy clicks remain explicit non-actions, green hex clicks still move, and focused smoke coverage exercises the scene-level click dispatch.
- Recently completed follow-up: direct enemy board clicks now use occupied-hex hit testing when the pointer misses the small stack token but remains inside the highlighted enemy hex, so ranged target clicks dispatch through the normal `Shoot` path instead of falling through as a no-op. Focused battle layout coverage stages a ranged hex-edge click that exercises the host-style mouse path, focused validation is green, and AcOrP manually confirmed the Ghoul Grove ranged shot path on the live shared screen.
- Recently completed follow-up: commander spell casting now clears ordinary closing-on-target context just like normal unit actions, so a spell after a closing move cannot leave stale movement wording in target/action guidance or board summaries. Focused core coverage stages the stale state with `Cinder Burst`, and focused core, battle layout, town/battle visual, repo validation, and X11 River Pass resolved-flow validation are green.
- Recently completed follow-up: invalid commander spell attempts now leave existing ordinary closing-on-target guidance intact, so a rejected repeat/stale spell command cannot erase truthful target guidance when no action occurred. The focused core spell-closing regression now proves rejected spells preserve closing context while valid spells still clear it.
- Recently completed follow-up: invalid ordinary battle orders now also leave ordinary closing-on-target guidance intact, so a rejected stale `Strike`/`Shoot`-style command cannot erase truthful target guidance when no action occurred. Successful ordinary actions still clear the context before resolving. Focused core coverage stages a rejected `Shoot` order after closing movement, and focused core plus battle layout smokes are green.
- Recently completed follow-up: visible outer-ring clicks inside a selected enemy hex now resolve against the actual hex polygon instead of the old center-radius cutoff, so highlighted ranged enemy hex-edge clicks that miss the token still dispatch through occupied-hex targeting and the normal `Shoot` path. Focused battle layout coverage stages the token-miss outer-ring click, and focused battle layout plus town/battle visual validation are green.
- Recently completed follow-up: visible green movement hex clicks now win over oversized friendly/active stack hit shapes when the resolved cell is a legal destination, so edge clicks in highlighted move cells are not swallowed as friendly stack focus no-ops. Focused battle layout coverage stages a legal movement cell overlapped by the active stack hit shape and proves the normal Move path executes.
- Recently completed follow-up: overlapped legal green movement hex tooltips now use the same Move-priority resolution as clicks, so a visible green destination partly under a friendly/active stack hit shape does not preview friendly-stack focus while the click executes movement. Focused battle layout coverage captures the tooltip before the overlapped click and proves it matches the movement intent.
- Recently completed follow-up: legal green movement destination clicks and tooltips now also win over oversized enemy token hit-shape overlap when the resolved cell is the green hex, so an adjacent enemy token cannot swallow a visible Move hex as target focus. Focused battle layout coverage stages an enemy-shape overlap on a legal destination, proves the tooltip stays on the Move intent, and proves the normal Move path executes.
- Recently completed follow-up: occupied enemy hex clicks and tooltips now prefer the actual resolved hex occupant over a neighboring enemy token's oversized hit shape, so a visible highlighted enemy hex cannot accidentally shoot the adjacent enemy stack. Focused battle layout coverage stages the neighboring-token overlap, proves the tooltip stays on the resolved hex target, and proves the normal `Shoot` path damages that target only.
- Recently completed follow-up: town-defense battles now derive retreat/surrender availability from the defense context as well as stored flags, so stale restored battle payloads cannot advertise open withdrawal buttons, pressure text, or summaries for actions that execution rejects. Focused core coverage stages stale open withdrawal flags on a restored Riverwatch defense battle, and focused core plus battle layout smokes are green.
- Recently completed follow-up: same-round player commander spell cooldown now surfaces truthfully after a cast in the spellbook, spell timing board, and order consequence command-tools line, matching the execution rejection for repeat casts. Focused core coverage stages a player cast followed by another friendly stack in the same round, and focused core plus battle layout smokes are green.
- Recently completed follow-up: invalid friendly/non-enemy battle-board stack clicks now surface their rejection in the visible battle dispatch instead of returning an invisible signal result, while preserving the current enemy target focus. Focused battle layout coverage clicks the active friendly stack and proves the `Only enemy stacks` rejection reaches the dispatch label without changing selected target state.
- Recently completed follow-up: opening tactical briefing text no longer masks real latest battle dispatch messages, so invalid board-click feedback can surface before the briefing is dismissed. Focused battle layout coverage keeps the briefing cached while clicking the active friendly stack and proves the `Only enemy stacks` rejection reaches the dispatch label without changing selected target state.
- Recently completed follow-up: empty in-board battlefield clicks on non-green movement hexes now route through the existing blocked Move rejection instead of disappearing as silent no-ops, so the visible dispatch can tell the player that the clicked hex is not a legal move destination. Focused battle layout coverage keeps the opening briefing cached, clicks an empty non-green hex, and proves the blocked Move rejection reaches the dispatch label without moving the active stack or changing target focus.
- Recently completed follow-up: empty non-green in-board battlefield hex tooltips now preview the same blocked Move intent that the click dispatches, so pre-click hover text and post-click dispatch feedback agree. Focused battle layout coverage captures the tooltip before the empty non-green hex click and proves it matches the blocked Move rejection.
- Recently completed follow-up: enemy-turn active stack hover text no longer advertises player green-hex or highlighted-enemy actions while input is locked to enemy initiative. The tooltip now matches the visible board-click rejection, and focused battle layout coverage drives the real board mouse path on the active enemy stack.
- Recently completed follow-up: enemy-turn empty hex hover/click feedback now surfaces locked initiative instead of calling those cells green movement input when the active enemy stack could legally move there. Focused battle layout coverage drives the real board mouse path on an empty enemy-turn movement cell and proves the tooltip, click rejection, and movement-intent summaries all avoid green-hex action wording while the player order window is closed.
- Recently completed follow-up: enemy-turn battle-board footer state now surfaces locked input instead of deriving target melee/ranged/blocked labels from the acting enemy stack. Focused battle layout coverage stages an adjacent enemy/player target during enemy initiative and proves the footer stays on `Input locked` while the existing hover/click rejection remains truthful.
- Recently completed follow-up: enemy-turn movement hover can no longer add a `Green:` movement footer label while input is locked. Focused battle layout coverage hovers an enemy-side legal movement cell during enemy initiative and proves the tooltip/preview stay locked while the footer movement affordance stays empty.
- Recently completed follow-up: enemy-turn board fallback tooltips now surface locked input instead of the generic `Green hex` / highlighted-enemy player instructions when the pointer is on board frame space that does not resolve to a hex or stack. Focused battle layout coverage stages enemy initiative, samples an empty fallback tooltip position, and proves it says the player turn is locked without action wording.
- Recently completed follow-up: enemy-turn battle-board attack highlights and validation summaries no longer expose player-click attack affordances from the acting enemy stack. The board presentation still leaves enemy AI legality available to rules, but the player-facing board snapshot locks legal target highlights, selected-target attackability, and board-click wording while input is locked. Focused battle layout coverage stages enemy initiative and proves no legal attack target highlight or board-click message leaks into the board presentation.
- Recently completed follow-up: enemy-turn target-cycle controls no longer advertise cycling legal enemy targets through disabled button tooltips while input is locked. Focused battle layout coverage stages enemy initiative and proves Prev/Next target controls stay disabled with locked-input tooltips and no target-cycling wording.
- Recently completed follow-up: enemy-turn spell action controls no longer advertise player casting buttons while input is locked. `get_spell_actions` now returns no player cast actions unless a player stack is active, and focused battle layout coverage stages enemy initiative and proves the footer spell action row is hidden.
- Recently completed follow-up: enemy-turn Timing tab guidance now uses an enemy-initiative branch instead of reusing player protection timing lines, so it surfaces that the player spell/order windows are closed and avoids player-turn wording such as trading this turn while input is locked. Focused battle layout coverage stages enemy initiative and proves the visible Timing panel plus core timing text stay locked.
- Recently completed follow-up: enemy-turn pressure and opening withdrawal labels now report the retreat/surrender window as closed while the active stack is enemy-side, instead of advertising open withdrawal actions that execution would reject until player initiative returns. Focused battle layout coverage stages enemy initiative with withdrawal generally allowed and proves pressure text says `Window closed` with no `Open` wording.
- Recently completed follow-up: enemy-turn primary command summaries and disabled button tooltips now use explicit input-lock wording instead of generic await text, and selected-target board-click intent now reports locked input without `Board click` wording while the active stack is enemy-side. Focused battle layout coverage stages enemy initiative and proves Advance/Strike/Shoot/Defend/Retreat/Surrender are disabled with not-player-turn summaries; focused core systems smoke is green.
- Recently completed follow-up: enemy-turn Risk board priority guidance no longer tells the player to shift focus while retargeting is locked during enemy initiative. Focused battle layout coverage stages enemy initiative and proves the visible Risk board plus tooltip say retargeting is locked without shift/cycle focus wording; focused core systems smoke is green.
- Recently completed follow-up: battle boards load checked-in generated terrain PNGs from `art/battle/terrain/` when available, with `plains` mapped cleanly to the grass texture and terrain rendering validation tracking texture path, loading, and mapping.
- Recently completed follow-up: AcOrP's manual terrain-alignment finding is addressed by rendering terrain art as clipped per-hex samples instead of a single full-board backdrop, so natural features are snapped to the tactical grid while existing movement/attack highlights, stack tokens, objective markers, turn strip, and footer remain readable. Missing textures fall back to per-hex procedural color/detail rather than a full-field wallpaper. Focused town/battle visual smoke, battle layout smoke, and repo validation are green.
- Recently completed follow-up: AcOrP's post hex-snapped terrain visibility finding is addressed by making the battle grid pass texture-aware: loaded terrain textures now render at full hex coverage with much lighter readability wash, textured cells no longer receive semi-opaque all-cell fills, front/center cues remain as subtle tactical tints, and textured grid borders use a deduplicated single-line path to avoid the double-border look. Missing textures still use the stronger hex-snapped color/detail fallback. Focused town/battle visual smoke, battle layout smoke, and repo validation are green.
- Recently completed follow-up: AcOrP's fresh terrain-sampling diagnosis is addressed by converting each clipped per-hex terrain source sample from texture pixel space into normalized `0..1` UVs before passing it to `draw_polygon`, while preserving the hex-snapped texture path, light tactical tints, cleaned deduplicated borders, and missing-texture procedural fallback. Focused validation now checks UV range and source-sample bounds rather than claiming direct visual proof. Focused town/battle visual smoke, battle layout smoke, and repo validation are green.
- Recently completed follow-up: pre-click battle guidance now surfaces the exact `Strike` or `Shoot` board-click intent for legal selected/hovered enemy targets through compact target context, action guidance, board footer/tooltip text, and validation snapshots; blocked selected targets keep the same explicit board-click contract.
- Recently completed follow-up: legal green movement hexes now surface explicit `Move` board-click intent through the existing board tooltip/footer/action context and validation summaries; blocked selected-target guidance now points to green-hex movement without adding panel clutter. Focused automated validation is green, but live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: legal green movement previews now include exact destination detail with hex and step count, hover/validation snapshots retain the same compact preview, and destinations truthfully call out when a move sets up a later `Strike` on the currently blocked target. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: legal green movement clicks now reuse the same compact preview language for the executed move result, and shell validation returns the same destination detail, step count, preview message, and later-attack setup hint when applicable. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: setup green-hex moves now preserve the blocked selected target after the move when that target remains valid, even when another legal enemy could become the default target. Post-move validation exposes the preserved target, current legality, board-click action/block state, and compact guidance so the UI truthfully reflects whether `Strike`/`Shoot` is now legal or the target remains blocked. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: preserved setup-move targets now surface as preserved setup targets in the immediate post-move action guide, target context, board footer, board validation summary, and move-click validation response. If the preserved target is now legal, the compact state names the `Strike`/`Shoot` board click and keeps the action enabled; if it is still blocked for the immediate active stack, the same compact surfaces say it is still blocked. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: explicit battle retargeting now clears preserved setup-target context instead of letting the old setup target linger as sticky emphasis. Target cycling and board enemy focus use the same target-selection rule path; preserved setup guidance remains only while the preserved target is still the selected context, and focused core/layout validation proves retargeting drops the special action guide, target context, board footer, board emphasis, and continuity key. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: explicit retarget clear is now durable when focus returns to the old setup target without a fresh setup move. Core coverage proves cycling back and direct target selection keep the old target as normal focus with no continuity key or preserved setup wording; layout coverage proves blocked board-click refocus does not restore preserved setup context through compact action guidance, target context, shell snapshots, or board summaries. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: post-clear movement toward the old setup target now has focused regression coverage proving ordinary movement, move-result payloads, post-move target guidance/context, board summaries, and shell validation snapshots stay normal target focus with no preserved setup wording or flags. The same core coverage proves a later fresh setup move can still recreate continuity truthfully. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: ordinary non-setup movement toward a selected blocked target now carries an explicit closing-on-target context through move results, post-move target/action guidance, board validation summaries, board footer state, and shell snapshots without setting preserved setup continuity. Focused regression coverage proves post-clear old-target movement stays ordinary while still communicating closing progress, and that a later fresh setup move clears the ordinary closing context before recreating preserved setup continuity. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: ordinary closing-on-target context now self-clears when it stops being truthful: if the selected target becomes directly attackable, target selection changes, or the active stack changes, compact battle surfaces drop the closing wording/flags and return to the real `Strike`/`Shoot` or blocked-target action state. Focused core and battle-layout regression proves closing appears for ordinary progress moves, then clears through move results, target/action guidance, board summaries/footer state, shell snapshots, and validation payloads. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: ordinary closing movement that immediately turns the same selected blocked target into a directly attackable target now clears the ordinary closing context without converting it into preserved setup continuity, and the move result, target/action guidance, board summary/footer, and shell snapshot surface the normal `board click will Strike` / `Shoot` state right away. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the immediate board-click attack after that direct-actionable post-move state now reports normal attack result payloads and post-attack selected-target/board/shell state, with no stale closing, preserved setup, or direct-actionable-after-move markers. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the same direct-actionable post-move chain is now covered through the normal `Strike`/`Shoot` action-button path. Shell validation preserves the attack result payload plus refreshed selected-target, board, action-guide, and target-context state, and focused coverage proves no stale closing, preserved setup, or direct-actionable-after-move markers remain after the immediate button attack. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: invalidating immediate attacks after the direct-actionable post-move state now settle onto normal post-attack focus. If the original attacked target is destroyed or no longer the selected active focus, post-attack payloads report the handoff, remove post-move transition fields, clear preserved setup and ordinary closing state, and compact board/footer/shell snapshots settle on the surviving normal target. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: invalidating immediate attacks after the direct-actionable post-move state now also cover the branch where the selected-target handoff lands on a newly selected target that is itself directly attackable. Post-attack payloads explicitly mark handoff, direct-actionable handoff, or blocked handoff state; board-click and `Strike`/`Shoot` validation prove compact target/action guidance, board summaries/footer labels, and shell snapshots settle straight onto normal `board click will Strike` / `Shoot` guidance for the new target with no stale closing, preserved setup, direct-actionable-after-move, or invalidation-transition residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: invalidating immediate attacks after the direct-actionable post-move state now also cover the no-selected-handoff branch where the original target is the last enemy and battle resolution clears the active battle. Post-attack result payloads explicitly settle on an empty selected target with no handoff, no direct-actionable target, empty legality/click intent, and no stale closing, preserved setup, direct-actionable-after-move, or post-move transition fields. The blocked replacement handoff core regression now also asserts the no-direct-action blocked-handoff flags, while existing layout coverage keeps the compact blocked-handoff board/footer/shell surfaces green. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: post-attack selected-target handoff now explicitly prefers a surviving directly attackable enemy over an earlier blocked survivor after an immediate post-move attack invalidates the original target. The default target-selection rule uses the active stack's legal attack target order before falling back to the first living enemy, and focused multi-enemy core coverage proves the attack result, selected target, legality, board-click intent, and compact hex summary land on the actionable survivor with no stale closing, preserved setup, or direct-actionable-after-move residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the actionable-preferred post-attack handoff branch now has scene/snapshot-level truthfulness coverage. A battle layout smoke case stages an immediate post-move attack that destroys the original target while an earlier blocked survivor and a later attackable survivor both remain; the shell response, attack result payload, selected-target state, compact board summary/footer, selected board cell, and validation snapshot all land on the attackable survivor with no stale closing, preserved setup, or direct-actionable-after-move residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the same actionable-preferred post-attack handoff branch is now mirrored through the immediate `Strike`/`Shoot` button path. The battle layout smoke restages the blocked-survivor plus attackable-survivor invalidation branch through shell button validation and proves the button response, attack result payload, selected-target state, compact action/target guidance, board summary/footer, selected board cell, and validation snapshot settle on the attackable survivor with no stale closing, preserved setup, or direct-actionable-after-move residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the no-selected-handoff final-kill branch now has scene/snapshot-level truthfulness coverage through both board-click and immediate `Strike`/`Shoot` button attacks after a direct-actionable post-move setup. The battle layout smoke uses isolated shell validation to prove the routed response/result payload, empty selected target, empty legality/click intent, cleared board summary, and empty-battle snapshot contain no stale closing, preserved setup, direct-actionable-after-move, handoff, or selected-target residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the same final-kill branch now has routed-resolution truthfulness coverage with normal battle routing enabled. The battle layout smoke drives both board-click and immediate `Strike`/`Shoot` button final-kill paths through the real `AppRouter` handoff, proves the validation response and immediate shell snapshot expose empty selected-target/battle guidance state, then verifies the routed scene lands on the truthful next state (`OverworldShell` while the scenario remains in progress, or `ScenarioOutcomeShell` if the scenario resolves). Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: immediate post-move final-kill routing now has save/resume-facing truthfulness coverage. The battle layout smoke checks board-click and immediate `Strike`/`Shoot` button final-kill routes through the routed scene, autosave/latest summaries, manual save from that routed scene, and restore semantics. The coverage proves the next resume target is overworld for in-progress sessions or outcome for resolved sessions, with empty battle payloads, no battle resume advertising, no selected-target residue, and outcome routes normalized to an explicit `outcome` game state. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: immediate post-move final-kill routing now also has menu-facing save-browser/latest-surface truthfulness coverage. The battle layout smoke returns routed in-progress and resolved final-kill paths to the main menu after both board-click and `Strike`/`Shoot` button attacks, opens the save browser, and verifies Continue Latest, latest save pulse, latest save row, selected save details, and load action labels advertise overworld resume or outcome review with no battle wording or selected-target residue. Main menu validation snapshots now expose the save-browser labels needed for this proof without changing the player-facing shell. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: immediate post-move final-kill menu action execution now has truthfulness coverage. The battle layout smoke triggers the actual Continue Latest action and the selected save-browser Load action after routed in-progress and resolved final-kill paths, then verifies the executed route lands on overworld resume or outcome review with empty battle payloads, matching session game state, matching routed scene snapshots, and no selected-target/battle guidance residue. Main menu validation now exposes a Continue Latest execution hook and strengthens selected-save resume result payloads for this proof. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: immediate post-move final-kill outcome action execution now has truthfulness coverage. After the resolved routed final-kill branch lands on `ScenarioOutcomeShell`, the battle layout smoke executes the actual outcome Return to Menu action, resumes the outcome again through the real main-menu Continue Latest path, then executes the outcome Retry Skirmish action and verifies the route lands on a clean restarted overworld session with no battle payload or selected-target residue. `ScenarioOutcomeShell` validation now reports the underlying action route and active session truth fields. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.

Execution order:
1. Audit the current River Pass path in the live client.
   - Start from Boot and MainMenu.
   - Launch the scenario through the normal campaign or skirmish surface selected for the milestone.
   - Record the first point where a real player is blocked, confused, misrouted, or forced to know developer-only behavior.
2. Build a parity ledger for River Pass only.
   - overworld launch and objective clarity
   - hero selection and movement
   - fog, map readability, and point-of-interest readability
   - resource pickup and site interaction
   - owned-town entry, construction, recruitment, spell or recovery actions
   - hostile encounter entry
   - battle start, targeting, action clarity, enemy turn handling, and battle end
   - post-battle army sync and overworld return
   - victory condition
   - defeat condition
   - save/resume from overworld
   - save/resume from town
   - save/resume from battle
   - outcome routing and menu return
3. Fix hard blockers before polish.
   - No scenario work counts until the player can route through the basic screens without dead ends.
   - Battle and town UI recovery outrank additional content breadth.
   - Missing affordances outrank extra summaries.
4. Tune the scenario for manual completion.
   - The opening army, accessible reinforcements, first fights, enemy pressure, and victory clock must allow a reasonable first-time player to win.
   - Defeat must remain possible through understandable failure, not through hidden traps or broken routing.
5. Prove save/resume in the same path.
   - Save from overworld, load, continue.
   - Save from town, load, continue.
   - Save from battle, load, continue or resolve.
6. Prove victory and defeat outcomes.
   - Victory routes to a truthful outcome screen.
   - Defeat routes to a truthful outcome screen.
   - Restart, return-to-menu, and save-browser behavior are coherent.
7. Write down any deferred gaps.
   - Gaps can remain only if they do not block a real manual completion.
   - Each deferred gap must have an owner phase.

River Pass acceptance criteria:
- A real player can launch River Pass without editor-only steps.
- The first screen after launch explains objective, threat, and next action through the game UI.
- The overworld map is readable enough to choose where to go.
- Movement, end turn, resource interaction, town entry, encounter entry, and return routing work through visible controls.
- At least one owned town supports useful recruitment or recovery decisions that affect completion.
- At least one battle is entered through normal overworld play and can be resolved with understandable tactical controls.
- The battle UI exposes whose turn it is, legal actions, target selection, expected consequences at a basic level, and the result.
- Post-battle survivors and losses sync back to the overworld state.
- The scenario has one reachable victory condition and one reachable defeat condition.
- Saving and loading from overworld, town, and battle do not corrupt the scenario or strand the player on the wrong surface.
- Victory and defeat outcomes route through the normal outcome/menu flow.
- The scenario can be completed manually at least twice from a clean profile, with notes captured for remaining friction.

Exit gate:
- Do not begin Phase 2 until River Pass can be completed manually end-to-end and the blockers are documented or fixed.

## Phase 2: Playable Alpha Baseline
Status: active; River Pass gate has passed, and the first six-faction scaffold slice has started.

Purpose:
- Convert the single-scenario proof into a small playable alpha with real strategy loops.
- Deepen playable faction vertical slices while the broader six-faction content scaffold matures under validation.

Scope:
- At least two deeply proven factions with distinct town, unit, hero, spell, battle, AI, and scenario identities before the alpha baseline can be called playable.
- Six target factions may exist as scaffolded content, but no faction counts as complete until scenario placement, AI behavior, save/load, and manual play prove the loop.
- Usable town, battle, and overworld UX.
- Deeper units, spells, artifacts, map objects, hero growth, neutral encounters, and scenario scripting.
- A small set of manually playable scenarios, not a broad campaign promise.

Execution order:
1. Keep the six-faction scaffold honest with content validation and no playability claims.
2. Select the first deep-play alpha faction pair or trio from the scaffold and freeze their implementation order.
3. Define the alpha content matrix:
   - unit tiers
   - town buildings
   - recruit economy
   - hero roles
   - spells
   - artifacts
   - map objects
   - neutral encounters
   - faction-specific battle hooks
4. Repair overworld UX around the alpha loop.
   - map readability
   - movement and pathing
   - fog/scouting
   - site affordances
   - threat surfacing
   - end-turn clarity
5. Repair town UX around the alpha loop.
   - build decisions
   - recruitment
   - garrison and transfer
   - spell learning where present
   - economy and affordability
   - town defense clarity
6. Repair battle UX around the alpha loop.
   - deployment and initiative clarity
   - stack identity
   - targeting
   - retaliation/ranged/melee expectations
   - spell and ability availability
   - win/loss consequences
7. Build 3-5 alpha scenarios that can be manually completed.
8. Add AI enough to contest the alpha scenarios without relying on scripted pressure only.
9. Stabilize save/load across alpha loops.
10. Run manual play passes, then add automated coverage for the issues found manually.

Acceptance criteria:
- Two factions are playable with distinct town, unit, hero, spell, and battle identities.
- A player can complete multiple scenarios without developer guidance.
- Town, battle, and overworld screens are usable at the default target resolution.
- Save/load is reliable across normal alpha behavior.
- The content pipeline catches missing ids, invalid references, impossible starts, and broken objective wiring.
- AI can take turns, contest objectives, and resolve battles without routine dead ends.

## Phase 3: Production Alpha Layer
Status: future.

Purpose:
- Make the alpha suitable for external playtest, not release.
- Replace roughest placeholder gaps with coherent placeholder art/audio and production packaging basics.

Execution order:
1. Establish an external playtest checklist.
2. Add or replace placeholder art so all primary screens have coherent original visual language.
3. Add placeholder audio coverage:
   - menu ambience
   - button/UI feedback
   - overworld movement or interaction cues
   - battle action cues
   - victory/defeat cues
4. Stabilize settings:
   - display/window mode
   - audio volume
   - accessibility basics
   - input affordances
5. Build export pipeline.
   - repeatable desktop export
   - version stamping
   - clean user data behavior
   - crash/log collection path
6. Add playtest telemetry or local report hooks where practical.
7. Create onboarding sufficient for first external players.
8. Run external playtest candidate builds and triage.

Acceptance criteria:
- A non-developer can install or run an exported build.
- The game has coherent placeholder art/audio instead of debug presentation.
- Settings persist and affect the live client.
- Logs and reports are usable for debugging playtest issues.
- Known blockers are tracked before wider playtest.

## Phase 4: HoMM2-Class Breadth
Status: future product horizon.

Purpose:
- Reach a broad, original fantasy strategy game package comparable in systemic breadth to the Heroes II era while remaining legally distinct.

Scope targets:
- Multiple original factions beyond the manually proven alpha subset, with the six-faction scaffold as the target breadth source.
- A meaningful roster of heroes, units, towns, spells, artifacts, neutral creatures, map objects, and handcrafted maps.
- Campaign framework with several completable chapters.
- Skirmish setup with meaningful map and faction choice.
- AI that can operate adventure and battle loops across broader content.

Execution order:
1. Expand playable faction count only after alpha loops remain stable; scaffold records alone do not satisfy this phase.
2. Add content in vertical bundles, not isolated JSON dumps.
   - faction data
   - town data
   - unit data
   - hero data
   - spells/artifacts
   - encounters
   - map/scenario placement
   - AI tuning
   - manual play pass
3. Build HoMM2-class map object variety.
4. Build campaign chapter chains only after single-map completion stays reliable.
5. Balance resources, recruitment pacing, battle difficulty, and AI pressure across the content set.
6. Harden save compatibility and migration.
7. Maintain a parity ledger comparing target breadth versus live playable breadth.

Acceptance criteria:
- Breadth is playable, not just authored.
- Multiple factions support complete town, battle, overworld, and AI loops.
- Campaign and skirmish content can be completed manually.
- Automated validation covers content graph integrity and previously discovered live-client regressions.

## Phase 5: HoMM3-Class Breadth
Status: late future product horizon.

Purpose:
- Expand from HoMM2-class breadth into deeper strategic density associated with Heroes III while keeping the game original.

Scope targets:
- More factions and stronger faction asymmetry.
- Richer hero progression and specialties.
- Larger spell and artifact ecosystems.
- More map objects, object chains, and scripted scenario structures.
- More sophisticated AI pressure and campaign pacing.
- Better balance tooling, QA workflow, accessibility, audio, visual polish, and packaging maturity.

Execution order:
1. Freeze the HoMM2-class baseline before adding HoMM3-class density.
2. Identify which HoMM3-like systems genuinely improve this original game rather than adding complexity for parity theater.
3. Expand one depth layer at a time:
   - hero progression
   - artifacts
   - magic
   - map objects
   - faction mechanics
   - AI
   - campaign scripting
4. Re-run manual play and automated validation after each layer.
5. Balance for readability and player agency.

Acceptance criteria:
- Added depth creates better strategic choices, not just more lists.
- Existing scenarios and saves survive added density or migrate clearly.
- The game remains understandable to new players.
- Parity claims are backed by playable breadth and manual evidence.

## Immediate Execution Order
1. Complete the documentation reset.
2. Run the current validation baseline enough to know whether docs-only changes kept the repo structurally intact.
3. Start the River Pass manual audit from the live client.
4. Record the River Pass parity ledger.
5. Fix launch and routing blockers.
6. Fix battle usability blockers.
7. Fix town usability blockers.
8. Fix overworld objective, map, movement, and end-turn clarity blockers.
9. Tune River Pass for one fair victory path.
10. Add or repair one fair defeat path.
11. Prove save/resume from overworld.
12. Prove save/resume from town.
13. Prove save/resume from battle.
14. Prove victory outcome routing.
15. Prove defeat outcome routing.
16. Repeat a clean manual completion pass and record notes.
17. Only then select Phase 2 alpha scope.

## Parity Ledger Template
Use this structure for each target system or content claim:

- Claim:
- Current implementation:
- Live-client usability:
- Manual-play evidence:
- Automated coverage:
- Known blockers:
- Phase owner:
- Acceptance gate:

No claim should move to "done" unless live-client usability and evidence are filled in.

## Current Acceptance Target
Current target: River Pass manually completable by a real player.

Done means:
- A clean-profile manual player can start River Pass, understand what to do, make meaningful overworld/town/battle decisions, save/resume, and reach victory.
- The same scenario can also reach a coherent defeat.
- The result is not dependent on editor setup, hidden debug controls, or knowledge of internal ids.
- Remaining gaps are documented as alpha gaps, not hidden behind completed language.
