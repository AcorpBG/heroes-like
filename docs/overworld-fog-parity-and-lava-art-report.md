# Overworld Fog Parity And Lava Art Report

Task: #10233

Slice: `bugfix-overworld-fog-parity-and-lava-art-10233`

Validated: 2026-09-04

## Result

Normal generated play visibly preserves permanent-exploration fog on both the main map and minimap. The harsh-biome blocker atlas is now original transparent raster art built from natural basalt shelves, ash boulders, cooled rope lava, slate ridges, and sparse ember seams rather than the previous bright fissure and purple ruin motifs.

## Root cause

The game runtime was not dropping exploration fog. The prior screenshot fixture `tests/overworld_raster_terrain_blocker_mass_report.gd` deliberately called reveal-all before every capture so it could inspect blocker art. Those images were then unsuitable as normal-play evidence. The minimap already queried `OverworldRules.is_tile_explored`, but the suite did not compare every minimap tile with the main-map shroud and authoritative fog state.

The lava complaint was a content-quality issue in the sixteen-cell `harsh_atlas.png`: highly luminous repeated cracks and purple architectural shapes read as tokens placed over the terrain. It was not a terrain, topology, collision, or RMG defect.

## Implementation

- The normal Medium screenshot path no longer mutates fog and now focuses on the active hero. Reveal-all is retained only in a separately named lava art-review capture, and the original fog/session dictionary is restored and compared afterward.
- `OverworldMinimap` exposes validation-only fog counts and per-tile presentation data. The focused report compares all 1,296 Small-map coordinates across `OverworldRules`, `OverworldMapView`, and `OverworldMinimap` before and after a legal move.
- The harsh source was generated with the built-in original-art workflow as a real RGBA image, then resized into the existing 4x4 runtime atlas contract. The provenance manifest records the successful source generation path, prompt summary, and #10233 revision reason.
- Harsh palette assignments keep glowing cells out of highland and subterranean use while retaining varied natural basalt/ash and restrained lava motifs for the actual ash/lava biome.
- No fog rule, visibility radius, map topology, placements, body masks, collision, pathing, interaction, save version, or Native RMG output changed.

## Evidence

- Focused fog parity: 25 explored and 1,271 hidden tiles before movement; 32 explored and 1,264 hidden afterward. Main-map, minimap, and cross-surface mismatch counts are all zero. Every hidden minimap tile uses the unexplored color.
- Harsh atlas: 512x512 RGBA, transparent canvas/cell corners, manifest-backed source, all exercised body sprites loaded and terrain matched, and zero uncovered body tiles.
- Deterministic Medium case: 2,324 expected body cells, 2,324 visual anchors, 18 distinct body assets, exact collision/session authority, and an explicitly isolated ash/lava review centered at tile 22,32.
- Live authored/generated object-art sweep: 9,752 live world placements, 777 distinct resolved assets, zero missing runtime textures, zero empty sprite assets, and zero valid procedural fallbacks.
- Inspected captures:
  - `.artifacts/overworld_fog_parity_lava_art_10233/normal_fog_1920x1080.png`
  - `.artifacts/overworld_fog_parity_lava_art_10233/normal_fog_1280x720.png`
  - `.artifacts/overworld_fog_parity_lava_art_10233/medium_lava_art_review_reveal_all_1920x1080.png` (explicit art review, not fog evidence)

## Validation

- `xvfb-run -a godot4 --path . --scene res://tests/overworld_fog_parity_lava_art_report.tscn`: pass.
- `godot4 --headless --path . --scene res://tests/fog_of_war_homm_style_regression.tscn`: pass.
- `godot4 --headless --path . --scene res://tests/random_map_live_overworld_render_move_report.tscn`: pass, including movement and save/reload fog restoration.
- `python3 tests/overworld_cohesive_biome_blocker_mass_report.py`: pass.
- `godot4 --headless --path . --scene res://tests/overworld_live_object_art_coverage_report.tscn`: pass.
- `python3 tests/validate_repo.py`: pass.
- Linux release export/package/startup: pass at 248,211,212 bytes, with source masters excluded.
- Windows release export/package: pass at the identical 248,211,212 bytes; PE/DLL/runtime assets/imports and Boot/Main Menu/native-DLL markers pass with no fatal runtime match. The stock verbose Wine runner times out while collecting loader output, as in #10232. A fresh-prefix direct packaged flow passes in 17,843 ms through `generated_map_setup`, `generated_overworld_entered`, and `generated_player_town_entered` with no errors.
- `git diff --check`: pass.

The familiar Godot renderer RID/texture messages occur only during process shutdown after the successful focused rendered report; they are the separately known engine-exit warning and not a gameplay or asset-load failure.

The inspected 1920x1080 normal-fog image, 1920x1080 Medium lava review, and 1280x720 normal-fog image were delivered to the owner through Proca on Discord as messages `1545458053250293852`, `1545458085756407898`, and `1545458113274978345`.
