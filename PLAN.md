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
it reaches full parity with `scripts/core/RandomMapGeneratorRules.gd`. The current
completed native children cover deterministic identity, terrain/grid output, and
foundation zone/player-start output only. The next pending child is
`native-rmg-road-river-network-10184`.

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
- `native-rmg-package-session-adoption-10184`: package/session integration behind explicit adapters after parity gates pass; no save version bump or call-site replacement before this slice.
- `native-rmg-full-parity-gate-10184`: final gate proving terrain, objects, roads, rivers, towns, guards, zones/player starts, validation/provenance, comparison harness, package/session integration, Linux, and Windows all pass before broad parity is claimed.

Until `native-rmg-full-parity-gate-10184` completes, native RMG remains incomplete and `RandomMapGeneratorRules.gd` remains authoritative for live generated skirmish gameplay.

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
