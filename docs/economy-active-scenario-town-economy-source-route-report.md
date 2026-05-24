# Economy Active Scenario Town Economy Source Route Report

Status: implementation evidence.

Slice: `economy-active-scenario-town-economy-source-route-20260524-10184`

## Scope

This slice closes the active-scenario economy route-access gap left by the town-development runway reports. Those reports proved that towns can fully develop after scenario-authored economy sources are secured; this report proves the player-owned towns can reach authored wood, ore, and faction-rare resource sources through live overworld route rules before that construction runway is assumed.

The focused report `active_scenario_town_economy_source_route_report_v1` boots every active authored campaign/skirmish scenario through `ScenarioFactory.create_session`, normalizes the live overworld state, and checks each player-owned town against required wood, ore, and `development_balance.rare_resource_id` sources. Route search uses `OverworldRules.tile_is_blocked`, `OverworldRules.tile_is_actionable_route_destination`, `OverworldRules.tile_has_route_interaction`, and `OverworldRules.tile_step_cuts_blocked_corner` so the evidence follows the same movement blockers and interaction destinations used by play.

## Evidence

- Coverage: 16 active scenarios, 18 player-town cases, 54 resource route cases, and 54 reachable route cases.
- Required common routes are capped at 24 steps, and required rare-resource routes are capped at 40 steps.
- Each town case requires reachable wood, ore, and faction rare resource routes.
- Guard-adjacent resource sources remain identified as guarded route targets; this report does not remove combat pressure.
- Lockmarsh Surge now gives Riverwatch local reachable wood and ore sources and keeps Murkward's inner ore route reachable.
- normal markets remain common-resource only; rare-resource access remains authored-source driven.

## Evidence Boundaries

- This is active authored-scenario resource route-access evidence, not final encounter pacing.
- It does not auto-resolve guarded fights, tune combat rewards, or claim final campaign balance approval.
- The existing active-scenario development runway reports remain the evidence for 30-turn town completion after reachable sources are secured.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
