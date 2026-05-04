# heroes-like Tactical Implementation Plan

Task: #10184
Document role: tactical execution plan
Source strategy: `project.md`
Reset date: 2026-04-27
Compacted date: 2026-05-03
Operational tracker: `ops/progress.json`

## Purpose

This plan turns `project.md` into executable work slices. It is not a history log, worker diary, evidence dump, or progress tracker.

Rules:
- Keep strategy in `project.md`.
- Keep detailed requirements, audits, and evidence in `docs/*.md` or `.artifacts/*`.
- Keep current state, completion evidence, worker notes, and validation records in `ops/progress.json`.
- A slice is complete only when implementation/content/tooling changes satisfy its referenced requirements and validation gates.
- Documentation-only and report-only work must stay distinct from implemented gameplay/system/content completion.
- Do not continue ad hoc UI cue/performance/content work unless it is selected here and tracked in `ops/progress.json`.

## Current Tactical State

Current phase: **Phase 2 - Deep Production Foundation**.

Current tactical chain: continue the native C++ GDExtension RMG parity track until
it reaches full parity with `scripts/core/RandomMapGeneratorRules.gd` for the
tracked supported profiles before any gameplay call-site adoption. The current
completed native children cover deterministic identity, terrain/grid output,
foundation zone/player-start output, foundation road/river network output,
foundation non-town object placement output, foundation town/guard placement
output, native validation/provenance reporting, and a focused GDScript/native
comparison harness, and feature-gated package/session adoption records for native
output. `native-rmg-full-parity-gate-10184` closes the tracked gate for the
current 36x36 `homm3_small` comparison fixtures while keeping unsupported native
configs explicitly `partial_foundation`.

Do not infer product readiness from the completed queue. Completed Phase 2/RMG/performance/tooling evidence means those specific slices passed their gates; it does not mean playable alpha, campaign breadth, release readiness, broad faction completion, asset parity, or HoMM3 byte-level cloning.

Persistent guardrail: do not import generated PNGs or generated-study derivatives into runtime/source assets until a later AcOrP-approved ingestion slice records provenance, import paths, rollback, and validation.

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
3. Confirm the selected slice has source docs, implementation targets, validation, completion criteria, and forbidden-scope boundaries.
4. Mark the selected slice `in_progress` in `ops/progress.json`.
5. On completion, record validation/evidence in `ops/progress.json`; do not paste the evidence block into this file.

If a requested task is not represented by a valid slice, first add or reconcile a compact slice entry. Do not invent untracked ad hoc implementation work.

## Phase Roadmap

### Phase 0 - Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

Closed tactical slices:
- `document-model-reset-10184`
- `progress-tracker-regeneration-10184`

Future work in this phase should be limited to document/process corrections that preserve the `project.md` -> `PLAN.md` -> `ops/progress.json` chain.

### Phase 1 - Manual Scenario Proof

Goal: preserve the manually proven River Pass loop without overstating product readiness.

Closed tactical slice:
- `river-pass-proof-preservation-10184`

Future work in this phase should only reopen if manual proof is invalidated by regressions or if AcOrP requests a new proof scenario.

### Phase 2 - Deep Production Foundation

Goal: build the foundation needed before broad campaign/skirmish production or final polish.

Primary tracks:
- world and faction identity;
- concept-art direction and curation;
- economy/resource model;
- overworld object taxonomy and encounter representation;
- magic and artifact systems;
- animation/event cue foundations;
- strategic AI foundations;
- terrain/editor/tooling foundations;
- random map generator foundations;
- map/scenario document structure and persistence foundations;
- focused corrective/performance/instrumentation slices selected from real evidence.

Operational state lives in `ops/progress.json`. Completed parent/child evidence is intentionally not repeated here.

Selection rules for new Phase 2 slices:
- Tie the slice to a source doc, owner report, profile artifact, regression, or explicit AcOrP direction.
- Keep implementation targets narrow.
- Include explicit non-goals for save schema, generated-map density/content, renderer/fog behavior, object contracts, public UI, and asset ingestion when relevant.
- Preserve existing validation/analyzer compatibility unless the slice explicitly changes it.
- Do not use profile/instrumentation slices as permission for optimization or gameplay semantics changes.

Completed owner-directed corrective slice:

id: `native-scenario-active-content-reset-10184`
phase: `phase-2-deep-production-foundation`
purpose: Archive the current native/authored scenario and campaign catalogs out of active player-facing selection while preserving generated random-map skirmish flow and historical compatibility records.
sourceDocs:
- `project.md`
- 2026-05-03 owner direction to clear native scenarios
implementationTargets:
- `content/scenarios.json`
- `content/campaigns.json`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/core/CampaignRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/random_map_scenario_load_smoke.gd`
completionCriteria:
- Authored/native scenario and campaign domains are marked archived/disabled.
- Skirmish and campaign browsers expose zero native authored entries.
- Generated random-map skirmish setup/load remains available and validated.
nonGoals:
- No RMG rewrite.
- No map package adoption.
- No save schema/version bump.
- No renderer, fog, pathing, gameplay, or asset-ingestion redesign.

Completed owner-directed implementation slice:

id: `native-rmg-disk-package-startup-10184`
phase: `phase-2-deep-production-foundation`
purpose: Make generated skirmish startup use native RMG package documents saved under `maps/` and loaded back from disk instead of authored `content/scenarios.json` or transient generated JSON scenario drafts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to remove JSON scenario startup and use native RMG packages under `maps/`
implementationTargets:
- `src/gdextension/include/map_document.hpp`
- `src/gdextension/src/map_document.cpp`
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/persistence/NativeRandomMapPackageSessionBridge.gd`
- `scenes/menus/MainMenu.gd`
- `tests/native_random_map_disk_package_startup_report.gd`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Native `MapPackageService` saves and loads generated map and scenario packages enough for generated startup.
- Generated skirmish setup writes `.amap` and `.ascenario` packages under `maps/` in dev/headless and loads them back before session creation.
- Generated startup does not use `ContentService` generated drafts or `content/scenarios.json` as the active launch source.
- Maps directory policy is documented for dev `res://maps` and exported `user://maps` semantics.
- Focused Godot smoke proves native load, generation, package save, package load, disk-backed startup, and no active `scenarios.json`/draft usage.
nonGoals:
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump or full `SessionDelta` rewrite.
- No renderer, fog, pathing, or broad gameplay redesign.
- No generated PNG or unrelated asset import.

Completed owner-directed corrective slice:

id: `native-rmg-package-readable-filenames-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace opaque generated native RMG disk package filenames with deterministic, filesystem-safe, human-readable paired names under `maps/`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner feedback that native RMG package filenames were dull/debug-sludge
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_disk_package_startup_report.gd`
- `tests/native_random_map_package_session_adoption_report.gd`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Generated native RMG `.amap` and `.ascenario` packages share a readable deterministic base stem.
- The stem uses `size-creative-name-hash` only, with a user-facing size token, a deterministic creative lowercase kebab name derived from normalized seed/config, and an 8-hex deterministic config hash suffix.
- Template/profile/player-count/water-mode/dimensions/hash details stay in package metadata/refs, not the filename.
- Focused native disk-package startup tests assert the corrected shape, reject old debug-name identity parts, and prove package refs/load behavior still work.
nonGoals:
- No native API, C++ document, save-version, authored catalog, renderer, fog, pathing, or gameplay semantics changes.

Completed owner-directed implementation slice:

id: `maps-folder-package-browser-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Populate skirmish and map editor selection flows from generated `.amap`/`.ascenario` package pairs under `maps/` instead of authored JSON scenario records.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to populate skirmish and map editor from generated maps-folder packages
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/persistence/NativeRandomMapPackageSessionBridge.gd`
- `scenes/menus/MainMenu.gd`
- `scenes/editor/MapEditorShell.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
completionCriteria:
- A generated maps-folder package index discovers paired `.amap`/`.ascenario` files under the active maps directory and returns readable records with package refs/metadata.
- Skirmish browser entries are built from generated disk package pairs, handle an empty maps folder gracefully, and start sessions by loading the selected package paths.
- Map editor can list and open generated package pairs from `maps/` without `content/scenarios.json` or transient generated draft registration.
- Focused Godot smoke proves package listing, package-backed skirmish launch, map editor package access/open, sane empty-directory behavior, and no authored JSON scenario path for generated package launch/open.
nonGoals:
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump.
- No renderer, fog, pathing, gameplay, or RMG generation semantics changes.
- No generated PNG or unrelated asset import.

Completed owner-directed corrective slice:

id: `map-editor-load-map-package-ui-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace the Map Editor's active old JSON scenario dropdown path with an explicit Load Map flow backed only by generated `.amap`/`.ascenario` package pairs under `maps/`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to make the map editor load maps from maps-folder packages instead of old JSON scenarios
implementationTargets:
- `scenes/editor/MapEditorShell.gd`
- `scenes/editor/MapEditorShell.tscn`
- `tests/map_editor_load_map_package_report.gd`
- `tests/map_editor_load_map_package_report.tscn`
- `tests/validate_repo.py`
completionCriteria:
- The active Map Editor top-bar flow says `Load Map` and lists generated map package entries from `maps/`.
- The active editor load path uses paired `.amap`/`.ascenario` refs and paths, and creates a package-backed editor working copy.
- Old authored JSON scenario loading is removed from the active editor UI and kept only behind explicit legacy/dev validation naming.
- Empty, invalid-pair, and failed-load states use map-package copy rather than scenario-dropdown copy.
- Focused Godot smoke proves package entries, package refs/paths, no authored JSON scenario/draft registration, and no old scenario dropdown copy in the active flow.
nonGoals:
- No skirmish browser behavior change beyond preserving the shared maps-folder package helper.
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump.
- No renderer, fog, pathing, gameplay, RMG generation, or asset-ingestion changes.

Completed owner-directed implementation slice:

id: `generated-grastl-runtime-terrain-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Wire the committed generated `grastl` grass terrain replacement frames into the overworld terrain runtime path instead of leaving them unused.
sourceDocs:
- `project.md`
- `PLAN.md`
- `art/overworld/runtime/terrain_tiles/generated/grastl/README.md`
- 2026-05-03 owner directive to load/use generated grastl frames under `art/overworld/runtime/terrain_tiles/generated/grastl/frames_64/`
implementationTargets:
- `content/terrain_grammar.json`
- `scripts/autoload/ContentService.gd`
- `art/overworld/manifest.json`
- `scenes/overworld/OverworldMapView.gd`
- `tests/generated_grastl_runtime_asset_report.gd`
- `tests/generated_grastl_runtime_asset_report.tscn`
- `tests/overworld_visual_smoke.gd`
- `tests/validate_repo.py`
completionCriteria:
- Grass/grastl terrain runtime asset resolution points at the generated `frames_64` resource directory.
- The overworld map view can resolve generated grastl frame paths while preserving existing terrain selection behavior for other atlases and roads.
- Godot import sidecars exist for the 79 generated grastl frame PNGs.
- Focused validation proves all 79 generated frame resources exist/load and a runtime grass tile resolves through the generated grastl frame bank.
validation:
- `godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/generated_grastl_runtime_asset_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No terrain placement, pathing, fog, save schema, RMG, editor paint semantics, road rendering, or non-grass terrain atlas redesign.
- No new generated asset ingestion beyond the already committed grastl `frames_64` replacement trial frames.

Selected owner-directed workflow slice:

id: `generated-terrain-classes-runtime-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add the tracked workflow and deterministic scaffolding needed to generate original replacement runtime terrain tiles for every remaining terrain class after `grastl`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/generated-terrain-class-replacement-workflow.md`
- `art/overworld/runtime/terrain_tiles/generated/grastl/README.md`
- 2026-05-04 owner directive to continue the grastl workflow for `dirttl`, `lavatl`, `rocktl`, `rougtl`, `sandtl`, `snowtl`, `subbtl`, `swmptl`, and `watrtl`
implementationTargets:
- `docs/generated-terrain-class-replacement-workflow.md`
- `tools/generated_terrain_atlas_tool.py`
- `art/overworld/runtime/terrain_tiles/generated/<class>/source_sheets/`
- `art/overworld/runtime/terrain_tiles/generated/<class>/previews/`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- A new tracked child slice exists for the remaining generated terrain class replacement workflow and is active in `ops/progress.json`.
- The workflow explicitly lists `dirttl` 46, `lavatl` 79, `rocktl` 48, `rougtl` 79, `sandtl` 24, `snowtl` 79, `subbtl` 79, `swmptl` 79, and `watrtl` 33.
- Deterministic tooling can pack original reference frames into 1024x1024 16x16 magenta-padded atlases, validate/cut later generated 1024 atlases into exact 64x64 class frames, force unused cells to magenta, and produce previews without calling image generation.
- Repo-owned original reference 1024 atlases and previews exist for every listed remaining class.
- Validation includes JSON validation, reference pack dry-run/generation, script syntax validation, `sync-plan` dry-run when available, and `git diff --check`.
validation:
- `python3 tools/generated_terrain_atlas_tool.py pack-reference --all --dry-run`
- `python3 tools/generated_terrain_atlas_tool.py pack-reference --all --force`
- `python3 -m py_compile tools/generated_terrain_atlas_tool.py`
- `python3 -m json.tool ops/progress.json`
- `python3 tests/validate_repo.py`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan --dry-run /root/dev/heroes-like`
- `git diff --check`
nonGoals:
- No image generation calls from this worker or repo tooling.
- No runtime replacement frame ingestion for non-`grastl` terrain classes until generated candidates exist and pass validation.
- No terrain placement, pathing, fog, save schema, RMG, editor paint semantics, road rendering, or unrelated renderer redesign.

Selected Phase 2 corrective slice:

id: `native-gdextension-editor-manifest-correction-10184`
phase: `phase-2-deep-production-foundation`
purpose: Fix GDExtension library feature selection so Godot editor/headless smokes load the native Debug library on Linux and Windows instead of falling back to the GDScript compatibility shim.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner report that Windows Godot 4.6.2 headless selects `windows.editor.x86_64`
implementationTargets:
- `src/gdextension/map_persistence.gdextension`
- `src/gdextension/map_persistence.gdextension.in`
- `src/gdextension/README.md`
- `scripts/build_map_persistence_windows.bat`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Linux and Windows editor/headless manifest entries point to the Debug native library.
- Existing debug/release template entries remain intact for export/template builds.
- Windows helper/docs explain that headless/editor smokes use the editor entry and Debug-only builds are sufficient for smokes.
- Linux native rebuild plus native package and RMG smokes still load the native extension.
nonGoals:
- No native API, RMG, gameplay, save, content, package, renderer, fog, pathing, or adoption semantics changes.
- No unsupported macOS library paths.

Selected Phase 2 planning slice:

id: `map-scenario-gdextension-persistence-foundation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace the current loose JSON/dictionary map and scenario persistence model with a planned typed map/scenario document architecture, likely backed by a C++ Godot GDExtension, before broad generated-map or scenario production depends on it.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner direction and RMG/save-path inspection
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd` generation/export boundary
- `scripts/core/ScenarioSelectRules.gd` generated-skirmish setup boundary
- `scripts/core/ScenarioFactory.gd` scenario/session bootstrap adapters
- `scripts/core/SessionStateStore.gd` session save reference/delta boundary
- `scripts/autoload/ContentService.gd` authored/generated scenario loading boundary
- `scripts/autoload/SaveService.gd` save/load JSON hot path
- `content/scenarios.json` split/manifest migration plan
- future `src/gdextension` or equivalent C++ map package module
baselineChecks:
- `python3 tests/validate_repo.py`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run`
- focused generated-map save/load, scenario-load, and RMG validation smokes selected at kickoff
sliceEvidence:
- Current RMG returns nested Dictionary payloads with `scenario_record`, `metadata`, `staging`, validation, and provenance instead of a typed map object.
- Generated skirmish sessions are memory/session-oriented and preserve no-authored-writeback boundaries rather than producing durable first-class map assets.
- Authored scenarios are bundled in large JSON content records under `content/scenarios.json`.
- `SaveService._save_raw_dictionary()` serializes full save payloads with `JSON.stringify(payload, "\t")` and writes raw JSON strings through `FileAccess`.
- A Small 36x36 generated-map profile wrote about 6.95 MB JSON and took roughly 202-219 ms in the save path, so larger generated maps will amplify the problem.
completionCriteria:
- A typed map/scenario document model is defined with stable ids, schema/version, metadata, terrain/layers, object placements, route/validation data, and generated provenance boundaries.
- A durable map package approach is selected for authored and generated maps, including load, validate, save, migrate, and corruption/tamper handling.
- Runtime saves are redesigned to reference immutable map packages by id/hash/version and store only mutable session deltas where practical.
- `content/scenarios.json` has a migration plan toward an index/manifest plus separate map/scenario package files.
- RMG bridge/export sequencing is defined so existing GDScript generation can emit/import the new format before any full C++ generator rewrite is attempted.
- Backward compatibility, rollback, validation scenes, and performance acceptance gates are named before implementation starts.
nonGoals:
- No immediate coding or coding-agent implementation during planning refinement.
- No breaking existing saves or authored scenarios without an explicit migration slice.
- No full RMG rewrite as the first step.
- No renderer/fog/pathing/gameplay semantics changes unless separately selected.
- No production content migration without provenance, rollback, and validation evidence.

Selected Phase 2 child implementation slice:

id: `native-rmg-gdextension-foundation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Start the native RMG port as a narrow C++ GDExtension foundation: API surface, deterministic minimal config/seed identity, and an empty generated `MapDocument` smoke result.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner direction to begin the native RMG port without gameplay adoption
implementationTargets:
- `src/gdextension/include/map_package_service.hpp`
- `src/gdextension/src/map_package_service.cpp`
- `scripts/persistence/MapPackageService.gd`
- `tests/native_random_map_foundation_report.gd`
- `tests/native_random_map_foundation_report.tscn`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Native API exposes minimal random-map config normalization, deterministic config identity, and `generate_random_map(config)` foundation behavior.
- Same config/seed produces the same identity and changed seed changes identity.
- Returned generation status is explicitly `partial_foundation` with full generation `not_implemented`.
- Existing GDScript RMG runtime flow remains authoritative and untouched.
- Existing native map package smoke and new native RMG foundation smoke pass after Linux native rebuild.
nonGoals:
- No full RMG rewrite.
- No `RandomMapGeneratorRules.gd` call-site replacement.
- No `ScenarioSelectRules.gd` runtime generation flow change.
- No package adoption, save version bump, authored content migration, generated authored writeback, renderer/fog/pathing/gameplay semantic change, or fake parity claim.

Native RMG parity track:

The native C++ GDExtension RMG must reach functional parity with the current GDScript source of truth in `scripts/core/RandomMapGeneratorRules.gd` before any gameplay adoption. The practical breakdown is:

- `native-rmg-terrain-grid-generation-10184`: deterministic normalized config, terrain/biome palette, width/height/level tile grid, terrain ids/codes, stable signatures, and terrain-grid smoke while preserving `partial_foundation`.
- `native-rmg-zone-player-starts-10184`: deterministic foundation player constraints, assignment metadata, runtime fallback zones, zone seed layout, owner grid, zone bounds/terrain association, start anchors, start spacing metadata, and status/signature reporting.
- `native-rmg-road-river-network-10184`: route/corridor graph, road overlays, river/water/underground transit records, and reachability proof surfaces.
- `native-rmg-object-placement-foundation-10184`: resource/reward/decor/object staging, footprint predicates, occupancy, and deterministic object placement records.
- `native-rmg-town-guard-placement-10184`: primary/neutral towns, mines, dwellings, route guards, border guards, monster/reward bands, and guard pressure records.
- `native-rmg-validation-provenance-parity-10184`: validation reports, phase pipeline, stable signatures, generated provenance, no-authored-write policy, and warning/failure parity.
- `native-rmg-gdscript-comparison-harness-10184`: headless comparison fixtures proving native/GDScript structural parity across supported seeds, sizes, water modes, underground, and player counts.
- `native-rmg-package-session-adoption-10184`: package/session integration behind explicit feature-gated adapters for native output; no save version bump or call-site replacement.
- `native-rmg-full-parity-gate-10184`: final tracked gate proving terrain, objects, roads, rivers, towns, guards, zones/player starts, validation/provenance, comparison harness, package/session integration, Linux, and Windows for the supported 36x36 `homm3_small` comparison profiles before any runtime call-site adoption.

With `native-rmg-full-parity-gate-10184` complete, native RMG may claim full
parity only for the supported tracked comparison profiles. Unsupported native
configs remain incomplete, and `RandomMapGeneratorRules.gd` remains
authoritative for live generated skirmish gameplay until a later explicit
runtime adoption slice changes the call sites.

Known Phase 2 parent tracks already represented in progress history:
- `world-faction-identity-implementation-bridge-10184`
- `concept-art-curation-gate-10184`
- `economy-resource-foundation-implementation-10184`
- `overworld-object-encounter-foundation-implementation-10184`
- `magic-system-foundation-implementation-10184`
- `artifact-system-foundation-implementation-10184`
- `animation-event-cue-foundation-implementation-10184`
- `strategic-ai-foundation-continuation-10184`
- `terrain-editor-tooling-foundation-implementation-10184`
- `random-map-generator-foundation-10184`
- `map-scenario-gdextension-persistence-foundation-10184`

Selected owner-directed corrective slice:

id: `random-map-homm3-parity-richness-corrective-10184`
phase: `phase-2-deep-production-foundation`
purpose: Re-audit generated-map output against owner-visible HoMM3-style RMG expectations and improve concrete generated-map richness where maps still look sparse or structurally wrong.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `docs/random-map-final-homm3-parity-regate-audit.md`
- `docs/random-map-xl-template-alignment-audit.md`
- 2026-05-04 owner directive that generated maps are still not close enough to HoMM3-style RMG
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- focused RMG report/test scenes under `tests/`
- `.artifacts/` generated-map inspection reports/previews when practical
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Multiple deterministic generated-map seeds/templates/sizes are inspected with human-readable evidence.
- Generated maps enforce stronger town spacing/zone placement constraints.
- Roads, rivers where terrain/template policy supports them, movement-shaping blockers/decorations, artifacts/rewards, and guards are generated at visible HoMM3-style densities.
- Validation checks road/river presence or explicit unsupported policy, minimum town distance, blocker/decor density, artifact and guard counts/association, template richness metrics, and native/package startup regressions.
- Remaining parity gaps are explicitly tracked as follow-up instead of being hidden behind a parity claim.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, or broad renderer/fog/pathing redesign unless required by focused validation.
knownFollowUp:
- `translated_rmg_template_002_v1` remains a poor/failing translated template under 72x72 inspection because start viability and decoration route-blocking constraints fail; track a separate template-structure corrective before using it as positive parity evidence.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-bounded-inspection-footprints-10184`
phase: `phase-2-deep-production-foundation`
purpose: Make the HoMM3-style RMG richness inspection reliable in headless runs and improve generated-map blocker footprint parity using real HoMM3 RMG object/passability evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- 2026-05-04 owner directive to continue RMG parity after `fa45218`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/` generated-map inspection previews/reports
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The richness report runs bounded multi-map headless inspections and exits with clear JSON/report output.
- Multiple deterministic seeds/templates include roads, river/water candidates, town spacing, artifacts, guards, decorative blocker density, multi-tile blocker footprint, and object writeout metrics.
- Decorative obstacles use terrain-family passability/body masks instead of all blockers being one-tile placeholders, while route safety remains validated.
- Generated inspection artifacts are written under ignored repo `.artifacts/` or workspace artifacts, not untracked `maps/`.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

### Phase 3 - Headless AI Agent Balance Harness

Goal: create non-graphical agent/test loops for scenarios, AI turns, economy, battles, balance checks, save/load, and regression detection.

Closed tactical slices:
- `headless-agent-simulation-harness-10184`
- `balance-regression-report-suite-10184`

Future work should be selected only when new gameplay/content systems need harness coverage or balance evidence.

### Phase 4 - Playable Alpha Baseline

Goal: a small coherent alpha that can be played repeatedly without developer interpretation.

Paused tactical slices:

id: `playable-alpha-scenario-set-10184`
phase: `phase-4-playable-alpha-baseline`
purpose: Build a small validated scenario/skirmish set after Phase 2 foundations are deliberately selected for alpha assembly.
sourceDocs:
- `project.md`
- relevant scenario, faction, economy, AI, town, battle, and RMG docs selected at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused Godot smoke/regression scenes selected at kickoff
completionCriteria:
- Multiple setups can be started, played, saved/resumed, won/lost, and understood without developer interpretation.
- At least two factions have enough live distinction to support repeated play.
nonGoals:
- No release claim.
- No content-breadth claim based only on JSON volume.

id: `playable-alpha-ux-onboarding-10184`
phase: `phase-4-playable-alpha-baseline`
purpose: Make the selected alpha setups understandable through compact player-facing UX rather than debug/report panels.
sourceDocs:
- `project.md`
- selected UX/onboarding docs or audit produced at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused UI smoke/regression scenes selected at kickoff
completionCriteria:
- New/returning players can launch, choose setup, understand objectives, read core controls, and recover from common mistakes.
- Debug/profile/report surfaces stay optional and non-primary.
nonGoals:
- No giant dashboard substitution for missing mechanics.
- No broad polish pass outside selected alpha paths.

### Phase 5 - Production Alpha Layer

Goal: expand the playable alpha into a production-shaped game slice.

Paused tactical slices:

id: `production-alpha-content-expansion-10184`
phase: `phase-5-production-alpha-layer`
purpose: Add more factions/content through established systems and validation gates.
sourceDocs:
- `project.md`
- content/faction/scenario docs selected at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused content/schema/smoke checks selected at kickoff
completionCriteria:
- New content enters live play through validated mechanics, AI, economy, scenario, save/load, and UI surfaces.
nonGoals:
- No raw content dump.
- No unvalidated asset ingestion.

id: `production-alpha-packaging-settings-performance-10184`
phase: `phase-5-production-alpha-layer`
purpose: Establish packaging, settings, accessibility, and performance requirements for a production alpha.
sourceDocs:
- `project.md`
- selected packaging/settings/accessibility/performance docs or audits
baselineChecks:
- `python3 tests/validate_repo.py`
- platform/performance checks selected at kickoff
completionCriteria:
- Required settings, accessibility boundaries, performance budgets, and packaging targets are explicit and validated for the selected alpha scope.
nonGoals:
- No release readiness claim.
- No platform promise without tested artifact evidence.

### Phase 6 - Broad Production Breadth

Goal: broaden into a full original fantasy strategy package after alpha foundations hold.

Long-horizon tracks:
- broad faction/town/unit/content breadth;
- broader map, campaign, skirmish, and replayability breadth;
- deeper AI/balance/polish/content pipeline maturity.

Do not reopen Phase 6 work until Phase 4/5 evidence supports it or AcOrP explicitly changes priorities.

## Progress Reconciliation

Use this after PLAN/progress changes:

```bash
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like
```

Expected shape after this compaction:
- PLAN contains compact tactical gates and future selectable slices.
- Completed implementation/report evidence remains in `ops/progress.json` and `docs/*.md`.
- `sync-plan --dry-run` should report only PLAN ids that already exist in active progress entries.
