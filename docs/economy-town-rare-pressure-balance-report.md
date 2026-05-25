# Economy Town Rare Pressure Balance Report

Slice: `economy-town-rare-pressure-balance-20260524-10184`

This slice tightens the high-tier rare-resource pressure in the town-development economy goal. Earlier gates proved all nine resources are live, active scenarios expose source coverage, every authored town can fully develop within 30 turns, and rare resources are restricted away from normal markets. This slice makes rare resources a meaningful late-development constraint instead of a token cost.

The faction signature unit-building ladders now use a 4/8/10 rare-resource tier curve on tiers 5, 6, and 7. Selected late unique town buildings keep additional faction-rare costs, so every authored town now spends at least `MIN_RARE_DEVELOPMENT_SPEND = 24` faction rare resources during full development. Each authored town also has at least one selected late unique building represented as an explicit rare-cost high-tier upgrade chain through `upgrade_from`, so upgrades participate in the rare-pressure gate instead of only existing as parallel late buildings.

The deterministic balance gate also caps post-completion rare surplus with `MAX_ENDING_RARE_AFTER_COMPLETION = 13` and now records high-tier unit-building pacing floors. Current evidence covers 15 authored towns, all still completing inside the 30-turn target and at or after the day-20 production pacing floor.

This keeps the intended cost shape:

- town development mainly costs `gold`, `wood`, and `ore`;
- high-tier buildings and late unique upgrades require the faction rare resource;
- rare-cost upgrades stay chained behind tier 5+ development;
- rare resources remain authored-source driven;
- normal markets remain common-resource only.

This is rare-pressure balance evidence for the current authored town-development model. It is not final campaign balance, final encounter pacing, final route safety, final strategic AI quality, final town UI/art approval, or final exact-price approval.

No `SAVE_VERSION` bump. `wood` remains canonical.
