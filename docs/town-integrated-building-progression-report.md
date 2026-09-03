# Integrated Town Building Progression Report

Task: #10226
Slice: `ux-town-integrated-building-progression-10226`
Requirement: `docs/town-integrated-building-progression-requirements.md`

## Root cause

`TownStageView.gd` previously selected one of three whole-scene faction panoramas from a coarse built-building ratio. That made construction change an approximate backdrop stage rather than add the exact completed structure. An older individual-building implementation had also generated a generic plot grid at runtime, which made buildings read as detached icons instead of parts of the painted settlement.

## Correction

- `content/town_building_scene_layouts.json` now owns explicit normalized faction scene plots, ground anchors, perspective scale, shared upgrade sites, base-embedded structures, and faction lighting modulation. `tools/generate_town_building_scene_layouts.py` deterministically rebuilds that checked-in manifest from the authored Town/building catalogs.
- The faction village painting remains the stable base. `TownStageView.gd` resolves only authoritative `built_buildings`, replaces predecessors on shared upgrade plots, depth-sorts exact original 256x256 building raster art, and projects both art and hit targets through the same cover-crop transform. There is no runtime-generated plot, stake, or missing-art fallback.
- Every visible non-base building owns an aligned hover/focus target with tooltip and accessibility copy. Activation opens the existing Town catalog modal in read-only building-information mode, showing authored name, description, category, cost, prerequisites, predecessor, image, and gameplay effects.
- The Town Hall remains painted into the village base and keeps the existing main-building hotspot that opens the authoritative construction ledger.
- Construction rules, resource mutation, progression, save version 9, AI, balance, and package boundaries are unchanged.

## Evidence

- Focused report: `TOWN_INTEGRATED_BUILDING_PROGRESSION_REPORT` passed for all 32 authored towns and all six factions. It verified 179 faction catalog mappings, loadable exact textures, contained source/destination rectangles, aligned hotspots, a real Riverwatch construction, exact resource cost, save/load restoration, and building-information routing.
- Responsive captures were visually inspected at 1280x720 and 2048x1079 for sparse, developing, and developed Riverwatch states. Buildings remain grouped on painted roads, docks, plazas, and foreground terraces; the compact HUD, command dock, and footer remain contained.
- `TOWN_SCREEN_LAYOUT_AND_DIALOG_CONTROLS_REPORT` passed.
- `COMPLETE_TOWN_BACKDROP_RUNTIME_REPORT` passed 52 Town/resolution cases and six faction fallback cases.
- `TOWN_DEVELOPMENT_FIRST_IMPORT_PROBE` passed all 18 faction/stage raster loads.
- `python3 tests/validate_repo.py` passed, and `git diff --check` passed.
- Linux and Windows release export/startup smokes passed with identical 245073436-byte PCKs, 4926564 bytes below the 250000000-byte ceiling. Windows additionally passed the generated setup, overworld entry, and Town entry flow under Wine.

Two existing broad checks remain independently red outside this slice's code paths: `town_battle_visual_smoke` stops on its Battle System command-panel roundtrip assertion, and `town_development_runtime_balance_report` reports that `town_moonbite_reedshrine` misses the 30-turn economy target. Neither failure is caused by Town scene layout, building art resolution, click routing, construction authority, or save restoration, and neither is claimed fixed here.
