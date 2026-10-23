# Game Setup Test Retirement

Owner decisions D-e and D-g, 2026-10-23 (`docs/native-rules-engine-transition.md`, Phase 7): the tests that call the GDScript map generator or the private setup functions that slice 7.11 deletes are retired by the `docs/rmg-test-retirement.md` process. They were retired on 2026-10-23 with 7.11 (`native-rules-phase7-11-setup-20261023`).

## Why

Game setup runs native. Slice 7.11 moved `ScenarioSelectRules`' setup, options, template catalog and maps-folder functions, `NativeRandomMapPackageSessionBridge`, `GeneratedRewardRules`, `GeneratedNeutralEncounterRules`, `NativeSceneryRules.is_scenery` and `validate`, and `RandomMapGeneratorRules.normalize_config` to C++ (`src/gdextension/rules/core/port/`, the human table in `human_registry.cpp`). The 57 that the game, the tools and the tests still call are thin wrappers over their port. The other GDScript bodies are gone.

By D-g, `RandomMapGeneratorRules.generate` (the GDScript generator, 503 functions) and the save path that rebuilt a map with it are deleted: every game since the map packages starts from a native package, and so do all five owner save copies (D9). A save from before the packages is refused with a message. `ScenarioFactory`'s generated-draft sessions, which only that generator fed, went with it, and so did the GDScript `MapPackageService`, `MapDocument` and `ScenarioDocument`, the fallback for a game without the native library.

The tests below ran the GDScript generator, built a session from its payload, or called a deleted private function. Setup is covered by:
- the core suite: `random_map_seeded_generator_core_report` (same seed, same map, same new game, through the native generator and the bridge), `random_map_small_2p_launch_report`, `random_map_final_writeout_export_save_schema_report` (a new game's package save schema and restore) and `generated_start_hero_growth_seed_report`. The first and the third were rewritten onto the native generator; the fourth lost its check of the deleted generated-draft session;
- the 7.11 check: new games from fixed seeds give the same session as main's, at every size and player count, with and without water and underground.

Git history keeps the retired tests.

## Retired (17 tests)

The GDScript generator's passes and reports: `random_map_connection_guard_materialization_report`, `random_map_decoration_density_pass_report`, `random_map_monster_reward_bands_report`, `random_map_object_footprint_catalog_report`, `random_map_object_pool_value_weighting_report`, `random_map_resource_encounter_fairness_report`, `random_map_roads_rivers_writeout_report`, `random_map_template_catalog_grammar_report`, `random_map_terrain_transit_semantics_report`, `random_map_town_mine_dwelling_placement_report`, `random_map_validation_batch_retry_report` and `random_map_water_underground_transit_gameplay_report`, with the fixtures `tests/fixtures/random_map_validation_batch_cases.json` and `random_map_large_batch_parity_stress_cases.json`.

A session from the GDScript generator's payload: `random_map_scenario_load_smoke`, `thornwake_commander_curated_portrait_report`, and the richness and visual-inspection scripts with their Large scene (`random_map_homm3_parity_richness_report`, `random_map_homm3_parity_visual_inspection_report`, `random_map_homm3_parity_large_visual_inspection_report`), which `docs/rmg-test-retirement.md` had kept for that scene.

A deleted private function: `maps_folder_package_browser_integration_report` (`ScenarioSelectRules._persist_and_load_generated_packages`).

`tests/full_play_validation_suite.py` no longer lists `random_map_object_pool_value_weighting_report`.

## Kept

- `map_package_api_skeleton_report` tests the native `MapPackageService` only; the GDScript fallback it accepted is gone.
- `creature_banks_report` checks unit idle art itself instead of calling `GeneratedNeutralEncounterRules._company_art_ready`.
- The test helpers `BalanceRegressionReportRules` and `HeadlessSimulationHarnessRules`, which their reports run on authored scenarios (quarantined), start their generated game from the native setup (`ScenarioSelectRules.build_random_map_skirmish_setup` and `start_random_map_skirmish_session_from_setup`) instead of the GDScript generator and `ScenarioFactory.create_generated_*`. The balance report's generated-map fairness sample now reads as deferred: the native payload has no GDScript fairness report.
