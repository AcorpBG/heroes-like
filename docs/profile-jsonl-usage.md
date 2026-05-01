# JSONL Performance Profiling

Broad profiling is opt-in and append-only.

## Enable

Linux/macOS:

```sh
HEROES_PROFILE_LOG=1 godot4 --path /root/dev/heroes-like
```

Windows PowerShell:

```powershell
$env:HEROES_PROFILE_LOG = "1"
godot4 --path C:\path\to\heroes-like
```

The older overworld switch still works:

```sh
HEROES_OVERWORLD_PROFILE_LOG=1 godot4 --path /root/dev/heroes-like
```

`HEROES_PROFILE_LOG=1` enables the broad log and also keeps overworld interaction records available through the existing overworld profile path.

## Paths

- General lifecycle/surface log: `user://debug/heroes_profile.jsonl`
- Legacy overworld interaction log: `user://debug/overworld_profile.jsonl`

Godot expands `user://` to the project user-data directory. Test helpers report absolute paths in their validation snapshots.

## Record Shape

General records use `schema: heroes_like.profile.v1`.

Important fields:

- `surface`: broad runtime surface, such as `boot`, `menu`, `router`, `save`, `overworld`, `town`, or `battle`.
- `phase`: lifecycle phase, such as `ready`, `refresh`, `scenario_launch`, `generated_setup`, `scene_transition`, `entry`, `action`, `payload`, or `end_turn`.
- `event`: specific action or milestone.
- `total_ms`: elapsed time for that profiled operation.
- `buckets_ms`: named timing buckets inside the operation.
- `metadata`: event-specific details, including target scene, active tab, save path, generated setup fields, action ids, or legacy overworld profile payloads where relevant.
- `session`: compact session metadata and counts for map, town/resource/artifact/encounter, and battle state.

Records are evidence only. They do not change save schema, routing contracts, renderer/fog behavior, pathing, generated-map density, or gameplay rules.

Town refresh records include active-town cache evidence when `surface: town` and `phase: refresh` or `entry`:

- `buckets_ms.town_entity_cache_hit` / `buckets_ms.town_entity_cache_miss`: numeric 1/0 indicators for whether the active `placement_id` view-state cache was reused.
- `buckets_ms.town_entity_cache_entries`: number of cached town entries for the active session.
- `metadata.town_entity_cache`: cache details, including `placement_id`, hit/miss state, and entry count.
- `metadata.save_surface_skipped_hidden` and `buckets_ms.save_surface_skipped_hidden`: true/1 when ordinary town refresh skipped expensive save-surface construction because save controls were not actively being used.
- `metadata.first_render_minimal` / `metadata.minimal_current_tab_only`: true when town entry rendered only the active town/current tab before deferred full town command refresh.

Router scene-transition records expose autosave behavior for transition fast paths:

- `buckets_ms.save_before_transition`: `0` when the ordinary transition did not synchronously write the runtime autosave.
- `metadata.save_before_transition_skipped`: true when save work was removed from the transition path.
- `metadata.autosave_deferred_or_skipped_reason`: reason string such as `manual_or_end_turn_only`, `generated_initial_overworld_deferred`, or `forced_save_required_battle`.
- `metadata.autosave_skipped_reason`: `manual_or_end_turn_only` for ordinary town/overworld transitions, which do not create pending autosave intent.
- `metadata.autosave_pending_intent`: true only when a route intentionally records a later runtime-save intent, such as the generated opening autosave path.

Runtime save records expose trusted-live autosave normalization behavior:

- `metadata.restore_normalize_skipped`: true when an already-live normalized autosave skipped the restore-style validation path.
- `metadata.restore_normalize_skip_reason`: reason string for the trusted-live skip.

## Analyze

General log:

```sh
python3 scripts/analyze_overworld_profile_log.py ~/.local/share/godot/app_userdata/heroes-like/debug/heroes_profile.jsonl --mode general
```

Legacy overworld log:

```sh
python3 scripts/analyze_overworld_profile_log.py ~/.local/share/godot/app_userdata/heroes-like/debug/overworld_profile.jsonl --mode overworld
```

`--mode auto` is the default and detects either schema.
