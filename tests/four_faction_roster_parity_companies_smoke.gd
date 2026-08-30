extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FOUR_FACTION_ROSTER_PARITY_COMPANIES_SMOKE"
const CASES := [
	{
		"scenario_id": "horizon-compact-six-citadels", "faction_id": "faction_embercourt",
		"town_id": "town_rainwrit_bastion", "town_placement_id": "horizon_rainwrit_town",
		"unit_id": "unit_embercourt_lockglass_writcasters", "building_id": "building_embercourt_oath_pikehall",
		"relief_id": "horizon_compact_day_four_relief", "relief_day": 4, "relief_count": 1,
		"battle_placement_id": "horizon_rainwrit_gate", "encounter_id": "encounter_horizon_rainwrit_charter_gate",
		"tier": 4, "role": "ranged", "ability_ids": ["volley"],
		"source_sha256": "c6593a01dc5039800abde5d5a3d291ffb88321def1943a05a14652283815b87d",
		"portrait_sha256": "ef43a89a805b081f25735b560d1006e769f2a8d9b09e4f778a01e59019f184b3",
		"icon_sha256": "4124f20348e0f00d066ff524dd48fb209956484cf6956af4656d91d9f968d132",
		"standee_sha256": "40c7724d9466f730928aa41b26b3f6abca50c8ec398dba5413eb6245f5826119",
		"overworld_sha256": "e08ecf1cb606632f79a8856e6c45498a8ab9ec93f373b75876c30814706311ec",
		"sheet_sha256": "4d20bff5b13dbec9e0825d31258f47d7ca5b1479742c5101421324d0ff72c369"
	},
	{
		"scenario_id": "mireford-skirmish", "faction_id": "faction_thornwake",
		"town_id": "town_thornwake_graftroot_caravan", "town_placement_id": "graftroot_bridgehead",
		"unit_id": "unit_thornwake_pollenhook_whistlers", "building_id": "building_thornwake_seed_vault",
		"relief_id": "graftroot_seed_train", "relief_day": 3, "relief_count": 4,
		"battle_placement_id": "bridge_ford_reavers", "encounter_id": "encounter_ford_reavers",
		"tier": 1, "role": "ranged", "ability_ids": ["harry"],
		"source_sha256": "aee551c6e0435b80c3bd877f29503ce868d69196a7c881fc0bd23121d036faf4",
		"portrait_sha256": "a3937bea36fc3213f0f368316e58ec2c52c3b6a06b32a8a91bfb9aca5f284da9",
		"icon_sha256": "f2f7099db52340a286bd2258a844b6d8f3dde1deb48131a345e587031cf7c938",
		"standee_sha256": "ce174e43e9d4b8889ba10eeb5bf24955af3611905c8327262dbbf16ff97436e4",
		"overworld_sha256": "0675f653011d3750b3e63c5ebbe48e8b9f492abd0b8ae27e73746be4940ad122",
		"sheet_sha256": "5120a188eb24e7047acb98f9b41929590f219b70ce95fd8ee670c616a729cc1c"
	},
	{
		"scenario_id": "orevein-contract", "faction_id": "faction_brasshollow",
		"town_id": "town_brasshollow_orevein_gantry", "town_placement_id": "orevein_gantry",
		"unit_id": "unit_brasshollow_tallyspring_throwers", "building_id": "building_brasshollow_ore_tithe_office",
		"relief_id": "orevein_clause_train", "relief_day": 3, "relief_count": 4,
		"battle_placement_id": "orevein_charter_counterbattery", "encounter_id": "encounter_lantern_patrol",
		"tier": 1, "role": "ranged", "ability_ids": ["volley"],
		"source_sha256": "4f7df2297cf1f5f0e38ecf50f77c5abf148789af2b035706d7b6288d6257adcd",
		"portrait_sha256": "91d03b955db2d480535b5035e9a4f38f7e18758697dd390b4ed4919a746a4f5c",
		"icon_sha256": "c842ce112d3d143a2397b912b907dfe24f4f5ecc1117041a67531343e5f0b2d6",
		"standee_sha256": "15e5622adada15634faaac98507d2c9f029e131ee7bb531a757aaa24ce8ed5aa",
		"overworld_sha256": "8f45964cca7a866322e5944a14a88f9be8ad7e07ccf120890530367339425b08",
		"sheet_sha256": "e5cdf4fa07b9d64fc79d7678283067d8de3e0cc4fe850254a89dbc903e567b1c"
	},
	{
		"scenario_id": "bellwake-wreck-claim", "faction_id": "faction_veilmourn",
		"town_id": "town_veilmourn_bellwake_harbor", "town_placement_id": "bellwake_harbor",
		"unit_id": "unit_veilmourn_gloamkeel_bulwarks", "building_id": "building_veilmourn_harpoon_gantry",
		"relief_id": "bellwake_salvage_muster", "relief_day": 3, "relief_count": 1,
		"battle_placement_id": "bellwake_sunvault_counter_sortie", "encounter_id": "encounter_glasswing_sortie",
		"tier": 4, "role": "melee", "ability_ids": ["brace", "fog_screen"],
		"source_sha256": "28200cc4bc83bbaec5230cd8554fa5f94129f7d4f3cb1b07ce574ce6f1f8a6ea",
		"portrait_sha256": "9100c6853782cee63204a64ad03fa4ab6b198b5060e009cbac725ed110198d01",
		"icon_sha256": "5736bb555dec353b63038e3afe15cced02ad4c96156002d7ffbcc4daf906dc05",
		"standee_sha256": "b96aa760a891c8a5047352b70162f47513359aa24764c9d277544b3012a92a8d",
		"overworld_sha256": "7c7e5ce5cb724ff901d0143a9f54da700c9fb573664cfbb8b4aacad6f36d2294",
		"sheet_sha256": "f6d8e6b54ba9974eb7a4c1551af6715e6f7542b32d7ab125cb2df0746d786b09"
	}
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	_expect(ContentService.get_content_ids(ContentService.UNITS_PATH).size() == 130, "Roster-parity batch must complete the 130-unit catalog.")
	for faction_id in ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake", "faction_brasshollow", "faction_veilmourn"]:
		_expect(_faction_unit_count(faction_id) == 12, "%s must expose exactly twelve live units." % faction_id)
	for case_value in CASES:
		await _run_case(case_value)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({
			"ok": true, "company_count": CASES.size(), "twelve_unit_faction_count": 6,
			"relief_route_count": CASES.size(), "town_recruit_count": CASES.size(),
			"live_battle_count": CASES.size(), "exact_art_surface_count": CASES.size() * 6,
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
	var recruits_before := int(initial_town.get("available_recruits", {}).get(unit_id, 0))
	session.day = int(case.get("relief_day", 0))
	var hook_result := ScenarioScriptRulesScript.process_hooks(session)
	var town := _row_by_key(session.overworld.get("towns", []), "placement_id", String(case.get("town_placement_id", "")))
	var recruits_after := int(town.get("available_recruits", {}).get(unit_id, 0))
	_expect(String(case.get("relief_id", "")) in hook_result.get("fired_ids", []) and recruits_after == recruits_before + int(case.get("relief_count", 0)), "%s exact relief route changed: %s" % [unit_id, JSON.stringify(hook_result)])
	_expect(String(town.get("town_id", "")) == String(case.get("town_id", "")) and String(town.get("owner", "")) == "player", "%s player town route changed." % scenario_id)

	var is_existing_building: bool = building_id in town.get("built_buildings", []) or building_id in ContentService.get_town(String(case.get("town_id", ""))).get("starting_building_ids", [])
	_prepare_town_for_build(session, town, building_id, unit_id, is_existing_building)
	var build_result: Dictionary = {"ok": true, "existing_building": true} if is_existing_building else TownRules.build_active_town(session, building_id)
	var built_town := _row_by_key(session.overworld.get("towns", []), "placement_id", String(case.get("town_placement_id", "")))
	var weekly_growth := int(OverworldRules.town_weekly_growth(built_town, session).get(unit_id, 0))
	var before_muster := _army_unit_count(session, unit_id)
	var muster_result: Dictionary = TownRules.recruit_active_town(session, unit_id, 1)
	_expect(bool(build_result.get("ok", false)) and building_id in built_town.get("built_buildings", []), "%s did not establish live dwelling authority: %s" % [building_id, JSON.stringify(build_result)])
	_expect(weekly_growth >= 1 and bool(muster_result.get("ok", false)) and _army_unit_count(session, unit_id) == before_muster + 1, "%s did not establish bounded weekly growth and live muster authority: weekly=%d result=%s" % [unit_id, weekly_growth, JSON.stringify(muster_result)])

	var placement := _row_by_key(session.overworld.get("encounters", []), "placement_id", String(case.get("battle_placement_id", "")))
	_expect(String(placement.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s authored battle route changed." % scenario_id)
	var battle := BattleRulesScript.create_battle_payload(session, placement)
	var company_stack := _battle_stack(battle.get("stacks", []), unit_id, "player")
	_expect(not battle.is_empty() and int(company_stack.get("base_count", 0)) >= 1, "%s was not deployed from the live recruited army." % unit_id)
	session.battle = battle
	await _validate_battle_art(session, unit_id)
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	_expect(String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement), "%s company battle did not resolve through live victory authority." % unit_id)
	var authority_after := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_after)
	_expect(restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority_after, "%s state did not round-trip through save version %d." % [unit_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id": scenario_id, "unit_id": unit_id, "relief_recruits": int(case.get("relief_count", 0)), "mustered": 1, "battle_victory": true, "weekly_growth": weekly_growth, "save_exact": true})
	SessionState.set_active_session(null)


func _validate_content_and_art(case: Dictionary) -> void:
	var unit_id := String(case.get("unit_id", ""))
	var building_id := String(case.get("building_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var building := ContentService.get_building(building_id)
	var unit_art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	_expect(String(unit.get("faction_id", "")) == String(case.get("faction_id", "")) and String(unit.get("role", "")) == String(case.get("role", "")) and int(unit.get("tier", 0)) == int(case.get("tier", 0)) and String(unit.get("content_status", "")) == "four_faction_roster_parity_company_live", "%s gameplay identity changed." % unit_id)
	_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s ability contract changed." % unit_id)
	_expect(int(building.get("growth_bonus", {}).get(unit_id, 0)) == 1 and int(building.get("recruitment_discount_percent", {}).get(unit_id, 0)) == 4, "%s recruitment contract changed." % building_id)
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


func _faction_unit_count(faction_id: String) -> int:
	var total := 0
	for unit_id in ContentService.get_content_ids(ContentService.UNITS_PATH):
		if String(ContentService.get_unit(String(unit_id)).get("faction_id", "")) == faction_id:
			total += 1
	return total


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
