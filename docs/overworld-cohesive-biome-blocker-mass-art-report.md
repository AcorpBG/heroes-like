# Overworld Cohesive Biome Blocker Mass Art Report

Task: #10232

Status: completed 2026-09-04

## Root cause

The #10231 renderer correctly attached raster art to every authoritative package blocker cell, but `_load_decorative_object_sprite_manifest()` first added all 200 authored blocker mappings to the generated-body candidate pool and then appended the small generated palette. Those authored assets are intentionally distinct landmarks; many include a self-contained local terrain bed. A placement-aware per-cell hash therefore produced a checkerboard of unrelated miniature scenes and exposed legacy DEF-record seams.

## Correction

- Added three original transparent 512x512 runtime atlases for temperate, wet/cold, and harsh land, sourced from built-in image generation and registered through 24 manifest assets. The palette covers all nine terrain-to-biome families, including subterranean underways.
- Generated body loading now clears the authored-derived candidates when the dedicated palette is present. Authored objects retain all 200 distinct identity mappings, while package body cells can resolve only through the cohesive palette.
- Art selection and bounded composition are stable in biome/world coordinates rather than legacy placement ids. Sprite extents overlap at 1.42 tiles with restrained 0.96-1.04 scale and small offsets, which hides cell and record boundaries without changing the body mask.
- The exact package placement ids, source counts, coordinates, body tiles, collision, interaction, pathing, deterministic session data, save version 9, and Native RMG output remain unchanged.

The final prompt set asked for original 4x4 transparent sprite atlases with a shared top-down camera, upper-left light, restrained biome palette, organic overlap-ready silhouettes, and no square ground plates, labels, frames, copied game art, or water/road tiles. Full source paths, prompt summaries, generator identity, processing, and asset policy are recorded in `art/overworld/source/generated/terrain/cohesive_blocker_mass_v3/manifest.json`.

## Evidence

- Dedicated palette: 9 biomes, 24 unique registered assets, 3 RGBA atlases, and zero intersection with authored landmark asset ids.
- Atlas checks: 512x512 each, 18.8%-35.9% fully transparent pixels, and zero opaque sprite-cell corners.
- Deterministic Medium `medium-random-screenshot-10230`: 693 source records, 2324 exact body cells, 2324 visible raster anchors, 0 uncovered cells, 18 exercised cohesive assets, and identical redraw composition signature `eba16b64756cae6a5cf4f2f40d7693999086e99c3acf50ab857d653c29110f1c`.
- Responsive captures were inspected at 1920x1080 and 1280x720. The old square-backed decorative mosaic is absent; temperate and harsh blockers overlap into continuous masses without clipping the map-first rail or routes.
- Small generated movement/save coverage retains exact 464/464 body-cell art before and after movement, identical composition signature, exact save reload, and a normal one-tile movement result.
- Authored decorative coverage remains 200/200 with 200 distinct assets. Live world coverage remains 9752 placements with 0 missing textures, 0 empty asset ids, and 0 normal-play procedural fallbacks.
- `python3 tests/validate_repo.py` and `git diff --check` pass.
- Linux export and boot pass. Linux and Windows PCKs both measure 248246124 bytes, 1753876 bytes below the unchanged ceiling, and contain no source masters.
- The direct packaged Windows validation completes generated setup, generated Overworld entry, and player Town entry in 15774 ms with no errors. The stock verbose Wine wrapper again retained a process handle past its timeout after proving Godot, DLL, boot scene, and Main Menu markers; it reported no fatal runtime match and is not treated as a game failure.

## Evidence paths

- `.artifacts/overworld_cohesive_biome_blocker_mass_10232/cohesion_report.json`
- `.artifacts/overworld_cohesive_biome_blocker_mass_10232/medium_generated_1920x1080.png`
- `.artifacts/overworld_cohesive_biome_blocker_mass_10232/medium_generated_1280x720.png`
- `.artifacts/packaging_linux_export_smoke/report.json`
- `.artifacts/packaging_windows_export_smoke/report.json`
- `.artifacts/packaging_windows_manual_cohesive_10232/live_validation_report.json`

## Separate observations

The known exit-only texture RID warning remains unchanged. The optional legacy `native_random_map_package_session_authoritative_replay_report` still expects the older fail-closed/non-authoritative Native RMG status while the current service reports runtime authority; that pre-existing contract mismatch is outside this presentation-only slice and was not papered over.
