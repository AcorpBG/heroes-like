# Overworld Raster Terrain And Visible Blocker Mass Report

Task: #10231

Slice: `ux-overworld-raster-terrain-and-visible-blocker-mass-10231`

Phase: Phase 6 - Production Alpha Layer
Status: completed 2026-09-04

## Root Cause

The sterile ground and invisible collision came from two renderer-owned presentation paths, not from missing or changed Native RMG topology. `OverworldMapView` drew five deterministic procedural line pairs independently on every non-water tile, producing the repeated scratch/streak grid. Separately, generated decorative packages retained every `package_block_tiles` collision cell but selected only one to three cells per placement for visible art; the remaining blocked cells returned as handled without drawing anything.

## Correction

- Removed the procedural per-tile ground-stroke pass from normal play.
- Added 17 original generated raster terrain materials covering the live terrain ids and aliases. Each 256x256 material is sampled continuously across an eight-by-eight map-space span so its motif does not restart on every tile.
- Increased sparse raster surface-detail cadence and scale while retaining deterministic tile/terrain-only selection and zero gameplay authority.
- Attached a deterministic, biome-matched original raster member to every unique authoritative generated blocker body cell. The 1.28-tile painted extent and bounded offsets overlap neighboring members into readable terrain masses while each visual remains owned by one existing 1x1 body cell.
- Added a 16-member original generated tree-cluster atlas for deciduous, evergreen, mire, autumn, frost, badland, and ash biomes. It augments the presentation palette only; it does not add placements or collision.
- Preserved the explicit local-reference terrain validation mode ahead of the new normal-play raster base, so existing self-contained transition validation remains exact.
- Retained the prior screenshot object identity `native_h3maped_90dbde7a_object_0011` / `AVLmtsw4.def` at `(1,9)`. Its three authoritative body cells now resolve to three loaded, original, mire-matched raster assets with no legacy procedural marker.

Generated source masters and prompt/provenance metadata are recorded in `art/overworld/source/generated/terrain/raster_base_v2/manifest.json`. Runtime art lives under `art/overworld/runtime/terrain_tiles/base_generated_v2/` and `art/overworld/runtime/objects/decorations/generated_blocker_tree_clusters_atlas.png`. No reference pixels, Heroes assets, DEF payloads, names, or protected compositions were imported.

## Evidence

The deterministic Medium `medium-random-screenshot-10230` case produced:

- 72x72 / 5,184 terrain cells, all using loaded raster bases;
- zero procedural microtexture tiles and zero procedural microtexture draw calls;
- 693 generated decorative records and 2,324 exact authoritative body cells;
- 2,324 visible raster members, zero uncovered body cells, and 100% raster coverage;
- 83 distinct resolved blocker assets, all loaded and biome-matched;
- identical deterministic composition, session payload, collision authority, and Native RMG output state.

Inspected captures:

- `.artifacts/overworld_raster_terrain_10231/medium_generated_1920x1080.png`
- `.artifacts/overworld_raster_terrain_10231/medium_generated_1280x720.png`

Both show continuous ground materials and visible forest, rock, ruin, fence, wetland, and volcanic masses without clipped controls. The package owns the high blocker density; this slice did not tune counts, topology, placement, terrain ids, roads, action tiles, or passability.

## Validation

- Focused Medium raster/body report: passed.
- Small generated-map movement, redraw, save/restore, pathing, and presentation report: passed with 464/464 visible body cells.
- #10222 exact placeholder identity report: passed with zero normal visible procedural fallbacks.
- Live object art coverage: passed across 9,752 placements with zero missing runtime textures and zero valid procedural fallbacks.
- Decorative and map-object distinct sprite reports: passed (200/200 decorative mappings and 422 distinct authored map objects).
- Ninefold terrain/transition regression: passed after retaining explicit local-reference precedence.
- `python3 tests/validate_repo.py`: passed.
- `git diff --check`: passed.
- Linux release export and boot: passed; PCK 246,949,848 bytes.
- Windows release export: passed with matching 246,949,848-byte PCK, valid PE/DLL/package contents, and source-art exclusion. The stock Wine wrapper repeatedly retained its process handle beyond its 180-second and extended 480-second bounds after emitting Godot, DLL, Boot, and Main Menu markers, with no fatal error. Direct execution of that same exported binary completed the packaged `boot_to_generated_skirmish_town` flow in 13,759 ms, including generated setup, Overworld entry, and player Town entry. Evidence: `.artifacts/packaging_windows_manual_generated_flow/live_validation_report.json`.

The known exit-only Godot texture RID warning still occurs after some rendered tests. It predates this slice, occurs after successful report publication, and is not presented as fixed here.

No Native RMG parity claim or release-readiness claim is made.
