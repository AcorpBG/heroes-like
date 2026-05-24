# Economy Active Scenario Development Runway Report

Status: implementation evidence.

Slice: `economy-active-scenario-development-runway-20260524-10184`

## Scope

This slice adds `active_scenario_town_development_runway_report_v1`, a focused Godot report that boots every active authored campaign/skirmish scenario with a player-owned town and simulates live town construction for each player-town case. Current evidence covers 16 active authored scenarios and 18 active player-town cases.

The report secures scenario-authored economy sources that provide resources required by that town's authored build list, then drives `TownRules.get_build_actions` and `OverworldRules.build_in_active_town` until the town completes its development target or the 30-turn limit is reached. Each case records completion day, build count, secured source resources, rare-resource spend, one-build-per-town-per-turn rejection, and common-only market boundaries.

The strengthened gate now runs construction inside the full scenario session state instead of replacing the scenario with a stripped local runway. Each row records the authored map size plus scenario resource-node, encounter, and enemy-state counts, and `full_session_case_count` must match the covered player-town cases. Day advancement uses a focused active-scenario economy-day step that applies live town income and controlled resource-site income without invoking the full strategic enemy turn loop for every simulated build day.

The latest strengthening keeps completed towns inside the active scenario session through the rest of the 30-turn development window, applies recovery relief and weekly musters, then proves the owning faction's seven-tier ladder through live recruit actions. Each completed case calls `TownRules.get_recruit_actions`, checks tier metadata, availability, weekly growth, and direct affordability, then recruits one unit from every tier through `OverworldRules.recruit_in_active_town`.

## Evidence Boundaries

- The report covers active authored scenarios and active player-town cases.
- Current focused evidence completes all 18 active player-town cases within the 30-turn target and observes high-tier rare-resource spending in every case.
- Current focused evidence completes 18/18 active player-town recruitment cases after development and recruits 126/126 tier recruitment cases through live active-town recruitment.
- Secured sources must come from the active scenario's authored `resource_nodes`; no synthetic resource sites are added.
- Highwater bridgehead starts in `ironbridge-stand` and `mireford-skirmish` include the authored `bridge_ore_reserve` ore source so their full development runway can still afford sequential tier 4-7 recruitment by turn 30.
- Construction preserves the active scenario's authored overworld state, including map, resource nodes, encounters, and enemy state data.
- Focused economy-day advancement is intentional report scope; it proves town/resource-income runway without treating strategic AI turns as part of this gate.
- The runway assumes the relevant authored economy sources have been secured, so this is not final scenario-wide route balance; route safety, encounter pacing, and guard pressure remain separate scenario-balance concerns.
- Construction still uses live town rules, build action surfaces, resource spending, daily income, and same-day build rejection.
- Rare resources remain authored-source driven; normal town markets stay common-resource only.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
