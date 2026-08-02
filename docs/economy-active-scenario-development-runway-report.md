# Economy Active Scenario Development Runway Report

Status: implementation evidence.

Slice: `economy-active-scenario-development-runway-20260524-10184`

## Scope

This slice adds `active_scenario_town_development_runway_report_v1`, a focused Godot report that boots every active authored campaign/skirmish scenario with a player-owned town and simulates live town construction for each player-town case. Current evidence covers 16 active authored scenarios, including 15 campaign scenarios and 16 skirmish scenarios, plus 18 active player-town cases.

The report secures a minimal set of scenario-authored economy sources that provide the required non-gold resources for that town's authored build list, then drives `TownRules.get_build_actions` and `OverworldRules.build_in_active_town` until the town completes its development target or the 30-turn limit is reached. Each case records completion day, build count, `source_adoption_policy`, secured source resources, rare-resource spend, one-build-per-town-per-turn rejection, and common-only market boundaries.

The strengthened gate now runs construction inside the full scenario session state instead of replacing the scenario with a stripped local runway. Each row records the authored map size plus scenario resource-node, encounter, and enemy-state counts, and `full_session_case_count` must match the covered player-town cases. Day advancement uses a focused active-scenario economy-day step that applies live town income and controlled resource-site income without invoking the full strategic enemy turn loop for every simulated build day.

The latest strengthening keeps completed towns inside the active scenario session through the rest of the 30-turn development window, applies recovery relief and weekly musters, then proves the owning faction's seven-tier ladder through live recruit actions. Each completed case calls `TownRules.get_recruit_actions`, checks tier metadata, availability, weekly growth, and direct affordability, then recruits one unit from every tier through `OverworldRules.recruit_in_active_town`.

The delayed-source strengthening adds `active_scenario_town_delayed_source_replay_v1` inside the same report. Each player-town case now also runs a fresh full scenario session where authored economy sources are not granted up front. Source ownership is delayed by live route-derived acquisition days using 12 route steps per day, plus one extra day for guarded sources. The delayed replay then reruns live town construction against the same 30-turn target, proving 18/18 delayed-source replay cases and current completion days from day 21 to day 25 with at least five days of remaining margin.

The delayed-source replay now also saves and restores each case after route-derived source acquisition has mutated the active scenario resource nodes and after the first rare-resource building has been constructed. The restored session must preserve the active town, resources, built buildings, `last_build_day`, available recruits, applied source-node claim/control state, town resume target, and `SAVE_VERSION`, then it must keep the same-day build guard active before continuing the 30-turn development runway. Current focused evidence proves 18/18 delayed-source save/resume checkpoints.

## Evidence Boundaries

- The report covers active authored scenarios and active player-town cases.
- Current focused evidence covers 17 campaign player-town cases and 18 skirmish player-town cases.
- Current focused evidence completes all 18 active player-town cases inside the day-24-to-day-30 pacing window, with main runway completion days ranging from day 24 to day 26.
- Current focused evidence proves 18/18 active player-town source adoption cases use `minimal_required_resource_coverage` instead of granting every matching authored economy source up front.
- Current focused evidence observes high-tier rare-resource spending in every case.
- Current focused evidence completes 18/18 active player-town recruitment cases after development and recruits 126/126 tier recruitment cases through live active-town recruitment.
- Current focused evidence completes 18/18 delayed-source replay cases after route-derived source acquisition delays, with delayed completion days ranging from day 21 to day 25.
- Current focused evidence completes 18/18 delayed-source save/resume checkpoints after source acquisition and rare-resource construction, then continues construction from the restored active scenario session.
- Secured sources must come from the active scenario's authored `resource_nodes`; no synthetic resource sites are added.
- The Highwater bridgehead in `ironbridge-stand` and Graftroot Caravan in `mireford-skirmish` include the authored `bridge_ore_reserve` ore source so their full development runway can still afford sequential tier 4-7 recruitment by turn 30.
- Construction preserves the active scenario's authored overworld state, including map, resource nodes, encounters, and enemy state data.
- Focused economy-day advancement is intentional report scope; it proves town/resource-income runway without treating strategic AI turns as part of this gate.
- The secured-source runway remains as an isolation proof, while the delayed-source replay adds route/guard timing pressure. This is still not final scenario-wide route balance; full encounter pacing and manual-play campaign approval remain separate scenario-balance concerns.
- Construction still uses live town rules, build action surfaces, resource spending, daily income, and same-day build rejection.
- Save/resume coverage uses `SaveService.save_runtime_manual_session` and `SaveService.restore_manual_session`; it does not change save schema ownership or bump `SAVE_VERSION`.
- Rare resources remain authored-source driven; normal town markets stay common-resource only.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
