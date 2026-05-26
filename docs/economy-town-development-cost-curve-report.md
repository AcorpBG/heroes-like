# Economy Town Development Cost Curve Report

Status: implementation evidence.

Slice: `economy-town-development-cost-curve-20260524-10184`

## Scope

This slice closes a cost-shape regression gap in the owner-directed town economy goal. Earlier gates prove town development can complete within 30 turns and that rare resources are live. This gate proves the development cost curve keeps the intended production shape: town development mainly costs gold, wood, and ore, while high-tier development uses every rare resource with faction-readable pressure.

The deterministic report `town_development_cost_curve_report_v1` parses authored factions, towns, buildings, and units. It covers 15 authored towns and all six faction signature ladders.

## Evidence

- Every authored development target costs gold.
- Every authored town spends wood and ore somewhere in its development curve.
- Gold remains the dominant numeric development cost in every town curve.
- Each town keeps at least a 2:1 common-only to rare-cost building ratio.
- Rare-cost high-tier unit buildings must use every rare resource.
- Rare-cost buildings must pair rare resources with gold, wood, and ore.
- Rare costs are gated behind tier 5+ development through the seven-tier faction signature ladder or a prerequisite chain that depends on tier 5+ construction.
- Six faction signature ladders keep seven unit-building tiers, with tiers 1-4 common-resource only and tiers 5-7 using the all-rare curve: faction signature rare `4/8/10`, faction secondary rare `3/5/6`, and every remaining rare `2/3/4`.
- The signature rare still follows the 4/8/10 curve, preserving the previous late-game faction bottleneck shape.
- Every authored town now spends at least 24 faction signature rare resources across full development, so high-tier rare costs are meaningful rather than token blockers.
- In short, every town still spends at least 24 faction rare resources, while the secondary and remaining rares add lighter pressure.
- Every authored town spends all six rares across high-tier development. Current deterministic pressure is 28-30 signature rare, 14 secondary rare, and 9 for each remaining rare.
- Every authored town includes at least one rare-cost high-tier upgrade building with explicit `upgrade_from` metadata behind tier 5+ development. Current deterministic coverage is 15/15 towns with 15 total rare-cost upgrade chains.
- Every authored town must stay inside deterministic price-band sanity limits for total development cost: `gold` 34000-45000, `wood` 20-38, `ore` 20-38, faction signature rare 24-32, secondary rare 12-16, remaining rare min/max 8-11, 20-24 target buildings, and 4-7 rare-cost buildings. This rejects extreme price regressions before manual exact-price approval.

## Evidence Boundaries

- This is authored cost-curve and prerequisite-shape evidence, not final campaign balance approval.
- It does not replace manual exact-price approval, encounter pacing, route safety, strategic AI quality, or final town UI/art.
- Existing runtime and active-scenario runway reports remain the evidence for 30-turn completion through live construction rules.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
