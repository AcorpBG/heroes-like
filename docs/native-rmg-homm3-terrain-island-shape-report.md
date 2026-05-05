# Native RMG HoMM3 Terrain And Island Shape Report

Slice: `native-rmg-homm3-terrain-island-shape-10184`  
Date: 2026-05-05

## Scope

This slice replaces the old native islands path that globally scored every tile
against protected land and zone anchors. The new path is still original-content
generation: it uses recovered behavior only as structural reference, does not
import HoMM3 names/assets/text, and does not start the roads, rivers, object,
guard, reward, town, or mine rewrites.

## Implemented

- Native islands terrain now derives land/water from the runtime zone owner grid
  and per-zone terrain/role semantics.
- Runtime zone land targets preserve allowed-terrain and faction-matched terrain
  already selected by the Phase 3 data-model/runtime-graph slices.
- Generated roads, towns, guards, rewards, decorations, body, visit, and
  approach surfaces are treated as required land for compatibility with the
  current pre-terrain object pipeline.
- Infeasible zone land budgets are reported in `terrain_grid.land_water_shape`
  diagnostics instead of silently pretending the requested quota was met.
- The old global island candidate-scoring/sort path is disabled and replaced by
  bounded zone flood fill.
- Medium maps include generated-cell terrain id/art/flip arrays. Larger maps
  keep compact generated-cell metadata to avoid large signature/serialization
  cost until the later tile-writeout adoption slice.

## Evidence

Focused report:

```sh
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_homm3_terrain_island_shape_report.tscn
```

Observed report metrics:

| Case | Template | Size | Elapsed | Water tiles | Land tiles | Surface water conflicts |
|---|---|---:|---:|---:|---:|---:|
| medium | `translated_rmg_template_001_v1` | 72x72 | 6.148s | 2,251 | 2,933 | 0 |
| XL | `translated_rmg_template_012_v1` | 144x144 | 8.754s | 12,781 | 7,955 | 0 |

Both cases reported:

- `source_model = runtime_zone_graph_owner_grid_zone_land_quotas`
- `candidate_scoring_policy = disabled_old_global_candidate_sort_removed`
- `performance_model = bounded_by_surface_tiles_and_runtime_zone_cells`

The XL fixture intentionally focuses terrain/island semantics and performance.
It does not claim later road/river/object parity.

## Remaining Gaps

- Exact TerrainPlacement queue propagation remains deferred.
- Exact terrain transition art/frame parity remains deferred.
- Roads, rivers, connection guards, object placement, towns/mines/resources,
  and guard/reward rewrites remain separate Phase 3 child slices.
