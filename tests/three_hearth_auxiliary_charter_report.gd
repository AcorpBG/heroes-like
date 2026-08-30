extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "THREE_HEARTH_AUXILIARY_CHARTER_REPORT"
const SCENARIO_ID := "three-hearth-auxiliary-charter"
const CASES := [
	{
		"unit_id": "unit_thornwake_canopy_rammers",
		"label": "Canopy Rammers",
		"faction_id": "faction_thornwake",
		"ability_ids": ["reach", "brace"],
		"placement_id": "auxiliary_canopy_breachers",
		"encounter_id": "encounter_third_hearths_canopy_breachers",
		"army_id": "army_third_hearths_canopy_breachers",
		"hook_id": "auxiliary_canopy_survivors_join",
		"source_sha256": "a072a8af177c4f41dcae2b28a775f018a9793a22c4a6e51dbd670bf7ebc4c8ae",
		"portrait_sha256": "730be4293a46baa1a91b05c1ce565419f5cdfcef5b7210772b731f961399acfc",
		"icon_sha256": "366a30e16549dceaaee978f4fde28450f1f3d5c4e4cda9b92835a559f1ac2fca",
		"standee_sha256": "66af55d78778bad63eb7ea716a20fa45906a9840785c4d12dc4f1b145cad053d",
		"overworld_sha256": "a8ad92c26c13558a441b30c922cbeef1a4481a714b1d3af23d8a4016333de11d",
		"sheet_sha256": "01810e83d6ced15bfc7dbf9c8267b648a49995fbe3b118857bd039283e2b5830",
	},
	{
		"unit_id": "unit_brasshollow_pressure_lancers",
		"label": "Pressure Lancers",
		"faction_id": "faction_brasshollow",
		"ability_ids": ["reach", "harry"],
		"placement_id": "auxiliary_redline_lancers",
		"encounter_id": "encounter_third_hearths_redline_lancers",
		"army_id": "army_third_hearths_redline_lancers",
		"hook_id": "auxiliary_redline_survivors_join",
		"source_sha256": "c15103c653201bae2045e407b06dedd2bc78ec681ecac7ed89af70189c5db4b8",
		"portrait_sha256": "2cb58e22a1dcc23460c7dd672726fafbae8969aa466710228c326192a96a3473",
		"icon_sha256": "718b7fba8bcf942a9b2e3a9cc3976ef4792a2d06e3a7458e1b4cbf91a0a9eab6",
		"standee_sha256": "ed7516167981cf07447d6a76ab29e58b46f4d7d89fa4647785fbb4be1f7dd211",
		"overworld_sha256": "0a618269b5357c3f777309304e0f552292c14baa3321433ecd45402389d5e2b3",
		"sheet_sha256": "8c083de93ea39c0e82f9463ff8df559438c90e8cf8000e66beccc8a733c420f6",
	},
	{
		"unit_id": "unit_veilmourn_wakeglass_navigators",
		"label": "Wakeglass Navigators",
		"faction_id": "faction_veilmourn",
		"ability_ids": ["fog_screen", "harry"],
		"placement_id": "auxiliary_wakeglass_pilots",
		"encounter_id": "encounter_third_hearths_wakeglass_pilots",
		"army_id": "army_third_hearths_wakeglass_pilots",
		"hook_id": "auxiliary_wakeglass_survivors_join",
		"source_sha256": "7019f7fbc74338b678f8509a591e59428c706e6102bdceb6b9acf68a59c621d4",
		"portrait_sha256": "8b6848180a136037f00697928ef45eea389848dd769e010aa5c349a1f845c717",
		"icon_sha256": "f002dcf6058e887844e4a034d20987ebf994039911cbcb23ac53150e57f7f92c",
		"standee_sha256": "2744ee0e4b344d1779e3875e07074b9983b1ea2044bd2d5c51f23d33484e0226",
		"overworld_sha256": "97fa46415d22cc38be8104fee59741ed4c4c2e8841ca7b1a341224ca8469c4cd",
		"sheet_sha256": "347e6960907540574dde26512355d7b7bccc1754261bb35475d5625b484cd1ce",
	},
]

var _errors: Array[String] = []
var _rows := []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	_validate_content_and_art()
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	_expect(session != null, "The auxiliary charter must create a live skirmish session.")
	if session != null:
		OverworldRules.normalize_overworld_state(session)
		_validate_scenario_layout(session)
		for case_value in CASES:
			_validate_encounter_and_recruit(session, case_value)
		_validate_save_round_trip(session)
		await _validate_live_recruited_battle_art(session)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({
			"ok": true,
			"scenario_id": SCENARIO_ID,
			"unit_count": CASES.size(),
			"encounter_count": CASES.size(),
			"recruited_count": CASES.size() * 2,
			"save_version": SessionStateStoreScript.SAVE_VERSION,
			"rows": _rows,
			"live_battle_art": true,
		})])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_content_and_art() -> void:
	_expect(ContentService.get_content_ids(ContentService.UNITS_PATH).size() == 106, "Unit catalog must contain the complete 106-unit batch.")
	_expect(ContentService.get_content_ids(ContentService.SCENARIOS_PATH).size() == 76, "Scenario catalog must contain the auxiliary charter as scenario 76.")
	for case_value in CASES:
		var case: Dictionary = case_value
		var unit_id := String(case.get("unit_id", ""))
		var unit := ContentService.get_unit(unit_id)
		var art := ContentService.get_unit_art(unit_id)
		var animation := ContentService.get_unit_animation(unit_id)
		var source_path := "res://art/units/source/curated/%s.png" % unit_id
		var portrait_path := "res://art/units/portraits/%s.png" % unit_id
		var icon_path := "res://art/units/battle_icons/%s.png" % unit_id
		var standee_path := "res://art/units/battle_standees/%s.png" % unit_id
		var overworld_path := "res://art/units/overworld_icons/%s.png" % unit_id
		var sheet_path := "res://art/animation/runtime/units/%s.png" % unit_id
		_expect(String(unit.get("name", "")) == String(case.get("label", "")) and String(unit.get("faction_id", "")) == String(case.get("faction_id", "")) and int(unit.get("tier", 0)) == 5 and String(unit.get("content_status", "")) == "scenario_auxiliary", "%s gameplay identity changed." % unit_id)
		_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s live ability contract changed." % unit_id)
		_expect(String(art.get("art_source_kind", "")) == "curated_original_character_v1" and String(art.get("curated_source", "")) == source_path and String(art.get("curated_source_sha256", "")) == String(case.get("source_sha256", "")), "%s curated provenance changed." % unit_id)
		_expect(String(art.get("portrait", "")) == portrait_path and String(art.get("battle_icon", "")) == icon_path and String(art.get("battle_standee", "")) == standee_path and String(art.get("overworld_icon", "")) == overworld_path and String(animation.get("sprite_sheet", "")) == sheet_path, "%s runtime art paths changed." % unit_id)
		var paths := [source_path, portrait_path, icon_path, standee_path, overworld_path, sheet_path]
		var hashes := [case.get("source_sha256", ""), case.get("portrait_sha256", ""), case.get("icon_sha256", ""), case.get("standee_sha256", ""), case.get("overworld_sha256", ""), case.get("sheet_sha256", "")]
		for index in range(paths.size()):
			_expect(FileAccess.get_sha256(paths[index]) == String(hashes[index]), "%s art hash drifted at %s." % [unit_id, paths[index]])
		var source := _load_image(source_path)
		var portrait := _load_image(portrait_path)
		var icon := _load_image(icon_path)
		var standee := _load_image(standee_path)
		var overworld := _load_image(overworld_path)
		var sheet := _load_image(sheet_path)
		_expect(source != null and source.get_size() == Vector2i(512, 512) and _transparent_corners(source), "%s source must remain a transparent 512x512 character master." % unit_id)
		_expect(portrait != null and portrait.get_size() == Vector2i(384, 512), "%s portrait dimensions changed." % unit_id)
		_expect(icon != null and icon.get_size() == Vector2i(160, 160), "%s battle icon dimensions changed." % unit_id)
		_expect(standee != null and standee.get_size() == Vector2i(192, 224), "%s battle standee dimensions changed." % unit_id)
		_expect(overworld != null and overworld.get_size() == Vector2i(96, 96), "%s overworld icon dimensions changed." % unit_id)
		_expect(sheet != null and sheet.get_size() == Vector2i(256, 896), "%s animation sheet dimensions changed." % unit_id)


func _validate_scenario_layout(session: SessionStateStoreScript.SessionData) -> void:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	_expect(int(map_size.get("width", 0)) == 16 and int(map_size.get("height", 0)) == 10, "Auxiliary charter map size changed.")
	_expect(scenario.get("selection", {}).get("availability", {}) == {"campaign": false, "skirmish": true}, "Auxiliary charter availability changed.")
	var occupied := {}
	for bucket in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for placement in session.overworld.get(bucket, []):
			if not (placement is Dictionary):
				continue
			var key := "%d,%d" % [int(placement.get("x", -1)), int(placement.get("y", -1))]
			_expect(not occupied.has(key), "Auxiliary charter placement collision at %s between %s and %s." % [key, occupied.get(key, ""), placement.get("placement_id", "")])
			occupied[key] = String(placement.get("placement_id", ""))
	_expect(session.overworld.get("encounters", []).size() == 3 and session.overworld.get("towns", []).size() == 2, "Auxiliary charter live placement breadth changed.")


func _validate_encounter_and_recruit(session: SessionStateStoreScript.SessionData, case: Dictionary) -> void:
	var unit_id := String(case.get("unit_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var placement := _encounter(session, placement_id)
	_expect(not placement.is_empty() and String(placement.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s live encounter placement changed." % placement_id)
	var army: Dictionary = ContentService.get_army_group(String(case.get("army_id", "")))
	_expect(String(army.get("id", "")) == String(case.get("army_id", "")) and _stack_count(army.get("stacks", []), unit_id) == 3, "%s authored enemy company changed." % placement_id)
	var authority_before := session.to_dict()
	var battle := BattleRulesScript.create_battle_payload(session, placement)
	var enemy_stack := _battle_stack(battle.get("stacks", []), unit_id, "enemy")
	var battle_ability_ids := _ability_ids(enemy_stack.get("abilities", []))
	var normalized_expected: Array = case.get("ability_ids", []).filter(func(ability_id): return String(ability_id) != "fog_screen")
	var battle_abilities_exact: bool = battle_ability_ids.size() == normalized_expected.size()
	for ability_id in normalized_expected:
		battle_abilities_exact = battle_abilities_exact and ability_id in battle_ability_ids
	if "fog_screen" in case.get("ability_ids", []):
		battle_abilities_exact = battle_abilities_exact and BattleRulesScript._active_ability_window_summary(enemy_stack, battle, {}).contains("live in this fog bank")
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(case.get("encounter_id", "")) and int(enemy_stack.get("base_count", 0)) == 3 and battle_abilities_exact, "%s did not construct its exact production battle stack: %s" % [placement_id, JSON.stringify(enemy_stack)])
	_expect(session.to_dict() == authority_before, "%s battle materialization mutated the live session." % placement_id)
	var count_before := _active_army_count(session, unit_id)
	_resolve_encounter(session, placement_id)
	var hook_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(String(case.get("hook_id", "")) in hook_result.get("fired_ids", []) and _active_army_count(session, unit_id) == count_before + 2, "%s did not recruit exactly two surviving auxiliaries." % placement_id)
	var authority_after := session.to_dict()
	var repeat := ScenarioScriptRulesScript.process_hooks(session)
	_expect(not (String(case.get("hook_id", "")) in repeat.get("fired_ids", [])) and session.to_dict() == authority_after, "%s recruitment hook repeated or mutated authority twice." % placement_id)
	_rows.append({"unit_id": unit_id, "placement_id": placement_id, "battle_stack_count": 3, "recruited": 2, "one_time": true})


func _validate_save_round_trip(session: SessionStateStoreScript.SessionData) -> void:
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	_expect(restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict(), "Auxiliary army and fired-hook authority did not survive the save-version-%d round trip." % SessionStateStoreScript.SAVE_VERSION)
	for case_value in CASES:
		_expect(_active_army_count(restored, String(case_value.get("unit_id", ""))) == 2, "%s recruited stack did not survive save normalization." % String(case_value.get("unit_id", "")))


func _validate_live_recruited_battle_art(session: SessionStateStoreScript.SessionData) -> void:
	var placement := _encounter(session, String(CASES[0].get("placement_id", "")))
	session.battle = BattleRulesScript.create_battle_payload(session, placement)
	var authority_before := session.to_dict()
	SessionState.set_active_session(session)
	var board = BattleBoardViewScript.new()
	board.size = Vector2(900, 560)
	add_child(board)
	board.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary: Dictionary = board.validation_unit_art_summary()
	for case_value in CASES:
		var unit_id := String(case_value.get("unit_id", ""))
		var matches: Array = summary.get("stacks", []).filter(func(entry): return entry is Dictionary and String(entry.get("unit_id", "")) == unit_id and bool(entry.get("loaded", false)) and bool(entry.get("battle_standee_loaded", false)) and bool(entry.get("animation_loaded", false)))
		_expect(not matches.is_empty(), "%s recruited stack was not visible with icon, standee, and animation art on the live BattleBoard." % unit_id)
	_expect(session.to_dict() == authority_before, "Live BattleBoard art observation mutated auxiliary session authority.")
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _resolve_encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	if placement_id not in resolved:
		resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved


func _active_army_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	return _stack_count(session.overworld.get("army", {}).get("stacks", []), unit_id)


func _stack_count(stacks: Variant, unit_id: String) -> int:
	var count := 0
	for stack in stacks if stacks is Array else []:
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			count += int(stack.get("count", 0))
	return count


func _battle_stack(stacks: Variant, unit_id: String, side: String) -> Dictionary:
	for stack in stacks if stacks is Array else []:
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id and String(stack.get("side", "")) == side:
			return stack
	return {}


func _ability_ids(abilities: Variant) -> Array:
	var result := []
	for ability in abilities if abilities is Array else []:
		if ability is Dictionary:
			result.append(String(ability.get("id", "")))
	return result


func _load_image(path: String) -> Image:
	var image := Image.new()
	return image if image.load(ProjectSettings.globalize_path(path)) == OK else null


func _transparent_corners(image: Image) -> bool:
	var max_x := image.get_width() - 1
	var max_y := image.get_height() - 1
	return image.get_pixel(0, 0).a <= 0.005 and image.get_pixel(max_x, 0).a <= 0.005 and image.get_pixel(0, max_y).a <= 0.005 and image.get_pixel(max_x, max_y).a <= 0.005


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
