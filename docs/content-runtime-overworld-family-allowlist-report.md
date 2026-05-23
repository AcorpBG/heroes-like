# Content Runtime Overworld Family Allowlist Report

Slice: `content-runtime-overworld-family-allowlist-20260523-10184`

This slice aligns `ContentService.gd` runtime validation with the authored overworld content families already accepted by repository validation. Recent Godot report logs emitted repeated `unsupported family` warnings for valid authored resource-site and map-object records, which made headless balance and simulation output look more debug-like than it should.

## Runtime Families

Runtime resource-site validation now accepts:

- `staged_resource_front`
- `support_producer`
- `shrine`
- `sign_waypoint`
- `scenario_objective`
- `faction_landmark`

Runtime map-object validation now accepts:

- `staged_resource_front`
- `support_producer`
- `sign_waypoint`
- `scenario_objective`

## Boundary

This is an allowlist alignment and validation-noise reduction slice. No new object interaction mechanics are added, and this does not activate rare resources, rewrite scenario scripting, change generated-map behavior, or alter authored content payloads.
