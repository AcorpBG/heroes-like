# Economy Active Scenario Town Economy Source Route Report

Status: implementation evidence.

Slice: `economy-active-scenario-town-economy-source-route-20260524-10184`

## Scope

This slice closes the active-scenario economy route-access gap left by the town-development runway reports. Those reports proved that towns can fully develop after scenario-authored economy sources are secured; this report proves the player-owned and enemy-owned towns can reach authored wood, ore, and all six rare-resource sources through live overworld route rules before that construction runway is assumed.

The focused report `active_scenario_town_economy_source_route_report_v1` boots every active authored campaign/skirmish scenario through `ScenarioFactory.create_session`, normalizes the live overworld state, and checks each player-owned and enemy-owned town against required wood, ore, and all six rare-resource sources. Route search uses `OverworldRules.tile_is_blocked`, `OverworldRules.tile_is_actionable_route_destination`, and `OverworldRules.tile_step_cuts_blocked_corner`. Actionable encounter and site tiles remain valid steps because a legal multi-action route can clear them before continuing; blocked non-actionable tiles remain impassable.

## Evidence

- Coverage: 18 active scenarios, all available through campaign and skirmish, 20 player-town cases, 160 player resource route cases, and 160 reachable player route cases.
- Split player-town coverage: 20 campaign player-town cases and 20 skirmish player-town cases.
- Enemy coverage: 22 enemy-town cases, 176 enemy resource route cases, and 176 reachable enemy route cases.
- Split enemy-town coverage: 22 campaign enemy-town cases and 22 skirmish enemy-town cases.
- Required common routes are capped at 24 steps, and required rare-resource routes are capped at 40 steps.
- Each town case requires reachable wood, ore, and all six rare-resource routes.
- Guard-adjacent resource sources remain identified as guarded route targets; this report does not remove combat pressure.
- Lockmarsh Surge now gives Riverwatch local reachable wood and ore sources and keeps Murkward's inner ore route reachable.
- normal markets remain common-resource only; rare-resource access remains authored-source driven.

## Evidence Boundaries

- This is active authored-scenario resource route-access evidence, not final encounter pacing.
- It does not auto-resolve guarded fights, tune combat rewards, or claim final campaign balance approval.
- The existing active-scenario development runway reports remain the evidence for 30-turn town completion after reachable sources are secured.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
