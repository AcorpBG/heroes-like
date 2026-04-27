# Overworld Object Editor Authoring Validation Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `overworld-object-editor-authoring-validation-10184`.

## Scope

This slice keeps overworld object taxonomy work in validator, report, and fixture surfaces. It does not adopt pathing, body-tile occupancy, approach behavior, renderer behavior, save behavior, or AI valuation.

## Implemented Evidence

The opt-in overworld object report now includes an `editor_authoring` section with:

- primary-class palette groups for editor object browsing;
- taxonomy/editor metadata readiness counts per object;
- role mismatch and unsupported legacy `map_roles` diagnostics;
- scenario-local 16x16 density diagnostics;
- placed resource-site instances that still lack a linked `map_object` authoring record.

Strict overworld object fixtures now validate editor-placement metadata more tightly. Fixture objects must provide a supported `density_band` or `density_bucket`; optional placement modes, boolean flags, and lane-clearance values are type checked. The invalid fixture set includes `bad_editor_placement_missing_density_band`.

## Current Findings

The report confirms the taxonomy is now more useful for editor authoring review, but production object authoring is not complete:

- `9` palette groups are emitted from current map-object classes.
- `3` objects are taxonomy/editor ready under this report surface, all from the lifted neutral encounter object records.
- `0` production objects currently provide top-level `editor_placement`.
- `3` neutral encounter objects provide nested `neutral_encounter.editor_placement`.
- `56` placed resource-site instances still depend on site-only authoring gaps.
- `19` scenario density regions require review, mostly because placed resource sites lack map-object links.

These are report diagnostics, not runtime errors.

## Validation

Validated with:

```bash
python3 tests/validate_repo.py --strict-overworld-object-fixtures --overworld-object-report --overworld-object-report-json /tmp/overworld-object-report-dev.json
```

The focused command passed and wrote JSON with `editor_authoring.schema` set to `overworld_object_editor_authoring_report_v1`.

## Deferred

Pathing/occupancy adoption, approach-tile behavior, route-effect behavior, renderer integration, save migration, and `SAVE_VERSION` changes remain deferred to explicit later slices. Economy policy remains unchanged: `wood` is canonical, no alternate wood-resource alias was introduced, and rare resources stay staged/report-only.
