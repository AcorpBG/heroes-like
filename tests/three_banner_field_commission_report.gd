extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "THREE_BANNER_FIELD_COMMISSION_REPORT"
const SCENARIO_ID := "three-banner-field-commission"
const CASES := [
	{
		"unit_id": "unit_embercourt_beaconline_writguard",
		"label": "Beaconline Writguard",
		"faction_id": "faction_embercourt",
		"ability_ids": ["brace", "formation_guard"],
		"placement_id": "commission_beaconline_writguard",
		"encounter_id": "encounter_three_banner_beaconline_writguard",
		"army_id": "army_three_banner_beaconline_writguard",
		"hook_id": "commission_beaconline_survivors_join",
		"source_sha256": "53537eead3a13d8a9ef36fe666cb0093d6a47ed9c50efc0e798d8bfbe1689a9f",
		"portrait_sha256": "2175b843b00a341213d433669f6b05b5978604c46d6a13398ec26152aa6faaf8",
		"icon_sha256": "b6f13dc2d3fa8f2ecd0e12aa61faaa6fbd5f0fa93d88ca2031d1b7310bd50d4a",
		"standee_sha256": "e712551478a98bffc632971829ec699c0644bb731f4b4e5cb1e2bb726d2c4218",
		"overworld_sha256": "fd5f1d2dc2962e9b2775448b9eab5cb0719d98357fa1e2a6a4710989be08e064",
		"sheet_sha256": "9c76dc08e25c1fa35045cfe80cc8f01953c155a3f6aa6c07c6e016e363ba7a7a",
	},
	{
		"unit_id": "unit_mireclaw_fenbell_chainstalkers",
		"label": "Fenbell Chainstalkers",
		"faction_id": "faction_mireclaw",
		"ability_ids": ["harry", "backstab"],
		"placement_id": "commission_fenbell_chainstalkers",
		"encounter_id": "encounter_three_banner_fenbell_chainstalkers",
		"army_id": "army_three_banner_fenbell_chainstalkers",
		"hook_id": "commission_fenbell_survivors_join",
		"source_sha256": "6c93d3a6302d21f710de10a718b85e6d9c855213d7f64ab3f745cd6f951b3e15",
		"portrait_sha256": "b28635791f8030969359318bf7b5ff445e4220ffb12da6afa7c67d1180e4bd8b",
		"icon_sha256": "9ca20d964acab96e63346596e6f4cea955ecf0de018542552b4a3dfbc8095dde",
		"standee_sha256": "e847ec7a5f8fbd1d5759c80f40af749b8ff83734e940c958754fc6c61cb09063",
		"overworld_sha256": "7168a1bd7e03680cf4aebe347c1a1467d15849c0a2ea93664d3cc93a9e1849c9",
		"sheet_sha256": "84ec82b7eb697911ca21153b3c3a6c7f12e8cd9a65a8f734b95682fadcf48763",
	},
	{
		"unit_id": "unit_sunvault_zenith_lensbearers",
		"label": "Zenith Lensbearers",
		"faction_id": "faction_sunvault",
		"ability_ids": ["volley", "harry"],
		"placement_id": "commission_zenith_lensbearers",
		"encounter_id": "encounter_three_banner_zenith_lensbearers",
		"army_id": "army_three_banner_zenith_lensbearers",
		"hook_id": "commission_zenith_survivors_join",
		"source_sha256": "42c57b8a2ec5449e24d370934bd4f79c01e122bd12de9c678d0e4c93100e81ac",
		"portrait_sha256": "3003d2746b4ee5390a4c8934ffefb67c2fd7a29183406273dfcc794e93775402",
		"icon_sha256": "d0b0bde16d05a32e0c9aca5d0c52651375c3e1dfb6e043f4c3fbe53c3d9f5e92",
		"standee_sha256": "896ed5ae204c3157f8c7aab70b48b7d51cf2b754fae2e10ef3afa0cc47fba0e6",
		"overworld_sha256": "06dab9f43e95f142256af35f60de685bb7c63b25f524e845ffec35ded359b532",
		"sheet_sha256": "004e83404aabe95fba9725a4aa973f2ed53ef73e892af02710f30b9a661e70c4",
	},
]

var _errors: Array[String] = []
var _rows := []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	_validate_content_and_art()
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "The field commission must create a live skirmish session.")
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
			"all_factions_have_auxiliaries": true,
			"live_battle_art": true,
		})])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_content_and_art() -> void:
	_expect(ContentService.get_content_ids(ContentService.UNITS_PATH).size() == 109, "Unit catalog must contain the complete 109-unit batch.")
	_expect(ContentService.get_content_ids(ContentService.SCENARIOS_PATH).size() == 77, "Scenario catalog must contain the field commission as scenario 77.")
	var auxiliary_factions := {}
	for unit_id in ContentService.get_content_ids(ContentService.UNITS_PATH):
		var candidate := ContentService.get_unit(unit_id)
		if String(candidate.get("content_status", "")) == "scenario_auxiliary":
			auxiliary_factions[String(candidate.get("faction_id", ""))] = int(auxiliary_factions.get(String(candidate.get("faction_id", "")), 0)) + 1
	_expect(auxiliary_factions == {"faction_embercourt": 1, "faction_mireclaw": 1, "faction_sunvault": 1, "faction_thornwake": 1, "faction_brasshollow": 1, "faction_veilmourn": 1}, "Scenario-earned auxiliary coverage must remain exactly one specialist per production faction.")
	for case_value in CASES:
		var case: Dictionary = case_value
		var unit_id := String(case.get("unit_id", ""))
		var unit := ContentService.get_unit(unit_id)
		var art := ContentService.get_unit_art(unit_id)
		var animation := ContentService.get_unit_animation(unit_id)
		var paths := [
			"res://art/units/source/curated/%s.png" % unit_id,
			"res://art/units/portraits/%s.png" % unit_id,
			"res://art/units/battle_icons/%s.png" % unit_id,
			"res://art/units/battle_standees/%s.png" % unit_id,
			"res://art/units/overworld_icons/%s.png" % unit_id,
			"res://art/animation/runtime/units/%s.png" % unit_id,
		]
		var hashes := [case.get("source_sha256", ""), case.get("portrait_sha256", ""), case.get("icon_sha256", ""), case.get("standee_sha256", ""), case.get("overworld_sha256", ""), case.get("sheet_sha256", "")]
		_expect(String(unit.get("name", "")) == String(case.get("label", "")) and String(unit.get("faction_id", "")) == String(case.get("faction_id", "")) and int(unit.get("tier", 0)) == 5 and String(unit.get("content_status", "")) == "scenario_auxiliary", "%s gameplay identity changed." % unit_id)
		_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s live ability contract changed." % unit_id)
		_expect(String(art.get("art_source_kind", "")) == "curated_original_character_v1" and String(art.get("curated_source", "")) == paths[0] and String(art.get("curated_source_sha256", "")) == String(hashes[0]), "%s curated provenance changed." % unit_id)
		_expect(String(art.get("portrait", "")) == paths[1] and String(art.get("battle_icon", "")) == paths[2] and String(art.get("battle_standee", "")) == paths[3] and String(art.get("overworld_icon", "")) == paths[4] and String(animation.get("sprite_sheet", "")) == paths[5], "%s runtime art paths changed." % unit_id)
		for index in range(paths.size()):
			_expect(FileAccess.get_sha256(paths[index]) == String(hashes[index]), "%s art hash drifted at %s." % [unit_id, paths[index]])
		var images := []
		for path in paths:
			images.append(_load_image(path))
		_expect(images[0] != null and images[0].get_size() == Vector2i(512, 512) and _transparent_corners(images[0]), "%s source must remain a transparent 512x512 master." % unit_id)
		_expect(images[1] != null and images[1].get_size() == Vector2i(384, 512), "%s portrait dimensions changed." % unit_id)
		_expect(images[2] != null and images[2].get_size() == Vector2i(160, 160), "%s battle icon dimensions changed." % unit_id)
		_expect(images[3] != null and images[3].get_size() == Vector2i(192, 224), "%s battle standee dimensions changed." % unit_id)
		_expect(images[4] != null and images[4].get_size() == Vector2i(96, 96), "%s overworld icon dimensions changed." % unit_id)
		_expect(images[5] != null and images[5].get_size() == Vector2i(256, 896), "%s animation sheet dimensions changed." % unit_id)


func _validate_scenario_layout(session: SessionStateStoreScript.SessionData) -> void:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	_expect(int(map_size.get("width", 0)) == 18 and int(map_size.get("height", 0)) == 12, "Field commission map size changed.")
	_expect(scenario.get("selection", {}).get("availability", {}) == {"campaign": false, "skirmish": true}, "Field commission availability changed.")
	var occupied := {}
	for bucket in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for placement in session.overworld.get(bucket, []):
			if not (placement is Dictionary):
				continue
			var key := "%d,%d" % [int(placement.get("x", -1)), int(placement.get("y", -1))]
			_expect(not occupied.has(key), "Field commission placement collision at %s between %s and %s." % [key, occupied.get(key, ""), placement.get("placement_id", "")])
			occupied[key] = String(placement.get("placement_id", ""))
	_expect(session.overworld.get("encounters", []).size() == 3 and session.overworld.get("towns", []).size() == 2, "Field commission live placement breadth changed.")


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
	var abilities_exact: bool = battle_ability_ids.size() == case.get("ability_ids", []).size()
	for ability_id in case.get("ability_ids", []):
		abilities_exact = abilities_exact and ability_id in battle_ability_ids
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(case.get("encounter_id", "")) and int(enemy_stack.get("base_count", 0)) == 3 and abilities_exact, "%s did not construct its exact production battle stack: %s" % [placement_id, JSON.stringify(enemy_stack)])
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
	_expect(restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict(), "Commission army and hook authority did not survive the save-version-%d round trip." % SessionStateStoreScript.SAVE_VERSION)
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
	_expect(session.to_dict() == authority_before, "Live BattleBoard art observation mutated commission authority.")
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
