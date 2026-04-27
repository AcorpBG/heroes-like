extends Node

const SCENARIO_ID := "glassroad-sundering"
const PLAYER_TOWN := "halo_spire_bridgehead"
const RELAY_SITE := "glassroad_watch_relay"
const LENS_HOUSE_SITE := "glassroad_lens_house"
const WOOD_PICKUP := "glassroad_wood"
const ORE_PICKUP := "glassroad_ore"
const CASH_PICKUP := "market_cache"
const MARKET_BUILDING := "building_market_square"
const UPGRADE_BUILDING := "building_starseer_annex"
const RECRUIT_UNIT := "unit_prism_adept"
const STOCKPILE_KEYS := ["gold", "wood", "ore"]

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	_assert_stockpile_keys("starting resources", session.overworld.get("resources", {}))
	if _failed:
		return

	_move_to_town(session, PLAYER_TOWN)
	var baseline := {
		"day": int(session.day),
		"resources": _resources(session),
		"town": _town_decision_snapshot(session, "baseline"),
		"army": _army_counts(session),
		"controlled_site_income": OverworldRules.controlled_resource_site_income(session, "player"),
	}

	var relay_claim := _claim_site(session, RELAY_SITE)
	if _failed:
		return
	var relay_day := _advance_day(session, "relay_income_day")
	if _failed:
		return
	_assert_resource_amount("relay day income", relay_day.get("site_income", {}), "gold", 25)
	_assert_message_contains(relay_day.get("message", ""), "Field sites yield 25 gold", "relay income message")
	if _failed:
		return

	var lens_claim := _claim_site(session, LENS_HOUSE_SITE)
	if _failed:
		return
	_assert_army_at_least("lens-house claim recruits", session, "unit_shard_guard", 1)
	_assert_army_at_least("lens-house claim recruits", session, RECRUIT_UNIT, 1)
	var lens_day := _advance_day(session, "relay_and_lens_income_day")
	if _failed:
		return
	_assert_resource_amount("relay plus lens day income", lens_day.get("site_income", {}), "gold", 70)
	_assert_message_contains(lens_day.get("message", ""), "Field sites yield 70 gold", "relay plus lens income message")
	if _failed:
		return

	var wood_claim := _claim_site(session, WOOD_PICKUP)
	if _failed:
		return
	var ore_claim := _claim_site(session, ORE_PICKUP)
	if _failed:
		return
	var cash_claim := _claim_site(session, CASH_PICKUP)
	if _failed:
		return
	_assert_stockpile_keys("post pickup resources", session.overworld.get("resources", {}))
	if _failed:
		return

	_move_to_town(session, PLAYER_TOWN)
	var before_market := _town_decision_snapshot(session, "before_market_build")
	var market_result: Dictionary = OverworldRules.build_in_active_town(session, MARKET_BUILDING)
	_assert_ok("market build", market_result)
	if _failed:
		return
	var after_market := _town_decision_snapshot(session, "after_market_build")
	_move_to_town(session, PLAYER_TOWN)
	var recruit_result: Dictionary = OverworldRules.recruit_in_active_town(session, RECRUIT_UNIT, 1)
	_assert_ok("post-market recruit", recruit_result)
	if _failed:
		return
	var after_spend := _town_decision_snapshot(session, "after_market_and_recruit")

	var save_resume := _save_and_resume_signature(session)
	if _failed:
		return

	var payload := {
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"selected_front": "glassroad_relay_lens_house",
		"resource_policy": {
			"live_stockpile_keys": STOCKPILE_KEYS,
			"wood_canonical": true,
			"rare_resources": "staged_report_only",
			"save_version": SessionStateStore.SAVE_VERSION,
		},
		"baseline": baseline,
		"claims": [
			relay_claim,
			lens_claim,
			wood_claim,
			ore_claim,
			cash_claim,
		],
		"income_days": [
			relay_day,
			lens_day,
		],
		"town_decisions": {
			"before_market": before_market,
			"market_result": _action_snapshot(market_result),
			"after_market": after_market,
			"starseer_annex_after_market": after_market.get("build_upgrade", {}),
			"recruit_result": _action_snapshot(recruit_result),
			"after_spend": after_spend,
		},
		"save_resume": save_resume,
		"caveats": [
			"Fixture positions the hero on selected sites to exercise current economy rules deterministically.",
			"No rare resources, save migration, market migration, hidden grants, or broad rebalance are used.",
			"Battle/path viability is covered by existing Glassroad proof surfaces; this report focuses on capture, income, spend, recruit, and save continuity.",
		],
	}
	print("ECONOMY_CAPTURE_INCOME_EXPANSION_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _claim_site(session, placement_id: String) -> Dictionary:
	var before_resources := _resources(session)
	var before_army := _army_counts(session)
	_move_to_resource(session, placement_id)
	var before_controller := _resource_controller(session, placement_id)
	var result: Dictionary = OverworldRules.collect_active_resource(session)
	_assert_ok("claim %s" % placement_id, result)
	if _failed:
		return {}
	var node := _resource_node(session, placement_id)
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	_assert_stockpile_keys("%s claim resources" % placement_id, session.overworld.get("resources", {}))
	return {
		"placement_id": placement_id,
		"site_id": String(node.get("site_id", "")),
		"site_name": String(site.get("name", "")),
		"family": String(site.get("family", "")),
		"persistent_control": bool(site.get("persistent_control", false)),
		"controller_before": before_controller,
		"controller_after": _resource_controller(session, placement_id),
		"claim_rewards": site.get("claim_rewards", site.get("rewards", {})),
		"control_income": site.get("control_income", {}),
		"claim_recruits": site.get("claim_recruits", {}),
		"resources_before": before_resources,
		"resources_after": _resources(session),
		"army_before": before_army,
		"army_after": _army_counts(session),
		"message": String(result.get("message", "")),
	}

func _advance_day(session, label: String) -> Dictionary:
	var before_resources := _resources(session)
	var expected_site_income := OverworldRules.controlled_resource_site_income(session, "player")
	var result: Dictionary = OverworldRules.end_turn(session)
	_assert_ok(label, result)
	if _failed:
		return {}
	_assert_stockpile_keys("%s resources" % label, session.overworld.get("resources", {}))
	return {
		"label": label,
		"day": int(session.day),
		"resources_before": before_resources,
		"resources_after": _resources(session),
		"site_income": expected_site_income,
		"resource_income_summary": String(result.get("resource_income_summary", "")),
		"turn_resolution_summary": String(result.get("turn_resolution_summary", "")),
		"message": String(result.get("message", "")),
	}

func _town_decision_snapshot(session, label: String) -> Dictionary:
	_move_to_town(session, PLAYER_TOWN)
	var town := _town(session, PLAYER_TOWN)
	var build_actions := TownRules.get_build_actions(session)
	var recruit_actions := TownRules.get_recruit_actions(session)
	var market_actions := TownRules.get_market_actions(session)
	var market_action_ids := []
	for action in market_actions:
		if action is Dictionary:
			market_action_ids.append(String(action.get("id", "")))
	return {
		"label": label,
		"day": int(session.day),
		"resources": _resources(session),
		"built_buildings": town.get("built_buildings", []),
		"available_recruits": town.get("available_recruits", {}),
		"market_action_count": market_action_ids.size(),
		"market_action_ids": market_action_ids,
		"build_market": _action_by_id(build_actions, "build:%s" % MARKET_BUILDING),
		"build_upgrade": _action_by_id(build_actions, "build:%s" % UPGRADE_BUILDING),
		"recruit_unit": _action_by_id(recruit_actions, "recruit:%s" % RECRUIT_UNIT),
	}

func _save_and_resume_signature(session) -> Dictionary:
	var before := _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, 3)
	_assert_ok("manual save", save_result)
	if _failed:
		return {}
	var restored = SaveService.restore_manual_session(3)
	if restored == null:
		_fail("manual save restore returned null")
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var after := _session_signature(restored)
	if JSON.stringify(before) != JSON.stringify(after):
		_fail("save/resume signature mismatch: before=%s after=%s" % [before, after])
		return {}
	return {
		"ok": true,
		"slot": 3,
		"summary": _save_summary_snapshot(save_result.get("summary", {})),
		"signature_before": before,
		"signature_after": after,
	}

func _save_summary_snapshot(summary_value: Variant) -> Dictionary:
	var summary: Dictionary = summary_value if summary_value is Dictionary else {}
	return {
		"valid": bool(summary.get("valid", false)),
		"validity": String(summary.get("validity", "")),
		"loadable": bool(summary.get("loadable", false)),
		"slot_type": String(summary.get("slot_type", "")),
		"slot_id": String(summary.get("slot_id", "")),
		"resume_target": String(summary.get("resume_target", "")),
		"scenario_id": String(summary.get("scenario_id", "")),
		"scenario_status": String(summary.get("scenario_status", "")),
		"game_state": String(summary.get("game_state", "")),
		"day": int(summary.get("day", 0)),
		"save_version": int(summary.get("save_version", 0)),
	}

func _session_signature(session) -> Dictionary:
	return {
		"save_version": int(session.save_version),
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"game_state": String(session.game_state),
		"scenario_status": String(session.scenario_status),
		"resources": _resources(session),
		"controlled_sites": {
			RELAY_SITE: _resource_controller(session, RELAY_SITE),
			LENS_HOUSE_SITE: _resource_controller(session, LENS_HOUSE_SITE),
			WOOD_PICKUP: _resource_controller(session, WOOD_PICKUP),
			ORE_PICKUP: _resource_controller(session, ORE_PICKUP),
			CASH_PICKUP: _resource_controller(session, CASH_PICKUP),
		},
		"town": {
			"placement_id": PLAYER_TOWN,
			"built_buildings": _town(session, PLAYER_TOWN).get("built_buildings", []),
			"available_recruits": _town(session, PLAYER_TOWN).get("available_recruits", {}),
		},
		"army": _army_counts(session),
	}

func _move_to_resource(session, placement_id: String) -> void:
	var node := _resource_node(session, placement_id)
	_set_hero_position(session, int(node.get("x", 0)), int(node.get("y", 0)))

func _move_to_town(session, placement_id: String) -> void:
	var town := _town(session, placement_id)
	_set_hero_position(session, int(town.get("x", 0)), int(town.get("y", 0)))

func _set_hero_position(session, x: int, y: int) -> void:
	session.overworld["hero_position"] = {"x": x, "y": y}
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = {"x": x, "y": y}
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.hero_id):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["position"] = {"x": x, "y": y}
			heroes[index] = roster_hero
			break
	session.overworld["player_heroes"] = heroes

func _resource_node(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	_fail("Missing resource placement %s" % placement_id)
	return {}

func _resource_controller(session, placement_id: String) -> String:
	var node := _resource_node(session, placement_id)
	return String(node.get("collected_by_faction_id", ""))

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	_fail("Missing town placement %s" % placement_id)
	return {}

func _resources(session) -> Dictionary:
	var result := {}
	for key in STOCKPILE_KEYS:
		result[String(key)] = int(session.overworld.get("resources", {}).get(String(key), 0))
	return result

func _army_counts(session) -> Dictionary:
	var counts := {}
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if stack is Dictionary:
			var unit_id := String(stack.get("unit_id", ""))
			counts[unit_id] = int(counts.get(unit_id, 0)) + int(stack.get("count", 0))
	return counts

func _action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action in actions:
		if action is Dictionary and String(action.get("id", "")) == action_id:
			return _action_snapshot(action)
	return {}

func _action_snapshot(action: Dictionary) -> Dictionary:
	return {
		"id": String(action.get("id", "")),
		"label": String(action.get("label", "")),
		"message": String(action.get("message", "")),
		"cost": action.get("cost", action.get("unit_cost", {})),
		"direct_affordable": bool(action.get("direct_affordable", false)),
		"direct_affordable_count": int(action.get("direct_affordable_count", 0)),
		"market_coverable": bool(action.get("market_coverable", false)),
		"market_action_count": int(action.get("market_action_count", 0)),
		"affordability_label": String(action.get("affordability_label", "")),
		"shortfall_summary": String(action.get("shortfall_summary", "")),
		"summary": String(action.get("summary", "")),
	}

func _assert_stockpile_keys(label: String, resources: Variant) -> void:
	if not (resources is Dictionary):
		_fail("%s was not a resource dictionary" % label)
		return
	for key in resources.keys():
		var resource_id := String(key)
		if resource_id not in STOCKPILE_KEYS:
			_fail("%s introduced unsupported stockpile key %s" % [label, resource_id])
			return

func _assert_resource_amount(label: String, resources: Variant, resource_id: String, expected: int) -> void:
	if not (resources is Dictionary):
		_fail("%s resources were not a dictionary" % label)
		return
	if int(resources.get(resource_id, 0)) != expected:
		_fail("%s expected %s=%d, got %s" % [label, resource_id, expected, resources])

func _assert_message_contains(message: String, expected: String, label: String) -> void:
	if not message.contains(expected):
		_fail("%s expected message token %s, got %s" % [label, expected, message])

func _assert_army_at_least(label: String, session, unit_id: String, minimum: int) -> void:
	var counts := _army_counts(session)
	if int(counts.get(unit_id, 0)) < minimum:
		_fail("%s expected at least %d %s in army, got %s" % [label, minimum, unit_id, counts])

func _assert_ok(label: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_fail("%s failed: %s" % [label, result])

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	var payload := {
		"ok": false,
		"scenario_id": SCENARIO_ID,
		"error": message,
	}
	push_error(message)
	print("ECONOMY_CAPTURE_INCOME_EXPANSION_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(1)
