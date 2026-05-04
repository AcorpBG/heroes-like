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
current tiny comparison fixtures only. `native-rmg-catalog-playability-wiring-10184`
then corrects the exposed-template fallback path so native package generation
uses imported catalog topology broadly enough for playable generated maps across
the menu catalog, while exact HoMM3-re byte/placement/art/reward-table parity
remains outside the current claim.

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

Completed owner-directed implementation slice:

id: `decorative-blocker-distinct-sprite-assets-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Follow up the decorative/blocker sprite foundation by replacing shared archetype reuse with one distinct generated sprite asset per authored decorative/blocker object while preserving the renderer/generator wiring and no-HoMM3-art boundary.
sourceDocs:
- `project.md`
- `PLAN.md`
- `art/overworld/decorative_object_sprites.json`
- owner correction on 2026-05-04 that all decorative/blocker objects need distinct assets, not only archetype coverage
implementationTargets:
- `art/overworld/runtime/objects/decorations/distinct/`
- `art/overworld/source/generated/decorations/distinct/`
- `art/overworld/source/trimmed/decorations/distinct/`
- `art/overworld/manifest.json`
- `art/overworld/decorative_object_sprites.json`
- `tests/validate_repo.py`
- `tests/overworld_decorative_sprite_asset_report.gd`
- `ops/progress.json`
completionCriteria:
- Exactly 200 authored decorative/blocker objects resolve to 200 distinct object asset ids.
- The 16 existing generated decoration sprites are preserved for 16 representative objects and the remaining 184 objects receive newly generated original sprites.
- Each distinct runtime sprite has source/provenance, manifest entry, trimmed source where applicable, and 512x512 runtime validation.
- Validation rejects asset reuse in the decorative/blocker object mapping and proves at least one generated decorative placement renders through a distinct object-specific sprite.
- No HoMM3 copyrighted art/DEF/image assets are imported.
nonGoals:
- No save-version bump, no binary map-package schema migration, no exact HoMM3 asset/DEF parity claim, no terrain replacement, no broad gameplay rebalance.

Completed owner-directed implementation slice:

id: `overworld-map-object-distinct-sprite-gap-fill-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Owner-directed asset follow-up to audit authored overworld map objects after the decorative/blocker foundation pass and generate distinct original sprite assets for every remaining non-decoration object gap.
sourceDocs:
- `content/map_objects.json`
- `art/overworld/manifest.json`
- `art/overworld/decorative_object_sprites.json`
- `docs/overworld-map-object-distinct-sprite-gap-audit.md`
implementationTargets:
- `art/overworld/map_object_sprites.json`
- `art/overworld/manifest.json`
- `art/overworld/runtime/objects/map_objects/distinct/`
- `art/overworld/source/generated/map_objects/distinct/`
- `art/overworld/source/trimmed/map_objects/distinct/`
- `scenes/overworld/OverworldMapView.gd`
- `tests/validate_repo.py`
- `tests/overworld_map_object_sprite_asset_report.gd`
- `ops/progress.json`
completionCriteria:
- The audit identifies authored map objects that still lack unique sprite assignments after the 200-object decorative/blocker pass.
- Every identified gap object has one distinct generated 512x512 runtime PNG, trimmed source PNG, source atlas provenance, manifest mapping, and no-HoMM3-art policy.
- Renderer lookup resolves resource and encounter placements through object-specific map object sprite mappings before shared fallback assets.
- Validation proves all 386 authored map objects have distinct assignments after combining the decorative foundation pass, preexisting unique non-decoration assignments, and this gap-fill pass.
completionEvidence:
- `docs/overworld-map-object-distinct-sprite-gap-audit.md`
- `art/overworld/map_object_sprites.json`
- `python3 tests/validate_repo.py`
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/overworld_map_object_sprite_asset_report.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/overworld_decorative_sprite_asset_report.tscn`
- direct PIL audit: runtime=178, imports=178, edge_alpha_issues=0
nonGoals:
- No HoMM3 copyrighted art/DEF/image/name/text import.
- No town, hero, unit, battle, terrain, road, or UI asset broadening beyond authored overworld map object sprite coverage.
- No generated random map package clutter committed under runtime maps.

id: `decorative-blocker-sprite-asset-foundation-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Owner-directed generated-art ingestion slice for decorative/blocker overworld objects: audit renderer and native map-generator object surfaces, generate original 2D sprite assets for decorative/blocker objects lacking art, wire those assets through the overworld renderer/manifest, and validate that generated decorative/blocker objects are represented without relying only on procedural fallback markers.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/concept-art-pipeline.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/overworld-object-content-batch-001b-biome-scenic-decoration-report.md`
- `docs/overworld-object-content-batch-001c-biome-blockers-edge-report.md`
- `docs/overworld-object-content-batch-001d-large-footprint-coverage-report.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
- owner request on 2026-05-04 to generate sprites for decorative/blocker objects after checking renderer and map generator
implementationTargets:
- `art/overworld/runtime/objects/decorations/`
- `art/overworld/source/trimmed/decorations/`
- `art/overworld/manifest.json`
- `scenes/overworld/OverworldMapView.gd`
- `tests/validate_repo.py`
- focused overworld visual/native decoration report tests as needed
- `ops/progress.json`
completionCriteria:
- Renderer and native map-generator decorative/blocker placement contracts are inspected and documented in the run evidence.
- Decorative/blocker objects lacking 2D assets are represented by generated original sprite assets or a documented, validated archetype mapping sufficient for every authored decorative/blocker object used by the renderer/generator.
- Generated sprite assets are committed only with provenance, runtime/source paths, manifest entries, and validation that files exist at expected dimensions.
- The overworld renderer can draw decorative/blocker map-object placements through mapped sprites while preserving procedural fallback for unmapped object types.
- No HoMM3 copyrighted art/DEF/image assets are imported.
- Validation covers manifest integrity, decorative/blocker asset mapping coverage, and at least one generated decorative/blocker runtime presentation path.
nonGoals:
- No save-version bump, no binary map-package schema migration, no exact HoMM3 asset/DEF parity claim, no full replacement of all terrain art, no broad gameplay rebalance.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-road-spread-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Follow up `native-rmg-homm3-road-placement-parity-10184` by improving the residual owner-like road spread gap: more occupied 6x6 road cells and smaller largest coarse roadless land regions, while preserving count-close roads and reduced reward-road bias.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner follow-up after accfaf1 on 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ `MapPackageService.generate_random_map()` remains the active runtime path.
- Owner-like road tile count stays near owner and reward within 1/4 tiles does not materially regress toward the prior over-road-bias.
- Road nonempty 6x6 cells move closer to owner and largest roadless land 6x6 region is reduced from the accfaf1 baseline.
- Town/start coverage, route reachability, local distribution, land/water shape, guard/reward package adoption, and full parity fixture reports remain passing.
completionEvidence:
- Native owner-like output now adds bounded short service stubs in residual roadless land pockets through the native C++ road materialization path; the active runtime path remains `MapPackageService.generate_random_map()`.
- Road nonempty 6x6 cells moved from 10 to 17 against owner 16, and largest roadless land 6x6 region moved from 25 to 9 against owner 8; road tiles moved from 180 to 201 against owner 184, still below the pre-accfaf1 240 over-road count.
- Reward-road bias remains a documented residual warning rather than full parity: reward within 1 tile stayed 0.125, reward within 4 tiles moved 0.4632 to 0.4779 against owner 0.3727, and town/start road coverage stayed 1.0.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd`, no generated packages committed, no road art lookup rewrite unless required, no HoMM3 asset import, no full parity claim.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-road-placement-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Improve native C++ RMG road layout parity for the owner-like translated medium islands case and general native templates by making route materialization more HoMM3-like: intentional trunk/branch roads, less over-connection, measured road/object interaction, and preserved start/town connectivity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ `MapPackageService.generate_random_map()` remains the active runtime path.
- Owner-like road tile count, land-normalized road density, reward distance-to-road ratios, road spread, road graph shape, and start/town coverage are reported against the owner H3M baseline.
- One bounded road placement/layout improvement lands without touching 4-neighbor road rendering, generated-map package commits, or copyrighted HoMM3 assets.
- Validation gates in the owner directive pass, and remaining exact HoMM3-re road-authoring gaps are stated.
completionEvidence:
- Native owner-like road materialization changed from fully materialized deterministic cross-links to a trunk/branch/short-spur policy for imported translated templates, preserving route graph reachability and road renderer lookup.
- Owner-like native road tiles moved from 240 before the slice to 180 against the owner H3M baseline of 184; reward references within 4 road tiles moved from 0.5588 to 0.4632 against owner 0.3727.
- Remaining exact HoMM3-re road authoring gap is documented; no full algorithm or byte parity is claimed.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd`, no generated `.amap`/`.ascenario` files committed, no road renderer art/lookup rewrite unless required, no exact HoMM3-re algorithm/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-land-normalized-object-density-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Compare owner-attached HoMM3 H3M object/category density against native owner-like 72x72 islands output after the land/water fix, then correct one clear land-normalized sparse category without rerouting generation away from native C++.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Added a land-normalized density report that parses the owner H3M and reports total object, decoration/impassable, reward/resource, guard, town, other-object, and road density per 100 land tiles plus category mix and package surfaces.
- Native owner-like islands output now applies a bounded compact decoration-density supplement for the 72x72 translated Small Ring islands profile, raising total objects from 344 to 488 against owner 496 and decoration/impassable density from 0.330x to 0.804x owner after land normalization.
evidence:
- `tests/native_random_map_homm3_land_normalized_object_density_report.tscn`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-land-water-shape-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond spatial placement comparison by correcting native C++ owner-like 72x72 islands output that was mostly land, anchoring the owner H3M land/water baseline, and preserving generated gameplay/package surfaces on land.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Native islands terrain for non-structural-parity cases now shapes a water-dominant island mask after routes, objects, towns, and guards are known, protecting starts, roads, object body/visit/approach cells, town/guard cells, and converted package body/visit/block surfaces as land.
- The new report parses the owner H3M tile stream directly and verifies the native owner-like case moved from 4,900 land / 284 water to 2,296 land / 2,888 water against the owner baseline of 1,948 land / 3,236 water.
evidence:
- `tests/native_random_map_homm3_land_water_shape_report.tscn`
- `docs/native-rmg-homm3-land-water-shape-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re terrain-shape/placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-obstacle-identity-comparison-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond fill coverage by making native C++ RMG decorative obstacles carry terrain-biased HoMM3-re `rand_trn` source identity/proxy metadata and by adding an empirical comparison/diversity gate against the owner-attached 72x72 Small Ring baseline.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- owner-attached HoMM3 72x72 Small Ring metrics from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `content/homm3_re_obstacle_proxy_catalog.json`
- `tests/native_random_map_homm3_re_identity_comparison_report.gd`
- `tests/native_random_map_homm3_re_identity_comparison_report.tscn`
- `tests/native_random_map_decoration_generation_report.gd`
- `docs/native-rmg-homm3-re-obstacle-identity-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ package generation remains the active path and decorative_obstacle records include HoMM3-re `rand_trn` source row/type/subtype/terrain/DEF-reference provenance plus original proxy family mapping.
- No HoMM3 copyrighted image/DEF assets are imported; source identity and DEF names are metadata/provenance only.
- The new report verifies the owner-attached gzip/decompressed H3M size baseline, compares owner parsed metrics against similar 72x72 islands Small Ring native output, reports counts by HoMM3 source type/source row/proxy family, and gates source-row/type diversity and terrain-biased presence.
- Broad seed/template quality sampling fails on low source-row diversity, missing terrain-biased source families, coverage regression, road/object density regression, or visually empty zone coverage regression.
- Existing catalog playability, fill coverage, menu wiring, decoration generation, and full parity fixture gates still pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no full HoMM3-re parity claim beyond the implemented source-identity/proxy and comparison gate, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-object-table-proxy-selection-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond native reward value tiers by making reward-bearing native C++ RMG object records carry HoMM3-re object/reward table source identity and select original proxy object families from a metadata-only proxy catalog.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `content/map_objects.json`
- `content/homm3_re_reward_object_proxy_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json`
implementation:
- Added a runtime-consumable reward/object proxy catalog with source type/name/subtype/source-row/DEF-reference provenance and original proxy mappings.
- Native `resource_site`, `mine`, `neutral_dwelling`, and `reward_reference` records now expose HoMM3-re source/proxy provenance and `provenance_only_original_proxy_art` policy.
- Reward proxy selection now maps minor, medium, major, and relic bands to different original proxy families/categories instead of only generic placeholder caches.
evidence:
- `tests/native_random_map_homm3_re_object_table_proxy_report.tscn`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re reward table/object/art/byte placement parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-spatial-placement-comparison-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue native C++ RMG parity work beyond density/count gates by parsing the owner-attached HoMM3 H3M for spatial object/road placement metrics, comparing them to owner-like native output, and reducing a clear native object-distribution skew.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `docs/native-rmg-homm3-re-obstacle-identity-comparison-report.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Added a native spatial comparison report that decompresses the owner H3M, parses the 72x72 tile stream, 297 object definitions, 496 placed object instances, and 184 road tiles, then compares quadrant/coarse-grid density, nearest-neighbor distances, road adjacency, and largest low-content regions against native owner-like generation.
- Changed native non-town zone object placement for mines, dwellings, and rewards from anchor-ring clustering to deterministic coarse-grid scatter inside each owning zone, preserving start-support resource placement and native `MapPackageService.generate_random_map()` as the active path.
evidence:
- `tests/native_random_map_homm3_spatial_placement_comparison_report.tscn`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-guard-reward-package-adoption-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue native RMG package parity by making generated package/editor surfaces preserve guard/reward relationships and object body/visit/block masks after native conversion and package save/load.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
- `docs/native-rmg-homm3-re-reward-value-distribution-report.md`
implementation:
- Native generated non-parity object placement now reserves materialized road cells before placing non-town objects, preventing reward/site blocking bodies from landing on road corridors.
- Native package conversion enriches generated object records with package body, visit, and block masks plus package occupancy roles.
- Protected rewards/sites now carry direct package guard links, guard references, guarded access requirements, guarded passability, and AI/pathing hints after convert/save/load.
- Guard records serialize as blocking package surfaces with neutral-stack passability metadata.
evidence:
- `tests/native_random_map_guard_reward_package_adoption_report.tscn`
- `docs/native-rmg-guard-reward-package-adoption-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/reward-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-reward-value-distribution-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond obstacle source identity by making native C++ RMG reward references derive values/categories from catalog zone treasure bands and by pairing valuable rewards with guard values scaled from protected reward values.
sourceDocs:
- `project.md`
- `content/random_map_template_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
implementation:
- Native reward records now include zone value budget/tier, reward value tier, reward source bucket, HoMM3-re-like treasure-band low/high/density provenance, and reward index/target metadata.
- Native site guards scale from protected reward value and record guard/reward relation metadata; medium rewards reject distant fallback guards while major/relic rewards are required guarded content for the report scope.
- `tests/native_random_map_homm3_re_reward_value_distribution_report.tscn` samples small, medium, large, and XL templates and preserves road/object/fill/decor/package regression checks.
evidence:
- `docs/native-rmg-homm3-re-reward-value-distribution-report.md`
- `ops/progress.json`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re reward table/object/art/byte placement parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-fill-coverage-gate-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add a real HoMM3-style fill coverage gate and raise native generated package decorative/blocking body coverage so generated maps no longer pass with barren token decorations.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/map_objects.json`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- owner-attached HoMM3 gzip and native `.amap`/`.ascenario` packages from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_fill_coverage_report.gd`
- `tests/native_random_map_homm3_fill_coverage_report.tscn`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
- `ops/progress.json`
completionCriteria:
- Native generated decorations use larger terrain-biased original blocker footprints and reserve full body tiles, not mostly 1x2 token records.
- The report compares HoMM3-re `rand_trn` obstacle catalog scale, authored AcOrP decoration/blocker catalog scale, attached pre-fix package fill, and sampled native small/medium/large/XL output.
- The attached 72x72 2.78% decoration/blocker body coverage package fails the new medium coverage floor, while the same config regenerated through native C++ package generation passes.
- Sampled native package convert/save/load surfaces retain road and object counts, and decorative bodies do not overlap materialized road cells.
- Exact HoMM3-re obstacle identity/art/template parity and compact binary format parity remain explicitly unclaimed.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no exact HoMM3-re DEF/art/placement parity claim, no compact binary map format claim, no save version bump or authored content writeback.

Completed owner-directed implementation slice:

id: `native-rmg-catalog-playability-wiring-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the native generated-map fallback architecture so every exposed local and translated catalog template uses imported topology and materializes visible roads, objects, decorations, towns, resources, rewards, and guards through native package convert/save/load.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_catalog_quality_report.gd`
- `tests/native_random_map_catalog_quality_report.tscn`
- `docs/native-rmg-template-decoration-wiring-report.md`
- `ops/progress.json`
completionCriteria:
- Native generated maps load catalog template zone and link data for all exposed templates where catalog records exist.
- Zone count, route edge count, road segments/cells, and object density scale from template topology and selected size instead of collapsing to the tiny foundation stub.
- Roads materialize into package/editor-visible terrain road surfaces after native convert/save/load.
- `decorative_obstacle`, town, mine/resource/reward/dwelling, and guard placements appear at sane scaled counts for sampled local, medium, large, and XL catalog templates.
- Existing tiny native full-parity fixture tests remain valid and do not define broad catalog quality.
- Broad catalog quality report, menu wiring report, decoration report, full parity gate, JSON validation, native build, and diff checks pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no exact HoMM3-re byte/placement/art/reward-table parity claim, no save version bump or authored content writeback.

Completed owner-directed implementation slice:

id: `native-rmg-template-decoration-wiring-10184`
phase: `phase-2-deep-production-foundation`
purpose: Wire the full imported random-map template catalog into the generated skirmish menu and make native C++ GDExtension package generation emit real decorative obstacle placements.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `docs/native-rmg-template-decoration-wiring-report.md`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_decoration_generation_report.gd`
- `ops/progress.json`
completionCriteria:
- Generated-map menu rules and UI expose all 56 catalog templates and 56 catalog profiles with template-scoped profile selection.
- Player-count options come from catalog template ranges/slots where available, with fallback only for missing catalog data.
- Active generated skirmish launch remains native `MapPackageService.generate_random_map()` package generation.
- Native object placements include scalable `decorative_obstacle` records with body, footprint, blocking, approach, and occupancy metadata.
- Menu wiring, native decoration generation, player-count/template filtering, full native parity gate, JSON validation, native build, and diff checks pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no false whole-catalog/full HoMM3-re parity claim, no exact HoMM3 decoration art/family parity claim.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-warning-classification-followup-10184`
phase: `phase-2-deep-production-foundation`
purpose: Continue post-a749da2 HoMM3 RMG visual fairness review by reducing remaining warning-level support-resource false positives and classifying accepted HoMM3-like template asymmetry separately from true unresolved regressions.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
- `.artifacts/rmg_parity_richness/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `docs/random-map-homm3-parity-warning-review.md`
- `ops/progress.json`
completionCriteria:
- Visual preview artifacts and warning review identify each remaining warning-level fairness source after `a749da2`.
- Early support-resource diagnostics measure only actual start-support resource routes, not every same-zone mine or dwelling route.
- Reports preserve raw warning and fail-threshold counts while splitting accepted HoMM3-like template asymmetry from unresolved warning-level review items.
- Focused visual, richness, and large visual reports pass with fail-threshold diagnostics still strict.
nonGoals:
- No fairness-threshold weakening, generated PNG import, runtime/source asset ingestion, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-support-resource-preview-gate-10184`
phase: `phase-2-deep-production-foundation`
purpose: Continue post-43ab952 HoMM3 RMG parity by separating real warning-level fairness imbalance from acceptable translated-template asymmetry, correcting compact start-support resource drift where present, and adding human-inspectable rendered preview artifacts for manual layout review.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
- `.artifacts/rmg_parity_richness/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `docs/random-map-homm3-parity-warning-review.md`
- `ops/progress.json`
completionCriteria:
- Current visual/richness/large artifacts are reviewed and warning-level fairness issues are classified without hiding or weakening diagnostics.
- Any real compact start-support resource route imbalance is corrected while preserving road coverage and HoMM3-like template asymmetry.
- Visual inspection produces rendered SVG/HTML preview artifacts suitable for manual map review in addition to ASCII/JSON.
- Focused visual/richness/large reports pass and progress tracking records validation/evidence.
nonGoals:
- No diagnostic threshold weakening, generated PNG import, runtime/source asset ingestion, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-secondary-road-coverage-10184`
phase: `phase-2-deep-production-foundation`
purpose: Review post-fairness RMG road coverage after `ee6015c` and restore HoMM3-like major-object road richness where the route graph remains connected but visually under-roaded.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- Visual artifact review distinguishes fairer path shortening from lost HoMM3-like major-object road coverage.
- Any added roads are grounded in source-backed road overlay timing after towns/mines/major objects and remain separate from fairness diagnostics.
- Visual and richness reports pass with no new fail-threshold fairness warnings and record road coverage/richness impact.
nonGoals:
- No diagnostic threshold weakening, generated PNG import, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-route-resource-fairness-10184`
phase: `phase-2-deep-production-foundation`
purpose: Reduce remaining translated-template route and resource distance unfairness after `random-map-homm3-parity-start-front-fairness-10184`, especially medium translated land templates whose strict diagnostics still exceed fail-threshold route spreads.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- RMG route/resource fairness behavior changes are grounded in translated template zone/link semantics rather than hidden diagnostics or relaxed thresholds.
- The cheap visual inspection report passes and records improved or no-worse total fail-threshold warning counts and distance spreads against the post-7689c3e baseline.
- Focused richness and large visual diagnostics pass or expose any remaining route/resource spread gaps clearly.
nonGoals:
- No fairness-threshold loosening unless an existing metric is proven wrong.
- No rendered asset ingestion, generated PNG import, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-town-zone-spacing-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG town placement quality by preventing generated start and neutral towns from reading as stacked or zone-collapsed, with deterministic spacing metrics across bounded seeds/templates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- Town placement uses a stricter map-size-aware separation policy with a hard no-stack fallback before giving up on a town placement.
- Town/mine/dwelling validation reports all-town, start-town, and same-zone closest-pair spacing metrics.
- The bounded HoMM3 parity richness report validates the stronger spacing requirements across multiple seeds/templates within its runtime budget.
nonGoals:
- No generated terrain-art replacement work.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable town spacing improvement.

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

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-guarded-artifact-pairing-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG reward semantics by making materialized artifacts explicitly consume nearby object guards before lower-priority filler guards, and prove the pairing in bounded richness reports.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- 2026-05-04 owner directive to continue RMG parity after `3b7fc04`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/` generated-map inspection reports/previews
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Object guard materialization deduplicates artifact reward candidates and prioritizes artifact guards before lower-priority mine, dwelling, and cache guards.
- Guard records carry explicit guarded-object point, distance, adjacency, and placement-id association metadata.
- Bounded richness report includes direct guarded-artifact coverage, missing-count, adjacency, and max-distance metrics across the existing multi-template cases without exceeding the runtime budget.
- Focused RMG report and repository validation pass, and remaining parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-connection-road-controls-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG road quality by making template connection `Value`, `Wide`, and `Border Guard` semantics visible and validated in generated road overlays instead of measuring only road tile counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- 2026-05-04 owner directive to continue RMG parity after `e20d96c`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Generated road overlays carry explicit connection-control markers for normal guarded links and border-guard links.
- Wide links preserve guard-suppressed road semantics without creating normal connection controls.
- Bounded richness metrics validate connection-control coverage, wide route semantics, and special border-guard gate roads across multiple seeds/templates.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-blocker-choke-shaping-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG movement texture by making decorative obstacle filler measurably shape route shoulders and chokepoints instead of only proving global decoration/blocker density.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.csv`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `ops/progress.json`
completionCriteria:
- Decorative obstacle candidate scoring accounts for required road/corridor shoulder pressure while preserving path safety.
- Generated decoration records and validation expose movement-shaping metrics for road-adjacent blocker bodies, covered required routes, and choked road tiles.
- Bounded richness report validates route/choke blocker coverage across multiple seeds/templates without exceeding the current runtime envelope.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable movement-shaping improvement.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-river-crossing-quality-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG river overlay quality by making land river candidates continuous, body-safe, and measurably crossed by generated roads instead of only counting river candidates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_roads_rivers_writeout_report.gd`
- `ops/progress.json`
completionCriteria:
- Land river candidates are generated as continuous ordered overlay paths that avoid object bodies while allowing explicit road bridge/ford crossing cells.
- Road/river writeout exposes river continuity, body-conflict, isolated-fragment, and road-crossing metrics.
- Bounded richness metrics validate coherent river candidates and road crossing coverage across the selected land/island seeds/templates without exceeding the current runtime envelope.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable river/crossing quality improvement.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-zone-richness-bands-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG template richness by ensuring non-connector zones carry measurable economy, treasure-band, guard, decoration, and reward coverage instead of hiding poor zones behind whole-map aggregate counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `ops/progress.json`
completionCriteria:
- Runtime zone metadata applies a conservative richness floor only where mine/resource requirements, treasure bands, or monster policy are missing or empty.
- Bounded richness metrics report per-zone richness minimum, poor zone count, object category coverage, reward-band source/fallback counts, value bands, and template variability across multiple seeds/templates.
- Focused richness validation passes within its runtime budget with zero poor eligible zones and no reward-band fallback in the selected cases.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No claim of full HoMM3 RMG parity beyond this measurable zone richness and reward-band improvement.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-visual-inspection-evidence-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add bounded multi-map visual/ASCII/JSON inspection evidence across more seeds, templates, and sizes so RMG parity work does not hide remaining quality gaps behind aggregate richness counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `2ba8fa5`
implementationTargets:
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.tscn`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- The report samples multiple deterministic seeds/templates/sizes with bounded runtime and writes human-inspectable ASCII/JSON artifacts under ignored `.artifacts/`.
- Strict positive cases remain green while diagnostic translated-template probes record remaining quality gaps without pretending full parity.
- The tracked gap note records that ASCII/JSON inspection is evidence only and does not complete rendered visual parity, large-template repair, native RMG parity, or asset ingestion.
- Focused RMG reports, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this inspection evidence and any explicitly fixed concrete gap.

Completed owner-directed corrective slice:

id: `random-map-homm3-parity-visual-diagnostic-runtime-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the bounded RMG visual inspection evidence after `be744e8` by reducing route-heavy translated-template probe cost, separating strict fixture budgets from capped diagnostic probe budgets, and replacing misleading grass-run summary metrics with marker-distribution evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `be744e8`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Route-heavy translated visual probes avoid unnecessary whole-grid path searches where direct or bidirectional route search is sufficient.
- Strict positive fixtures remain on the existing per-case runtime bar, while diagnostic translated-template probes have explicit capped evidence budgets and still report strict-budget overruns as notes.
- Visual summary and matrix expose marker row/column/quadrant coverage and per-route timing so grass terrain runs are not mistaken for blank-map quality failures.
- Focused visual/richness reports, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this bounded report/runtime correction.

Completed owner-directed follow-up slice:

id: `random-map-homm3-parity-large-visual-diagnostic-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add a separate bounded visual diagnostic path for excluded large translated RMG templates, starting with `translated_rmg_template_042_v1` at 108x108, without making the cheap visual gate hang.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `41233b1`
implementationTargets:
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_large_visual_inspection_report.tscn`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- The existing cheap visual gate keeps its 36x36/72x72 case set and runtime bounds.
- A separate large report mode inspects one deterministic 108x108 `translated_rmg_template_042_v1` case with explicit total and diagnostic per-case budgets.
- Large-template quality gaps are reported as diagnostic gaps with limit 0 for this focused evidence path; strict-budget overruns remain diagnostic notes.
- Focused large/cheap visual reports, richness report if reasonable, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No promotion of `translated_rmg_template_042_v1`, `translated_rmg_template_043_v1`, 144x144, or underground large templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this bounded large-template diagnostic evidence.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-large-layout-quality-metrics-10184`
phase: `phase-2-deep-production-foundation`
purpose: Surface the source-backed large-template fairness/layout quality warnings that are currently present in validation output but hidden from the visual diagnostic matrix and compact metrics.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `docs/random-map-generator-foundation.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- 2026-05-04 owner directive to continue RMG parity after `6c14f35`
implementationTargets:
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Large/visual inspection metrics expose fairness status, warning counts, fail-threshold warning counts, contest-route distance spread, contest-guard pressure spread, route-guard pressure spread, and town-to-resource distance spread from the existing source-backed fairness report.
- The visual matrix and JSON summaries make large layout-quality warnings visible without changing generator route, object, guard, terrain, save/load, renderer, or runtime semantics.
- The gap note records the newly visible large-template layout warning evidence and identifies layout correction as a separate next slice before strict promotion.
- Focused large visual report, cheap visual report if reasonable, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No route/pathing, zone layout, guard pressure, object placement, content density, save-version, native generator, renderer, fog, or gameplay behavior change.
- No promotion of `translated_rmg_template_042_v1`, `translated_rmg_template_043_v1`, 144x144, or underground large templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this clearer diagnostic evidence.

Selected owner-directed implementation slice:

id: `native-rmg-homm3-local-distribution-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the native C++ owner-like 72x72 islands output after the land/water and land-normalized density fixes so local interactive placement has fewer barren land windows and fewer oversized piles while preserving small guarded reward clusters.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
- owner screenshots from 2026-05-04 showing desolate regions and localized piles after commit `ed0dad2`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_local_distribution_report.gd`
- `tests/native_random_map_homm3_local_distribution_report.tscn`
- `docs/native-rmg-homm3-local-distribution-report.md`
- `ops/progress.json`
completionCriteria:
- Active native package generation through `MapPackageService.generate_random_map()` remains the only runtime path touched; generation is not rerouted to `scripts/core/RandomMapGeneratorRules.gd`.
- The new report measures local empty-window, pile concentration, window density spread, and nearest-neighbor metrics separately for decorations, interactive rewards/sites, guards, and guarded packages on the owner-like 72x72 generated/native case.
- Native interactive object placement uses deterministic coarse-grid/spacing scoring so non-decorative objects distribute across eligible zone/land windows while guarded reward packages remain compact local pairs, not large piles.
- Existing guard/reward package adoption, road non-conflict/connectivity, source identity/proxy metadata, land/water shape, fill coverage, catalog/menu wiring, decoration generation, and full-parity gates still pass.
nonGoals:
- No generated `.amap`/`.ascenario` commits under `maps/`.
- No copyrighted HoMM3 art/assets, exact HoMM3 byte/object-table/art parity, or full parity claim.
- No save-version bump, authored scenario adoption, renderer/fog rewrite, generated terrain-art ingestion, or route back to old GDScript RMG.

Selected owner-directed implementation slice:

id: `random-map-homm3-parity-start-front-fairness-10184`
phase: `phase-2-deep-production-foundation`
purpose: Reduce the largest newly exposed RMG layout fairness warnings by classifying comparable primary contest/early fronts per active player start from translated template connections, without weakening guard/resource/distance diagnostics.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `docs/random-map-generator-foundation.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- 2026-05-04 owner directive to continue RMG parity after `cf52aa9`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_richness/`
- `.artifacts/rmg_parity_visual_inspection/`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Translated template connections keep their source guard payloads and required route materialization, including wide and border-guard semantics.
- Layout fairness classifies one deterministic primary contest/early front per active player start, preferring active-opponent fronts and then lower-pressure neutral fronts, so duplicate links and inactive owner-slot links do not inflate one player's comparable start-front pressure.
- Fairness diagnostics remain strict and continue reporting remaining route/resource/guard spread warnings after the corrected primary-front model.
- Richness, visual, large visual if reasonable, JSON/progress sync, diff check, and repository validation pass or any skipped validation is recorded with a concrete reason.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, renderer, fog, pathing, or gameplay loop redesign.
- No promotion of large translated templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this bounded start-front fairness correction.

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
