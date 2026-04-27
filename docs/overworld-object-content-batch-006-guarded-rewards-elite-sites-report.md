# Overworld Object Content Batch 006 Guarded Rewards And Elite Sites Report

Date: 2026-04-27.
Slice: `overworld-object-content-batch-006-guarded-rewards-elite-sites-10184`.
Status: implementation evidence.

## Implementation

Batch 006 adds and normalizes guarded reward and elite site content in `content/map_objects.json` and `content/resource_sites.json`.

Implemented coverage:

- 32 Batch 006 map objects and 32 linked guarded reward resource-site records.
- 369 map objects total after this batch.
- 165 resource sites total after this batch.
- 8 minor guarded rewards.
- 8 major guarded rewards.
- 8 creature-bank-like elite sites.
- 8 guarded route/reward hybrids.
- The two existing guarded reward site records, `object_barrow_vault` and `object_drowned_reliquary`, are normalized into the Batch 006 contract.

Every Batch 006 object authors:

- explicit `footprint`, `body_tiles`, and adjacent `approach.visit_offsets`;
- `guard_link`, `guard_expectation`, and linked site `guard_profile` metadata;
- `guarded_reward_contract` metadata on both object and linked site;
- `reward_preview` and reward category metadata;
- biome applicability, editor placement, AI hints, and placeholder animation cues;
- metadata-only runtime boundaries for guard resolution, broad reward migration, route effects, pathing adoption, save payloads, renderer sprites, scenario placement migration, market changes, and rare-resource activation.

## Coverage

The batch covers all 9 authored biomes with at least 4 guarded reward definitions per biome.

Footprint coverage:

- `2x1`
- `2x2`
- `2x3`
- `3x1`
- `3x2`
- `3x3`
- `4x2`
- `4x3`

Reward category coverage:

- `resource`
- `artifact`
- `spell`
- `recruit`
- `scouting`
- `route`
- `town_support`
- `objective`

Guard risk coverage includes `light`, `standard`, `heavy`, and `elite`.

## Boundaries

Batch 006 is metadata/content implementation.

No neutral encounter migration.
No broad reward runtime migration.
No renderer sprite import.
No save migration.
No rare-resource activation.

The batch also does not add scenario placement migration, market changes, UI inventory, or economy rebalance.

Rare-resource references remain staged/report-only metadata and are not live grants, costs, markets, or save payloads. `wood` remains canonical; no non-canonical wood alias is introduced.

No internal/debug/score fields are intended for player-facing/public text.

## Validation

Validator/report coverage was extended so `python3 tests/validate_repo.py --overworld-object-report` reports Batch 006 counts, role coverage, shape contracts, linked site contracts, guard links, guard contracts, reward category coverage, biome coverage, metadata-only boundaries, no rare-resource activation, and no non-canonical wood alias.

Current focused report result:

- Batch 006 errors: 0
- Batch 006 warnings: 0
