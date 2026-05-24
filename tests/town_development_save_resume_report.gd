extends Node

const TARGET_TURNS := 30
const SAVE_SLOT := 3
const REPORT_SCHEMA := "town_development_save_resume_report_v1"
const HERO_ID := "hero_lyra"
const SAVE_SCENARIO_ID := "river-pass"
const PLAYER_TOWN_PLACEMENT_ID := "save_resume_balance_town"
const ACTIVE_TOWN_PLACEMENT_KEY := "active_town_placement_id"
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
		"save_slot": SAVE_SLOT,
		"authored_town_count": 0,
		"save_resume_case_count": 0,
		"completed_case_count": 0,
		"rare_resume_case_count": 0,
		"same_day_guard_case_count": 0,
		"resume_target_case_count": 0,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
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
		if bool(town_result.get("completed", false)):
			report["completed_case_count"] = int(report.get("completed_case_count", 0)) + 1
		if bool(town_result.get("save_resume_ok", false)):
			report["save_resume_case_count"] = int(report.get("save_resume_case_count", 0)) + 1
		if bool(town_result.get("rare_resume_ok", false)):
			report["rare_resume_case_count"] = int(report.get("rare_resume_case_count", 0)) + 1
		if bool(town_result.get("same_day_guard_after_restore", false)):
			report["same_day_guard_case_count"] = int(report.get("same_day_guard_case_count", 0)) + 1
		if bool(town_result.get("resume_target_town", false)):
			report["resume_target_case_count"] = int(report.get("resume_target_case_count", 0)) + 1
		_assert_town_case(town_id, town_result)
	report["ok"] = _errors.is_empty()
	print("TOWN_DEVELOPMENT_SAVE_RESUME_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _assert_town_case(town_id: String, row: Dictionary) -> void:
	if not bool(row.get("completed", false)):
		_errors.append("%s did not complete development after save/resume within %d turns" % [town_id, TARGET_TURNS])
	if not bool(row.get("save_resume_ok", false)):
		_errors.append("%s did not preserve town-development state across save/resume" % town_id)
	if not bool(row.get("rare_resume_ok", false)):
		_errors.append("%s did not save/resume immediately after a rare-resource build" % town_id)
	if not bool(row.get("same_day_guard_after_restore", false)):
		_errors.append("%s did not preserve one-build-per-day guard after restore" % town_id)
	if not bool(row.get("build_actions_after_restore_blocked", false)):
		_errors.append("%s exposed build actions after restoring same-day build state" % town_id)
	if not bool(row.get("resume_target_town", false)):
		_errors.append("%s save summary did not resume to town" % town_id)
	if int(row.get("save_version", 0)) != SessionStateStore.SAVE_VERSION:
		_errors.append("%s changed save version during town-development continuity check" % town_id)

func _run_town_case(town_template: Dictionary, faction: Dictionary) -> Dictionary:
	var town_id := String(town_template.get("id", ""))
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns := int(profile.get("target_complete_turns", TARGET_TURNS))
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var signature_order := _signature_order(faction)
	var session = _build_runtime_session(town_template, profile)
	var build_log := []
	var save_resume := {}
	var rare_spend_events := []
	var stalled_days := []

	for _turn in range(target_turns):
		var end_turn_result: Dictionary = OverworldRules.end_turn(session)
		if not bool(end_turn_result.get("ok", false)):
			stalled_days.append({"day": int(session.day), "reason": "end_turn_failed", "message": String(end_turn_result.get("message", ""))})
			continue
		_force_town_development_state(session)
		_set_active_town(session)
		var selected_id := _select_building_id(session, target_buildings, signature_order)
		if selected_id == "":
			stalled_days.append({"day": int(session.day), "reason": "no_affordable_build", "resources": _resources(session)})
			continue
		var before_resources := _resources(session)
		var selected_building := ContentService.get_building(selected_id)
		var build_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
		if not bool(build_result.get("ok", false)):
			stalled_days.append({"day": int(session.day), "reason": "build_failed", "building_id": selected_id, "message": String(build_result.get("message", ""))})
			continue
		var after_resources := _resources(session)
		var rare_delta := _rare_resource_spend(selected_building.get("cost", {}), before_resources, after_resources)
		if not rare_delta.is_empty():
			rare_spend_events.append({"day": int(session.day), "building_id": selected_id, "spent": rare_delta})
		build_log.append({
			"day": int(session.day),
			"building_id": selected_id,
			"rare_spend": rare_delta,
			"resources_before": before_resources,
			"resources_after": after_resources,
		})
		if save_resume.is_empty() and not rare_delta.is_empty():
			save_resume = _save_resume_checkpoint(session, selected_id)
			if save_resume.has("session"):
				session = save_resume.get("session")
			if not bool(save_resume.get("ok", false)):
				break
		if _missing_buildings(session, target_buildings).is_empty():
			break

	var missing := _missing_buildings(session, target_buildings)
	return {
		"town_id": town_id,
		"faction_id": String(faction.get("id", "")),
		"target_turns": target_turns,
		"target_building_count": target_buildings.size(),
		"completed": missing.is_empty(),
		"completion_day": int(build_log[-1].get("day", 0)) if not build_log.is_empty() else 0,
		"build_count": build_log.size(),
		"missing_buildings": missing,
		"rare_spend_events": rare_spend_events,
		"save_resume_ok": bool(save_resume.get("ok", false)),
		"rare_resume_ok": bool(save_resume.get("rare_resume_ok", false)),
		"same_day_guard_after_restore": bool(save_resume.get("same_day_guard_after_restore", false)),
		"build_actions_after_restore_blocked": bool(save_resume.get("build_actions_after_restore_blocked", false)),
		"resume_target_town": bool(save_resume.get("resume_target_town", false)),
		"save_version": int(save_resume.get("save_version", 0)),
		"save_resume": _without_session(save_resume),
		"ending_resources": _resources(session),
		"stalled_days": stalled_days.slice(0, 5),
		"build_log": build_log,
	}

func _save_resume_checkpoint(session, built_building_id: String) -> Dictionary:
	_force_town_development_state(session)
	var before_signature := _development_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		return {"ok": false, "stage": "save", "message": String(save_result.get("message", ""))}
	var summary: Dictionary = SaveService.inspect_manual_slot(SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if restored == null:
		return {"ok": false, "stage": "restore", "summary": summary}
	OverworldRules.normalize_overworld_state(restored)
	_force_town_development_state(restored)
	var active_town_flag_preserved := String(restored.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, "")) == PLAYER_TOWN_PLACEMENT_ID
	_set_active_town(restored)
	var after_signature := _development_signature(restored)
	var same_day_result: Dictionary = OverworldRules.build_in_active_town(restored, built_building_id)
	var same_day_guard_ok := (
		not bool(same_day_result.get("ok", true))
		and String(same_day_result.get("message", "")).contains("already completed a build order today")
	)
	var actions_blocked := TownRules.get_build_actions(restored).is_empty()
	var signature_ok := _signatures_match(before_signature, after_signature)
	var resume_target_town := String(summary.get("resume_target", "")) == "town"
	return {
		"ok": signature_ok and same_day_guard_ok and actions_blocked and resume_target_town and active_town_flag_preserved,
		"session": restored,
		"slot": SAVE_SLOT,
		"built_building_id": built_building_id,
		"rare_resume_ok": _rare_resource_spent_in_signature(before_signature, after_signature),
		"same_day_guard_after_restore": same_day_guard_ok,
		"build_actions_after_restore_blocked": actions_blocked,
		"resume_target_town": resume_target_town,
		"active_town_flag_preserved": active_town_flag_preserved,
		"signature_ok": signature_ok,
		"signature_before": before_signature,
		"signature_after": after_signature,
		"same_day_reject_message": String(same_day_result.get("message", "")),
		"summary_resume_target": String(summary.get("resume_target", "")),
		"save_version": int(restored.save_version),
	}

func _force_town_development_state(session) -> void:
	session.game_state = "town"
	session.scenario_status = "in_progress"

func _development_signature(session) -> Dictionary:
	var town := _town(session)
	return {
		"save_version": int(session.save_version),
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"game_state": String(session.game_state),
		"scenario_status": String(session.scenario_status),
		"active_town_placement_id": String(session.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, "")),
		"resources": _resources(session),
		"built_buildings": _string_array(town.get("built_buildings", [])),
		"last_build_day": int(town.get("last_build_day", 0)),
		"available_recruits": _int_dictionary(town.get("available_recruits", {})),
	}

func _signatures_match(before: Dictionary, after: Dictionary) -> bool:
	return JSON.stringify(before) == JSON.stringify(after)

func _rare_resource_spent_in_signature(before: Dictionary, after: Dictionary) -> bool:
	var before_resources: Dictionary = before.get("resources", {}) if before.get("resources", {}) is Dictionary else {}
	var after_resources: Dictionary = after.get("resources", {}) if after.get("resources", {}) is Dictionary else {}
	for resource_id in RARE_RESOURCE_IDS:
		if int(before_resources.get(resource_id, 0)) > 0 or int(after_resources.get(resource_id, 0)) > 0:
			return true
	return false

func _without_session(payload: Dictionary) -> Dictionary:
	var result := {}
	for key in payload.keys():
		if String(key) == "session":
			continue
		result[key] = payload.get(key)
	return result

func _build_runtime_session(town_template: Dictionary, profile: Dictionary):
	var hero_template := ContentService.get_hero(HERO_ID)
	var hero := HeroCommandRules.build_hero_from_template(
		hero_template,
		{"x": 0, "y": 0},
		{"id": "save_resume_balance_army", "name": "Save Resume Balance Army", "stacks": []},
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
		"save_resume_balance_%s" % String(town_template.get("id", "")),
		SAVE_SCENARIO_ID,
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
		_errors.append("Unable to select save/resume town: %s" % String(result.get("message", "")))

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
				"placement_id": "save_resume_income_%s_%03d" % [resource_id, node_index],
				"site_id": String(source.get("site_id", "")),
				"x": 1 + (node_index % 2),
				"y": 1 + int(node_index / 2),
				"collected": true,
				"collected_by_faction_id": "player",
				"collected_day": 0,
			})
			node_index += 1
	return nodes

func _missing_buildings(session, target_buildings: Array) -> Array:
	var built := _string_array(_town(session).get("built_buildings", []))
	var missing := []
	for building_id in target_buildings:
		if String(building_id) not in built:
			missing.append(String(building_id))
	return missing

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

func _int_dictionary(value: Variant) -> Dictionary:
	var result := {}
	var source: Dictionary = value if value is Dictionary else {}
	for key in source.keys():
		result[String(key)] = int(source.get(key, 0))
	return result
