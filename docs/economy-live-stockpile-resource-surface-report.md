# Economy Live Stockpile Resource Surface Report

Slice: `economy-live-stockpile-resource-surface-breadth-20260524-10184`.

This slice closes a live economy wiring gap left after rare resources became real stockpile ids. The rules and town balance gates already used the full stockpile set, but the global resource summary and generated-map opening resource line still collapsed the player-facing surface to `Gold | Wood | Ore`.

## Implemented

- `OverworldRules.describe_resources` now delegates to a stockpile summary built from `LIVE_STOCKPILE_RESOURCE_KEYS`.
- `OverworldRules.describe_resource_stockpile(..., include_zero_rare)` can emit all nine live resources, including zero-valued rare resources for audit/report surfaces.
- Runtime resource normalization, resource additions, spending, income merging, market-cost coverage, player daily income projection, and controlled site income now preserve all live stockpile keys.
- `ScenarioFactory` seeds all live stockpile keys when creating scenario resources so new sessions start with the same resource dictionary shape.
- The generated-map opening surface now uses `OverworldRules.describe_resources` instead of a hard-coded common-resource string.

## Focused Report

`tests/live_stockpile_resource_surface_report.tscn` creates a River Pass skirmish session, seeds all nine resources, injects one controlled rare-resource site for each rare id, then verifies:

- normalized session resources contain exactly `gold`, `wood`, `ore`, `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`;
- full audit summaries can display zero-valued rare resources;
- visible summaries display every rare resource once the player has a non-zero stockpile;
- controlled site income exposes all stockpile keys and gives each injected rare resource its daily income;
- `OverworldRules.end_turn` applies rare-resource income through the live turn path;
- save/resume preserves the full stockpile, controlled income, and resource summary text.

This is a production-readiness increment for resource wiring and resource surfaces. It is not final scenario-wide economy balance, market-cap persistence, final town UI art, or broad AI economy planning.
