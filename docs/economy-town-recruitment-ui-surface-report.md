# Economy Town Recruitment UI Surface Report

Status: implementation evidence.

Slice: `economy-town-recruitment-ui-surface-20260524-10184`

## Scope

This slice adds `town_recruitment_ui_surface_report_v1`, a focused Godot report that instantiates the live `TownShell` for each faction seed town after its seven signature unit buildings are present and all seven faction units are waiting in reserve.

The report validates the player-facing recruitment surface, not just headless rule output. Each faction case checks that the live Muster tab exposes seven recruit actions, that every action has matching `unit_tier` and `tier_label` metadata, that button text and tooltips include the visible `Tier 1` through `Tier 7` labels, that the recruitment tooltip names every tier/unit, that direct affordability is positive, and that unit portraits load for all seven recruit orders.

## Evidence Boundaries

- Current focused evidence covers six faction seed towns and 42/42 recruitment UI tier cases.
- The report uses live `TownShell`, `TownRules.get_recruit_actions`, unit portrait loading, and TownShell validation snapshots.
- The report is a player-facing recruitment-readiness gate for the existing town economy and seven-tier unit ladder work.
- This is not final town art, final UI layout approval, exact price tuning, scenario-wide route safety, encounter pacing, or campaign balance approval.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
