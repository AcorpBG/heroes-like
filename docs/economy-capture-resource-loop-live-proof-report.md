# Economy Capture Resource Loop Live Proof Report

Status: passes for the selected economy loop.
Date: 2026-04-26.
Slice: `economy-capture-resource-loop-live-slice-10184`.

## Scope

This report covers only the selected Riverwatch signal-yard proof path in `river-pass`:

- `north_timber`
- `river_signal_post`
- `river_free_company`
- `river_pass_ghoul_grove`
- `river_pass_hollow_mire`
- `southern_ore`
- optional `eastern_cache`
- Riverwatch spend/recruit choice
- save/resume preservation

No production content JSON, runtime code, schema, validator, save migration, pathing, renderer, editor, AI, resource registry, `wood` to `timber` migration, rare-resource activation, market-cap overhaul, generated asset, or broad balance change was needed.

## Proof Method

The proof used current authored data and current Godot core systems. A temporary local Godot scene/script under `.artifacts/` exercised the exact path headlessly, then was removed before final changes. The generated observation JSON was written to `/tmp/heroes-economy-capture-proof.json` and checked with `python3 -m json.tool`.

The existing routed live validation harness was not used for this exact path because no existing flow deliberately visits `north_timber`, `river_signal_post`, `river_pass_hollow_mire`, `southern_ore`, optional `eastern_cache`, then makes the post-capture Riverwatch spend/recruit choice. The closest existing routed flows cover broader River Pass routing, town save/resume, `river_free_company`, encounters, and outcome paths, but not this selected economy proof sequence. Adding a new harness flow would be test/harness implementation and was outside the strict first-preference scope because the current rules/data already prove the loop.

Battle observations below force victory through current battle resolution rules to inspect economy state after the selected clears. This proves the economy path after the fights are cleared; it does not make a fresh tactical balance claim.

## Starting State

Scenario: `river-pass`, normal difficulty, skirmish launch.

Starting resources:

- `gold`: 1500
- `wood`: 4
- `ore`: 3

Starting army:

- `unit_river_guard`: 10
- `unit_ember_archer`: 5

Riverwatch state:

- Town placement: `riverwatch_hold`
- Town id: `town_riverwatch`
- Owner: `player`
- Built buildings: `building_town_hall`, `building_muster_yard`, `building_wayfarers_hall`
- Available recruits: `unit_river_guard: 9`

Starting Riverwatch orders:

- `building_market_square` is directly affordable at `gold 1000`.
- `building_stone_store` is directly affordable at `gold 900`, `ore 2`.
- `building_bowyer_lodge` is directly affordable at `gold 1200`, `wood 2`.
- `building_lantern_archive` is directly affordable at `gold 1100`, `wood 1`.
- `building_watch_barracks` is not initially buildable because it requires `building_stone_store`.
- `building_river_granary_exchange` is not initially buildable because it requires `building_market_square` and `building_stone_store`.
- `unit_river_guard` recruitment is available, with 9 available and all 9 directly affordable.

## Path Observations

`north_timber` / `site_timber_wagon`:

- Result: passed.
- Message: `Claimed Timber Wagon. Stores 150 gold, 2 wood.`
- Resources changed from `1500 gold, 4 wood, 3 ore` to `1650 gold, 6 wood, 3 ore`.
- Site state became `collected: true`, `collected_by_faction_id: player`, `collected_day: 1`.
- Observation: current live resource id is still `wood`, while player-facing text names Timber. No `timber` migration is needed for this proof.

`river_signal_post` / `site_ember_signal_post`:

- Result: passed.
- Message: `Secured Ember Signal Post. Stores 50 gold.`
- Resources changed from `1650 gold, 6 wood, 3 ore` to `1700 gold, 6 wood, 3 ore`.
- Site state became `collected: true`, `collected_by_faction_id: player`, `collected_day: 1`.
- Day advance after capture changed resources from `1700 gold, 6 wood, 3 ore` on day 1 to `2450 gold, 6 wood, 3 ore` on day 2.
- Day-2 message included `Field sites yield 20 gold.`
- Observation: persistent capture income is active and observable through current day-advance messages.

`river_free_company` / `site_riverwatch_free_company_yard`:

- Result: passed.
- Message: `Secured Riverwatch Free Company Yard. Stores 80 gold. Auxiliaries join the field army (+3 Ember Archer, +5 River Guard).`
- Resources changed from `2450 gold, 6 wood, 3 ore` to `2530 gold, 6 wood, 3 ore`.
- Army changed to `15 River Guard`, `8 Ember Archer`.
- Site state became `collected: true`, `collected_by_faction_id: player`, `collected_day: 2`.
- Day advance after capture changed resources from `2530 gold, 6 wood, 3 ore` on day 2 to `3570 gold, 7 wood, 4 ore` on day 3.
- Day-3 message included `Field sites yield 60 gold`, proving `river_signal_post` and `river_free_company` income together.
- Day-3 scripts also added the Riverwatch relief resources and recruits, and spawned/advanced Mireclaw pressure.
- Observation: `river_free_company` provides both immediate army value and persistent daily gold value.

`river_pass_ghoul_grove` / `encounter_ghoul_grove`:

- Result: passed after forced victory through current battle resolution rules.
- Battle payload was created for `encounter_ghoul_grove` with resolved key `river_pass_ghoul_grove`.
- Resources changed from `3570 gold, 7 wood, 4 ore` to `3820 gold, 7 wood, 4 ore`.
- `river_pass_ghoul_grove` was added to `resolved_encounters`.
- `pass_cleared` became true.
- The script hook uncovered `north_road_salvage` at `4,1`.
- Observation: clearing this low fight adds gold and opens the north-road salvage hook, so it is a meaningful route/timing choice rather than just a combat checkbox.

`river_pass_hollow_mire` / `encounter_hollow_mire`:

- Result: passed after forced victory through current battle resolution rules.
- Battle payload was created for `encounter_hollow_mire` with resolved key `river_pass_hollow_mire`.
- Resources changed from `3820 gold, 7 wood, 4 ore` to `4000 gold, 7 wood, 6 ore`.
- `river_pass_hollow_mire` was added to `resolved_encounters`.
- `mire_cleared` and `mire_cleansing_rewarded` became true.
- Observation: Hollow Mire already supplies `ore +2` before `southern_ore`, so the southern branch strongly reinforces ore availability.

`southern_ore` / `site_ore_crates`:

- Result: passed.
- Message: `Claimed Ore Crates. Stores 100 gold, 2 ore.`
- Resources changed from `4000 gold, 7 wood, 6 ore` to `4100 gold, 7 wood, 8 ore`.
- Site state became `collected: true`, `collected_by_faction_id: player`, `collected_day: 3`.
- Observation: the branch provides enough ore headroom for Riverwatch support and later military chains without changing shared town or resource-site data.

Optional `eastern_cache` / `site_waystone_cache`:

- Result: passed.
- Message: `Claimed Waystone Cache. Stores 400 gold.`
- Resources changed from `4100 gold, 7 wood, 8 ore` to `4500 gold, 7 wood, 8 ore`.
- Site state became `collected: true`, `collected_by_faction_id: player`, `collected_day: 3`.
- Observation: the optional cash bridge is reachable in the current rule path and gives enough margin for a build plus recruitment.

## Town Spend And Recruit Choice

Before spending, Riverwatch had `4500 gold`, `7 wood`, and `8 ore` after the optional cache path. The selected spend was `building_bowyer_lodge` because it demonstrates that the `north_timber` wood pickup and captured income can convert into a military unlock without new schema work.

Build result:

- Action: `building_bowyer_lodge`.
- Result: passed.
- Message: `Built Bowyer Lodge in Riverwatch Hold.`
- Resources changed from `4500 gold, 7 wood, 8 ore` to `3300 gold, 5 wood, 8 ore`.
- Riverwatch recruits after build: `unit_ember_archer: 6`, `unit_river_guard: 14`.

Recruit result:

- Action: recruit `unit_ember_archer`.
- Result: passed.
- Message: `Recruited 6 Ember Archer.`
- Resources changed from `3300 gold, 5 wood, 8 ore` to `2820 gold, 5 wood, 8 ore`.
- Final army after recruitment: `unit_ember_archer: 14`, `unit_river_guard: 15`.
- Riverwatch remaining recruits: `unit_ember_archer: 0`, `unit_river_guard: 14`.

Observation: the proof path creates a clear spend/recruit loop. Captures and pickups lead to a town military unlock, then the new unit pool can be recruited into the field army while the scenario remains in progress.

## Save And Resume

Manual slot: 3 in isolated temp user data.

Save result:

- `save_ok: true`
- `scenario_id: river-pass`
- `resume_target: overworld`
- `game_state: overworld`
- `saved_from_game_state: overworld`
- `validity: ok`

Resume result:

- State match: true.
- Restored day: 3.
- Restored resources: `2820 gold`, `5 wood`, `8 ore`.
- Restored Riverwatch state preserved `building_bowyer_lodge`, available recruits, and owner.
- Restored army preserved `14 Ember Archer` and `15 River Guard`.
- Restored site states preserved `north_timber`, `river_signal_post`, `river_free_company`, `southern_ore`, and `eastern_cache` as collected by player.
- Restored resolved encounters preserved `river_pass_ghoul_grove` and `river_pass_hollow_mire`.

Observation: current save/resume preserves the selected economy path state.

## Scenario Viability

After the proof path:

- Scenario status remained `in_progress`.
- Victory objective summary was `2/4`: Blackbranch and Hollow Mire were complete; Duskfen capture and Reed Totemists remained.
- Defeat risks were `0/3 triggered`.
- Riverwatch remained owned by player.
- Duskfen Bastion remained enemy-owned.
- Resources remained sufficient at `2820 gold`, `5 wood`, `8 ore`.
- Army stood at `14 Ember Archer`, `15 River Guard`.
- Mireclaw pressure was below the defeat threshold, though active raid pressure existed.

Viability finding: the economy path leaves the scenario plausibly completable and strengthens the field army. It does not by itself finish the scenario because `river_pass_reed_totemists` and `duskfen_bastion` remain for the normal victory route.

## Result

The proof passes for the selected minimal economy capture/resource loop:

- Player starts with readable `gold`/`wood`/`ore` resources.
- `north_timber` affects the current wood/Timber stockpile.
- `river_signal_post` and `river_free_company` are persistent captures with observable day-advance income.
- `river_free_company` adds immediate field recruits.
- Ghoul Grove and Hollow Mire choices affect route state, flags, resources, and scenario progress.
- `southern_ore` and optional `eastern_cache` are reachable in the current rule path.
- Riverwatch can convert the collected/captured economy into `building_bowyer_lodge` and `unit_ember_archer` recruitment.
- Save/resume preserves resources, captured sites, resolved fights, town build state, recruits, army, and scenario progress.

No minimal code or content change was required.

## Follow-Up

Next slice should be `economy-capture-resource-loop-manual-gate-10184`: review this proof report and, if AcOrP wants live-client transcript coverage for this exact sequence, approve a narrow routed harness/manual-gate pass rather than broad economy migration.
