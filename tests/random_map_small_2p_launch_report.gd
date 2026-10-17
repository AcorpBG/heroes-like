extends Node

const REPORT_ID := "RANDOM_MAP_SMALL_2P_LAUNCH_REPORT"
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _assert_launch_keeps_chosen_monster_strength():
		return
	var retry_cases := _assert_two_player_retry_cases()
	if retry_cases.is_empty():
		return
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_skirmish_stage")
	shell.call("validation_set_generated_seed", "aurelion-random-skirmish-10184")
	if not bool(shell.call("validation_select_generated_size_class", "homm3_small")):
		_fail("Small size class was not selectable.")
		return
	if not bool(shell.call("validation_select_generated_water_mode", "land")):
		_fail("Land water mode was not selectable.")
		return
	if not bool(shell.call("validation_select_generated_player_count", 2)):
		_fail("Two-player Small/Land setup was not selectable.")
		return
	shell.call("validation_set_generated_underground", false)
	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	var setup: Dictionary = snapshot.get("setup", {}) if snapshot.get("setup", {}) is Dictionary else {}
	if not bool(setup.get("ok", false)):
		_fail("Two-player Small/Land setup failed before launch: %s" % JSON.stringify(setup))
		return
	var launch_result: Dictionary = shell.call("validation_start_generated_skirmish")
	if not bool(launch_result.get("started", false)):
		_fail("Two-player Small/Land launch failed: %s" % JSON.stringify(launch_result))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": String(launch_result.get("active_scenario_id", "")),
		"retry_status": launch_result.get("active_retry_status", {}),
		"controls": snapshot.get("controls", {}),
		"retry_cases": retry_cases,
	})])
	get_tree().quit(0)

# The public launch rebuilds every config as catalog-auto. A strength the caller
# chose survives that on every template selection mode; an unchosen one gets the
# default.
func _assert_launch_keeps_chosen_monster_strength() -> bool:
	var modes := [
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,
	]
	for mode in modes:
		for size_class in ["homm3_small", "homm3_large"]:
			for strength in ["weak", "strong", ""]:
				var config := ScenarioSelectRulesScript.build_random_map_player_config(
					"launch-strength-10184", "", "", 2, "land", false, size_class, mode, "", "", strength
				)
				var launch: Dictionary = ScenarioSelectRulesScript._random_map_public_h3maped_launch_config(config)
				var expected: String = strength if strength != "" else ScenarioSelectRulesScript.RANDOM_MAP_DEFAULT_MONSTER_STRENGTH
				if String(launch.get("monster_strength", "")) != expected:
					_fail("Launch config for %s %s chose '%s' but launches '%s'." % [mode, size_class, strength, String(launch.get("monster_strength", ""))])
					return false
	return true

func _assert_two_player_retry_cases() -> Array:
	var seeds := [
		"aurelion-random-skirmish-10184",
		"small-land-2p-user-seed-10184",
		"1",
		"2",
		"3",
		"4",
		"5",
		"17",
		"27",
		"48",
		"10184",
	]
	var cases := []
	var neutral_factions := {}
	for seed in seeds:
		var config := ScenarioSelectRulesScript.build_random_map_player_config(
			String(seed),
			"",
			"",
			2,
			"land",
			false,
			"homm3_small",
			ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
		)
		var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
			config,
			"normal",
			ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
		)
		if not bool(setup.get("ok", false)):
			_fail("Two-player Small/Land retry setup failed for seed %s: %s" % [String(seed), JSON.stringify(setup)])
			return []
		cases.append({
			"seed": String(seed),
			"normalized_seed": String(setup.get("normalized_seed", "")),
			"attempt_count": int(setup.get("retry_status", {}).get("attempt_count", 0)) if setup.get("retry_status", {}) is Dictionary else 0,
			"template_id": String(setup.get("template_id", "")),
		})
		if not _collect_neutral_town_factions(setup, neutral_factions):
			return []
	# A neutral town's faction follows the town type the generator rolled for it.
	if neutral_factions.size() < 3:
		_fail("Neutral towns on generated maps fell back to too few factions: %s" % JSON.stringify(neutral_factions))
		return []
	return cases

func _collect_neutral_town_factions(setup: Dictionary, factions: Dictionary) -> bool:
	var startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	var map_load: Dictionary = ClassDB.instantiate("MapPackageService").load_map_package(String(startup.get("map_path", "")))
	var document = map_load.get("map_document", null)
	if document == null:
		_fail("Generated map package did not load: %s" % JSON.stringify(startup))
		return false
	for index in range(int(document.get_object_count())):
		var town: Dictionary = document.get_object_by_index(index)
		if String(town.get("kind", "")) != "town" or String(town.get("owner", "")) != "neutral":
			continue
		var faction_id := String(town.get("faction_id", ""))
		var town_faction_id := String(ContentService.get_town(String(town.get("town_id", ""))).get("faction_id", ""))
		if ContentService.get_faction(faction_id).is_empty() or town_faction_id != faction_id:
			_fail("Neutral town has no matching faction and town: %s" % JSON.stringify(town))
			return false
		factions[faction_id] = int(factions.get(faction_id, 0)) + 1
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
