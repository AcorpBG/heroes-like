# Native RMG Guard/Reward Package Adoption Report

Date: 2026-05-04  
Slice: `native-rmg-guard-reward-package-adoption-10184`

## Scope

This slice improves the active native C++ GDExtension random-map package path:

`MainMenu -> ScenarioSelectRules -> MapPackageService.generate_random_map() -> convert_generated_payload() -> save/load .amap`

It does not route generation to `scripts/core/RandomMapGeneratorRules.gd`, does not import HoMM3 art or DEF assets, does not commit generated `.amap` or `.ascenario` files under `maps/`, and does not claim full HoMM3-re parity.

## Implemented

- `convert_generated_payload()` now materializes package/editor/runtime surface fields for generated objects:
  - `package_body_tiles`
  - `package_block_tiles`
  - `package_visit_tiles`
  - `package_occupancy_role`
  - `package_pathing_materialization_state`
- Protected reward/site objects now retain direct package-level guard links:
  - `protected_by_guard`
  - `guarded_by_placement_id`
  - `guard_reference`
  - `guarded_access_requirements`
  - `guard_link`
  - guarded passability and AI/pathing hints
- Guard records now serialize as blocking package surfaces with neutral-stack passability metadata.
- Native non-parity object placement now reserves materialized road cells before placing non-town objects, preventing reward/site body block masks from landing on traversable road corridors.
- Map metadata and conversion reports include `native_random_map_guard_reward_package_adoption_summary_v1`.

## Evidence

New report:

`tests/native_random_map_guard_reward_package_adoption_report.tscn`

Passed across four package save/load cases:

- Small `frontier_spokes_v1`: 26 rewards, 31 guards, 7 guarded rewards retained after save/load, 0 non-guard road block conflicts.
- Medium `translated_rmg_template_024_v1`: 88 rewards, 69 valuable rewards, 56 guarded valuable rewards, 28 high-value rewards, 0 non-guard road block conflicts.
- Large `translated_rmg_template_042_v1`: 400 rewards, 304 valuable rewards, 220 guarded valuable rewards, 135 high-value rewards, 0 non-guard road block conflicts.
- XL `translated_rmg_template_043_v1`: 726 rewards, 580 valuable rewards, 452 guarded valuable rewards, 220 high-value rewards, 0 non-guard road block conflicts.

Aggregate package-loaded surface:

- 1,240 reward records
- 953 valuable reward records
- 728 guarded valuable reward records
- 383 high-value reward records
- 345 guarded medium reward records
- 1,548 guard records
- 13,670 package block tiles
- 8,018 package visit tiles

## Remaining Gaps

This is a package/editor/runtime surface adoption improvement. It does not prove exact HoMM3-re object placement, byte format, art, reward table, creature-bank behavior, or full generator parity. Actual live interaction resolution still depends on the existing runtime rules consuming these package records correctly.
