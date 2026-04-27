# Overworld Object Route-Effect Authoring Validation Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `overworld-object-route-effect-authoring-validation-10184`.

## Scope

This slice makes selected transit object route-effect authoring safer and more useful in tooling. It is metadata-only: `object_repaired_ferry_stage` and `object_rope_lift` now author route-effect contracts, body masks, linked approach endpoints, interaction cadence, editor placement hints, and AI hints for report/validator consumption.

The overworld object report now includes a `route_effect_authoring` section and the baseline validator checks route-effect shape for authored transit objects.

## Validated Boundary

- `route_effect` must declare a stable effect id, supported effect type, visit/owner booleans, movement cost delta, toll resources, blocked state ids, and linked endpoint group when applicable.
- Transit objects must keep route/transit tags, `conditional_pass`, `conditional` interaction cadence, and `linked_endpoint` approach metadata.
- `body_tiles` and `approach.visit_offsets` are checked as separate authored surfaces; linked endpoint exits must match visit offsets.
- Public route-effect text fields, if authored later, are checked against internal score/debug token leaks.

No public/internal score leaks are introduced. The report may expose route-effect authoring details because it is tooling-only.

## Deferred

No route-effect runtime adoption was performed. No broad pathing migration, renderer import, save migration, `SAVE_VERSION` bump, broad resource migration, rare-resource activation, or strategic AI rewrite was performed.

`wood` remains canonical; no alternate wood alias or replacement resource was introduced.
