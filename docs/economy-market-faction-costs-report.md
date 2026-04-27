# Economy Market And Faction Costs Report

Status: implemented bounded validation/report slice.
Date: 2026-04-27.
Slice: `economy-market-faction-costs-10184`.

## Scope

This slice does not activate rare resources, add live rare-resource costs, broaden normal market exchange, migrate saves, or rebalance faction costs.

The implemented evidence is a focused validator/report that proves the currently supported hooks are bounded:

- normal town markets remain common-resource only: `wood` and `ore`;
- staged rare resources remain report-only and are not buyable through normal markets;
- strict market-cap fixtures define weekly common-resource caps for future live adoption without claiming runtime cap state;
- live recruitment costs already apply faction, town, and building discount profiles through `OverworldRules.town_recruit_cost`;
- discount hooks preserve the original resource keys and do not create hidden grants.

## Implementation

- Added `market_faction_cost_report_v1` to `tests/validate_repo.py`.
- Added default validation for normal-market resource bounds, rare-resource gates, save-version stability, and faction/town/building recruitment discount evidence.
- Added opt-in report flags:
  - `--market-faction-cost-report`
  - `--market-faction-cost-report-json <path>`
- Kept live stockpile resources as `gold`, `wood`, and `ore`.
- Kept `wood` as the canonical resource id.
- Preserved `SAVE_VERSION 9`.

## Explicit Non-Changes

- No rare-resource runtime activation.
- No normal-market rare-resource buying.
- No live weekly market-cap state or save serialization.
- No AI behavior migration beyond validating the existing common-resource market and live recruitment-cost hooks.
- No broad market migration or faction rebalance.

## Validation Evidence

Required focused validation:

- `python3 tests/validate_repo.py --market-faction-cost-report --market-faction-cost-report-json /tmp/heroes-market-faction-cost-report.json`
- `python3 -m json.tool /tmp/heroes-market-faction-cost-report.json >/tmp/heroes-market-faction-cost-report-json.txt`

This focused report is intentionally paired with the economy resource report and strict economy fixtures so rare resources remain staged until source paths, UI display, save state, AI behavior, and normal-market restrictions are implemented together.
