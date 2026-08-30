extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "THREE_HORIZON_SKIRMISH_COMPANIES_SMOKE"
const CASES := [
	{
		"scenario_id": "crownroot-quenchline-verdict", "faction_id": "faction_thornwake",
		"town_id": "town_crownroot_refuge", "town_placement_id": "crownroot_court_home",
		"unit_id": "unit_thornwake_bramblekite_needlers", "companion_ids": ["unit_thornwake_seedglass_cantors", "unit_thornwake_seedshield_wardens"],
		"building_id": "building_thornwake_bramble_toll", "encounter_id": "encounter_crownroot_seedglass_trial",
		"placement_id": "crownroot_counterstroke_front", "counterstroke_id": "crownroot_counterstroke", "relief_id": "crownroot_relief",
		"survivor_hook_id": "crownroot_seedglass_survivors", "join_flag": "crownroot_seedglass_company_joined",
		"tier": 2, "ability_ids": ["harry"], "relief_count": 3, "battle_count": 5,
		"source_sha256": "3550f9978d09a49ff29382ef9fcb06db350bb394425475afba7944ebb42aecf8",
		"portrait_sha256": "fbbfa934abb0047cb64e8b84319d3bc410e82c7b4f2ddeb6f755fe5de3af934f",
		"icon_sha256": "be34c7ca387ad82343ddba022f35e7c036610390e0124cd7f36a1375633468dc",
		"standee_sha256": "3f022de22d9d11f4028f3c865c5a102404fe33436c61986e02f983e488cefbe9",
		"overworld_sha256": "d6042ac5a4cd329951e8ebb3eb9e54bc4be4dc589640a7904de75d3f3f73f297",
		"sheet_sha256": "c167d2b7bb39607a8a181abe4d25d4e0a3386527171678e2d63c7721127600dc"
	},
	{
		"scenario_id": "blackbell-saltwake-foreclosure", "faction_id": "faction_brasshollow",
		"town_id": "town_blackbell_foundry", "town_placement_id": "blackbell_court_home",
		"unit_id": "unit_brasshollow_quenchspool_slingers", "companion_ids": ["unit_brasshollow_quenchbell_mortars", "unit_brasshollow_gaugefire_arbalists"],
		"building_id": "building_brasshollow_rivet_kennels", "encounter_id": "encounter_blackbell_quenchbell_proving",
		"placement_id": "blackbell_counterstroke_front", "counterstroke_id": "blackbell_counterstroke", "relief_id": "blackbell_relief",
		"survivor_hook_id": "blackbell_quenchbell_survivors", "join_flag": "blackbell_quenchbell_company_joined",
		"tier": 2, "ability_ids": ["volley"], "relief_count": 3, "battle_count": 5,
		"source_sha256": "613765314d1a256a1503a0371da838f10f4ce8be62a0c0154cb3ff8cef34d05d",
		"portrait_sha256": "d3b33c305e7b74842704e77ef619f5005e877e677df8fc5414535adcb7818473",
		"icon_sha256": "88719bc6ba4428f7e8596673b9d73f7bdd923dccf10db228c3f0b3ad60b4a8a8",
		"standee_sha256": "d479ce852332403ac7d225d27b48099d9a18fa317d441c2b6462f572f8c129ea",
		"overworld_sha256": "b4da23771ef45996ba8a3fb684f92fd35445d1d844f03767470cf7c7db0c28ee",
		"sheet_sha256": "acdfd9fab7c50e9b92dd7e61797d04e41cb61d1496d5d05429e9966c5f1729ed"
	},
	{
		"scenario_id": "pale-sounding-tidewrit-reckoning", "faction_id": "faction_veilmourn",
		"town_id": "town_pale_sounding_harbor", "town_placement_id": "pale_court_home",
		"unit_id": "unit_veilmourn_saltbell_casters", "companion_ids": ["unit_veilmourn_saltwake_eulogists", "unit_veilmourn_wakechain_boarders"],
		"building_id": "building_veilmourn_ransom_exchange", "encounter_id": "encounter_pale_saltwake_recital",
		"placement_id": "pale_counterstroke_front", "counterstroke_id": "pale_counterstroke", "relief_id": "pale_relief",
		"survivor_hook_id": "pale_saltwake_survivors", "join_flag": "pale_saltwake_company_joined",
		"tier": 1, "ability_ids": ["harry"], "relief_count": 4, "battle_count": 7,
		"source_sha256": "0e433b71732ac76abdd51c14262095bccd75f8ee303b6aad1d033ebb911f0c27",
		"portrait_sha256": "a140027876eb33ebfe214e664729c637d05c032f37765306e4cc2a63c9b2a399",
		"icon_sha256": "37461182b2f85c2a01e2323a0a6410ec3969549e5812ac7fc5b5bab5fedc92ae",
		"standee_sha256": "8f7d01f3961d419075ecce868d1e0fa7e2d7920f070d82adfaa5f2cef9aa27e9",
		"overworld_sha256": "8839df2d68e8203ef9f55802d7fdcc18b5b9313714d69727330e1cda2c491be2",
		"sheet_sha256": "7a0637a54554d53c2d46598b4ea38c983f2433772680215f2e6652f99fd3ad12"
	}
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	_expect(ContentService.get_content_ids(ContentService.UNITS_PATH).size() == 126, "Skirmish batch must complete the 126-unit catalog.")
	for case_value in CASES:
		await _run_case(case_value)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({
			"ok": true, "company_count": CASES.size(), "relief_route_count": CASES.size(),
			"live_battle_count": CASES.size(), "town_recruit_count": CASES.size(),
			"survivor_company_count": CASES.size() * 3, "exact_art_surface_count": CASES.size() * 6,
			"save_version": SessionStateStoreScript.SAVE_VERSION, "single_consolidated_smoke": true, "rows": _rows
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

	var initial_town := _row_by_key(session.overworld.get("towns", []), "placement_id", String(case.get("town_placement_id", "")))
	var recruits_before_relief := int(initial_town.get("available_recruits", {}).get(unit_id, 0))
	session.day = 4
	var spawn_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(String(case.get("relief_id", "")) in spawn_result.get("fired_ids", []) and String(case.get("counterstroke_id", "")) in spawn_result.get("fired_ids", []), "%s did not fire its combined relief and battle routes." % scenario_id)
	var placement := _row_by_key(session.overworld.get("encounters", []), "placement_id", String(case.get("placement_id", "")))
	_expect(String(placement.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s skirmish encounter route changed." % scenario_id)
	var town := _row_by_key(session.overworld.get("towns", []), "placement_id", String(case.get("town_placement_id", "")))
	var recruits_after_relief := int(town.get("available_recruits", {}).get(unit_id, 0))
	_expect(String(town.get("town_id", "")) == String(case.get("town_id", "")) and String(town.get("owner", "")) == "player" and recruits_after_relief == recruits_before_relief + int(case.get("relief_count", 0)), "%s player-town relief changed." % scenario_id)

	var town_template := ContentService.get_town(String(case.get("town_id", "")))
	var is_existing_building: bool = building_id in town.get("built_buildings", []) or building_id in town_template.get("starting_building_ids", [])
	_prepare_town_for_build(session, town, building_id, unit_id, is_existing_building)
	var build_result: Dictionary = {"ok": true, "existing_building": true} if is_existing_building else TownRules.build_active_town(session, building_id)
	var built_town := _row_by_key(session.overworld.get("towns", []), "placement_id", String(case.get("town_placement_id", "")))
	var weekly_growth := int(OverworldRules.town_weekly_growth(built_town, session).get(unit_id, 0))
	var before_muster := _army_unit_count(session, unit_id)
	var muster_result: Dictionary = TownRules.recruit_active_town(session, unit_id, 1)
	_expect(bool(build_result.get("ok", false)) and building_id in built_town.get("built_buildings", []), "%s did not establish its live building authority: %s" % [building_id, JSON.stringify(build_result)])
	_expect(weekly_growth >= max(1, int(ContentService.get_unit(unit_id).get("growth", 1)) - 1) and bool(muster_result.get("ok", false)) and _army_unit_count(session, unit_id) == before_muster + 1, "%s did not establish weekly growth and live muster authority." % unit_id)

	var battle := BattleRulesScript.create_battle_payload(session, placement)
	var skirmish_stack := _battle_stack(battle.get("stacks", []), unit_id, "enemy")
	_expect(not battle.is_empty() and int(skirmish_stack.get("base_count", 0)) == int(case.get("battle_count", 0)), "%s did not construct its exact skirmish-company battle stack." % unit_id)
	session.battle = battle
	await _validate_battle_art(session, unit_id)
	var survivor_counts := {unit_id: _army_unit_count(session, unit_id)}
	for companion_id_value in case.get("companion_ids", []):
		var companion_id := String(companion_id_value)
		survivor_counts[companion_id] = _army_unit_count(session, companion_id)
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	_expect(String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement), "%s company battle did not resolve through live victory authority." % unit_id)
	var recruit_result := ScenarioScriptRulesScript.process_hooks(session)
	var fired_hook_ids: Array = session.overworld.get(ScenarioScriptRulesScript.SCRIPT_STATE_KEY, {}).get("fired_hook_ids", [])
	var survivors_exact := _army_unit_count(session, unit_id) == int(survivor_counts.get(unit_id, 0)) + 2
	for companion_id_value in case.get("companion_ids", []):
		var companion_id := String(companion_id_value)
		survivors_exact = survivors_exact and _army_unit_count(session, companion_id) == int(survivor_counts.get(companion_id, 0)) + 2
	_expect(String(case.get("survivor_hook_id", "")) in fired_hook_ids and survivors_exact and bool(session.flags.get(String(case.get("join_flag", "")), false)), "%s three-company survivors did not join exactly: %s" % [unit_id, JSON.stringify(recruit_result)])
	var authority_after := session.to_dict()
	var repeat_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(not (String(case.get("survivor_hook_id", "")) in repeat_result.get("fired_ids", [])) and session.to_dict() == authority_after, "%s survivor hook repeated or mutated authority twice." % unit_id)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_after)
	_expect(restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority_after, "%s state did not round-trip through save version %d." % [unit_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id": scenario_id, "unit_id": unit_id, "relief_recruits": int(case.get("relief_count", 0)), "battle_victory": true, "mustered": 1, "three_company_survivors_joined": 6, "weekly_growth": weekly_growth, "save_exact": true})
	SessionState.set_active_session(null)


func _validate_content_and_art(case: Dictionary) -> void:
	var unit_id := String(case.get("unit_id", ""))
	var building_id := String(case.get("building_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var building := ContentService.get_building(building_id)
	var unit_art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	_expect(String(unit.get("faction_id", "")) == String(case.get("faction_id", "")) and String(unit.get("role", "")) == "ranged" and int(unit.get("tier", 0)) == int(case.get("tier", 0)) and String(unit.get("content_status", "")) == "horizon_skirmish_company_live", "%s gameplay identity changed." % unit_id)
	_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s ability contract changed." % unit_id)
	_expect(int(building.get("growth_bonus", {}).get(unit_id, 0)) == 1 and int(building.get("recruitment_discount_percent", {}).get(unit_id, 0)) == 4, "%s skirmish recruitment contract changed." % building_id)
	var paths := [
		"res://art/units/source/curated/%s.png" % unit_id, "res://art/units/portraits/%s.png" % unit_id,
		"res://art/units/battle_icons/%s.png" % unit_id, "res://art/units/battle_standees/%s.png" % unit_id,
		"res://art/units/overworld_icons/%s.png" % unit_id, "res://art/animation/runtime/units/%s.png" % unit_id
	]
	var hashes := [case.get("source_sha256", ""), case.get("portrait_sha256", ""), case.get("icon_sha256", ""), case.get("standee_sha256", ""), case.get("overworld_sha256", ""), case.get("sheet_sha256", "")]
	var sizes := [Vector2i(512, 512), Vector2i(384, 512), Vector2i(160, 160), Vector2i(192, 224), Vector2i(96, 96), Vector2i(256, 896)]
	for index in range(paths.size()):
		var image := _load_image(paths[index])
		_expect(FileAccess.get_sha256(paths[index]) == String(hashes[index]) and image != null and image.get_size() == sizes[index], "%s art surface changed at %s." % [unit_id, paths[index]])
	_expect(String(unit_art.get("curated_source_sha256", "")) == String(case.get("source_sha256", "")) and String(animation.get("curated_source_sha256", "")) == String(case.get("source_sha256", "")), "%s curated provenance changed." % unit_id)


func _prepare_town_for_build(session: SessionStateStoreScript.SessionData, town: Dictionary, building_id: String, unit_id: String, is_existing_building: bool) -> void:
	session.day = 30
	session.overworld["resources"] = {"gold": 100000, "wood": 1000, "ore": 1000, "aetherglass": 1000, "embergrain": 1000, "peatwax": 1000, "verdant_grafts": 1000, "brass_scrip": 1000, "memory_salt": 1000}
	var built_buildings: Array = town.get("built_buildings", []).duplicate(true)
	if not is_existing_building:
		for requirement_value in ContentService.get_building(building_id).get("requires", []):
			_append_building_requirements(built_buildings, String(requirement_value))
		built_buildings.erase(building_id)
	town["built_buildings"] = built_buildings
	town["last_build_day"] = 29
	var available: Dictionary = town.get("available_recruits", {}).duplicate(true)
	if not is_existing_building:
		available.erase(unit_id)
	town["available_recruits"] = available
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_expect(bool(visit_result.get("ok", false)), "%s could not establish its live town visit." % building_id)


func _append_building_requirements(target: Array, building_id: String) -> void:
	if building_id == "" or building_id in target:
		return
	for requirement_value in ContentService.get_building(building_id).get("requires", []):
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
	_expect(not matches.is_empty(), "%s did not load its exact art on the live battle board." % unit_id)
	board.queue_free()
	await get_tree().process_frame


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
