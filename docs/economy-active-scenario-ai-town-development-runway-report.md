# Economy Active Scenario AI Town Development Runway Report

Status: implementation evidence.

Slice: `economy-active-scenario-ai-town-development-runway-20260524-10184`

## Scope

This slice adds `active_scenario_ai_town_development_runway_report_v1`, a focused Godot report that boots every active authored campaign/skirmish scenario with an enemy-owned town and simulates live AI town construction for each enemy-town case. Current evidence covers 16 active authored scenarios and 20 active enemy-town cases.

The report secures scenario-authored economy sources that provide resources required by that town's authored build list, then drives `EnemyTurnRules.run_enemy_town_economy_turn` until the enemy town completes its development target or the 30-turn limit is reached. Each case records completion day, build count, secured daily income, rare-resource spend, full live treasury tracking, and whether a same-day second AI build is blocked.

The strengthened gate now runs construction inside the full scenario session state instead of replacing the scenario with a stripped local runway. Each row records authored map size plus scenario resource-node, encounter, and enemy-state counts, and `full_session_case_count` must match the covered enemy-town cases. The report keeps scope on target-faction town economy and `EnemyTurnRules.town_governor_pressure_report`; it does not claim full strategic AI routing quality.

The delayed-source strengthening adds `active_scenario_ai_town_delayed_source_replay_v1` inside the same report. Each enemy-town case now also runs a fresh full scenario session where target-faction economy sources are not granted up front. Source ownership is delayed by live route-derived acquisition days using 12 route steps per day, plus one extra day for guarded sources. The delayed replay then reruns `EnemyTurnRules.run_enemy_town_economy_turn` against the same 30-turn target, proving 20/20 delayed-source replay cases and current completion days from day 20 to day 23 with at least seven days of remaining margin.

The delayed-source AI replay now also saves and restores each case after route-derived source acquisition has mutated active scenario resource nodes and after the first rare-resource building has been constructed by `EnemyTurnRules.run_enemy_town_economy_turn`. The restored session must preserve target enemy treasury, target town buildings, `last_build_day`, available recruits, applied source-node claim/control state, overworld resume target, and `SAVE_VERSION`; it must also keep the target-town same-day AI build guard active before continuing the 30-turn runway. Current focused evidence proves 20/20 delayed-source AI save/resume checkpoints.

## Evidence

- Current focused evidence completes all 20 active enemy-town cases within the 30-turn target.
- Current focused evidence observes high-tier rare-resource spending in all 20 active enemy-town cases.
- Current focused evidence proves same-day second AI builds are blocked in all 20 active enemy-town cases.
- Current focused evidence proves all active enemy-town cases run inside full active scenario sessions with authored map, resource nodes, encounters, and enemy state data preserved.
- Current focused evidence completes 20/20 delayed-source replay cases after route-derived source acquisition delays, with delayed completion days ranging from day 20 to day 23.
- Current focused evidence completes 20/20 delayed-source AI save/resume checkpoints after source acquisition and rare-resource construction, then continues construction from the restored active scenario session.
- Ninefold Confluence now gives Bellwake Harbor local authored wood and ore reserve nodes on its reachable harbor-front economy tile, matching its memory-salt front so Veilmourn AI development has common-plus-rare runway access.
- Enemy treasuries now preserve all nine live stockpile resources: `gold`, `wood`, `ore`, `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`.
- Enemy town build selection now passes the current day into build readiness, and successful AI construction stamps `last_build_day`.
- Town market affordability now rejects restricted rare-resource deficits instead of treating normal-market common resources as coverage for high-tier rare costs.
- Rare-resource front sites now provide rare income plus gold pacing, and active enemy towns have matching scenario-authored rare-resource access.

## Evidence Boundaries

- This is AI town-development economy runway evidence, not final strategic AI quality.
- This is not final route safety, encounter pacing, guard pressure, campaign balance, or enemy objective-play approval.
- The secured-source runway remains as an isolation proof, while the delayed-source replay adds route/guard timing pressure. This is still not final route safety, encounter pacing, guard pressure, campaign balance, or enemy objective-play approval.
- Save/resume coverage uses `SaveService.save_runtime_manual_session` and `SaveService.restore_manual_session`; it does not change save schema ownership or bump `SAVE_VERSION`.
- Normal town markets remain common-resource only.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
