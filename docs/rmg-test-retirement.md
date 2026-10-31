# Random-Map Test Retirement

Decision, 2026-10-07, made with the owner's delegation: the random-map tests written for the generator before the native H3MapEd state-chain rewrite (`d866370d9`, 2026-06-19) are retired. Plan id: `tests-rmg-retirement-20261007`.

## Why

The native generator was rewritten in June and July to reproduce H3MapEd byte for byte across a supported matrix of 24 setups (Small to Extra Large, land, normal water and Islands, one or two levels); anything else fails closed (PLAN.md, `native-rmg-source-order-h3maped-alignment-10184`). Its `full_parity_claim` covers only that matrix.

On 2026-10-07 all 104 random-map test scenes ran on Windows with isolated profiles: 29 passed, 75 failed. 71 of the failures had not been edited since before the rewrite. They checked the earlier approximate generator, so their failures said nothing about the current game. They were removed instead of rewritten; git history keeps them. Tests built on authored scenarios were not used for this (`docs/authored-scenarios-obsolete.md`).

The core self-test `bin/h3maped_rmg_core_selftest` still passes. For the render test's map, the 2026-09-18 build and today's build produce the same payload from the same input.

## Retired (73 tests)

Removed or renamed native API: the capabilities, phases or methods they call no longer exist.
`native_random_map_foundation_report`, `native_random_map_terrain_grid_report`, `native_random_map_zone_player_starts_report`, `native_random_map_road_river_report`, `native_random_map_object_placement_report`, `native_random_map_town_guard_report`, `native_random_map_validation_provenance_report`, `native_random_map_gdscript_comparison_report`, `native_random_map_decoration_generation_report`, `native_random_map_extension_profile_report`, `native_random_map_full_parity_gate_report`, `native_random_map_guard_reward_package_adoption_report`, `native_random_map_homm3_guards_rewards_monsters_report`, `native_random_map_homm3_mines_resources_report`, `native_random_map_homm3_object_placement_pipeline_report`, `native_random_map_homm3_roads_rivers_connections_report`, `native_random_map_homm3_runtime_zone_graph_report`, `native_random_map_homm3_terrain_island_shape_report`, `native_random_map_homm3_validation_adoption_gates_report`, `native_rmg_small_h3maped_negative_validator_report`, `native_random_map_disk_package_startup_report`, `native_rmg_medium_h3maped_corpus_audit_report`, `native_rmg_small_h3maped_port_boundary_report`, and the non-runnable `archived_native_rmg_small_h3maped_port_boundary_report_20260513`.

Old status and scope contracts: they expect statuses such as `owner_compared_translated_profile_supported`, require that parity stays unclaimed, or use translated template ids and replay fields the native launch no longer records.
`native_random_map_package_session_adoption_report`, `native_random_map_auto_template_batch_report`, `native_random_map_broad_template_generation_report`, `native_random_map_broad_translated_catalog_route_closure_sweep_report`, `native_random_map_broad_translated_catalog_islands_route_closure_sweep_report`, `native_random_map_broad_translated_catalog_underground_route_closure_sweep_report`, `native_random_map_catalog_quality_report`, `native_random_map_gdscript_port_audit_report`, `native_random_map_homm3_generator_data_model_report`, `native_random_map_homm3_local_distribution_report`, `native_random_map_homm3_re_reward_value_distribution_report`, `native_random_map_owner_normal_water_underground_package_report`, `native_random_map_package_object_only_breadth_report`, `native_random_map_package_session_authoritative_replay_report`, `native_random_map_package_surface_topology_report`, `native_random_map_supported_underground_terrain_count_report`, `native_random_map_template_spec_filtering_report`, `native_random_map_town_spacing_regression_report`, `native_random_map_zone_choke_regression_report`, `native_rmg_medium_h3maped_runtime_acceptance_report`, `native_rmg_medium_h3maped_template_selection_report`, `native_rmg_small_h3maped_template_selection_hard_lock_report`, `native_rmg_small_h3maped_public_template_matrix_report`, `native_rmg_small_h3maped_runtime_corpus_acceptance_report`, `native_random_map_homm3_uploaded_small_comparison_report`, `random_map_medium_land_start_coverage_regression_report`, `random_map_skirmish_ui_save_replay_report`.

Evidence outside the repository: H3M samples and HoMM3 tables at paths on the old Linux workspace (`/root/.openclaw/...`) or `res://maps/small3playermap*.h3m`.
`native_random_map_homm3_fill_coverage_report`, `native_random_map_homm3_land_normalized_object_density_report`, `native_random_map_homm3_land_water_shape_report`, `native_random_map_homm3_re_identity_comparison_report`, `native_random_map_homm3_spatial_placement_comparison_report`, `native_random_map_homm3_uploaded_small_topology_report`, `native_rmg_small_h3maped_corpus_audit_report`, `native_random_map_production_parity_completion_audit_report`, `native_random_map_homm3_owner_corpus_coverage_report`.

Approximation-era quality floors and old generator contracts: density, choke and artifact minimums the source-exact generator does not promise, the replaced terrain renderer, the pre-H3M-mask interaction model, and the capture-a-town objective (generated maps now ask to defeat every rival).
`random_map_large_batch_parity_stress_report`, `random_map_zone_layout_water_underground_report`, `random_map_template_filtering_assignment_report`, `random_map_playable_materialization_runtime_report`, `random_map_generated_small_distribution_report`, `random_map_terrain_town_road_constraints_report`, `random_map_generated_visual_path_regression_report`, `random_map_generated_object_footprint_interaction_report`, `random_map_homm3_parity_richness_report`, `random_map_default_seed_objective_regression_report`, and the small-mode scene of `random_map_homm3_parity_visual_inspection_report`. The visual-inspection and richness scripts stay because the passing Large scene uses them.

Old route and guard play logic: routes stop at guard zones since 2026-09-18 and map orders take two presses since 2026-09-12.
`native_rmg_small_h3maped_guard_engagement_report`, `native_rmg_small_h3maped_guarded_victory_playtest_report`. Guard approach and full generated matches are covered by `tests/generated_guard_approach_regression.py` and `tests/generated_full_match_quality.py`.

## Kept

The 32 remaining random-map scenes all pass on Windows: `native_rmg_end_to_end_runtime_boundary_report`, `native_random_map_homm3_re_object_table_proxy_report` and 30 `random_map_*` reports (menu, setup, launch, retry, save schema, rendering, roads, transit, fairness and placement). The Python checks `test_rmg_*`, `rmg_evidence_storage_test`, `rmg_fast_audit_h3m_anchor_regression` and `test_rmg_exploration_contract` pass on Windows. `rmg_exploration_regression`, `rmg_town_supply_removal_regression` and `rmg_blocker_variety` use the Linux probe harness.

Three later tests were updated rather than retired: `random_map_live_overworld_render_move_report` (fixture counts for today's default launch; its move goes through `OverworldShell.validation_try_progress_action`, which now confirms the order), `random_map_post_open_tail_timing_report` (the runtime scenario record is saved once since `7689b1b0a`), and `random_map_town_mine_dwelling_placement_report` (the report-only fairness model may warn).

`scripts/build_map_persistence_windows.bat` and `src/gdextension/README.md` now run `map_package_api_skeleton_report` and `random_map_seeded_generator_core_report` after a native build, with an isolated profile on Windows.

## Known gap

`tests/economy_town_goal_scorecard_report.py` drew generated-map town-economy pacing from the retired adoption report. Its targets (for example, all seven tiers by day 22) predate the October economy changes and had produced no data since June. That section was removed. There is no current pacing check for generated maps; new targets are a balance decision.

## Rules

- A random-map test that fails should be fixed or retired in the commit that changes the behavior it checks.
- Do not restore retired tests. Write a new test against current behavior instead.
- Native RMG generator changes still follow `docs/lessons-learned.md`.
