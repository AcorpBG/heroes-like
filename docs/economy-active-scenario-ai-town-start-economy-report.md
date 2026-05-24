# Economy Active Scenario AI Town Start Economy Report

Slice: `economy-active-scenario-ai-town-start-economy-20260524-10184`

Report schema: `active_scenario_ai_town_start_economy_report_v1`

## Scope

This slice adds a focused live Godot report for natural active-scenario enemy town starts. It covers 16 active authored scenarios and 20 enemy-town cases without injected source capture.

Each case boots the authored scenario through `ScenarioFactory`, copies the natural enemy town, treasury, and resource-node state into an isolated town-economy fixture, then drives first-week construction through `EnemyTurnRules.run_enemy_town_economy_turn`. The helper uses the same live AI town income and construction internals as the full enemy turn while skipping strategic pressure, raid routing, and recruitment delivery, which already have separate gates.

## Evidence

- Enemy town starts now seed their faction treasury from the authored town `development_balance.starting_resources` during `ScenarioFactory.create_session`.
- Every active enemy-town start completes at least three natural first-week AI builds.
- Every case spends `wood` or `ore` through live AI construction before the week ends.
- The one-build-per-town-per-turn guard is observed in every case.
- All nine live treasury ids are normalized in every active enemy-town start case.
- The report uses natural active-scenario enemy town starts and does not grant resources or claim sources.
- No `SAVE_VERSION` bump.
- `wood` remains canonical.

## Boundaries

This is first-week AI town economy readiness evidence. It is not final strategic AI quality, campaign balance, route safety, encounter pacing, guard pressure, final town UI art, or scenario difficulty approval.
