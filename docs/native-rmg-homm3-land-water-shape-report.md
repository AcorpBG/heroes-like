# Native RMG HoMM3 Land/Water Shape Report

Slice: `native-rmg-homm3-land-water-shape-parity-10184`  
Date: 2026-05-04

## Scope

This slice corrects a specific native C++ RMG islands failure exposed by the
spatial placement report: owner-like 72x72 islands output was still mostly land.
Active generation remains `MapPackageService.generate_random_map()` through the
native GDExtension package path. No generation is routed through
`scripts/core/RandomMapGeneratorRules.gd`, no generated map packages are
committed under `maps/`, and no HoMM3 art/assets are imported.

## Implemented Change

`src/gdextension/src/map_package_service.cpp` now shapes non-parity native
`water_mode == "islands"` terrain after zone, route, object, town, and guard
placement. The terrain pass builds a water-dominant island mask using:

- the owner 72x72 islands land-ratio target as an empirical reference;
- protected land cells for starts, routes, towns, guards, rewards,
  decorations, generated body/visit/approach surfaces, and package
  body/visit/block surfaces;
- deterministic scoring around protected surfaces and zone anchors for
  repeatable island shapes.

The tracked small structural-parity terrain counts remain on their existing
target path.

## Evidence

New report: `tests/native_random_map_homm3_land_water_shape_report.tscn`.

The report parses the owner H3M gzip directly:
`/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz`.

Owner anchors:

| Metric | Owner H3M |
|---|---:|
| H3M version | 28 |
| size | 72x72 |
| land tiles | 1,948 |
| water tiles | 3,236 |
| land ratio | 0.3758 |
| road tiles | 184 |

Native owner-like case:

| Metric | Before | After |
|---|---:|---:|
| land tiles | 4,900 | 2,296 |
| water tiles | 284 | 2,888 |
| land ratio | 0.9452 | 0.4429 |
| absolute land delta vs owner | 2,952 | 348 |
| land-delta improvement | n/a | 88.21% |

Post-change package/surface checks:

| Surface | Count | Water conflicts |
|---|---:|---:|
| generated road cells | 292 | 0 |
| generated body cells | 1,660 | 0 |
| generated visit cells | 344 | 0 |
| generated approach cells | 1,044 | 0 |
| package body cells | 1,660 | 0 |
| package block cells | 1,648 | 0 |
| package visit cells | 674 | 0 |

Package adoption remains passing in the focused report:

- reward count: 88
- valuable reward count: 64
- guarded valuable reward count: 46
- guard count: 103
- unguarded high-value reward count: 0

## Remaining Gaps

This is a concrete land/water ratio and protected-surface improvement, not full
HoMM3-re parity. Remaining gaps include exact island contours, exact shore
semantics, exact object count, exact road/object/deco distributions, exact
HoMM3 object/reward table behavior, byte parity, and any copyrighted art/asset
parity.
