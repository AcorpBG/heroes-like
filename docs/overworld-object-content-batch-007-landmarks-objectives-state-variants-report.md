# Overworld Object Content Batch 007 Landmarks Objectives And State Variants Report

Status: implementation evidence.

Slice: `overworld-object-content-batch-007-landmarks-objectives-state-variants-10184`.

## Summary

Batch 007 adds and normalizes faction landmarks, scenario objective object families, and damaged/captured/claimed state-variant metadata in `content/map_objects.json` and `content/resource_sites.json`.

- 20 Batch 007 map objects and 20 linked resource-site metadata records.
- Repository totals after the batch: 386 map objects and 185 resource sites.
- Category coverage: 9 faction landmarks, 7 scenario objective object families, and 4 state variants.
- The three existing faction landmark objects are normalized into the Batch 007 contract.
- All six factions have landmark coverage, and all nine biomes have at least two Batch 007 definitions.

## Boundary

Batch 007 is metadata-only content implementation.

- No broad objective runtime migration.
- No scenario placement migration.
- No renderer sprite import.
- No save migration.
- No rare-resource activation.
- No market changes, UI inventory work, or economy rebalance.
- No public/internal score leaks.
- `wood` remains canonical.

Public text is limited to compact key/summary boundaries for hover or selection surfaces. These objects do not use map text panels as the main implementation.

## Validation Coverage

`tests/validate_repo.py` now reports Batch 007 in the overworld object report and validates:

- exact object and linked-site counts;
- role split for faction landmarks, scenario objective objects, and state variants;
- footprint/body/approach contracts;
- linked landmark, objective, and state-variant contracts;
- faction and biome coverage;
- damaged/captured/claimed state variant metadata;
- metadata-only runtime boundaries;
- no rare-resource activation;
- no non-canonical wood alias;
- public text leak guards.

Validation target:

- Batch 007 errors: 0
- Batch 007 warnings: 0
