# Overworld Object Content Batch 005 Dwellings And Guarded Dwellings Report

Status: implementation evidence.
Slice: `overworld-object-content-batch-005-dwellings-guarded-dwellings-10184`.

## Summary

Batch 005 normalizes and expands neutral dwelling object content.

Current repo truth had 25 existing neutral dwelling map objects, so the implemented batch covers 33 Batch 005 map objects:

- 25 existing dwelling normalizations.
- 4 new basic dwelling variants for undercovered regions.
- 4 guarded high-value dwelling variants.

Map object count after the batch: 339 map objects.
Resource site count after the batch: 135 resource sites.

## Contract Coverage

Every Batch 005 dwelling object authors:

- `content_batch_id` or `normalized_content_batch_id`.
- `primary_class: "neutral_dwelling"` and neutral recruitment tags.
- explicit `footprint`, `body_tiles`, and adjacent `approach.visit_offsets`.
- linked `resource_site_id` with matching `dwelling_contract`.
- recruit roster expectations tied to an existing neutral dwelling family.
- guard expectation metadata with neutral guard army and encounter references.
- `editor_placement`, `ai_hints`, and runtime-boundary metadata.

The batch covers all authored biomes and footprint contracts `2x1`, `2x2`, `3x2`, and `3x3`. Guarded variants are Storm Rook Eyrie, Mirror-Bound Barracks, Furnace Oath Yard, and Drowned Crown Hall.

## Boundaries

This is metadata-only object/content implementation where behavior is not already supported by current neutral dwelling site handling.

No broad dwelling runtime migration is included.
No recruitment UI overhaul is included.
No scenario placement migration is included.
No renderer sprite import is included.
No save migration is included.
No rare-resource activation is included.
No market changes, rare-resource economy activation, pathing runtime migration, or economy rebalance is included.
`wood` remains canonical.

## Validation

Validator/report coverage was extended so `python3 tests/validate_repo.py --overworld-object-report` reports Batch 005 counts, existing normalization, new basic dwellings, guarded high-value dwelling variants, linked site contracts, roster and guard expectations, shape/approach readiness, biome coverage, metadata-only boundaries, no rare-resource activation, and no non-canonical wood alias.
