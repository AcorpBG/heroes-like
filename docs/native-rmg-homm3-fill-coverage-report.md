# Native RMG HoMM3 Fill Coverage Report

Date: 2026-05-04

## Scope

This report covers the owner-directed fill correction for native C++ generated
map packages. The active generation path remains:

`MainMenu` -> `ScenarioSelectRules` -> `MapPackageService.generate_random_map()`

No generated-map launch path was routed back through GDScript generation.

## Source Catalog Comparison

HoMM3-re obstacle/deco source evidence from
`/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
and `random-map-decoration-object-placement.md`:

| Metric | Count |
|---|---:|
| `rand_trn` obstacle rows | 109 |
| Unique decorative type names | 33 |
| Mapped DEF template refs | 2425 |
| Unique mapped DEF templates | 415 |

By terrain: dirt 17, grass 17, rough 15, swamp 14, cave 13, sand 11, snow 11,
lava 9, water 2.

Our authored `content/map_objects.json` currently has 199 decoration records,
117 authored decoration/blocker records, and blocker footprint coverage from
1x1 through 6x6, including 60 `blocking_non_visitable` and 57 `edge_blocker`
records. Native generation now samples terrain-biased original blocker families
from those large-footprint proportions, but exact HoMM3 DEF/template identity is
not implemented.

## Fill Gate

The new focused gate is
`tests/native_random_map_homm3_fill_coverage_report.tscn`.

It fails maps that only have nonzero object counts but barren body coverage. The
technical floor is:

- small: at least 18% unique decorative/blocker body coverage;
- medium/large/XL: at least 20% unique decorative/blocker body coverage;
- average decoration footprint at least 8 body tiles;
- at least 90% of decorations using large multi-tile bodies;
- no decorative body overlap with materialized road cells.

The 20% floor is intentionally below an 80% fill target because generated roads,
towns, rewards, mines, guards, starts, and traversability corridors must stay
open. The report prints the remaining gap to 80% as a visible non-parity metric.

## Validation Metrics

The owner-attached pre-fix medium package:

| Metric | Value |
|---|---:|
| Size | 72x72 |
| Objects | 315 |
| Decorations | 72 |
| Unique body coverage | 381 tiles / 7.35% |
| Unique deco/blocker coverage | 144 tiles / 2.78% |
| Blocking coverage | 144 tiles / 2.78% |
| Visit coverage | 315 tiles / 6.08% |
| Average decoration footprint | 2.0 tiles |
| Raw JSON / gzip equivalent | 1,137,126 bytes / 47,451 bytes |

Native generated samples after this correction:

| Case | Size | Objects | Decorations | Roads / cells | Body coverage | Deco/blocker coverage | Blocking coverage | Visit coverage | Avg deco footprint | Per-zone decorations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| small local frontier spokes | 36x36 | 118 | 21 | 9 / 103 | 32.25% | 24.77% | 24.77% | 9.10% | 15.286 | 2-7, avg 5.25 |
| medium translated 024 | 72x72 | 339 | 121 | 8 / 151 | 37.56% | 33.35% | 33.35% | 6.54% | 14.289 | 13-22, avg 17.286 |
| large translated 042 | 108x108 | 1401 | 212 | 46 / 735 | 36.31% | 26.11% | 26.11% | 12.01% | 14.368 | 1-37, avg 23.556 |
| XL translated 043 | 144x144 | 2252 | 331 | 68 / 1904 | 30.82% | 21.55% | 21.55% | 10.86% | 13.502 | 1-39, avg 13.24 |
| attached medium config regenerated | 72x72 | 338 | 95 | 11 / 250 | 29.65% | 24.96% | 24.96% | 6.52% | 13.621 | 3-19, avg 11.875 |

All package surfaces were converted, saved, loaded, and retained road/object
surfaces. No generated `.amap` or `.ascenario` files are committed under
`maps/`.

## Remaining Gaps

Broad native fill density is improved and the attached barren 72x72 case now
fails the new gate before the fix and passes when regenerated through the native
path. Exact HoMM3-re obstacle identity, DEF art/template parity, byte/placement
parity, and compact binary H3M-format parity remain open gaps and should not be
claimed complete from this slice.
