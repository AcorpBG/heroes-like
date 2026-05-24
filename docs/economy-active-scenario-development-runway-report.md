# Economy Active Scenario Development Runway Report

Status: implementation evidence.

Slice: `economy-active-scenario-development-runway-20260524-10184`

## Scope

This slice adds `active_scenario_town_development_runway_report_v1`, a focused Godot report that boots every active authored campaign/skirmish scenario with a player-owned town and simulates live town construction for each player-town case. Current evidence covers 16 active authored scenarios and 18 active player-town cases.

The report secures scenario-authored economy sources that provide resources required by that town's authored build list, then drives `TownRules.get_build_actions` and `OverworldRules.build_in_active_town` until the town completes its development target or the 30-turn limit is reached. Each case records completion day, build count, secured source resources, rare-resource spend, one-build-per-town-per-turn rejection, and common-only market boundaries.

## Evidence Boundaries

- The report covers active authored scenarios and active player-town cases.
- Current focused evidence completes all 18 active player-town cases within the 30-turn target and observes high-tier rare-resource spending in every case.
- Secured sources must come from the active scenario's authored `resource_nodes`; no synthetic resource sites are added.
- The runway assumes the relevant authored economy sources have been secured, so this is not final scenario-wide route balance; route safety, encounter pacing, and guard pressure remain separate scenario-balance concerns.
- Construction still uses live town rules, build action surfaces, resource spending, daily income, and same-day build rejection.
- Rare resources remain authored-source driven; normal town markets stay common-resource only.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
