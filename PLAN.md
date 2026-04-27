# heroes-like Tactical Implementation Plan

Task: #10184  
Document role: tactical execution plan  
Source strategy: `project.md`  
Reset date: 2026-04-27

## Purpose

This plan turns the strategic phases in `project.md` into executable implementation slices.

Rules:
- Keep this document compact and worker-usable.
- Do not append worker logs or chronological history here.
- Reference detailed requirements in `docs/*.md` instead of copying them.
- Track operational state in `ops/progress.json`, not in this file.
- A slice is complete only when implementation and validation satisfy its referenced requirements.
- Documentation-only slices must be explicitly labeled as documentation-only.

## Current Phase

Current phase: **Phase 2 — Deep Production Foundation**.

Current strategic objective: rebuild the foundation needed before broad campaign/skirmish production, final screen polish, or playable-alpha claims.

Immediate workflow objective: regenerate clean planning/progress documents before restarting implementation workers.

## Slice Status Model

Each implementation slice should map to:

- `id`: stable slice id in `ops/progress.json`.
- `phase`: project phase.
- `sourceDocs`: requirement/spec docs under `docs/`.
- `implementationTargets`: expected systems/files/content/tooling.
- `validation`: repo checks, report scenes, smoke tests, or manual gates.
- `completionCriteria`: concrete evidence required before `completed`.

## Phase 0 — Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

### P0.1 Document model reset

id: `document-model-reset-10184`  
status intent: documentation/governance slice

Source docs:
- `project.md`
- `AGENTS.md`
- `archive/document-reset-2026-04-27/`

Implementation targets:
- Clean `project.md` strategic charter.
- Clean `PLAN.md` tactical plan.
- Regenerated `ops/progress.json` operational tracker.
- Optional progress helper/skill updates.

Validation:
- Documents exist in expected roles.
- `ops/progress.json` is valid JSON.
- Coding-agent onboarding no longer requires loading giant history files.

Completion criteria:
- `project.md`, `PLAN.md`, and `ops/progress.json` have distinct roles.
- Archived polluted originals remain available for reference.
- First real implementation slice can be selected without ambiguity.

### P0.2 Progress tracker regeneration

id: `progress-tracker-regeneration-10184`

Source docs:
- `project.md`
- this `PLAN.md`
- `AGENTS.md`

Implementation targets:
- `ops/progress.json`
- heroes-progress helper/skill if needed

Validation:
- `python3 -m json.tool ops/progress.json`
- progress helper can show current task and next task.
- All PLAN slices exist in tracker with initial status.

Completion criteria:
- Planned slices exist before implementation begins.
- Docs-ready and implementation-complete states are distinguishable.
- Current/next worker task is explicit.

## Phase 1 — Manual Scenario Proof

Goal: one real scenario can be completed manually in the live client.

Current state: River Pass manual gate is proof history, not current product readiness.

### P1.1 River Pass proof preservation

id: `river-pass-proof-preservation-10184`

Source docs:
- Archived plan/progress records.
- Existing smoke/manual play evidence.

Implementation targets:
- No new gameplay by default.
- Keep River Pass evidence referenced as baseline proof.

Validation:
- Existing scenario still loads through repo validation/smoke when relevant.

Completion criteria:
- River Pass is represented as completed proof history in tracker.
- It is not used to claim broad alpha/product readiness.

## Phase 2 — Deep Production Foundation

Goal: implement the production foundations needed before broad campaign/skirmish production or final polish.

### P2.1 World and faction identity implementation bridge

id: `world-faction-identity-implementation-bridge-10184`

Source docs:
- `docs/worldbuilding-foundation.md`
- `docs/factions-content-bible.md`
- `docs/concept-art-implementation-briefs.md`

Implementation targets:
- `content/factions.json`
- `content/heroes.json`
- `content/units.json`
- `content/towns.json`
- faction/town/scenario placement hooks as needed

Validation:
- `python3 tests/validate_repo.py`
- focused content validation for faction asymmetry and no shared-template regression.

Completion criteria:
- At least two faction identities are represented beyond placeholder scaffolds in content and live-flow surfaces.
- Requirements remain legally original and non-derivative.

### P2.2 Concept-art curation gate

id: `concept-art-curation-gate-10184`  
kind: documentation/decision gate

Source docs:
- `docs/concept-art-pipeline.md`
- `docs/concept-art-batch-001-review.md`
- `docs/concept-art-batch-002-review.md`
- `docs/concept-art-batch-003-review.md`
- `docs/concept-art-batch-004-review.md`
- `docs/concept-art-batch-005-review.md`
- `docs/concept-art-implementation-briefs.md`

Implementation targets:
- Curation/status doc only unless AcOrP selects an implementation brief.

Validation:
- Accepted/rejected/deferred studies are clearly listed.
- One next implementation brief track is selected or explicitly deferred.

Completion criteria:
- Art-direction decisions are usable by future content/visual implementation slices.
- No runtime asset import unless separately planned.

### P2.3 Economy/resource foundation implementation

id: `economy-resource-foundation-implementation-10184`

Source docs:
- `docs/economy-overhaul-foundation.md`
- `docs/economy-resource-schema-migration-plan.md`
- `docs/economy-resource-additive-schema-validator-plan.md`
- `docs/economy-capture-resource-loop-proof-plan.md`
- `docs/economy-capture-resource-loop-live-proof-report.md`
- `docs/economy-capture-resource-loop-manual-gate-review.md`

Implementation targets:
- Economy rule helpers.
- Optional resource registry only if selected by sub-slice.
- Resource-site capture/production reports and live loop surfaces.
- Market/cost migration only after explicit sub-slice approval.

Validation:
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --economy-resource-report`
- focused Godot report/smoke when runtime behavior changes.

Completion criteria:
- Economy changes are implemented in live rules or tooling, not just reported.
- `wood`/`timber`, rare resources, market caps, and save compatibility have explicit decisions before migration.

### P2.4 Overworld object and encounter foundation implementation

id: `overworld-object-encounter-foundation-implementation-10184`

Source docs:
- `docs/overworld-content-bible.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/overworld-object-schema-migration-plan.md`
- `docs/overworld-object-safe-additive-schema-plan.md`
- `docs/overworld-object-report-review-001.md`
- `docs/neutral-encounter-representation-plan.md`
- `docs/neutral-encounter-first-class-object-migration-plan.md`

Implementation targets:
- `content/map_objects.json`
- `content/resource_sites.json`
- scenario placement metadata
- map editor object tooling
- validator/report fixtures

Validation:
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --overworld-object-report`
- `python3 tests/validate_repo.py --neutral-encounter-report`
- map editor smoke when editor behavior changes.

Completion criteria:
- Object/encounter metadata supports real placement/tooling decisions.
- Broad pathing/body-tile/renderer adoption occurs only through explicit sub-slices.

### P2.5 Magic system foundation implementation

id: `magic-system-foundation-implementation-10184`

Source docs:
- `docs/magic-system-expansion-foundation.md`

Implementation targets:
- `content/spells.json`
- `scripts/core/SpellRules.gd`
- battle/adventure spell hooks as selected by sub-slices
- validation fixtures

Validation:
- `python3 tests/validate_repo.py`
- focused battle/overworld smoke or report when runtime spell behavior changes.

Completion criteria:
- Spell metadata and behavior support the planned school/category/tier direction.
- Battle/adventure magic changes are implemented and validated, not only documented.

### P2.6 Artifact system foundation implementation

id: `artifact-system-foundation-implementation-10184`

Source docs:
- `docs/artifact-system-expansion-foundation.md`

Implementation targets:
- `content/artifacts.json`
- `scripts/core/ArtifactRules.gd`
- reward/source tables if selected
- validation fixtures

Validation:
- `python3 tests/validate_repo.py`
- focused overworld/town/battle smoke where artifacts affect live flow.

Completion criteria:
- Artifact slots, rarity/family/set/source concepts are represented in implementable schema or runtime behavior.
- UI cues alone do not satisfy this slice.

### P2.7 Animation/event cue foundation implementation

id: `animation-event-cue-foundation-implementation-10184`

Source docs:
- `docs/animation-systems-foundation.md`

Implementation targets:
- animation/event cue catalog
- reduced-motion / fast-mode contract
- battle/town/overworld state-change hooks

Validation:
- repo validation
- focused scene smoke for any visual/runtime cue behavior

Completion criteria:
- Event/cue ids and playback policy exist as implementation contracts.
- No final art/VFX requirement unless selected later.

### P2.8 Strategic AI foundation implementation

id: `strategic-ai-foundation-implementation-10184`

Source docs:
- `docs/strategic-ai-foundation.md`
- `docs/strategic-ai-pressure-expansion-plan.md`
- `docs/strategic-ai-event-surfacing-plan.md`
- `docs/strategic-ai-hero-task-state-save-normalizer-preservation-plan.md`
- other strategic AI docs as referenced by sub-slices

Implementation targets:
- `scripts/core/EnemyTurnRules.gd`
- `scripts/core/EnemyAdventureRules.gd`
- focused AI report scenes under `tests/`

Validation:
- `python3 tests/validate_repo.py`
- relevant Godot AI report scenes
- no internal score/debug field leaks in public output

Completion criteria:
- AI improvements are implemented in rule/report harnesses or live behavior as selected.
- Save/schema/durable event changes require explicit sub-slices and rollback boundaries.

Current selected sub-slice:
- `strategic-ai-hero-task-state-save-normalizer-preservation-report-implementation-10184`

### P2.9 Terrain/editor/tooling foundation implementation

id: `terrain-editor-tooling-foundation-implementation-10184`

Source docs:
- `docs/screen-wireframes.md`
- terrain/editor archived notes and current content schemas

Implementation targets:
- terrain grammar/layers
- `OverworldMapView.gd`
- `MapEditorShell.gd`
- editor validation/export tooling

Validation:
- `python3 tests/validate_repo.py`
- `tests/map_editor_smoke.tscn`
- overworld visual smoke when map presentation changes

Completion criteria:
- Editor/tooling supports real scenario iteration.
- Stale `homm3-editor-restamp-behavior-10184` is completed, superseded, or re-scoped in progress tracking.

### P2.10 Random map generator foundation

id: `random-map-generator-foundation-10184`

Source docs:
- `project.md` Phase 2
- future random-map requirements doc when created

Implementation targets:
- deterministic map-generation rules/helpers
- constraints for terrain, towns, resources, encounters, roads, objectives, and fairness
- validation/report harnesses
- integration path for headless balance harness

Validation:
- generator report tests
- map validity checks
- seed determinism checks
- scenario load smoke for generated prototype maps when implemented

Completion criteria:
- Controlled prototype maps can be generated reproducibly.
- Generated maps satisfy minimum viability constraints for later simulation/balance testing.

## Phase 3 — Headless AI Agent Balance Harness

Goal: run scenarios, AI turns, economy loops, battles, and balance checks without graphics.

### P3.1 Headless simulation harness

id: `headless-agent-simulation-harness-10184`

Source docs:
- `project.md` Phase 3
- future harness requirements doc

Implementation targets:
- headless scenario runner
- AI turn runner
- economy loop runner
- battle resolver/sampler
- structured reports

Validation:
- deterministic seeded runs
- repeated simulation report
- failure summaries for invalid maps, impossible economies, runaway AI, and battle imbalance

Completion criteria:
- Agents can execute core loops through domain rules without scene graphics.
- Reports are actionable for balance and regression work.

### P3.2 Balance and regression report suite

id: `balance-regression-report-suite-10184`

Source docs:
- Phase 3 harness requirements
- economy/object/AI/random-map docs

Implementation targets:
- automated reports for faction balance, economy pressure, scenario viability, battle outcome distribution, and AI objective pressure

Validation:
- repeated run stability
- report output schema checks
- CI/local command documented

Completion criteria:
- Balance harness can guide content/system tuning before playable-alpha expansion.

## Phase 4 — Playable Alpha Baseline

Goal: a small coherent alpha playable without developer interpretation.

### P4.1 Alpha scenario set

id: `playable-alpha-scenario-set-10184`

Source docs:
- Phase 2 foundation outputs
- concept/economy/object/magic/artifact/AI docs as implemented

Implementation targets:
- multiple scenarios/skirmish setups
- at least two playable factions
- save/load and outcome loops

Validation:
- manual play gates
- smoke tests
- balance harness reports

Completion criteria:
- Repeated play works without debug/report interpretation.

### P4.2 Alpha UX and onboarding pass

id: `playable-alpha-ux-onboarding-10184`

Source docs:
- `docs/screen-wireframes.md`
- manual play findings

Implementation targets:
- main menu, overworld, town, battle, outcome UX
- onboarding/help where needed

Validation:
- manual play review
- focused smoke tests

Completion criteria:
- Major surfaces are understandable without debug dashboards.

## Phase 5 — Production Alpha Layer

Goal: expand alpha into a production-shaped game slice.

### P5.1 Production alpha content expansion

id: `production-alpha-content-expansion-10184`

Implementation targets:
- more factions/content through established systems
- campaign/skirmish expansion
- difficulty and AI stability

Validation:
- balance harness
- manual play
- repo validation/smoke suite

Completion criteria:
- Content pipeline and gameplay loops support broader production.

### P5.2 Packaging/settings/performance baseline

id: `production-alpha-packaging-settings-performance-10184`

Implementation targets:
- packaging path
- settings/accessibility baseline
- performance budgets and checks

Validation:
- packaged build smoke
- settings persistence checks
- performance sampling

Completion criteria:
- Production-alpha distribution risks are known and tracked.

## Phase 6 — Broad Production Breadth

Goal: broad original fantasy strategy package with classic Heroes-style systemic breadth and replayability.

### P6.1 Broad faction/content breadth

id: `broad-production-faction-content-breadth-10184`

Completion criteria:
- Multiple original factions, towns, unit ladders, spells, artifacts, neutral sites, handcrafted maps, campaign structure, and reliable AI are implemented through working loops.

### P6.2 Broad map/campaign/replayability breadth

id: `broad-production-map-campaign-replayability-10184`

Completion criteria:
- Handcrafted maps, random maps/skirmish replayability, campaign complexity, strategic pressure, and polish are production-shaped.

## Immediate Next Step

Before any gameplay/system implementation resumes:

1. Complete the clean `project.md` review.
2. Complete this tactical `PLAN.md` review.
3. Generate `ops/progress.json` from this plan with all slices initially represented.
4. Use the progress interface to select the next implementation slice.

Do not start another implementation worker until these steering documents are accepted enough to prevent unanchored work.
