# Overworld Object Content Batch 001 Core Density And Pickups Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `overworld-object-content-batch-001-core-density-pickups-10184`.

## Implemented

This slice adds the first corrective P2.4 object-content batch as production JSON content, not documentation-only planning.

- Added 12 passable, non-interactable scenic decorations in `content/map_objects.json`.
- Added 8 non-interactable blocker or edge-blocker decorations with explicit `body_tiles`.
- Added 6 live common pickup objects for current resources only: `gold`, `wood`, and `ore`.
- Added 5 linked live pickup site records in `content/resource_sites.json` and normalized the existing `site_ore_crates` with a map object.
- Added 4 staged rare-resource pickup records as report-only metadata with no live `resource_site_id`, no visitability, and no live reward grant.
- Extended `tests/validate_repo.py` so the overworld object report summarizes Batch 001 counts and rejects live rare-resource activation in this batch.

## Boundaries

Rare-resource pickup records remain staged/report-only metadata. They do not activate rare resources in live economy, costs, markets, grants, saves, or migration.

No renderer sprite import, save migration, `SAVE_VERSION` bump, broad pathing migration, scenario placement migration, or UI-only completion claim was performed.

`wood` remains the canonical live resource id.

## Validation

- `python3 tests/validate_repo.py --overworld-object-report`
  - Batch 001 report: 30 objects, 12 scenic decorations, 8 blocking/edge decorations, 6 live common pickups, 4 staged rare pickups, 0 Batch 001 errors.
