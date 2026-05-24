# Economy Active Scenario AI Town Development Runway Report

Status: implementation evidence.

Slice: `economy-active-scenario-ai-town-development-runway-20260524-10184`

## Scope

This slice adds `active_scenario_ai_town_development_runway_report_v1`, a focused Godot report that boots every active authored campaign/skirmish scenario with an enemy-owned town and simulates live AI town construction for each enemy-town case. Current evidence covers 16 active authored scenarios and 20 active enemy-town cases.

The report secures scenario-authored economy sources that provide resources required by that town's authored build list, then drives `EnemyTurnRules.run_enemy_turn` until the enemy town completes its development target or the 30-turn limit is reached. Each case records completion day, build count, secured daily income, rare-resource spend, full live treasury tracking, and whether a same-day second AI build is blocked.

## Evidence

- Current focused evidence completes all 20 active enemy-town cases within the 30-turn target.
- Current focused evidence observes high-tier rare-resource spending in all 20 active enemy-town cases.
- Current focused evidence proves same-day second AI builds are blocked in all 20 active enemy-town cases.
- Enemy treasuries now preserve all nine live stockpile resources: `gold`, `wood`, `ore`, `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`.
- Enemy town build selection now passes the current day into build readiness, and successful AI construction stamps `last_build_day`.
- Town market affordability now rejects restricted rare-resource deficits instead of treating normal-market common resources as coverage for high-tier rare costs.
- Rare-resource front sites now provide rare income plus gold pacing, and active enemy towns have matching scenario-authored rare-resource access.

## Evidence Boundaries

- This is AI town-development economy runway evidence, not final strategic AI quality.
- This is not final route safety, encounter pacing, guard pressure, campaign balance, or enemy objective-play approval.
- The runway assumes relevant authored economy sources have been secured for the isolated evidence session.
- Normal town markets remain common-resource only.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
