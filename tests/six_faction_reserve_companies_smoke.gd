extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_FACTION_RESERVE_COMPANIES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_faction_reserve_companies"
const TOWN_SCENARIO_ID := "horizon-compact-six-citadels"
const CASES := [
	{
		"faction_id":"faction_embercourt", "unit_id":"unit_embercourt_cinderseal_bombardiers", "tier":6, "role":"ranged", "ability_ids":["volley","readiness_writ"],
		"town_id":"town_rainwrit_bastion", "town_placement_id":"horizon_rainwrit_town", "building_id":"building_embercourt_drake_sluice", "building_growth":1, "town_growth":1, "town_discount":3,
		"scenario_id":"pollenglass-lockglass-appeal", "battle_placement_id":"pollenglass_watch_contract", "encounter_id":"encounter_rainwrit_charter_watch", "stack_count":1,
		"hashes":["a9b10cbe0ba037147d2c5a565f0aed7804eb95c8b12264ebd3178083ed58c375","26cbd7e7db1bc9c303a8ca3e54d7857ea5198b82695915cdd57b9299b2532965","6f0313a372b71b1266725b42b1262bb39602820f4c4372b47733e6bdcd2ca51c","e435e38c6922f7d82986ef3c1b30b778cd2e24195f4c693ccc67e3d8ab856320","169bc8e39d5cba0428b2f76958545fc07197e6ff678c2d18dc3e2b68b75c783b","e4777132af57f722e0257da4fa963119aaa2d329da7fa6be05e55e19ba00bcda"]
	},
	{
		"faction_id":"faction_mireclaw", "unit_id":"unit_mireclaw_mireglass_reedcasters", "tier":4, "role":"ranged", "ability_ids":["rot_cant"],
		"town_id":"town_hollowreed_sanctuary", "town_placement_id":"horizon_hollowreed_town", "building_id":"building_mireclaw_chainboom_ferry", "building_growth":3, "town_growth":1, "town_discount":4,
		"scenario_id":"glassmarshal-fenbell-refraction", "battle_placement_id":"glassmarshal_watch_contract", "encounter_id":"encounter_nightglass_drowned_watch", "stack_count":2,
		"hashes":["15ae4a8a0d45752a075ad449bafa265ec2cf7bcb86aa7dd9dd8dc8afed0801dc","526d8d6fa4bb4d8a9d3cd5de3a72f248af37e5ae12c11f8d1bf3317d3db5062f","46d8debf07f28659e4103a949518ad245300adbead5d11d20e9cfbf9ea125c8f","7efdd21aad3f899d16178b309ae4e23798d4ac2549024e759a817636e1c5217b","97ce61698ec0030e4239b343cf133041b05570a2819263cd3e7e2bcea5373a20","a2c12fa5782147ff19577ac8ba0a69684d9a858395f287bf5d2ef6c08a2feff9"]
	},
	{
		"faction_id":"faction_sunvault", "unit_id":"unit_sunvault_noonfacet_sentinels", "tier":4, "role":"melee", "ability_ids":["brace","shielding"],
		"town_id":"town_meridian_choirhold", "town_placement_id":"horizon_meridian_town", "building_id":"building_sunvault_harmonic_cloister", "building_growth":3, "town_growth":1, "town_discount":4,
		"scenario_id":"thorncart-daybreak-tangle", "battle_placement_id":"thorncart_watch_contract", "encounter_id":"encounter_halo_spire_noon_watch", "stack_count":2,
		"hashes":["ffe6710668b1ecaea7aa352a68f334c7fc8246ff615cd9c00bc0565e419729af","e5f915b077d8c1b5f3bf0ea90caecc4bf0692235b8d75a825744d9fb7376e1f3","5c7c34f03ee355b8314fb7082e8e3a3dd20d7d016ccbff95f3bb82434b2b2f51","fa4b2668801bda0ac278bf3159bf1ff3314562483dbf7d1318cf091fa731f94a","3a4f3604ae593b6787e709dccbe4121049a05fc4d393fd15844dc39519e87639","627ec86a4bad7ec65b5596835641d13d1d806f0b5a33e961506a7e9884aa21dd"]
	},
	{
		"faction_id":"faction_thornwake", "unit_id":"unit_thornwake_dawnseed_bolters", "tier":4, "role":"ranged", "ability_ids":["harry","volley"],
		"town_id":"town_crownroot_refuge", "town_placement_id":"horizon_crownroot_town", "building_id":"building_thornwake_barkmantle_run", "building_growth":3, "town_growth":1, "town_discount":4,
		"scenario_id":"chainboom-graftwake-cordon", "battle_placement_id":"chainboom_watch_contract", "encounter_id":"encounter_briarwheel_witness_watch", "stack_count":2,
		"hashes":["3f7819e1b7080056d1f9959b6685513b7bf92a8c8c17b992a611ddaaa10bf633","24eedb50c348cb34095bc38b5510814fb03c75e07d4d256b8c7b6705ae00882e","a841282fa2f7942cfc1bfad0823f4b87eabe8659b9f668905a166d61e6a8e35e","b410124e9f8bce15ae817fe352c48c859a37d9b42ba9aa433df68e6e0b0895fe","03cf7d1ff41d4599ae805dcd7b418c3cbfeb188e32110caab38ba578d74e4040","6c8aa04e5b53041205bccfafde3207754158eaf319a5a8170eb07e414dc955f0"]
	},
	{
		"faction_id":"faction_brasshollow", "unit_id":"unit_brasshollow_gaugeplate_bailiffs", "tier":4, "role":"melee", "ability_ids":["brace","shielding"],
		"town_id":"town_blackbell_foundry", "town_placement_id":"horizon_blackbell_town", "building_id":"building_brasshollow_boiler_cathedral", "building_growth":3, "town_growth":1, "town_discount":4,
		"scenario_id":"reedscript-redline-reckoning", "battle_placement_id":"reedscript_watch_contract", "encounter_id":"encounter_blackbell_quench_watch", "stack_count":2,
		"hashes":["62f316cdeb069354e60df4e2380aa7711ce5f5ea9cfbd995489a3dc7788d67d1","1d6bca3b4bf9d51be304464e2b9fd2390d2aa0a16bbf897216a872b7832961df","344b97d803cd651db5a7d06537b5c484ad04f47d5d9511905cc95a582d829827","f399de199db193b0291caf06896cf46b5768f4e7e75cd0ed6379246bf3c8c061","20202a3be2c7af8c0ba169d6f4334811b4f495cd72b89a5c7f5a079c307477e4","b8fa6d4e50012d5eb6327ab2f8b35b4d021eeec33debd1c3690a877926e405c6"]
	},
	{
		"faction_id":"faction_veilmourn", "unit_id":"unit_veilmourn_tidehook_deckhands", "tier":2, "role":"melee", "ability_ids":["hookline","fog_screen"],
		"town_id":"town_pale_sounding_harbor", "town_placement_id":"horizon_pale_town", "building_id":"building_veilmourn_ransom_exchange", "building_growth":5, "town_growth":2, "town_discount":4,
		"scenario_id":"facetlane-last-sounding", "battle_placement_id":"facetlane_watch_contract", "encounter_id":"encounter_pale_sounding_memory_watch", "stack_count":4,
		"hashes":["e48a0ec6607f7c20d9cf2b8e6803d78df2e6c8afd9bd4245f65b14e7c7ccffba","9a6b425e674817c47f86cd2da52933cb0e36d33a7c38038051df70ce4e4376e4","70d8ba53b5d6c710cc74e6f8f02f897d9be273df1b41d9c7a06741e7e33c7ee6","c589b8089486289262ed31d0fc91e8d28145daa18d6af58b68d5dc8fa5435f90","d9dec3b7e5522b591129e4c48c8373afd7dd7e91025526c197991b8b7ea8dcd7","ed6c23ee3f816d9549b3fdef3483bc7ad964bb1985f096af8b3e2212c183f56d"]
	}
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	_expect(ContentService.get_content_ids(ContentService.UNITS_PATH).size() == 154, "Reserve-company batch must remain present in the expanded 154-unit catalog.")
	for faction_id in ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake", "faction_brasshollow", "faction_veilmourn"]:
		_expect(_faction_unit_count(faction_id) == 13, "%s must expose exactly thirteen live units." % faction_id)
	for case_value in CASES:
		await _run_case(case_value)
	_write_standee_contact_sheet()
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"company_count":6,"thirteen_unit_faction_count":6,"town_recruit_count":6,"live_watch_battle_count":6,"exact_art_surface_count":36,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true,"rows":_rows})])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(case: Dictionary) -> void:
	_validate_content_and_art(case)
	var town_session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(TOWN_SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(town_session != null, "%s did not create the live six-town session." % String(case.get("unit_id", "")))
	if town_session == null:
		return
	OverworldRules.normalize_overworld_state(town_session)
	var town_result := _exercise_town_recruitment(town_session, case)

	var scenario_id := String(case.get("scenario_id", ""))
	var unit_id := String(case.get("unit_id", ""))
	var battle_session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(battle_session != null, "%s did not create its live relay-road session." % scenario_id)
	if battle_session == null:
		return
	OverworldRules.normalize_overworld_state(battle_session)
	var placement := _row_by_key(battle_session.overworld.get("encounters", []), "placement_id", String(case.get("battle_placement_id", "")))
	_expect(String(placement.get("encounter_id", "")) == String(case.get("encounter_id", "")), "%s watch encounter route changed." % unit_id)
	var battle := BattleRulesScript.create_battle_payload(battle_session, placement)
	var company_stack := _battle_stack(battle.get("stacks", []), unit_id, "enemy")
	_expect(int(company_stack.get("base_count", 0)) == int(case.get("stack_count", 0)), "%s did not deploy its exact relay-watch stack." % unit_id)
	battle_session.battle = battle
	await _validate_battle_art(battle_session, unit_id)
	for stack_value in battle_session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution := BattleRulesScript.resolve_if_battle_ready(battle_session)
	_expect(String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(battle_session, placement), "%s watch battle did not resolve through live victory authority." % unit_id)
	var authority_after := battle_session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_after)
	var save_exact := restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority_after
	_expect(save_exact, "%s did not round-trip through save version %d." % [unit_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"unit_id":unit_id,"weekly_growth":int(town_result.get("weekly_growth",0)),"mustered":bool(town_result.get("mustered",false)),"watch_stack":int(company_stack.get("base_count",0)),"battle_victory":String(resolution.get("state","")) == "victory","save_exact":save_exact})
	SessionState.set_active_session(null)


func _exercise_town_recruitment(session: SessionStateStoreScript.SessionData, case: Dictionary) -> Dictionary:
	var unit_id := String(case.get("unit_id", ""))
	var placement_id := String(case.get("town_placement_id", ""))
	var building_id := String(case.get("building_id", ""))
	var town := _row_by_key(session.overworld.get("towns", []), "placement_id", placement_id)
	_expect(String(town.get("town_id", "")) == String(case.get("town_id", "")), "%s exact town placement changed." % unit_id)
	if String(town.get("owner", "")) != "player":
		_expect(OverworldRules.capture_town_by_placement(session, placement_id) != "", "%s town could not transfer through live capture authority." % unit_id)
	town = _row_by_key(session.overworld.get("towns", []), "placement_id", placement_id)
	_prepare_town_for_build(session, town, building_id)
	var is_existing: bool = building_id in town.get("built_buildings", [])
	var build_result: Dictionary = {"ok":true,"existing":true} if is_existing else TownRules.build_active_town(session, building_id)
	var built_town := _row_by_key(session.overworld.get("towns", []), "placement_id", placement_id)
	var weekly_growth := int(OverworldRules.town_weekly_growth(built_town, session).get(unit_id, 0))
	var before_muster := _army_unit_count(session, unit_id)
	var muster_result := TownRules.recruit_active_town(session, unit_id, 1)
	var mustered := bool(muster_result.get("ok", false)) and _army_unit_count(session, unit_id) == before_muster + 1
	_expect(bool(build_result.get("ok", false)) and building_id in built_town.get("built_buildings", []), "%s did not establish live dwelling authority: %s" % [building_id, JSON.stringify(build_result)])
	_expect(weekly_growth >= 1 and mustered, "%s did not expose bounded effective growth and live muster authority: weekly=%d result=%s" % [unit_id, weekly_growth, JSON.stringify(muster_result)])
	return {"weekly_growth":weekly_growth,"mustered":mustered}


func _validate_content_and_art(case: Dictionary) -> void:
	var unit_id := String(case.get("unit_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var building := ContentService.get_building(String(case.get("building_id", "")))
	var town := ContentService.get_town(String(case.get("town_id", "")))
	_expect(String(unit.get("faction_id", "")) == String(case.get("faction_id", "")) and String(unit.get("role", "")) == String(case.get("role", "")) and int(unit.get("tier", 0)) == int(case.get("tier", 0)) and String(unit.get("content_status", "")) == "six_faction_reserve_company_live", "%s gameplay identity changed." % unit_id)
	_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s ability contract changed." % unit_id)
	_expect(int(building.get("growth_bonus", {}).get(unit_id, 0)) == int(case.get("building_growth", 0)) and int(building.get("recruitment_discount_percent", {}).get(unit_id, 0)) == 4, "%s building recruitment contract changed." % unit_id)
	_expect(int(town.get("recruitment", {}).get("growth_bonus", {}).get(unit_id, 0)) == int(case.get("town_growth", 0)) and int(town.get("recruitment", {}).get("cost_discount_percent", {}).get(unit_id, 0)) == int(case.get("town_discount", 0)), "%s town recruitment contract changed." % unit_id)
	var paths := ["res://art/units/source/curated/%s.png" % unit_id,"res://art/units/portraits/%s.png" % unit_id,"res://art/units/battle_icons/%s.png" % unit_id,"res://art/units/battle_standees/%s.png" % unit_id,"res://art/units/overworld_icons/%s.png" % unit_id,"res://art/animation/runtime/units/%s.png" % unit_id]
	var sizes := [Vector2i(512,512),Vector2i(384,512),Vector2i(160,160),Vector2i(192,224),Vector2i(96,96),Vector2i(256,896)]
	var hashes: Array = case.get("hashes", [])
	for index in range(paths.size()):
		var image := Image.load_from_file(ProjectSettings.globalize_path(paths[index]))
		_expect(not image.is_empty() and image.get_size() == sizes[index] and FileAccess.get_sha256(paths[index]) == String(hashes[index]), "%s exact art surface changed at %s." % [unit_id, paths[index]])
	var unit_art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	_expect(String(unit_art.get("curated_source_sha256", "")) == String(hashes[0]) and String(animation.get("curated_source_sha256", "")) == String(hashes[0]), "%s curated provenance changed." % unit_id)


func _prepare_town_for_build(session: SessionStateStoreScript.SessionData, town: Dictionary, building_id: String) -> void:
	session.day = 30
	session.overworld["resources"] = {"gold":100000,"wood":1000,"ore":1000,"aetherglass":1000,"embergrain":1000,"peatwax":1000,"verdant_grafts":1000,"brass_scrip":1000,"memory_salt":1000}
	var built_buildings: Array = town.get("built_buildings", []).duplicate(true)
	if building_id not in built_buildings:
		for requirement_value in ContentService.get_building(building_id).get("requires", []):
			_append_building_requirements(built_buildings, String(requirement_value))
		built_buildings.erase(building_id)
	town["built_buildings"] = built_buildings
	town["last_build_day"] = 29
	_move_active_hero_to_town(session, town)
	var visit_result := OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
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


func _write_standee_contact_sheet() -> void:
	var contact := Image.create(576, 448, false, Image.FORMAT_RGBA8)
	contact.fill(Color("141820"))
	for index in range(CASES.size()):
		var unit_id := String(CASES[index].get("unit_id", ""))
		var standee := Image.load_from_file(ProjectSettings.globalize_path("res://art/units/battle_standees/%s.png" % unit_id))
		if not standee.is_empty():
			contact.blend_rect(standee, Rect2i(Vector2i.ZERO, standee.get_size()), Vector2i((index % 3) * 192, (index / 3) * 224))
	_expect(contact.save_png("%s/runtime_standee_contact_sheet.png" % OUTPUT_DIR) == OK, "Could not write the six-company runtime contact sheet.")


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
	var position := {"x":int(town.get("x",0)),"y":int(town.get("y",0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = position.x
	hero["y"] = position.y
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
