# Native RMG HoMM3-re Obstacle Identity Comparison Report

Slice: `native-rmg-homm3-re-obstacle-identity-comparison-10184`

## Scope

This is a concrete parity increment after the fill-coverage gate. Native C++
package generation now records HoMM3-re `rand_trn` obstacle source identity on
generated `decorative_obstacle` records while preserving original runtime art
boundaries.

No HoMM3 image or DEF assets are imported. DEF names are provenance/template
references only; generated records map source-row semantics to original authored
proxy blocker families.

## Implemented

- Added `content/homm3_re_obstacle_proxy_catalog.json`, derived from
  `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`.
- Native C++ loads that catalog and chooses terrain-biased source rows for
  decorative obstacles.
- Each native `decorative_obstacle` now carries source provenance including:
  `homm3_re_source_kind`, `homm3_re_rand_trn_source_row`,
  `homm3_re_type_id`, `homm3_re_type_name`, `homm3_re_subtype`,
  `homm3_re_terrain_name`, `homm3_re_primary_def_template_ref`,
  `homm3_re_def_template_refs`, `proxy_family_id`, `proxy_object_id`, and
  `homm3_re_art_asset_policy`.
- The decoration pass now advances source/proxy candidates after failed fits and
  uses an explicit compact-footprint fallback for constrained land pockets
  instead of repeatedly trying one impossible footprint.
- Added `tests/native_random_map_homm3_re_identity_comparison_report.tscn`.

## Evidence

Source catalog:
- `rand_trn` obstacle rows: 109.
- unique HoMM3-re type names: 33.
- unique DEF template references: 415.
- mapped DEF template reference total: 2,425.

Owner-attached H3M baseline:
- gzip size verified: 12,952 bytes.
- decompressed size verified: 61,868 bytes.
- parsed metrics used as owner-provided baseline: 72x72, islands, seed
  `1777897383`, Small Ring, 496 object instances, 272 impassable terrain/deco
  instances, 184 road tiles, 578 decoration-blocked tiles, 1,026 all
  blocked/occupied tiles.

Owner-like native comparison case:
- config: 72x72 islands, seed `1777897383`,
  `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1`.
- object instances: 345.
- road cells: 240.
- decoration-blocked coverage: 27.39% whole map.
- all blocked/occupied coverage: 32.16% whole map.
- HoMM3-re sourced decorations: 98 / 98.
- unique HoMM3-re source rows: 45.
- unique HoMM3-re type names: 19.
- unique HoMM3-re source terrains: 5.
- terrain alias match ratio: 100%.
- top HoMM3-re type names include Mine, Mountain, Crater, Outcropping, Rock,
  Lava Flow, Lava Lake, Stump, Dead Vegetation, and Volcano.

Broad sample gate:
- cases: 5 seeds/templates/sizes.
- unique HoMM3-re source rows represented: 93.
- unique HoMM3-re type names represented: 29.
- unique HoMM3-re source terrains represented: 7.
- unique original proxy families represented: 42.
- sizable surface land zones remain above the 7% per-zone decoration body
  floor in the five-case sample; underground/cave source rows are still counted
  in source-terrain diversity, but the visual empty-zone gate is scoped to
  surface land zones.

## Remaining Gaps

This does not claim full HoMM3-re RMG parity. Exact placement, byte format,
reward-table semantics, object value scoring, and exact HoMM3 art/DEF template
rendering remain unimplemented.
