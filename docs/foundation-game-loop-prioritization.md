# Foundation Game-Loop Prioritization

Status: completed prioritization, documentation only.
Date: 2026-04-26.
Slice: foundation-game-loop-prioritization-10184.

## Purpose

Choose the next broader foundation or game-loop track after the metadata-only first-class neutral encounter object bundle review.

This document does not approve production JSON migration, validator or test implementation, runtime encounter/pathing/AI/editor/renderer/save behavior changes, generated PNG import, asset import, or broader neutral encounter migration.

## Current Baseline

Recent foundation work has produced useful planning and report scaffolding:

- Economy foundation exists in `docs/economy-overhaul-foundation.md`, including target resources, resource-site classes, capture/counter-capture loops, daily/weekly rhythms, town costs, markets, and faction economy behavior.
- Overworld object taxonomy and schema migration planning exist in `docs/overworld-object-taxonomy-density.md`, `docs/overworld-object-schema-migration-plan.md`, and `docs/overworld-object-safe-additive-schema-plan.md`.
- `safe_metadata_bundle_001` proves runtime-inactive object metadata for eight production map objects.
- Neutral encounter report and first-class object scaffolding exist, and `neutral_encounter_first_class_object_bundle_001` proves the metadata-only object-backed boundary for three authored placements.
- The reviewed neutral encounter report now has 3 first-class neutral encounter objects, 3 object-backed/lifted placements, 45 remaining direct placements, 542 warnings, and 0 errors.
- Strategic AI and animation foundations are documented, but neither should be treated as live-client proof yet.
- Concept-art implementation briefs exist, but generated PNGs remain external concept evidence only and AcOrP curation remains open.

The project still needs a stronger player-facing loop: exploration, capture, resources, town choices, risk, recovery, opponent pressure, and readable feedback. Warning-count reduction alone will not prove that loop.

## Candidate Tracks

| Track | Player-facing leverage | Risk | Dependency readiness | Validation gates | Assessment |
| --- | --- | --- | --- | --- | --- |
| Economy capture/resource loop | Very high. Directly improves why the player explores, captures sites, develops towns, recruits, and defends territory. | Medium if staged on existing resources and current site behavior; high only if rare resources or save migration are pulled in too early. | Strong. Economy foundation, resource report scaffolding, resource-site behavior, towns, rewards, and object metadata all exist. | Existing repo validation, economy report, overworld object report, focused manual live-client proof, save/resume check. | Best next track. It strengthens the core strategy loop while avoiding premature body-tile/pathing/editor or full AI adoption. |
| Object/pathing/editor adoption | High later. True body tiles, approach offsets, editor placement checks, and first-class objects are important for production maps. | High now. Pathing and approach adoption can invalidate existing maps, trap heroes, or create renderer/editor/runtime divergence. | Partial. Schema plans and small metadata bundles exist, but broad object migration and placement checks are not ready. | Object report, placement validation, pathing regression, editor play-copy checks, manual map traversal. | Defer until an economy loop or map-authoring need demands it. Plan it as a follow-up, not the immediate next center of effort. |
| Strategic AI turn pressure | High. The game needs real opponent pressure beyond scripted or raid-director behavior. | High if started before economy/object valuation is concrete. AI can amplify shallow or unstable systems. | Partial. Strategic AI foundation and existing `EnemyTurnRules`/`EnemyAdventureRules` scaffolds exist, but target resource/object valuation is not yet live. | Deterministic AI tests, event-stream checks, manual opponent-turn proof, difficulty/fairness review. | Important second-order track. It should follow the first economy capture loop so AI has meaningful resources and sites to value. |
| Live-client game-loop proof | Very high if scoped; very high risk if vague. | High unless anchored to one specific mechanic family and one scenario path. | Medium. River Pass passed a manual gate, but the next proof needs deeper economy/town/site pressure. | Manual play report, save/resume, win/loss route, resource/town decision notes. | Fold into the economy track as the proof method. Do not launch a broad undifferentiated full-loop polish slice. |
| Animation/screen feedback | Medium now, high later. It improves clarity and feel, especially for state changes. | Medium. It can become polish over incomplete systems if started too broadly. | Planning exists, but cue catalogs and event contracts are not implemented. | Reduced-motion checks, event-cue coverage, screenshot/playback review. | Defer. First decide what economy/site/town state changes need feedback, then animate those events. |
| Concept-art-to-asset pipeline | Medium now, high for production identity. | Medium. Asset import can create churn before runtime object/town contracts settle. | Partial. Briefs exist, generated PNGs are external only, and AcOrP review remains open. | Art-direction acceptance, source-asset rules, import checks, renderer review. | Defer for now. Use the briefs as planning evidence, but do not import generated assets or start production asset ingestion. |

## Recommended Track

Recommend `economy-capture-resource-loop-proof-planning-10184` as the next concrete slice.

The broader track is an economy capture/resource loop proof, anchored to existing runtime capabilities and current resources before rare-resource or schema migration work. The purpose is to make map control matter in a way a player can feel: scout a site, evaluate risk, capture it, receive daily/weekly value, spend that value in town/recruitment decisions, and see whether losing or ignoring sites changes the strategic situation.

Rationale:

- Player-facing leverage is highest. Economy capture is the connective tissue between overworld exploration, battles, town growth, recruitment, faction identity, and future AI pressure.
- Dependency readiness is better than the alternatives. The repo already has resource sites, persistent control concepts, rewards, town costs, economy reports, object reports, and River Pass manual-play history.
- Risk can be bounded. The first planning/proof can stay on `gold`, `wood`, and `ore`, plus existing resource-site behavior, without introducing `content/resources.json`, rare resources, save migration, market caps, body tiles, approach offsets, or pathing changes.
- Validation gates are clear. Automated validation can stay with current repo checks and opt-in reports, while live-client proof can inspect whether a real player experiences a meaningful capture/spend/defend loop.
- It prepares later AI better than starting AI now. Strategic AI needs concrete site/resource value before full hero/town planning becomes useful.

## Neutral Encounter Migration Decision

Neutral encounter metadata migration should stay paused.

The metadata-only bundle proved the intended boundary: object ids, scenario bridge metadata, lifted agreement, guard-target resolution, and strict production checks work for the declared three records. Continuing with more tiny neutral encounter bundles would mostly reduce compatibility warnings across the remaining 45 direct placements. It would not improve runtime encounter behavior, pathing, renderer output, AI decisions, editor placement, save behavior, or player-facing loop quality.

The remaining direct placements should stay compatibility-warning-only until a later slice has a concrete player-facing or tooling reason to migrate them, such as editor object placement, object/pathing adoption, AI object valuation, renderer adoption, save-state adoption, or a scenario-authoring bundle.

## Next Slices

### 1. Economy Capture Resource Loop Proof Planning

Slice id: `economy-capture-resource-loop-proof-planning-10184`.

Scope:

- Choose one narrow proof target, preferably River Pass or a small River Pass-adjacent path, using existing `gold`, `wood`, and `ore` behavior.
- Identify the specific resource sites, town costs/recruit choices, rewards, capture states, and save/resume observations that should prove the loop.
- Define expected player decisions: what to scout, what to fight, what to capture, what to spend, what can be delayed, and what should become risky if ignored.
- Define exact validation commands and a manual live-client proof checklist.

Non-change boundaries:

- No production JSON migration.
- No new resource registry or wood id change.
- No rare-resource activation.
- No runtime economy, market, AI, pathing, renderer, editor, save, or asset changes.
- No validator/test implementation.

### 2. Economy Capture Resource Loop Live Slice

Slice id: `economy-capture-resource-loop-live-slice-10184`.

Scope:

- Implement only the minimum changes approved by the planning slice to make the selected capture/resource/town-spend path readable and manually testable.
- Prefer existing resource-site, town, reward, and day-advance systems before adding new behavior.
- Keep changes focused enough that save/resume and manual play can verify them in one scenario path.

Non-change boundaries:

- No full nine-resource migration.
- No `content/resources.json` unless a later planning slice explicitly approves it.
- No market-cap overhaul, rare-resource economy, faction-wide cost rebalance, AI rewrite, body-tile/approach pathing adoption, renderer sprite ingestion, or generated PNG import.
- No broad scenario economy retuning outside the selected proof path.

### 3. Economy Loop Manual Gate And Report Review

Slice id: `economy-capture-resource-loop-manual-gate-10184`.

Scope:

- Run the selected live-client proof and record whether capture, daily/weekly income, town spending, recruitment, save/resume, and outcome routing are understandable without developer interpretation.
- Compare observed behavior with the planning checklist and existing economy/overworld reports.
- Decide whether to iterate the economy slice, move to AI pressure, or unblock object/pathing/editor adoption.

Non-change boundaries:

- Documentation/report review unless the slice explicitly authorizes fixes.
- No new production migration bundle.
- No renderer, pathing, AI, editor, save, or asset import changes.

### 4. Strategic AI Economy Pressure Planning

Slice id: `strategic-ai-economy-pressure-planning-10184`.

Scope:

- After the player economy loop proof, plan the smallest AI pressure slice that values the same sites/resources and surfaces fair opponent intent.
- Decide whether to start with event streams, town governor choices, raid target valuation, or real AI hero task state.
- Define fairness and difficulty constraints before implementation.

Non-change boundaries:

- No AI implementation in the planning slice.
- No hidden resource bonuses or perfect information.
- No broad strategic AI rewrite before economy-loop proof data exists.

## Validation Expectations

For this prioritization slice:

- `python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt`
- `git diff --check`
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --neutral-encounter-report`
- `python3 tests/validate_repo.py --overworld-object-report`

For the next planning slice, add the economy report to the review set:

- `python3 tests/validate_repo.py --economy-resource-report`

GitHub auth remains blocked; keep work local and do not push.
