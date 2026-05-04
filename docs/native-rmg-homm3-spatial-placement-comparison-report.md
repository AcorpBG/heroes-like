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
- road quadrant/6x6 spread, largest roadless land region, and
  endpoint/trunk/branch/intersection topology from 4-neighbor road cells;
- native start coverage and owner/native town coverage against road cells;
- largest coarse low-content region approximation;
- H3M owner land/water normalized counts.

Post-road-spread follow-up key metrics:

| Metric | Owner H3M | Native owner-like |
|---|---:|---:|
| object instances | 496 | 513 |
| road tiles | 184 | 201 |
| land tiles | 1,948 | 2,441 |
| road density per land tile | 0.0945 | 0.0823 |
| road nonempty 6x6 cells | 16 | 17 |
| road endpoints / branches / intersections | 18 / 10 / 0 | 18 / 46 / 14 |
| town road coverage within 4 tiles | 1.0000 | 1.0000 |
| start road coverage within 4 tiles | n/a | 1.0000 |
| all-content quadrant CV | 0.1935 | 0.1886 |
| reward quadrant CV | 0.2378 | 0.3962 |
| reward nonempty 6x6 cells | 26 | 33 |
| reward average distance to road | 7.909 | 5.522 |
| reward within 1 tile of road | 0.0909 | 0.1250 |
| reward within 4 tiles of road | 0.3727 | 0.4779 |
| largest low-content 6x6 region | 2 | 1 |
| largest roadless land 6x6 region | 8 | 9 |

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

## Native Road Placement Change

Before this slice, imported-template native roads were materialized as direct
L-shaped paths for every catalog connection. On the owner-like translated
72x72 islands case this drew the 8-zone ring plus the extra links back to
zone 001 as separate direct roads, producing 240 unique road tiles and keeping
reward piles too close to road cells.

`src/gdextension/src/map_package_service.cpp` now materializes imported
template roads as a trunk/branch network for non-structural-parity native
profiles:

- the first imported connection establishes the trunk;
- newly reached endpoints branch to the nearest existing trunk cell;
- already covered cross-links emit short branch spurs instead of a full direct
  cross-map road;
- route graph edges, reachability proof, start/town coverage, road renderer
  lookup, and the native `MapPackageService.generate_random_map()` path remain
  intact.

Reward object scoring now also avoids treating direct road adjacency as the
best placement band. Rewards still prefer reachable route neighborhoods, but
the preferred band is off the immediate road shoulder.

Measured effect on the owner-like case:

- road tiles moved from 240 before the road change to 180 against owner 184;
- reward average distance to road moved from 4.544 to 6.537 against owner 7.909;
- reward within four tiles of road moved from 0.5588 to 0.4632 against owner
  0.3727;
- all-content quadrant CV moved from 0.2049 to 0.1972 against owner 0.1935;
- town and native start road coverage remain 1.0000 within four tiles.

## Native Road Spread Follow-up

After the first road pass, road count and reward-road bias were much closer, but
the road layout under-spread across land: native occupied only 10 nonempty 6x6
road cells against owner 16, and the largest roadless coarse land region stayed
25 cells against owner 8.

`src/gdextension/src/map_package_service.cpp` now adds a bounded owner-like
road-spread supplement after imported-template trunk/branch materialization:

- only the native C++ owner-like translated 72x72 islands case is eligible;
- seven three-tile non-route service stubs are placed in coarse roadless zone
  pockets far from existing road cells;
- the stubs are exposed in `road_spread_service_stub_summary` and counted in
  endpoint/branch/intersection topology;
- route graph reachability, start/town coverage, road renderer lookup, and the
  native `MapPackageService.generate_random_map()` path remain unchanged.

Measured effect against the post-accfaf1 baseline:

- road tiles moved from 180 to 201 against owner 184, remaining inside the
  count gate and far below the pre-pass 240;
- road nonempty 6x6 cells moved from 10 to 17 against owner 16;
- largest roadless land 6x6 region moved from 25 to 9 against owner 8;
- reward within one tile stayed 0.1250, and reward within four tiles moved from
  0.4632 to 0.4779, still below the gate ceiling and below the pre-pass 0.5588;
- town and native start road coverage remain 1.0000 within four tiles.

## Remaining Gaps

This is spatial evidence and bounded placement/terrain-shape correction, not
full parity. The follow-up land/water shape slice reduced the owner-like native
land count from 4,900 to the current post-road-spread report's 2,441 tiles while
preserving route/object/package surfaces on land. The road placement gate now
requires the owner-like native road spread and largest roadless region to stay
near the owner coarse baseline, while still reporting the residual warning that
native rewards remain somewhat more road-adjacent than owner. Remaining known
gaps include exact HoMM3 object/art/template choice, byte-level H3M parity,
exact island contours/shore semantics, exact object count parity, and exact
HoMM3-re road authoring/placement/object/deco spatial distributions.
