# Economy Town Resource UI Surface Report

Status: implementation evidence.

Slice: `economy-town-resource-ui-surface-20260524-10184`

## Scope

This slice closes a player-facing town economy surface gap. TownShell now keeps the compact visible stockpile line, but also exposes a full nine-resource ledger tooltip and validation snapshot through `validation_resource_ledger_snapshot`. That keeps the screen compact while making zero-valued rare resources auditable in the live town UI path.

The focused report `town_economy_resource_ui_surface_report_v1` instantiates TownShell for six faction seed towns. Each case stages an authored high-tier rare-cost building with its prerequisites already built, proves the missing faction rare resource blocks the build action, proves normal-market coverage does not satisfy the rare-resource shortfall, then stocks the rare resource and proves the same action becomes directly affordable.

## Evidence

- The report covers six faction seed towns and all six live rare resources: aetherglass, embergrain, peatwax, verdant grafts, brass scrip, and memory salt.
- TownShell visible resource text stays compact for common resources and positive rare resources.
- TownShell tooltip and validation ledger include all nine live stockpile resources, including zero-valued rares.
- Rare-cost build actions expose `direct_affordable`, `market_coverable`, `shortfall_summary`, and `disabled_reason` through the live town action catalog.
- Normal markets remain common-resource only for wood and ore; normal markets remain common-resource only in the focused gate.

## Evidence Boundaries

- This is live TownShell resource-ledger and build-readiness surface evidence, not final town UI art direction.
- This does not change economy pricing, market rules, save schema, or scenario-wide pacing.
- Rare resources remain authored-source driven and high-tier-development gated.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
