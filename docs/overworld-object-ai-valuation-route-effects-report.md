# Overworld Object AI Valuation And Route Effects Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `overworld-object-ai-valuation-route-effects-10184`.

## Scope

This slice connects selected first-class neutral encounter object metadata to strategic AI valuation and route-pressure reporting. The adopted surface is intentionally bounded:

- `EnemyAdventureRules.neutral_encounter_object_valuation_breakdown(...)` reads object-backed neutral encounter `secondary_tags`, `passability_class`, `guard_link`, nested `ai_hints`, and shape-mask presence.
- `EnemyAdventureRules.neutral_encounter_object_route_pressure_report(...)` exposes tooling/report-only internal valuation values for object-backed encounter placements.
- Encounter target candidates receive a small bounded metadata adjustment only for neutral encounters already present in scenario encounter lists.

The selected proof cases are `river_pass_reed_totemists` and `river_pass_hollow_mire`. They demonstrate scenario-objective guard pressure and route-block pressure from authored object metadata.

## Shape-Mask Boundary

The helper preserves the HoMM-style object contract:

- visual footprint is reported from `footprint`;
- blocking body occupancy is reported from `body_tiles`;
- interaction/approach positions are reported from `approach.visit_offsets`;
- `body_tiles_separate_from_approach` is a report proof flag, not a renderer or migration switch.

No broad neutral encounter pathing adoption was added.

## Public Output Boundary

Internal scores stay report/tooling-only. Public event surfaces receive compact reason text and reason codes, while the new report test checks that score keys such as `object_metadata_value`, `priority_with_object_metadata`, and route-pressure component fields do not appear in public assignment events.

## Validation Evidence

Focused proof:

- `tests/ai_overworld_object_valuation_route_effects_report.gd`
- `tests/ai_overworld_object_valuation_route_effects_report.tscn`

Repository validation now requires the focused helper, report scene, leak check, and this implementation report.

## Deferred

No renderer import or generated asset ingestion was performed. No save migration or `SAVE_VERSION` bump was performed. No broad strategic AI rewrite, wholesale map-object migration, runtime neutral encounter pathing migration, or rare-resource activation was performed. `wood` remains canonical; no alternate wood-resource alias was introduced.
