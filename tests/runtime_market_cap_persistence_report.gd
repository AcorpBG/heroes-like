extends Node

const SCENARIO_ID := "glassroad-sundering"
const PLAYER_TOWN := "halo_spire_bridgehead"
const MARKET_BUILDING := "building_market_square"
const SMUGGLER_SCENARIO_ID := "nightglass-redoubt"
const SMUGGLER_TOWN := "reedbarrow_bridgehead"
const SMUGGLER_BUILDING := "building_smugglers_flotilla"
const STOCKPILE_KEYS := [
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
	_prepare_market_fixture(session)
	if _failed:
		return

	var initial := _market_snapshot(session, "initial")
	_assert_action_state(initial, "market:buy:wood:1", false, 6, "initial buy wood")
	_assert_action_state(initial, "market:sell:ore:1", false, 8, "initial sell ore")
	_assert_common_only(initial)
	if _failed:
		return

	var buy_results := _perform_repeated(session, "market:buy:wood:1", 6, "buy wood cap")
	var after_buy_cap := _market_snapshot(session, "after_buy_cap")
	_assert_action_state(after_buy_cap, "market:buy:wood:1", true, 0, "after buy cap")
	var rejected_buy: Dictionary = TownRules.perform_market_action(session, "market:buy:wood:1")
	_assert_not_ok("buy over cap", rejected_buy)
	_assert_contains(String(rejected_buy.get("message", "")), "Weekly market cap reached", "buy over cap message")
	if _failed:
		return

	var sell_results := _perform_repeated(session, "market:sell:ore:1", 8, "sell ore cap")
	var after_sell_cap := _market_snapshot(session, "after_sell_cap")
	_assert_action_state(after_sell_cap, "market:sell:ore:1", true, 0, "after sell cap")
	var rejected_sell: Dictionary = TownRules.perform_market_action(session, "market:sell:ore:1")
	_assert_not_ok("sell over cap", rejected_sell)
	_assert_contains(String(rejected_sell.get("message", "")), "Weekly market cap reached", "sell over cap message")
	if _failed:
		return

	var resume := _save_and_resume(session)
	if _failed:
		return
	var restored = resume.get("session")
	var restored_snapshot := _market_snapshot(restored, "restored_same_week")
	_assert_action_state(restored_snapshot, "market:buy:wood:1", true, 0, "restored buy cap")
	_assert_action_state(restored_snapshot, "market:sell:ore:1", true, 0, "restored sell cap")
	if _failed:
		return

	var advanced := _advance_to_next_week(restored)
	var next_week := _market_snapshot(restored, "next_week")
	_assert_action_state(next_week, "market:buy:wood:1", false, 6, "next week buy reset")
	_assert_action_state(next_week, "market:sell:ore:1", false, 8, "next week sell reset")
	if _failed:
		return
	var smuggler_case := _run_smuggler_profile_case()
	if _failed:
		return

	var payload := {
		"ok": true,
		"schema": "runtime_market_cap_persistence_report_v1",
		"scenario_id": SCENARIO_ID,
		"town_placement_id": PLAYER_TOWN,
		"market_building_id": MARKET_BUILDING,
		"policy": {
			"normal_market_resource_ids": ["wood", "ore"],
			"rare_resource_buying_enabled": false,
			"refresh_cadence": "weekly",
			"usage_storage": "town.market_usage",
			"save_version_bump": false,
		},
		"initial": initial,
		"buy_results": buy_results,
		"after_buy_cap": after_buy_cap,
		"sell_results": sell_results,
		"after_sell_cap": after_sell_cap,
		"save_resume": resume.get("report", {}),
		"restored_same_week": restored_snapshot,
		"next_week_advance": advanced,
		"next_week": next_week,
		"smuggler_profile": smuggler_case,
		"caveats": [
			"Fixture seeds stockpiles to isolate market cap behavior.",
			"Normal markets remain common-resource only; rare-resource sourcing remains tied to authored income, sites, and high-tier costs.",
			"AI projected market affordability uses the same cap-aware readiness helpers, but this report focuses on live player exchange mutation and save continuity.",
		],
	}
	print("RUNTIME_MARKET_CAP_PERSISTENCE_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _run_smuggler_profile_case() -> Dictionary:
	var session = ScenarioFactory.create_session(
		SMUGGLER_SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	_set_full_stockpile(session, {
		"gold": 100000,
		"wood": 40,
		"ore": 40,
	})
	var town_result := _town_result_by_placement(session, SMUGGLER_TOWN)
	if int(town_result.get("index", -1)) < 0:
		_fail("Missing smuggler town %s" % SMUGGLER_TOWN)
		return {}
	var towns: Array = session.overworld.get("towns", [])
	var town: Dictionary = town_result.get("town", {})
	var built: Array = town.get("built_buildings", []) if town.get("built_buildings", []) is Array else []
	built = built.duplicate(true)
	for building_id in ["building_market_square", "building_wayfarers_hall"]:
		if building_id not in built:
			built.append(building_id)
	built.erase(SMUGGLER_BUILDING)
	town["built_buildings"] = built
	town["market_usage"] = {}
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, SMUGGLER_TOWN)
	_assert_ok("set smuggler comparison town", visit_result)
	var square_state: Dictionary = OverworldRules.town_market_state(town)

	built.append(SMUGGLER_BUILDING)
	town["built_buildings"] = built
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	OverworldRules.normalize_overworld_state(session)
	visit_result = OverworldRules.set_active_town_visit(session, SMUGGLER_TOWN)
	_assert_ok("set active smuggler town", visit_result)
	town = _town_by_placement(session, SMUGGLER_TOWN)
	var smuggler_state: Dictionary = OverworldRules.town_market_state(town)
	if String(smuggler_state.get("profile", "")) != "smugglers" \
			or String(smuggler_state.get("building_id", "")) != SMUGGLER_BUILDING \
			or int(smuggler_state.get("tier", 0)) != 2:
		_fail("Smugglers Flotilla did not supersede Market Square: %s" % smuggler_state)
		return {}
	var bulk_resources: Array = smuggler_state.get("bulk_resources", []) if smuggler_state.get("bulk_resources", []) is Array else []
	if bulk_resources != ["wood", "ore"] or int(smuggler_state.get("bulk_amount", 0)) != 2:
		_fail("Smuggler profile did not expose both bounded two-crate lots: %s" % smuggler_state)
		return {}
	for resource_id in ["wood", "ore"]:
		if int(smuggler_state.get("sell_rates", {}).get(resource_id, 0)) <= int(square_state.get("sell_rates", {}).get(resource_id, 0)):
			_fail("Smuggler profile did not improve %s liquidation over Market Square." % resource_id)
			return {}
		if int(smuggler_state.get("buy_caps", {}).get(resource_id, 0)) != 8 \
				or int(smuggler_state.get("sell_caps", {}).get(resource_id, 0)) != 10:
			_fail("Smuggler profile did not apply bounded weekly %s throughput: %s" % [resource_id, smuggler_state])
			return {}

	var actions := []
	for action_value in TownRules.get_market_actions(session):
		if action_value is Dictionary:
			actions.append(_action_snapshot(action_value))
	var before := {
		"resources": _resources(session),
		"state": smuggler_state,
		"actions": actions,
		"panel": TownRules.describe_market(session),
	}
	for action_id in ["market:buy:wood:2", "market:sell:wood:2", "market:buy:ore:2", "market:sell:ore:2"]:
		var action := _action_by_id(before, action_id)
		if action.is_empty() or bool(action.get("disabled", true)):
			_fail("Smuggler profile is missing ready flexible bulk action %s: %s" % [action_id, before])
			return {}
	_assert_common_only(before)
	_assert_contains(String(before.get("panel", "")), "Smugglers Flotilla", "smuggler exchange panel")
	_assert_contains(String(before.get("panel", "")), "captured cargo", "smuggler specialty panel")
	if _failed:
		return {}

	var starting_gold := int(session.overworld.get("resources", {}).get("gold", 0))
	var starting_ore := int(session.overworld.get("resources", {}).get("ore", 0))
	var unit_sell_rate := int(smuggler_state.get("sell_rates", {}).get("ore", 0))
	var expected_bulk_gold := maxi(1, int(round(float(unit_sell_rate * 2) * 1.1)))
	var result: Dictionary = TownRules.perform_market_action(session, "market:sell:ore:2")
	_assert_ok("smuggler bulk ore liquidation", result)
	_assert_contains(String(result.get("message", "")), "through Smugglers Flotilla", "smuggler execution message")
	var after_town := _town_by_placement(session, SMUGGLER_TOWN)
	if int(session.overworld.get("resources", {}).get("gold", 0)) != starting_gold + expected_bulk_gold \
			or int(session.overworld.get("resources", {}).get("ore", 0)) != starting_ore - 2 \
			or int(after_town.get("market_usage", {}).get("sell", {}).get("ore", 0)) != 2:
		_fail("Smuggler bulk liquidation did not mutate resources and shared cap usage exactly: %s" % result)
		return {}
	var after_actions := []
	for action_value in TownRules.get_market_actions(session):
		if action_value is Dictionary:
			after_actions.append(_action_snapshot(action_value))
	var after := {
		"resources": _resources(session),
		"actions": after_actions,
		"usage": after_town.get("market_usage", {}),
	}
	_assert_action_state(after, "market:sell:ore:1", false, 8, "smuggler shared single cap")
	_assert_action_state(after, "market:sell:ore:2", false, 8, "smuggler shared bulk cap")
	return {
		"ok": not _failed,
		"scenario_id": SMUGGLER_SCENARIO_ID,
		"town_placement_id": SMUGGLER_TOWN,
		"market_building_id": SMUGGLER_BUILDING,
		"square_state": square_state,
		"before": before,
		"bulk_sell_result": result,
		"expected_bulk_gold": expected_bulk_gold,
		"after": after,
	}

func _prepare_market_fixture(session) -> void:
	_set_full_stockpile(session, {
		"gold": 100000,
		"wood": 40,
		"ore": 40,
	})
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == PLAYER_TOWN:
			var built: Array = town.get("built_buildings", []) if town.get("built_buildings", []) is Array else []
			built = built.duplicate(true)
			if MARKET_BUILDING not in built:
				built.append(MARKET_BUILDING)
			town["built_buildings"] = built
			town["market_usage"] = {}
			towns[index] = town
			session.overworld["towns"] = towns
			var result: Dictionary = OverworldRules.set_active_town_visit(session, PLAYER_TOWN)
			_assert_ok("set active town", result)
			return
	_fail("Missing player town %s" % PLAYER_TOWN)

func _market_snapshot(session, label: String) -> Dictionary:
	OverworldRules.normalize_overworld_state(session)
	var result: Dictionary = OverworldRules.set_active_town_visit(session, PLAYER_TOWN)
	_assert_ok("set active town %s" % label, result)
	var town := _town(session)
	var actions := []
	for action_value in TownRules.get_market_actions(session):
		if action_value is Dictionary:
			actions.append(_action_snapshot(action_value))
	return {
		"label": label,
		"day": int(session.day),
		"week": int(floori(float(max(int(session.day), 1) - 1) / 7.0)) + 1,
		"resources": _resources(session),
		"market_state": OverworldRules.town_market_state(town),
		"market_usage": town.get("market_usage", {}),
		"actions": actions,
		"panel": TownRules.describe_market(session),
	}

func _perform_repeated(session, action_id: String, count: int, label: String) -> Array:
	var results := []
	for index in range(count):
		var result: Dictionary = TownRules.perform_market_action(session, action_id)
		_assert_ok("%s %d" % [label, index + 1], result)
		results.append({
			"index": index + 1,
			"ok": bool(result.get("ok", false)),
			"message": String(result.get("message", "")),
			"resources": _resources(session),
			"usage": _town(session).get("market_usage", {}),
		})
		if _failed:
			return results
	return results

func _save_and_resume(session) -> Dictionary:
	var before := _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, 4)
	_assert_ok("save capped market", save_result)
	if _failed:
		return {}
	var restored = SaveService.restore_manual_session(4)
	if restored == null:
		_fail("restore returned null")
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var after := _session_signature(restored)
	if JSON.stringify(before) != JSON.stringify(after):
		_fail("market cap save signature mismatch before=%s after=%s" % [before, after])
		return {}
	return {
		"session": restored,
		"report": {
			"ok": true,
			"slot": 4,
			"signature_before": before,
			"signature_after": after,
		},
	}

func _advance_to_next_week(session) -> Dictionary:
	var start_day := int(session.day)
	while int(session.day) < 8:
		var result: Dictionary = OverworldRules.end_turn(session)
		_assert_ok("advance day %d" % int(session.day), result)
		if _failed:
			return {}
	OverworldRules.normalize_overworld_state(session)
	return {
		"start_day": start_day,
		"end_day": int(session.day),
		"market_usage_after_normalize": _town(session).get("market_usage", {}),
	}

func _set_full_stockpile(session, values: Dictionary) -> void:
	var resources := {}
	for key in STOCKPILE_KEYS:
		resources[key] = int(values.get(key, 0))
	session.overworld["resources"] = resources

func _session_signature(session) -> Dictionary:
	return {
		"save_version": int(session.save_version),
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"resources": _resources(session),
		"town_market_usage": _town(session).get("market_usage", {}),
	}

func _action_snapshot(action_value: Variant) -> Dictionary:
	var action: Dictionary = action_value if action_value is Dictionary else {}
	return {
		"id": String(action.get("id", "")),
		"label": String(action.get("label", "")),
		"summary": String(action.get("summary", "")),
		"disabled": bool(action.get("disabled", false)),
		"disabled_reason": String(action.get("disabled_reason", "")),
		"cap_week": int(action.get("cap_week", 0)),
		"cap_used": int(action.get("cap_used", 0)),
		"cap_limit": int(action.get("cap_limit", 0)),
		"cap_remaining": int(action.get("cap_remaining", 0)),
		"refresh_cadence": String(action.get("refresh_cadence", "")),
	}

func _action_by_id(snapshot: Dictionary, action_id: String) -> Dictionary:
	for action_value in snapshot.get("actions", []):
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return action_value
	return {}

func _town(session) -> Dictionary:
	var town := _town_by_placement(session, PLAYER_TOWN)
	if not town.is_empty():
		return town
	_fail("Missing town %s" % PLAYER_TOWN)
	return {}

func _town_by_placement(session, placement_id: String) -> Dictionary:
	return _town_result_by_placement(session, placement_id).get("town", {})

func _town_result_by_placement(session, placement_id: String) -> Dictionary:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

func _resources(session) -> Dictionary:
	var result := {}
	for key in STOCKPILE_KEYS:
		result[key] = int(session.overworld.get("resources", {}).get(key, 0))
	return result

func _assert_action_state(snapshot: Dictionary, action_id: String, disabled: bool, remaining: int, label: String) -> void:
	var action := _action_by_id(snapshot, action_id)
	if action.is_empty():
		_fail("%s missing action %s" % [label, action_id])
		return
	if bool(action.get("disabled", false)) != disabled:
		_fail("%s expected disabled=%s for %s, got %s" % [label, disabled, action_id, action])
		return
	if int(action.get("cap_remaining", -1)) != remaining:
		_fail("%s expected cap_remaining=%d for %s, got %s" % [label, remaining, action_id, action])

func _assert_common_only(snapshot: Dictionary) -> void:
	for action_value in snapshot.get("actions", []):
		if not (action_value is Dictionary):
			continue
		var action_id := String(action_value.get("id", ""))
		var parts := action_id.split(":")
		if parts.size() >= 3 and String(parts[2]) not in ["wood", "ore"]:
			_fail("Market exposed non-common resource action %s" % action_id)
			return

func _assert_ok(label: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_fail("%s failed: %s" % [label, result])

func _assert_not_ok(label: String, result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_fail("%s unexpectedly succeeded: %s" % [label, result])

func _assert_contains(value: String, expected: String, label: String) -> void:
	if not value.contains(expected):
		_fail("%s expected %s in %s" % [label, expected, value])

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("RUNTIME_MARKET_CAP_PERSISTENCE_REPORT %s" % JSON.stringify({
		"ok": false,
		"schema": "runtime_market_cap_persistence_report_v1",
		"scenario_id": SCENARIO_ID,
		"error": message,
	}))
	get_tree().quit(1)
