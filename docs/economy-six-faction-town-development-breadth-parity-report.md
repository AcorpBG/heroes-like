# Economy Six-Faction Town Development Breadth Parity Report

Status: implementation evidence.

Slice: `economy-six-faction-town-development-breadth-parity-20260524-10184`

## Scope

This slice closes the town-development breadth gap where Thornwake, Brasshollow, and Veilmourn towns could satisfy the previous 30-turn gate with only seven unit-ladder buildings. Those towns now have faction-flavored non-unit economy, support, magic, and civic development targets in addition to the seven-tier unit ladder.

The deterministic and live Godot town-development reports now require every authored town to expose at least 20 buildable development targets and at least 12 non-unit development targets. The deterministic gate requires a day-24 production pacing floor plus early/mid/late phase distribution, while the live secured-income fixture keeps its day-20 runtime pacing floor so a town cannot satisfy the 30-turn target by finishing as a shallow rush arc. The newer six-faction scaffold towns additionally carry `six_faction_town_breadth_parity` building records so their expanded arcs are explicit content, not accidental generic filler.

## Evidence

- Thornwake towns gained Rootroad Markers, Loam Ledger, Pollen Litany, Bramblewall Coppice, and Old Grove Accord.
- Brasshollow towns gained Scalehouse, Clause Court, Heatwright Vestry, Gauge Arsenal, and Debtworks Vault.
- Veilmourn towns gained Fog Signal Buoys, Salvage Ledger, Wake Oratory, Black-Sail Loft, and Memory Anchor.
- Thornwake towns now also include Rootweave Tithe, Bramble Marshal Moot, Spore-Oath Chantry, Thornwarden Husk Yard, and Verdant Concord Seat as late faction-unique non-unit development.
- Brasshollow towns now also include Ledger Mint, Foreman Clausehouse, Caliper Sanctum, Redline Assembly Yard, and Brassbound Directorate as late faction-unique non-unit development.
- Veilmourn towns now also include Salt Counting House, Mourner Pilot Guild, Tideglass Chapel, Drowned Map Room, and Memory-Rite Court as late faction-unique non-unit development.
- Thornwake towns add Root-Cairn Watch, Sap-Chandler Grove, and Bastion Seed Conclave to keep the live secured-economy build count at production pacing.
- Brasshollow towns add Quenchwright Bay, Rail Tax Office, and Warrant Engine House to keep the live secured-economy build count at production pacing.
- Veilmourn towns add Bell-Chain Watch, Saltwake Factor, and Drowned Admiralty to keep the live secured-economy build count at production pacing.
- `tests/town_development_balance_report.py` now reports and gates target-building count, non-unit-building count, and six-faction breadth-parity coverage.
- `tests/town_development_runtime_balance_report.gd` now gates the same breadth shape through live `OverworldRules` and `TownRules` construction.

## Evidence Boundaries

- This is town-development breadth and balance-shape evidence, not final campaign balance.
- The 30-turn cap remains the production target; this slice prevents seven-building-only towns from counting as fully developed.
- Normal markets remain common-resource only.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.
