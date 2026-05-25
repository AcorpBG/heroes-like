extends Node

const TownShellScene = preload("res://scenes/town/TownShell.tscn")

const REPORT_SCHEMA := "town_economy_resource_ui_surface_report_v1"
const SCENARIO_ID := "river-pass"
const COMMON_RESOURCE_IDS := ["gold", "wood", "ore"]
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const LIVE_STOCKPILE_RESOURCE_IDS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const RESOURCE_LABELS := {
	"gold": "Gold",
	"wood": "Wood",
	"ore": "Ore",
	"aetherglass": "Aetherglass",
	"embergrain": "Embergrain",
	"peatwax": "Peatwax",
	"verdant_grafts": "Verdant grafts",
	"brass_scrip": "Brass scrip",
	"memory_salt": "Memory salt",
}

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var faction_ids := ContentService.get_content_ids(ContentService.FACTIONS_PATH)
	faction_ids.sort()
	var rows := []
	for faction_id_value in faction_ids:
		var faction_id := String(faction_id_value)
		var faction := ContentService.get_faction(faction_id)
		if faction.is_empty():
			continue
		var row: Dictionary = await _run_faction_case(faction)
		rows.append(row)
		if not bool(row.get("ok", false)):
			for error_value in row.get("errors", []):
				_errors.append(String(error_value))

	if rows.size() < 6:
		_errors.append("Expected six faction town UI economy cases, got %d." % rows.size())
	var same_day_build_lockout_case_count := 0
	for row in rows:
		if row is Dictionary and bool(row.get("same_day_build_lockout_ok", false)):
			same_day_build_lockout_case_count += 1

	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"faction_case_count": rows.size(),
		"same_day_build_lockout_case_count": same_day_build_lockout_case_count,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"common_resource_ids": COMMON_RESOURCE_IDS,
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"Each case instantiates TownShell with an isolated seed-town state and a high-tier rare-cost building made available through authored prerequisites.",
			"The report validates player-facing town resource ledger, build-readiness, and same-day construction lockout surfaces; it does not retune scenario-wide economy pacing.",
		],
	}
	if _errors.is_empty():
		print("TOWN_ECONOMY_RESOURCE_UI_SURFACE_REPORT %s" % JSON.stringify(report))
	else:
		push_error("TOWN_ECONOMY_RESOURCE_UI_SURFACE_REPORT failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_faction_case(faction: Dictionary) -> Dictionary:
	var case_errors := []
	var faction_id := String(faction.get("id", ""))
	var town_id := String(faction.get("seed_town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var rare_id := String(town_template.get("development_balance", {}).get("rare_resource_id", ""))
	var target_building_id := _first_rare_building_id(town_template, rare_id)
	var target_building := ContentService.get_building(target_building_id)
	var target_cost: Dictionary = target_building.get("cost", {}) if target_building.get("cost", {}) is Dictionary else {}
	var placement_id := "town_ui_surface_%s" % town_id
	var row := {
		"faction_id": faction_id,
		"town_id": town_id,
		"rare_resource_id": rare_id,
		"target_building_id": target_building_id,
		"errors": case_errors,
	}
	if town_template.is_empty():
		case_errors.append("%s seed town is missing." % faction_id)
		row["ok"] = false
		return row
	if rare_id not in RARE_RESOURCE_IDS:
		case_errors.append("%s seed town rare_resource_id is not live: %s." % [town_id, rare_id])
	if target_building_id == "":
		case_errors.append("%s has no rare-cost buildable target for %s." % [town_id, rare_id])
		row["ok"] = false
		return row

	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town_state := _town_state_for_surface_case(town_template, faction_id, placement_id, target_building_id)
	session.overworld["towns"] = [town_state]
	session.overworld["resources"] = _blocked_resource_stockpile()
	session.day = 1
	_move_active_hero_to_town(session, town_state)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(visit_result.get("ok", false)):
		case_errors.append("%s could not open TownShell visit: %s." % [town_id, JSON.stringify(visit_result)])
	session = SessionState.set_active_session(session)

	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var blocked_snapshot: Dictionary = shell.call("validation_resource_ledger_snapshot")
	var blocked_catalog: Dictionary = shell.call("validation_action_catalog")
	var blocked_action: Dictionary = _action_by_id(blocked_catalog.get("build", []), "build:%s" % target_building_id)
	var blocked_market_actions: Array = blocked_catalog.get("market", []) if blocked_catalog.get("market", []) is Array else []
	_assert_town_shell_resource_surface(blocked_snapshot, rare_id, false, case_errors)
	_assert_common_only_market_actions(blocked_market_actions, case_errors)
	_assert_blocked_rare_build_action(blocked_action, rare_id, target_cost, case_errors)

	var rare_amount: int = max(1, int(target_cost.get(rare_id, 0)))
	session.overworld["resources"][rare_id] = rare_amount
	OverworldRules.normalize_overworld_state(session)
	shell.call("validation_force_refresh")
	await get_tree().process_frame

	var ready_snapshot: Dictionary = shell.call("validation_resource_ledger_snapshot")
	var ready_catalog: Dictionary = shell.call("validation_action_catalog")
	var ready_action: Dictionary = _action_by_id(ready_catalog.get("build", []), "build:%s" % target_building_id)
	_assert_town_shell_resource_surface(ready_snapshot, rare_id, true, case_errors)
	_assert_ready_rare_build_action(ready_action, rare_id, target_cost, case_errors)

	var build_result: Dictionary = TownRules.build_active_town(session, target_building_id)
	build_result["action_id"] = "build:%s" % target_building_id
	build_result["lane"] = "build"
	build_result["state_changed"] = bool(build_result.get("ok", false))
	shell.call("validation_force_refresh")
	await get_tree().process_frame
	var post_build_catalog: Dictionary = shell.call("validation_action_catalog")
	var post_build_actions: Array = post_build_catalog.get("build", []) if post_build_catalog.get("build", []) is Array else []
	var post_build_town := _town_by_placement_id(session, placement_id)
	var same_day_guarded_unbuilt_count := _same_day_guarded_unbuilt_count(post_build_town, int(session.day))
	var post_build_enabled_action_count := _enabled_action_count(post_build_actions)
	var same_day_build_lockout_ok := _assert_same_day_build_lockout(
		build_result,
		post_build_actions,
		post_build_town,
		target_building_id,
		int(session.day),
		same_day_guarded_unbuilt_count,
		case_errors
	)

	row["ok"] = case_errors.is_empty()
	row["blocked_action"] = _action_summary(blocked_action)
	row["ready_action"] = _action_summary(ready_action)
	row["build_result"] = _build_result_summary(build_result)
	row["same_day_build_lockout_ok"] = same_day_build_lockout_ok
	row["post_build_action_count"] = post_build_actions.size()
	row["post_build_enabled_action_count"] = post_build_enabled_action_count
	row["post_build_last_build_day"] = int(post_build_town.get("last_build_day", 0))
	row["same_day_guarded_unbuilt_count"] = same_day_guarded_unbuilt_count
	row["post_build_action_ids"] = _action_ids(post_build_actions)
	row["blocked_resource_surface"] = _resource_surface_summary(blocked_snapshot)
	row["ready_resource_surface"] = _resource_surface_summary(ready_snapshot)
	row["market_action_count"] = blocked_market_actions.size()
	row["built_prerequisite_count"] = _string_array(town_state.get("built_buildings", [])).size()
	row["errors"] = case_errors
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _town_state_for_surface_case(town_template: Dictionary, faction_id: String, placement_id: String, target_building_id: String) -> Dictionary:
	var built := {}
	for starting_value in town_template.get("starting_building_ids", []):
		built[String(starting_value)] = true
	var visited := {}
	_collect_required_buildings(target_building_id, built, visited)
	built.erase(target_building_id)
	return {
		"placement_id": placement_id,
		"town_id": String(town_template.get("id", "")),
		"owner": "player",
		"controlling_faction_id": faction_id,
		"x": 4,
		"y": 4,
		"built_buildings": _dictionary_keys(built),
		"available_recruits": {},
		"last_build_day": 0,
	}

func _collect_required_buildings(building_id: String, built: Dictionary, visited: Dictionary) -> void:
	if bool(visited.get(building_id, false)):
		return
	visited[building_id] = true
	var building := ContentService.get_building(building_id)
	if building.is_empty():
		return
	for requirement_value in building.get("requires", []):
		var requirement_id := String(requirement_value)
		if requirement_id == "" or bool(built.get(requirement_id, false)):
			continue
		built[requirement_id] = true
		_collect_required_buildings(requirement_id, built, visited)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and not bool(built.get(upgrade_from, false)):
		built[upgrade_from] = true
		_collect_required_buildings(upgrade_from, built, visited)

func _first_rare_building_id(town_template: Dictionary, rare_id: String) -> String:
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		var building := ContentService.get_building(building_id)
		var cost: Dictionary = building.get("cost", {}) if building.get("cost", {}) is Dictionary else {}
		if int(cost.get(rare_id, 0)) > 0:
			return building_id
	return ""

func _blocked_resource_stockpile() -> Dictionary:
	var resources := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		resources[resource_id] = 0
	resources["gold"] = 50000
	resources["wood"] = 500
	resources["ore"] = 500
	return resources

func _assert_town_shell_resource_surface(snapshot: Dictionary, rare_id: String, rare_positive: bool, errors: Array) -> void:
	var resources: Dictionary = snapshot.get("resources", {}) if snapshot.get("resources", {}) is Dictionary else {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		if not resources.has(resource_id):
			errors.append("TownShell snapshot resources missing %s." % resource_id)
	var resource_ids: Array = snapshot.get("live_stockpile_resource_ids", []) if snapshot.get("live_stockpile_resource_ids", []) is Array else []
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		if resource_id not in resource_ids:
			errors.append("TownShell snapshot live_stockpile_resource_ids missing %s." % resource_id)
	var visible_text := String(snapshot.get("resources_visible_text", ""))
	for resource_id in COMMON_RESOURCE_IDS:
		_assert_contains(visible_text, String(RESOURCE_LABELS.get(resource_id, resource_id)), "visible resource line", errors)
	var tooltip_text := String(snapshot.get("resources_tooltip_text", ""))
	var full_ledger_text := String(snapshot.get("resources_full_ledger_text", ""))
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		var label := String(RESOURCE_LABELS.get(resource_id, resource_id))
		_assert_contains(tooltip_text, label, "resource tooltip ledger", errors)
		_assert_contains(full_ledger_text, label, "full resource ledger", errors)
	var rare_label := String(RESOURCE_LABELS.get(rare_id, rare_id))
	if rare_positive:
		_assert_contains(visible_text, rare_label, "visible positive rare resource line", errors)
	else:
		if visible_text.find(rare_label) >= 0:
			errors.append("Visible resource line should stay compact and omit zero %s: %s." % [rare_id, visible_text])

func _assert_blocked_rare_build_action(action: Dictionary, rare_id: String, target_cost: Dictionary, errors: Array) -> void:
	if action.is_empty():
		errors.append("Rare-cost build action was missing.")
		return
	var cost: Dictionary = action.get("cost", {}) if action.get("cost", {}) is Dictionary else {}
	if int(cost.get(rare_id, 0)) <= 0 or int(target_cost.get(rare_id, 0)) <= 0:
		errors.append("Rare-cost build action did not carry %s cost: %s." % [rare_id, JSON.stringify(action)])
	if not bool(action.get("disabled", false)):
		errors.append("Rare-cost build action should be disabled while %s is missing." % rare_id)
	if bool(action.get("direct_affordable", false)):
		errors.append("Rare-cost build action incorrectly reported direct_affordable without %s." % rare_id)
	if bool(action.get("market_coverable", false)):
		errors.append("Rare-cost build action incorrectly allowed normal-market coverage for %s." % rare_id)
	_assert_contains(String(action.get("shortfall_summary", "")), rare_id, "rare build shortfall", errors)
	_assert_contains(String(action.get("disabled_reason", "")), rare_id, "rare build disabled reason", errors)

func _assert_ready_rare_build_action(action: Dictionary, rare_id: String, target_cost: Dictionary, errors: Array) -> void:
	if action.is_empty():
		errors.append("Ready rare-cost build action was missing.")
		return
	var cost: Dictionary = action.get("cost", {}) if action.get("cost", {}) is Dictionary else {}
	if int(cost.get(rare_id, 0)) != int(target_cost.get(rare_id, 0)):
		errors.append("Ready rare-cost build action changed %s cost: %s." % [rare_id, JSON.stringify(action)])
	if bool(action.get("disabled", true)):
		errors.append("Rare-cost build action stayed disabled after %s was stocked." % rare_id)
	if not bool(action.get("direct_affordable", false)):
		errors.append("Rare-cost build action did not become direct_affordable after %s was stocked." % rare_id)
	if bool(action.get("market_coverable", false)):
		errors.append("Directly affordable rare-cost build action should not require market coverage.")

func _assert_common_only_market_actions(actions: Array, errors: Array) -> void:
	if actions.is_empty():
		errors.append("TownShell market actions were empty for a town with a built market square.")
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action_id := String(action_value.get("id", ""))
		var parts := action_id.split(":")
		if parts.size() >= 3 and String(parts[0]) == "market":
			var resource_id := String(parts[2])
			if resource_id not in ["wood", "ore"]:
				errors.append("Normal town market exposed non-common resource %s in %s." % [resource_id, action_id])

func _assert_same_day_build_lockout(
	build_result: Dictionary,
	post_build_actions: Array,
	post_build_town: Dictionary,
	target_building_id: String,
	current_day: int,
	same_day_guarded_unbuilt_count: int,
	errors: Array
) -> bool:
	var ok := true
	if not bool(build_result.get("ok", false)):
		errors.append("TownShell build action did not complete before same-day lockout check: %s." % JSON.stringify(build_result))
		ok = false
	var built_buildings := _string_array(post_build_town.get("built_buildings", []))
	if target_building_id not in built_buildings:
		errors.append("Built target %s was not present in post-build town state: %s." % [target_building_id, JSON.stringify(post_build_town)])
		ok = false
	if int(post_build_town.get("last_build_day", 0)) != current_day:
		errors.append("Post-build town last_build_day did not match current day %d: %s." % [current_day, JSON.stringify(post_build_town)])
		ok = false
	if post_build_actions.size() > 0:
		errors.append("TownShell still exposed build actions after same-day build order: %s." % JSON.stringify(_action_ids(post_build_actions)))
		ok = false
	if _enabled_action_count(post_build_actions) > 0:
		errors.append("TownShell still exposed enabled build actions after same-day build order.")
		ok = false
	if same_day_guarded_unbuilt_count <= 0:
		errors.append("No remaining unbuilt town building carried the same-day build guard after construction.")
		ok = false
	return ok

func _town_by_placement_id(session, placement_id: String) -> Dictionary:
	var towns = session.overworld.get("towns", [])
	if towns is Array:
		for town_value in towns:
			if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
				return town_value
	return {}

func _same_day_guarded_unbuilt_count(town: Dictionary, current_day: int) -> int:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var built_buildings := _string_array(town.get("built_buildings", []))
	var count := 0
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		if building_id == "" or building_id in built_buildings:
			continue
		var status: Dictionary = OverworldRules.get_town_build_status(town, building_id, current_day)
		var blockers: Array = status.get("blockers", []) if status.get("blockers", []) is Array else []
		if "Already built in this town today." in blockers:
			count += 1
	return count

func _enabled_action_count(actions: Array) -> int:
	var count := 0
	for action_value in actions:
		if action_value is Dictionary and not bool(action_value.get("disabled", false)):
			count += 1
	return count

func _assert_contains(text: String, needle: String, label: String, errors: Array) -> void:
	if needle == "":
		return
	if text.find(needle) < 0:
		errors.append("%s missing '%s': %s." % [label, needle, text])

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position: Dictionary = {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _action_by_id(actions: Variant, action_id: String) -> Dictionary:
	if not (actions is Array):
		return {}
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return action_value
	return {}

func _action_summary(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}
	return {
		"id": String(action.get("id", "")),
		"cost": action.get("cost", {}),
		"disabled": bool(action.get("disabled", false)),
		"direct_affordable": bool(action.get("direct_affordable", false)),
		"market_coverable": bool(action.get("market_coverable", false)),
		"shortfall_summary": String(action.get("shortfall_summary", "")),
		"disabled_reason": String(action.get("disabled_reason", "")),
	}

func _build_result_summary(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"action_id": String(result.get("action_id", "")),
		"lane": String(result.get("lane", "")),
		"state_changed": bool(result.get("state_changed", false)),
		"message": String(result.get("message", "")),
	}

func _action_ids(actions: Array) -> Array:
	var ids := []
	for action_value in actions:
		if action_value is Dictionary:
			ids.append(String(action_value.get("id", "")))
	ids.sort()
	return ids

func _resource_surface_summary(snapshot: Dictionary) -> Dictionary:
	return {
		"resources_visible_text": String(snapshot.get("resources_visible_text", "")),
		"resources_tooltip_text": String(snapshot.get("resources_tooltip_text", "")),
		"resources_full_ledger_text": String(snapshot.get("resources_full_ledger_text", "")),
	}

func _dictionary_keys(value: Dictionary) -> Array:
	var keys := []
	for key in value.keys():
		keys.append(String(key))
	keys.sort()
	return keys

func _string_array(value: Variant) -> Array:
	var result := []
	if value is Array:
		for entry in value:
			result.append(String(entry))
	return result
