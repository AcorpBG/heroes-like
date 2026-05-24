# Economy Active Scenario Town Start Economy Report

Slice: `economy-active-scenario-town-start-economy-20260524-10184`

Report schema: `active_scenario_town_start_economy_report_v1`

## Scope

This slice adds a focused live Godot report for natural active-scenario town-start economy readiness. It covers 16 active authored scenarios and 18 player-town cases without injected source capture.

Each case boots the authored scenario through `ScenarioFactory`, copies the natural starting town, stockpile, and resource-node state into an isolated town-economy fixture, then drives first-week construction through live `OverworldRules.end_turn`, `OverworldRules.build_in_active_town`, and `TownRules.get_build_actions`.

## Evidence

- Every active player-town start completes at least three natural first-week builds.
- Every case spends `wood` or `ore` through live construction before the week ends.
- The one-build-per-day guard is observed in every case.
- Build actions are blocked after a same-day build in every case.
- All nine live stockpile ids are normalized in every active-scenario start case.
- The report uses natural active-scenario starts and does not grant resources or claim sources.
- No `SAVE_VERSION` bump.
- `wood` remains canonical.

## Boundaries

This is first-week town economy readiness evidence. It is not final campaign balance, route safety, encounter pacing, final town UI art, full strategic AI quality, or final scenario difficulty approval.
