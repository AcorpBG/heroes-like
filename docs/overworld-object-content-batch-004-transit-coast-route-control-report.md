# Overworld Object Content Batch 004 Transit Coast And Route Control Report

Status: implementation evidence.
Slice: `overworld-object-content-batch-004-transit-coast-route-control-10184`.

## Summary

Batch 004 adds or normalizes 24 Batch 004 map objects for transit, coast, harbor, and route-control authoring.

Map object count after the batch: 331 map objects.
Resource site count after the batch: 127 resource sites.

Category coverage:

- 6 two-way transit contracts, including normalized Ferry Stage and Rope Lift records.
- 4 one-way transit contracts.
- 6 route-lock gate contracts.
- 6 coast/harbor route object contracts.
- 2 route waypoint/control marker contracts.

## Contract Coverage

Every Batch 004 object authors:

- `content_batch_id` or `normalized_content_batch_id`.
- explicit `footprint`, `body_tiles`, and linked `approach.visit_offsets`.
- linked `resource_site_id` with transit profile metadata.
- `linked_endpoint_contract` on the object and linked site.
- `route_effect` metadata and route-effect boundary metadata.
- guard or event expectation metadata.
- `editor_placement` and `ai_hints`.
- metadata-only `runtime_boundary`.

The batch covers two-way, one-way, conditional-lock, and coast-route endpoint directionality. Footprint coverage includes `1x1`, `1x2`, `2x1`, `2x2`, `2x3`, `3x1`, and `3x2` objects across all authored biomes. Coast applicability metadata is present for harbor/coast objects and selected coast-adjacent transit records.

## Boundaries

This is metadata-only content implementation where runtime behavior is not already adopted.

No route-effect runtime adoption is included.
No full ship movement system is included.
No renderer sprite import is included.
No save migration is included.
No rare-resource activation is included.
No market, UI inventory, live ship system, pathing runtime migration, scenario placement migration, or broad economy rebalance is included.
`wood` remains canonical.

## Validation

Validator/report coverage was extended so `python3 tests/validate_repo.py --overworld-object-report` reports Batch 004 counts, route role coverage, linked endpoint contracts, route-effect metadata-only boundaries, coast applicability, footprint/body/approach readiness, biome coverage, no rare-resource activation, and no live ship-system adoption.
