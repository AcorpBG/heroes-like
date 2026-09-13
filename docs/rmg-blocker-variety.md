# RMG blocker variety

Status: completed. Owner requested additional map blockers used by the RMG.

The native package bridge marks generated decorative obstacles as blocker sprites. OverworldMapView renders their exact body cells using generated_body_palette in art/overworld/decorative_object_sprites.json. This is the live original-game art adoption boundary; changing the legacy generator catalog would not supply the requested live variety.

Create twelve original transparent biome masses: thornroot thicket, tangled marsh roots, shattered slate, snowbound deadfall, basalt chimneys, cavern crystal crag, giant shelf fungi, redstone hoodoos, blue ice crag, saltworn driftwood, wild rose barrier and ancient oak grove. Add each to suitable biome palettes, retain existing art, preserve native generator semantics and exact blocking cells. Dedicated generated-body art remains separate from authored landmark identity mappings.

Keep source PNGs and full generation prompts/provenance. The wiki must explain that these are non-interactive RMG blocker appearances, not collectible resources or new adventure sites. Validation is focused on new assets, palette selection, exact body coverage, unchanged session/collision authority, and rendered generated-map evidence. No full manual match or unattended visible game process is required.

## Delivery

Twelve original transparent PNGs expand the dedicated live pool from 24 to 36 appearances. Every biome receives additions. All are registered in the runtime overworld manifest and generated-body palettes; no native generation, placement, collision, save schema or route algorithm changed. The renderer selects appearances deterministically from terrain and world coordinates.

Original 1254px source masters and full prompts are retained under `art/overworld/source/generated/terrain/blocker_variety_20260913/`. Runtime PNGs are under `art/overworld/runtime/objects/decorations/blocker_variety_20260913/`; Godot imports use a 256px size limit, mipmaps and alpha-border correction. Windows and Linux consume the same portable PNGs/manifests and import settings. Both export presets include runtime art and exclude source masters; no package builds were performed for this slice.

The wiki contains twelve explicit RMG-scenery entries with biome, availability and collision-authority explanations. The catalog builder now replaces its output atomically so an open local-file wiki cannot leave a partially rewritten catalog.

The first six additions passed one focused off-screen Windows generated-Medium check: 2,324/2,324 blocked body cells covered, unchanged collision and session authority, deterministic selection of all six across isolated terrain fixtures, and 355 actual placements of three new appearances in the generated map. Both responsive captures and the volcanic-region capture were produced; the latter was inspected. No runtime errors occurred. The engine process exited automatically.

The owner then requested less testing and more assets. Six more sprites were produced through the same palette path. All twelve source images were visually reviewed; the expanded batch received normal Godot import (successful, no import errors) and a wiki rebuild, without another gameplay run or broader test suite. This is not a claim that every new appearance was observed in a played match.

Evidence: `.artifacts/rmg-blocker-variety-20260913/variety-report.json`, `runtime.log`, `final-import.log`, and the three PNG captures. The test driver and disposable settings profile were removed (3,389 bytes for the final import profile, regenerable). Generated-map evidence and original art/provenance were retained. No task-owned Godot process remains running.
