extends Node

const TARGET_TURNS := 30
const TARGET_TIER_COUNT := 7
const MIN_BUILDABLE_TARGETS := 20
const MIN_NON_UNIT_BUILDABLE_TARGETS := 12
const MIN_COMPLETION_DAY := 20
const SIX_FACTION_BREADTH_PARITY_STATUS := "six_faction_town_breadth_parity"
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
		"min_completion_day": MIN_COMPLETION_DAY,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"normal_market_resource_ids": COMMON_MARKET_RESOURCE_IDS,
		"authored_town_count": 0,
		"recruitment_end_to_end_town_count": 0,
		"seven_tier_recruitment_case_count": 0,
		"recruited_unit_case_count": 0,
		"towns": {},
		"errors": _errors,
	}
	for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_template := ContentService.get_town(town_id)
		var faction_id := String(town_template.get("faction_id", ""))
		var faction := ContentService.get_faction(faction_id)
		if town_template.is_empty() or faction.is_empty():
			continue
		report["authored_town_count"] = int(report.get("authored_town_count", 0)) + 1
		var town_result := _run_town_case(town_template, faction)
		report["towns"][town_id] = town_result
		if not bool(town_result.get("completed", false)):
			_errors.append("%s did not complete in %d turns" % [town_id, TARGET_TURNS])
		if int(town_result.get("completion_day", 0)) < MIN_COMPLETION_DAY:
			_errors.append("%s completed before the production pacing floor day %d" % [town_id, MIN_COMPLETION_DAY])
		if not bool(town_result.get("same_day_reject_ok", false)):
			_errors.append("%s did not reject same-day second build" % town_id)
		if not bool(town_result.get("build_actions_after_build_blocked", false)):
			_errors.append("%s build-action surface still exposed same-day build actions" % town_id)
		if not bool(town_result.get("rare_spend_observed", false)):
			_errors.append("%s never spent its high-tier rare resource through live build rules" % town_id)
		if not bool(town_result.get("market_common_only", false)):
			_errors.append("%s market actions were not bounded to wood/ore" % town_id)
		if int(town_result.get("target_building_count", 0)) < MIN_BUILDABLE_TARGETS:
			_errors.append("%s did not expose enough buildable town-development targets" % town_id)
		if int(town_result.get("non_unit_building_count", 0)) < MIN_NON_UNIT_BUILDABLE_TARGETS:
			_errors.append("%s did not expose enough non-unit town-development targets" % town_id)
		if bool(town_result.get("recruitment_end_to_end_ok", false)):
			report["recruitment_end_to_end_town_count"] = int(report.get("recruitment_end_to_end_town_count", 0)) + 1
		else:
			_errors.append("%s did not recruit through its full seven-tier ladder after development" % town_id)
		report["seven_tier_recruitment_case_count"] = int(report.get("seven_tier_recruitment_case_count", 0)) + int(town_result.get("recruitment_case_count", 0))
		report["recruited_unit_case_count"] = int(report.get("recruited_unit_case_count", 0)) + int(town_result.get("recruited_unit_case_count", 0))
	report["ok"] = _errors.is_empty()
	print("TOWN_DEVELOPMENT_RUNTIME_BALANCE_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town_case(town_template: Dictionary, faction: Dictionary) -> Dictionary:
	var town_id := String(town_template.get("id", ""))
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns := int(profile.get("target_complete_turns", TARGET_TURNS))
	var session = _build_runtime_session(town_template, profile)
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var non_unit_buildings := _non_unit_building_ids(target_buildings)
	var breadth_parity_buildings := _breadth_parity_building_ids(target_buildings)
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
	var recruitment_report := _recruitment_end_to_end_report(session, faction)
	return {
		"town_id": town_id,
		"faction_id": String(faction.get("id", "")),
		"target_turns": target_turns,
		"target_building_count": target_buildings.size(),
		"non_unit_building_count": non_unit_buildings.size(),
		"breadth_parity_building_count": breadth_parity_buildings.size(),
		"completed": missing.is_empty(),
		"completion_day": int(build_log[-1].get("day", 0)) if not build_log.is_empty() else 0,
		"build_count": build_log.size(),
		"missing_buildings": missing,
		"same_day_reject_ok": same_day_reject_ok,
		"build_actions_after_build_blocked": build_actions_after_build_blocked,
		"rare_spend_observed": not rare_spend_events.is_empty(),
		"rare_spend_events": rare_spend_events,
		"market_common_only": market_common_only,
		"recruitment_end_to_end_ok": bool(recruitment_report.get("ok", false)),
		"recruitment_case_count": int(recruitment_report.get("case_count", 0)),
		"recruited_unit_case_count": int(recruitment_report.get("recruited_unit_case_count", 0)),
		"recruitment_report": recruitment_report,
		"support_income_nodes": session.overworld.get("resource_nodes", []).size(),
		"ending_resources": _resources(session),
		"stalled_days": stalled_days.slice(0, 5),
		"build_log": build_log,
	}

func _recruitment_end_to_end_report(session, faction: Dictionary) -> Dictionary:
	_set_active_town(session)
	var ladder_ids := _string_array(faction.get("unit_ladder_ids", []))
	var rows := []
	var errors := []
	var recruited_count := 0
	var before_army := _army_stack_counts(session)
	if ladder_ids.size() != TARGET_TIER_COUNT:
		errors.append("%s unit ladder must expose seven tiers" % String(faction.get("id", "")))
	for index in range(ladder_ids.size()):
		var unit_id := String(ladder_ids[index])
		var expected_tier := index + 1
		var action := _recruit_action_for(session, unit_id)
		var row := {
			"ok": false,
			"unit_id": unit_id,
			"expected_tier": expected_tier,
			"action_found": not action.is_empty(),
		}
		if action.is_empty():
			row["error"] = "missing recruit action"
			errors.append("%s missing recruit action for %s" % [String(faction.get("id", "")), unit_id])
			rows.append(row)
			continue
		var unit := ContentService.get_unit(unit_id)
		var before_count := int(_army_stack_counts(session).get(unit_id, 0))
		var available_before := int(action.get("available_count", 0))
		var weekly_growth := int(action.get("weekly_growth", 0))
		var direct_affordable_count := int(action.get("direct_affordable_count", 0))
		var market_affordable_count := int(action.get("market_affordable_count", 0))
		row["unit_name"] = String(unit.get("name", unit_id))
		row["unit_tier"] = int(action.get("unit_tier", 0))
		row["tier_label"] = String(action.get("tier_label", ""))
		row["available_before"] = available_before
		row["weekly_growth"] = weekly_growth
		row["direct_affordable_count"] = direct_affordable_count
		row["market_affordable_count"] = market_affordable_count
		row["market_coverable"] = bool(action.get("market_coverable", false))
		row["unit_cost"] = action.get("unit_cost", {})
		if direct_affordable_count <= 0 and _has_common_recruitment_shortfall(session, action.get("unit_cost", {})):
			row["market_purchases"] = _apply_recruitment_market_coverage(session, action.get("unit_cost", {}))
			action = _recruit_action_for(session, unit_id)
			direct_affordable_count = int(action.get("direct_affordable_count", 0))
			market_affordable_count = int(action.get("market_affordable_count", 0))
			row["direct_affordable_count"] = direct_affordable_count
			row["market_affordable_count"] = market_affordable_count
			row["market_coverable"] = bool(action.get("market_coverable", false))
		if int(unit.get("tier", 0)) != expected_tier or int(action.get("unit_tier", 0)) != expected_tier:
			row["error"] = "tier mismatch"
		elif available_before <= 0:
			row["error"] = "no recruits available"
		elif weekly_growth <= 0:
			row["error"] = "weekly growth missing"
		elif direct_affordable_count <= 0:
			row["error"] = "not directly affordable"
		elif not String(action.get("summary", "")).contains("Tier %d" % expected_tier):
			row["error"] = "summary missing tier label"
		else:
			var recruit_result: Dictionary = OverworldRules.recruit_in_active_town(session, unit_id, 1)
			var after_count := int(_army_stack_counts(session).get(unit_id, 0))
			row["recruit_result_ok"] = bool(recruit_result.get("ok", false))
			row["recruit_message"] = String(recruit_result.get("message", ""))
			row["army_count_before"] = before_count
			row["army_count_after"] = after_count
			if not bool(recruit_result.get("ok", false)):
				row["error"] = "recruit action failed"
			elif after_count != before_count + 1:
				row["error"] = "field army did not receive recruit"
			else:
				row["ok"] = true
				recruited_count += 1
		if not bool(row.get("ok", false)):
			errors.append("%s %s tier %d recruitment failed: %s" % [
				String(faction.get("id", "")),
				unit_id,
				expected_tier,
				String(row.get("error", "unknown")),
			])
		rows.append(row)
	var after_army := _army_stack_counts(session)
	return {
		"ok": errors.is_empty() and ladder_ids.size() == TARGET_TIER_COUNT and recruited_count == TARGET_TIER_COUNT,
		"faction_id": String(faction.get("id", "")),
		"case_count": rows.size(),
		"recruited_unit_case_count": recruited_count,
		"army_before": before_army,
		"army_after": after_army,
		"tiers": rows,
		"errors": errors,
	}

func _has_common_recruitment_shortfall(session, unit_cost_value: Variant) -> bool:
	var unit_cost: Dictionary = unit_cost_value if unit_cost_value is Dictionary else {}
	for resource_id in COMMON_MARKET_RESOURCE_IDS:
		if int(unit_cost.get(resource_id, 0)) > int(_resources(session).get(resource_id, 0)):
			return true
	return false

func _apply_recruitment_market_coverage(session, unit_cost_value: Variant) -> Array:
	var unit_cost: Dictionary = unit_cost_value if unit_cost_value is Dictionary else {}
	var rows := []
	for resource_id in COMMON_MARKET_RESOURCE_IDS:
		var needed = max(0, int(unit_cost.get(resource_id, 0)) - int(_resources(session).get(resource_id, 0)))
		var wait_days := 0
		while needed > 0:
			var result: Dictionary = TownRules.perform_market_action(session, "market:buy:%s:1" % resource_id)
			rows.append({
				"resource_id": resource_id,
				"ok": bool(result.get("ok", false)),
				"message": String(result.get("message", "")),
				"day": int(session.day),
			})
			if bool(result.get("ok", false)):
				needed -= 1
				wait_days = 0
				continue
			if wait_days >= 7:
				return rows
			var end_turn_result: Dictionary = OverworldRules.end_turn(session)
			rows.append({
				"resource_id": resource_id,
				"ok": bool(end_turn_result.get("ok", false)),
				"message": String(end_turn_result.get("message", "")),
				"day": int(session.day),
				"waited_for_market_reset": true,
			})
			_set_active_town(session)
			if not bool(end_turn_result.get("ok", false)):
				return rows
			wait_days += 1
	return rows

func _recruit_action_for(session, unit_id: String) -> Dictionary:
	_set_active_town(session)
	for action_value in TownRules.get_recruit_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")) == "recruit:%s" % unit_id:
			return action_value
	return {}

func _army_stack_counts(session) -> Dictionary:
	var counts := {}
	for stack_value in session.overworld.get("army", {}).get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var unit_id := String(stack_value.get("unit_id", ""))
		if unit_id == "":
			continue
		counts[unit_id] = int(counts.get(unit_id, 0)) + int(stack_value.get("count", 0))
	return counts

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
	var town := _town(session)
	var resources := _resources(session)
	for building_id_value in OverworldRules.get_town_build_options(town, int(session.day)):
		var building_id := String(building_id_value)
		if building_id not in target_buildings:
			continue
		var building := ContentService.get_building(building_id)
		var readiness: Dictionary = OverworldRules.town_cost_readiness(town, resources, building.get("cost", {}), int(session.day))
		if not bool(readiness.get("direct_affordable", false)):
			continue
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

func _non_unit_building_ids(building_ids: Array) -> Array:
	var result := []
	for building_id in building_ids:
		var building := ContentService.get_building(String(building_id))
		if String(building.get("unlock_unit_id", "")).is_empty():
			result.append(String(building_id))
	return result

func _breadth_parity_building_ids(building_ids: Array) -> Array:
	var result := []
	for building_id in building_ids:
		var building := ContentService.get_building(String(building_id))
		if String(building.get("content_status", "")) == SIX_FACTION_BREADTH_PARITY_STATUS:
			result.append(String(building_id))
	return result

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
