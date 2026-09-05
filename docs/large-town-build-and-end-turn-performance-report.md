# Large Map Town Construction And End Turn Profile

Owner request, 2026-09-05: profile slow Large-map construction and End Turn. Parent: Phase 6; slice: `performance-large-town-build-and-end-turn-20260905`. Requirements: [large-town-build-and-end-turn-performance-requirements.md](large-town-build-and-end-turn-performance-requirements.md).

## Result and boundary

The stalls were reproduced and the active-goal continuation selected runtime fixes. Town now shares fresh construction query results and builds current-session tooltip copy without inspecting unrelated saved games. End Turn shares read-only warning calculations, and AI target enumeration/exploration reuses decision-local visibility inputs. Matched construction waiting fell 73.4% and End Turn waiting fell 29.3%. Exact state comparisons, relevant regressions and both-platform package checks pass. Gameplay rules, scoring, target order, saves and generated content remain unchanged; this is not a release-readiness claim.

Baseline runtime source: `3dd32bc77f065d2f204696de05b021492bb6ee69`; profiling-only commit: `b628ec36576f5ec03aa7a5e55b11f5de28afcde3`. Instrumentation adds `TownShell`'s `build_commit` event and splits AI arrival timing into resolution, target family and repair. The prior `build` event measures only recap generation and is retained for compatibility; it must not be interpreted as the whole purchase. After optimization, confirmation preflight is measured by the complete callback timer, not the inner commit event.

## Reproduction

The control commands below were run at the baseline/profiling revisions, serially on an otherwise idle Linux host. They are historical controls, not fresh baseline measurements of the optimized code:

```sh
python3 tests/large_town_build_end_turn_profile.py --label baseline
python3 tests/large_town_build_end_turn_profile.py --label instrumented --detail --compare baseline
```

Use fresh labels when retaining prior evidence. Outputs live under `.artifacts/large_town_build_end_turn_20260905/<label>/`: `runtime.log`, `report.json`, and twelve complete before/after session snapshots. The actual captured sequence was `baseline`, `detailed`, then `instrumented`; the final `compare_states` helper compared instrumented snapshots to baseline in `state_parity.json` after the run. `--compare` embeds the same check in future reports.

Host: four exposed AMD EPYC-Genoa CPUs, Linux 6.8.0-111 x86_64, Godot 4.6.2 stable. Peak child RSS in the instrumented run: 1689616 KiB. These are headless CPU/main-thread measurements, not Windows hardware or GPU frame-time certification.

Fixture: seed `large-runtime-profile-10225`, 108x108 `homm3_large`, four players, translated template/profile 042, land/single level, Veilmourn and Orso Nightchart. Runtime scenario `native_h3maped_c2520619_skirmish`; unchanged materialized signature `7362cf00`. Generated source records: 2961. No generation rules, placements or content were changed.

The runner enters the player's existing town and buys the first naturally enabled building on each of three successive days: Market Square, Fog Signal Buoys, Salvage Ledger. No stockpile injection. It calls the actual ledger open/select/confirm callbacks, measures synchronous return and the construction input blocker's release, then uses the existing real End Turn request/confirmation path with autosave. Only automatic scene routing is disabled to keep the test observer alive; the rules still execute. Human time spent deciding in dialogs is excluded. Session snapshots and save/restore checks run outside timed actions, in isolated save storage.

## Baseline timings and root causes

Seconds; instrumented run. Baseline purchase confirmations were 8.12/9.60/11.47 seconds and End Turns 8.79/10.72/17.03 seconds, consistent with the instrumented reproduction below. These are repeated reproductions, **not before/after improvements**.

| Day | Town entry | Ledger open | Select plan | Confirm callback | Confirm to usable controls | End Turn request + confirm |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1.91 | 2.24 | 6.44 | 8.03 | 8.84 | 8.64 |
| 2 | 1.83 | 1.74 | 4.87 | 9.55 | 10.35 | 10.65 |
| 3 | 2.04 | 2.27 | 6.52 | 11.29 | 12.12 | 16.88 |

### Construction

At the baseline revision, `scenes/town/TownShell.gd`:

- `_select_build_action` looks up an action through the full catalog, separately calls `TownRules.get_build_actions`, then passes incomplete action rows to `_rebuild_build_actions`, which rebuilds the full catalog again. On day one the lookup takes 2.11 seconds, rebuild takes 2.13 seconds, and the intervening action query accounts for roughly another 2 seconds. Opening the ledger constructs its actual controls in approximately 33 milliseconds; the rest is querying.
- `_on_confirm_build_pressed` performs another full catalog eligibility query (2.08 seconds on day one).
- `_commit_build_action` computes a full pre-action consequence signature (2.28 seconds), then `_validation_action_for_id` calls `validation_action_catalog`, collecting all ten Town action domains (2.18 seconds). This validation-named helper is on the live purchase path.
- The authoritative `TownRules.build_active_town` / `OverworldRules.build_in_active_town` mutation itself costs 228/239/313 milliseconds. Recap and presentation setup cost about 0.24 and 0.21 seconds, respectively. No evidence supports changing build costs or animation art to address the main stall.
- `_refresh` costs 0.81/3.93/3.94 seconds. The scenic stage refresh is approximately 1–2 milliseconds in the headless profile; most later-day refresh time comes from save inspection described below.

The baseline `_build_active_town_entity_view_state` calls `_town_action_context_surface`, which forces `_town_save_surface_for_context(true)` → `AppRouter.active_save_surface` → `SaveService.build_in_session_save_surface` → `latest_loadable_summary`. The latter enumerates/inspects autosave, legacy slots and named files. With an autosave now present on days two and three, that inspection takes 3.11/3.10 seconds, despite the visible Save controls being closed. The separate `save_surface_skipped_hidden` refresh field therefore does not prove that no save work occurred earlier in view-model construction. This is summary inspection, not writing an extra construction autosave.

Read-only diagnostic control: the same 23-row `TownRules.get_build_catalog` took 2089.886 ms without a scope and 802.458 ms inside the existing paired normalized/Town read scopes. Catalog values and the entire session were exactly unchanged. This establishes useful redundant-query cost, not a measured improvement in shipped interactions. Never retain a read scope across a build mutation.

### End Turn

| Ending day | Request preparation | Simulation | Autosave | Synchronous refresh | Full request + confirm |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1.45 | 4.67 | 1.61 | 0.68 | 8.64 |
| 2 | 1.67 | 6.39 | 1.62 | 0.69 | 10.65 |
| 3 | 2.03 | 12.15 | 1.61 | 0.72 | 16.88 |

The columns do not sum exactly: full wall time also includes confirmation stale-state checking and dispatch outside the existing core `end_turn` event. `OverworldShell._request_end_turn` prepares warning/forecast surfaces and the stale-state signature; the confirm path validates that signature before `_commit_end_turn` runs rules/save/refresh.

By day three, baseline aggregated enemy faction phases include 3.56 seconds advancing existing raids, 1.47 seconds advancing newly launched raids, 1.45 seconds pre-build task planning, 1.32 seconds post-raid task planning, and 1.14 seconds launch selection. `EnemyTurnRules._run_empire_cycle` owns that sequence; `EnemyAdventureRules.plan_enemy_hero_task_board` enumerates descriptors and projects candidates from origins. The first profile did not isolate every inner planner/risk-resolution cost. Source inspection and the subsequent decision-local visibility experiment identified repeated sight-source gathering; the correction and matched control are described below.

The new arrival split localizes **4.411 seconds to `EnemyAdventureRules._resolve_arrived_target`**, across existing and newly launched raids, versus only 39 ms in `_repair_live_raid_target_after_resolution`. Arrival resolution dispatches resource/artifact claims, encounters, town/exploration goals, readiness checks and risk retasking. This disproves treating the adjacent target-repair function as the main arrival bottleneck. The 4.411-second figure is nested inside the raid phases, not additive to them. Autosave remained stable and is not the source of this turn-to-turn growth.

## Implemented optimizations

1. `TownShell._read_build_catalog` uses existing paired read scopes. Each selection builds one complete catalog and reuses it for lookup/cards. `_prepare_build_read_context` shares catalog, consequence and build-lane action reads in a single synchronous confirmation preflight, then **closes both scopes before mutation**. It is not retained across input events; changed resources, prerequisites and daily limits are rechecked. The authoritative build, recap, invalidation, resolution guard, refresh and presentation sequence remains.
2. `SaveService.build_current_session_save_context` reuses the full save surface's current-session copy builders, returning only the two fields consumed by the action tooltip. It performs zero stored-summary inspections. Real Save/menu surfaces retain the full path; no autosave/write/restore/recovery work is skipped or deferred. Current tooltip strings remain exactly equal to the old full-surface values.
3. `OverworldShell._current_end_turn_warning` shares its normalized read calculations. It captures the old forecast **before** scope entry, because normalization after an external day change can refresh that field; it restores the original forecast before returning. Cancellation and stale-confirmation semantics remain read-only.
4. `EnemyAdventureRules._target_candidate_descriptors` creates one local knowledge snapshot for town/resource/artifact/encounter filtering. Previously each unseen target could rebuild sight sources by scanning towns, encounters and resource nodes again. The snapshot retains first-match memory expiry semantics and the same faction sight radii. Exploration and frontier sweeps similarly reuse the sight-source list within their read-only tile loop. No snapshot survives the call, movement, capture or memory changes; no targets, risk checks, scoring, paths or AI actions are removed.

`tests/large_town_turn_optimization_regression.py` compares descriptors and exploration plans against the unoptimized dynamic-lookup path across 36 scenario/faction combinations, with additional expiry/duplicate-memory, source-removal, stale-affordability, closed-read-scope and exact save-copy/zero-inspection checks. The main Large runner can enforce aggregate Town and End Turn timing ratios using `--require-improvement --compare instrumented`, in addition to twelve full session comparisons. No timing or gameplay fields are discarded from the state comparison.

## Profiling-stage validation evidence

Completed measurements: three naturally affordable purchases and three successive End Turns in each of the baseline, detailed and instrumented runs; signature and 2961-record generated save/restore preservation pass. All twelve complete instrumented session trees exactly equal baseline, with **no ignored fields**, including enemy decisions, resources, town development and day progression (`state_parity.json`). The read-only scoped/unscoped catalog probe also passes exact catalog/session equality.

Additional validation under `.artifacts/large_town_build_end_turn_20260905/validation/`:

- `town_limit.log`: PASS, independent per-town/day construction limits and next-day availability.
- `town_catalog.log`: PASS, live construction/muster catalog controls at 1280x720 and 1920x1080 plus six-faction auxiliary cases. Rendered via Xvfb with profiling disabled.
- `end_turn_confirmation.log`: PASS, cancellation, stale requests, risk confirmation, same-stack routing/focus safety and low-risk one-click behavior, profiling disabled.
- `repo.log`: `python3 tests/validate_repo.py` — `VALIDATION PASSED`; Python compilation and `git diff --check` pass.
- `linux-final/report.json`, `windows-final/report.json`: PASS, serial exports, startup, native sidecars and all package-content checks. Both PCKs are **248370060 bytes**, 1629940 below the unchanged 250000000-byte ceiling.
- `linux-generated-flow/live_validation_report.json` and `windows-final/generated-flow/live_validation_report.json`: PASS, actual packaged generated setup → Overworld → player Town. Windows exercised through fresh Wine prefixes, not native Windows hardware certification.

The first Linux export attempt failed because the test's isolated `XDG_DATA_HOME` hid installed export templates. The successful final serial runs retained isolated save data while exposing the existing templates through a temporary symlink. This was a validation-environment correction, not a game or template change. Existing renderer shutdown RID warnings remain outside this profiling scope.

The entries above are retained profiling-stage evidence, not substituted for validation of changed runtime code.

## Final optimization measurements

Final source is the runtime patch committed with this report, based on profiling commit `b628ec3`. Run `verified_final` measured that patch before commit; the report's `revision` field therefore names its base HEAD, not an unchanged baseline. The final replay command was:

```sh
python3 tests/large_town_build_end_turn_profile.py --label verified_final --detail --compare instrumented --require-improvement
```

`verified_final/report.json`: PASS, including all twelve exact session-tree comparisons against the preserved instrumented control, matching actions/days, signature `7362cf00`, and all 2961 generated source records through day-four save/restore. No fields were ignored. Final peak child RSS: 1706580 KiB. Earlier intermediate `town_optimized`, `visibility_optimized` and `optimized_final` runs also retained exact state equality; they are not substituted for this final run.

Seconds, same seed and purchases as the baseline table:

| Day | Town entry | Ledger open | Select plan | Confirm callback | Confirm to usable controls | End Turn request + confirm |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1.93 | 0.94 | 0.97 | 2.36 | 3.17 | 6.36 |
| 2 | 1.80 | 0.77 | 0.74 | 2.18 | 2.99 | 8.00 |
| 3 | 2.01 | 0.95 | 0.91 | 2.45 | 3.30 | 11.20 |

The aggregate measured construction interaction (ledger open + selection + confirmation through usable controls) fell from **55.399 to 14.743 seconds across three purchases: 73.4% less waiting**. Full End Turn fell from **36.170 to 25.565 seconds across three turns: 29.3% less waiting**. This is the matched three-day CPU fixture, not a claim about every save, late-game turn, machine or rendered frame rate.

Confirmation now spends 0.69–0.88 seconds in one fresh preflight. The actual build mutation remains 0.23–0.30 seconds; Town refresh remains approximately 0.81–0.82 seconds on all three days instead of growing to 3.94 seconds after autosaves exist. End Turn warning preparation is 0.27/0.30/0.41 seconds. Simulation is 3.61/5.18/8.08 seconds and autosave is 1.58/1.56/1.62 seconds; the save is still synchronous and included. Later-day simulation remains a significant cost and warrants future profiling rather than claiming instantaneous turns.

## Optimization validation and remaining limits

Evidence root: `.artifacts/large_town_build_end_turn_20260905/optimization_validation/` unless stated otherwise.

- `town_build_per_town_turn_limit_report.log`, `town_build_muster_popup_catalog_smoke.log`: PASS, per-town/day progression and rendered live ledger/recruitment controls at 1280x720 and 1920x1080, plus six-faction cases.
- `overworld_end_turn_confirmation_runtime_report_recheck.log`: PASS, cancellation, stale state, risk confirmation and one-click paths. The first run caught scope-entry forecast normalization happening before the old forecast was captured; the runtime fix captures it first, and the unchanged strict test then passes.
- `ai_known_world_memory_report_recheck.log`, `ai_hero_task_live_target_selection_report_recheck.log`, `ai_hero_task_live_turn_execution_report_recheck.log`: PASS, current/recent knowledge, memory expiry, post-move target/route occupancy, reservations and actual task execution.
- `save_transactional_commit_regression_recheck.log`: PASS. `generated_large_town_explicit_save_surface_regression_headless_confirm.log`: PASS, exact payload/copy/recovery, physical slot selection, cancellation, successful writes, and precommit/after-backup failure injection. No thresholds were relaxed. Earlier Xvfb input timing exceeded its one-second budget at 1340 ms; the first headless refresh was 1044.557 ms. An unchanged isolated headless rerun passed at 893 ms selection and 971.409 ms refresh. These narrow host-sensitive budgets have little margin; the earlier failures remain recorded.
- `named_save_files_regression.log`: PASS, all four live Save routes, named-file storage beyond three files, explicit overwrite, deletion, legacy compatibility and recovery. Actual Save browser captures at 1920x1080 and 1280x720 were visually inspected; file entry, list, confirmation text and Save/Cancel controls remain accessible. Captures/report are under `.artifacts/visual_performance_file_saves_review/`.

- `focused_regression.log` and `../regression/report.json`: PASS, 36 scenario/faction reference comparisons plus memory/source freshness, stale affordability, closed read scopes, exact current-save copy and zero summary-inspection checks. Reference generation fails if it cannot isolate and disable the optimized input; it cannot silently compare the optimized method with itself.
- `repo.log`: `python3 tests/validate_repo.py` — `VALIDATION PASSED`. The construction-order validator accepts the new optional preflight parameter and retains its build/recap/refresh/presentation ordering assertions. Python compilation and `git diff --check` pass.
- `linux/report.json`, `windows/report.json`: PASS, serial fresh exports, startup, required native sidecars and content exclusions. Both PCKs are **248372668 bytes**, 1627332 below the unchanged 250000000-byte ceiling. Validation retained isolated save data and exposed existing export templates through a temporary symlink.
- `linux-generated-flow/live_validation_report.json`, `windows/generated-flow/live_validation_report.json`: PASS, actual packaged setup → generated Overworld → player Town. Windows uses fresh Wine prefixes; this is not native Windows hardware certification. These headless entry checks do not claim rendered screenshots.

Existing renderer texture-RID shutdown warnings and whole-game release certification remain outside this performance change. Remaining End Turn latency is measured above, not concealed by deferred work. The earlier host-sensitive legacy Save UI budget failures are retained even though the final unchanged headless regression passes.
