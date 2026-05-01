# Overworld Refresh/Input Pipeline Plan

Date: 2026-05-01
Status: slice-1 implementation seam plus staged async/incremental plan

## Current Synchronous Flow

Route selection is currently input-driven but refresh-heavy:

1. `OverworldShell._on_map_tile_pressed(tile)` validates the tile, starts optional command profiling with `_debug_begin_path_command("click", tile)`, resolves `_selection_route_tile(tile)`, and records `input_handler_entry`.
2. If the tile is a new selection, `_set_selected_tile(route_tile)` updates `_selected_tile`, calls `_invalidate_selected_route_state("selected_tile_changed")`, and clears `_refresh_cache`.
3. Selection then either opens an owned town through `_visit_selected_town()`, performs adjacent movement through `_try_move(dx, dy, true)`, or calls `_refresh()` for route preview/order surfaces.
4. `_refresh()` now runs named synchronous phases:
   - `_refresh_read_scope_and_map_state()`: `OverworldRules.begin_normalized_read_scope(_session)`, map data/size derivation, selected tile repair, refresh-cache invalidation.
   - `_refresh_map_view()`: `_map_view.set_map_state(_session, _map_data, _map_size, _selected_tile, _selected_route_cache_for_map_view())`.
   - `_refresh_action_rails()`: `_rebuild_hero_actions()`, `_rebuild_context_actions()`, `_rebuild_spell_actions()`, `_rebuild_specialty_actions()`, `_rebuild_artifact_actions()`.
   - `_refresh_save_surface()` and `_refresh_status_surfaces()`: save picker/generated opening surfaces, header/status rails, drawer text, tooltip/context drawer sync.
5. Route preview work is pulled synchronously by `_selected_route_cache_for_map_view()` and `_selected_route_decision_surface()`, both of which can call `_ensure_selected_route_state()`. Misses compute `_build_path(hero_pos, _selected_tile)` and `OverworldRules.route_movement_preview(_session, route, movement_current)`.
6. Context actions for selected routes run through `_current_context_actions()`. For non-hero selections it uses `_selected_route_action_surface_signature()`, `_build_selected_route_context_actions()`, `_selected_tile_movement_action()`, and `_selected_route_decision_surface()`. Current-tile actions still call `OverworldRules.get_context_actions(_session)`.

Movement confirmation is also synchronous:

1. Primary button/Enter or a second click calls `_activate_primary_action()` and `_on_context_action_pressed(action_id)`.
2. `advance_route` and `march_selected` dispatch to `_move_toward_selected_tile()`.
3. `_move_toward_selected_tile()` gets `_ensure_selected_route_state("execution")`, profiles `route_execution_lookup`, then calls `OverworldRules.try_move_along_route(_session, route)`.
4. `OverworldRules.try_move_along_route()` validates route topology with `tile_is_blocked()` and `tile_has_route_interaction()`, spends movement, commits active hero state, reveals route fog with `_reveal_route_fog()`, resolves destination interaction if reached, and returns route execution data.
5. `OverworldShell._adopt_selected_route_after_execution(route, result)` keeps a valid remaining-route cache when possible. `_handle_move_result()` routes to battle/town or calls `_refresh()`.

## Derived State Classification

Pure or cacheable when keyed by explicit signatures:

- Selected route path and movement preview: `_ensure_selected_route_state()`, `_selected_route_signature()`, `_selected_route_map_signature()`, `_selected_route_topology_signature()`, `OverworldRules.route_movement_preview()`.
- Selected-route action and decision surfaces: `_selected_route_action_surface_signature()`, `_current_context_actions()` for non-current-tile selections, `_selected_route_decision_surface()`.
- Hero switch actions: `_cached_hero_actions()` keyed by `_hero_actions_state_signature()`.
- Map-view static indexes/layers when keyed by map/session/topology signatures inside `OverworldMapView`.
- Text surfaces that only summarize session state, if their inputs are captured in smaller signatures later.

Mutation-sensitive or read-scope dependent:

- `OverworldRules.normalize_overworld_state*()` and `begin_normalized_read_scope()` side effects.
- Movement execution: `try_move()`, `try_move_along_route()`, `_set_active_hero_position()`, movement budget changes, fog reveal, post-move interaction resolution.
- Context actions on the active tile: `get_active_context()`, `get_context_actions()`, resource/site/artifact/encounter/town state.
- Object resolution and ownership: resource collection/response, artifact collection, town capture/visit, encounter resolution.
- Roster and active hero changes: `switch_active_hero()`, `HeroCommandRulesScript.commit_active_hero()`.
- Map/topology changes: generated/load materialization, map array, towns, resource nodes, artifacts, encounters, resolved encounters, reserve hero positions.
- Fog/visibility state, because route/action eligibility and renderer presentation depend on explored/visible state.

## Event And Invalidation Model

- Selected tile changed: invalidate selected route state, selected-route action surfaces, refresh-scope cache, map overlay route highlight; keep durable hero actions unless hero/roster signature changes.
- Selected route changed: invalidate route decision/context surfaces and map route overlay; route preview/path cache can be replaced without touching mutation state.
- Hero moved: invalidate selected route state unless `_adopt_selected_route_after_execution()` can prove the remaining route starts at the new hero tile; invalidate current-tile context/action surfaces, movement/fog/status rails, map dynamic layer.
- Movement changed: invalidate route preview/decision surfaces, hero action cache if hero movement is part of switchability summary, end-turn/status surfaces.
- Roster changed: invalidate hero action cache, active hero mirror signatures, hero/army/specialty/spell/artifact rails, map hero index.
- Object collected/resolved: invalidate topology signature, blocked/interaction indexes, context actions, route path/decision surfaces, map dynamic/object layers, objective/status surfaces.
- Map/topology changed: invalidate map signature, topology signature, blocked and spatial indexes, route/path/overlay caches, map-view static and dynamic layers.
- Fog/visibility changed: invalidate route/action surfaces that include visibility/explored state, map dynamic/fog layer, hover/context text.
- Session/load changed: clear all durable shell caches, refresh cache, map-view caches, profile validation snapshots, and route/action signatures.

## Deferred/Async Boundaries

Do not introduce real async until the synchronous phases above remain stable under tests. Candidate boundaries, in order:

- Route preview computation: make `_ensure_selected_route_state()` request-oriented and cancellable by route signature. Later compute `_build_path()` plus `route_movement_preview()` deferred, then commit only if the selected-route signature still matches.
- Expensive action surfaces: split selected-route decision/context surfaces from current-tile mutation-sensitive actions. Later defer selected-route decision text/interception surfaces while keeping primary action fallback deterministic.
- Map overlay updates: separate route highlight/fog/dynamic overlay refresh from full `_map_view.set_map_state()`. Later schedule overlay-only redraws when map/topology signatures are unchanged.

## Implementation Slices

1. Refresh phase seams: split `OverworldShell._refresh()` into named synchronous phase methods without behavior changes. Validation: profile-log analyzer, selected-route context-action cache regression, hero-action refresh cache regression, interaction profile-log regression, JSON validation, `git diff --check`.
2. Explicit invalidation helpers: add event-named cache invalidation methods in `OverworldShell` and route all existing invalidations through them without changing cache signatures. Validation: same focused regressions plus a route execution regression.
3. Route preview request object: extract selected-route path/preview computation behind a synchronous request/result helper keyed by `_selected_route_signature()`. Validation: cache regressions prove identical hit/miss behavior and profile bucket names remain comparable.
4. Selected-route action surface split: separate pure selected-route decision/context construction from current-tile context actions, keeping current-tile actions synchronous. Validation: selected route, owned town, encounter, artifact, and resource primary-action regressions.
5. Deferred preview prototype: add a disabled-by-default deferred route-preview path with stale-result rejection by signature. Validation: default path parity tests plus opt-in deferred regression proving stale selections do not overwrite current route state.
