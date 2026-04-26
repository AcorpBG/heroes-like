# Strategic AI Glassroad Defense Proof Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-glassroad-defense-proof-planning-10184`.

## Purpose

Plan a bounded Embercourt defense and stabilization proof in `glassroad-sundering` before any coefficient tuning or broader strategic AI state work.

The selected path is an Embercourt Glassroad charter-front proof centered on `glassroad_watch_relay` and `glassroad_starlens`, with `halo_spire_bridgehead` as the town-front sanity check and `glassroad_beacon_wardens` as the objective/encounter companion. The follow-up slice should prove what current systems already expose through report/debug output: assignment pressure, site seizure or retake behavior, compact public event reasons, and town-governor stabilization signals.

This slice does not edit AI behavior, production content JSON, scenario balance, coefficients, pathing, body tiles, approach rules, renderer/editor behavior, saves, durable event logs, full AI hero task state, neutral encounter migration, resource schemas, market caps, generated assets, or River Pass balance.

## Evidence Baseline

Use current systems and reports first:

- `docs/strategic-ai-capture-countercapture-defense-proof-report.md` passes the Mireclaw River Pass site-control proof: current raid resolution can assign and seize `river_free_company`, flip controller state, and emit compact `ai_target_assigned` / `ai_site_seized` records.
- `docs/strategic-ai-strategy-config-audit-report.md` confirms `glassroad-sundering` is the current direct Embercourt enemy fixture and that `prismhearth-watch` must not be cited as Embercourt evidence.
- `docs/strategic-ai-faction-personality-evidence-report.md` already shows Embercourt resource ordering with `glassroad_watch_relay` first and `glassroad_starlens` second when player-controlled.
- `docs/strategic-ai-event-surfacing-report-gate-review.md` passes the current compact public/debug event vocabulary for assignment, pressure summary, site seizure, and site contest.
- `docs/strategic-ai-town-governor-pressure-report-gate-review.md` passes town governor report surfaces for garrison stabilization, raid reinforcement, commander rebuild, and compact derived events.

## Fixture Setup

Scenario: `glassroad-sundering`.

Player faction: `faction_sunvault`.

Enemy faction: `faction_embercourt`.

Enemy label: `Charter Road Wardens`.

Enemy town: `riverwatch_market`.

Player town/front sanity target: `halo_spire_bridgehead`.

Primary proof site: `glassroad_watch_relay`.

Companion proof site: `glassroad_starlens`.

Objective/encounter companion: `glassroad_beacon_wardens`.

Relevant current scenario facts:

- Embercourt starts as the enemy faction and controls `riverwatch_market`.
- Sunvault starts at `halo_spire_bridgehead`.
- Embercourt spawn points are `{x: 9, y: 1}` and `{x: 9, y: 4}`.
- Embercourt priority targets are `halo_spire_bridgehead`, `glassroad_watch_relay`, `glassroad_starlens`, and `glassroad_beacon_wardens`.
- Embercourt Glassroad overrides include `faction_outpost: 1.55`, `frontier_shrine: 1.2`, `town: 1.4`, `resource: 0.95`, `encounter: 1.2`, and `town_siege_weight: 1.5`.
- `glassroad_watch_relay` uses `site_prism_watch_relay` at `{x: 2, y: 3}`, with persistent control, `claim_rewards.gold: 60`, `control_income.gold: 25`, `vision_radius: 3`, `pressure_guard: 1`, and a response profile named `Repair Outpost`.
- `glassroad_starlens` uses `site_starlens_sanctum` at `{x: 9, y: 2}`, with persistent control, `claim_rewards.experience: 140`, `learn_spell_id: "spell_beacon_path"`, and a response profile named `Relight Shrine`.
- `glassroad_beacon_wardens` uses `encounter_beacon_wardens` at `{x: 8, y: 0}` and is required by the `clear_beacon_line` victory objective.

## Public And Debug Vocabulary Decision

Use the current compact vocabulary for the follow-up proof:

- `ai_target_assigned`
- `ai_pressure_summary`
- `ai_site_seized`
- `ai_site_contested`
- `ai_town_built`
- `ai_town_recruited`
- `ai_garrison_reinforced`
- `ai_raid_reinforced`
- `ai_commander_rebuilt`

Defense-specific behavior does not need new explicit durable state for this bounded proof unless the follow-up report cannot express the expected behavior through current controller state, staged raid assignment/seizure, town-front pressure, and town-governor stabilization surfaces.

Do not add an `ai_site_defended`, `ai_site_stabilized`, or persistent hero task state in the next slice just to make the proof read cleaner. Add those only in a later planning slice if a report proves that current public events cannot distinguish a real guarded-friendly-site order from generic raid pressure.

## Exact Proof Goals

The next implementation/report slice should add a focused Godot report, not tune behavior. Suggested marker: `AI_GLASSROAD_DEFENSE_PROOF_REPORT`.

Required cases:

1. `embercourt_glassroad_fixture_sanity`
   - Create a `glassroad-sundering` skirmish session.
   - Normalize overworld state and refresh fog as existing focused reports do.
   - Verify the enemy config is `faction_embercourt`.
   - Verify the priority target list includes `halo_spire_bridgehead`, `glassroad_watch_relay`, `glassroad_starlens`, and `glassroad_beacon_wardens`.
   - Verify the scenario overrides listed above are present in the report payload.

2. `embercourt_relay_starlens_selection`
   - Stage `glassroad_watch_relay` and `glassroad_starlens` as player-controlled persistent sites.
   - Run `EnemyAdventureRules.resource_pressure_report(...)` from `{x: 9, y: 1}` for `faction_embercourt`.
   - Expected ordering: `glassroad_watch_relay` first, `glassroad_starlens` second.
   - Expected simple-site sanity: both controlled persistent sites should outrank simple pickups such as `glassroad_timber`, `glassroad_ore`, and `market_cache`.
   - Expected relay reason: public reason `income and route vision denial`, with `persistent_income_denial`, `route_vision`, and `player_town_support`.
   - Expected Starlens reason: public reason `route pressure`, with `route_pressure`; record that the reason is generic because current metadata is coarse.

3. `embercourt_town_front_sanity`
   - Run `EnemyAdventureRules.choose_target(...)` from `{x: 9, y: 1}`.
   - Expected accepted result: `halo_spire_bridgehead` may remain the full-selector target with public reason `town siege remains the main front`.
   - This must not be treated as failure. The proof is about defense/stabilization surfaces around Glassroad assets, not forcing resource targets above the main town front.

4. `embercourt_relay_assignment`
   - Build an assignment event from the relay target row or stage a current-system Embercourt raid targeting `glassroad_watch_relay`.
   - Expected event: `ai_target_assigned`.
   - Expected target: `glassroad_watch_relay`.
   - Expected public reason: `income and route vision denial`.
   - Required reason codes: `persistent_income_denial`, `route_vision`, and `player_town_support`.
   - Public event must not expose score-table keys such as `base_value`, `persistent_income_value`, `denial_value`, `assignment_penalty`, or `final_priority`.

5. `embercourt_relay_retake_or_seizure`
   - Stage `glassroad_watch_relay` as player-controlled.
   - Add an Embercourt raid at the relay or one deterministic step from the relay using current `advance_raids(...)` behavior.
   - Run `EnemyAdventureRules.advance_raids(...)`.
   - Expected state if current systems support the proof: `glassroad_watch_relay.collected_by_faction_id == "faction_embercourt"`.
   - Expected event if current systems support the proof: `ai_site_seized`.
   - Expected target: `glassroad_watch_relay`.
   - Expected public reason: `income and route vision denial`.
   - Required reason codes: `site_seized`, `persistent_income_denial`, and `route_vision`.
   - If the current system cannot produce a relay seizure/retake without behavior changes, record the exact blocker in the report and do not tune coefficients or add state in this slice.

6. `embercourt_starlens_stabilization_reason`
   - Keep `glassroad_starlens` as the companion target, not a second broad seizure path.
   - Verify it remains second in controlled-site ordering.
   - Record current public reason `route pressure` and reason code `route_pressure`.
   - Record current site response profile facts: `Relight Shrine`, `watch_days: 3`, `readiness_bonus: 1`, `pressure_bonus: 1`, and `recovery_relief: 2`.
   - Treat these as stabilization evidence surfaces, not AI behavior changes.

7. `embercourt_town_governor_stabilization`
   - Run or reuse the Embercourt Glassroad town governor report case for `riverwatch_market`.
   - Required garrison case signals: `ai_town_built`, `ai_town_recruited`, and `ai_garrison_reinforced`.
   - Expected selected build evidence: `building_market_square`, category `economy`, dominant debug components including market and income.
   - Accepted caveat: current public build reason may remain `builds pressure`.
   - Expected recruitment destination under a critical garrison gap: type `garrison`, public reason `stabilizes garrison`, reason code `garrison_safety`.

8. `public_surface_compactness`
   - For assignment, seizure, pressure, and town-governor events, assert that public records contain compact fields only: event type, faction, actor, target, importance, reason codes, public reason, summary, debug reason, visibility, and state policy.
   - Detailed score breakdowns may appear in report/debug target tables only.
   - The proof must not create a text-heavy live-client dashboard.

## Report Payload Contract

The focused report should print a single JSON payload after the marker:

```text
AI_GLASSROAD_DEFENSE_PROOF_REPORT {"ok": true, ...}
```

Recommended top-level fields:

- `ok`
- `scenario_id`
- `faction_id`
- `selected_path`
- `fixture_sanity`
- `resource_order`
- `top_resource_targets`
- `chosen_target_sanity`
- `assignment_event`
- `seizure_or_blocker`
- `site_controller_before`
- `site_controller_after`
- `starlens_stabilization_surface`
- `town_governor_stabilization`
- `public_leak_check`
- `state_need_decision`
- `caveats`

The implementation report document should record the meaningful output in `docs/strategic-ai-glassroad-defense-proof-report.md`.

## Expected Assignment, Pressure, Defense, And Stabilization Signals

Relay assignment:

- Event: `ai_target_assigned`.
- Target id: `glassroad_watch_relay`.
- Target label: `Prism Watch Relay`.
- Public reason: `income and route vision denial`.
- Reason codes: `persistent_income_denial`, `route_vision`, `player_town_support`.
- Public importance: `high`.
- State policy: `derived`.

Relay seizure/retake if current systems support it:

- Event: `ai_site_seized`.
- Target id: `glassroad_watch_relay`.
- Public reason: `income and route vision denial`.
- Reason codes: `site_seized`, `persistent_income_denial`, `route_vision`.
- State policy: current durable state reference.
- Controller after: `faction_embercourt`.

Town-front pressure sanity:

- Event: `ai_pressure_summary`.
- Target id: `halo_spire_bridgehead`.
- Public reason: `town siege remains the main front`.
- Reason codes: `town_siege`, `objective_front`.
- Public importance: `critical`.

Starlens stabilization surface:

- Target id: `glassroad_starlens`.
- Target label: `Starlens Sanctum`.
- Public reason: `route pressure`.
- Reason code: `route_pressure`.
- Response profile evidence: `Relight Shrine`, 3 watch days, readiness, pressure, and recovery relief.

Town governor stabilization:

- Events: `ai_town_built`, `ai_town_recruited`, `ai_garrison_reinforced`.
- Actor town: `riverwatch_market`.
- Recruitment destination: `garrison`.
- Public reason: `stabilizes garrison`.
- Reason code: `garrison_safety`.

## Validation Commands

Required repo validation for the planning slice and the follow-up proof slice:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

Focused reports the implementation slice should run:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_glassroad_defense_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_faction_personality_evidence_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

The economy pressure report is optional unless the proof touches shared resource scoring helpers:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
```

## Manual Live-Client Gate Triggers

Manual live-client inspection remains deferred for this planning slice.

For the follow-up proof slice, run a manual Glassroad enemy-turn gate only if the implementation:

- changes target ordering, coefficients, raid cadence, reinforcement strength, arrival frequency, or visible map pressure;
- changes normal player-facing turn text, event display, threat/dispatch composition, or screen layout;
- changes resource-site capture, counter-capture, daily income, response profile use, or player recapture behavior;
- adds durable event logs, save migration, full AI hero task state, pathing/body-tile/approach behavior, renderer/editor behavior, production scenario content, or generated assets;
- produces a focused report pass but AcOrP asks for live-client confirmation.

If triggered, the manual gate should use `glassroad-sundering` only:

1. Start a normal skirmish from `glassroad-sundering`.
2. Capture or stage player control of `glassroad_watch_relay` and `glassroad_starlens`.
3. End turns until Embercourt assigns or reaches the Glassroad relay front.
4. Confirm compact visible language for assignment, seizure/retake, pressure, and garrison stabilization if surfaced.
5. Confirm no text-heavy dashboard and no score-table leakage.
6. Confirm site controller, persistent income/response surface, and scenario state after any retake.
7. Save/resume only if the proof slice changes save-relevant state; otherwise defer save migration checks.

## Out Of Scope

- Production JSON edits.
- AI behavior changes.
- Coefficient tuning or broad behavior tuning.
- Durable event logs.
- Save migration.
- Full AI hero task state or broad strategic AI rewrite.
- New defense-specific durable state.
- Pathing, body-tile, approach, renderer, or editor adoption.
- Generated PNG import or runtime asset import.
- Neutral encounter migration.
- `content/resources.json`.
- `wood` to `timber` migration.
- Rare-resource activation.
- Market-cap overhaul.
- River Pass rebalance.
- Same-scenario Embercourt versus Mireclaw A/B personality proof.
- Commander-role doctrine proof.
- Adventure spell, artifact, or full strategic planner proof.

## Recommended Next Slice

Recommended next slice: `strategic-ai-glassroad-defense-proof-report-10184`.

Purpose:

- Add the focused `AI_GLASSROAD_DEFENSE_PROOF_REPORT` Godot report and a short implementation/report document.
- Prove the current Embercourt Glassroad relay/starlens defense and stabilization surfaces if current systems already support them.
- Decide from evidence whether defense-specific behavior needs explicit state later.
- If current systems fail, record the exact blocker without tuning coefficients or broadening scope.

Acceptance:

- The report proves player-owned `glassroad_watch_relay` and `glassroad_starlens` remain high-value Embercourt Glassroad targets.
- The report proves `glassroad_watch_relay` can either be assigned and seized/retaken by current Embercourt raid resolution, or records the exact current-system blocker.
- The report preserves the valid `halo_spire_bridgehead` town-front sanity result.
- The report records Starlens response-profile stabilization evidence without changing behavior.
- The report records Embercourt town-governor garrison stabilization at `riverwatch_market`.
- Public events stay compact and score-table-free.
- Any required code changes are limited to report/test scaffolding unless a current-system bug prevents the proof.

Deferred after that:

- Bounded coefficient tuning only if the focused proof shows a specific ordering, defense, seizure, or retake defect.
- Defense-specific explicit state planning only if the focused proof shows current assignment/seizure/town-governor surfaces cannot express the needed behavior.
- Commander-role state planning only if site-control proof shows target/capture behavior is not the blocker.
