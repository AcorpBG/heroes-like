extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const AbilityRuntimeReportScript = preload("res://tests/unit_ability_runtime_report.gd")

const REPORT_ID := "SIX_ELDER_WILDS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_elder_wilds_smoke"
const SCENARIO_ID := "ninefold-confluence"
const EXPECTED_SCENARIO_ENCOUNTER_COUNT := 31
const CASES := [
	{"unit_id":"unit_neutral_brambleback_knucklebears","tier":4,"role":"melee","ability_ids":["brace","shielding"],"army_group_id":"army_neutral_brambleback_crown_watch","encounter_id":"encounter_brambleback_crown_watch","placement_id":"ninefold_brambleback_crown_watch","objective_id":"brambleback_crown_rootline","objective_type":"cover_line","asset_id":"encounter_elder_wild_brambleback_crown_watch","identity_path":"res://art/overworld/runtime/objects/encounters/elder_wilds/unit_neutral_brambleback_knucklebears.png","position":Vector2i(19,10),"combat_seed":26501,"reward_key":"wood"},
	{"unit_id":"unit_neutral_mireglass_belltoads","tier":4,"role":"ranged","ability_ids":["harry","volley"],"army_group_id":"army_neutral_mireglass_bellbasin_watch","encounter_id":"encounter_mireglass_bellbasin_watch","placement_id":"ninefold_mireglass_bellbasin_watch","objective_id":"mireglass_bellbasin_throat_pool","objective_type":"hazard_zone","asset_id":"encounter_elder_wild_mireglass_bellbasin_watch","identity_path":"res://art/overworld/runtime/objects/encounters/elder_wilds/unit_neutral_mireglass_belltoads.png","position":Vector2i(33,17),"combat_seed":26502,"reward_key":"peatwax"},
	{"unit_id":"unit_neutral_galehorn_striders","tier":5,"role":"melee","ability_ids":["reach","bloodrush"],"army_group_id":"army_neutral_galehorn_breakline_watch","encounter_id":"encounter_galehorn_breakline_watch","placement_id":"ninefold_galehorn_breakline_watch","objective_id":"galehorn_breakline_notch","objective_type":"breach_point","asset_id":"encounter_elder_wild_galehorn_breakline_watch","identity_path":"res://art/overworld/runtime/objects/encounters/elder_wilds/unit_neutral_galehorn_striders.png","position":Vector2i(13,34),"combat_seed":26503,"reward_key":"ore"},
	{"unit_id":"unit_neutral_sunscale_lanternmoths","tier":5,"role":"ranged","ability_ids":["harry","volley"],"army_group_id":"army_neutral_sunscale_lantern_drift_watch","encounter_id":"encounter_sunscale_lantern_drift_watch","placement_id":"ninefold_sunscale_lantern_drift_watch","objective_id":"sunscale_lantern_drift_lane","objective_type":"lane_battery","asset_id":"encounter_elder_wild_sunscale_lantern_drift_watch","identity_path":"res://art/overworld/runtime/objects/encounters/elder_wilds/unit_neutral_sunscale_lanternmoths.png","position":Vector2i(40,36),"combat_seed":26504,"reward_key":"aetherglass"},
	{"unit_id":"unit_neutral_rimebell_skyrakers","tier":6,"role":"melee","ability_ids":["fog_screen","reach"],"battle_ability_ids":["reach"],"army_group_id":"army_neutral_rimebell_whitewake_watch","encounter_id":"encounter_rimebell_whitewake_watch","placement_id":"ninefold_rimebell_whitewake_watch","objective_id":"rimebell_whitewake_signal","objective_type":"signal_beacon","asset_id":"encounter_elder_wild_rimebell_whitewake_watch","identity_path":"res://art/overworld/runtime/objects/encounters/elder_wilds/unit_neutral_rimebell_skyrakers.png","position":Vector2i(5,43),"combat_seed":26505,"reward_key":"memory_salt"},
	{"unit_id":"unit_neutral_deepforge_vaultwyrms","tier":7,"role":"melee","ability_ids":["brace","shielding"],"army_group_id":"army_neutral_deepforge_seventh_seal_watch","encounter_id":"encounter_deepforge_seventh_seal_watch","placement_id":"ninefold_deepforge_seventh_seal_watch","objective_id":"deepforge_seventh_seal_pylon","objective_type":"ritual_pylon","asset_id":"encounter_elder_wild_deepforge_seventh_seal_watch","identity_path":"res://art/overworld/runtime/objects/encounters/elder_wilds/unit_neutral_deepforge_vaultwyrms.png","position":Vector2i(58,41),"combat_seed":26506,"reward_key":"brass_scrip"},
]

var _errors: Array[String] = []
var _rows: Array = []
var _ability_runtime_count := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var encounters: Array = session.overworld.get("encounters", [])
	_expect(encounters.size() == EXPECTED_SCENARIO_ENCOUNTER_COUNT, "Ninefold Confluence must retain 25 prior encounters plus all six Elder Wilds watches.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		_validate_case(session, view, case_value)
	var authority_before: Dictionary = session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_before)
	_expect(restored.to_dict() == authority_before, "The complete Elder Wilds scenario authority did not round-trip exactly through save version %d." % SessionStateStoreScript.SAVE_VERSION)
	for case_value in CASES:
		_expect(not _encounter_by_placement(restored, String(case_value.get("placement_id", ""))).is_empty(), "%s was lost after save/load." % String(case_value.get("placement_id", "")))
	var capture_path := "%s/elder_wilds_contact_sheet.png" % OUTPUT_DIR
	_expect(_write_contact_sheet(capture_path), "Could not write the Elder Wilds visual contact sheet.")
	var report := {
		"ok": _errors.is_empty(),
		"scenario_id": SCENARIO_ID,
		"case_count": CASES.size(),
		"battle_payload_count": _rows.size(),
		"ability_runtime_count": _ability_runtime_count,
		"exact_identity_art_count": _rows.filter(func(row): return bool(row.get("exact_identity_art", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"save_round_trip_exact": restored.to_dict() == authority_before,
		"single_consolidated_smoke": true,
		"visual_capture": capture_path,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"battle_payload_count":6,"ability_runtime_count":12,"exact_identity_art_count":6,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(session, view: Control, case: Dictionary) -> void:
	var unit_id := String(case.get("unit_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var expected_ability_ids: Array = case.get("ability_ids", [])
	_expect(not unit.is_empty(), "%s is not shipped." % unit_id)
	_expect(String(unit.get("content_status", "")) == "elder_wilds_live", "%s is not marked live." % unit_id)
	_expect(int(unit.get("tier", 0)) == int(case.get("tier", 0)) and String(unit.get("role", "")) == String(case.get("role", "")), "%s tier or role drifted." % unit_id)
	_expect(_ability_ids(unit.get("abilities", [])) == expected_ability_ids, "%s ability identity drifted." % unit_id)
	var art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	for art_key in ["portrait", "battle_icon", "battle_standee", "overworld_icon"]:
		var art_path := String(art.get(art_key, ""))
		_expect(art_path != "" and load(art_path) is Texture2D, "%s lost its %s runtime art." % [unit_id, art_key])
	var animation_path := String(animation.get("sprite_sheet", ""))
	_expect(animation_path != "" and load(animation_path) is Texture2D, "%s lost its runtime animation sheet." % unit_id)
	_expect(String(art.get("curated_source_sha256", "")) != "" and String(art.get("curated_source_sha256", "")) == String(animation.get("curated_source_sha256", "")), "%s art provenance drifted across runtime manifests." % unit_id)

	var army_group_id := String(case.get("army_group_id", ""))
	var army := ContentService.get_army_group(army_group_id)
	_expect(not army.is_empty() and String(army.get("affiliation", "")) == "neutral", "%s is not a neutral production army." % army_group_id)
	_expect(_army_has_unit(army, unit_id), "%s does not field %s." % [army_group_id, unit_id])
	var placement := _encounter_by_placement(session, String(case.get("placement_id", "")))
	_expect(not placement.is_empty(), "%s is not live on Ninefold Confluence." % String(case.get("placement_id", "")))
	var expected_position: Vector2i = case.get("position", Vector2i(-1, -1))
	_expect(Vector2i(int(placement.get("x", -1)), int(placement.get("y", -1))) == expected_position and int(placement.get("combat_seed", 0)) == int(case.get("combat_seed", 0)), "%s position or combat seed drifted." % String(case.get("placement_id", "")))
	var encounter_id := String(case.get("encounter_id", ""))
	var encounter := ContentService.get_encounter(encounter_id)
	_expect(String(placement.get("encounter_id", "")) == encounter_id and String(encounter.get("enemy_group_id", "")) == army_group_id, "%s lost its encounter-to-army link." % encounter_id)
	_expect(encounter.get("rewards", {}).has(String(case.get("reward_key", ""))) and not encounter.get("victory_flags", []).is_empty(), "%s lost its distinct reward or victory state." % encounter_id)
	var authored_objective := _objective_by_id(encounter.get("field_objectives", []), String(case.get("objective_id", "")))
	_expect(String(authored_objective.get("type", "")) == String(case.get("objective_type", "")), "%s lost its authored field objective." % encounter_id)

	var authority_before: Dictionary = session.to_dict()
	var battle: Dictionary = BattleRules.create_battle_payload(session, placement)
	_expect(session.to_dict() == authority_before, "%s battle construction mutated scenario authority." % encounter_id)
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == encounter_id and String(battle.get("enemy_army_id", "")) == army_group_id, "%s did not construct its exact production battle." % encounter_id)
	_expect(int(battle.get("combat_seed", 0)) == int(case.get("combat_seed", 0)), "%s battle lost its deterministic seed." % encounter_id)
	var battle_stack := _battle_stack_for_unit(battle, unit_id)
	_expect(not battle_stack.is_empty(), "%s battle did not field %s." % [encounter_id, unit_id])
	for stat_key in ["tier", "unit_hp", "attack", "defense", "min_damage", "max_damage", "initiative", "speed", "ranged"]:
		var unit_key: String = "hp" if stat_key == "unit_hp" else String(stat_key)
		_expect(battle_stack.get(stat_key) == unit.get(unit_key), "%s battle stack changed authored %s." % [unit_id, stat_key])
	var expected_battle_ability_ids: Array = case.get("battle_ability_ids", expected_ability_ids)
	_expect(_ability_ids(battle_stack.get("abilities", [])) == expected_battle_ability_ids, "%s battle payload lost its exact mutable abilities." % unit_id)
	var battle_objective := _objective_by_id(battle.get(BattleRules.FIELD_OBJECTIVES_KEY, []), String(case.get("objective_id", "")))
	_expect(String(battle_objective.get("type", "")) == String(case.get("objective_type", "")), "%s battle payload lost its field objective." % encounter_id)

	var probe = AbilityRuntimeReportScript.new()
	var ability_results := {}
	for ability_id_value in expected_ability_ids:
		var ability_id := String(ability_id_value)
		var result: Dictionary = probe.call("_runtime_consequence_for_ability", unit_id, ability_id)
		ability_results[ability_id] = result
		_ability_runtime_count += 1
		_expect(bool(result.get("ok", false)), "%s %s did not execute its live combat consequence: %s" % [unit_id, ability_id, JSON.stringify(result)])
	probe.free()

	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", placement)
	var asset_id := String(case.get("asset_id", ""))
	var expected_icon_path := String(case.get("identity_path", ""))
	var identity_texture = view.call("_object_texture_for_asset", asset_id)
	var exact_identity_art := String(presentation.get("identity_encounter_asset_id", "")) == asset_id and String(presentation.get("identity_encounter_path", "")) == expected_icon_path and bool(presentation.get("uses_identity_encounter_sprite", false)) and identity_texture is Texture2D and not (identity_texture is AtlasTexture)
	_expect(exact_identity_art, "%s did not resolve its exact non-placeholder encounter identity art: %s" % [encounter_id, JSON.stringify(presentation)])
	_rows.append({"unit_id":unit_id,"army_group_id":army_group_id,"encounter_id":encounter_id,"placement_id":String(case.get("placement_id", "")),"objective_id":String(case.get("objective_id", "")),"objective_type":String(case.get("objective_type", "")),"battle_stack_count":int(battle_stack.get("base_count", 0)),"ability_results":ability_results,"exact_identity_art":exact_identity_art})

func _encounter_by_placement(session, placement_id: String) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary and String(encounter_value.get("placement_id", "")) == placement_id:
			return encounter_value
	return {}

func _battle_stack_for_unit(battle: Dictionary, unit_id: String) -> Dictionary:
	for stack_value in battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy" and String(stack_value.get("unit_id", "")) == unit_id:
			return stack_value
	return {}

func _army_has_unit(army: Dictionary, unit_id: String) -> bool:
	for stack_value in army.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id and int(stack_value.get("count", 0)) > 0:
			return true
	return false

func _objective_by_id(objectives: Variant, objective_id: String) -> Dictionary:
	if not (objectives is Array):
		return {}
	for objective_value in objectives:
		if objective_value is Dictionary and String(objective_value.get("id", "")) == objective_id:
			return objective_value
	return {}

func _ability_ids(abilities: Variant) -> Array:
	var result := []
	if not (abilities is Array):
		return result
	for ability_value in abilities:
		if ability_value is Dictionary:
			result.append(String(ability_value.get("id", "")))
	return result

func _write_contact_sheet(path: String) -> bool:
	var cell_size := Vector2i(256, 256)
	var sheet := Image.create(cell_size.x * 3, cell_size.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.035, 0.045, 0.06, 1.0))
	for index in range(CASES.size()):
		var unit_id := String(CASES[index].get("unit_id", ""))
		var source_path := String(ContentService.get_unit_art(unit_id).get("curated_source", ""))
		var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if source.is_empty():
			return false
		source.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		var target := Vector2i((index % 3) * cell_size.x, (index / 3) * cell_size.y)
		sheet.blend_rect(source, Rect2i(Vector2i.ZERO, cell_size), target)
	return sheet.save_png(path) == OK

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
