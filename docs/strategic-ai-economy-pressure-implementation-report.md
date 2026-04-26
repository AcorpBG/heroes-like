# Strategic AI Economy Pressure Implementation Report

Status: completed implementation.
Date: 2026-04-26.
Slice: `strategic-ai-economy-pressure-implementation-10184`.

## Scope

This slice implements the first narrow strategic AI economy pressure target for existing `river-pass` / Mireclaw pressure behavior.

The implementation stays on the current `EnemyAdventureRules` target-selection path. It does not add full AI heroes, AI task state, production JSON migration, new resources, `timber` migration, rare-resource activation, market-cap changes, pathing/body-tile/approach adoption, renderer/editor/save behavior changes, generated assets, neutral encounter migration, or broad River Pass rebalance.

## Delivered

- Added `EnemyAdventureRules.resource_target_score_breakdown(...)` for resource targets.
- Added `EnemyAdventureRules.resource_pressure_report(...)` for deterministic report/debug output.
- Routed existing resource target candidates through the score breakdown while keeping town, hero, artifact, encounter, raid, and siege candidate paths unchanged.
- Added compact `target_debug_reason` data to resource candidates so assigned raids can carry a short reason without storing the full breakdown.
- Added `tests/ai_economy_pressure_report.gd` and `.tscn` as a focused Godot report/test.

The score breakdown exposes:

- `base_value`
- `persistent_income_value`
- `recruit_value`
- `scarcity_value`
- `denial_value`
- `route_pressure_value`
- `town_enablement_value`
- `objective_value`
- `faction_bias`
- `travel_cost`
- `guard_cost`
- `assignment_penalty`
- `final_priority`
- `debug_reason`

## River Pass Findings

Focused report command:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
```

The report passed these deterministic River Pass cases:

- `signal_post_owned`: player-controlled `river_signal_post` outranks `north_timber`, `southern_ore`, and `eastern_cache`.
- `signal_post_and_free_company_owned`: player-controlled `river_free_company` ranks first among resource targets and `river_signal_post` ranks second.
- Simple pickups do not outrank owned persistent signal-yard sites in the resource report.
- The full target selector still chooses `riverwatch_hold` as the top target in the tested opening siege context, so town pressure can still dominate when the strategic front says it should.

Representative score reasons:

- `river_free_company`: `denies 40 gold daily, recruit denial, player-town support`.
- `river_signal_post`: `denies 20 gold daily, route vision, player-town support`.

## Boundaries Preserved

The scoring is based on current content and current state only: claim rewards, daily control income, claim/weekly recruits, current `gold`/`wood`/`ore` scarcity, player control, route pressure, player-town support, objective proximity, faction strategy weights, travel distance, guard hint, and duplicate assignment penalty.

No hidden difficulty bonus was added. Difficulty remains handled by the existing difficulty systems.

The player-facing threat summary behavior remains intact. The new detailed output is report/debug-oriented, with only compact target reasons attached to resource candidates.

## Follow-Up

Next slice should be `strategic-ai-economy-pressure-report-gate-10184`:

- Review the focused report output and decide whether the gate passes.
- Decide whether compact public threat reason surfacing is enough or whether a reusable AI event stream should be planned next.
- Only tune coefficients if AcOrP sees poor target ordering in manual play or report review.
