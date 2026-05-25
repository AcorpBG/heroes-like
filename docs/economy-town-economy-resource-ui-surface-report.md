# Economy Town Resource UI Surface Report

Status: implementation evidence.

Slice: `economy-town-resource-ui-surface-20260524-10184`

## Scope

This slice closes a player-facing town economy surface gap. TownShell now keeps the compact visible stockpile line, but also exposes a full nine-resource ledger tooltip, player-readable `Economy Plan`, and validation snapshot through `validation_resource_ledger_snapshot`. That keeps the screen compact while making zero-valued rare resources, daily income, next build, next muster, field-site value, and the current build bottleneck readable in the live town UI path.

The focused report `town_economy_resource_ui_surface_report_v1` instantiates TownShell for six faction seed towns. Each case stages an authored high-tier rare-cost building with its prerequisites already built, proves the missing faction rare resource blocks the build action, proves normal-market coverage does not satisfy the rare-resource shortfall, proves the economy plan names that rare resource as the build bottleneck, stocks the rare resource and proves the same action becomes directly affordable, then executes the selected build through live town rules, refreshes TownShell, and proves the same-day construction surface is locked out.

## Evidence

- The report covers six faction seed towns and all six live rare resources: aetherglass, embergrain, peatwax, verdant grafts, brass scrip, and memory salt.
- TownShell visible resource text stays compact for common resources and positive rare resources.
- TownShell tooltip and validation ledger include all nine live stockpile resources, including zero-valued rares.
- TownShell tooltip now includes `Economy Plan` lines for daily income, next build, build bottleneck, next muster, and field sites.
- Rare-cost build actions expose `direct_affordable`, `market_coverable`, `shortfall_summary`, and `disabled_reason` through the live town action catalog.
- Current focused evidence includes 6/6 player-readable economy plan cases, 6/6 rare bottleneck surface cases, and 6/6 ready build plan surface cases.
- Normal markets remain common-resource only for wood and ore; normal markets remain common-resource only in the focused gate.
- Current focused evidence includes 6/6 same-day build lockout cases: after a real build selected from the TownShell action surface, post-build construction action count is zero, enabled construction action count is zero, the town records `last_build_day`, and remaining unbuilt buildings carry the same-day build guard.

## Evidence Boundaries

- This is live TownShell resource-ledger and build-readiness surface evidence, not final town UI art direction.
- This does not change economy pricing, market rules, save schema, or scenario-wide pacing.
- Rare resources remain authored-source driven and high-tier-development gated.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
