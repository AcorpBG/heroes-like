# Native RMG HoMM3 Spatial Placement Comparison Report

Slice: `native-rmg-homm3-spatial-placement-comparison-10184`
Date: 2026-05-04

## Scope

This report adds an empirical spatial comparison between the owner-attached
HoMM3 H3M and native C++ GDExtension random map output. Active generation
remains `MapPackageService.generate_random_map()` through the native package
path. No generated `.amap`/`.ascenario` files and no HoMM3 art/assets are
imported.

## Implemented Evidence

- Added `tests/native_random_map_homm3_spatial_placement_comparison_report.tscn`.
- The report decompresses and parses the owner H3M attachment directly:
  `/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz`.
- Parsed owner attachment anchors:
  - H3M version: 28.
  - size: 72x72.
  - gzip bytes: 12,952.
  - decompressed bytes: 61,868.
  - tile stream offset: 624.
  - object definition offset: 36,912.
  - object definitions: 297.
  - placed object instances: 496.
  - road tiles from tile byte 4: 184.
- Native owner-like case:
  - seed: `1777897383`.
  - template/profile: `translated_rmg_template_001_v1` /
    `translated_rmg_profile_001_v1`.
  - size/water: `homm3_medium`, `islands`.

## Metrics

The comparison now reports:

- object/deco/reward/guard/town density by quadrant and 6x6 coarse grid;
- nearest-neighbor distances by category;
- reward/deco/guard/town distance to roads and road-adjacency ratios;
- road coverage normalized by whole map and land tiles;
- largest coarse low-content region approximation;
- H3M owner land/water normalized counts.

Post-change key metrics:

| Metric | Owner H3M | Native owner-like |
|---|---:|---:|
| object instances | 496 | 344 |
| road tiles | 184 | 240 |
| land tiles | 1,948 | 2,296 |
| all-content quadrant CV | 0.1935 | 0.3560 |
| reward quadrant CV | 0.2378 | 0.3499 |
| reward nonempty 6x6 cells | 26 | 26 |
| reward average distance to road | 7.909 | 5.287 |
| reward within 4 tiles of road | 0.3727 | 0.5662 |
| largest low-content 6x6 region | 2 | 3 |

## Native Placement Change

Before this slice, non-town native generated mines, dwellings, and rewards were
chosen by expanding outward from each zone anchor. The owner H3M comparison
showed the native owner-like map still skewed heavily into southwest coarse
cells for rewards and guards.

`src/gdextension/src/map_package_service.cpp` now scatters non-town zone objects
across deterministic coarse-grid targets inside their owning zone. The fallback
anchor-ring behavior remains only if a zone has no valid scatter candidate.
Support resources near player starts remain on the existing start-support path.

Measured effect on the owner-like case:

- all-content quadrant CV improved from 0.5123 before the change to 0.3560;
- reward quadrant CV improved from 0.5849 to 0.3499;
- guard quadrant CV improved from 0.8008 to 0.5968;
- largest low-content coarse region improved from 4 cells to 3 cells.

## Remaining Gaps

This is spatial evidence and bounded placement/terrain-shape correction, not
full parity. The follow-up land/water shape slice reduced the owner-like native
land count from 4,900 to 2,296 tiles while preserving route/object/package
surfaces on land. Remaining known gaps include exact HoMM3 object/art/template
choice, byte-level H3M parity, exact island contours/shore semantics, exact
object count parity, and exact HoMM3 road/object/deco spatial distributions.
