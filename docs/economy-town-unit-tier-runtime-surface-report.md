# Economy Town Unit Tier Runtime Surface Report

Status: implementation evidence.

Slice: `economy-town-unit-tier-runtime-surface-20260524-10184`

## Scope

This slice wires faction unit-tier identity into the live town action surface. `TownRules.get_build_actions` now emits `unlocked_unit_id`, `unit_tier`, and `tier_label` for unit-unlocking buildings, and `TownRules.get_recruit_actions` emits `unit_tier` and `tier_label` for recruit orders.

The focused report `town_unit_tier_runtime_surface_report_v1` creates isolated live town sessions for each faction seed town and validates all six seven-tier signature ladders through runtime `TownRules` actions. It proves tier 1-4 signature unit buildings stay common-resource only, tier 5-7 signature unit buildings cost the faction rare resource, build/recruit summaries expose the tier label, and seed-town starting signature buildings surface the same tier identity through recruit actions once they are already built.

## Evidence Boundaries

- Runtime town build/recruit actions now expose seven-tier unit identity directly.
- The report covers six factions, seven signature unit-building tiers per faction, and 42 live tier cases.
- The report covers 39 build-action cases and 3 seed-town starting signature cases that are validated through live recruit actions instead of build-menu availability.
- This is runtime town-development surface evidence, not final town UI layout, final scenario-wide economy pacing, or campaign balance approval.
- Rare resources remain authored-source driven; normal town markets stay common-resource only.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
