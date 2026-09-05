# Large Map Town Construction And End Turn Profile

Owner request, 2026-09-05: profile slow Large-map construction and End Turn. Parent: Phase 6; slice: `performance-large-town-build-and-end-turn-20260905`. Requirements: [large-town-build-and-end-turn-performance-requirements.md](large-town-build-and-end-turn-performance-requirements.md).

## Result and boundary

The stalls are reproduced. Construction is dominated by repeated catalog/consequence queries and a forced save-summary inspection, not the building mutation or scenic sprite update. End Turn grows substantially with enemy arrival resolution and planning. This slice currently adds reproducible profiling tooling and opt-in timing fields only. **No production performance optimization is implemented or claimed.** Applying fixes is a separate, owner-confirmed continuation.

Baseline runtime source: `3dd32bc77f065d2f204696de05b021492bb6ee69`. Final instrumentation adds `TownShell`'s `build_commit` event and splits the existing AI arrival timing into resolution and repair. Original gameplay call order and results remain unchanged. The prior `build` profile event measures only recap generation and is retained for compatibility; it must not be interpreted as the whole purchase.

## Reproduction

Run serially on an otherwise idle Linux host:

```sh
python3 tests/large_town_build_end_turn_profile.py --label baseline
python3 tests/large_town_build_end_turn_profile.py --label instrumented --detail --compare baseline
```

Use fresh labels when retaining prior evidence. Outputs live under `.artifacts/large_town_build_end_turn_20260905/<label>/`: `runtime.log`, `report.json`, and twelve complete before/after session snapshots. The actual captured sequence was `baseline`, `detailed`, then `instrumented`; the final `compare_states` helper compared instrumented snapshots to baseline in `state_parity.json` after the run. `--compare` embeds the same check in future reports.

Host: four exposed AMD EPYC-Genoa CPUs, Linux 6.8.0-111 x86_64, Godot 4.6.2 stable. Peak child RSS in the instrumented run: 1689616 KiB. These are headless CPU/main-thread measurements, not Windows hardware or GPU frame-time certification.

Fixture: seed `large-runtime-profile-10225`, 108x108 `homm3_large`, four players, translated template/profile 042, land/single level, Veilmourn and Orso Nightchart. Runtime scenario `native_h3maped_c2520619_skirmish`; unchanged materialized signature `7362cf00`. Generated source records: 2961. No generation rules, placements or content were changed.

The runner enters the player's existing town and buys the first naturally enabled building on each of three successive days: Market Square, Fog Signal Buoys, Salvage Ledger. No stockpile injection. It calls the actual ledger open/select/confirm callbacks, measures synchronous return and the construction input blocker's release, then uses the existing real End Turn request/confirmation path with autosave. Only automatic scene routing is disabled to keep the test observer alive; the rules still execute. Human time spent deciding in dialogs is excluded. Session snapshots and save/restore checks run outside timed actions, in isolated save storage.

## Timings

Seconds; instrumented run. Baseline purchase confirmations were 8.12/9.60/11.47 seconds and End Turns 8.79/10.72/17.03 seconds, consistent with the instrumented reproduction below. These are repeated reproductions, **not before/after improvements**.

| Day | Town entry | Ledger open | Select plan | Confirm callback | Confirm to usable controls | End Turn request + confirm |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1.91 | 2.24 | 6.44 | 8.03 | 8.84 | 8.64 |
| 2 | 1.83 | 1.74 | 4.87 | 9.55 | 10.35 | 10.65 |
| 3 | 2.04 | 2.27 | 6.52 | 11.29 | 12.12 | 16.88 |

### Construction

`scenes/town/TownShell.gd`:

- `_select_build_action` looks up an action through the full catalog, separately calls `TownRules.get_build_actions`, then passes incomplete action rows to `_rebuild_build_actions`, which rebuilds the full catalog again. On day one the lookup takes 2.11 seconds, rebuild takes 2.13 seconds, and the intervening action query accounts for roughly another 2 seconds. Opening the ledger constructs its actual controls in approximately 33 milliseconds; the rest is querying.
- `_on_confirm_build_pressed` performs another full catalog eligibility query (2.08 seconds on day one).
- `_commit_build_action` computes a full pre-action consequence signature (2.28 seconds), then `_validation_action_for_id` calls `validation_action_catalog`, collecting all ten Town action domains (2.18 seconds). This validation-named helper is on the live purchase path.
- The authoritative `TownRules.build_active_town` / `OverworldRules.build_in_active_town` mutation itself costs 228/239/313 milliseconds. Recap and presentation setup cost about 0.24 and 0.21 seconds, respectively. No evidence supports changing build costs or animation art to address the main stall.
- `_refresh` costs 0.81/3.93/3.94 seconds. The scenic stage refresh is approximately 1–2 milliseconds in the headless profile; most later-day refresh time comes from save inspection described below.

`_build_active_town_entity_view_state` calls `_town_action_context_surface`, which forces `_town_save_surface_for_context(true)` → `AppRouter.active_save_surface` → `SaveService.build_in_session_save_surface` → `latest_loadable_summary`. The latter enumerates/inspects autosave, legacy slots and named files. With an autosave now present on days two and three, that inspection takes 3.11/3.10 seconds, despite the visible Save controls being closed. The separate `save_surface_skipped_hidden` refresh field therefore does not prove that no save work occurred earlier in view-model construction. This is summary inspection, not writing an extra construction autosave.

Read-only diagnostic control: the same 23-row `TownRules.get_build_catalog` took 2089.886 ms without a scope and 802.458 ms inside the existing paired normalized/Town read scopes. Catalog values and the entire session were exactly unchanged. This establishes useful redundant-query cost, not a measured improvement in shipped interactions. Never retain a read scope across a build mutation.

### End Turn

| Ending day | Request preparation | Simulation | Autosave | Synchronous refresh | Full request + confirm |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1.45 | 4.67 | 1.61 | 0.68 | 8.64 |
| 2 | 1.67 | 6.39 | 1.62 | 0.69 | 10.65 |
| 3 | 2.03 | 12.15 | 1.61 | 0.72 | 16.88 |

The columns do not sum exactly: full wall time also includes confirmation stale-state checking and dispatch outside the existing core `end_turn` event. `OverworldShell._request_end_turn` prepares warning/forecast surfaces and the stale-state signature; the confirm path validates that signature before `_commit_end_turn` runs rules/save/refresh.

By day three, aggregated enemy faction phases include 3.56 seconds advancing existing raids, 1.47 seconds advancing newly launched raids, 1.45 seconds pre-build task planning, 1.32 seconds post-raid task planning, and 1.14 seconds launch selection. `EnemyTurnRules._run_empire_cycle` owns that sequence; `EnemyAdventureRules.plan_enemy_hero_task_board` enumerates descriptors and projects candidates from origins. The profile does not yet isolate all inner planner/risk-resolution costs, so no specific inner algorithm optimization is claimed.

The new arrival split localizes **4.411 seconds to `EnemyAdventureRules._resolve_arrived_target`**, across existing and newly launched raids, versus only 39 ms in `_repair_live_raid_target_after_resolution`. Arrival resolution dispatches resource/artifact claims, encounters, town/exploration goals, readiness checks and risk retasking. This disproves treating the adjacent target-repair function as the main arrival bottleneck. The 4.411-second figure is nested inside the raid phases, not additive to them. Autosave remained stable and is not the source of this turn-to-turn growth.

## Safe next work, not yet implemented

1. Eliminate redundant construction catalog/consequence queries using bounded read scopes and action-domain-specific lookup; preserve fresh eligibility checks at confirmation and invalidate before mutation.
2. Stop ordinary action tooltips forcing full stored-save inspection; retain correct save/return summaries when requested, without weakening transaction recovery or hiding a delayed stall elsewhere.
3. Profile inside the expensive arrival-resolution and planner paths before choosing behavior-preserving reuse. Keep enemy decisions, risk checks, target integrity and ordering unchanged; do not reduce enemy activity to make timing smaller.

## Validation evidence

Completed measurements: three naturally affordable purchases and three successive End Turns in each of the baseline, detailed and instrumented runs; signature and 2961-record generated save/restore preservation pass. All twelve complete instrumented session trees exactly equal baseline, with **no ignored fields**, including enemy decisions, resources, town development and day progression (`state_parity.json`). The read-only scoped/unscoped catalog probe also passes exact catalog/session equality.

Additional validation under `.artifacts/large_town_build_end_turn_20260905/validation/`:

- `town_limit.log`: PASS, independent per-town/day construction limits and next-day availability.
- `town_catalog.log`: PASS, live construction/muster catalog controls at 1280x720 and 1920x1080 plus six-faction auxiliary cases. Rendered via Xvfb with profiling disabled.
- `end_turn_confirmation.log`: PASS, cancellation, stale requests, risk confirmation, same-stack routing/focus safety and low-risk one-click behavior, profiling disabled.
- `repo.log`: `python3 tests/validate_repo.py` — `VALIDATION PASSED`; Python compilation and `git diff --check` pass.
- `linux-final/report.json`, `windows-final/report.json`: PASS, serial exports, startup, native sidecars and all package-content checks. Both PCKs are **248370060 bytes**, 1629940 below the unchanged 250000000-byte ceiling.
- `linux-generated-flow/live_validation_report.json` and `windows-final/generated-flow/live_validation_report.json`: PASS, actual packaged generated setup → Overworld → player Town. Windows exercised through fresh Wine prefixes, not native Windows hardware certification.

The first Linux export attempt failed because the test's isolated `XDG_DATA_HOME` hid installed export templates. The successful final serial runs retained isolated save data while exposing the existing templates through a temporary symlink. This was a validation-environment correction, not a game or template change. Existing renderer shutdown RID warnings remain outside this profiling scope.

The profiling tooling and findings are validated. The broader optimization continuation remains unimplemented and awaits owner direction; no performance-fix or release-readiness completion claim is made.
