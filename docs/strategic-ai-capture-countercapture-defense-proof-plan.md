# Strategic AI Capture Counter-Capture Defense Proof Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-capture-countercapture-defense-proof-planning-10184`.

## Purpose

Plan one narrow site-control proof before any coefficient tuning.

The selected path is a Mireclaw counter-capture and denial proof in `river-pass`: the player first controls `river_free_company` and `river_signal_post`, then a Mireclaw raid retakes or denies the Free Company yard with compact public reasons and report/debug evidence. `river_signal_post` remains the companion ordering and reason check.

This slice does not edit AI behavior, production content JSON, scenario balance, coefficients, pathing, body tiles, approach rules, renderer/editor behavior, saves, durable event logs, full AI hero task state, neutral encounter migration, resource schemas, market caps, generated assets, or River Pass balance.

## Evidence Baseline

Use current systems and reports first:

- `docs/economy-capture-resource-loop-manual-gate-review.md` passes the Riverwatch signal-yard economy loop: player capture of `river_signal_post` and `river_free_company` creates persistent daily gold income, recruit support, and town-spend value.
- `docs/strategic-ai-economy-pressure-report-gate-review.md` passes the first AI pressure target: when player-owned, `river_free_company` and `river_signal_post` outrank simple pickups in the focused resource report.
- `docs/strategic-ai-event-surfacing-report-gate-review.md` passes compact assignment, seizure, contest, threat, and dispatch reason surfacing for River Pass examples.
- `docs/strategic-ai-town-governor-pressure-report-gate-review.md` passes Duskfen / Mireclaw town governor report surfaces for raid feeding, garrison stabilization, and commander rebuild.
- `docs/strategic-ai-faction-personality-evidence-report.md` supports Mireclaw as raid, denial, growth/replacement, resource counter-pressure, and commander-rebuild pressure.
- `docs/strategic-ai-strategy-config-audit-report.md` says current Embercourt/Mireclaw config is coherent enough to avoid immediate coefficient tuning; missing proof is actual site-control behavior.

## Fixture Choice

### Selected Fixture: Mireclaw River Pass Signal Yard

Scenario: `river-pass`.

Enemy faction: `faction_mireclaw`.

Primary proof site: `river_free_company`.

Companion site: `river_signal_post`.

Relevant current scenario facts:

- Player starts as `faction_embercourt` at `riverwatch_hold`.
- Mireclaw starts from `duskfen_bastion`.
- Enemy spawn points are `{x: 7, y: 1}` and `{x: 7, y: 3}`.
- Mireclaw priority targets include `riverwatch_hold`, `river_signal_post`, `river_free_company`, and `warcrest_ruin`.
- Mireclaw overrides include resource weight `1.35`, site denial weight `1.5`, hero hunt weight `1.15`, and raid reinforcement bias `1.45`.
- `river_signal_post` uses `site_ember_signal_post` at `{x: 2, y: 3}`.
- `river_free_company` uses `site_riverwatch_free_company_yard` at `{x: 0, y: 4}`.

### Why This Beats Glassroad For The First Proof

`glassroad-sundering` is valid direct Embercourt enemy evidence, and `glassroad_watch_relay` plus `glassroad_starlens` are good later defense/stabilization candidates. It is not the first proof because the River Pass signal-yard path already has:

- a passed player economy capture proof,
- a passed Mireclaw resource-ordering proof,
- an existing event-surfacing seizure case for `river_free_company`,
- a stronger current personality claim around denial and counter-capture,
- lower fixture risk because it does not require new Embercourt-specific defense wording or coefficient review.

The Glassroad defense/stabilization proof should follow only after this first site-control report clarifies whether current seizure/retake mechanics are enough or whether defense-specific state is the real missing foundation.

## Exact Proof Goals

The next implementation/report slice should add a focused Godot report, not tune behavior. Suggested marker: `AI_SITE_CONTROL_PROOF_REPORT`.

Required cases:

1. `mireclaw_signal_yard_selection`
   - Create a `river-pass` skirmish session.
   - Normalize overworld state and fog as existing focused reports do.
   - Stage `river_free_company` and `river_signal_post` as player-controlled persistent sites.
   - Run `EnemyAdventureRules.resource_pressure_report(...)` from `{x: 7, y: 1}` for `faction_mireclaw`.
   - Expected ordering: `river_free_company` before `river_signal_post`; both before reachable simple pickups such as `north_wood` and `eastern_cache`.
   - Also run `EnemyAdventureRules.choose_target(...)` as a sanity check. It may still choose `riverwatch_hold`; that remains acceptable and should be recorded, not treated as failure.

2. `mireclaw_free_company_assignment`
   - Build or advance a current-system Mireclaw raid with target kind `resource`, target `river_free_company`, and encounter id `encounter_mire_raid`.
   - Expected event: `ai_target_assigned`.
   - Expected target: `river_free_company`.
   - Expected public reason: `recruit and income denial`.
   - Required reason codes: `persistent_income_denial`, `recruit_denial`, and `player_town_support`.
   - Public event must not expose score-table keys such as `base_value`, `persistent_income_value`, `recruit_value`, `denial_value`, `assignment_penalty`, or `final_priority`.

3. `mireclaw_free_company_countercapture`
   - Stage `river_free_company` as player-controlled.
   - Add a Mireclaw raid at the site or one deterministic step from the site using current `advance_raids(...)` behavior.
   - Run `EnemyAdventureRules.advance_raids(...)`.
   - Expected state: `river_free_company.collected_by_faction_id == "faction_mireclaw"`.
   - Expected event: `ai_site_seized`.
   - Expected target: `river_free_company`.
   - Expected public reason: `recruit and income denial`.
   - Required reason codes: `site_seized`, `persistent_income_denial`, and `recruit_denial`.
   - Expected message includes compact logistics denial wording, currently `denies its logistics route`.
   - Enemy state should record the current-system pressure/treasury effects from `_secure_resource_target(...)`; the report should print those effects, not tune them.

4. `mireclaw_signal_post_denial_reason`
   - Stage `river_signal_post` as player-controlled.
   - Verify its report/debug reason remains `income and route vision denial`.
   - Required reason codes: `persistent_income_denial`, `route_vision`, and `player_town_support`.
   - This is a companion reason check, not a second broad proof path.

5. `public_surface_compactness`
   - For assignment and seizure events, assert that public records contain compact fields only: event type, faction, actor, target, importance, reason codes, public reason, summary, debug reason, visibility, and state policy.
   - Detailed score breakdowns may appear in report/debug target tables only.
   - The proof must not create a text-heavy live-client dashboard.

## Report Payload Contract

The focused report should print a single JSON payload after the marker:

```text
AI_SITE_CONTROL_PROOF_REPORT {"ok": true, ...}
```

Recommended top-level fields:

- `ok`
- `scenario_id`
- `faction_id`
- `selected_path`
- `cases`
- `resource_order`
- `chosen_target_sanity`
- `assignment_event`
- `seizure_event`
- `site_controller_before`
- `site_controller_after`
- `enemy_state_delta`
- `public_leak_check`
- `caveats`

The implementation report document should record the meaningful output in `docs/strategic-ai-capture-countercapture-defense-proof-report.md`.

## Expected Events And Reasons

Primary Free Company path:

- Assignment event: `ai_target_assigned`.
- Seizure event: `ai_site_seized`.
- Target id: `river_free_company`.
- Target label: current site label for `site_riverwatch_free_company_yard`.
- Public reason: `recruit and income denial`.
- Reason codes: `persistent_income_denial`, `recruit_denial`, `player_town_support`; seizure adds `site_seized`.
- Public importance: `high`.
- State policy: assignment can remain `derived`; seizure can remain the current `durable_state_reference`.

Signal Post companion:

- Target id: `river_signal_post`.
- Public reason: `income and route vision denial`.
- Reason codes: `persistent_income_denial`, `route_vision`, `player_town_support`.
- Public importance: `high`.

Full selector sanity:

- `choose_target(...)` may choose `riverwatch_hold` with `town siege remains the main front`.
- That result is acceptable because the proof is site-control capability, not a coefficient change forcing resources above the town front in all contexts.

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
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_faction_personality_evidence_report.tscn
```

The town governor report is optional unless the proof changes recruitment, reinforcement, commander rebuild, or town pressure surfaces:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

## Manual Live-Client Gate Triggers

Manual live-client inspection remains deferred for this planning slice.

For the follow-up proof slice, run a manual River Pass enemy-turn gate only if the implementation:

- changes target ordering, coefficients, raid cadence, reinforcement strength, arrival frequency, or visible map pressure;
- changes normal player-facing turn text, event display, threat/dispatch composition, or screen layout;
- changes resource-site capture, counter-capture, daily income, recruit joins, or player recapture behavior;
- adds durable event logs, save migration, full AI hero task state, pathing/body-tile/approach behavior, renderer/editor behavior, production scenario content, or generated assets;
- produces a focused report pass but AcOrP asks for live-client confirmation.

If triggered, the manual gate should use `river-pass` only:

1. Start a normal skirmish from `river-pass`.
2. Capture `river_signal_post` and `river_free_company`.
3. End turns until a Mireclaw raid targets or reaches the signal-yard front.
4. Confirm compact visible language for assignment/seizure/pressure, no text-heavy dashboard, and no score-table leakage.
5. Confirm the site controller, daily income, and scenario state after seizure.
6. Save/resume only if the proof slice changes save-relevant state; otherwise defer save migration checks.

## Out Of Scope

- Production JSON edits.
- AI behavior changes.
- Coefficient tuning or broad behavior tuning.
- Durable event logs.
- Save migration.
- Full AI hero task state or broad strategic AI rewrite.
- Pathing, body-tile, approach, renderer, or editor adoption.
- Generated PNG import or runtime asset import.
- Neutral encounter migration.
- `content/resources.json`.
- wood id change.
- Rare-resource activation.
- Market-cap overhaul.
- River Pass rebalance.
- Embercourt Glassroad defense implementation.
- Same-scenario Embercourt versus Mireclaw A/B personality proof.
- Commander-role doctrine proof.
- Adventure spell, artifact, or full strategic planner proof.

## Recommended Next Slice

Recommended next slice: `strategic-ai-site-control-proof-report-10184`.

Purpose:

- Add the focused `AI_SITE_CONTROL_PROOF_REPORT` Godot report and a short implementation/report document.
- Prove the current Mireclaw signal-yard counter-capture path if current systems already support it.
- If current systems fail, record the exact blocker without tuning coefficients or broadening scope.

Acceptance:

- The report proves player-owned `river_free_company` and `river_signal_post` remain high-value Mireclaw site-control targets.
- The report proves `river_free_company` can be seized by current Mireclaw raid resolution with compact `ai_site_seized` output.
- The report preserves the valid `riverwatch_hold` town-front sanity result.
- Public events stay compact and score-table-free.
- Any required code changes are limited to report/test scaffolding unless a current-system bug prevents the proof.

Deferred after that:

- Bounded coefficient tuning only if the focused proof shows a specific ordering defect.
- Embercourt Glassroad defense/stabilization proof using `glassroad_watch_relay` and `glassroad_starlens`.
- Commander-role state planning only if site-control proof shows target/capture behavior is not the blocker.
