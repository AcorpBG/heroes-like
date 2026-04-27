# heroes-like Tactical Implementation Plan

Task: #10184
Document role: tactical execution plan
Source strategy: `project.md`
Reset date: 2026-04-27
Reconciliation sources: `archive/document-reset-2026-04-27/PLAN.md`, `archive/document-reset-2026-04-27/progress.json`, `docs/*.md`

## Purpose

This plan turns the strategic charter in `project.md` into executable implementation slices. It is not a history log, worker diary, or progress tracker.

Rules:
- Reference detailed requirements in `docs/*.md` instead of copying them.
- Track operational state in `ops/progress.json`, not here.
- A slice is complete only when implementation and validation satisfy its referenced requirements.
- Documentation-only and report-only slices must stay distinct from implemented gameplay/system/content completion.
- Baseline repository checks catch regressions; they do not prove a slice is complete.
- Do not continue ad hoc UI cue work unless a source document and selected slice explicitly justify it.

## Current Phase

Current phase: **Phase 2 - Deep Production Foundation**.

Current tactical objective: reconcile planning around implementation obligations, then resume bounded foundation work. The archived plan/progress show many completed docs, reports, scaffolds, and cue slices, but completion claims must now be mapped to implementation reality.

Selected next implementation candidate after PLAN review: `strategic-ai-hero-task-state-save-normalizer-preservation-report-implementation-10184`.

## Slice Status Model

Each implementation slice maps to a progress entry with:

- `id`: stable slice id.
- `phase`: project phase.
- `purpose`: why the slice exists.
- `sourceDocs`: source requirements or evidence docs.
- `implementationTargets`: files, systems, content, tooling, or reports expected to change.
- `baselineChecks`: generic health checks required before completion.
- `sliceEvidence`: focused proof that the slice requirement was met.
- `completionCriteria`: objective completion bar.
- `nonGoals`: explicit boundaries when scope is risky.

Recommended progress states:
- `pending`: planned, not started.
- `in_progress`: active implementation or review.
- `blocked`: cannot proceed; blocker must be named.
- `completed`: implementation and slice evidence meet the criteria.
- `docs_ready`: requirement/design/planning docs exist, but implementation is not done.
- `report_only`: diagnostic or review evidence exists; live/product behavior is not implemented unless explicitly stated.
- `deferred`: intentionally delayed by sequencing or risk.
- `superseded`: old direction replaced by this plan or a later accepted decision.

## Reconciled Implementation-Obligation Inventory

This inventory summarizes obligations found in `docs/*.md` and the archived plan/progress. It is the basis for the slices below.

### Governance And Manual Proof

Implemented:
- River Pass was manually proven historically for launch, objective flow, town usability, battle usability, save/resume, victory/defeat routing, and clean completion.
- Current repo has real Godot 4 systems, JSON content, save/load, overworld, town, battle, outcome, campaign, AI, validation, and smoke surfaces.

Docs-ready/report-only:
- `project.md` is now the strategic charter.
- Current planning reset is in progress and this PLAN is the tactical plan.
- `docs/progress-implementation-audit-2026-04-27.md` is an audit/reconciliation report only.

Pending:
- Regenerate `ops/progress.json` from reviewed PLAN slices, without inheriting polluted completion semantics.

Superseded/deferred:
- The archived polluted `project.md`, `PLAN.md`, and `progress.json` are reference inputs only.
- River Pass proof must not be used to claim playable alpha or product breadth.

### World, Factions, And Concept Art

Implemented:
- JSON content breadth exists: six factions, many heroes/units/buildings/towns/scenarios/campaigns.
- First concept-art implementation briefs exist for Embercourt, Mireclaw, and core overworld object classes.

Docs-ready/report-only:
- `docs/worldbuilding-foundation.md` and `docs/factions-content-bible.md` are design sources, not implemented JSON proof.
- `docs/concept-art-pipeline.md`, concept-art batch reviews, and `docs/concept-art-implementation-briefs.md` define direction and curation evidence. Generated PNGs remain external.

Pending:
- Migrate selected faction identity into mechanics, towns, hero/unit hooks, scenario placement, AI pressure, and player-readable surfaces.
- Select accepted/deferred concept tracks before runtime asset ingestion.

Deferred:
- Production asset import, final visual direction, generated PNG ingestion, and broad art replacement.

### Economy And Resources

Implemented:
- Current live stockpile economy uses `gold`, `wood`, and `ore`.
- River Pass signal-yard economy proof passed through current systems.
- Validator/report scaffolding exists for opt-in economy/resource analysis.
- Strategic AI focused reports value selected economy sites.

Docs-ready/report-only:
- `docs/economy-overhaul-foundation.md`, `docs/economy-resource-schema-migration-plan.md`, and `docs/economy-resource-additive-schema-validator-plan.md` are planning sources.
- `docs/economy-capture-resource-loop-live-proof-report.md` and manual gate review prove one narrow current-systems path, not a full economy overhaul.

Pending:
- Decide and implement resource registry policy.
- Resolve `wood`/`timber` compatibility.
- Stage rare-resource activation, market caps, and faction-biased costs only through explicit migration slices.

Deferred:
- Full multi-resource economy migration, save migration, broad cost rebalance, and market overhaul.

### Overworld Objects And Neutral Encounters

Implemented:
- `content/map_objects.json`, `content/resource_sites.json`, and `content/neutral_dwellings.json` have broad scaffolds.
- `safe_metadata_bundle_001` is runtime-inactive metadata on eight map objects.
- `neutral_encounter_representation_bundle_001` and `neutral_encounter_first_class_object_bundle_001` are authored for three placements/objects.
- Validator/report fixtures exist for object and neutral encounter compatibility checks.
- Map editor UI surfaces taxonomy metadata.

Docs-ready/report-only:
- `docs/overworld-content-bible.md`, `docs/overworld-object-taxonomy-density.md`, schema migration plans, safe additive plan, and report reviews define staged migration constraints.
- Neutral encounter representation and first-class object docs define the target, report evidence, and paused migration boundary.

Pending:
- Implement object metadata only when it supports live placement, editor authoring, AI valuation, renderer/pathing adoption, or scenario authoring.

Deferred:
- Broad object migration, true `body_tiles`, approach offsets, pathing/occupancy adoption, renderer sprite ingestion, route effects, animation cue ids, editor placement enforcement, save-state adoption.
- Neutral encounter migration beyond the first three authored records.

### Magic, Artifacts, And Animation

Implemented:
- `content/spells.json`, `content/artifacts.json`, `SpellRules.gd`, and `ArtifactRules.gd` exist.
- Several UI/smoke surfaces expose spell, artifact, status, and battle timing cues.

Docs-ready/report-only:
- `docs/magic-system-expansion-foundation.md`, `docs/artifact-system-expansion-foundation.md`, and `docs/animation-systems-foundation.md` are design/technical planning sources.

Pending:
- Implement expanded spell schools/categories, adventure-map magic, artifact slots/families/sets/source tables, AI valuation, economy/spell hooks, and animation event contracts through bounded slices.

Deferred:
- Treating UI cues as artifact/magic/animation implementation.
- Final VFX/audio and production animation polish before event contracts and cue catalogs exist.

### Strategic AI

Implemented:
- `EnemyAdventureRules.gd` and `EnemyTurnRules.gd` contain real target, pressure, town governor, raid, event, commander-role, and report helpers.
- Focused reports/gates have passed for economy pressure, event surfacing, town governor pressure, faction personality evidence, strategy config audit, site control, Glassroad defense, commander-role state, commander-role turn transcript, and hero task-state boundary.

Docs-ready/report-only:
- `docs/strategic-ai-foundation.md` is the broad design source.
- Commander-role and hero-task-state docs define boundaries and report contracts, not live AI task behavior.

Pending:
- `strategic-ai-hero-task-state-save-normalizer-preservation-report-implementation-10184` is the next selected report-only implementation candidate.

Deferred:
- Live commander-role behavior, live AI hero task-state adoption, schema writes, save migration, durable event logs, defense-specific durable state, broad AI rewrite, and coefficient tuning.

### Terrain, Renderer, Editor, And UI

Implemented:
- Terrain grammar/layers, overworld renderer, and map editor have substantial foundation work.
- Compact UI cue surfaces exist across menu, overworld, town, battle, outcome, and editor.

Docs-ready/report-only:
- `docs/screen-wireframes.md` defines visual/screen composition targets.
- The audit identifies later UI cue drift.

Pending:
- Reconcile stale terrain/editor progress item `homm3-editor-restamp-behavior-10184` as completed, superseded, or re-scoped during tracker regeneration.

Deferred/superseded:
- `overworld-artifact-check-cue-10184` is stopped/superseded patch evidence only.
- The ad hoc compact UI cue stream is paused.
- UI polish must not substitute for missing mechanics, content migration, AI behavior, or tooling.

## Phase 0 - Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

### P0.1 Document Model Reset

id: `document-model-reset-10184`
phase: `phase-0-prototype-reality-and-governance`
purpose: Maintain distinct strategic, tactical, and operational documents after the reset.

sourceDocs:
- `project.md`
- `AGENTS.md`
- `archive/document-reset-2026-04-27/project.md`
- `archive/document-reset-2026-04-27/PLAN.md`
- `archive/document-reset-2026-04-27/progress.json`
- `docs/progress-implementation-audit-2026-04-27.md`

implementationTargets:
- `project.md` remains concise strategic charter.
- `PLAN.md` becomes this reconciled tactical plan.
- `ops/progress.json` is regenerated later from reviewed PLAN slices.
- Progress helper usage is documented if needed.

baselineChecks:
- `test -f project.md`
- `test -f PLAN.md`
- `python3 -m json.tool ops/progress.json` after progress regeneration only.

sliceEvidence:
- A worker can identify current phase, candidate next slice, and source docs without loading archived progress history.
- This plan distinguishes docs-ready/report-only from implemented completion.

completionCriteria:
- `project.md`, `PLAN.md`, and `ops/progress.json` have distinct roles.
- Archived polluted files remain reference-only.
- No gameplay implementation is performed by this planning slice.

nonGoals:
- Do not regenerate `ops/progress.json` during PLAN reconciliation unless separately selected.
- Do not edit gameplay code, tests, content JSON, or archived files.

### P0.2 Progress Tracker Regeneration

id: `progress-tracker-regeneration-10184`
phase: `phase-0-prototype-reality-and-governance`
purpose: Rebuild `ops/progress.json` from reviewed PLAN slices.

sourceDocs:
- `project.md`
- `PLAN.md`
- `AGENTS.md`
- `archive/document-reset-2026-04-27/progress.json`

implementationTargets:
- `ops/progress.json`
- Optional progress helper metadata if required by the existing workflow.

baselineChecks:
- `python3 -m json.tool ops/progress.json`
- Progress helper status command, using the executable wrapper directly if the `.py` wrapper remains a bash script.

sliceEvidence:
- All reviewed PLAN slice ids exist in the tracker.
- Tracker states use `pending`, `completed`, `docs_ready`, `report_only`, `deferred`, `blocked`, or `superseded` according to implementation reality.
- Current and next tasks are explicit.

completionCriteria:
- Planned slices exist before implementation resumes.
- Documentation readiness and implementation completion are distinguishable.
- Stale entries are reconciled, especially `homm3-editor-restamp-behavior-10184`, stopped UI cue work, and the selected AI normalizer proof.

nonGoals:
- Do not mark docs/report-only obligations as implemented.
- Do not copy all archived tracker history into the new tracker.

## Phase 1 - Manual Scenario Proof

Goal: preserve the historical one-scenario proof without overstating product readiness.

### P1.1 River Pass Proof Preservation

id: `river-pass-proof-preservation-10184`
phase: `phase-1-manual-scenario-proof`
purpose: Preserve River Pass as proof history and regression baseline.

sourceDocs:
- `archive/document-reset-2026-04-27/PLAN.md`
- `archive/document-reset-2026-04-27/progress.json`
- River Pass evidence referenced by the archived plan.

implementationTargets:
- Progress metadata only, unless a later regression slice is selected.
- Existing scenario and smoke evidence remain referenced as historical proof.

baselineChecks:
- Repository validation and relevant scenario smoke only when a later implementation slice touches River Pass.

sliceEvidence:
- Tracker records River Pass proof as historical completed evidence.
- Current plan states that River Pass does not prove alpha, broad product depth, or HoMM parity.

completionCriteria:
- River Pass remains available as a baseline manual-play scenario.
- Future workers do not use River Pass completion to skip Phase 2 foundation work.

nonGoals:
- No new River Pass mechanics/content in this preservation slice.

## Phase 2 - Deep Production Foundation

Goal: implement the production foundations needed before broad campaign/skirmish production, final screen polish, or playable-alpha claims.

### P2.1 World And Faction Identity Implementation Bridge

id: `world-faction-identity-implementation-bridge-10184`
phase: `phase-2-deep-production-foundation`
purpose: Carry accepted world/faction identity into playable systems instead of leaving it only in design docs and broad JSON scaffolds.

sourceDocs:
- `docs/worldbuilding-foundation.md`
- `docs/factions-content-bible.md`
- `docs/concept-art-implementation-briefs.md`
- `docs/progress-implementation-audit-2026-04-27.md`

implementationTargets:
- `content/factions.json`
- `content/heroes.json`
- `content/units.json`
- `content/towns.json`
- scenario placement hooks and faction-specific AI/economy hooks as selected by sub-slices.

baselineChecks:
- `python3 tests/validate_repo.py`
- Focused JSON/content validation for touched files.

sliceEvidence:
- Focused content diff/report shows at least two factions represented beyond shared templates in mechanics, content hooks, scenario use, or AI pressure.
- Live or tooling surface demonstrates the selected identity hook.

completionCriteria:
- At least two factions have implemented identity hooks that affect real player or AI decisions.
- Requirements remain original and non-derivative.

nonGoals:
- No broad faction rebalance or asset import without a sub-slice.
- No claim that the six-faction scaffold is full faction implementation.

### P2.2 Concept-Art Curation Gate

id: `concept-art-curation-gate-10184`
phase: `phase-2-deep-production-foundation`
purpose: Convert external concept-study evidence into accepted/deferred implementation direction.

sourceDocs:
- `docs/concept-art-pipeline.md`
- `docs/concept-art-batch-001-review.md`
- `docs/concept-art-batch-002-review.md`
- `docs/concept-art-batch-003-review.md`
- `docs/concept-art-batch-004-review.md`
- `docs/concept-art-batch-005-review.md`
- `docs/concept-art-implementation-briefs.md`

implementationTargets:
- Curation/status document or brief update only unless an explicit asset implementation slice follows.

baselineChecks:
- Referenced concept review docs exist.
- Markdown sanity check.

sliceEvidence:
- Accepted, rejected, and deferred studies are clearly listed.
- One next implementation brief track is selected or explicitly deferred.

completionCriteria:
- Future visual/content workers can identify which concept directions are approved for implementation.
- Generated PNGs remain external unless a later asset-ingestion slice approves import.

nonGoals:
- No runtime asset import.
- No renderer replacement.

### P2.3 Economy Resource Foundation Implementation

id: `economy-resource-foundation-implementation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Move from narrow current economy proof toward a staged production economy without unsafe migration.

sourceDocs:
- `docs/economy-overhaul-foundation.md`
- `docs/economy-resource-schema-migration-plan.md`
- `docs/economy-resource-additive-schema-validator-plan.md`
- `docs/economy-capture-resource-loop-proof-plan.md`
- `docs/economy-capture-resource-loop-live-proof-report.md`
- `docs/economy-capture-resource-loop-manual-gate-review.md`

implementationTargets:
- Economy rule helpers.
- Resource-site capture/production reports.
- Optional resource registry only if a sub-slice selects it.
- Town cost/recruitment/market behavior only through explicit migration sub-slices.

baselineChecks:
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --economy-resource-report`

sliceEvidence:
- Focused economy report or live proof demonstrates the selected requirement.
- Runtime behavior changes include focused smoke/manual evidence.
- Resource id and save compatibility decisions are recorded before migration.

completionCriteria:
- Economy changes are implemented in live rules or tooling, not only described.
- `wood`/`timber`, rare resources, market caps, and save compatibility have explicit decisions before production migration.

nonGoals:
- No full multi-resource migration in a generic foundation slice.
- No `SAVE_VERSION` bump, market overhaul, or broad rebalance without explicit approval.

### P2.4 Overworld Object And Neutral Encounter Foundation

id: `overworld-object-encounter-foundation-implementation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Convert object/encounter taxonomy into useful runtime, tooling, or validation behavior only where it improves implementation.

sourceDocs:
- `docs/overworld-content-bible.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/overworld-object-schema-migration-plan.md`
- `docs/overworld-object-safe-additive-schema-plan.md`
- `docs/overworld-object-report-review-001.md`
- `docs/neutral-encounter-representation-plan.md`
- `docs/neutral-encounter-additive-validator-report-plan.md`
- `docs/neutral-encounter-representation-bundle-001-plan.md`
- `docs/neutral-encounter-first-class-object-migration-plan.md`
- `docs/neutral-encounter-first-class-object-bundle-001-plan.md`
- neutral encounter report review docs.

implementationTargets:
- `content/map_objects.json`
- `content/resource_sites.json`
- `content/scenarios.json` placement metadata.
- Map editor object tooling.
- Validator/report fixtures.

baselineChecks:
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --overworld-object-report`
- `python3 tests/validate_repo.py --neutral-encounter-report`

sliceEvidence:
- Object/neutral report demonstrates selected metadata, warning, migration, or validation requirement.
- Editor or live placement behavior demonstrates the requirement when behavior changes.

completionCriteria:
- Object/encounter metadata supports real placement, tooling, AI, renderer, or scenario-authoring decisions.
- Remaining legacy/direct placements are intentionally tracked as compatibility warnings until selected.

nonGoals:
- No broad warning-count cleanup as an end in itself.
- No pathing/body-tile/approach/renderer/save adoption without explicit sub-slices.

### P2.5 Magic System Foundation Implementation

id: `magic-system-foundation-implementation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Implement selected pieces of the expanded magic model in rules and live flow.

sourceDocs:
- `docs/magic-system-expansion-foundation.md`

implementationTargets:
- `content/spells.json`
- `scripts/core/SpellRules.gd`
- battle spell hooks.
- adventure spell hooks.
- validation fixtures/reports as needed.

baselineChecks:
- `python3 tests/validate_repo.py`
- Relevant battle/overworld smoke for touched flows.

sliceEvidence:
- Focused battle or overworld report/smoke proves selected spell metadata or behavior.
- AI or UI behavior is covered only when the selected magic requirement touches it.

completionCriteria:
- Spell metadata and behavior support the planned school/category/tier direction for the selected slice.
- Battle/adventure magic is implemented and validated, not only documented.

nonGoals:
- No broad spell dump without live behavior and validation.
- No UI-only cue treated as magic system implementation.

### P2.6 Artifact System Foundation Implementation

id: `artifact-system-foundation-implementation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Implement selected artifact taxonomy and behavior beyond narrow current item records.

sourceDocs:
- `docs/artifact-system-expansion-foundation.md`

implementationTargets:
- `content/artifacts.json`
- `scripts/core/ArtifactRules.gd`
- reward/source tables.
- hero equipment/inventory surfaces.
- validation fixtures/reports as needed.

baselineChecks:
- `python3 tests/validate_repo.py`
- Relevant overworld/town/battle smoke for touched flows.

sliceEvidence:
- Focused report or smoke proves selected artifact slots, rarity/family/set/source, spell, economy, or AI hook.

completionCriteria:
- Artifact changes affect implementable schema or runtime behavior.
- Reward and equipment implications are understandable in live or tooling surfaces.

nonGoals:
- No artifact cue polish as a substitute for taxonomy/source/behavior work.
- No generated asset import.

### P2.7 Animation And Event Cue Foundation

id: `animation-event-cue-foundation-implementation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Establish event/cue contracts for readable state changes before final visual polish.

sourceDocs:
- `docs/animation-systems-foundation.md`
- `docs/screen-wireframes.md`

implementationTargets:
- Animation/event cue catalog.
- Reduced-motion and fast-mode policy.
- Battle, town, overworld, object, and UI state-change hooks as selected.

baselineChecks:
- `python3 tests/validate_repo.py`
- Focused scene smoke for touched surfaces.

sliceEvidence:
- Report or smoke proves selected event ids, playback policy, and reduced-motion/fast-mode behavior.

completionCriteria:
- Event/cue ids and playback policy exist as implementation contracts.
- Selected state changes become more readable without panel-heavy dashboard composition.

nonGoals:
- No final VFX/audio requirement.
- No broad screen polish without event contract work.

### P2.8 Strategic AI Foundation Continuation

id: `strategic-ai-foundation-continuation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Continue strategic AI through report-backed, bounded behavior or schema gates.

sourceDocs:
- `docs/strategic-ai-foundation.md`
- `docs/strategic-ai-economy-pressure-slice-plan.md`
- `docs/strategic-ai-event-surfacing-plan.md`
- `docs/strategic-ai-pressure-expansion-plan.md`
- `docs/strategic-ai-hero-task-state-boundary-plan.md`
- `docs/strategic-ai-hero-task-state-report-fixture-plan.md`
- `docs/strategic-ai-hero-task-state-save-normalizer-preservation-plan.md`
- Strategic AI implementation reports and gate reviews.

implementationTargets:
- `scripts/core/EnemyTurnRules.gd`
- `scripts/core/EnemyAdventureRules.gd`
- focused AI report scenes under `tests/`
- implementation report docs when a report-only slice is selected.

baselineChecks:
- `python3 tests/validate_repo.py`
- Focused Godot report scene for the selected AI slice.
- `git diff --check`

sliceEvidence:
- Relevant AI report prints the expected marker and passes failure checks.
- Public/player-facing surfaces are checked for internal score/debug leaks when applicable.

completionCriteria:
- AI improvements are implemented in rule/report harnesses or live behavior as selected.
- Save/schema/durable event changes occur only through explicit sub-slices and rollback boundaries.

nonGoals:
- No coefficient tuning unless a report or manual gate identifies a concrete defect.
- No live commander-role behavior, live AI hero tasks, save migration, durable event logs, production JSON edits, pathing, renderer, or UI composition changes unless explicitly selected.

#### P2.8a Hero Task-State Save-Normalizer Preservation Report

id: `strategic-ai-hero-task-state-save-normalizer-preservation-report-implementation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Prove optional future `enemy_states[].hero_task_state` can be preserved/normalized when present while old saves remain absent.

sourceDocs:
- `docs/strategic-ai-hero-task-state-save-normalizer-preservation-plan.md`
- `docs/strategic-ai-hero-task-state-report-gate-review.md`
- `docs/strategic-ai-hero-task-state-boundary-plan.md`

implementationTargets:
- Narrow report-only helper in or near `EnemyTurnRules.gd`.
- Explicit preservation branch in `EnemyTurnRules.normalize_enemy_states(...)` only for already-present synthetic optional fields.
- Focused Godot report scene, expected marker `AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT`.
- Implementation report doc after validation.

baselineChecks:
- `python3 tests/validate_repo.py`
- `git diff --check`

sliceEvidence:
- Report reviews old-save absence, valid board preservation, explicit empty board, malformed state tolerance, unknown field sanitization, SaveService boundary, and commander roster continuity.
- `SessionStateStore.SAVE_VERSION` remains unchanged.

completionCriteria:
- Missing `hero_task_state` stays missing.
- Valid synthetic optional task boards are normalized only when explicitly present.
- Malformed/unknown task state does not corrupt enemy state.
- `SaveService` remains a payload/version boundary and gains no AI task semantics.

nonGoals:
- No live task-state producer.
- No disk save writes, schema adoption, save migration, `SAVE_VERSION` bump, durable logs, target selection changes, raid movement changes, town-governor changes, coefficient tuning, production JSON edits, pathing/renderer/editor changes, or UI output.

### P2.9 Terrain, Renderer, And Editor Tooling Foundation

id: `terrain-editor-tooling-foundation-implementation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Keep map presentation and editor tooling usable for scenario iteration without mistaking prototypes for final art.

sourceDocs:
- `docs/screen-wireframes.md`
- `docs/progress-implementation-audit-2026-04-27.md`
- archived terrain/editor plan/progress entries.

implementationTargets:
- `content/terrain_grammar.json`
- `content/terrain_layers.json`
- `scenes/overworld/OverworldMapView.gd`
- `scenes/editor/MapEditorShell.gd`
- editor validation/export tooling.

baselineChecks:
- `python3 tests/validate_repo.py`
- `godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/map_editor_smoke.tscn` when editor behavior changes.
- relevant overworld visual smoke when renderer behavior changes.

sliceEvidence:
- Map editor smoke proves selected editor/tooling behavior.
- Overworld visual smoke proves selected map presentation behavior.

completionCriteria:
- Editor/tooling supports real scenario iteration.
- Stale `homm3-editor-restamp-behavior-10184` is completed, superseded, or re-scoped in tracker regeneration.

nonGoals:
- No use of local reference/prototype terrain as shippable art.
- No broad pathing/occupancy or renderer asset migration without explicit slice.

### P2.10 Random Map Generator Foundation

id: `random-map-generator-foundation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add a deterministic random map generator foundation for scenario prototyping, balance harness input, and later skirmish replayability.

sourceDocs:
- `project.md`
- future random-map requirements doc when created.
- economy, object, terrain/editor, faction, and AI docs as dependencies.

implementationTargets:
- Deterministic map-generation rules/helpers.
- Constraints for terrain, towns, roads, resources, encounters, guards, objectives, and fairness.
- Generator validation/report harness.
- Integration path for Phase 3 headless balance harness.

baselineChecks:
- `python3 tests/validate_repo.py`
- Generator report command exits cleanly.

sliceEvidence:
- Seed determinism checks pass.
- Generated map validity checks prove minimum viability constraints.
- Scenario load smoke proves generated prototype maps load once runtime integration is selected.

completionCriteria:
- Controlled prototype maps can be generated reproducibly.
- Generated maps satisfy minimum constraints for later simulation and balance testing.

nonGoals:
- No claim of finished skirmish RMG.
- No broad content migration hidden inside generator work.
- No generated map use in campaign/alpha until validated by later slices.

## Phase 3 - Headless AI Agent Balance Harness

Goal: run scenarios, AI turns, economy loops, battles, and balance checks without graphics.

### P3.1 Headless Simulation Harness

id: `headless-agent-simulation-harness-10184`
phase: `phase-3-headless-ai-agent-balance-harness`
purpose: Execute core loops through domain rules faster than manual UI play.

sourceDocs:
- `project.md`
- future harness requirements doc.
- Phase 2 economy/object/AI/random-map outputs.

implementationTargets:
- Headless scenario runner.
- AI turn runner.
- Economy loop runner.
- Battle resolver/sampler.
- Structured report output.

baselineChecks:
- Harness command exits cleanly.
- `python3 tests/validate_repo.py`

sliceEvidence:
- Deterministic seeded runs are reproducible.
- Repeated simulation report exposes scenario viability, economy pressure, AI behavior, battle outcomes, and failure summaries.

completionCriteria:
- Headless agents can execute core loops through domain rules without scene graphics.
- Reports identify invalid maps, impossible economies, runaway AI, battle imbalance, and regression failures.

nonGoals:
- Do not replace manual play gates.
- Do not make reports player-facing UI.

### P3.2 Balance And Regression Report Suite

id: `balance-regression-report-suite-10184`
phase: `phase-3-headless-ai-agent-balance-harness`
purpose: Turn headless simulation into actionable balance and regression signals.

sourceDocs:
- Phase 3 harness requirements.
- Phase 2 economy/object/AI/random-map docs and reports.

implementationTargets:
- Reports for faction balance, economy pressure, scenario viability, battle outcome distribution, AI objective pressure, and save/replay stability.

baselineChecks:
- Report command exits cleanly.
- Report schema checks pass.

sliceEvidence:
- Repeated run stability is demonstrated.
- Output is documented and usable by implementation workers.

completionCriteria:
- Balance harness can guide content/system tuning before playable-alpha expansion.

nonGoals:
- No automatic tuning loop until reporting is trusted.

## Phase 4 - Playable Alpha Baseline

Goal: a small coherent alpha playable without developer interpretation.

### P4.1 Alpha Scenario Set

id: `playable-alpha-scenario-set-10184`
phase: `phase-4-playable-alpha-baseline`
purpose: Build multiple playable scenarios/skirmish setups from completed foundation systems.

sourceDocs:
- Completed Phase 2 outputs.
- Phase 3 harness reports.
- scenario/campaign requirements created later.

implementationTargets:
- Multiple scenarios/skirmish setups.
- At least two meaningfully playable factions.
- Save/load and outcome loops.
- AI pressure and economy viability.

baselineChecks:
- Core repo validation.
- relevant Godot smoke tests.
- balance harness reports when available.

sliceEvidence:
- Manual play gates prove scenarios are playable without developer interpretation.
- Harness reports support scenario/faction viability.

completionCriteria:
- Repeated play works without debug/report interpretation.
- At least two factions are meaningfully distinct in live flow.

nonGoals:
- No alpha claim based on content breadth alone.

### P4.2 Alpha UX And Onboarding Pass

id: `playable-alpha-ux-onboarding-10184`
phase: `phase-4-playable-alpha-baseline`
purpose: Make major player-facing surfaces understandable without debug dashboards.

sourceDocs:
- `docs/screen-wireframes.md`
- manual play findings from alpha scenario set.

implementationTargets:
- main menu, overworld, town, battle, outcome, save/load, and help/onboarding surfaces.

baselineChecks:
- Relevant UI smoke checks.
- `git diff --check`

sliceEvidence:
- Manual play review proves UX/onboarding requirements.
- Focused smoke tests cover implemented flows.

completionCriteria:
- Major surfaces are understandable and scenery/play-surface-first.

nonGoals:
- No panel-heavy dashboard composition.
- No cue stream without prioritized UX gaps.

## Phase 5 - Production Alpha Layer

Goal: expand alpha into a production-shaped game slice.

### P5.1 Production Alpha Content Expansion

id: `production-alpha-content-expansion-10184`
phase: `phase-5-production-alpha-layer`
purpose: Expand content through established systems after the alpha baseline holds.

sourceDocs:
- Completed Phase 2-4 outputs.
- future production-alpha content requirements.

implementationTargets:
- more factions/content through established systems.
- campaign/skirmish expansion.
- difficulty and AI stability.

baselineChecks:
- Repo validation and smoke suite.
- balance harness reports.

sliceEvidence:
- Expanded content works through established systems in manual and headless validation.

completionCriteria:
- Content pipeline and gameplay loops support broader production.

nonGoals:
- No content dump that bypasses validation or live-flow proof.

### P5.2 Packaging, Settings, Accessibility, And Performance Baseline

id: `production-alpha-packaging-settings-performance-10184`
phase: `phase-5-production-alpha-layer`
purpose: Establish production-alpha distribution and runtime quality gates.

sourceDocs:
- future packaging/settings/accessibility/performance requirements.

implementationTargets:
- packaging path.
- settings/accessibility baseline.
- performance budgets and checks.

baselineChecks:
- Packaged build command exits cleanly when packaging is selected.
- settings persistence checks.

sliceEvidence:
- Packaged build smoke, settings checks, accessibility review, and performance sampling prove the selected requirement.

completionCriteria:
- Production-alpha distribution risks are known, tested, and tracked.

nonGoals:
- No release claim.

## Phase 6 - Broad Production Breadth

Goal: expand into a broad original fantasy strategy package with systemic breadth, density, and replayability.

### P6.1 Broad Faction And Content Breadth

id: `broad-production-faction-content-breadth-10184`
phase: `phase-6-broad-production-breadth`
purpose: Build broad original faction, unit, town, spell, artifact, neutral site, and campaign content through proven systems.

sourceDocs:
- Completed foundation/alpha docs and future production requirements.

implementationTargets:
- Multiple original factions.
- Towns, unit ladders, spells, artifacts, neutral sites, handcrafted maps, campaign structure, and reliable AI.

baselineChecks:
- Full validation/smoke/harness suite.

sliceEvidence:
- Broad content works through live play, headless reports, and content validation.

completionCriteria:
- Breadth is implemented through playable systems and validated pipelines.

nonGoals:
- No parity claim based on raw record counts.

### P6.2 Broad Map, Campaign, And Replayability Breadth

id: `broad-production-map-campaign-replayability-10184`
phase: `phase-6-broad-production-breadth`
purpose: Expand map/campaign/skirmish/replayability depth after core breadth is reliable.

sourceDocs:
- Completed RMG, harness, alpha, and production content outputs.

implementationTargets:
- Handcrafted maps.
- random-map/skirmish replayability.
- campaign complexity.
- strategic pressure and polish.

baselineChecks:
- Full validation/smoke/harness suite.

sliceEvidence:
- Manual and headless validation prove replayability, difficulty, and scenario quality.

completionCriteria:
- Map/campaign/replayability breadth is production-shaped.

nonGoals:
- No late breadth work before foundational systems are validated.

## Progress.json Generation Notes

After PLAN review, regenerate `ops/progress.json` from this plan instead of editing archived progress history into place.

Generation rules:
- Create one tracker entry for every PLAN slice id.
- Preserve the current phase as `phase-2-deep-production-foundation`.
- Set `document-model-reset-10184` and this PLAN reconciliation as completed only if review accepts this document.
- Set `progress-tracker-regeneration-10184` to pending until the tracker is actually rebuilt and validated.
- Represent design documents as `docs_ready`, not `completed`, unless the slice is explicitly documentation-only.
- Represent diagnostic reports/gate reviews as `report_only` unless they changed live/rule/tool behavior and met implementation criteria.
- Preserve true implemented history where useful, but keep it summarized. Do not import the 283 archived steps wholesale as the new primary work queue.
- Mark `strategic-ai-hero-task-state-save-normalizer-preservation-report-implementation-10184` as the selected pending next implementation candidate after tracker regeneration.
- Mark `overworld-artifact-check-cue-10184` as `superseded` or stopped evidence only.
- Mark the ad hoc compact UI cue stream as `deferred` or `superseded`, not active.
- Reconcile `homm3-editor-restamp-behavior-10184` explicitly as completed, superseded, or re-scoped rather than leaving it silently pending.
- Keep neutral encounter migration beyond the first three authored records deferred until a player-facing/tooling reason selects it.
- Keep asset import, save migration, pathing/body-tile adoption, renderer sprite ingestion, rare-resource activation, market overhaul, broad AI rewrite, and live AI task adoption pending/deferred behind explicit slices.

Recommended initial tracker groups:
- Governance: document reset and progress regeneration.
- Historical proof: River Pass preservation.
- Phase 2 foundations: world/faction, concept curation, economy, object/neutral, magic, artifact, animation, strategic AI, terrain/editor, random map generator.
- Phase 3 harness: headless simulation and balance reports.
- Later horizons: playable alpha, production alpha, broad production breadth.

Validation for tracker generation:
- `python3 -m json.tool ops/progress.json`
- progress helper status command
- `git diff --check`

## Validation For PLAN Reconciliation

This planning task validates only markdown/file sanity:
- `test -f PLAN.md`
- grep expected headings and slice ids from `PLAN.md`
- `git diff --check`

Do not run long Godot smoke for this planning-only reconciliation.
