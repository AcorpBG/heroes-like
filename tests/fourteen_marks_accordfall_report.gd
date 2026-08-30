extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")

const REPORT_ID := "FOURTEEN_MARKS_ACCORDFALL_REPORT"
const OUTPUT_DIR := "res://.artifacts/fourteen_marks_accordfall_report"
const SCENARIO_ID := "accordfall-fourteen-marks"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/fourteen_marks_state_atlas.png"
const CASES := [
	{"site_id":"site_granary_lock_exchange","placement_id":"accordfall_granary_exchange","role":"landmark","active":"resource_site_fourteen_marks_granary_lock_exchange_state","cost":{},"rewards":{"gold":120,"wood":2},"flag":"","objective":"","region":Rect2(0,0,48,48)},
	{"site_id":"site_blackwater_shrine_marker","placement_id":"accordfall_blackwater_shrine","role":"landmark","active":"resource_site_fourteen_marks_blackwater_shrine_marker_state","cost":{},"rewards":{"gold":100,"wood":1},"flag":"","objective":"","region":Rect2(48,0,48,48)},
	{"site_id":"site_prism_yard_standard","placement_id":"accordfall_prism_standard","role":"landmark","active":"resource_site_fourteen_marks_prism_yard_standard_state","cost":{},"rewards":{"gold":120,"ore":2},"flag":"","objective":"","region":Rect2(96,0,48,48)},
	{"site_id":"site_broken_treaty_stone","placement_id":"accordfall_broken_treaty","role":"objective","active":"resource_site_fourteen_marks_broken_treaty_stone_state","cost":{},"rewards":{"gold":220},"flag":"accordfall_broken_treaty_recorded","objective":"record_broken_treaty","region":Rect2(144,0,48,48)},
	{"site_id":"site_sealed_causeway_lever","placement_id":"accordfall_causeway_lever","role":"objective","active":"resource_site_fourteen_marks_sealed_causeway_lever_state","cost":{},"rewards":{"gold":100},"flag":"accordfall_causeway_released","objective":"release_sealed_causeway","region":Rect2(192,0,48,48)},
	{"site_id":"site_mirror_anchor_frame","placement_id":"accordfall_mirror_anchor","role":"objective","active":"resource_site_fourteen_marks_mirror_anchor_frame_state","cost":{},"rewards":{"ore":2},"flag":"accordfall_mirror_anchor_aligned","objective":"align_mirror_anchor","region":Rect2(240,0,48,48)},
	{"site_id":"site_crownless_standard","placement_id":"accordfall_crownless_standard","role":"objective","active":"resource_site_fourteen_marks_crownless_standard_state","cost":{},"rewards":{"gold":180},"flag":"accordfall_crownless_standard_raised","objective":"raise_crownless_standard","region":Rect2(288,0,48,48)},
	{"site_id":"site_drowned_toll_bell","placement_id":"accordfall_drowned_bell","role":"objective","active":"resource_site_fourteen_marks_drowned_toll_bell_state","cost":{},"rewards":{"wood":2},"flag":"accordfall_drowned_toll_rung","objective":"ring_drowned_toll","region":Rect2(336,0,48,48)},
	{"site_id":"site_orchard_writ_seal","placement_id":"accordfall_orchard_writ","role":"objective","active":"resource_site_fourteen_marks_orchard_writ_seal_state","cost":{},"rewards":{"gold":150,"wood":1},"flag":"accordfall_orchard_writ_accepted","objective":"accept_orchard_writ","region":Rect2(384,0,48,48)},
	{"site_id":"site_brass_oath_wheel","placement_id":"accordfall_oath_wheel","role":"objective","active":"resource_site_fourteen_marks_brass_oath_wheel_state","cost":{},"rewards":{"gold":200,"ore":1},"flag":"accordfall_brass_oath_wheel_turned","objective":"turn_brass_oath_wheel","region":Rect2(432,0,48,48)},
	{"site_id":"site_burned_signal_brazier","placement_id":"accordfall_signal_brazier","role":"variant","active":"resource_site_fourteen_marks_burned_signal_brazier_state","cost":{"gold":100,"wood":2},"rewards":{},"flag":"accordfall_signal_brazier_restored","objective":"restore_signal_brazier","region":Rect2(480,0,48,48)},
	{"site_id":"site_repaired_ferry_stage_claimed","placement_id":"accordfall_ferry_stage","role":"variant","active":"resource_site_fourteen_marks_repaired_ferry_stage_claimed_state","cost":{"gold":120,"wood":3},"rewards":{"gold":60},"flag":"accordfall_ferry_stage_claimed","objective":"claim_repaired_ferry","region":Rect2(528,0,48,48)},
	{"site_id":"site_claimed_quarry_head","placement_id":"accordfall_quarry_head","role":"variant","active":"resource_site_fourteen_marks_claimed_quarry_head_state","cost":{"gold":130,"ore":3},"rewards":{"gold":80},"flag":"accordfall_quarry_head_restarted","objective":"restart_quarry_head","region":Rect2(576,0,48,48)},
	{"site_id":"site_withered_rootgate_marker","placement_id":"accordfall_rootgate","role":"variant","active":"resource_site_fourteen_marks_withered_rootgate_marker_state","cost":{"gold":90,"wood":3},"rewards":{},"flag":"accordfall_rootgate_restored","objective":"restore_rootgate_marker","region":Rect2(624,0,48,48)},
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
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	_expect(not scenario.is_empty(), "Accordfall Fourteen Marks is not shipped.")
	var map_size: Dictionary = scenario.get("map_size", {})
	_expect(int(map_size.get("width",0)) == 26 and int(map_size.get("height",0)) == 16, "Scenario size changed.")
	_expect(scenario.get("resource_nodes", []).size() == 20 and scenario.get("towns", []).size() == 2 and scenario.get("encounters", []).size() == 5, "Scenario breadth changed.")
	_expect(scenario.get("objectives", {}).get("victory", []).size() == 13 and scenario.get("script_hooks", []).size() == 5, "Scenario objectives or reactive hooks changed.")
	_validate_restoration_runway(scenario)
	for case_value in CASES:
		_validate_case(view, case_value)
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not atlas.is_empty() and atlas.get_size() == Vector2i(672,48), "Could not load the fourteen-state atlas.")
	if not atlas.is_empty():
		atlas.save_png("%s/fourteen_marks_state_strip.png" % OUTPUT_DIR)
	var report := {
		"ok":_errors.is_empty(),"scenario_id":SCENARIO_ID,"case_count":CASES.size(),
		"landmark_count":3,"objective_count":7,"state_variant_count":4,
		"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors,
		"single_visual_capture":"%s/fourteen_marks_state_strip.png" % OUTPUT_DIR,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":14,"landmarks":3,"objectives":7,"state_variants":4,"save_version":SessionStateStoreScript.SAVE_VERSION,"visual_capture":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_restoration_runway(scenario: Dictionary) -> void:
	var total := {"gold":0,"wood":0,"ore":0}
	for case_value in CASES:
		for key in case_value.get("cost", {}).keys():
			total[key] = int(total.get(key,0)) + int(case_value.get("cost",{}).get(key,0))
	var starting: Dictionary = scenario.get("starting_resources", {})
	for key in total.keys():
		_expect(int(starting.get(key,0)) >= int(total.get(key,0)), "Starting %s cannot fund all four authored restorations." % key)

func _validate_case(view: Control, case: Dictionary) -> void:
	var session = _new_session()
	var site_id := String(case.get("site_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var role := String(case.get("role", ""))
	var site := ContentService.get_resource_site(site_id)
	var node_result := _node_result(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	var expected_status := "live" if role == "landmark" else ("objective_event_live" if role == "objective" else "state_variant_live")
	_expect(String(site.get("runtime_boundary", {}).get("status", "")) == expected_status, "%s is not live for role %s." % [site_id,role])
	var art_manifest: Dictionary = view.get("_overworld_art_manifest")
	var sprite_entry: Dictionary = art_manifest.get("resource_site_sprites", {}).get(site_id, {})
	if role != "landmark":
		_expect(String(view.call("_resource_asset_id", node)) == String(sprite_entry.get("unclaimed_asset_id", "")), "%s lost its original pre-claim art." % site_id)
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var first := OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(first.get("ok", false)), "%s interaction failed: %s" % [site_id,JSON.stringify(first)])
	for key in ["gold","wood","ore"]:
		var expected_after := int(resources_before.get(key,0)) - int(case.get("cost",{}).get(key,0)) + int(case.get("rewards",{}).get(key,0))
		_expect(int(session.overworld.get("resources",{}).get(key,0)) == expected_after, "%s %s transaction changed." % [site_id,key])
	var flag := String(case.get("flag", ""))
	if flag != "":
		_expect(bool(session.flags.get(flag, false)), "%s did not set its claim flag." % site_id)
		_expect(ScenarioRulesScript.is_objective_met(session, String(case.get("objective", "")), "victory"), "%s did not satisfy its scenario objective." % site_id)
	var claimed: Dictionary = _node_result(session, placement_id).get("node", {})
	_expect(bool(claimed.get("collected", false)) and String(claimed.get("collected_by_faction_id", "")) == "player", "%s did not persist player control." % site_id)
	var active_id := String(view.call("_resource_asset_id", claimed))
	var texture = view.call("_object_texture_for_asset", active_id)
	_expect(active_id == String(case.get("active", "")), "%s did not switch to its authored state art." % site_id)
	_expect(texture is AtlasTexture and texture.region == case.get("region") and texture.get_size() == Vector2(48,48), "%s atlas region changed." % site_id)
	var authority_after: Dictionary = session.to_dict()
	var repeat := OverworldRules._collect_resource_node_result(session, _node_result(session, placement_id), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after, "%s repeat interaction mutated authority." % site_id)
	var restored = _clone_session(session)
	_expect(restored.to_dict() == session.to_dict(), "%s save round-trip changed claimed authority." % site_id)
	_rows.append({"site_id":site_id,"role":role,"cost":case.get("cost",{}),"rewards":case.get("rewards",{}),"repeat_blocked":true,"save_round_trip_exact":true,"active_asset_id":active_id})

func _new_session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}

func _clone_session(source):
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
