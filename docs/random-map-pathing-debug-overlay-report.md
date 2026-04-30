# Random Map Pathing Debug Overlay Report

Date: 2026-04-30

## Scope

Implemented a normal live-overworld debug overlay for route/path command instrumentation only. This slice does not change map generation, object placement, pathing rules, renderer semantics, save schema, or gameplay balance.

## Toggle

- Key: `F3`
- Validation hook: `OverworldShell.validation_set_debug_overlay_enabled(true)`
- Live availability: the overlay is created by `OverworldShell.gd` in normal scene runs and is hidden by default.

## Metrics Exposed

- command type, raw target tile, selected route tile, hero before/after
- total command time in milliseconds
- shell route/BFS time, call count, status, path tile count, visited count, enqueue count, blocked-tile lookup count
- map-view route recompute time and path details
- blocked-tile index rebuild delta, rebuild time when a rebuild occurs, and current blocked-index tile count
- shell refresh time, shell `refresh_set_map_state` time, and map-view `set_map_state` time
- object index time plus static object index rebuild/skip counts and hero index rebuild/skip counts
- road index time plus rebuild/skip counts
- static/state/dynamic draw times when a frame has presented after the command, dynamic layer reason/generation, and draw/check counts
- save/autosave profile when a save starts during the command; otherwise `none observed`
- current FPS and derived frame time

## Validation

Added `tests/random_map_pathing_debug_overlay_report.tscn`, which launches a generated Small 36x36 skirmish, enables the overlay, selects a reachable route target, verifies non-empty timing fields, performs the primary route movement, and confirms the hero still moves while the scenario remains in the live overworld. Medium-or-larger generated validation was not practical for this smoke report because the generated Small launch already takes roughly 90 seconds in this checkout; the overlay itself is normal live `OverworldShell` UI and is not size-gated.

## TODOs

- Dynamic-layer invalidation itself does not currently expose a separate invalidation-duration timer; the overlay reports measured dynamic draw time plus the dynamic layer reason/generation.
- Save work is reported only when `SaveService` starts a runtime save during the command. Normal route selection/movement currently reports `none observed`.
