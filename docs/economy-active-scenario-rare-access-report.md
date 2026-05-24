# Economy Active Scenario Rare Access Report

Status: implementation evidence.

Slice: `economy-active-scenario-rare-access-20260524-10184`

## Scope

This slice closes the active authored-scenario rare-resource access gap in the town-development economy goal. Every active campaign/skirmish scenario with a player-owned town now includes an authored rare-resource source matching that town's `development_balance.rare_resource_id`.

The focused Godot report `active_scenario_rare_economy_access_report_v1` boots every active authored scenario through `ScenarioFactory.create_session`, places the active hero on the matching rare source, claims it through `OverworldRules.collect_active_resource`, verifies player control through `OverworldRules.controlled_resource_site_income`, and advances one day through `OverworldRules.end_turn` to prove next-day rare income.

## Evidence Boundaries

- Active authored scenarios now expose live rare-source access for high-tier town-development resources.
- Rare resources remain authored-source driven; normal town markets stay common-resource only.
- The report uses deterministic hero placement on the source to isolate live economy collection and income rules.
- This is not final scenario-wide economy tuning, route/path safety, encounter pacing, campaign balance, or final town UI/art.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
