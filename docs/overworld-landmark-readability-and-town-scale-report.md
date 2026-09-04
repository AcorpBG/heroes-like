# Overworld Landmark Readability And Town Scale Report

Task: #10229
Slice: `ux-overworld-landmark-readability-and-town-scale-10229`
Requirement source: `docs/overworld-landmark-readability-and-town-scale-requirements.md`

## Comparison and root cause

The supplied Heroes III reference and the official Heroes III HD adventure-map screenshot on Steam were used only as composition references. They show a stable visual hierarchy: towns dominate several tiles, heroes and encounters read as actors, pickups remain recognizable, and decorative terrain masses stay subordinate.

The Aurelion Reach raster sources were not the primary defect. The live renderer reduced artifacts to 0.30 tiles, pickups to 0.36, encounters to 0.46, ordinary structures to roughly 0.54, heroes to 0.64, and town art to a nominal 2.85-tile square. Because the town sources include both nearly square faction masters and wider identity paintings, aspect-preserving fit made several authored towns only 2.4 to 3.4 tiles tall. Fully opaque decoration and weak gameplay-object edges then made most props compete at nearly the same visual weight.

## Correction

- Town painting now occupies one explicit 2.90-by-3.72-tile box within the existing 3-by-4 visual envelope. It remains bottom-grounded with 0.18-tile clearance while its authoritative footprint stays exactly 3-by-2 with the bottom-middle visit entry.
- All six faction town assets, the wide Riverwatch identity fixture, and all 26 authored town identities use the same landmark box through the existing manifest-backed raster path.
- Original object assets now use semantic scale bands: decoration 0.46, artifact 0.58, ordinary object 0.62, pickup 0.68, waypoint 0.78, durable service 0.82, hero 0.86, encounter 0.88, blocker 0.92, landmark 0.94, and bounded multi-tile structures up to 1.35 tiles.
- Interactive raster objects receive the existing eight-direction dark alpha silhouette; ground decoration is excluded and rendered at 0.82 alpha. No label, plate, badge, glow, procedural stand-in, content mapping, placement, or gameplay rule was added.
- Hero art was re-grounded by reducing visual lift from 0.30 to 0.25 of its tile so the larger sprite and its silhouette remain inside the tile.

## Evidence

- Focused report: `python3 tests/overworld_landmark_readability_runtime_report.py` passes semantic ordering, silhouette ownership, decoration subordination, seven representative town assets, town click routing, and unchanged session authority.
- All authored towns: `overworld_faction_town_sprite_runtime_report.tscn` passes 26 identities at 1280x720 and 1920x1080, including save/resume, fallback, owner pennant, grounding, footprint, and silhouette containment.
- Deterministic generated Large map: `overworld_generated_large_town_scale_runtime_report.tscn` passes six towns, exact blocked-tile and interaction indexes, click routing, and unchanged session authority at both resolutions.
- Authored responsive coverage: `overworld_small_map_visual_scale_runtime_report.tscn` passes the authored small and large scenarios at both resolutions with unchanged logical footprints and gameplay authority.
- Inspected captures:
  - `.artifacts/overworld_landmark_readability_10229/after/generated_large_1920x1080.png`
  - `.artifacts/overworld_landmark_readability_10229/after/generated_large_1280x720.png`
  - `.artifacts/overworld_landmark_readability_10229/after/authored/authored_small_1920x1080.png`
  - `.artifacts/overworld_landmark_readability_10229/after/authored/authored_small_1280x720.png`
  - `.artifacts/overworld_landmark_readability_10229/after/authored/authored_large_1920x1080.png`
- Repository validation passes. Gameplay movement-input ownership passes for keyboard, controller, pointer route, and modal-release cases.
- Linux and Windows release exports both boot successfully with matching 245089360-byte PCKs. Windows Wine also passes generated setup, Overworld entry, and player-Town entry; source masters remain excluded.

Two broad legacy tests retain independent stale expectations and are not caused by this slice: the object-occupancy report expects a ten-tile sawmill body while current authored authority is six, and the full-route report expects a retired route-step VFX payload. The focused movement-input, town interaction, generated-map authority, repository, and packaged generated-flow gates are green.

No Heroes III pixel, name, map, or asset was copied.
