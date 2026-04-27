# Progress Implementation Audit - 2026-04-27

Status: audit/reconciliation report only. No gameplay code, scenes, tests, content JSON, save format, or production data were changed by this audit.

## Scope And Method

Audited sources:
- Root planning and rules: `AGENTS.md`, `project.md`, `PLAN.md`, `ops/progress.json`.
- All planning/report documents under `docs/*.md`.
- Implemented repo surfaces: `content/*.json`, `scripts/core`, `scripts/autoload`, scenes, tests, validator/report harnesses, and recent git history.

Lightweight checks run during audit:
- `python3 -m json.tool ops/progress.json`
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --economy-resource-report`
- `python3 tests/validate_repo.py --overworld-object-report`
- `python3 tests/validate_repo.py --neutral-encounter-report`

## Worktree State

Dirty files at audit start:
- `ops/progress.json`
- `scenes/overworld/OverworldShell.gd`

The dirty `ops/progress.json` changes switch the current slice from completed `main-menu-continue-check-cue-10184` to in-progress `overworld-artifact-check-cue-10184`.

The dirty `OverworldShell.gd` changes are WIP for a compact overworld `Artifact check:` cue. They add `_artifact_check_surface()`, `_artifact_action_check_surface()`, artifact validation payloads, and tooltip text. This audit did not continue, test, revert, or complete that implementation.

## Source Documents

### Root Rules And Strategy

`AGENTS.md` is consistent with the intended product posture: Godot 4, data-driven content, modular core systems, staged slices, no fake MVP, no temporary worktrees, and screen-composition rules that keep scenic/play surfaces primary.

`project.md` and `PLAN.md` both establish the active direction as deep production foundation after River Pass. Implemented systems are useful foundations, not proof of HoMM2/HoMM3 parity or release readiness.

Implemented reality:
- Godot 4 project exists with modular autoloads and core rule scripts.
- Content is JSON-authored under `content/`.
- Save/load, campaign progression, overworld, battle, town, AI, difficulty, spells, artifacts, hero command/progression, and validation harnesses exist.

Partial or report-only:
- Deep production foundation tracks exist mostly as docs, reports, compatibility scaffolding, and narrow evidence slices.
- Playable alpha, HoMM2-class breadth, and HoMM3-class breadth remain future horizons.

Issue:
- `PLAN.md` acceptance still says "completed active slice is compact main-menu Quit check clarity", while git HEAD is `Add main menu continue check cue` and `ops/progress.json` now says an artifact cue is in progress. This is stale sequencing text.

### World, Faction, Concept Art

Sources:
- `docs/worldbuilding-foundation.md`
- `docs/factions-content-bible.md`
- `docs/concept-art-pipeline.md`
- `docs/concept-art-batch-001-review.md` through `docs/concept-art-batch-005-review.md`
- `docs/concept-art-implementation-briefs.md`

Implemented:
- Six faction records exist in `content/factions.json`.
- Content scaffold breadth exists: 60 heroes, 103 units, 77 buildings, 12 towns, 15 scenarios, and 4 campaigns.
- First implementation briefs exist for Embercourt, Mireclaw, and core overworld object classes.

Partial:
- JSON records are scaffolds, not full world/faction implementation proof.
- Generated concept images remain external and are not runtime/source assets.

Only planned/report-only:
- AcOrP accept/reject/defer calls for concept batches.
- Asset ingestion and final visual direction.
- Full faction identity migration into runtime mechanics, towns, AI, scenario placement, and balance.

### Economy And Resource Loop

Sources:
- `docs/economy-overhaul-foundation.md`
- `docs/economy-resource-schema-migration-plan.md`
- `docs/economy-resource-additive-schema-validator-plan.md`
- `docs/economy-capture-resource-loop-proof-plan.md`
- `docs/economy-capture-resource-loop-live-proof-report.md`
- `docs/economy-capture-resource-loop-manual-gate-review.md`

Implemented:
- Current live stockpile economy is `gold`, `wood`, and `ore`.
- River Pass economy proof passed for Riverwatch signal-yard flow.
- Validator supports opt-in economy/resource report and strict fixtures.
- Economy report currently shows stockpile resources `gold`, `ore`, `wood`; `timber` is registry-only alias target; 163 warnings and 0 errors.

Partial:
- Persistent site capture and market-cap concepts are report/compatibility warnings, not migrated systems.
- Strategic AI now values selected economy sites in focused report paths.

Only planned/report-only:
- `content/resources.json` or equivalent production registry.
- `wood` to `timber` migration.
- Rare-resource activation.
- Market cap overhaul.
- Multi-resource town/recruitment/building costs.

### Overworld Object And Neutral Encounter Migration

Sources:
- `docs/overworld-content-bible.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/overworld-object-schema-migration-plan.md`
- `docs/overworld-object-safe-additive-schema-plan.md`
- `docs/overworld-object-report-review-001.md`
- Neutral encounter plan/report documents.

Implemented:
- `content/map_objects.json` has 46 objects.
- `content/resource_sites.json` has 48 sites.
- `content/neutral_dwellings.json` has 25 dwelling families.
- `safe_metadata_bundle_001` is production-authored for 8 map objects.
- `neutral_encounter_representation_bundle_001` and `neutral_encounter_first_class_object_bundle_001` are authored for 3 placements/objects.
- Map editor UI surfaces object taxonomy metadata.
- Validator supports object and neutral encounter compatibility reports plus strict fixtures.

Partial:
- Object report: 46 map objects, 48 resource sites, 127 site placements, 48 encounter placements, 8 safe-metadata objects, 3 first-class neutral encounter objects, 177 warnings, 0 errors.
- Neutral report: 48 direct placements, 3 authored/object-backed placements, 45 inferred legacy placements, 542 warnings, 0 errors.

Only planned/report-only:
- True `body_tiles`, approach offsets, pathing/occupancy adoption, renderer sprite ingestion, route effects, animation cue ids, editor placement adoption, broad object JSON migration.
- Neutral encounter migration beyond the first 3 records is explicitly paused.

### Magic, Artifacts, Animation

Sources:
- `docs/magic-system-expansion-foundation.md`
- `docs/artifact-system-expansion-foundation.md`
- `docs/animation-systems-foundation.md`

Implemented:
- `content/spells.json` has 20 spells.
- `content/artifacts.json` has 4 artifacts.
- `SpellRules.gd` and `ArtifactRules.gd` exist.
- Several UI surfaces now expose spell/artifact/status/timing cues.

Partial:
- Existing spells/artifacts are narrow runtime foundations, not the expanded Accord magic/artifact system in the docs.
- Recent artifact-related UI cues do not implement artifact taxonomy, sets, source tables, AI valuation, economy hooks, or spell interactions.

Only planned/report-only:
- Expanded spell schools/categories and adventure-map magic.
- Artifact families, sets, rarity/slot schema, source tables, AI valuation, spell/economy hooks.
- Animation event contracts, cue catalogs, reduced motion/fast mode, unit/hero/town/object animation pipelines, and final VFX/audio cues.

### Strategic AI

Sources:
- `docs/strategic-ai-foundation.md`
- Strategic AI economy pressure, event surfacing, town governor, faction personality, strategy-config, site-control, Glassroad, commander-role, and hero-task-state docs.

Implemented:
- `EnemyAdventureRules.gd` and `EnemyTurnRules.gd` contain real enemy-state, target, pressure, town governor, raid, event, commander-role, and report helpers.
- Focused Godot reports exist for economy pressure, event surfacing, town governor pressure, faction personality evidence, site control, Glassroad defense, commander role state, commander-role turn transcript, and hero task-state boundary.
- Reports/gates through `AI_HERO_TASK_STATE_BOUNDARY_REPORT` passed.

Partial:
- AI pressure and role/task surfaces are mostly report/debug or derived-event evidence, not full live AI hero task behavior.
- `EnemyTurnRules.normalize_enemy_states(...)` remains the key save-normalizer risk called out by the latest AI planning docs.

Only planned/report-only:
- `AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT` implementation is pending.
- Live commander-role behavior, live AI hero task-state adoption, schema writes, save migration, durable event logs, defense-specific durable state, and coefficient tuning remain deferred.

### Terrain, Renderer, And Editor

Sources:
- `project.md` terrain notes.
- `docs/screen-wireframes.md`.
- HoMM3 terrain rewrite planning is referenced in `project.md` via external workspace artifact.

Implemented:
- `content/terrain_grammar.json` and `content/terrain_layers.json` exist.
- `OverworldMapView.gd` and `MapEditorShell.gd` share terrain/editor preview paths.
- Terrain/editor slices advanced through local-reference/prototype and map-editor placement work.

Partial:
- Local HoMM3-reference prototype assets are not shippable assets.
- Terrain presentation is not final art, not a pathing rewrite, and not full restamp parity.

Stale progress item:
- `ops/progress.json` still has pending `homm3-editor-restamp-behavior-10184`, but later terrain/editor steps are completed after it. This item needs explicit reconciliation: complete, supersede, or re-scope.

### Screen/UI Cue Work

Sources:
- `docs/screen-wireframes.md`
- `PLAN.md` item 73-75 and the broad "prefer another compact real player-facing or tooling-facing implementation slice" recommendation.

Implemented:
- Many compact cue surfaces were committed across main menu, overworld, town, battle, outcome, and editor scenes.
- Focused smoke coverage exists in `tests/menu_outcome_visual_smoke.gd`, `tests/overworld_visual_smoke.gd`, `tests/town_battle_visual_smoke.gd`, and `tests/map_editor_smoke.gd`.

Assessment:
- The first few cue slices had a legitimate parent: improve live-client/player-facing readability using existing payloads without mechanics/schema/content changes.
- The later rapid sequence of small cue tasks is only weakly anchored. It is not directly executing the pending AI normalizer proof, object migration, economy migration, magic/artifact/animation foundations, or concept-art curation. Continuing this stream now would be unanchored polish unless a new planning document defines a bounded UI-readability epic and prioritizes specific gaps.
- The stopped `overworld-artifact-check-cue-10184` WIP is audit input only. It should not be completed by default.

## Implemented Repo Reality Summary

Content:
- `army_groups.json`: 69 items.
- `artifacts.json`: 4 items.
- `biomes.json`: 9 items.
- `buildings.json`: 77 items.
- `campaigns.json`: 4 items.
- `encounters.json`: 62 items.
- `factions.json`: 6 items.
- `heroes.json`: 60 items.
- `map_objects.json`: 46 items.
- `neutral_dwellings.json`: 25 items.
- `resource_sites.json`: 48 items.
- `scenarios.json`: 15 items.
- `spells.json`: 20 items.
- `terrain_layers.json`: 2 items.
- `towns.json`: 12 items.
- `units.json`: 103 items.

Core implementation exists for scenario factory/rules/scripts, overworld rules, battle rules/AI, town rules, hero command/progression, artifacts, spells, campaign rules/progression, enemy adventure/turn rules, difficulty, save/load, app routing, settings, and content loading.

Scenes exist for boot, main menu, overworld, town, battle, outcome, and map editor. These are real surfaces, but recent work is heavily concentrated in compact UI cues.

Tests and harnesses:
- `tests/validate_repo.py` is broad and includes opt-in compatibility reports.
- Godot smoke/report scenes cover core systems, live flow, menu/outcome, overworld, town/battle, editor, scenario breadth, and AI evidence.
- This audit did not run long Godot smoke tests.

Recent git history:
- The latest commits are dominated by "Add ... check cue" / "Add ... handoff cue" UI slices.
- Many recent commits update `ops/progress.json`, a scene controller, and a focused smoke file. Some also update `PLAN.md`; many do not.
- This supports AcOrP's concern that recent coding-worker tasks are not consistently tied back to current `PLAN.md`/`nextActions`.

## ops/progress.json NextActions Classification

1. Concept-art pipeline gate: active guardrail, but not an actionable next worker without an approved asset/content target.
2. Overworld object taxonomy gate: active guardrail; partially executed through reports/editor metadata; needs a specific bundle or tooling target to become actionable.
3. Magic foundation gate: active but currently unexecuted; stale as a "next action" unless a spell-schema/UI/AI-casting task is selected.
4. Artifact foundation gate: active but unexecuted; current artifact cue WIP is UI polish, not the foundation work described here.
5. Animation foundation gate: active but unexecuted; should map to cue catalog/event-contract work, not more ad hoc UI text.
6. Strategic AI foundation gate: active but too broad; several listed subareas are already partly implemented. Needs narrowing to the pending normalizer proof.
7. Concept-art batch curation: blocked/deferred on AcOrP accept/reject/defer decisions; not worker-actionable as implementation.
8. Concept-art implementation briefs: deferred until curation decisions; actionable only as a specific Embercourt/Mireclaw/object implementation-plan slice.
9. Object/neutral schema planning contracts: partially implemented; neutral migration is paused. Actionable only if a new declared bundle is selected.
10. AI event surfacing gate: stale/completed reference, not a next action.
11. Huge AI planning/evidence contract: stale. It says the next slice is hero task-state adoption sequencing, but that sequencing and save-normalizer planning are already completed. The real next AI task is the report-only normalizer preservation implementation.
12. Neutral encounter migration paused: active deferral.
13. Resume campaign/skirmish/screen/full-loop polish after foundations: deferred; recent UI cue stream conflicts with this if treated as continuing screen polish.
14. River Pass/Ninefold evidence framing: active guardrail.
15. No parity/readiness claims: active guardrail.

Pending/non-completed steps:
- `strategic-ai-hero-task-state-save-normalizer-preservation-report-implementation-10184`: valid, actionable, and currently skipped.
- `post-foundation-map-screen-polish-10184`: broad placeholder; deferred until foundation depth exists.
- `homm3-editor-restamp-behavior-10184`: stale or needs re-scope because later terrain/editor work continued.
- `overworld-artifact-check-cue-10184`: in-progress dirty WIP; not approved to continue under this audit.

## Recommended Next Worker Sequence

1. Progress/plan reconciliation slice.
   Source: this audit, `PLAN.md`, `ops/progress.json`.
   Targets: update `ops/progress.json` current slice away from the stopped artifact cue, add this audit as a completed audit step, mark the UI cue stream paused, and fix stale `PLAN.md` acceptance/current-slice text. Do not touch gameplay code.

2. Strategic AI hero task-state normalizer preservation implementation.
   Source: `docs/strategic-ai-hero-task-state-save-normalizer-preservation-plan.md`.
   Targets: `EnemyTurnRules.normalize_enemy_states(...)`, narrowly scoped helper/report code, `tests/ai_hero_task_state_normalizer_preservation_report.gd/.tscn`, and an implementation report. No save-version bump, no live behavior, no schema producer.

3. Strategic AI normalizer preservation gate review.
   Source: output of task 2 plus existing AI gate-review pattern.
   Targets: new docs gate review, validation rerun, update `PLAN.md`/`ops/progress.json` to decide whether to pause AI, plan minimal schema, or return to another foundation track.

4. Concept-art curation reconciliation.
   Source: concept batch reviews and `docs/concept-art-implementation-briefs.md`.
   Targets: a short curation/status doc that lists accepted/rejected/deferred external studies and picks one implementation brief track. No asset import.

5. Overworld object next-bundle planning.
   Source: `docs/overworld-object-taxonomy-density.md`, `docs/overworld-object-schema-migration-plan.md`, object report output.
   Targets: plan `safe_metadata_bundle_002` or an editor/tooling metadata bundle, explicitly deciding whether to add `body_tiles`, `approach`, `editor_placement`, or animation cue ids. No runtime pathing/renderer adoption unless separately approved.

6. Economy resource registry decision/report gate.
   Source: economy resource schema plans and economy report.
   Targets: reconcile `wood`/`timber`, decide whether `content/resources.json` is the next additive production registry, and define one strict bundle. No rare-resource activation or market overhaul yet.

7. Artifact schema planning before more artifact UI cues.
   Source: `docs/artifact-system-expansion-foundation.md`.
   Targets: artifact metadata plan for slots, rarity, family/set ids, source tables, and validator fixtures. Avoid UI cue work unless it directly consumes the planned schema.

8. Animation cue catalog planning.
   Source: `docs/animation-systems-foundation.md`.
   Targets: event/cue id catalog and reduced-motion/fast-mode contract for existing battle/town/overworld state changes. No final art/VFX implementation yet.

9. Magic schema planning.
   Source: `docs/magic-system-expansion-foundation.md`.
   Targets: spell school/category/tier metadata and validation fixtures, plus one narrow runtime compatibility adapter if needed. Do not expand battle/adventure magic behavior until schema/report gates pass.

## Recommended Reconciliation Changes

Do not apply these as part of this audit unless a follow-up reconciliation task is approved:

- In `ops/progress.json`, mark `overworld-artifact-check-cue-10184` blocked, abandoned, or superseded unless a new planning slice explicitly approves continuing it.
- In `PLAN.md`, replace stale "completed active slice is Quit check" acceptance text with a current audit/reconciliation statement.
- In `ops/progress.json`, update NextAction 11 to point to `strategic-ai-hero-task-state-save-normalizer-preservation-report-implementation-10184`, not already-completed adoption sequencing.
- Split the broad NextActions list into actionable current-next items and durable guardrails.
- Mark `homm3-editor-restamp-behavior-10184` completed, superseded, or re-scoped after comparing it with later terrain/editor work.
- Add an explicit "UI cue stream paused pending reconciliation" note so future small cue workers need a direct source-doc parent.
- Keep `post-foundation-map-screen-polish-10184` pending/deferred, not current.

## Headline Findings

- The repo has substantial real foundations, but many docs are planning/report gates rather than implementation proof.
- The active progress tracker skipped a valid pending AI normalizer proof and drifted into many small UI cue slices.
- Recent UI cue work has a weak umbrella parent but is now overextended; more cue work should stop until re-anchored.
- Current dirty WIP is an overworld artifact cue and should be treated as stopped implementation input, not as the next audit action.
- `ops/progress.json` NextActions are mostly broad guardrails or stale completed references; they need reconciliation into concrete next worker tasks.
