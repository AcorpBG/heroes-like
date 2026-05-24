# Economy Town Unique Building Runtime Payoff Report

Slice: `economy-town-unique-building-runtime-payoff-20260524-10184`
Report schema: `town_unique_building_runtime_payoff_report_v1`

## Scope

This slice closes the six-faction unique non-unit town building payoff gap in the economy and town-development goal. It now covers six factions, 15 authored towns, at least 56 faction-unique non-unit buildings, and 127 runtime payoff cases.

Every faction now exposes at least five unique non-unit buildings per faction, and every authored faction town includes at least five unique non-unit buildings per authored town. Embercourt, Mireclaw, and Sunvault retain their faction-specific economy, support, magic, defense, and civic buildings; Thornwake, Brasshollow, and Veilmourn now carry deeper late unique non-unit chains so their full town arcs no longer finish as shallow 12-build paths.

## Runtime Evidence

`tests/town_unique_building_runtime_payoff_report.tscn` builds every unique non-unit town building through live `TownRules` and `OverworldRules` surfaces in a fully funded fixture. Each case must expose a build action, spend authored resources, build successfully, report player-facing impact text, and change a live income, readiness, pressure, reinforcement, spell, or market surface.

The report also proves at least one rare-cost unique building per faction, with rare costs restricted to the owning faction's rare resource. No `SAVE_VERSION` bump was needed, and `wood` remains canonical.

## Boundary

This is a town-development production-readiness increment for faction identity and runtime payoff coverage. It is not final scenario balance, final town UI art, broad strategic AI quality, campaign pacing approval, or final economy tuning.
