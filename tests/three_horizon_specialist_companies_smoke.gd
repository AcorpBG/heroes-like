extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "THREE_HORIZON_SPECIALIST_COMPANIES_SMOKE"
const CASES := [
	{
		"scenario_id": "crownroot-quenchline-verdict",
		"faction_id": "faction_thornwake",
		"town_id": "town_crownroot_refuge",
		"town_placement_id": "crownroot_court_home",
		"unit_id": "unit_thornwake_seedglass_cantors",
		"building_id": "building_thornwake_seedglass_cantory",
		"encounter_id": "encounter_crownroot_seedglass_trial",
		"army_id": "army_crownroot_seedglass_trial",
		"counterstroke_id": "crownroot_counterstroke",
		"placement_id": "crownroot_counterstroke_front",
		"survivor_hook_id": "crownroot_seedglass_survivors",
		"join_flag": "crownroot_seedglass_company_joined",
		"ability_ids": ["harry", "volley"],
		"source_sha256": "8681a55c2a69ea56fc3c5210e13fa594aec2ce15e9fdb4378e0503c1448e4cce",
		"portrait_sha256": "4d8fbb7768c60457546f285ae2f143903f9d663ee03a5354b7e1158e5d73f8d9",
		"icon_sha256": "ee33b5ad9a242c86854b4927a07c93b27bd511b0b80d3ea66d8b2cb2d483f026",
		"standee_sha256": "c643cb44879599f232c3ea6f282b1c7efcf7e2348833126f9884054f64ebb2bf",
		"overworld_sha256": "20c588116da37f8dec547af4083af137443fa2866e8a6d01db08f4e7b8356676",
		"sheet_sha256": "0ec099f044f7896a0808c7d76f76fbc11520996ddd16f4a60b70c665e5e5489f",
		"building_source_sha256": "bfe79166b6f683e2dc3ad7fa454816a1d62f5d570811ec94d59302a2548f5ead",
		"building_icon_sha256": "4ba935e1801f23f85698fe9d499354fefc143f88828a4fec5213ce9c457cb9a9"
	},
	{
		"scenario_id": "blackbell-saltwake-foreclosure",
		"faction_id": "faction_brasshollow",
		"town_id": "town_blackbell_foundry",
		"town_placement_id": "blackbell_court_home",
		"unit_id": "unit_brasshollow_quenchbell_mortars",
		"building_id": "building_brasshollow_quenchbell_mortar_bay",
		"encounter_id": "encounter_blackbell_quenchbell_proving",
		"army_id": "army_blackbell_quenchbell_proving",
		"counterstroke_id": "blackbell_counterstroke",
		"placement_id": "blackbell_counterstroke_front",
		"survivor_hook_id": "blackbell_quenchbell_survivors",
		"join_flag": "blackbell_quenchbell_company_joined",
		"ability_ids": ["volley", "harry"],
		"source_sha256": "d13d6b5da5bd7284e51360a70bc2611e5effcb1ab2d0048af06fded673408bdb",
		"portrait_sha256": "d646eb356cfee80a7399be6a67b23f6d800e24dcbc79a2b82e5777df99ef4a42",
		"icon_sha256": "e6426b726277d6f719e8d9dce74e01a7d4a21606bdc68f08531188166e37d901",
		"standee_sha256": "3619259786cc8ab4113b99a9efe440cdba4cb624c089be80e106efda6a926cc0",
		"overworld_sha256": "15d0bf63397ae22e493c944cf1a5ef294f1a3b72039838f6ce38230e6c08568f",
		"sheet_sha256": "324fea40c05d47544735cac682902c8e1fdc502b1ef35d62e5f57401f70cc850",
		"building_source_sha256": "fe0f69ac21e4c6db7384987dfa97dd374b29283e544a69809e81dca55441e560",
		"building_icon_sha256": "d22591d5b04db49ba5488b685ac709cf9ecb3e4aa54d035eb6c901df65cd05e2"
	},
	{
		"scenario_id": "pale-sounding-tidewrit-reckoning",
		"faction_id": "faction_veilmourn",
		"town_id": "town_pale_sounding_harbor",
		"town_placement_id": "pale_court_home",
		"unit_id": "unit_veilmourn_saltwake_eulogists",
		"building_id": "building_veilmourn_saltwake_eulogy_house",
		"encounter_id": "encounter_pale_saltwake_recital",
		"army_id": "army_pale_saltwake_recital",
		"counterstroke_id": "pale_counterstroke",
		"placement_id": "pale_counterstroke_front",
		"survivor_hook_id": "pale_saltwake_survivors",
		"join_flag": "pale_saltwake_company_joined",
		"ability_ids": ["obituary", "volley"],
		"source_sha256": "0b9b571182de7753f09fd97c1ca0853fa32fd36eca3b3776b65143ceed2b20c6",
		"portrait_sha256": "2324418a9ff1cb7112b0fd068d2efbbaac67bf69114f79cfb8fa325e15c70f4e",
		"icon_sha256": "10b8c75399df881a645c7b2c79e7eecb26e5589a3ed624ce15c29fdf1819dc26",
		"standee_sha256": "1e8d6a74a627fae82b13d62647a2e4367c2070a6bfb3782f4f0cd9e8ce6c0ece",
		"overworld_sha256": "365fcbd4594e0733982150fa0a73a50131066c66d0bad48f96d0f00c309b5640",
		"sheet_sha256": "02448ea47aaa5daa32f5883bde6681d32ef7fffbd90026f27b1a30027ef1fff6",
		"building_source_sha256": "87cde663f883e3211d60dcd3b6539fe868ac758dbab0459f6753f8f76e45aa61",
		"building_icon_sha256": "b52b67af0948e3eee627bea3be126245d863cdb9c718ee3af9d94527ad5d3d78"
	}
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	_expect(ContentService.get_content_ids(ContentService.UNITS_PATH).size() == 120, "Specialist batch must expand the live unit catalog to 120.")
	for case_value in CASES:
		await _run_case(case_value)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({
			"ok": true,
			"company_count": CASES.size(),
			"live_battle_count": CASES.size(),
			"town_build_count": CASES.size(),
			"muster_count": CASES.size(),
			"survivor_recruit_count": CASES.size() * 2,
			"exact_art_surface_count": CASES.size() * 8,
			"save_version": SessionStateStoreScript.SAVE_VERSION,
			"single_consolidated_smoke": true,
			"rows": _rows
		})])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var unit_id := String(case.get("unit_id", ""))
	var building_id := String(case.get("building_id", ""))
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	_validate_content_and_art(case)

	session.day = 4
	var spawn_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(String(case.get("counterstroke_id", "")) in spawn_result.get("fired_ids", []), "%s did not spawn its day-four specialist trial." % scenario_id)
	var placement := _encounter(session, String(case.get("placement_id", "")))
	_expect(String(placement.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s specialist encounter identity changed." % scenario_id)

	var town := _town(session, String(case.get("town_placement_id", "")))
	_expect(String(town.get("town_id", "")) == String(case.get("town_id", "")) and String(town.get("owner", "")) == "player", "%s player town route changed." % scenario_id)
	_prepare_town_for_build(session, town, building_id, unit_id)
	var build_action := _row_by_key(TownRules.get_build_actions(session), "id", "build:%s" % building_id)
	var build_result: Dictionary = TownRules.build_active_town(session, building_id)
	var built_town := _town(session, String(case.get("town_placement_id", "")))
	var immediate_recruits := int(built_town.get("available_recruits", {}).get(unit_id, 0))
	var weekly_growth := int(OverworldRules.town_weekly_growth(built_town, session).get(unit_id, 0))
	var before_muster := _army_unit_count(session, unit_id)
	var muster_result: Dictionary = TownRules.recruit_active_town(session, unit_id, 1)
	var after_muster := _army_unit_count(session, unit_id)
	_expect(not build_action.is_empty() and not bool(build_action.get("disabled", true)) and bool(build_result.get("ok", false)), "%s specialist building did not expose and execute a ready build action: %s" % [building_id, JSON.stringify(build_result)])
	_expect(building_id in built_town.get("built_buildings", []) and immediate_recruits >= 2 and weekly_growth >= 2, "%s did not establish immediate and weekly specialist growth." % building_id)
	_expect(bool(muster_result.get("ok", false)) and after_muster == before_muster + 1, "%s did not recruit through live TownRules authority." % unit_id)

	var battle := BattleRulesScript.create_battle_payload(session, placement)
	var specialist_stack := _battle_stack(battle.get("stacks", []), unit_id, "enemy")
	_expect(not battle.is_empty() and int(specialist_stack.get("base_count", 0)) == 3, "%s did not construct its exact specialist battle stack." % unit_id)
	session.battle = battle
	await _validate_battle_art(session, unit_id)
	var before_survivors := _army_unit_count(session, unit_id)
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	_expect(String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement), "%s specialist trial did not resolve through live battle victory." % unit_id)
	var recruit_result := ScenarioScriptRulesScript.process_hooks(session)
	var after_survivors := _army_unit_count(session, unit_id)
	var fired_hook_ids: Array = session.overworld.get(ScenarioScriptRulesScript.SCRIPT_STATE_KEY, {}).get("fired_hook_ids", [])
	_expect(String(case.get("survivor_hook_id", "")) in fired_hook_ids and after_survivors == before_survivors + 2 and bool(session.flags.get(String(case.get("join_flag", "")), false)), "%s survivor company did not join exactly once: %s" % [unit_id, JSON.stringify(recruit_result)])
	var authority_after := session.to_dict()
	var repeat_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(not (String(case.get("survivor_hook_id", "")) in repeat_result.get("fired_ids", [])) and session.to_dict() == authority_after, "%s survivor hook repeated or mutated authority twice." % unit_id)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_after)
	_expect(restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority_after, "%s specialist town, army, and hook state did not round-trip through save version %d." % [unit_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id": scenario_id, "unit_id": unit_id, "building_id": building_id, "battle_victory": true, "mustered": 1, "survivors_joined": 2, "weekly_growth": weekly_growth, "save_exact": true})
	SessionState.set_active_session(null)


func _validate_content_and_art(case: Dictionary) -> void:
	var unit_id := String(case.get("unit_id", ""))
	var building_id := String(case.get("building_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var building := ContentService.get_building(building_id)
	var unit_art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	var building_art := ContentService.get_building_art(building_id)
	_expect(String(unit.get("faction_id", "")) == String(case.get("faction_id", "")) and String(unit.get("role", "")) == "ranged" and int(unit.get("tier", 0)) == 5 and String(unit.get("content_status", "")) == "horizon_specialist_company_live", "%s gameplay identity changed." % unit_id)
	_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s ability contract changed." % unit_id)
	_expect(String(building.get("faction_id", "")) == String(case.get("faction_id", "")) and String(building.get("unlock_unit_id", "")) == unit_id and int(building.get("growth_bonus", {}).get(unit_id, 0)) == 2 and String(building.get("content_status", "")) == "horizon_specialist_company_live", "%s building contract changed." % building_id)
	var unit_paths := [
		"res://art/units/source/curated/%s.png" % unit_id,
		"res://art/units/portraits/%s.png" % unit_id,
		"res://art/units/battle_icons/%s.png" % unit_id,
		"res://art/units/battle_standees/%s.png" % unit_id,
		"res://art/units/overworld_icons/%s.png" % unit_id,
		"res://art/animation/runtime/units/%s.png" % unit_id
	]
	var unit_hashes := [case.get("source_sha256", ""), case.get("portrait_sha256", ""), case.get("icon_sha256", ""), case.get("standee_sha256", ""), case.get("overworld_sha256", ""), case.get("sheet_sha256", "")]
	var unit_sizes := [Vector2i(512, 512), Vector2i(384, 512), Vector2i(160, 160), Vector2i(192, 224), Vector2i(96, 96), Vector2i(256, 896)]
	for index in range(unit_paths.size()):
		var image := _load_image(unit_paths[index])
		_expect(FileAccess.get_sha256(unit_paths[index]) == String(unit_hashes[index]) and image != null and image.get_size() == unit_sizes[index], "%s art surface changed at %s." % [unit_id, unit_paths[index]])
	_expect(String(unit_art.get("curated_source_sha256", "")) == String(case.get("source_sha256", "")) and String(animation.get("curated_source_sha256", "")) == String(case.get("source_sha256", "")), "%s curated unit provenance changed." % unit_id)
	var building_source := "res://art/towns/source/buildings/curated/%s.png" % building_id
	var building_icon := "res://art/towns/runtime/buildings/%s.png" % building_id
	var source_image := _load_image(building_source)
	var icon_image := _load_image(building_icon)
	_expect(FileAccess.get_sha256(building_source) == String(case.get("building_source_sha256", "")) and source_image != null and source_image.get_size() == Vector2i(1254, 1254), "%s source art changed." % building_id)
	_expect(FileAccess.get_sha256(building_icon) == String(case.get("building_icon_sha256", "")) and icon_image != null and icon_image.get_size() == Vector2i(256, 256), "%s runtime icon changed." % building_id)
	_expect(String(building_art.get("source_sha256", "")) == String(case.get("building_source_sha256", "")) and String(building_art.get("icon_sha256", "")) == String(case.get("building_icon_sha256", "")), "%s curated building provenance changed." % building_id)


func _prepare_town_for_build(session: SessionStateStoreScript.SessionData, town: Dictionary, building_id: String, unit_id: String) -> void:
	session.day = 30
	session.overworld["resources"] = {"gold": 100000, "wood": 1000, "ore": 1000, "aetherglass": 1000, "embergrain": 1000, "peatwax": 1000, "verdant_grafts": 1000, "brass_scrip": 1000, "memory_salt": 1000}
	var built_buildings: Array = town.get("built_buildings", []).duplicate(true)
	for requirement_value in ContentService.get_building(building_id).get("requires", []):
		_append_building_requirements(built_buildings, String(requirement_value))
	built_buildings.erase(building_id)
	town["built_buildings"] = built_buildings
	town["last_build_day"] = 29
	var available: Dictionary = town.get("available_recruits", {}).duplicate(true)
	available.erase(unit_id)
	town["available_recruits"] = available
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_expect(bool(visit_result.get("ok", false)), "%s could not establish the live town visit needed for build and muster." % building_id)


func _append_building_requirements(target: Array, building_id: String) -> void:
	if building_id == "" or building_id in target:
		return
	var building := ContentService.get_building(building_id)
	for requirement_value in building.get("requires", []):
		_append_building_requirements(target, String(requirement_value))
	target.append(building_id)


func _validate_battle_art(session: SessionStateStoreScript.SessionData, unit_id: String) -> void:
	SessionState.set_active_session(session)
	var board = BattleBoardViewScript.new()
	board.size = Vector2(900, 560)
	add_child(board)
	board.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary: Dictionary = board.validation_unit_art_summary()
	var matches: Array = summary.get("stacks", []).filter(func(entry): return entry is Dictionary and String(entry.get("unit_id", "")) == unit_id and bool(entry.get("loaded", false)) and bool(entry.get("battle_standee_loaded", false)) and bool(entry.get("animation_loaded", false)))
	_expect(not matches.is_empty(), "%s did not load its portrait/icon, standee, and animation on the live battle board." % unit_id)
	board.queue_free()
	await get_tree().process_frame


func _town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return _row_by_key(session.overworld.get("towns", []), "placement_id", placement_id)


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return _row_by_key(session.overworld.get("encounters", []), "placement_id", placement_id)


func _row_by_key(rows: Variant, key: String, expected: String) -> Dictionary:
	for row_value in rows if rows is Array else []:
		if row_value is Dictionary and String(row_value.get(key, "")) == expected:
			return row_value
	return {}


func _battle_stack(stacks: Variant, unit_id: String, side: String) -> Dictionary:
	for stack_value in stacks if stacks is Array else []:
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id and String(stack_value.get("side", "")) == side:
			return stack_value
	return {}


func _ability_ids(abilities: Variant) -> Array:
	var result := []
	for ability in abilities if abilities is Array else []:
		if ability is Dictionary:
			result.append(String(ability.get("id", "")))
	return result


func _army_unit_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	var total := 0
	for stack_value in session.overworld.get("army", {}).get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
			total += int(stack_value.get("count", 0))
	return total


func _move_active_hero_to_town(session: SessionStateStoreScript.SessionData, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = position.x
	hero["y"] = position.y
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero


func _load_image(path: String) -> Image:
	var image := Image.new()
	return image if image.load(ProjectSettings.globalize_path(path)) == OK else null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
