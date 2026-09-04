# Overworld Town Proportion And Environs Report

Task: #10236  
Slice: `ux-overworld-town-proportion-and-environs-10236`  
Date: 2026-09-04

## Result

The distorted Ninefold starting-town presentation is corrected in live rendering. Town sprites now keep their painted alpha-bounds aspect ratio while fitting uniformly inside the existing 2.90-tile-wide by 3.72-tile-tall visual envelope. The logical 3x2 footprint, bottom-middle visit tile, click routing, blocking, ownership, and save version remain unchanged.

Riverwatch now resolves through the existing canonical manifest id to a new original generated transparent land-set raster. The high-resolution source is retained at `art/overworld/source/generated/towns/identity/town_riverwatch_source.png`; the 512x512 runtime derivative is at `art/overworld/runtime/objects/towns/identity/town_riverwatch.png`. The workflow used a built-in image-generation precise edit followed by transparent-background extraction, then the repository's runtime resize/import path. No Heroes art, copied pixels, SVG, or procedural stand-in was used.

Three explicit grassland blocker placements now form a loose settlement edge within the starting town's radius-five reveal: two low-fence clusters and one orchard-root cluster. Their 13 body tiles are authoritative blockers, none overlap the east/south roads, and all three anchors resolve to existing original raster assets. The authoring tool replaces only its own batch and reproduces byte-identical scenario content on rerun. Native/generated-map output was not changed.

## Root cause

`OverworldMapView._town_sprite_draw_payload()` previously forced every painted town region into both a fixed 2.90-tile width and fixed 3.72-tile height. That non-uniform transform visibly stretched or compressed source art. The surrounding Ninefold density pass also placed its nearest substantial biome blockers outside the town's initial radius-five reveal, so the normal first view read as an isolated town on open terrain even though more scenery existed farther away.

## Evidence

- Focused runtime report: `.artifacts/overworld_town_proportion_environs_10236/report.json`
- Inspected normal-play capture: `.artifacts/overworld_town_proportion_environs_10236/ninefold_town_environs_1920x1080.png`
- Inspected smaller capture: `.artifacts/overworld_town_proportion_environs_10236/ninefold_town_environs_1280x720.png`
- The report proves 12 live Ninefold town profiles preserve source/draw aspect, Riverwatch resolves exactly, three town-environs placements are visible raster art, all 13 body tiles are blocked and road-clear, session authority is unchanged, and Native RMG output is unchanged.
- Visual inspection confirmed the town no longer has the forced tall distortion, the road remains visually and logically open, nearby fences/root mass are visible inside fog, and neither 1920x1080 nor 1280x720 clips the map, command rail, minimap, or footer.

## Validation

- `python3 tests/overworld_town_proportion_environs_report.py`: PASS
- `godot4 --headless --path . --scene res://tests/overworld_faction_town_sprite_runtime_report.tscn`: PASS, 26 authored towns across both target viewports
- `python3 tests/overworld_landmark_readability_runtime_report.py`: PASS
- `godot4 --headless --path . --scene res://tests/overworld_generated_large_town_scale_runtime_report.tscn`: PASS, generated 108x108 map at both target viewports
- `godot4 --headless --path . --scene res://tests/overworld_strategic_density_runtime_report.tscn`: PASS, Ninefold 29 authored blockers / 164 blocked body tiles
- `python3 tests/overworld_town_vision_command_roster_report.py`: PASS, radius five and both captures
- `python3 tests/validate_repo.py`: PASS
- `git diff --check`: PASS
- `python3 tests/packaging_linux_export_smoke.py`: PASS
- `python3 tests/packaging_windows_export_smoke.py`: PASS after making the Wine gate initialize fresh prefixes and capture runtime logs to files so descendant Wine services cannot retain the Python output pipe
- Linux and Windows PCKs match at 248,360,044 bytes, 1,639,956 bytes below the unchanged 250,000,000-byte ceiling. Windows startup and generated setup -> Overworld -> owned Town markers all passed.

The broad `overworld_visual_smoke.tscn` continues to stop on its pre-existing ordinary field-hero command-marker geometry assertion; the failure is outside this slice and occurs after the migrated town presentation assertions. Focused town proportion, click, generated-map, fog/vision, density/pathing, and package owners all pass.

## Non-claims

This does not change Native RMG behavior, map topology, gameplay balance, town rules, movement rules, save schema, package limit, signing, publication, whole-game certification, or release readiness.
