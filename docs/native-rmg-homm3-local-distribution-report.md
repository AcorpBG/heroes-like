# Native RMG HoMM3 Local Distribution Report

Date: 2026-05-04

## Scope

This report covers the active native C++ GDExtension random-map package path:

`MainMenu -> ScenarioSelectRules -> MapPackageService.generate_random_map()`

It does not route generation to `scripts/core/RandomMapGeneratorRules.gd`, does not import HoMM3 assets, does not commit generated map packages, and does not claim full parity.

## Problem Evidence

After `ed0dad2`, the owner-like 72x72 native islands case had improved global land-normalized density, but visual inspection still showed:

- large land areas with little or no interactive content;
- localized piles of objects, guards, and reward packages;
- reward/guard clusters that could become much larger than intended guarded-site groups.

The pre-fix spatial comparison gate still passed, but its metrics showed the local shape of the issue:

- native reward average nearest-neighbor distance: about `2.015`;
- native guard average nearest-neighbor distance: about `2.615`;
- native guard SW quadrant count: `53`, versus owner SW guard count `16`;
- native object count: `488`.

## Implementation

`src/gdextension/src/map_package_service.cpp` now scores native non-decoration object candidates with a deterministic local-distribution policy:

- coarse-grid scatter per zone;
- spacing penalties against nearby non-decoration placements;
- same-zone, same-kind, local-window, and map-quadrant pressure;
- road-reachability pressure that rejects genuinely off-road interactive candidates without forcing all rewards into one road-adjacent pile;
- existing guarded reward packages remain compact local groups.

Object guard materialization also limits additional low-priority site guards in already crowded guard windows while preserving high-value reward guarding. Compact decoration density was retained to preserve fill coverage and land-normalized object density after guard pile reduction.

The first scoring implementation created a transient sorted candidate dictionary for every eligible zone cell. On large/XL validation cases that made the guard/reward package adoption report allocate into multi-GB RSS territory under the OpenClaw gateway cgroup. The final implementation keeps the same owner-like 72x72 scoring result, but uses a streaming best-candidate scan, a map-level packed road-distance field, and bounded deterministic candidate sampling only for maps larger than 72x72. That removes the OOM trigger while preserving the local-distribution gate surface.

## New Gate

Added:

- `tests/native_random_map_homm3_local_distribution_report.gd`
- `tests/native_random_map_homm3_local_distribution_report.tscn`

The report measures the owner-like native 72x72 islands case with:

- 12x12 sliding land windows at step 6;
- empty interactive window ratio;
- low interactive+guard window ratio;
- max interactive, interactive+guard, and guarded-package pile windows;
- interactive density coefficient of variation;
- largest low-content 6x6 land region;
- nearest-neighbor summaries for decorations, interactives, guards, guarded packages, interactive+guard combined content, and towns.

Passing evidence from the validated run:

- object count: `511`;
- empty interactive window ratio: `0.04`;
- low interactive+guard window ratio: `0.04`;
- max interactive window count: `19`;
- max interactive+guard window count: `26`;
- max guarded-package window count: `14`;
- interactive density CV: `0.7981`;
- largest low-content land region: `3`;
- interactive average nearest-neighbor distance: `3.301`;
- interactive+guard close-pair ratio <= 2: `0.8341`.

## Existing Gate Preservation

The existing spatial comparison gate passed after the native scoring change:

- native reward quadrant CV: `0.4154` under the `0.45` threshold;
- native reward within-4-tiles-of-road ratio: `0.5588` over the `0.55` threshold;
- native reward average distance to road improved relative to owner by `-3.365`;
- largest low-content region delta: `-1`.

The land-normalized density gate remained in range during tuning with total object density ratio over the required floor and guarded high-value rewards still present.

## Validation And Memory

Validated on 2026-05-04 with one Godot run at a time and explicit timeouts:

- local distribution report: pass, `0:10.73`, peak RSS `545008 KB`;
- guard/reward package adoption report: pass, `2:25.99`, peak RSS `1132992 KB`, including the XL case;
- land-normalized density report: pass, `0:11.01`, peak RSS `559456 KB`;
- land/water shape report: pass, `0:11.00`, peak RSS `559256 KB`;
- spatial placement comparison report: pass, `0:11.53`, peak RSS `545004 KB`;
- full parity gate: pass, `0:22.41`, peak RSS `580480 KB`.

## Remaining Gaps

This is a bounded local-distribution improvement, not exact HoMM3 placement parity. The native output still intentionally has compact guarded reward groups, and some windows can remain denser than neighboring land when roads, zones, and reward packages overlap. Broader templates, underground variants, and large maps still rely on their existing report gates unless selected for separate local-distribution slices.
