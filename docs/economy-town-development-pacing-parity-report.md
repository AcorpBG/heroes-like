# Economy Town Development Pacing Parity Report

Slice: `economy-town-development-pacing-parity-20260524-10184`
Report schemas: `town_development_balance_report_v1`, `town_development_runtime_balance_report_v1`, `town_unique_building_runtime_payoff_report_v1`

## Scope

This slice tightens the economy and town-development goal from "can complete by turn 30" to a production-shaped pacing window. The previous six-faction expansion left Thornwake, Brasshollow, and Veilmourn towns with shallow 12-build arcs that could finish far earlier than the older authored towns. Those towns now have deeper late non-unit development chains, and the deterministic plus live Godot gates reject shallow town arcs.

## Implementation

- Thornwake towns gained Rootweave Tithe, Bramble Marshal Moot, Spore-Oath Chantry, Thornwarden Husk Yard, Verdant Concord Seat, Root-Cairn Watch, Sap-Chandler Grove, Bastion Seed Conclave, Mycorrhizal Store, and Rootlaw Moot.
- Brasshollow towns gained Ledger Mint, Foreman Clausehouse, Caliper Sanctum, Redline Assembly Yard, Brassbound Directorate, Quenchwright Bay, Rail Tax Office, and Warrant Engine House.
- Veilmourn towns gained Salt Counting House, Mourner Pilot Guild, Tideglass Chapel, Drowned Map Room, Memory-Rite Court, Bell-Chain Watch, Saltwake Factor, and Drowned Admiralty.
- The deterministic balance report now requires at least 20 buildable development targets, at least 12 non-unit targets, and a day-20 production pacing floor while preserving the 30-turn cap.
- The live Godot runtime report gates the same minimum breadth and day-20 pacing floor through `OverworldRules.end_turn`, `OverworldRules.build_in_active_town`, same-day build rejection, rare-resource spend, and post-development seven-tier recruitment.

## Evidence

- Deterministic report: 15/15 authored towns pass, minimum buildable target count is 20, minimum non-unit count is 12, and completion days now range from day 23 to day 28.
- Live Godot runtime report: 15/15 authored towns pass, minimum buildable target count is 20, minimum non-unit count is 12, and completion days now range from day 20 to day 23 under the secured-income fixture.
- Unique-building payoff report: six factions, 15 authored towns, 127 runtime payoff cases, and at least 56 faction-unique non-unit buildings with live income/readiness/pressure/reinforcement/spell/market consequences.

## Boundaries

This is a production-readiness increment for town-development pacing and faction town breadth. It is not final campaign balance, encounter pacing, strategic AI quality, final town UI art, or final economy tuning approval. No `SAVE_VERSION` bump is required, and `wood` remains canonical.
