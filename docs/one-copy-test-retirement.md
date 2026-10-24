# One-Copy Test Retirement

Owner decision D-e, 2026-10-23 (`docs/native-rules-engine-transition.md`, Phase 7): the tests that call GDScript bodies Phase 7 deletes are retired by the `docs/rmg-test-retirement.md` process. They were retired on 2026-10-24 with slice 7.15 (`native-rules-phase7-15-one-copy-20261023`), at Phase 7's last merge.

## Why

Every rule Phase 7 ported has one copy, its C++ port. Merge 4 made the 416 entries of slices 7.8, 7.9, 7.13 and 7.15 NATIVE: their GDScript functions are thin wrappers over `HumanEngine.native`, and their `__gd` bodies are gone. It also deleted 1,320 GDScript functions (23,734 lines) that only each other and the tests reached. 113 tests and one test harness, `tests/support/HeadlessSimulationHarnessRules.gd`, called those bodies directly. The tests that load, extend, import or run one of them are retired with them.

The rules are covered by:
- the parity checks, native against main: `tools/rules_parity.py --human` (eight seeds), `--editor` (three seeds) and the six AI seeds;
- the core suite. What it calls stays, as thin wrappers;
- `battle_sim_cli` and `match_sim_cli`, the native port outside Godot.

Git history keeps the retired tests.

## Retired (166 tests)

The map, its sites and the hero's moves (`OverworldRules`): `ai_player_rules_report`, `all_town_composition_regression`, `battle_resolution_autosave_failure_route_safety_regression`, `eight_guarded_route_gates_report`, `eight_neutral_dwelling_musters_report`, `eleven_roads_objectives_report`, `generated_guard_approach_regression`, `generated_site_footprint_dressing_report`, `graphical_usability_regression`, `hero_guard_zone_report`, `neutral_dwelling_claimed_landmark_report`, `overworld_actor_readability_regression`, `overworld_biome_surface_regression`, `overworld_consumed_site_collision_regression`, `overworld_generated_large_town_scale_runtime_report`, `overworld_object_scale_regression`, `overworld_raster_terrain_blocker_mass_report`, `overworld_recruitment_cutout_probe`, `overworld_road_junction_report`, `overworld_rope_lift_live_transit_report`, `overworld_route_arcane_cutout_probe`, `overworld_scenery_pickup_readability_report`, `overworld_visual_smoke`, `runtime_market_cap_persistence_report`, `seven_minor_guarded_caches_report`, `single_faction_towns_regression`, `six_horizon_capstone_monuments_smoke`, `six_major_vault_unsealing_report`, `ten_land_transit_network_report`, `terrain_blocking_town_capture_interaction_regression`, `test_town_embercourt_sequence`, `three_creature_bank_forts_report`, `town_battle_visual_smoke`, `town_build_muster_popup_catalog_smoke`, `town_capital_project_identity_runtime_report`, `town_development_runtime_balance_report`, `town_economy_resource_ui_surface_report`, `town_logistics_read_scope_regression`, `town_market_popout_report`, `town_mireclaw_variant_regression`, `town_rare_import_regression`, `town_unique_building_runtime_payoff_report`.

The computer players' commanders and raids (`EnemyAdventureRules`): `ai_army_capacity_regression`, `ai_commander_entry_projection_regression`, `ai_hero_task_live_turn_execution_report`, `ai_hero_task_state_normalizer_preservation_report`, `ai_known_world_memory_report`, `ai_raid_assault_grouping_report`, `artifact_dwelling_reward_execution_report`, `artifact_guarded_site_reward_execution_report`, `artifact_pickup_source_execution_report`, `artifact_shrine_reward_execution_report`, `generated_full_match_guarded_continuation`, `overworld_enemy_commander_sprite_runtime_report`, `overworld_enemy_route_closure_feedback_report`, `overworld_resource_assault_victory_return_feedback_report`, `rmg_exploration_regression`, `six_faction_command_regalia_runtime_report`.

Battle setup and aftermath (`BattleRules`): `battle_controller_board_navigation_smoke`, `battle_intent_forecast_report`, `targeting_commit_regression`.

Towns (`TownRules`, `TownDevelopmentRules`): `overworld_route_tooltip_smoke`, `town_ai_services_regression`, `town_building_panel_report`, `town_civic_art_regression`, `town_construction_screen_report`, `town_creature_upgrades_regression`, `town_development_regression`, `town_hall_art_regression`.

Artifacts (`ArtifactRules`): `artifact_battle_salvage_execution_report`, `artifact_set_faction_content_report`, `artifact_set_runtime_effects_report`, `artifact_source_reward_report`, `artifact_taxonomy_schema_report`, `creature_banks_report`, `faction_artifact_set_runtime_report`, `hero_exchange_screen_report`, `hero_field_rendezvous_artifact_transfer_report`, `hero_field_rendezvous_spell_sharing_report`, `town_hero_review_fixes_regression`, `usability_expansion_regression`.

Heroes and their progression (`HeroCommandRules`, `HeroProgressionRules`): `army_capacity_regression`, `battle_entry_transition_report`, `five_faction_roster_final_nine_curated_portrait_report`, `hero_level_up_roll_display_report`, `overworld_faction_hero_sprite_runtime_report`, `overworld_hero_cutout_probe`, `overworld_movement_feedback_report`, `overworld_town_vision_command_roster_report`, `recruitment_logistics_regression`, `six_faction_roster_adepts_curated_portrait_report`, `six_faction_roster_lieutenants_curated_portrait_report`, `six_faction_roster_officers_curated_portrait_report`, `six_faction_roster_sages_curated_portrait_report`, `six_faction_roster_scholars_curated_portrait_report`, `six_faction_roster_specialists_curated_portrait_report`, `town_command_entry_regression`, `town_garrison_rows_report`.

Spells (`SpellRules`): `seven_school_signature_spellbook_smoke`.

Scenario state, objectives and scripts (`ScenarioRules`, `ScenarioScriptRules`, `ScenarioFactory`): `campaign_completion_persistence_atomicity_regression`, `scripted_reinforcement_retention_regression`.

Other rules (dwellings, mines, transit, water travel, difficulty, player identity): `battle_retaliation_playback_regression`, `generated_rival_objective_regression`, `menu_and_turn_readability_regression`, `native_rmg_end_to_end_runtime_boundary_report`, `overworld_control_flags_regression`, `portal_networks_report`, `rare_mines_regression`, `resource_bar_daily_income_report`, `test_overworld_ground_materials`, `test_overworld_object_density`, `unified_mines_regression`, `water_travel_report`.

Built on a retired test: `ai_multi_scenario_recruitment_delivery_report`, `economy_town_goal_scorecard_report`, `headless_simulation_harness_report`, `large_town_turn_optimization_regression`, `overworld_animation_readability_regression`, `overworld_artifact_cutout_probe`, `overworld_cohesive_biome_blocker_mass_report`, `overworld_command_cutout_probe`, `overworld_contract_cutout_probe`, `overworld_cutout_batch_regression`, `overworld_final_cutout_probe`, `overworld_living_scenery_regression`, `overworld_remaining_encounter_cutout_probe`, `overworld_remaining_site_cutout_probe`, `overworld_training_cutout_probe`, `packaged_all_town_composition_regression`, `packaged_embercourt_town_overlap_regression`, `packaged_menu_and_turn_readability_regression`, `packaged_overworld_animation_readability_regression`, `packaged_overworld_cutout_batch_regression`, `packaged_overworld_living_scenery_regression`, `packaged_overworld_resource_strip_regression`, `packaged_recruitment_logistics_regression`, `packaged_targeting_commit_regression`, `packaged_town_building_outline_regression`, `packaged_town_roster_double_click_regression`, `raw_pickup_shine_regression`, `rmg_blocker_variety`, `seven_final_neutral_dwelling_musters_report`, `sixteen_neutral_dwelling_musters_report`, `strategic_ai_baseline_kpi_report`, `strategic_ai_long_run_seed_matrix_report`, `test_generated_full_match_quality`, `test_overworld_cutout_save_fixture`, `test_town_brasshollow_faction`, `test_town_embercourt_variants`, `test_town_mireclaw_variants`, `test_town_sunvault_faction`, `test_town_thornwake_faction`, `test_town_veilmourn_variants`, `town_biome_art_regression`, `town_biome_release_regression`, `town_brasshollow_faction_regression`, `town_building_outline_regression`, `town_embercourt_variant_regression`, `town_frontier_status_regression`, `town_logistics_legacy_balance_control`, `town_sunvault_faction_regression`, `town_thornwake_faction_regression`, `town_upgrade_actions_regression`, `town_upgrade_embercourt_regression`, `town_veilmourn_variant_regression`, `waystone_chest_regression`.

## Edited, not retired

- `town_scene_layer_regression` and `overworld_map_object_cutout_regression` read a resource site's controller through `PlayerIdentityRules.resource_controller_id`. That is the public function the deleted `OverworldRules._resource_node_matches_controller` called. 21 tests run on these two through `packaged_town_scene_layer_regression` and `battle_readability_regression`, and so do `tools/review_upgraded_creature_completion.py`, `tools/review_nonupgraded_creature_completion.py` and `tools/rmg_guard_space_audit.py`.
- `tests/full_play_validation_suite.py` no longer lists the 12 retired tests it ran.
- `tools/run_headless_balance_harness.py` no longer runs `headless_simulation_harness_report`.

## Packaged modes left broken

Seven tests stay for their own mode. Run with `--platform`, each imports the retired `packaged_menu_and_turn_readability_regression`: `battle_pose_playback_regression`, `combat_vfx_regression`, `generated_overworld_quality_regression`, `hero_sheet_regression`, `rmg_town_supply_removal_regression`, `spell_effect_variety_regression` and `spellbook_regression`. Release packaging waits until the owner prepares a release.

## Rules

- A rule change goes into the C++ port only (AGENTS.md).
- Do not restore retired tests. Write a new test against the public functions or the native port instead.
