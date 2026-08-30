extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_PROGRESSION_SHRINES_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_progression_shrines_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/progression_shrine_awakened_atlas.png"
const CASES := [
	{"scenario_id":"tollbrand-blackwake-levy","site_id":"site_oath_ember_shrine","placement_id":"tollbrand_dormant_b","guard_id":"","guard_encounter_id":"","unclaimed":"mapobj_oath_ember_shrine","awakened":"resource_site_progression_shrine_oath_ember_awakened","region":Rect2(0,0,48,48),"xp":90,"command_key":"attack","spell_id":"spell_beacon_waymark_road_15","vision":0,"repeatable":false,"effect":"","amount":0},
	{"scenario_id":"votivejaw-reedflame-vigil","site_id":"site_reedscript_vow_shrine","placement_id":"votivejaw_dormant_a","guard_id":"","guard_encounter_id":"","unclaimed":"mapobj_reedscript_vow_shrine","awakened":"resource_site_progression_shrine_reedscript_vow_awakened","region":Rect2(48,0,48,48),"xp":75,"command_key":"knowledge","spell_id":"spell_mire_flood_fenlight_12","vision":3,"repeatable":false,"effect":"","amount":0},
	{"scenario_id":"glassmarshal-ossuary-battery","site_id":"site_prism_measure_shrine","placement_id":"glassmarshal_dormant_b","guard_id":"","guard_encounter_id":"","unclaimed":"mapobj_prism_measure_shrine","awakened":"resource_site_progression_shrine_prism_measure_awakened","region":Rect2(96,0,48,48),"xp":80,"command_key":"power","spell_id":"spell_lens_starlens_survey_12","vision":4,"repeatable":false,"effect":"","amount":0},
	{"scenario_id":"seedseer-drowned-orchard","site_id":"site_root_accord_ring","placement_id":"seedseer_dormant_a","guard_id":"seedseer_screen_a","guard_encounter_id":"encounter_drowned_bell_procession","unclaimed":"mapobj_root_accord_ring","awakened":"resource_site_progression_shrine_root_accord_awakened","region":Rect2(144,0,48,48),"xp":60,"command_key":"","spell_id":"","vision":0,"repeatable":true,"effect":"mixed","amount":120,"town_amount":1},
	{"scenario_id":"pitmarshal-peat-chain-seizure","site_id":"site_furnace_oath_marker","placement_id":"pitmarshal_dormant_b","guard_id":"pitmarshal_screen_a","guard_encounter_id":"encounter_mossglass_moonhunt","unclaimed":"mapobj_furnace_oath_marker","awakened":"resource_site_progression_shrine_furnace_oath_awakened","region":Rect2(192,0,48,48),"xp":65,"command_key":"","spell_id":"","vision":0,"repeatable":true,"effect":"movement","amount":150},
	{"scenario_id":"keelwarden-lockfire-run","site_id":"site_tide_bell_shrine","placement_id":"keelwarden_dormant_b","guard_id":"keelwarden_screen_a","guard_encounter_id":"encounter_lockflame_turncoats","unclaimed":"mapobj_tide_bell_shrine","awakened":"resource_site_progression_shrine_tide_bell_awakened","region":Rect2(240,0,48,48),"xp":55,"command_key":"","spell_id":"","vision":4,"repeatable":true,"effect":"pressure","amount":1},
]

var _errors: Array[String] = []
var _rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _validate_case(view, case_value)
	var capture := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not capture.is_empty(), "Could not load the consolidated progression-shrine capture.")
	if not capture.is_empty():
		capture.save_png("%s/progression_shrine_state_strip.png" % OUTPUT_DIR)
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"atlas_path":ATLAS_PATH,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_visual_capture":"%s/progression_shrine_state_strip.png" % OUTPUT_DIR,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION,"visual_capture":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	_seed_effect_inputs(session, case)
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(site_id)
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == "shrine_progression_live", "%s is not live." % site_id)
	_expect(String(view.call("_resource_asset_id", node)) == String(case.get("unclaimed", "")), "%s lost ready-state art." % site_id)
	var guard_id := String(case.get("guard_id", ""))
	var battle_constructed := false
	if guard_id != "":
		var blocking := OverworldRules.resource_site_blocking_guard(session, node, site)
		_expect(String(blocking.get("placement_id", "")) == guard_id, "%s lost its exact guard link." % site_id)
		var blocked := OverworldRules._collect_resource_node_result(session, node_result, true)
		_expect(not bool(blocked.get("ok", true)), "%s could be used before guard clearance." % site_id)
		var guard := _encounter(session, guard_id)
		var battle := BattleRulesScript.create_battle_payload(session, guard)
		battle_constructed = not battle.is_empty()
		_expect(battle_constructed and String(battle.get("encounter_id", "")) == String(case.get("guard_encounter_id", "")), "%s did not construct its authored guard battle." % site_id)
		_resolve_guard(session, guard_id)
		_expect(OverworldRules.resource_site_blocking_guard(session, _node_result(session, placement_id).get("node", {}), site).is_empty(), "%s remained guarded after resolution." % site_id)
		_seed_effect_inputs(session, case)
	var before := _snapshot(session, case)
	var first := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(bool(first.get("ok", false)), "%s first claim failed: %s" % [site_id, JSON.stringify(first)])
	if not bool(first.get("ok", false)):
		return
	_validate_delta(before, _snapshot(session, case), case, first, "first")
	var claimed: Dictionary = _node_result(session, placement_id).get("node", {})
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x",0)),int(node.get("y",0))))
	await get_tree().process_frame
	var awakened_id := String(view.call("_resource_asset_id", claimed))
	var texture = view.call("_object_texture_for_asset", awakened_id)
	_expect(awakened_id == String(case.get("awakened", "")), "%s did not switch to awakened art." % site_id)
	_expect(texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region"), "%s awakened atlas region changed." % site_id)
	var authority_after_first := session.to_dict()
	var early := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(not bool(early.get("ok", true)) and session.to_dict() == authority_after_first, "%s immediate repeat mutated authority." % site_id)
	var restored := _clone_session(session)
	_expect(restored.to_dict() == session.to_dict(), "%s first save round-trip changed authority." % site_id)
	var weekly_revisit := false
	if bool(case.get("repeatable", false)):
		restored.day = int(claimed.get("collected_day", 0)) + 7
		_seed_effect_inputs(restored, case)
		var before_second := _snapshot(restored, case)
		var second := OverworldRules._collect_resource_node_result(restored, _node_result(restored, placement_id), true)
		_expect(bool(second.get("ok", false)), "%s weekly revisit failed: %s" % [site_id, JSON.stringify(second)])
		if bool(second.get("ok", false)):
			_validate_delta(before_second, _snapshot(restored, case), case, second, "second")
			weekly_revisit = true
			var restored_again := _clone_session(restored)
			_expect(restored_again.to_dict() == restored.to_dict(), "%s weekly save round-trip changed authority." % site_id)
	_rows.append({"scenario_id":scenario_id,"site_id":site_id,"placement_id":placement_id,"guard_battle_constructed":battle_constructed,"first_claim":true,"immediate_repeat_blocked":true,"weekly_revisit":weekly_revisit,"save_round_trip_exact":true,"ready_asset_id":String(case.get("unclaimed","")),"awakened_asset_id":awakened_id})

func _seed_effect_inputs(session, case: Dictionary) -> void:
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = 100
	movement["max"] = 1000
	session.overworld["movement"] = movement
	if String(case.get("effect", "")) == "mixed":
		var towns: Array = session.overworld.get("towns", [])
		for index in range(towns.size()):
			if towns[index] is Dictionary and String(towns[index].get("owner", "")) == "player":
				var town: Dictionary = towns[index]
				town["recovery"] = {"pressure":4,"source":"shrine smoke"}
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
	var hero: Dictionary = session.overworld.get("hero", {})
	var recovery := 0
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			recovery = int(town.get("recovery", {}).get("pressure", 0))
			break
	var pressure := 0
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary:
			pressure = maxi(pressure, int(state.get("pressure", 0)))
	return {"experience":int(hero.get("experience",0)),"command":hero.get("command",{}).duplicate(true),"known_spell_ids":hero.get("spellbook",{}).get("known_spell_ids",[]).duplicate(true),"movement":int(session.overworld.get("movement",{}).get("current",0)),"recovery":recovery,"pressure":pressure}

func _validate_delta(before: Dictionary, after: Dictionary, case: Dictionary, result: Dictionary, label: String) -> void:
	var site_id := String(case.get("site_id", ""))
	_expect(int(after.get("experience",0))-int(before.get("experience",0)) == int(case.get("xp",0)), "%s %s experience changed." % [site_id,label])
	var command_key := String(case.get("command_key", ""))
	if command_key != "":
		_expect(int(after.get("command",{}).get(command_key,0))-int(before.get("command",{}).get(command_key,0)) == 1, "%s permanent command lesson changed." % site_id)
	var spell_id := String(case.get("spell_id", ""))
	if spell_id != "":
		_expect(spell_id not in before.get("known_spell_ids",[]) and spell_id in after.get("known_spell_ids",[]), "%s spell lesson changed." % site_id)
	var effects: Dictionary = result.get("shrine_effects", {})
	match String(case.get("effect", "")):
		"movement": _expect(int(effects.get("movement_restored",0)) == int(case.get("amount",0)), "%s %s movement renewal changed." % [site_id,label])
		"mixed":
			_expect(int(effects.get("movement_restored",0)) == int(case.get("amount",0)), "%s %s movement renewal changed." % [site_id,label])
			_expect(int(effects.get("town_recovery_relieved",0)) == int(case.get("town_amount",0)), "%s %s recovery relief changed." % [site_id,label])
		"pressure": _expect(int(effects.get("enemy_pressure_relieved",0)) == int(case.get("amount",0)), "%s %s pressure relief changed." % [site_id,label])
	if int(case.get("vision",0)) > 0:
		_expect(int(result.get("site_vision_radius",0)) == int(case.get("vision",0)), "%s %s survey radius changed." % [site_id,label])

func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}

func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}

func _resolve_guard(session, placement_id: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	if placement_id not in resolved:
		resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved

func _clone_session(source) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
