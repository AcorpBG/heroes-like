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
- command lifecycle phase buckets for input/validation entry, tile/object selection resolution, body-tile to visit-tile resolution, route decision construction, route text generation, primary-action computation/activation, context-action dispatch, movement rules, and route-advance lookup
- shell route/BFS time, call count, status, path tile count, visited count, enqueue count, blocked-tile lookup count
- map-view route recompute time and path details
- blocked-tile index rebuild delta, rebuild time when a rebuild occurs, and current blocked-index tile count
- shell refresh time, refresh call count, shell `refresh_set_map_state` time, and map-view `set_map_state` time
- internal refresh section timings for normalized read/map-state setup, action rebuilds, generated compact surfaces, header/objective/status/resource surfaces, command commitment and hero/army/heroes/specialty/spell/artifact rails, frontier drawer, context tile text, event/action context, end-turn surface, and tooltip/context drawer sync
- object index time plus static object index rebuild/skip counts and hero index rebuild/skip counts
- road index time plus rebuild/skip counts
- static/state/dynamic draw times when a frame has presented after the command, dynamic layer reason/generation, and draw/check counts
- deferred one-frame wait time when the command snapshot is enriched after presentation
- debug overlay text update cost
- `measured_sum_ms`, `unaccounted_ms`, and a concise top-offenders list; the full validation snapshot exposes `phase_buckets_ms`, `refresh_sections_ms`, and `top_offenders`
- save/autosave profile when a save starts during the command; otherwise `none observed`
- current FPS and derived frame time

## Reconciliation Finding

The original overlay total was measured from command-capture start to `_debug_finish_path_command()`, but the displayed subtotals only covered route/BFS, refresh total, map-view `set_map_state`, indexes, draw-after-frame, and save observation. It did not expose expensive shell lifecycle work inside or adjacent to refresh, especially generated compact surface/action rebuild phases and object/body selection resolution before refresh. The new phase buckets reconcile the command by reporting those lifecycle sections directly and computing explicit `unaccounted_ms`.

Focused Small validation now reconciles both selection and movement commands with near-zero unaccounted time in the generated route smoke. AcOrP's XL finding should now surface the missing pre-refresh or refresh-internal bucket as a named top offender instead of leaving it hidden behind the total.

## Latency Optimization Follow-Up

AcOrP's XL generated-map overlay capture at HEAD `d8c559c` showed a routine adjacent/same-tile move spending `13762.108ms` total: `7890.9ms` in `cmd/movement_rules`, `5824.791ms` in refresh, `3262.4ms` in `refresh/read_scope_map_state`, and `2214.8ms` in `refresh/actions`, while route/BFS, map-view state setting, object/road indexes, drawing, and saves were tiny.

The root cause was repeated broad recomputation around a command that had already-normalized state:

- `OverworldRules.try_move()` and `OverworldShell._refresh()` both re-entered full overworld normalization on generated sessions.
- Post-move interaction resolution could call collection/capture entry points that normalized the just-mutated generated session again before finalization.
- Selected-route action rebuilds asked for broad route-interception fallback surfaces during normal movement/selection, causing whole generated-map scans that were not needed for the route-specific action.

The optimization keeps semantics intact by caching runtime-normalized session signatures, marking state normalized after movement/finalization, using the runtime-normalized path for routine collection/capture entry points, preserving explicit fog/scenario refresh in finalization, caching shell tile object lookups within a refresh, and limiting selected-route interception work to route-specific checks. It does not change generation, object counts, pathing/body/visit contracts, renderer art semantics, saves, objectives, or balance.

Focused generated Small validation now asserts the optimized movement command stays below `50ms` for read-scope setup, `2000ms` for movement rules, `1200ms` for action refresh, and `3500ms` total. A representative post-fix run reported `read_scope_map_state` about `0.8ms`, `movement_rules` about `528ms`, `refresh/actions` about `333ms`, and total about `882ms` on the same generated Small report path. This is not an XL wall-clock substitute, but it proves the targeted full-normalization/read-scope hotspot has been removed from routine generated movement.

## Validation

Added `tests/random_map_pathing_debug_overlay_report.tscn`, which launches a generated Small 36x36 skirmish, enables the overlay, selects a reachable route target, verifies non-empty timing and reconciliation fields, performs the primary route movement, and confirms the hero still moves while the scenario remains in the live overworld. Medium-or-larger generated validation was not practical for this smoke report because the generated Small launch already takes roughly 90 seconds in this checkout; the overlay itself is normal live `OverworldShell` UI and is not size-gated.

## TODOs

- Dynamic-layer invalidation itself does not currently expose a separate invalidation-duration timer; the overlay reports measured dynamic draw time plus the dynamic layer reason/generation.
- Save work is reported only when `SaveService` starts a runtime save during the command. Normal route selection/movement currently reports `none observed`.
