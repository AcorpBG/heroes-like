extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "TWIN_HOLD_DEFENSE_VIGILS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/twin_hold_defense_vigils_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/twin_hold_defense_vigils/twin_hold_defense_vigils_atlas.png"
const CASES := [
	{"scenario_id":"powderwrit-two-lock-vigil","hero_id":"hero_embercourt_maela_powderwrit","faction_id":"faction_embercourt","army_id":"army_maela_powderwrit_commission","prefix":"powdervigil","muster_site_id":"site_stormseal_powder_wharf","encounter_id":"encounter_gloamchain_sluice_ram","enemy_group_id":"army_gloamchain_sluice_ram","asset_id":"encounter_defense_gloamchain_sluice_ram","region":Rect2(0,0,48,48)},
	{"scenario_id":"reedcaller-moonwax-stand","hero_id":"hero_mireclaw_rhask_reedcaller","faction_id":"faction_mireclaw","army_id":"army_rhask_reedcaller_commission","prefix":"reedvigil","muster_site_id":"site_moonwax_reed_circle","encounter_id":"encounter_red_ledger_pile_driver","enemy_group_id":"army_red_ledger_pile_driver","asset_id":"encounter_defense_red_ledger_pile_driver","region":Rect2(48,0,48,48)},
	{"scenario_id":"sevenfold-meridian-vigil","hero_id":"hero_sunvault_aven_sevenfold","faction_id":"faction_sunvault","army_id":"army_aven_sevenfold_commission","prefix":"facetvigil","muster_site_id":"site_facet_vigil","encounter_id":"encounter_rootshade_facet_breaker","enemy_group_id":"army_rootshade_facet_breaker","asset_id":"encounter_defense_rootshade_facet_breaker","region":Rect2(96,0,48,48)},
	{"scenario_id":"boltroot-twin-grove-stand","hero_id":"hero_thornwake_bryn_boltroot","faction_id":"faction_thornwake","army_id":"army_bryn_boltroot_commission","prefix":"rootvigil","muster_site_id":"site_heartseed_bolt_grove","encounter_id":"encounter_ashwrit_sapfire_tower","enemy_group_id":"army_ashwrit_sapfire_tower","asset_id":"encounter_defense_ashwrit_sapfire_tower","region":Rect2(144,0,48,48)},
	{"scenario_id":"blackgauge-double-assay","hero_id":"hero_brasshollow_kestra_blackgauge","faction_id":"faction_brasshollow","army_id":"army_kestra_blackgauge_commission","prefix":"gaugevigil","muster_site_id":"site_blackbell_assay_watch","encounter_id":"encounter_zenith_wire_crucible","enemy_group_id":"army_zenith_wire_crucible","asset_id":"encounter_defense_zenith_wire_crucible","region":Rect2(192,0,48,48)},
	{"scenario_id":"tidehook-last-mooring-vigil","hero_id":"hero_veilmourn_olan_tidehook","faction_id":"faction_veilmourn","army_id":"army_olan_tidehook_commission","prefix":"tidevigil","muster_site_id":"site_last_memory_mooring","encounter_id":"encounter_fenwake_bell_dredger","enemy_group_id":"army_fenwake_bell_dredger","asset_id":"encounter_defense_fenwake_bell_dredger","region":Rect2(240,0,48,48)}
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	var atlas := load(ATLAS_PATH) as Texture2D
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "The twin-hold landmark atlas must remain exactly 288x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"direct_lead_count": _rows.filter(func(row): return bool(row.get("direct_lead", false))).size(),
		"twin_hold_count": _rows.filter(func(row): return bool(row.get("twin_holds", false))).size(),
		"pressure_chain_count": _rows.filter(func(row): return bool(row.get("pressure_chain", false))).size(),
		"battle_victory_count": _rows.reduce(func(total, row): return total + int(row.get("battle_victories", 0)), 0),
		"exact_encounter_art_count": _rows.filter(func(row): return bool(row.get("exact_art", false))).size(),
		"day_twelve_victory_count": _rows.filter(func(row): return bool(row.get("day_twelve_victory", false))).size(),
		"lost_hold_defeat_count": _rows.filter(func(row): return bool(row.get("lost_hold_defeat", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"battle_victory_count":18,"day_twelve_victory_count":6,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var campaign_chapter := scenario_id == "blackgauge-double-assay"
	var direct_lead := bool(availability.get("campaign", not campaign_chapter)) == campaign_chapter and bool(availability.get("skirmish", false)) and String(session.hero_id) == String(case.get("hero_id", "")) and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(scenario.get("player_army_id", "")) == String(case.get("army_id", ""))
	_expect(direct_lead, "%s did not launch its exact captain, faction, and four-stack company." % scenario_id)
	var map_size: Dictionary = scenario.get("map_size", {})
	var towns: Array = session.overworld.get("towns", [])
	var twin_holds := towns.size() == 2 and towns.all(func(town): return town is Dictionary and String(town.get("owner", "")) == "player")
	_expect(int(map_size.get("width", 0)) == 13 and int(map_size.get("height", 0)) == 8 and twin_holds and scenario.get("resource_nodes", []).size() == 8 and scenario.get("artifact_nodes", []).size() == 1 and scenario.get("encounters", []).size() == 3 and scenario.get("script_hooks", []).size() == (7 if campaign_chapter else 6), "%s lost its 13x8 twin-hold composition." % scenario_id)
	var day_victories: Array = scenario.get("objectives", {}).get("victory", []).filter(func(row): return row is Dictionary and String(row.get("type", "")) == "day_at_least" and int(row.get("day", 0)) == 12)
	_expect(day_victories.size() == 1 and scenario.get("objectives", {}).get("victory", []).size() == 6 and scenario.get("objectives", {}).get("defeat", []).size() == 5, "%s lost its Day-12 hold objective contract." % scenario_id)

	var muster_result := _resource_node_result(session, "%s_muster" % prefix)
	var muster_node: Dictionary = muster_result.get("node", {})
	_expect(String(muster_node.get("site_id", "")) == String(case.get("muster_site_id", "")), "%s is missing its own live field muster." % scenario_id)
	_set_active_hero_position(session, Vector2i(int(muster_node.get("x", 0)), int(muster_node.get("y", 0))))
	var muster_claim: Dictionary = OverworldRules._collect_resource_node_result(session, muster_result, true)
	_expect(bool(muster_claim.get("ok", false)), "%s field muster could not reinforce the live reserve company: %s" % [scenario_id, JSON.stringify(muster_claim)])

	var hook_probe := _clone_session(session)
	hook_probe.day = 4
	ScenarioScriptRulesScript.process_hooks(hook_probe)
	hook_probe.day = 7
	ScenarioScriptRulesScript.process_hooks(hook_probe)
	hook_probe.day = 10
	ScenarioScriptRulesScript.process_hooks(hook_probe)
	var probe_ids: Array = hook_probe.overworld.get("encounters", []).map(func(row): return String(row.get("placement_id", "")) if row is Dictionary else "")
	var fired_hook_ids: Array = hook_probe.overworld.get(ScenarioScriptRulesScript.SCRIPT_STATE_KEY, {}).get("fired_hook_ids", [])
	var pressure_chain := "%s_day_four_pressure" % prefix in fired_hook_ids and "%s_day_seven_counterstroke" % prefix in fired_hook_ids and "%s_day_ten_final_surge" % prefix in fired_hook_ids and "%s_counterstroke" % prefix in probe_ids and "%s_final_surge" % prefix in probe_ids
	_expect(pressure_chain, "%s did not fire its Day-7 counterstroke and Day-10 final surge through production hook authority." % scenario_id)

	var primary := _encounter(session, "%s_primary_front" % prefix)
	var encounter_id := String(case.get("encounter_id", ""))
	var encounter_definition := ContentService.get_encounter(encounter_id)
	_expect(String(primary.get("encounter_id", "")) == encounter_id and String(encounter_definition.get("enemy_group_id", "")) == String(case.get("enemy_group_id", "")) and encounter_definition.get("field_objectives", []).size() == 1, "%s lost its exact siege encounter, army, or field objective." % scenario_id)
	var tile := Vector2i(int(primary.get("x", -1)), int(primary.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", primary)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(presentation.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and bool(presentation.get("uses_identity_encounter_sprite", false)) and texture is AtlasTexture and texture.region == case.get("region", Rect2()) and texture.atlas is Texture2D and texture.atlas.resource_path == ATLAS_PATH and texture.atlas.get_size() == Vector2(288, 48)
	_expect(exact_art, "%s exact generated landmark did not reach the live map renderer." % encounter_id)
	var capture_path := await _capture_if_requested(scenario_id)

	var battle_victories := 0
	for placement_suffix in ["primary_front", "north_front", "south_front"]:
		var placement_id := "%s_%s" % [prefix, placement_suffix]
		var battle_session := _clone_session(session)
		if _resolve_front(battle_session, placement_id):
			battle_victories += 1
			var resolved: Array = session.overworld.get("resolved_encounters", [])
			if placement_id not in resolved:
				resolved.append(placement_id)
			session.overworld["resolved_encounters"] = resolved
	_expect(battle_victories == 3, "%s did not win all three authored production battles; victories=%d." % [scenario_id, battle_victories])
	if battle_victories != 3:
		return

	# The hook probe above exercises the intervening Day-4/7/10 escalation states.
	# Start the outcome-boundary check at Day 11 so this one six-case smoke does not
	# redundantly execute sixty strategic-AI turns already owned by AI endurance gates.
	session.day = 11
	var day_eleven: Dictionary = ScenarioRulesScript.evaluate_session(session)
	_expect(int(session.day) == 11 and String(day_eleven.get("status", "")) == "in_progress", "%s must remain in progress after all fronts fall but before Day 12: %s" % [scenario_id, JSON.stringify(day_eleven)])

	var lost_hold := _clone_session(session)
	_set_town_owner(lost_hold, "%s_second_hold" % prefix, "enemy")
	var lost_turn: Dictionary = OverworldRules.end_turn(lost_hold)
	var lost_result: Dictionary = ScenarioRulesScript.evaluate_session(lost_hold)
	var lost_hold_defeat := bool(lost_turn.get("ok", false)) and int(lost_hold.day) == 12 and String(lost_result.get("status", "")) == "defeat"
	_expect(lost_hold_defeat, "%s did not lose when its second hold fell at the Day-12 threshold: %s" % [scenario_id, JSON.stringify(lost_result)])

	var day_twelve_turn: Dictionary = OverworldRules.end_turn(session)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var day_twelve_victory := bool(day_twelve_turn.get("ok", false)) and int(session.day) == 12 and String(victory_result.get("status", "")) == "victory" and _met_victory_objective_count(session, scenario_id) == 6
	_expect(day_twelve_victory, "%s did not win through production Day-12 progression with both holds intact: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"direct_lead":direct_lead,"twin_holds":twin_holds,"pressure_chain":pressure_chain,"battle_victories":battle_victories,"exact_art":exact_art,"day_twelve_victory":day_twelve_victory,"lost_hold_defeat":lost_hold_defeat,"capture_path":capture_path,"save_round_trip_exact":save_exact})


func _resolve_front(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		_error("Missing encounter placement %s." % placement_id)
		return false
	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		_error("Could not construct production battle for %s." % placement_id)
		return false
	session.battle = payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	var won: bool = bool(result.get("completed", false)) and String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])
	if not won:
		print("%s FRONT_FAILED %s %s" % [REPORT_ID, placement_id, JSON.stringify(result)])
	return won


func _resource_node_result(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {"index":-1,"node":{}}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _set_town_owner(session: SessionStateStoreScript.SessionData, placement_id: String, owner: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			var town: Dictionary = towns[index]
			town["owner"] = owner
			towns[index] = town
	session.overworld["towns"] = towns


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero: Dictionary = session.overworld.get("hero", {})
	active_hero["position"] = position.duplicate(true)
	session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes


func _met_victory_objective_count(session: SessionStateStoreScript.SessionData, scenario_id: String) -> int:
	var met := 0
	for value in ContentService.get_scenario(scenario_id).get("objectives", {}).get("victory", []):
		if value is Dictionary and ScenarioRulesScript.is_objective_met(session, String(value.get("id", "")), "victory"):
			met += 1
	return met


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var result := SessionStateStoreScript.SessionData.new()
	result.from_dict(source.to_dict())
	return result


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("TWIN_HOLD_DEFENSE_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png(path) == OK, "%s capture failed." % stem)
	return path


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
