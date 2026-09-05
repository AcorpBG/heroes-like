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
- `buckets_ms.town_entity_cache_dynamic`: time spent refreshing small dynamic town overlays from a cache hit, such as resource affordability labels, leave-button movement text, and compact stage counts.
- `metadata.save_surface_skipped_hidden` and `buckets_ms.save_surface_skipped_hidden`: true/1 when ordinary town refresh skipped expensive save-surface construction because save controls were not actively being used.
- `metadata.first_render_minimal` / `metadata.minimal_current_tab_only`: true when town entry rendered only the active town/current tab before deferred full town command refresh.

Router scene-transition records expose autosave behavior for transition fast paths:

- `buckets_ms.save_before_transition`: `0` when the ordinary transition did not synchronously write the runtime autosave.
- `metadata.save_before_transition_skipped`: true when save work was removed from the transition path.
- `metadata.autosave_deferred_or_skipped_reason`: reason string such as `manual_or_end_turn_only`, `generated_initial_overworld_deferred`, or `forced_save_required_battle`.
- `metadata.autosave_skipped_reason`: `manual_or_end_turn_only` for ordinary town/overworld transitions, which do not create pending autosave intent.
- `metadata.autosave_pending_intent`: true only when a route intentionally records a later runtime-save intent, such as the generated opening autosave path.

Town exit records are additive and do not replace the router transition record:

- `surface: town`, `phase: exit_handoff`, `event: town_exit_first_overworld_frame` measures Leave button/input through the first overworld frame after return.
- `buckets_ms` contains step-delta buckets whose sum reconciles with `total_ms`, covering town handoff computation, router state/scene change, overworld ready/normalize/save-picker work, first refresh/map-state work, compact save-surface handling, and first-frame wait.
- `metadata.router_only_ms` keeps the comparable router-only span visible so slow perceived exits are not mistaken for the cheaper `router/scene_transition/go_to_overworld` record.
- `metadata.first_overworld_ready_ms` and `metadata.first_overworld_frame_ms` distinguish synchronous overworld readiness from the first returned frame.

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

## Full-play and extended Large controls

Use fresh labels: these runners preserve earlier evidence and isolate save storage under `.artifacts/full_play_runtime_20260905/`.

```sh
python3 tests/full_play_runtime_profile.py --label skirmish_play
python3 tests/full_play_runtime_profile.py --label campaign_play --flow campaign --resolution 1280x720
python3 tests/full_play_large_session_profile.py --label large_control --reference-lookups --rendered
python3 tests/full_play_large_session_profile.py --label large_current --rendered --compare .artifacts/full_play_runtime_20260905/large_control
python3 tests/content_lookup_performance_regression.py --label lookups --require-improvement
python3 tests/battle_refresh_optimization_regression.py --label battle_copy
python3 tests/save_refresh_projection_regression.py --label save_bars
python3 tests/end_turn_snapshot_probe.py --label tied_scouting_memory
python3 tests/full_play_validation_suite.py --label domains
python3 tests/full_play_compatibility_regression.py --label input_checks --case active_input --accessibility disabled
python3 tests/full_play_compatibility_regression.py --label moonbite_control --case town_balance_control
```

The Large driver uses the shipped owned-town body click without moving the hero, legal orders/exploration, and at least ten simulated days or a natural outcome; it also requires actual successful movement. Quick Resolve is a shipped order, not an injected victory. Battle report Continue includes its required save. The authored flow's opt-in deterministic identity and complete state captures are fixture-only; see [full-play report](full-play-runtime-performance-report.md). Use equal renderer/resolution/instrumentation when comparing latency, and do not sum nested timers or numeric counters stored in historical timing buckets.

Rendered runs use an isolated D-Bus/Xvfb desktop and commit the requested resolution through the real Settings owner in their isolated test storage (engine command-line size alone is overwritten by saved settings). `--accessibility disabled` is an explicit test-only workaround for the reproduced Godot 4.6.2 AccessKit `InterfaceNotFound` abort; both timing controls must use the same backend. Preserve the failed enabled-backend logs and do not claim a disabled-backend run certifies screen-reader support. The normal game settings are not changed.

`full_play_profile_compare.py CONTROL CURRENT --expected-states N` compares every complete control session tree and only equal ordered profile-event identities. A failed partial control remains labeled partial, never a completed playthrough. `end_turn_snapshot_probe.py [SESSION_FIXTURE] --label NAME` can replay a preserved whole-session failure or use its default tied-scouting-memory fixture; real state changes must still invalidate confirmation.

Save-surface records now include `metadata.stored_recaps_requested`: Battle, Overworld and explicit Town save bars request verified slot/current-state copy without constructing unused stored resume text. Outcome retains its displayed stored recap. No storage freshness check or required save is skipped. `--functional-only` disables profiling for an independent behavior-only playthrough; its wall time/RSS must not be used as performance comparison evidence.

`full_play_validation_suite.py --only TEST... [--rendered]` isolates existing domain reports with a configurable per-case timeout (900 seconds by default: the town catalog and music scene matrices exceed four minutes). Deliberately injected save/settings failure lines are classified only for their exact test/domain; other native/script errors and leaked resources fail. The full catalog currently reports a pre-existing Moonbite development-budget failure. `town_balance_control` reproduces its identical full report with old/current lookup owners; that parity pass does not waive the balance failure.

`active_input` reuses four unchanged physical Overworld input cases. The legacy all-in-one input smoke also assumes the retired numbered-slot dialog, Town TabBar and pre-casualty-report Battle handoff, so it is not claimed passed. Run named-file, current Town layout/dialog, Battle controller-board and actual dialog-button regressions separately for those interfaces. Failed full campaign attempts and enabled-AT-SPI runs remain evidence gaps, not successful whole-arc/accessibility certification.
