# Battle Test Retirement

Decision D6, 2026-10-20 (`docs/native-rules-engine-transition.md`): tests that call private battle functions the port deletes are retired by the `docs/rmg-test-retirement.md` process. They were retired on 2026-10-23 with Phase 2d (`native-rules-phase2-d-exit-20261022`), which deleted the GDScript copies of the battle port.

## Why

Battles run native. Phase 2d deleted the GDScript bodies of the 725 functions of the battle registry (`src/gdextension/rules/core/port/registry.cpp`) and the `HEROES_NATIVE_BATTLE` switch. The 232 that the game, the tools and the tests still call are thin wrappers over their native port. The other 493 are gone, with 198 GDScript functions, constants and statics only they used, including all of `BattleDamageRules.gd`.

The tests below called those private functions directly, preloaded `BattleDamageRules.gd`, or ran on a harness that did. Battles are covered by:
- the parity corpus: `tools/rules_parity.py` on the six seeds, native against main;
- the core suite: `battle_deterministic_rng_state_report` and `battle_ai_flow_report`. They keep the private functions they call, as thin wrappers;
- `battle_sim_cli`, which `arena.py` and `tune.py` run.

Git history keeps the retired tests.

## Retired (46 tests)

Board, movement and turn order: `battle_layout_smoke`, `battle_screen_report`, `core_systems_regression_smoke`, `battle_melee_approach_report`, `battle_board_obstacles_report`, `battle_battlefield_art_report`, `battle_wait_turn_order_report`, `battle_unit_body_runtime_regression`, `battle_faction_fast_balance_benchmark`.

Damage, stack health and forecasts: `battle_cursor_forecast_report`, `combat_consequence_preview_regression`, `battle_plates_details_report`, `battle_stack_health_normalize_report`, `battle_stat_scaling_report`, `unit_production_readiness_report`.

Unit abilities and town upgrades: `unit_ability_runtime_report`, `town_upgrade_brasshollow_regression`, `town_upgrade_sunvault_regression`, `town_upgrade_thornwake_regression`, `town_upgrade_veilmourn_regression`.

Spells and hero casting: `battle_spell_effects_report`, `battle_spell_wounded_target_report`, `magic_battle_spell_behavior_report`, `magic_ai_valuation_casting_hooks_report`, `battle_hero_casting_report`.

Battle AI: `battle_ai_withdrawal_decision_report`, `battle_autoplay_tactical_order_report`, `battle_quick_resolve_focus_report`.

Battle setup and aftermath: `artifact_equip_runtime_effects_report`, `hero_specialty_catalog_report`, `visit_buildings_report`, `town_defender_clarity_regression`, `generated_neutral_encounter_regression`, `creature_dwellings_report`, `hero_hire_army_level_report`, `hero_level_up_regression`, `native_guarded_portal_regression`, `post_battle_report_runtime_report`.

Built on a retired test: `four_elder_wild_recruitment_sanctuaries_smoke`, `six_elder_wilds_smoke` (scene and runner) and `two_elite_neutral_dwellings_report` ran `unit_ability_runtime_report`'s ability probe. `magic_prism_bastion_root_countercontrol_regression` ran a case of `magic_ai_valuation_casting_hooks_report`. `packaged_combat_consequence_preview_regression` and `packaged_town_defender_clarity_regression` ran their unpackaged tests in a package.

Not runnable before: `town_faction_mechanics_regression` called private battle functions on an undefined `Battle` alias.

`tests/full_play_validation_suite.py` no longer lists `post_battle_report_runtime_report` and `four_elder_wild_recruitment_sanctuaries_smoke`.

## Kept

`battle_readability_regression` is the runner for about 30 other tests, so it was updated instead of retired. Its battle checks measure distances with `BattleFootprint.distance` and a local hex step, not the deleted `_hex_distance` and `_can_make_melee_attack`. Its own battle fixture fails, and did before Phase 2d: since battles went native, `create_battle_payload` refuses the fixture's enemy config, which has no player records, and the battle table has no GDScript fallback.

## Known gap

No test checks single unit abilities, spells or town-upgrade battle effects in isolation any more. A wrong ability shows up only through the parity corpus, the arena or a played game.

## Rules

- A battle change goes into the C++ port only, with one six-seed check of native mode against main (AGENTS.md).
- Do not restore retired tests. Write a new test against public battle functions or the native port instead.
