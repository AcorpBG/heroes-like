extends Node

const TARGET_TURNS := 30
const REPORT_SCHEMA := "town_development_runtime_balance_report_v1"
const HERO_ID := "hero_lyra"
const PLAYER_TOWN_PLACEMENT_ID := "runtime_balance_town"
const COMMON_MARKET_RESOURCE_IDS := ["wood", "ore"]
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
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const RESOURCE_INCOME_SITES := {
	"gold": {"site_id": "site_mirror_bound_barracks", "amount": 50},
	"wood": {"site_id": "site_brightwood_sawmill", "amount": 1},
	"ore": {"site_id": "site_ridge_quarry", "amount": 1},
	"aetherglass": {"site_id": "site_aetherglass_lens_house", "amount": 1},
	"embergrain": {"site_id": "site_embergrain_warm_granary", "amount": 1},
	"peatwax": {"site_id": "site_peatwax_reed_yard", "amount": 1},
	"verdant_grafts": {"site_id": "site_verdant_graft_nursery", "amount": 1},
	"brass_scrip": {"site_id": "site_brass_scrip_mint", "amount": 1},
	"memory_salt": {"site_id": "site_memory_salt_pan", "amount": 1},
}

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := {
		"schema": REPORT_SCHEMA,
		"target_turns": TARGET_TURNS,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"normal_market_resource_ids": COMMON_MARKET_RESOURCE_IDS,
		"towns": {},
		"errors": _errors,
	}
	for faction_id in ContentService.get_content_ids(ContentService.FACTIONS_PATH):
		var faction := ContentService.get_faction(faction_id)
		var seed_town_id := String(faction.get("seed_town_id", ""))
		if seed_town_id == "":
			continue
		var town_result := _run_town_case(faction)
		report["towns"][seed_town_id] = town_result
		if not bool(town_result.get("completed", false)):
			_errors.append("%s did not complete in %d turns" % [seed_town_id, TARGET_TURNS])
		if not bool(town_result.get("same_day_reject_ok", false)):
			_errors.append("%s did not reject same-day second build" % seed_town_id)
		if not bool(town_result.get("build_actions_after_build_blocked", false)):
			_errors.append("%s build-action surface still exposed same-day build actions" % seed_town_id)
		if not bool(town_result.get("rare_spend_observed", false)):
			_errors.append("%s never spent its high-tier rare resource through live build rules" % seed_town_id)
		if not bool(town_result.get("market_common_only", false)):
			_errors.append("%s market actions were not bounded to wood/ore" % seed_town_id)
	report["ok"] = _errors.is_empty()
	print("TOWN_DEVELOPMENT_RUNTIME_BALANCE_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town_case(faction: Dictionary) -> Dictionary:
	var town_id := String(faction.get("seed_town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns := int(profile.get("target_complete_turns", TARGET_TURNS))
	var session = _build_runtime_session(town_template, profile)
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var signature_order := _signature_order(faction)
	var build_log := []
	var stalled_days := []
	var same_day_reject_ok := false
	var build_actions_after_build_blocked := false
	var rare_spend_events := []
	var market_common_only := true

	for _turn in range(target_turns):
		var end_turn_result: Dictionary = OverworldRules.end_turn(session)
		if not bool(end_turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "end_turn_failed",
				"message": String(end_turn_result.get("message", "")),
			})
			continue
		_set_active_town(session)
		var before_build_town := _town(session)
		var selected_id := _select_building_id(session, target_buildings, signature_order)
		if selected_id == "":
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_affordable_build_action",
				"resources": _resources(session),
				"open_buildings": _open_building_ids(before_build_town, target_buildings),
			})
			continue
		var before_resources := _resources(session)
		var selected_building := ContentService.get_building(selected_id)
		var build_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
		if not bool(build_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "build_failed",
				"building_id": selected_id,
				"message": String(build_result.get("message", "")),
			})
			continue
		var after_resources := _resources(session)
		var rare_delta := _rare_resource_spend(selected_building.get("cost", {}), before_resources, after_resources)
		if not rare_delta.is_empty():
			rare_spend_events.append({
				"day": int(session.day),
				"building_id": selected_id,
				"spent": rare_delta,
			})
		var same_day_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
		if not bool(same_day_result.get("ok", true)) and String(same_day_result.get("message", "")).contains("already completed a build order today"):
			same_day_reject_ok = true
		build_actions_after_build_blocked = TownRules.get_build_actions(session).is_empty()
		build_log.append({
			"day": int(session.day),
			"building_id": selected_id,
			"message": String(build_result.get("message", "")),
			"resources_before": before_resources,
			"resources_after": after_resources,
		})
		market_common_only = market_common_only and _market_actions_common_only(session)
		if _missing_buildings(session, target_buildings).is_empty():
			break

	var missing := _missing_buildings(session, target_buildings)
	return {
		"town_id": town_id,
		"faction_id": String(faction.get("id", "")),
		"target_turns": target_turns,
		"completed": missing.is_empty(),
		"completion_day": int(build_log[-1].get("day", 0)) if not build_log.is_empty() else 0,
		"build_count": build_log.size(),
		"missing_buildings": missing,
		"same_day_reject_ok": same_day_reject_ok,
		"build_actions_after_build_blocked": build_actions_after_build_blocked,
		"rare_spend_observed": not rare_spend_events.is_empty(),
		"rare_spend_events": rare_spend_events,
		"market_common_only": market_common_only,
		"support_income_nodes": session.overworld.get("resource_nodes", []).size(),
		"ending_resources": _resources(session),
		"stalled_days": stalled_days.slice(0, 5),
		"build_log": build_log,
	}

func _build_runtime_session(town_template: Dictionary, profile: Dictionary):
	var hero_template := ContentService.get_hero(HERO_ID)
	var hero := HeroCommandRules.build_hero_from_template(
		hero_template,
		{"x": 0, "y": 0},
		{"id": "runtime_balance_army", "name": "Runtime Balance Army", "stacks": []},
		"normal"
	)
	hero["is_primary"] = true
	var town_state := {
		"placement_id": PLAYER_TOWN_PLACEMENT_ID,
		"town_id": String(town_template.get("id", "")),
		"x": 0,
		"y": 0,
		"owner": "player",
		"controlling_faction_id": "",
		"built_buildings": _string_array(town_template.get("starting_building_ids", [])),
		"available_recruits": {},
		"garrison": town_template.get("garrison", []).duplicate(true) if town_template.get("garrison", []) is Array else [],
		"recovery": {},
		"front": {},
		"occupation": {},
		"last_build_day": 0,
	}
	var overworld := {
		"map": [["grass", "grass", "grass"], ["grass", "grass", "grass"], ["grass", "grass", "grass"]],
		"map_size": {"width": 3, "height": 3},
		"terrain_layers": {},
		"active_hero_id": HERO_ID,
		"player_heroes": [hero],
		"hero_position": {"x": 0, "y": 0},
		"hero": hero,
		"movement": hero.get("movement", {"current": 10, "max": 10}),
		"fog": {},
		"resources": _normalized_resources(profile.get("starting_resources", {})),
		"army": hero.get("army", {}),
		"encounters": [],
		"resolved_encounters": [],
		"towns": [town_state],
		"resource_nodes": _resource_nodes_for_income(profile.get("daily_income", {})),
		"artifact_nodes": [],
		"enemy_states": [],
		"scenario_script_state": {},
	}
	var session = SessionStateStore.new_session_data(
		"runtime_balance_%s" % String(town_template.get("id", "")),
		"",
		HERO_ID,
		0,
		overworld,
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	session.game_state = "town"
	session.scenario_status = "in_progress"
	session.flags = {}
	OverworldRules.normalize_overworld_state(session)
	_set_active_town(session)
	return session

func _set_active_town(session) -> void:
	var result: Dictionary = OverworldRules.set_active_town_visit(session, PLAYER_TOWN_PLACEMENT_ID)
	if not bool(result.get("ok", false)):
		_errors.append("Unable to select runtime town: %s" % String(result.get("message", "")))

func _select_building_id(session, target_buildings: Array, signature_order: Dictionary) -> String:
	var actions := []
	for action_value in TownRules.get_build_actions(session):
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			continue
		var building_id := String(action.get("id", "")).trim_prefix("build:")
		if building_id in target_buildings:
			actions.append(building_id)
	actions.sort_custom(func(a, b): return _build_sort_key(a, target_buildings, signature_order) < _build_sort_key(b, target_buildings, signature_order))
	return String(actions[0]) if not actions.is_empty() else ""

func _build_sort_key(building_id: String, target_buildings: Array, signature_order: Dictionary) -> String:
	var signature_rank := int(signature_order.get(building_id, 99))
	var target_rank := target_buildings.find(building_id)
	if target_rank < 0:
		target_rank = 999
	return "%03d:%03d:%s" % [signature_rank, target_rank, building_id]

func _signature_order(faction: Dictionary) -> Dictionary:
	var order := {}
	var signature_ids := _string_array(faction.get("signature_building_ids", []))
	for index in range(signature_ids.size()):
		order[signature_ids[index]] = index + 1
	return order

func _resource_nodes_for_income(income_value: Variant) -> Array:
	var income: Dictionary = income_value if income_value is Dictionary else {}
	var nodes := []
	var node_index := 0
	for resource_id_value in income.keys():
		var resource_id := String(resource_id_value)
		var amount: int = max(0, int(income.get(resource_id, 0)))
		if amount <= 0 or not RESOURCE_INCOME_SITES.has(resource_id):
			continue
		var source: Dictionary = RESOURCE_INCOME_SITES[resource_id]
		var source_amount: int = max(1, int(source.get("amount", 1)))
		var count: int = int(ceil(float(amount) / float(source_amount)))
		for _i in range(count):
			nodes.append({
				"placement_id": "runtime_income_%s_%03d" % [resource_id, node_index],
				"site_id": String(source.get("site_id", "")),
				"x": 1 + (node_index % 2),
				"y": 1 + int(node_index / 2),
				"collected": true,
				"collected_by_faction_id": "player",
				"collected_day": 0,
				"delivery_arrival_day": 0,
				"delivery_controller_id": "",
				"delivery_manifest": {},
				"delivery_origin_town_id": "",
				"delivery_target_id": "",
				"delivery_target_kind": "",
				"delivery_target_label": "",
				"response_commander_id": "",
				"response_last_day": 0,
				"response_origin": "",
				"response_security_rating": 0,
				"response_source_town_id": "",
				"response_until_day": 0,
			})
			node_index += 1
	return nodes

func _market_actions_common_only(session) -> bool:
	for action_value in TownRules.get_market_actions(session):
		if not (action_value is Dictionary):
			continue
		var action_id := String(action_value.get("id", ""))
		if action_id.begins_with("market:buy:") or action_id.begins_with("market:sell:"):
			var parts := action_id.split(":")
			if parts.size() >= 3 and String(parts[2]) not in COMMON_MARKET_RESOURCE_IDS:
				return false
	return true

func _missing_buildings(session, target_buildings: Array) -> Array:
	var built := _string_array(_town(session).get("built_buildings", []))
	var missing := []
	for building_id in target_buildings:
		if String(building_id) not in built:
			missing.append(String(building_id))
	return missing

func _open_building_ids(town: Dictionary, target_buildings: Array) -> Array:
	var built := _string_array(town.get("built_buildings", []))
	var open := []
	for building_id in target_buildings:
		if String(building_id) not in built:
			open.append(String(building_id))
	return open

func _town(session) -> Dictionary:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town_value in towns:
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == PLAYER_TOWN_PLACEMENT_ID:
			return town_value
	return {}

func _rare_resource_spend(cost_value: Variant, before: Dictionary, after: Dictionary) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var spent := {}
	for resource_id in RARE_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) <= 0:
			continue
		var delta := int(before.get(resource_id, 0)) - int(after.get(resource_id, 0))
		if delta > 0:
			spent[resource_id] = delta
	return spent

func _normalized_resources(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var resources := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		resources[resource_id] = max(0, int(source.get(resource_id, 0)))
	return resources

func _resources(session) -> Dictionary:
	return _normalized_resources(session.overworld.get("resources", {}))

func _string_array(value: Variant) -> Array:
	var result := []
	if not (value is Array):
		return result
	for item in value:
		var text := String(item)
		if text != "":
			result.append(text)
	return result
