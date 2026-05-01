# Overworld Refresh/Input Pipeline Plan

Date: 2026-05-01
Status: rendered-client large-map simple-route context/readiness hot-path follow-up implemented; staged async plan remains

## Current Synchronous Flow

Route selection is currently input-driven but refresh-heavy:

1. `OverworldShell._on_map_tile_pressed(tile)` validates the tile, starts optional command profiling with `_debug_begin_path_command("click", tile)`, resolves `_selection_route_tile(tile)`, and records `input_handler_entry`.
2. If the tile is a new selection, `_set_selected_tile(route_tile)` updates `_selected_tile`, calls `_invalidate_selected_route_state("selected_tile_changed")`, and clears `_refresh_cache`.
3. Selection then either opens an owned town through `_visit_selected_town()`, performs adjacent movement through `_try_move(dx, dy, true)`, or calls `_refresh_selected_route_preview()` for route preview/order surfaces.
4. `_refresh()` remains the full safety path and now runs through a refresh request containing all phases:
   - `_refresh_read_scope_and_map_state()`: `OverworldRules.begin_normalized_read_scope(_session)`, map data/size derivation, selected tile repair, refresh-cache invalidation.
   - `_refresh_map_view()`: `_map_view.set_map_state(_session, _map_data, _map_size, _selected_tile, _selected_route_cache_for_map_view())`.
   - `_refresh_action_rails(request)`: rebuilds only requested action rails, or all rails for full refresh.
   - `_refresh_save_surface()` and `_refresh_status_surfaces()`: save picker/generated opening surfaces, header/status rails, drawer text, tooltip/context drawer sync.
5. `_refresh_selected_route_preview()` builds a targeted refresh request for `map_view` and `route_preview`. It keeps the normalized read scope, updates the selected-route overlay through the map view, rebuilds the primary/context buttons through the destination-only route action path, refreshes selected-tile route text, and skips broad context actions, hero/spell/specialty/artifact/save/status rails, and tooltip/context drawer rebuilds unless some later dirty request explicitly includes them.
6. Route preview work is pulled synchronously by `_selected_route_cache_for_map_view()` and `_selected_route_decision_surface()`, both of which can call `_ensure_selected_route_state()`. Misses compute `_build_path(hero_pos, _selected_tile)` and `OverworldRules.route_movement_preview(_session, route, movement_current)`.
7. Selected-route actions are destination-only. `_refresh_selected_route_action_surface()` calls `_selected_route_destination_actions()`, which classifies the final destination interaction and exposes hold/blocked/advance/march actions without calling broad `_current_context_actions()` or route-wide context scanning. For `open` and `current` destinations, `_selected_route_simple_destination_surface()` builds the action, rail line, context tile route line, field-readiness route line, and primary button tooltip directly from `_selected_route_state`, the cached movement preview, and the compact destination descriptor. Those open/current paths do not call `_selected_route_decision_surface()`, `_route_decision_tooltip()`, `_route_decision_brief()`, `_primary_order_commit_check_surface()`, `_route_target_handoff_surface()`, `_town_entry_handoff_surface()`, or `_active_site_order_surface()`. Rich route decision/tooltip/brief/handoff surfaces remain available for town, resource, artifact, and encounter destinations. The cache signature is minimal: session identity, active hero id/position, movement current/max, selected tile, selected-route generation/validity, destination blocked state, and destination-tile interaction state only. It does not hash full map rows, full topology arrays, hero/resource serialization, or objective recaps.

Movement confirmation is also synchronous:

1. Primary button/Enter or a second click calls `_activate_primary_action()` and `_on_context_action_pressed(action_id)`.
2. `advance_route` and `march_selected` dispatch to `_move_toward_selected_tile()`.
3. `_move_toward_selected_tile()` gets `_ensure_selected_route_state("execution")`, profiles `route_execution_lookup`, and checks whether the selected-route cache is still executable by start tile, selected tile, movement budget, preview availability, destination bounds, and destination blocked state.
4. On a valid selected-route cache, `_move_toward_selected_tile()` passes the cached destination interaction descriptor into `OverworldRules.execute_prevalidated_route(_session, route, preview, -1, descriptor)`. This path uses cached reachable steps/movement-after data, moves to the farthest reachable tile, commits active hero state once, reveals fog along traversed steps, and skips scenario evaluation, post-action recap, broad active-tile discovery, and post-action tile context scans for open destinations. If the reached destination descriptor is interactable, it dispatches only that descriptor kind/id/tile. It does not re-run the route-wide `tile_is_blocked()` / `tile_has_route_interaction()` validation loop.
5. On stale, missing, or unsafe cache state, `_move_toward_selected_tile()` falls back to `OverworldRules.try_move_along_route(_session, route)`, preserving the full validation loop and existing safety semantics.
6. `OverworldShell._adopt_selected_route_after_execution(route, result)` keeps a valid remaining-route cache when possible. `_handle_move_result()` routes to battle/town, or, when route selection is preserved, calls `_refresh_selected_route_preview("route_execution_changed")` so confirmation reuses the cached route and destination-only action path instead of forcing a full context/hero refresh.
7. Open adjacent-tile clicks now enter the same selected-route cached execution path as route confirmation after `_set_selected_tile()` builds the adjacent route target. Non-open adjacent destinations still use the existing direct move/interaction path.
8. Movement-rule profiling now exposes `cached_execution_mode`, `post_action_recap_skipped`, `scenario_eval_skipped`, `interaction_dispatch_mode`, and exact `fallback_reason` so cached open movement, descriptor interaction movement, and full fallback movement are distinguishable in F3 snapshots and persistent JSONL records. Route-action profiling also exposes `simple_route_ui_fast_path`, `simple_open_route_ui_fast_path`, `simple_current_route_ui_fast_path`, `rich_route_surface_skipped_for_simple_route`, `primary_route_action_cheap_tooltip`, `context_tile_text_simple_route_fast_path`, and `field_readiness_simple_route_fast_path`, with JSONL `simple_route_fast_paths` details so rendered-client records show when rich open/current route UI, context text, and readiness work were actually skipped.

## Derived State Classification

Pure or cacheable when keyed by explicit signatures:

- Selected route path and movement preview: `_ensure_selected_route_state()`, `_selected_route_signature()`, `_selected_route_destination_state_signature()`, `OverworldRules.route_movement_preview()`.
- Selected-route action and decision surfaces: `_selected_route_action_surface_signature()`, `_selected_route_destination_actions()`, `_selected_route_simple_destination_surface()`, `_selected_route_destination_interaction_surface()`, `_selected_route_decision_surface()`.
- Hero switch actions: `_cached_hero_actions()` keyed by `_hero_actions_state_signature()`.
- Map-view static indexes/layers when keyed by map/session/topology signatures inside `OverworldMapView`.
- Text surfaces that only summarize session state, if their inputs are captured in smaller signatures later.

Mutation-sensitive or read-scope dependent:

- `OverworldRules.normalize_overworld_state*()` and `begin_normalized_read_scope()` side effects.
- Movement execution: `try_move()`, `try_move_along_route()`, `execute_prevalidated_route()`, `_set_active_hero_position()`, movement budget changes, fog reveal, post-move interaction resolution.
- Context actions on the active tile: `get_active_context()`, `get_context_actions()`, resource/site/artifact/encounter/town state.
- Object resolution and ownership: resource collection/response, artifact collection, town capture/visit, encounter resolution.
- Roster and active hero changes: `switch_active_hero()`, `HeroCommandRulesScript.commit_active_hero()`.
- Map/topology changes: generated/load materialization, map array, towns, resource nodes, artifacts, encounters, resolved encounters, reserve hero positions.
- Fog/visibility state, because route/action eligibility and renderer presentation depend on explored/visible state.

## Event And Invalidation Model

- Implemented request phases: `map_view`, `action_rails`, `hero_actions`, `context_actions`, `route_preview`, `spell_rails`, `specialty_rails`, `artifact_rails`, `status_surfaces`, `save_surface`, and `generated_surfaces`.
- `_set_selected_tile()` now marks only `map_view` and `route_preview` dirty for non-current route destinations while invalidating selected-route state/action surfaces. It adds `context_actions` only when selection returns to the active hero/current tile. It does not mark hero/spell/specialty/artifact/status/save surfaces dirty.
- `_refresh_selected_route_preview()` consumes the selected-route dirty phases through the targeted request and leaves the full `_refresh()` path available for load/session/topology/mutation-heavy operations.
- Selected tile changed: invalidate selected route state, selected-route action surfaces, refresh-scope cache, map overlay route highlight; keep durable hero actions unless hero/roster signature changes.
- Selected route changed: invalidate route decision/destination-action surfaces and map route overlay; route preview/path cache can be replaced without touching mutation state.
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
- Expensive action surfaces: open/current selected-route preview now uses the simple-route UI fast path. Later defer selected-route decision text/interception surfaces for rich interaction destinations while keeping primary action fallback deterministic.
- Map overlay updates: separate route highlight/fog/dynamic overlay refresh from full `_map_view.set_map_state()`. Later schedule overlay-only redraws when map/topology signatures are unchanged.
- Movement execution remains synchronous, but selected-route confirmation now has a cached prevalidated execution path. Future movement work should target any remaining measured inner cause instead of moving the full route-validation loop into another bucket.

## Implementation Slices

1. Completed - Refresh phase seams: split `OverworldShell._refresh()` into named synchronous phase methods without behavior changes. Validation: profile-log analyzer, selected-route context-action cache regression, hero-action refresh cache regression, interaction profile-log regression, JSON validation, `git diff --check`.
2. Completed - Incremental route-preview refresh plus destination-only route actions: add the lightweight refresh request/dirty-phase model, route selected-tile/route preview through a targeted synchronous request, build selected-route primary/context actions from the destination tile only, and skip broad context actions, hero actions, and tooltip/context drawers on the selected-route hot path. Validation: new incremental and destination-only route regressions, existing cache regressions, interaction profile-log regression, JSON validation, profile-log analyzer, `git diff --check`.
3. Completed - Cached selected-route execution and open-tile fast path: replace selected-route action/decision signatures with destination-only signatures, reuse cached route state/preview for selected-route confirmation, execute valid selected-route caches through `execute_prevalidated_route()`, and for open reached destinations skip full finalization, scenario evaluation, post-action recap, broad active interaction discovery, post-action tile context scans, and route-wide revalidation. Interactable reached destinations dispatch by cached destination descriptor. Stale, missing, unknown, or mismatched descriptors fall back to `try_move_along_route()`. Validation: cached-route execution regression plus existing destination-only, incremental refresh, profile-log, selected-route cache, and hero-action cache regressions.
4. Completed - Rendered-client large-map simple-route UI hot path: based on `.artifacts/uploaded_profiles/20260501/display99_actual_large_overworld_profile.jsonl`, open/current route preview and post-move current-tile refresh now build compact action/rail/tooltip surfaces from `_selected_route_state` and the destination descriptor, skip rich decision/brief/handoff/commit-check surfaces, and expose explicit JSONL counters for the fast path. Adjacent open-tile clicks use the cached selected-route execution path instead of the full direct `try_move()` route-wide validation path. Validation: cached-route execution regression, destination-only action regression, incremental refresh regression, profile-log regression, selected-route cache regression, hero-action cache regression, and analyzer run on the uploaded DISPLAY profile.
5. Completed - Rendered-client large-map context/readiness simple-route follow-up: based on `.artifacts/uploaded_profiles/20260501/display99_actual_large_after_2e81b35_profile.jsonl`, open/current selected route context tile text now uses the compact route line instead of `_selected_route_decision_surface()`, and field readiness uses cheap simple-route primary/readiness text while skipping rich route decision/brief, route target handoff, town entry handoff, and active-site handoff construction. Persistent JSONL records expose `simple_route_fast_paths.context_tile_text_*` and `simple_route_fast_paths.field_readiness_*` alongside the raw profile counters. Validation: cached-route execution regression, destination-only action regression, incremental refresh regression, profile-log regression, selected-route cache regression, hero-action cache regression, JSON validation, diff whitespace check, and analyzer compatibility run on the uploaded after-2e81b35 profile.
6. Next async boundary - Route preview request object: extract selected-route path/preview computation behind a cancellable request/result helper keyed by `_selected_route_signature()`. Keep it synchronous first if needed, then defer `_build_path()` plus `route_movement_preview()` with stale-result rejection.
7. Deferred preview prototype: add a disabled-by-default deferred route-preview path with stale-result rejection by signature. Validation: default path parity tests plus opt-in deferred regression proving stale selections do not overwrite current route state.
