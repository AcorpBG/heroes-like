# Overworld Object Runtime Metadata Adoption Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `overworld-object-runtime-metadata-adoption-10184`.

## Adopted Safe Metadata

This slice adopts only the safe metadata needed for runtime classification and report text:

- `primary_class`
- `secondary_tags`
- `interaction.cadence`

The adopted surface is `OverworldRules.describe_resource_site_interaction_surface()`, which is used by overworld inspection, map tooltips, editor inspection, and validation helper surfaces. Runtime role text now prefers authored `secondary_tags` when present and falls back to legacy `map_roles` when absent. Class and cadence reporting continue to read authored `primary_class` and `interaction.cadence` when present, with legacy resource-site inference as compatibility fallback.

## Validation Evidence

Focused runtime proof:

- `tests/overworld_object_runtime_metadata_report.gd`
- `tests/overworld_object_runtime_metadata_report.tscn`

The report exercises the current runtime helper against safe bundle objects:

- `object_wood_wagon` / `site_wood_wagon`: pickup class, one-time cadence, safe secondary tags.
- `object_brightwood_sawmill` / `site_brightwood_sawmill`: persistent economy class, persistent-control cadence, safe secondary tags.
- `object_wayfarer_infirmary` / `site_wayfarer_infirmary`: interactable-site class, cooldown cadence, safe secondary tags.

Repository validation now records the report adapter as `classification_reporting_safe_metadata` and lists the adopted fields in the opt-in overworld object report.

## Deferred

No pathing, occupancy, approach, renderer, AI valuation, route effect, save/load, or save-version behavior was adopted. `passability_class` remains validated/reportable metadata only; legacy `passable` and `visitable` stay authoritative for runtime behavior.

No save migration, `SAVE_VERSION` bump, broad production JSON migration, or resource economy migration was performed. `wood` remains canonical and no alternate wood-resource alias path was introduced.
