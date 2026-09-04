# Overworld Town Vision And Command Roster Report

Task: #10234

Status: completed

## Result

Player-owned towns now join the existing authoritative fog-source refresh and reveal an exact Manhattan-radius-five area from their entry coordinate. Enemy and neutral towns contribute no player vision. Capture adds the new source immediately; loss of ownership stops later source refresh without erasing permanent exploration. The save schema remains version 9.

The Overworld right rail now presents a persistent paired Heroes/Towns roster below the minimap. Every player hero and owned town receives one compact original-art icon control. Hero portraits come from the existing hero-art records and town thumbnails from the existing scenic-backdrop records. Active/selected states, tooltips, accessibility descriptions, full keyboard/controller focus, and bounded vertical scrolling are present. Reserve heroes reuse `OverworldRules.switch_active_hero`; the active hero and towns reuse the existing camera/selection paths.

Responsive layout keeps four roster rows visible at 1920x1080. At 1280x720 the minimap and roster contract while the less-important event strip collapses, leaving all roster entries scroll-reachable and keeping the map, rail, and footer inside the viewport.

## Focused evidence

`python3 tests/overworld_town_vision_command_roster_report.py` passed its Godot runtime fixture with:

- 61 exact explored tiles from one radius-five player town;
- zero enemy/neutral town contribution;
- 122 exact tiles after transferring the source to a non-overlapping captured town, with the former source retained as permanent exploration;
- exact save/reload restoration at save version 9;
- four unique hero controls and five unique owned-town controls in the stress fixture;
- all roster art loaded and all controls focusable, accessible, and tooltip-backed;
- exact hero switch to `hero_caelen` at 19,26 and exact town selection at 11,8;
- 85.52% map width at 1920x1080 and 78.28% at 1280x720, with no map/rail/footer overlap or clipping.

The final visually inspected captures are:

- `.artifacts/overworld_town_vision_command_roster_10234/town_vision_roster_1920x1080.png`
- `.artifacts/overworld_town_vision_command_roster_10234/town_vision_roster_1280x720.png`

## Regression and package evidence

- `fog_of_war_homm_style_regression.tscn`: passed.
- `terrain_blocking_town_capture_interaction_regression.tscn`: passed.
- `overworld_map_first_command_rail_report.py`: passed two viewports, two captures, and exact session authority.
- `random_map_live_overworld_render_move_report.tscn`: passed generated-map render, fog, move, and save/reload authority.
- `python3 tests/validate_repo.py`: passed, including the #10234 static ownership checks.
- `git diff --check` and Godot editor import/parse check: passed.
- Linux release export/package boot: passed; PCK 248217276 bytes.
- Windows release export and baseline startup reached Godot, native DLL, Boot, and Main Menu without fatal matches. The wrapper's baseline Wine process timed out after those markers and therefore skipped its generated subflow; the same exported Windows build then passed the direct packaged `boot_to_generated_skirmish_town` flow with the exact setup, Overworld-entry, and player-town-entry steps.
- Linux and Windows PCK sizes match and remain 1782724 bytes below the unchanged 250000000-byte ceiling.

`overworld_visual_smoke.tscn` was also exercised after its hero-roster expectations were updated. It progressed beyond the roster checks and later reported the independent active-hero command-marker `ground_y` geometry assertion. #10234 does not change that map-marker renderer or geometry contract, so that broader assertion is recorded but is not used as evidence for this slice.

## Preserved boundaries

Native RMG output, map topology, town placement and ownership rules, hero/town records, pathing, interaction, AI, economy, construction, recruitment, input bindings, and save version are unchanged. No copied Heroes art, names, or pixels were introduced.
