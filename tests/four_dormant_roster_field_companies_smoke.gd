extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FOUR_DORMANT_ROSTER_FIELD_COMPANIES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/four_dormant_roster_field_companies_smoke"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/dormant_roster_field_companies/dormant_roster_field_companies_atlas.png"
const ATLAS_SHA256 := "1427677a89e0a49cdbd1feb2fcd2778c52e1e233b34c3628885227a7a38dd683"

const CASES := [
	{"scenario_id":"horizon-compact-six-citadels","placement_id":"horizon_lockglass_citation_field","encounter_id":"encounter_lockglass_citation_field","army_id":"army_lockglass_citation_field","unit_id":"unit_embercourt_lockglass_writcasters","faction_id":"faction_embercourt","unit_count":2,"objective_id":"lockglass_citation_bench","objective_type":"cover_line","reward_id":"embergrain","gold":340,"victory_flag":"lockglass_citation_field_cleared","asset_id":"encounter_dormant_roster_lockglass_citation_field","atlas_x":0,"source_name":"lockglass_citation_field_source.png","source_sha256":"27a8df3f93eb5c0e78fd1e98bd0bbddd08f51c7800a570db9e34ce21a0691504"},
	{"scenario_id":"crownroot-quenchline-verdict","placement_id":"crownroot_pollenhook_whistle_line","encounter_id":"encounter_pollenhook_whistle_line","army_id":"army_pollenhook_whistle_line","unit_id":"unit_thornwake_pollenhook_whistlers","faction_id":"faction_thornwake","unit_count":12,"objective_id":"pollenhook_snare_wind","objective_type":"hazard_zone","reward_id":"verdant_grafts","gold":260,"victory_flag":"pollenhook_whistle_line_cleared","asset_id":"encounter_dormant_roster_pollenhook_whistle_line","atlas_x":48,"source_name":"pollenhook_whistle_line_source.png","source_sha256":"e296268dcd3fa95eadfbe716ade31f1cb5e601c6dfe9ec28fc90d1c0349c8acd"},
	{"scenario_id":"blackbell-saltwake-foreclosure","placement_id":"blackbell_tallyspring_proving_rack","encounter_id":"encounter_tallyspring_proving_rack","army_id":"army_tallyspring_proving_rack","unit_id":"unit_brasshollow_tallyspring_throwers","faction_id":"faction_brasshollow","unit_count":12,"objective_id":"tallyspring_ricochet_rack","objective_type":"lane_battery","reward_id":"brass_scrip","gold":280,"victory_flag":"tallyspring_proving_rack_cleared","asset_id":"encounter_dormant_roster_tallyspring_proving_rack","atlas_x":96,"source_name":"tallyspring_proving_rack_source.png","source_sha256":"2d4929bea7382d8bf84ccad51a27204e38b75c06b73f9d30e8adc9c854225ddf"},
	{"scenario_id":"pale-sounding-tidewrit-reckoning","placement_id":"pale_gloamkeel_sounding_barricade","encounter_id":"encounter_gloamkeel_sounding_barricade","army_id":"army_gloamkeel_sounding_barricade","unit_id":"unit_veilmourn_gloamkeel_bulwarks","faction_id":"faction_veilmourn","unit_count":2,"objective_id":"gloamkeel_sounding_line","objective_type":"obstruction_line","reward_id":"memory_salt","gold":350,"victory_flag":"gloamkeel_sounding_barricade_cleared","asset_id":"encounter_dormant_roster_gloamkeel_sounding_barricade","atlas_x":144,"source_name":"gloamkeel_sounding_barricade_source.png","source_sha256":"9ff17e975bfbf820da707fa53a20e01f9bcbccd46a129388f7ef751d29d19dab"},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	_validate_atlas_and_catalog()
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		print("%s CASE_START %s" % [REPORT_ID, case_value.get("scenario_id", "")])
		await _validate_case(view, case_value)
		print("%s CASE_DONE %s" % [REPORT_ID, case_value.get("scenario_id", "")])
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"new_army_group_count": CASES.size(),
		"new_encounter_count": CASES.size(),
		"formerly_dormant_unit_count": CASES.size(),
		"atlas_path": ATLAS_PATH,
		"atlas_size": [192, 48],
		"atlas_sha256": ATLAS_SHA256,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_atlas_and_catalog() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not image.is_empty() and image.get_size() == Vector2i(192, 48), "The compact field-company atlas must remain 192x48.")
	_expect(FileAccess.get_sha256(ATLAS_PATH) == ATLAS_SHA256 and image.detect_alpha() != Image.ALPHA_NONE, "The compact field-company atlas lost its exact transparent runtime bytes.")
	var used_units := {}
	for army_id in ContentService.get_content_ids(ContentService.ARMY_GROUPS_PATH):
		for stack_value in ContentService.get_army_group(army_id).get("stacks", []):
			if stack_value is Dictionary:
				used_units[String(stack_value.get("unit_id", ""))] = true
	for case_value in CASES:
		_expect(used_units.has(String(case_value.get("unit_id", ""))), "%s remains absent from the live army catalog." % case_value.get("unit_id", ""))
	_expect(view_invalid_asset_control() == null, "Unknown encounter art must fail closed instead of resolving a fabricated texture.")


func view_invalid_asset_control() -> Variant:
	var probe = MapViewScript.new()
	var result = probe.call("_object_texture_for_asset", "encounter_not_authored_field_company")
	probe.free()
	return result


func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var encounter_id := String(case.get("encounter_id", ""))
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % scenario_id)
	if session == null:
		return
	var placement := _encounter(session, placement_id)
	_expect(String(placement.get("encounter_id", "")) == encounter_id and bool(placement.get("prefer_identity_landmark", false)), "%s lost its exact live scenario placement." % encounter_id)
	_validate_unique_placements(session, scenario_id)

	var encounter := ContentService.get_encounter(encounter_id)
	var army := ContentService.get_army_group(String(case.get("army_id", "")))
	var unit := ContentService.get_unit(String(case.get("unit_id", "")))
	var objective := _objective(encounter.get("field_objectives", []), String(case.get("objective_id", "")))
	_expect(String(encounter.get("enemy_group_id", "")) == String(case.get("army_id", "")) and String(army.get("faction_id", "")) == String(case.get("faction_id", "")), "%s lost faction-correct army ownership." % encounter_id)
	_expect(String(unit.get("faction_id", "")) == String(case.get("faction_id", "")) and not unit.get("abilities", []).is_empty(), "%s lost its authored faction or battle ability." % case.get("unit_id", ""))
	_expect(String(objective.get("type", "")) == String(case.get("objective_type", "")) and encounter.get("rewards", {}).has(String(case.get("reward_id", ""))) and String(case.get("victory_flag", "")) in encounter.get("victory_flags", []), "%s lost its field objective, rare reward, or victory flag." % encounter_id)

	var source_path := "res://art/overworld/source/generated/encounters/dormant_roster_field_companies/%s" % String(case.get("source_name", ""))
	_expect(FileAccess.get_sha256(source_path) == String(case.get("source_sha256", "")), "%s source provenance changed." % encounter_id)
	_set_active_hero_position(session, Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0))))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0))))
	await get_tree().process_frame
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", placement)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(presentation.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and String(presentation.get("identity_encounter_path", "")) == ATLAS_PATH and bool(presentation.get("uses_identity_encounter_sprite", false)) and texture is AtlasTexture and texture.region == Rect2(float(case.get("atlas_x", 0)), 0.0, 48.0, 48.0) and texture.atlas.get_size() == Vector2(192, 48)
	_expect(exact_art, "%s did not resolve its exact live atlas region: %s" % [encounter_id, JSON.stringify(presentation)])
	var capture_path := await _capture_if_requested(scenario_id)

	var resources_before := _resource_snapshot(session)
	var battle := BattleRulesScript.create_battle_payload(session, placement)
	_expect(not battle.is_empty(), "%s did not construct a live battle payload." % encounter_id)
	if battle.is_empty():
		return
	var dormant_stack := _battle_stack(battle.get("stacks", []), String(case.get("unit_id", "")), "enemy")
	_expect(int(dormant_stack.get("base_count", 0)) == int(case.get("unit_count", -1)), "%s did not enter battle at its authored stack count." % case.get("unit_id", ""))
	session.battle = battle
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	_expect(String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement), "%s did not resolve through live Battle authority." % encounter_id)
	var resources_after := _resource_snapshot(session)
	var rare_id := String(case.get("reward_id", ""))
	var gold_delta := int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0))
	var rare_delta := int(resources_after.get(rare_id, 0)) - int(resources_before.get(rare_id, 0))
	_expect(gold_delta == int(case.get("gold", -1)) and rare_delta == 1 and bool(session.flags.get(String(case.get("victory_flag", "")), false)), "%s reward or victory authority changed." % encounter_id)
	var authority := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority)
	_expect(restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority, "%s did not round-trip exactly through save version %d." % [encounter_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"encounter_id":encounter_id,"unit_id":String(case.get("unit_id", "")),"battle_victory":true,"gold_delta":gold_delta,"rare_resource_delta":rare_delta,"exact_art":exact_art,"capture_path":capture_path,"save_round_trip_exact":true})
	SessionState.set_active_session(null)


func _battle_stack(stacks: Variant, unit_id: String, side: String) -> Dictionary:
	for value in stacks if stacks is Array else []:
		if value is Dictionary and String(value.get("unit_id", "")) == unit_id and String(value.get("side", "")) == side:
			return value
	return {}


func _objective(objectives: Variant, objective_id: String) -> Dictionary:
	for value in objectives if objectives is Array else []:
		if value is Dictionary and String(value.get("id", "")) == objective_id:
			return value
	return {}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _resource_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return (session.overworld.get("resources", {}) as Dictionary).duplicate(true)


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes


func _validate_unique_placements(session: SessionStateStoreScript.SessionData, scenario_id: String) -> void:
	var occupied := {}
	for bucket in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for value in session.overworld.get(bucket, []):
			if not (value is Dictionary):
				continue
			var key := "%d,%d" % [int(value.get("x", -1)), int(value.get("y", -1))]
			_expect(not occupied.has(key), "%s placement collision at %s between %s and %s." % [scenario_id, key, occupied.get(key, ""), value.get("placement_id", "")])
			occupied[key] = String(value.get("placement_id", ""))


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("DORMANT_ROSTER_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_error("Could not save visual capture %s." % path)
		return ""
	return path


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Unable to write report %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
