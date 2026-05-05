# Native RMG HoMM3 Spec Rework Gap Report

Date: 2026-05-05
Slice: `native-rmg-homm3-spec-gap-audit-10184`
Status: report and planning gate; not an implementation slice.

## Scope

This report maps the recovered HoMM3 random-map-generation behavior to the current native C++ generator in `src/gdextension/src/map_package_service.cpp`, then fixes the Phase 3 child-slice order. It uses recovered behavior and structure only as engineering reference. It does not import or require HoMM3 names, art, DEF assets, maps, text, or binary-compatible `.h3m` output.

Primary source anchors:

- `random-map-generation-h3maped-full-spec.md`, especially execution order, template fields, generated cells, writeout, and checklist sections.
- `random-map-generator-implementation-model.md` lines 13-33 for the recovered graph-to-map pipeline and lines 124-245 for the first implementation model.
- `random-map-generator-implementation-checklist.md` lines 6-299 for implementation acceptance order.
- `random-map-connection-payload-semantics.md` lines 11-27 and 68-145 for link `Value`, `Wide`, and `Border Guard` semantics.
- `random-map-connection-special-guards-and-wide.md` lines 8-30 and 109-150 for type-9 border guard materialization and `Wide` as guard suppression, not geometry width.
- `random-map-monster-and-seven-category-semantics.md` lines 24-37, 38-80, 81-181, and 183-200 for mine/resource categories, monster masks, strength scaling, and type limits.
- `random-map-decoration-object-placement.md` for object-template filtering, value bands, footprints, limits, and `rand_trn` decorative filler.
- `random-map-writeout-to-map-structures.md` lines 32-59, 87-132, and 150-170 for final tile/object writeout.
- `profile_native_rmg_cpp_phases_compare.log`, `profile_native_rmg_cpp_phases_direct.log`, and `profile_native_rmg_compare.log` for current XL cost evidence.

Existing repo reports reconciled rather than duplicated: `docs/random-map-generator-foundation.md`, `docs/random-map-homm3-parity-gap-audit.md`, `docs/random-map-xl-template-alignment-audit.md`, `docs/random-map-final-homm3-parity-gate-audit.md`, `docs/random-map-final-homm3-parity-regate-audit.md`, and the native RMG Phase 2 comparison reports under `docs/native-rmg-*.md`.

## Current Native Baseline

Current native generation is a staged package generator with useful Phase 2 infrastructure, not the Phase 3 target architecture. The top-level order is:

1. normalize config and assign players;
2. generate nearest-seed zone layout;
3. create player starts;
4. generate route/road records;
5. generate river metadata;
6. place objects;
7. place towns and guards;
8. generate terrain grid;
9. validate, package, and expose feature-gated adoption metadata.

Native evidence:

- `generate_random_map()` calls `generate_zone_layout`, `generate_player_starts`, `generate_road_network`, `generate_river_network`, `generate_object_placements`, `generate_town_guard_placements`, then `generate_terrain_grid` (`map_package_service.cpp` lines 7053-7066). This differs from the recovered phase order, where terrain and towns precede later object, road, river, and writeout phases.
- `generate_zone_layout()` uses a weighted nearest-seed owner grid and records `full_generation_status = not_implemented` (`map_package_service.cpp` lines 1570-1622).
- Imported catalog links are copied into native route records, but roads are materialized through direct or trunk/branch route heuristics and stored as staged overlay records (`map_package_service.cpp` lines 1722-1784 and 2502-2750).
- Object placement uses target-count heuristics and proxy metadata, then appends decorative placements (`map_package_service.cpp` lines 4376-4521). This improved density and provenance in Phase 2 but is not a recovered object-template pipeline.
- Towns and guards are staged package records, with neutral guard stacks selected by native placeholder units and strength bands (`map_package_service.cpp` lines 4561-4587 and 5153-5220).
- Terrain grid generation either writes count-parity terrain for special fixtures or paints native terrain from deterministic terrain seeds; island mode uses a native island shape helper when available (`map_package_service.cpp` lines 5619-5741).
- Validation checks dimensions, counts, ids, and basic component integrity, but does not validate the recovered phase semantics end to end (`map_package_service.cpp` lines 5826-5915 and following).

The profiling artifacts show the most severe known bottleneck: XL islands spend about 32.9 seconds in `deep.terrain.island_candidate_scoring` and 33.0 seconds in `phase.terrain_grid`, producing a 45.3 second total in `profile_native_rmg_cpp_phases_compare.log`. XL land cases are also object-heavy: `phase.object_placement` is about 10.7-17.7 seconds in the compare log, with `deep.object.object_point_for_zone_index`, `deep.object.interactive_loops`, `deep.object.find_decoration_point`, and `deep.object.road_distance_field` dominating.

## Required Child-Slice Order

This is the exact Phase 3 order. Later workers should not skip ahead unless AcOrP changes the selected slice.

| Order | Slice id | Purpose | Depends on |
|---:|---|---|---|
| 0 | `native-rmg-homm3-spec-gap-audit-10184` | This report and planning/tracker reconciliation. | Phase 3 strategy setup |
| 1 | `native-rmg-homm3-generator-data-model-10184` | Define reusable generator schema/data for templates, zones, links, object definitions, masks, footprints, limits, value bands, validation, and writeout metadata. | audit |
| 2 | `native-rmg-homm3-runtime-zone-graph-10184` | Build filtered runtime template/zone graph preserving owners, roles, base sizes, links, terrain/faction rules, and infeasibility diagnostics. | data model |
| 3 | `native-rmg-homm3-terrain-island-shape-10184` | Replace ratio/protected-cell island shaping with zone-aware terrain/water painting and fix XL island candidate-scoring performance. | data model, runtime graph |
| 4 | `native-rmg-homm3-towns-castles-10184` | Implement Phase 4a/4b town/castle minimums/densities, mapped owner vs neutral `-1`, same-type neutral reuse, source-zone faction choice, and placement failure reporting. | runtime graph, terrain/island |
| 5 | `native-rmg-homm3-roads-rivers-connections-10184` | After towns/castles, consume connection payloads in recovered cleanup/late order; implement `Wide`, border-guard, road, and river overlay semantics. | runtime graph, terrain/island, towns/castles |
| 6 | `native-rmg-homm3-object-placement-pipeline-10184` | Implement object catalog/footprint/occupancy/value-band/limit/decorative filler pipeline shared by mines, rewards, guards, and decorations. | data model, runtime graph, terrain/island, roads/connections |
| 7 | `native-rmg-homm3-mines-resources-10184` | Implement seven mine/resource categories, adjacent resources, and placement failure reporting. | object pipeline, runtime graph, terrain/island, towns/castles |
| 8 | `native-rmg-homm3-guards-rewards-monsters-10184` | Implement connection guards, protected rewards, monster masks, strength scaling, guard/reward relations, and value-banded reward semantics. | object pipeline, mines/resources, roads/connections |
| 9 | `native-rmg-homm3-validation-adoption-gates-10184` | Add phase validators, regression/performance gates, package/session/save/replay boundaries, and final adoption report. | all implementation slices |

Rationale: the recovered pipeline starts from template graph and runtime zones, then terrain, towns/castles, cleanup/connection payload handling, mines/resources and other objects, guards/rewards, decoration/overlays, and writeout. The implementation order keeps shared data and runtime graph first, resolves the XL terrain bottleneck before broad sampling, places towns/castles before later connection/object/road/river work, and leaves adoption until all structure can be validated.

## Phase Gap Matrix

### 1. Template Data Model And Catalog Import

Recovered behavior:

- HoMM3 RMG is driven by a template graph whose zones and links encode size/player filters, roles, owner slots, terrain rules, town rules, monster rules, mine/resource arrays, treasure bands, and link payloads (`random-map-generator-implementation-model.md` lines 13-33 and 47-123).
- The recovered catalog has 53 templates, 646 zones, 869 links, 21 wide links, and 8 border-guard links. `rmg-template-summary.csv` and `rmg-template-catalog.json` preserve these facts.
- The implementation checklist requires structured `RmgTemplate`, `TemplateZone`, `TemplateLink`, `ObjectTemplate`, `ObjectTypeMetadata`, `RandTrnObstacle`, and `GenerationConfig` schemas before behavior work (`random-map-generator-implementation-checklist.md` lines 6-35).

Current native behavior:

- `content/random_map_template_catalog.json` has 56 template/profile records, including translated templates and local fixtures, but native C++ consumes only part of that schema. `catalog_zone_to_native_zone()` copies selected zone fields and metadata but normalizes roles, owners, and terrain through current native shortcuts (`map_package_service.cpp` lines 1184-1240).
- No single reusable native data model exists for object templates, type metadata, `rand_trn` obstacles, terrain masks, pass/action masks, per-zone/global limits, or writeout metadata.

Player-visible/product effect:

- Maps can have plausible counts and provenance but lack durable structural guarantees. Future changes risk drifting by adding local heuristics instead of shared generator rules.

Required implementation slice:

- `native-rmg-homm3-generator-data-model-10184`

Priority/dependencies:

- Order 1, blocks all later slices.

Unknowns/unsupported boundaries:

- Exact HoMM3 TSV schema should not become the production schema. The project needs an original structured schema that preserves behavior fields without copying creative names/assets.
- Binary-compatible `.h3m` output is not a target.

### 2. Template Filtering, Player Assignment, And Runtime Zone Graph

Recovered behavior:

- Templates are filtered by size score, water mode, human count, total player count, and capacity; zones and links are filtered by player ranges (`random-map-generator-implementation-model.md` lines 126-147).
- Runtime zones preserve source ids, roles, owner/player slots, chosen factions, terrain, area weights, and link lists (`random-map-generator-implementation-model.md` lines 149-193).
- The full spec records source-zone and connection fields, reciprocal link records, and graph/connectivity rules (`random-map-generation-h3maped-full-spec.md` sections 3.2-3.4 and 4.3-4.4).

Current native behavior:

- Native zone layout uses deterministic seed points and a nearest-seed owner grid (`map_package_service.cpp` lines 1570-1622). Imported catalog zones exist, but zone footprints are not built as recovered runtime zone rectangles/cells with corridor feasibility.
- `foundation_route_links()` copies link endpoints and payload booleans, but graph filtering is shallow and does not reject unusable filtered graphs with phase diagnostics (`map_package_service.cpp` lines 1722-1784).

Player-visible/product effect:

- Template topology is recognizable in reports but maps can still read as radial/Voronoi approximations. Starts, treasure zones, and front routes are not guaranteed to express the intended template shape.

Required implementation slice:

- `native-rmg-homm3-runtime-zone-graph-10184`

Priority/dependencies:

- Order 2, depends on `native-rmg-homm3-generator-data-model-10184`.

Unknowns/unsupported boundaries:

- Exact HoMM3 zone footprint heuristics can remain bounded if the implementation preserves source graph semantics, target areas, connectivity, and clear infeasibility reporting.
- Disconnected source templates need an explicit project policy.

### 3. Terrain, Water, Underground, And XL Island Shape

Recovered behavior:

- Zone terrain is chosen from faction match and allowed terrain masks; blank terrain masks default to dirt. Terrain ids include dirt, sand, grass, snow, swamp, rough, subterranean, lava, water, and rock (`random-map-generator-implementation-model.md` lines 216-245).
- Terrain is painted and normalized through a TerrainPlacement-compatible generated-cell adapter, with terrain id, art index, and flips later written to tile bytes (`random-map-generation-h3maped-full-spec.md` sections 3.5, 6.3, and 7.2; `random-map-writeout-to-map-structures.md` lines 87-132).
- The checklist accepts full-map terrain normalization as an intentional first implementation simplification, but generated cells must still store terrain id/art/flip fields (`random-map-generator-implementation-checklist.md` lines 73-107).

Current native behavior:

- `generate_terrain_grid()` runs after objects and guards, not before town/object placement. It paints from deterministic terrain seeds or island land lookup and stores terrain codes only, not recovered art/flip normalization (`map_package_service.cpp` lines 5619-5741).
- XL islands suffer a severe candidate-scoring bottleneck: `deep.terrain.island_candidate_scoring` is about 32.9 seconds and dominates a 45.3 second XL islands run in `profile_native_rmg_cpp_phases_compare.log`.

Player-visible/product effect:

- Terrain shape can be closer than the original foundation but still lacks recovered zone terrain ownership, terrain-art normalization, and scalable island performance. XL islands are not acceptable for a production generator until this is fixed.

Required implementation slice:

- `native-rmg-homm3-terrain-island-shape-10184`

Priority/dependencies:

- Order 3, depends on data model and runtime zone graph. It must run before broad object-placement sampling because land/water cells and zone terrain determine legal footprints.

Unknowns/unsupported boundaries:

- Exact TerrainPlacement queue propagation, private terrain frame names, and binary tile-byte parity are out of scope unless selected later.
- The slice must record any remaining Windows/Linux performance delta if native profiling differs by platform.

### 4. Connections, Roads, Rivers, Wide Links, And Border Guards

Recovered behavior:

- Connection endpoints are consumed early for runtime-zone geometry; `Value`, `Wide`, and `Border Guard` payloads are consumed later (`random-map-connection-payload-semantics.md` lines 52-87).
- `Value` is scaled into normal guard placement. `Wide` suppresses normal guard value and is not a corridor-width input. `Border Guard` enables special type-9-equivalent object materialization even with zero `Value` (`random-map-connection-payload-semantics.md` lines 11-27 and 131-145; `random-map-connection-special-guards-and-wide.md` lines 8-30 and 109-150).
- Roads and rivers are overlay layers separate from `rand_trn` decorative filler, and write tile overlay bytes/flip bits (`random-map-cell-flags-and-overlays.md`; `random-map-writeout-to-map-structures.md` lines 113-132).

Current native behavior:

- Native road generation builds route edges and staged road segments from links, with connection control metadata and broad road-spread heuristics (`map_package_service.cpp` lines 2502-2750).
- `Wide` and `border_guard` are preserved in metadata. Wide links are counted as suppressed routes, but true late connection semantics are not implemented. Border guards are represented as control/gate metadata and native guard records, not type-9-equivalent object placement with subtype support.
- Rivers are simple metadata paths or waterline records and do not mutate terrain/passability/tile overlay bytes (`map_package_service.cpp` lines 2903-2935).

Player-visible/product effect:

- Roads can visually and structurally improve map readability, but gates and wide edges are not yet reliable gameplay geometry. Rivers are mostly decorative/report metadata. Link semantics can drift from template intent.

Required implementation slices:

- `native-rmg-homm3-towns-castles-10184` must run first for Phase 4a/4b town/castle placement.
- `native-rmg-homm3-roads-rivers-connections-10184` follows towns/castles for cleanup, late connection payloads, roads, and rivers.

Priority/dependencies:

- Order 5 for roads/rivers/connections, depends on runtime graph, terrain/island shape, and town/castle placement. It should not be selected before `native-rmg-homm3-towns-castles-10184`.

Unknowns/unsupported boundaries:

- Exact HoMM3 road/river path heuristics and visual transform axes remain partially unresolved.
- Border guards must be implemented as original-content gate objects, not copied HoMM3 art/text.

### 5. Object Catalog, Footprints, Occupancy, Value Bands, Limits, And Decoration

Recovered behavior:

- Object placement filters `objects.txt`/`objtmplt.txt` templates by type, subtype, terrain masks, passability/action masks, placement bucket, and runtime zone terrain. It enforces per-zone/global type limits and uses value-banded object selection (`random-map-decoration-object-placement.md` and `random-map-monster-and-seven-category-semantics.md` lines 183-200).
- Decorative filler is a late ordinary-object pass using `rand_trn` terrain/adjacency/overlap scoring, not a special decoration super-type (`random-map-decoration-object-placement.md`; `random-map-generator-implementation-checklist.md` lines 193-205).
- Object definitions and placed instances serialize separately from tile bytes (`random-map-writeout-to-map-structures.md` lines 150-170).

Current native behavior:

- Native object placement creates resource sites, mines, neutral dwellings, reward references, and decorations through target-count heuristics and proxy catalogs (`map_package_service.cpp` lines 4376-4521).
- Phase 2 added valuable object provenance, reward value metadata, guard/reward links, and fill coverage, documented in `docs/native-rmg-homm3-fill-coverage-report.md`, `docs/native-rmg-homm3-re-reward-value-distribution-report.md`, and `docs/native-rmg-homm3-re-object-table-proxy-report.md`. These are useful but still proxy heuristics.
- The current object placement profile is expensive on XL maps: object placement is about 10.7-17.7 seconds in the provided compare profile logs.

Player-visible/product effect:

- Maps are no longer barren, but object density can still feel algorithmic and may not respect the recovered value/limit/footprint semantics. Performance cost also limits broad seed/template validation.

Required implementation slice:

- `native-rmg-homm3-object-placement-pipeline-10184`

Priority/dependencies:

- Order 5, depends on data model, runtime graph, terrain/island shape, and road/connection reservation.

Unknowns/unsupported boundaries:

- HoMM3 object identity, DEF frame dependency, and exact object table parity are not goals.
- Original object ids/assets must be used for product output.

### 6. Towns, Castles, Mines, Resources, And Same-Type Neutral Semantics

Recovered behavior:

- Town/castle placement consumes zone minimums/densities, owner/town selection, terrain/faction rules, and `Towns are of same type` neutral reuse (`random-map-generation-h3maped-full-spec.md` sections 3.6 and 5.4; `random-map-town-sametype-and-object-metadata.md`).
- Seven mine/resource categories are Wood, Mercury, Ore, Sulfur, Crystal, Gems, and Gold. Minimums are placed before density-weighted extras, and matching resource objects can be placed adjacent to mines (`random-map-monster-and-seven-category-semantics.md` lines 24-80).

Current native behavior:

- Start towns and neutral towns are generated as staged records with spacing heuristics (`map_package_service.cpp` lines 5153-5191). `same_type_neutral` is not yet a first-class per-zone placement rule.
- Mines and resource sites are generated through target formulas, value bands, and proxy metadata, not the recovered seven-category minimum/density loop (`map_package_service.cpp` lines 4430-4456 and existing Phase 2 reports).

Player-visible/product effect:

- Player starts and economy sites exist, but economic shape is not yet driven by template semantics. Rare resource availability, mine distribution, and neutral town faction reuse can diverge from intended map templates.

Required implementation slices:

- `native-rmg-homm3-towns-castles-10184`
- `native-rmg-homm3-mines-resources-10184`

Priority/dependencies:

- Towns/castles are Order 4 and depend on runtime graph and terrain/island shape.
- Mines/resources are Order 7 and depend on the object placement pipeline, runtime graph, terrain/island shape, and completed town/castle placement.

Unknowns/unsupported boundaries:

- Broad economy rebalance is out of scope. The slice should implement placement semantics using existing original resources/sites and report unsupported categories explicitly.

### 7. Guards, Rewards, Monsters, And Strength Scaling

Recovered behavior:

- Monster masks include neutral plus town factions, with `match_to_town` narrowing candidates when runtime town/faction is known (`random-map-monster-and-seven-category-semantics.md` lines 81-119).
- Local monster strength tokens combine with global monster strength and the recovered `0x4a65a5` formula; sample base values are 1500, 3500, and 7000 (`random-map-monster-and-seven-category-semantics.md` lines 120-181).
- Value-banded reward placement ignores invalid/zero-density bands, respects low/high values, terrain, footprints, weights, and type limits (`random-map-generator-implementation-checklist.md` lines 157-192).

Current native behavior:

- Route guards and object guards are staged as native placeholder neutral stacks from guard values and strength bands (`map_package_service.cpp` lines 4561-4587 and 5153-5220).
- Phase 2 reward reports added guard/reward value relations and proxy reward buckets, but not recovered monster mask selection, effective mode calculation, or exact protected-object semantics.

Player-visible/product effect:

- Guarded rewards exist but can feel too generic and may not match zone faction/monster intent. Risk/reward pressure is metadata-driven rather than a faithful generator mechanic.

Required implementation slice:

- `native-rmg-homm3-guards-rewards-monsters-10184`

Priority/dependencies:

- Order 7, depends on object placement, towns/mines/resources, and roads/connections.

Unknowns/unsupported boundaries:

- Exact creature rosters, HoMM3 unit names, and creative reward identities are not copied. The implementation must translate masks and strength into original unit/content ids.
- Exact UI labels for global monster setting values remain unresolved in the recovered notes; use numeric/internal modes with documented mapping.

### 8. Validation, Save/Replay, Package Boundaries, And Adoption

Recovered behavior:

- The recovered generator writes a final tile stream and object definitions/instances after phase completion (`random-map-writeout-to-map-structures.md` lines 32-59 and 150-170).
- The implementation checklist requires validators after each major phase, deterministic regression tests, visual debug export, supported simplification notes, and an end-to-end sample generator (`random-map-generator-implementation-checklist.md` lines 240-299).

Current native behavior:

- Native package/session conversion exists and preserves generated map surfaces behind feature-gated adoption metadata (`docs/native-rmg-guard-reward-package-adoption-report.md`).
- `generate_random_map()` explicitly sets `no_authored_writeback = true`, returns validation/provenance, and marks non-supported output as not authoritative (`map_package_service.cpp` lines 7159-7238).
- Validation is broad integrity validation, not phase-by-phase recovered semantic validation.

Player-visible/product effect:

- Generated maps can feed current menu/package paths, but Phase 3 must not promote them to authoritative gameplay or alpha readiness until validation proves supported profiles are structurally acceptable.

Required implementation slice:

- `native-rmg-homm3-validation-adoption-gates-10184`

Priority/dependencies:

- Order 8, depends on all implementation slices.

Unknowns/unsupported boundaries:

- No generated runtime map package clutter should be committed.
- No save-version bump, campaign adoption, or player-facing parity claim should land before this gate records exact validation evidence.

## Priority Problems To Track

1. XL island candidate scoring and object-placement performance are release blockers for broad seed validation. Fix under `native-rmg-homm3-terrain-island-shape-10184` and keep object-placement cost visible under `native-rmg-homm3-object-placement-pipeline-10184`.
2. Template graph and runtime zone semantics are the root architectural gap. Fix before adding more local placement heuristics.
3. Terrain/water island shaping must be zone-aware and performant before object density and route validation are meaningful.
4. Towns/castles must consume source fields `+0x20..+0x3c` before later cleanup, connection payload, road, river, mine/resource, object, guard/reward, and decoration work.
5. Roads/rivers/connections must consume `Value`, `Wide`, and border-guard flags in the recovered phase order, with original gate objects.
6. Object placement must move from proxy target counts to explicit object definitions, footprints, limits, value bands, and ordinary-object decoration filler.
7. Guards/rewards/monsters/mines/resources must translate recovered semantics into original content without broad rebalance or creative copying.
8. Validation/adoption must remain last and must cover save/replay/package boundaries and Windows/Linux native expectations.

## Final Boundaries

- This report completes a planning gate only. It does not complete any implementation child slice.
- Unsupported parity boundaries are explicit: exact `.h3m` byte output, HoMM3 art/DEF/assets/text, private editor toolkit details, exact PRNG stream parity, and exact terrain/road/river visual frame names are not claimed.
- Future reports should link back to this file and record which unsupported boundaries remain, rather than reopening broad parity claims.
