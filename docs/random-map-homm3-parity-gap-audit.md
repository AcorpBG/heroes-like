# Random Map HoMM3-Parity Gap Audit

Status: planning/report slice, not implementation parity.
Date: 2026-04-29.
Slice: `random-map-homm3-parity-gap-audit-10184`.

## Conclusion

The current random map generator is a useful foundation, but it is not close to HoMM3-style RMG parity and must not be treated as alpha-ready random-map generation. It proves deterministic, catalog-backed generated drafts through a transient scenario/domain load boundary. It does not yet reproduce the full functional shape of HoMM3 random map generation in original-game terms.

The parity target is now explicit: RMG is incomplete until it reaches full functional parity with the HoMM3 RMG model translated into Aurelion Reach systems, content ids, terrain, object taxonomy, UI, save/replay, validation, and skirmish runtime flows.

## Source Evidence

Primary extracted model sources:

- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-summary.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-web-map-editor/`

Current implementation evidence:

- `content/random_map_template_catalog.json`
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_seeded_generator_core_report.gd`
- `tests/random_map_terrain_town_road_constraints_report.gd`
- `tests/random_map_resource_encounter_fairness_report.gd`
- `tests/random_map_template_catalog_grammar_report.gd`
- `tests/random_map_scenario_load_smoke.gd`
- `docs/random-map-generator-foundation.md`

The extracted catalog contains 53 source templates, 646 zones, 869 links, 21 wide links, and 8 border-guard links. The current original catalog contains 3 small authored templates/profiles and only shallow coverage of the grammar.

## Foundation-Complete Evidence

These are real foundations that should be preserved:

- Deterministic seed/profile normalization and stable payload signatures exist.
- A generated scenario-like payload is staged behind an explicit no-write boundary.
- A small data-driven template catalog exists with zone ids, links, owner slots, terrain constraints, guard values, wide flags, and border-guard flags.
- Runtime output preserves selected profile/template metadata through generation.
- Zone graph, seed layout, terrain owner grid, road-staging payloads, route classifications, resource/encounter fairness summaries, and generated draft scenario records exist.
- Focused Godot reports cover seeded core determinism, terrain/town/road constraints, resource/encounter fairness, template-catalog grammar preservation, and transient generated-draft scenario load.
- Generated drafts can enter `ScenarioFactory`, `OverworldRules`, `ScenarioRules`, and `ScenarioScriptRules` lookup/evaluation paths without authored JSON writeback.

These are foundation-complete only. They are not parity-complete.

## Gap Matrix

| Domain | Foundation-complete now | Missing for HoMM3-style parity |
|---|---|---|
| Template library breadth and grammar | Three original templates exercise small zone/link graphs, selected profile metadata, size/player filters, wide flags, and border-guard flags. | Import/translate the full 53-template functional breadth into original schema; preserve all zone fields, link fields, player filters, size-score behavior, mine arrays, treasure bands, monster masks, same-type town flags, duplicate-name handling, disconnected-template policy, and size/water/level support. Current schema is too narrow. |
| Zone types, ownership, player/team constraints | Human/computer start, treasure, and junction roles exist. Owner slots survive into runtime staging for limited profiles. | Full player assignment for 1-8 humans/total players, fixed owner slots, human/computer capacity checks, team/free-for-all metadata, neutral/townless profiles, faction/town masks, per-zone ownership behavior, and failure diagnostics are incomplete. |
| Zone links and special/wide/border-guard connections | Link endpoints, guard values, `wide`, and `border_guard` survive into route/fairness records. Wide suppresses normal guard pressure in report logic; border guard has special classification. | Connection payloads are not fully consumed like the extracted model. No real special guard object placement, type/subtype equivalent, key/gate support, locked marker handling, reciprocal processed state, fallback connection passes, or multi-pass corridor/guard placement. Wide is represented in metadata but not integrated with full guard-object materialization. |
| Terrain, underground, water, and transit semantics | Land terrain ids and biome tags are staged; water is treated mostly as impassable. Roads are staged as overlay payloads. | No full size-score/water-mode behavior, island handling, underground levels, subterranean terrain/cave rules, multi-level zone allocation, portals/monoliths/subterranean gates, boats/shipyards/ferries, bridges, rivers, overlay autotiling, or terrain art/flip normalization. |
| Object density and decorative placement | A small set of towns, support resources, and encounters are placed with basic body/approach metadata. | No object catalog loader equivalent, footprint/action/passability masks, object type metadata, global/per-zone object limits, value-banded object selection, rand_trn-style decorative obstacle filler, terrain/adjacency/overlap scoring, or density passes that make maps feel populated rather than sparse. |
| Mines/resources, dwellings, towns, and same-type metadata | Early gold/wood/ore support sites and primary towns are placed for starts; town ids resolve through content. | Seven mine/resource categories are not implemented as template-driven minimum/density arrays; no mine objects with adjacent resources, rare resource support, neutral dwellings, full town/castle minimum and density behavior, neutral town placement, or same-type neutral town reuse. |
| Monsters, guard categories, and seven-category semantics | Route guard values are reported as pressure classes and encounters are placed using one default encounter id. | No monster faction mask selection, match-to-town monster logic, local/global strength mode scaling, mine guard base values, true neutral stack selection, guard-object creation, unavoidable-guard validation, or seven-category mine/guard interactions. |
| Rewards, artifacts, spells, and skills equivalents | Generated scenario has placeholder objective/reward pressure reporting and empty artifact nodes. | No value-banded reward object selection, artifact pools, spell/skill reward equivalents, treasure bands, risk/reward value balancing, artifact neighborhood finalization, reward allowlists, or original-game conversion of HoMM3 reward classes. |
| Roads, rivers, writeout, and map-structure serialization | Staged road segments/stubs exist with no authored tile writeout. Generated scenario/terrain-layer records are transient and no-write. | No durable road/river overlay tile bytes, terrain art/flip byte packing, final object definition/instance serialization, generated file export, editor writeback, generated map round-trip, or save-stable map-structure writer. |
| Validation batches, retry, and failure modes | Focused reports validate a few fixed seeds/profiles and classify some fairness failures. | No phase-by-phase validator suite, retry loop, batch seeds across template families/sizes/players/levels, deterministic regression checksums, template import parity checks, negative corpus, CI-scale generated-map batches, or actionable remediation reports by phase/zone/link/object. |
| Skirmish/runtime adoption, UI, save/replay, and writeback boundaries | Generated drafts intentionally stay out of authored scenarios, campaign, skirmish browser, save migration, and player-facing UI. | No random-map setup UI, skirmish browser integration, generated scenario persistence, replay seed capture, save/load schema support, generated file/export contract, campaign exclusion rules, or user-facing failure/retry flow. |

## Parity Gate

RMG parity must require all of the following before any alpha-complete claim:

- Template coverage equivalent to the extracted 53-template functional breadth, expressed with original ids and content.
- Runtime generation that consumes the full template grammar, not just preserves fields in reports.
- Generated maps that place towns, mines, dwellings, guards, rewards, roads, rivers/transit, and decorations through original content ids and object metadata.
- Multi-size, multi-player, team/free-for-all, water, underground, and transit cases with deterministic outputs.
- Batch validation and retry behavior that can reject bad generations and explain why.
- Runtime adoption into skirmish with save/replay provenance and explicit writeback/export boundaries.

Until those gates are met, P2.10 remains a foundation and test harness surface only.

## Executable Implementation Queue

The follow-on slices below are ordered for continuous coding-agent implementation. Each slice must update `PLAN.md`/`ops/progress.json` status as it starts and completes.

1. `random-map-template-catalog-import-10184` - expand the original schema/importer to cover the full extracted template grammar and catalog breadth in original-game ids.
2. `random-map-template-filtering-assignment-10184` - implement size/water/player filtering, capacity checks, fixed owner slots, player/team assignment, and faction selection.
3. `random-map-zone-layout-water-underground-10184` - build runtime zone graph scaling, multi-level allocation, water/island policy, and deterministic zone footprint layout.
4. `random-map-terrain-transit-semantics-10184` - implement terrain palette choice, terrain normalization, underground/cave handling, water/coast rules, and transit-object route semantics.
5. `random-map-object-footprint-catalog-10184` - add original object metadata, footprints, action/passability masks, placement predicates, and object limit validation.
6. `random-map-town-mine-dwelling-placement-10184` - implement town/castle minimums/densities, neutral same-type behavior, seven mine categories, adjacent resources, and neutral dwellings.
7. `random-map-connection-guard-materialization-10184` - materialize normal route guards, special border-guard equivalents, wide-guard suppression, and connection failure diagnostics.
8. `random-map-monster-reward-bands-10184` - implement monster faction masks, strength scaling, treasure bands, reward objects, artifacts/spells/skills equivalents, and risk/reward reports.
9. `random-map-decoration-density-pass-10184` - implement terrain-biased decorative obstacle filler and density scoring without blocking required paths.
10. `random-map-roads-rivers-writeout-10184` - implement road/river overlays, generated map serialization, round-trip validation, and generated file/export boundaries.
11. `random-map-validation-batch-retry-10184` - add batch generation, retry/failure policy, deterministic regression checksums, and CI-friendly parity reports.
12. `random-map-skirmish-ui-save-replay-10184` - adopt validated generated maps into skirmish setup, UI, save/load, replay seed provenance, and player-facing retry/error flow.

## Immediate Next Slice

Start with `random-map-template-catalog-import-10184`. It is the correct next implementation slice because every downstream parity domain depends on a schema/catalog that can represent the extracted template grammar without losing fields.
