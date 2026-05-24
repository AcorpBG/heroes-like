# Economy Runtime Market Cap Persistence Report

Slice: `economy-runtime-market-cap-persistence-20260524-10184`

## Result

Normal town markets now use persisted weekly caps for live exchange orders.

- Standard market caps: buy 6 wood, buy 6 ore, sell 8 wood, sell 8 ore per town per week.
- River exchange towns receive a wood cap bonus.
- Resonant exchange towns receive an ore cap bonus.
- Usage is stored on each runtime town as `town.market_usage`, normalized by week, and preserved through save/resume.
- Buy/sell actions expose cap metadata, disable when exhausted, and reject over-cap execution at the rule layer.
- Normal markets remain common-resource only. Rare resources stay outside ordinary market buying and must come from authored economy sources.

## Focused Gate

`tests/runtime_market_cap_persistence_report.tscn` boots `glassroad-sundering`, seeds a controlled market stockpile, exhausts buy and sell caps, verifies over-cap actions fail, saves and restores the session, verifies the exhausted caps remain enforced, advances to the next week, and verifies caps reset.

This is a runtime cap and persistence increment. It is not final scenario-wide economy tuning, final market UI art, broad AI economy strategy, or a final campaign balance approval.
