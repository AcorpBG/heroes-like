# Overworld Placeholder Art Resolution (#10222)

## Scope and authority

The owner screenshot at `/root/.openclaw/workspace/media/inbound/openclaw-staged-6e5ca23c-0d30-4de1-93e1-677596e141d3/input-image---5348e6c6-df27-4400-b89e-d367e9153c62.png` shows the renderer's green, black-outlined ruin silhouette among painted generated-map blockers. This correction is limited to that visual-resolution path. It does not change RMG topology, placement, collision, interaction, economy, save data, or authored art families.

## Root cause

Native/generated decorative placements enter the session as `kind=decorative_obstacle`, `runtime_object_role=decorative_blocker_sprite` records. Their retained legacy DEF `x/y` coordinate is an anchor for the source placement; `package_block_tiles` is the authoritative footprint used for pathing and for the generated raster-body presentation.

`OverworldMapView._rebuild_static_object_indexes()` previously indexed each record twice:

1. the raw legacy `x/y` record entered `_decorative_objects_by_tile`; and
2. `_index_generated_decorative_body_cells()` created the terrain-matched raster presentation across `package_block_tiles`.

When the legacy anchor was outside its package body cells, its empty authored `object_id` could not resolve through `decorative_object_sprites.json`. The raw duplicate therefore reached `_draw_decorative_object_marker()` and `_draw_ruin_silhouette()`. The default blocker marker color produces the exact green fill and black frame visible in the owner screenshot. The legitimate generated raster body remained present elsewhere in the same placement mass.

This was not one of the authored map-object mappings audited by the earlier distinct-sprite pass. That pass covered 386 authored definitions at the time; the current manifests cover all 422 authored definitions (200 decorative and 222 non-decorative). Generated package records with empty authored object ids are a separate runtime category. The old live coverage report also skipped `decorative_blocker_sprite` records and accepted any loaded sprite on a tile, so a valid neighboring or co-located layer could mask the orphan raw-anchor fallback.

## Correction

Generated decorative records with non-empty `package_block_tiles` now take one exclusive render-resolution path: the legacy source record remains untouched in session/save authority, but only its package body cells enter the visual index. Normal authored decorative placements retain their existing direct manifest lookup.

No new stand-in was generated. The appropriate original generated raster already existed in the authoritative biome pipeline, so reusing it is both semantically correct and smaller than adding duplicate art. In the pinned `live-render-move-10184` case, the concrete reproduced record is:

- placement: `native_h3maped_90dbde7a_object_0011`
- retained source identity: `AVLmtsw4.def`
- legacy anchor: `(1, 9)`
- resolved raster asset: `decor_mire_drum_island_reed_wall`
- runtime path: `res://art/overworld/runtime/objects/decorations/distinct/decor_mire_drum_island_reed_wall.png`
- provenance: `built_in_image_gen_chroma_key_split`, policy `original_generated_runtime_sprite_no_homm3_art_import`

The focused report finds 65 raw-anchor candidates in the deterministic 175-record package, indexes zero of them as separate visible markers, retains all 223 terrain-matched raster anchors, and observes zero procedural fallbacks across 334 normal visible object layers. Session authority is byte-for-byte unchanged by presentation resolution, and the placement/debug overlay is disabled.

## Evidence and validation

Visual evidence:

- Before: `.artifacts/overworld_live_object_art_coverage/generated/generated_before_move.png` contains five orphan green ruin markers in the representative viewport.
- Corrected: `.artifacts/overworld_placeholder_art_resolution/captures/generated_before_move.png` at 1600x900 and `.artifacts/overworld_placeholder_art_resolution/captures_1280x720/generated_before_move.png` use the same seed with the orphan markers absent and the painted blocker bodies retained. Both captures were inspected at original resolution; controls, painted props, towns, roads, and terrain remain intact without clipping.

Focused and regression commands:

```text
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/overworld_placeholder_art_resolution_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/overworld_decorative_sprite_asset_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/overworld_map_object_sprite_asset_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 --scene res://tests/overworld_live_object_art_coverage_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 RANDOM_MAP_LIVE_VISUAL_REVEAL_ALL=1 RANDOM_MAP_LIVE_VISUAL_CAPTURE_ONLY=1 RANDOM_MAP_LIVE_VISUAL_CAPTURE_DIR=res://.artifacts/overworld_placeholder_art_resolution/captures xvfb-run -a -s '-screen 0 1600x900x24' godot --path . --quit-after 240 --scene res://tests/random_map_live_overworld_render_move_report.tscn
python3 tests/validate_repo.py
git diff --check
python3 tests/packaging_linux_export_smoke.py
python3 tests/packaging_windows_export_smoke.py
```

The full non-capture `random_map_live_overworld_render_move_report` was also attempted. Its new generated-body and placeholder assertions passed before an unrelated natural-fog terrain-detail assertion stopped the run (`terrain_detail_invalid_count=1`); the focused production-seed report and visual-capture route cover the #10222 behavior directly.

The focused placeholder report, both authored distinct-sprite reports, exhaustive live-art coverage (9,465 placements), repository validator, and both package smokes passed. Linux and Windows PCKs match at 244,965,688 bytes, 5,034,312 bytes below the unchanged 250 MB ceiling. Linux packaged boot passed; the Windows/Wine gate additionally passed boot, generated setup, generated Overworld entry, and generated Town entry.

This report does not claim Native RMG parity, release readiness, native Windows certification, signing, or publication.
