extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "THREE_HORIZON_RESERVE_COMPANIES_SMOKE"
const CASES := [
	{
		"scenario_id": "crownroot-quenchline-verdict", "faction_id": "faction_thornwake",
		"town_id": "town_crownroot_refuge", "town_placement_id": "crownroot_court_home",
		"unit_id": "unit_thornwake_seedshield_wardens", "specialist_unit_id": "unit_thornwake_seedglass_cantors",
		"building_id": "building_thornwake_sporeglass_hothouse", "encounter_id": "encounter_crownroot_seedglass_trial",
		"placement_id": "crownroot_counterstroke_front", "counterstroke_id": "crownroot_counterstroke",
		"survivor_hook_id": "crownroot_seedglass_survivors", "join_flag": "crownroot_seedglass_company_joined",
		"role": "melee", "ability_ids": ["brace", "shielding"],
		"source_sha256": "6b06cd03bab0045ad1c3e467b369bdb2d183ab56e848c77f351a6c3faf6480f3",
		"portrait_sha256": "2116bdb2780fe7f1801126a0ad8b1011996ad1f29c04bbac0eacf8170de5f787",
		"icon_sha256": "4e4e327bde8d66e6a1577e06a5a4cbb5ab1811fc53020920ad26a3aa7bb22a7f",
		"standee_sha256": "4923eb8fc68283b817b240ea901365bfffcdeae7583ba293ab8c7d4b7efc5087",
		"overworld_sha256": "b58695983491dcfa2692c46d8084bf5003e620be403e3ccae868b678b1c76828",
		"sheet_sha256": "5bd536b36f8eb40382c365b2ec852777ed2d829be2c4cd07136c39b90165f346"
	},
	{
		"scenario_id": "blackbell-saltwake-foreclosure", "faction_id": "faction_brasshollow",
		"town_id": "town_blackbell_foundry", "town_placement_id": "blackbell_court_home",
		"unit_id": "unit_brasshollow_gaugefire_arbalists", "specialist_unit_id": "unit_brasshollow_quenchbell_mortars",
		"building_id": "building_brasshollow_pavis_foundry", "encounter_id": "encounter_blackbell_quenchbell_proving",
		"placement_id": "blackbell_counterstroke_front", "counterstroke_id": "blackbell_counterstroke",
		"survivor_hook_id": "blackbell_quenchbell_survivors", "join_flag": "blackbell_quenchbell_company_joined",
		"role": "ranged", "ability_ids": ["volley", "harry"],
		"source_sha256": "cd0581b664a61a385cecb956af6d1284f12c46bfe142ffe82e8e5cacd4c2a6c6",
		"portrait_sha256": "b079394b8302b5251e196ea5fa0380119e3fe196e050085d0076c132550514f9",
		"icon_sha256": "acaca4e7b7865387784877ef98acbc7dffc03e8a0674b9d5395e711ae4167ece",
		"standee_sha256": "92618aa666e1b7611269740a5c88e88dc25bbf37efc8687cb807ce642d81f42f",
		"overworld_sha256": "f2e453372c7464074f2d7270e8c5c1184935b112ccc962010f460dc88ac9aca4",
		"sheet_sha256": "f166996d00ad7f120c05ff62b5378bd98c93d29abc1706de8c50c7cf479fae84"
	},
	{
		"scenario_id": "pale-sounding-tidewrit-reckoning", "faction_id": "faction_veilmourn",
		"town_id": "town_pale_sounding_harbor", "town_placement_id": "pale_court_home",
		"unit_id": "unit_veilmourn_wakechain_boarders", "specialist_unit_id": "unit_veilmourn_saltwake_eulogists",
		"building_id": "building_veilmourn_mirror_drydock", "encounter_id": "encounter_pale_saltwake_recital",
		"placement_id": "pale_counterstroke_front", "counterstroke_id": "pale_counterstroke",
		"survivor_hook_id": "pale_saltwake_survivors", "join_flag": "pale_saltwake_company_joined",
		"role": "melee", "ability_ids": ["hookline", "fog_screen"],
		"source_sha256": "a816f24a217b3d9eb35f7230b8f2bac76f674d4c0db4d3b08c609914688b9d06",
		"portrait_sha256": "0a7415bf36ab0c891c5edc213fd8c52ff2b9a53583c418bbbc7cd81df2fa85f2",
		"icon_sha256": "163b090bb3e1ab328db87bfba6671daef96042346f414a89866e41dfa676dc66",
		"standee_sha256": "75257099f86332233ce97d713c844817dc45d28f68081dd2885952b7e03a48b6",
		"overworld_sha256": "b864e4fe775700ee94faa965efff36b54bda4005d9781cc28c65b249cbed1417",
		"sheet_sha256": "e3bc7f5ac7e22b39bb0050b5f0cbec5f5d062c9a68011a906bde1bf60c1e32ef"
	}
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	_expect(ContentService.get_content_ids(ContentService.UNITS_PATH).size() == 123, "Reserve batch must expand the live unit catalog to 123.")
	for case_value in CASES:
		await _run_case(case_value)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({
			"ok": true, "company_count": CASES.size(), "live_battle_count": CASES.size(),
			"town_recruit_count": CASES.size(), "survivor_company_count": CASES.size() * 2,
			"exact_art_surface_count": CASES.size() * 6, "save_version": SessionStateStoreScript.SAVE_VERSION,
			"single_consolidated_smoke": true, "rows": _rows
		})])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var unit_id := String(case.get("unit_id", ""))
	var specialist_unit_id := String(case.get("specialist_unit_id", ""))
	var building_id := String(case.get("building_id", ""))
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	_validate_content_and_art(case)

	session.day = 4
	var spawn_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(String(case.get("counterstroke_id", "")) in spawn_result.get("fired_ids", []), "%s did not spawn its day-four company battle." % scenario_id)
	var placement := _row_by_key(session.overworld.get("encounters", []), "placement_id", String(case.get("placement_id", "")))
	_expect(String(placement.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s reserve encounter route changed." % scenario_id)

	var town := _row_by_key(session.overworld.get("towns", []), "placement_id", String(case.get("town_placement_id", "")))
	_expect(String(town.get("town_id", "")) == String(case.get("town_id", "")) and String(town.get("owner", "")) == "player", "%s player town route changed." % scenario_id)
	var town_template := ContentService.get_town(String(case.get("town_id", "")))
	var is_starting_building: bool = building_id in town_template.get("starting_building_ids", [])
	_prepare_town_for_build(session, town, building_id, unit_id, is_starting_building)
	var build_result: Dictionary = {"ok": true, "starting_building": true} if is_starting_building else TownRules.build_active_town(session, building_id)
	var built_town := _row_by_key(session.overworld.get("towns", []), "placement_id", String(case.get("town_placement_id", "")))
	var immediate_recruits := int(built_town.get("available_recruits", {}).get(unit_id, 0))
	var weekly_growth := int(OverworldRules.town_weekly_growth(built_town, session).get(unit_id, 0))
	var before_muster := _army_unit_count(session, unit_id)
	var muster_result: Dictionary = TownRules.recruit_active_town(session, unit_id, 1)
	_expect(bool(build_result.get("ok", false)) and building_id in built_town.get("built_buildings", []), "%s did not build through live TownRules authority: %s" % [building_id, JSON.stringify(build_result)])
	var after_muster := _army_unit_count(session, unit_id)
	_expect(immediate_recruits >= 1 and weekly_growth >= 4 and bool(muster_result.get("ok", false)) and after_muster == before_muster + 1, "%s did not establish growth and muster authority: immediate=%d weekly=%d before=%d after=%d result=%s" % [unit_id, immediate_recruits, weekly_growth, before_muster, after_muster, JSON.stringify(muster_result)])

	var battle := BattleRulesScript.create_battle_payload(session, placement)
	var reserve_stack := _battle_stack(battle.get("stacks", []), unit_id, "enemy")
	_expect(not battle.is_empty() and int(reserve_stack.get("base_count", 0)) == 4, "%s did not construct its exact reserve-company battle stack." % unit_id)
	session.battle = battle
	await _validate_battle_art(session, unit_id)
	var before_reserve_survivors := _army_unit_count(session, unit_id)
	var before_specialist_survivors := _army_unit_count(session, specialist_unit_id)
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	_expect(String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement), "%s company battle did not resolve through live victory authority." % unit_id)
	var recruit_result := ScenarioScriptRulesScript.process_hooks(session)
	var fired_hook_ids: Array = session.overworld.get(ScenarioScriptRulesScript.SCRIPT_STATE_KEY, {}).get("fired_hook_ids", [])
	_expect(String(case.get("survivor_hook_id", "")) in fired_hook_ids and _army_unit_count(session, unit_id) == before_reserve_survivors + 2 and _army_unit_count(session, specialist_unit_id) == before_specialist_survivors + 2 and bool(session.flags.get(String(case.get("join_flag", "")), false)), "%s paired survivors did not join exactly: %s" % [unit_id, JSON.stringify(recruit_result)])
	var authority_after := session.to_dict()
	var repeat_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(not (String(case.get("survivor_hook_id", "")) in repeat_result.get("fired_ids", [])) and session.to_dict() == authority_after, "%s survivor hook repeated or mutated authority twice." % unit_id)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_after)
	_expect(restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority_after, "%s town, army, and hook state did not round-trip through save version %d." % [unit_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id": scenario_id, "unit_id": unit_id, "building_id": building_id, "battle_victory": true, "mustered": 1, "reserve_survivors_joined": 2, "specialist_survivors_joined": 2, "weekly_growth": weekly_growth, "save_exact": true})
	SessionState.set_active_session(null)


func _validate_content_and_art(case: Dictionary) -> void:
	var unit_id := String(case.get("unit_id", ""))
	var building_id := String(case.get("building_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var building := ContentService.get_building(building_id)
	var unit_art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	_expect(String(unit.get("faction_id", "")) == String(case.get("faction_id", "")) and String(unit.get("role", "")) == String(case.get("role", "")) and int(unit.get("tier", 0)) == 3 and String(unit.get("content_status", "")) == "horizon_reserve_company_live", "%s gameplay identity changed." % unit_id)
	_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s ability contract changed." % unit_id)
	_expect(int(building.get("growth_bonus", {}).get(unit_id, 0)) == 1 and int(building.get("recruitment_discount_percent", {}).get(unit_id, 0)) == 4, "%s reserve recruitment contract changed." % building_id)
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


func _prepare_town_for_build(session: SessionStateStoreScript.SessionData, town: Dictionary, building_id: String, unit_id: String, is_starting_building: bool) -> void:
	session.day = 30
	session.overworld["resources"] = {"gold": 100000, "wood": 1000, "ore": 1000, "aetherglass": 1000, "embergrain": 1000, "peatwax": 1000, "verdant_grafts": 1000, "brass_scrip": 1000, "memory_salt": 1000}
	var built_buildings: Array = town.get("built_buildings", []).duplicate(true)
	if not is_starting_building:
		for requirement_value in ContentService.get_building(building_id).get("requires", []):
			_append_building_requirements(built_buildings, String(requirement_value))
		built_buildings.erase(building_id)
	town["built_buildings"] = built_buildings
	town["last_build_day"] = 29
	var available: Dictionary = town.get("available_recruits", {}).duplicate(true)
	if not is_starting_building:
		available.erase(unit_id)
	town["available_recruits"] = available
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_expect(bool(visit_result.get("ok", false)), "%s could not establish its live town visit." % building_id)


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
