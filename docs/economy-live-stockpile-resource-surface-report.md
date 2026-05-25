# Economy Live Stockpile Resource Surface Report

Slice: `economy-live-stockpile-resource-surface-breadth-20260524-10184`.

This slice closes a live economy wiring gap left after rare resources became real stockpile ids. The rules and town balance gates already used the full stockpile set, but the global resource summary and generated-map opening resource line still collapsed the player-facing surface to `Gold | Wood | Ore`.

## Implemented

- `OverworldRules.describe_resources` now delegates to a stockpile summary built from `LIVE_STOCKPILE_RESOURCE_KEYS`.
- `OverworldRules.describe_resource_stockpile(..., include_zero_rare)` can emit all nine live resources, including zero-valued rare resources for audit/report surfaces.
- Runtime resource normalization, resource additions, spending, income merging, market-cost coverage, player daily income projection, and controlled site income now preserve all live stockpile keys.
- `ScenarioFactory` seeds all live stockpile keys when creating scenario resources so new sessions start with the same resource dictionary shape.
- `NativeRandomMapPackageSessionBridge` seeds generated/native package sessions with the same full nine-resource stockpile contract, preserving the opening common resources while carrying every rare resource at zero.
- `NativeRandomMapPackageSessionBridge` now adapts H3M rare mine proxies into original live rare-resource fronts for strict Small native package sessions, instead of collapsing those mines into common/gold-only sources.
- The generated-map opening surface now uses `OverworldRules.describe_resources` instead of a hard-coded common-resource string.

## Focused Report

`tests/live_stockpile_resource_surface_report.tscn` creates a River Pass skirmish session, seeds all nine resources, injects one controlled rare-resource site for each rare id, then verifies:

- normalized session resources contain exactly `gold`, `wood`, `ore`, `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`;
- full audit summaries can display zero-valued rare resources;
- visible summaries display every rare resource once the player has a non-zero stockpile;
- controlled site income exposes all stockpile keys and gives each injected rare resource its daily income;
- `OverworldRules.end_turn` applies rare-resource income through the live turn path;
- save/resume preserves the full stockpile, controlled income, and resource summary text.

`tests/native_random_map_package_session_adoption_report.tscn` also covers generated/native package sessions. It validates both the direct package bridge and the active disk-loaded package startup path, requiring the opening session stockpile to contain all nine live resources with `gold`, `wood`, and `ore` at the generated-map opening amounts and each rare resource present at zero. The same report now emits `generated_package_town_economy_surface_v1`, proving generated package towns are backed by authored town templates and seven-tier ladders while player-required common and rare resource sources are present in the live generated resource-node surface. It also gates generated town identity diversity so the strict Small package cannot collapse all towns into one template family; current evidence covers 4 generated project factions and 5 generated town templates across 7 generated towns. It also emits `generated_package_player_town_development_runway_v1`, proving the generated player town can use generated resource sources to build all initially missing targets within 30 turns, spend rare resources, preserve one-build-per-day blocking, and recruit all seven tiers; current evidence builds 22 initially missing `town_highwater_keep` targets by day 22.

This is a production-readiness increment for resource wiring and resource surfaces. It is not final scenario-wide economy balance, market-cap persistence, final town UI art, or broad AI economy planning.
