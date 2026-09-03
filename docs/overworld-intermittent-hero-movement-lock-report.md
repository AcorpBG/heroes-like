# Intermittent Overworld Hero Movement Lock Report

Task: #10227
Slice: `bugfix-overworld-intermittent-hero-movement-lock-10227`
Completed: 2026-09-03

## Root cause

`OverworldShell._overworld_gameplay_movement_blocked_reason()` returned `debug_active` whenever the persistent F3 path-profile overlay or F4 placement overlay was visible. Both overlays are passive `MOUSE_FILTER_IGNORE` drawing surfaces, and the established path-profile contract says the game must remain movable while the overlay observes normal commands. Their setters also cancelled live controller movement and route-cursor state as though a modal owner had opened. Leaving either overlay enabled therefore made a hero with valid movement points appear frozen to keyboard/controller input.

This was an input-ownership mismatch, not exhausted movement, path topology, object footprints, a generated-map start trap, or an unresolved encounter. Authoritative movement and route rules did not require changes.

## Correction

- Only the short synchronous `_debug_command_in_progress` interval returns `debug_active`.
- F3/F4 visibility is reported separately as `diagnostic_overlays_visible` and no longer cancels live movement/route state.
- Real command drawers, settings, save popup/confirmation, End Turn confirmation/commit, and transient command capture remain exclusive input owners.
- Movement points, path computation, blocked tiles/corners, interactions, battle/Town routing, generated payload identity, and save version 9 are unchanged.

## Evidence

- `OVERWORLD_GAMEPLAY_MOVEMENT_INPUT_OWNERSHIP_REGRESSION`: passed. F3, F4, and both together each permit one keyboard step, one controller step, and one two-step pointer route, spending exactly four movement points; all eight real owners remain mutation-safe and ghost-repeat-free.
- `RANDOM_MAP_PATHING_DEBUG_OVERLAY_REPORT`: passed on the deterministic generated 36x36 Small case with F3 visible; the hero moved one step and retained live Overworld state.
- `OVERWORLD_CACHED_ROUTE_EXECUTION_REGRESSION`, `OVERWORLD_CONTROLLER_ROUTE_SELECTION_REGRESSION`, and `OVERWORLD_ROUTE_DESTINATION_ONLY_ACTION_REGRESSION`: passed.
- `python3 tests/validate_repo.py`, Godot editor parse/load, and `git diff --check`: passed.
- Linux and Windows release export/startup passed with identical 245073628-byte PCKs, 4926372 bytes below the 250000000-byte ceiling. Windows generated setup, Overworld entry, and Town entry also passed under Wine.

`OVERWORLD_FULL_ROUTE_MOVEMENT_REGRESSION` remains independently red in this environment because the persisted `reduce_flashes=true` preference selects the valid `route_endpoint_snap` fallback while that older presentation assertion hard-codes `vfx_placeholder_route_step`. The movement itself reaches the exact endpoint; this environment-sensitive VFX expectation is outside the input-lock correction and is not claimed fixed.
