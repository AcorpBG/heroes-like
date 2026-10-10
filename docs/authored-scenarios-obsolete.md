# Authored Maps, Scenarios And Campaigns Are Obsolete

Owner decision, 2026-10-05: every authored map and scenario is obsolete and needs revisiting. The owner will redo them completely. Until the owner selects that rework, put no effort into them.

**Archived, 2026-10-08 (owner decision).** The catalogs moved to `archive/authored-scenarios-2026-10-08/` (`scenarios.json`, `campaigns.json`, `terrain_layers.json` and the `tools/author_*.py` scripts; see its README). Their `domain_status` is `archived_*`, so the game offers none of them: the Skirmish list has no authored fronts and the main menu shows Campaign as "Coming soon". `ContentService` still loads them by id, so tests keep using them as hidden setups and old saves still load. This replaces the rule below that kept the roster playable; paths in this document that say `content/scenarios.json`, `content/campaigns.json` or `tools/author_*.py` now live in the archive.

Plan id: `content-authored-scenarios-obsolete-20261005` in `PLAN.md` (paused until the owner selects the rework).

## Covered

- All 299 authored scenarios in `content/scenarios.json`, including their embedded maps (terrain, towns, placements, encounters, sites), starts, objectives, scripts, difficulty and encounter balance.
- All 25 campaigns in `content/campaigns.json`, which chain those scenarios, and art made only for them (campaign chapter seals and arc emblems).
- The tools that write them: `tools/author_charterless_compact_campaign.py`, `tools/author_eight_commander_doctrine_expeditions.py`, `tools/author_eight_commanders_proving_roads.py`, `tools/author_named_rival_banner_challenges.py`, `tools/author_overworld_strategic_density_10230.py`, `tools/author_overworld_town_environs_10236.py`, `tools/author_six_frontier_mythic_habitats.py`, `tools/author_six_grand_arcanum_convocations.py`, `tools/author_six_marchland_local_retinues.py`, `tools/author_six_marchland_retinue_heirloom_trials.py`, `tools/author_six_marchland_seats.py`, `tools/author_six_marchland_warworks.py`, `tools/author_six_sealed_companies_campaign.py`, `tools/author_six_uncrowned_sovereign_roads.py`, `tools/author_ten_commander_dominion_sieges.py`, `tools/author_twelve_command_relic_marches.py`, `tools/author_twelve_marchland_grand_route_operations.py`, `tools/author_twelve_marchland_warband_musters.py`, `tools/author_veteran_company_musters.py`, `tools/author_wild_atlas_accord_campaign.py`.
- Docs and reports about the authored roster, such as `docs/*active-scenario*` and the campaign and chapter reports. They are history, not targets.
- The authored-scenario and campaign sections in `PLAN.md` and their rows in `ops/progress.json`. They record what was built, not work to continue.

## Not covered

- Generated maps: the native random map generator, generated scenarios, `.amap`/`.ascenario` packages, and the tracked `maps/manual-strict_small_*` fixtures.
- Shared content definitions, even where an authored batch first added them: factions, heroes, units, towns, buildings, artifacts, spells, encounters, map objects, resource sites, neutral dwellings, art and audio. Generated maps and live systems use them.
- The runtime authored scenarios run on: `ScenarioFactory.gd`, `ScenarioRules.gd`, `ScenarioScriptRules.gd`, `ScenarioSelectRules.gd`, `CampaignRules.gd`, `CampaignProgression.gd`, save/load and the map editor. Generated maps use the same code, so keep it working.

## Rules

- Do not add, extend, fix, retune, rebalance, re-art or re-validate authored scenarios or campaigns, and do not run `tools/author_*.py`. Do not select them as a slice.
- The tests and `tests/validate_repo.py` checks about authored scenarios and campaigns were deleted on 2026-10-10 (owner decision; see "Deleted checks" below). Do not restore them; the rework writes new ones on its own content.
- Leave the scenario and campaign data as it is. Since 2026-10-08 the archive hides the roster through its `domain_status` fields; do not make it playable again before the rework.
- Many system tests load an authored scenario only as a harness (about 350 test files, most of them `river-pass` or `ninefold-confluence`). Since 2026-10-10 they are quarantined: do not run them, repair them or use them to verify work. Verify with generated-map tests and `python tools/core_suite.py` (AGENTS.md "Validation budget"). When the rework replaces the authored content, a covered system that still needs a test gets one on a generated map.
- New work that needs a map uses a generated map.
- Open items about authored content are dropped, including the six twin-command scenarios that lost their starting Wayfarers Hall (`content-validator-findings-20261004`). Those six findings are the only errors `tests/validate_repo.py` reported when this hold started.

## Deleted checks

Owner decision, 2026-10-10: the obsolete checks were deleted instead of being left failing.

- 127 test scripts about the authored roster (batch and campaign smokes, chapter viability, roster economy and AI runways, balance of authored encounter placements), with their `.tscn` runners and the 31 Python wrappers that launched them. `tests/test_validation_artifact_lifecycle.py` went with them; it only covered those checks.
- 88 `tests/validate_repo.py` functions about authored scenarios and campaigns (the 85 listed here before, plus `validate_active_scenario_resource_availability_matrix`, `validate_active_scenario_town_start_economy` and `validate_six_faction_reserve_companies`), and the constants, helpers and `--require-historical-smoke-reports` option only they used.
- Checks in live `validate_repo` functions that read the text of a deleted test (for example the Ninefold road, fog and terrain-lighting pins).
- Their entries in `tests/full_play_validation_suite.py` (`--scripted-rewards`) and `tools/run_headless_balance_harness.py`.

The full lists are in the git history of this file and of the deletion commit. On the same worktree, `validate_repo.py` went from 885 errors to 128, with no new errors.

Later the same day the rest of the old `validate_repo.py` (about 68,000 lines, mostly pins on source and doc text) was replaced by a short content check that passes: content parses, ids and references resolve, art manifests cover every record, runtime files exist, scenes are wired. The mixed `validate_repo` functions listed below went with it.

## Mixed checks

These check shared definitions that are still live (sites, dwellings, landmarks, artifacts, spells, art) and also assert where an authored scenario places them. The definition checks stay valid; the authored-placement assertions are obsolete.

Test files under `tests/`:

```text
artifact_set_runtime_effects_report.gd
eight_guarded_route_gates_report.gd
eight_neutral_dwelling_musters_report.gd
eleven_roads_objectives_report.gd
faction_artifact_set_runtime_report.gd
faction_content_breadth_report.gd
five_scouting_structures_report.gd
four_elder_wild_recruitment_sanctuaries_smoke.gd
neutral_dwelling_claimed_landmark_report.gd
seven_final_neutral_dwelling_musters_report.gd
seven_minor_guarded_caches_report.gd
seven_school_signature_spellbook_smoke.gd
sevenfold_high_arcanum_smoke.gd
six_elder_wilds_smoke.gd
six_faction_command_regalia_runtime_report.gd
six_horizon_capstone_monuments_smoke.gd
six_horizon_citadels_smoke.gd
six_horizon_relic_commissions_smoke.gd
six_major_vault_unsealing_report.gd
six_progression_shrines_report.gd
six_repeatable_field_services_report.gd
sixteen_neutral_dwelling_musters_report.gd
systemic_encounter_landmark_runtime_report.gd
ten_land_transit_network_report.gd
three_creature_bank_forts_report.gd
two_elite_neutral_dwellings_report.gd
```

`tests/validate_repo.py` functions (deleted 2026-10-10 with the old validator):

```text
validate_eight_guarded_route_gates
validate_eight_neutral_dwelling_musters
validate_eleven_roads_objectives
validate_five_scouting_structures
validate_four_elder_wild_recruitment_sanctuaries
validate_live_faction_landmarks
validate_overworld_ten_land_transit_network
validate_recurring_encounter_landmarks
validate_recurring_resource_site_landmarks
validate_seven_final_neutral_dwelling_musters
validate_seven_minor_guarded_caches
validate_sevenfold_high_arcanum
validate_signature_encounter_landmarks
validate_six_elder_wilds
validate_six_horizon_capstone_monuments
validate_six_horizon_citadels
validate_six_major_vault_unsealing
validate_six_progression_shrines
validate_six_repeatable_field_services
validate_systemic_encounter_landmarks
validate_three_creature_bank_forts
validate_two_elite_neutral_dwellings
```
