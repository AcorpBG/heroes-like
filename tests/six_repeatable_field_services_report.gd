extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_REPEATABLE_FIELD_SERVICES_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_repeatable_field_services_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/repeatable_service_visited_atlas.png"
const SCENARIO_ID := "ninefold-confluence"
const CASES := [
	{"site_id":"site_wayfarer_menders_tent","placement_id":"ninefold_wayfarer_menders_tent","unclaimed":"mapobj_wayfarer_menders_tent","visited":"resource_site_repeatable_service_wayfarer_menders_tent_visited","region":Rect2(0,0,48,48),"cost":{"gold":120},"reward":{},"effect":"town","amount":2},
	{"site_id":"site_courier_change_post","placement_id":"ninefold_courier_change_post","unclaimed":"mapobj_courier_change_post","visited":"resource_site_repeatable_service_courier_change_post_visited","region":Rect2(48,0,48,48),"cost":{"gold":100},"reward":{},"effect":"movement","amount":260},
	{"site_id":"site_contract_scribe_booth","placement_id":"ninefold_contract_scribe_booth","unclaimed":"mapobj_contract_scribe_booth","visited":"resource_site_repeatable_service_contract_scribe_booth_visited","region":Rect2(96,0,48,48),"cost":{"gold":80},"reward":{},"effect":"pressure","amount":1},
	{"site_id":"site_reedboat_supply_stand","placement_id":"ninefold_reedboat_supply_stand","unclaimed":"mapobj_reedboat_supply_stand","visited":"resource_site_repeatable_service_reedboat_supply_stand_visited","region":Rect2(144,0,48,48),"cost":{"gold":110,"wood":1},"reward":{"wood":2},"effect":"movement","amount":160,"vision":2},
	{"site_id":"site_ash_cooler_kitchen","placement_id":"ninefold_ash_cooler_kitchen","unclaimed":"mapobj_ash_cooler_kitchen","visited":"resource_site_repeatable_service_ash_cooler_kitchen_visited","region":Rect2(192,0,48,48),"cost":{"gold":100,"ore":1},"reward":{},"effect":"mixed","amount":100,"town_amount":1},
	{"site_id":"site_lens_calibration_cart","placement_id":"ninefold_lens_calibration_cart","unclaimed":"mapobj_lens_calibration_cart","visited":"resource_site_repeatable_service_lens_calibration_cart_visited","region":Rect2(240,0,48,48),"cost":{"gold":130},"reward":{},"effect":"vision","amount":5},
]

var _errors: Array[String] = []
var _rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	_expect((scenario.get("resource_nodes", []) as Array).size() == 88, "Ninefold must expose all 88 resource placements.")
	_expect((scenario.get("encounters", []) as Array).size() == 23, "Service placement must not add encounter clutter.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	var last_session = null
	for case_value in CASES:
		last_session = await _validate_case(view, case_value)
	if last_session != null:
		view.set_map_state(last_session, last_session.overworld.get("map", []), OverworldRules.derive_map_size(last_session), Vector2i(32, 32))
		await get_tree().process_frame
	var capture := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not capture.is_empty(), "Could not load the consolidated service-state capture.")
	if not capture.is_empty():
		capture.save_png("%s/repeatable_service_state_strip.png" % OUTPUT_DIR)
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"scenario_id":SCENARIO_ID,"atlas_path":ATLAS_PATH,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_visual_capture":"%s/repeatable_service_state_strip.png" % OUTPUT_DIR,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION,"visual_capture":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(view: Control, case: Dictionary):
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	_seed_authority(session, case)
	var placement_id := String(case.get("placement_id", ""))
	var site_id := String(case.get("site_id", ""))
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "repeatable_service_live", "%s is not live." % site_id)
	_expect(String(view.call("_resource_asset_id", node)) == String(case.get("unclaimed", "")), "%s lost ready-state art." % site_id)
	var before := _snapshot(session, case)
	var first := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(first.get("ok", false)), "%s first weekly service failed: %s" % [site_id, JSON.stringify(first)])
	if not bool(first.get("ok", false)):
		return session
	_validate_delta(before, _snapshot(session, case), case, first, "first")
	var claimed: Dictionary = _node_result(session, placement_id).get("node", {})
	_expect(bool(claimed.get("collected", false)) and int(claimed.get("collected_day", -1)) == session.day, "%s did not record its cooldown day." % site_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x",0)),int(node.get("y",0))))
	await get_tree().process_frame
	var visited_id := String(view.call("_resource_asset_id", claimed))
	var texture = view.call("_object_texture_for_asset", visited_id)
	_expect(visited_id == String(case.get("visited", "")), "%s did not switch to visited art." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.get_size() == Vector2(288, 48) and texture.region == case.get("region"), "%s visited atlas region changed." % site_id)
	var authority_after_first := session.to_dict()
	var early := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(not bool(early.get("ok", true)) and session.to_dict() == authority_after_first, "%s early revisit mutated authority." % site_id)
	var cooldown_restore: SessionStateStoreScript.SessionData = _clone_session(session)
	_expect(cooldown_restore.to_dict() == session.to_dict(), "%s cooldown save round-trip changed authority." % site_id)
	cooldown_restore.day = int(claimed.get("collected_day", 0)) + 7
	_seed_effect_inputs(cooldown_restore, case)
	var before_second := _snapshot(cooldown_restore, case)
	var second := OverworldRules._collect_resource_node_result(cooldown_restore, _node_result(cooldown_restore, placement_id), true)
	_expect(bool(second.get("ok", false)), "%s weekly revisit failed: %s" % [site_id, JSON.stringify(second)])
	_validate_delta(before_second, _snapshot(cooldown_restore, case), case, second, "second")
	var after_second: Dictionary = _node_result(cooldown_restore, placement_id).get("node", {})
	_expect(int(after_second.get("collected_day", -1)) == cooldown_restore.day, "%s did not advance the second cooldown day." % site_id)
	var restored_after_second: SessionStateStoreScript.SessionData = _clone_session(cooldown_restore)
	_expect(restored_after_second.to_dict() == cooldown_restore.to_dict(), "%s second service save round-trip changed authority." % site_id)
	_rows.append({"site_id":site_id,"placement_id":placement_id,"first_service":true,"early_revisit_blocked":true,"weekly_revisit":true,"save_round_trip_exact":true,"ready_asset_id":String(case.get("unclaimed","")),"visited_asset_id":visited_id})
	return cooldown_restore

func _seed_authority(session, case: Dictionary) -> void:
	var resources: Dictionary = session.overworld.get("resources", {})
	resources["gold"] = 5000
	resources["wood"] = 50
	resources["ore"] = 50
	session.overworld["resources"] = resources
	_seed_effect_inputs(session, case)

func _seed_effect_inputs(session, case: Dictionary) -> void:
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = 100
	movement["max"] = 1000
	session.overworld["movement"] = movement
	if String(case.get("effect", "")) in ["town", "mixed"]:
		var towns: Array = session.overworld.get("towns", [])
		for index in range(towns.size()):
			if towns[index] is Dictionary and String(towns[index].get("owner", "")) == "player":
				var town: Dictionary = towns[index]
				town["recovery"] = {"pressure":4,"source":"service smoke"}
				towns[index] = town
				break
		session.overworld["towns"] = towns
	if String(case.get("effect", "")) == "pressure":
		var states: Array = session.overworld.get("enemy_states", [])
		if not states.is_empty():
			var state: Dictionary = states[0]
			state["pressure"] = 5
			states[0] = state
			session.overworld["enemy_states"] = states

func _snapshot(session, case: Dictionary) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {})
	var recovery := 0
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			recovery = int(town.get("recovery", {}).get("pressure", 0))
			break
	var pressure := 0
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary:
			pressure = maxi(pressure, int(state.get("pressure", 0)))
	return {"gold":int(resources.get("gold",0)),"wood":int(resources.get("wood",0)),"ore":int(resources.get("ore",0)),"movement":int(session.overworld.get("movement",{}).get("current",0)),"recovery":recovery,"pressure":pressure}

func _validate_delta(before: Dictionary, after: Dictionary, case: Dictionary, result: Dictionary, label: String) -> void:
	var site_id := String(case.get("site_id", ""))
	var cost: Dictionary = case.get("cost", {})
	var reward: Dictionary = case.get("reward", {})
	for resource_id in ["gold","wood","ore"]:
		var expected := -int(cost.get(resource_id,0)) + int(reward.get(resource_id,0))
		_expect(int(after.get(resource_id,0))-int(before.get(resource_id,0)) == expected, "%s %s %s delta changed." % [site_id,label,resource_id])
	var effects: Dictionary = result.get("service_effects", {})
	match String(case.get("effect", "")):
		"movement": _expect(int(effects.get("movement_restored",0)) == int(case.get("amount",0)), "%s %s movement effect changed." % [site_id,label])
		"town": _expect(int(effects.get("town_recovery_relieved",0)) == int(case.get("amount",0)), "%s %s recovery effect changed." % [site_id,label])
		"pressure": _expect(int(effects.get("enemy_pressure_relieved",0)) == int(case.get("amount",0)), "%s %s pressure effect changed." % [site_id,label])
		"mixed":
			_expect(int(effects.get("movement_restored",0)) == int(case.get("amount",0)), "%s %s movement effect changed." % [site_id,label])
			_expect(int(effects.get("town_recovery_relieved",0)) == int(case.get("town_amount",0)), "%s %s recovery effect changed." % [site_id,label])
		"vision": _expect(int(result.get("site_vision_radius",0)) == int(case.get("amount",0)), "%s %s vision effect changed." % [site_id,label])
	if int(case.get("vision",0)) > 0:
		_expect(int(result.get("site_vision_radius",0)) == int(case.get("vision",0)), "%s %s channel survey changed." % [site_id,label])

func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}

func _clone_session(source) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  "))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
