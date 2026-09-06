extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FIELD_MUSTER_COMMISSION_SKIRMISHES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/field_muster_commission_skirmishes_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/field_muster_commissions/field_muster_commissions_atlas.png"
const CASES := [
	{"scenario_id":"powderwrit-fogchain-commission","hero_id":"hero_embercourt_maela_powderwrit","faction_id":"faction_embercourt","army_id":"army_maela_powderwrit_commission","reserve_unit_id":"unit_embercourt_cinderseal_bombardiers","muster_id":"powderwrit_muster","muster_site_id":"site_stormseal_powder_wharf","claim_count":1,"placement_id":"powderwrit_commission","encounter_id":"encounter_powderwrit_fogchain_commission","enemy_group_id":"army_pale_sounding_memory_watch","enemy_town_id":"powderwrit_enemy_town","record_flag":"powderwrit_commission_recorded","victory_flag":"powderwrit_fogchain_commission_fulfilled","objective_id":"fogchain_powder_gate","asset_id":"encounter_commission_powderwrit_fogchain_gate","region":Rect2(0,0,48,48)},
	{"scenario_id":"reedcaller-redgauge-commission","hero_id":"hero_mireclaw_rhask_reedcaller","faction_id":"faction_mireclaw","army_id":"army_rhask_reedcaller_commission","reserve_unit_id":"unit_mireclaw_mireglass_reedcasters","muster_id":"reedcaller_muster","muster_site_id":"site_moonwax_reed_circle","claim_count":2,"placement_id":"reedcaller_commission","encounter_id":"encounter_reedcaller_redgauge_commission","enemy_group_id":"army_blackbell_quench_watch","enemy_town_id":"reedcaller_enemy_town","record_flag":"reedcaller_commission_recorded","victory_flag":"reedcaller_redgauge_commission_fulfilled","objective_id":"redgauge_reed_drum","asset_id":"encounter_commission_reedcaller_redgauge_tower","region":Rect2(48,0,48,48)},
	{"scenario_id":"sevenfold-rootmirror-commission","hero_id":"hero_sunvault_aven_sevenfold","faction_id":"faction_sunvault","army_id":"army_aven_sevenfold_commission","reserve_unit_id":"unit_sunvault_noonfacet_sentinels","muster_id":"sevenfold_muster","muster_site_id":"site_facet_vigil","claim_count":2,"placement_id":"sevenfold_commission","encounter_id":"encounter_sevenfold_rootmirror_commission","enemy_group_id":"army_briarwheel_witness_watch","enemy_town_id":"sevenfold_enemy_town","record_flag":"sevenfold_commission_recorded","victory_flag":"sevenfold_rootmirror_commission_fulfilled","objective_id":"sevenfold_rootmirror","asset_id":"encounter_commission_sevenfold_rootmirror_arch","region":Rect2(96,0,48,48)},
	{"scenario_id":"boltroot-lockfire-commission","hero_id":"hero_thornwake_bryn_boltroot","faction_id":"faction_thornwake","army_id":"army_bryn_boltroot_commission","reserve_unit_id":"unit_thornwake_dawnseed_bolters","muster_id":"boltroot_muster","muster_site_id":"site_heartseed_bolt_grove","claim_count":2,"placement_id":"boltroot_commission","encounter_id":"encounter_boltroot_lockfire_commission","enemy_group_id":"army_rainwrit_charter_watch","enemy_town_id":"boltroot_enemy_town","record_flag":"boltroot_commission_recorded","victory_flag":"boltroot_lockfire_commission_fulfilled","objective_id":"boltroot_lockfire_beacon","asset_id":"encounter_commission_boltroot_lockfire_beacon","region":Rect2(144,0,48,48)},
	{"scenario_id":"blackgauge-noonwire-commission","hero_id":"hero_brasshollow_kestra_blackgauge","faction_id":"faction_brasshollow","army_id":"army_kestra_blackgauge_commission","reserve_unit_id":"unit_brasshollow_gaugeplate_bailiffs","muster_id":"blackgauge_muster","muster_site_id":"site_blackbell_assay_watch","claim_count":2,"placement_id":"blackgauge_commission","encounter_id":"encounter_blackgauge_noonwire_commission","enemy_group_id":"army_halo_spire_noon_watch","enemy_town_id":"blackgauge_enemy_town","record_flag":"blackgauge_commission_recorded","victory_flag":"blackgauge_noonwire_commission_fulfilled","objective_id":"blackgauge_prism_impound","asset_id":"encounter_commission_blackgauge_noonwire_impound","region":Rect2(192,0,48,48)},
	{"scenario_id":"tidehook-reedwake-commission","hero_id":"hero_veilmourn_olan_tidehook","faction_id":"faction_veilmourn","army_id":"army_olan_tidehook_commission","reserve_unit_id":"unit_veilmourn_tidehook_deckhands","muster_id":"tidehook_muster","muster_site_id":"site_last_memory_mooring","claim_count":5,"placement_id":"tidehook_commission","encounter_id":"encounter_tidehook_reedwake_commission","enemy_group_id":"army_nightglass_drowned_watch","enemy_town_id":"tidehook_enemy_town","record_flag":"tidehook_commission_recorded","victory_flag":"tidehook_reedwake_commission_fulfilled","objective_id":"tidehook_reedwake_bell","asset_id":"encounter_commission_tidehook_reedwake_bell","region":Rect2(240,0,48,48)}
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "The commission landmark atlas must remain exactly 288x48.")
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
		"muster_claim_count": _rows.filter(func(row): return bool(row.get("muster_claimed", false))).size(),
		"battle_victory_count": _rows.filter(func(row): return bool(row.get("battle_victory", false))).size(),
		"exact_encounter_art_count": _rows.filter(func(row): return bool(row.get("exact_art", false))).size(),
		"scenario_victory_count": _rows.filter(func(row): return bool(row.get("scenario_victory", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"direct_lead_count":6,"muster_claim_count":6,"battle_victory_count":6,"exact_encounter_art_count":6,"scenario_victory_count":6,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var campaign_chapter := scenario_id == "tidehook-reedwake-commission"
	var direct_lead := bool(availability.get("campaign", not campaign_chapter)) == campaign_chapter and bool(availability.get("skirmish", false)) and String(session.hero_id) == String(case.get("hero_id", "")) and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(scenario.get("player_army_id", "")) == String(case.get("army_id", ""))
	_expect(direct_lead, "%s did not preserve its selection availability and exact captain, faction, and company." % scenario_id)
	var map_size: Dictionary = scenario.get("map_size", {})
	_expect(int(map_size.get("width", 0)) == 12 and int(map_size.get("height", 0)) == 8 and scenario.get("towns", []).size() == 2 and scenario.get("resource_nodes", []).size() == 8 and scenario.get("artifact_nodes", []).size() == 1 and scenario.get("encounters", []).size() == 3 and scenario.get("script_hooks", []).size() == (6 if campaign_chapter else 5), "%s lost its compact authored composition: map=%s towns=%d resources=%d artifacts=%d encounters=%d hooks=%d." % [scenario_id, JSON.stringify(map_size), scenario.get("towns", []).size(), scenario.get("resource_nodes", []).size(), scenario.get("artifact_nodes", []).size(), scenario.get("encounters", []).size(), scenario.get("script_hooks", []).size()])

	var muster_result := _resource_node_result(session, String(case.get("muster_id", "")))
	var muster_node: Dictionary = muster_result.get("node", {})
	_expect(String(muster_node.get("site_id", "")) == String(case.get("muster_site_id", "")), "%s is missing its own live field muster." % scenario_id)
	var reserve_before := _army_count(session, String(case.get("reserve_unit_id", "")))
	_set_active_hero_position(session, Vector2i(int(muster_node.get("x", 0)), int(muster_node.get("y", 0))))
	var muster_claim := OverworldRules._collect_resource_node_result(session, muster_result, true)
	var muster_claimed := bool(muster_claim.get("ok", false)) and _army_count(session, String(case.get("reserve_unit_id", ""))) - reserve_before == int(case.get("claim_count", 0))
	_expect(muster_claimed, "%s did not claim its exact reserve company through live field-muster authority: %s" % [scenario_id, JSON.stringify(muster_claim)])

	var placement_id := String(case.get("placement_id", ""))
	var encounter := _encounter(session, placement_id)
	var encounter_id := String(case.get("encounter_id", ""))
	var encounter_definition := ContentService.get_encounter(encounter_id)
	var objective_rows: Array = encounter_definition.get("field_objectives", [])
	_expect(String(encounter.get("encounter_id", "")) == encounter_id and String(encounter_definition.get("enemy_group_id", "")) == String(case.get("enemy_group_id", "")), "%s lost its exact commission encounter or rival company." % scenario_id)
	_expect(objective_rows.size() == 1 and String(objective_rows[0].get("id", "")) == String(case.get("objective_id", "")), "%s lost its asymmetric battlefield objective." % encounter_id)
	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", encounter)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(presentation.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and bool(presentation.get("uses_identity_encounter_sprite", false)) and not bool(presentation.get("uses_commander_sprite", true)) and texture is AtlasTexture and texture.region == case.get("region", Rect2()) and texture.atlas is Texture2D and texture.atlas.resource_path == ATLAS_PATH and texture.atlas.get_size() == Vector2(288, 48)
	_expect(exact_art, "%s exact landmark did not reach the live map renderer." % encounter_id)
	var capture_path := await _capture_if_requested(scenario_id)

	var first := _clone_session(session)
	var second := _clone_session(session)
	var first_battle := BattleRulesScript.create_battle_payload(first, _encounter(first, placement_id))
	var second_battle := BattleRulesScript.create_battle_payload(second, _encounter(second, placement_id))
	_expect(not first_battle.is_empty() and not second_battle.is_empty(), "%s did not construct its production battle." % encounter_id)
	if first_battle.is_empty() or second_battle.is_empty():
		return
	first.battle = first_battle
	second.battle = second_battle
	first.game_state = "battle"
	second.game_state = "battle"
	first.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	second.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var first_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(first)
	var second_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(second)
	var deterministic := first_result == second_result and first.to_dict() == second.to_dict()
	var battle_victory: bool = bool(first_result.get("completed", false)) and String(first_result.get("state", "")) == "victory" and placement_id in first.overworld.get("resolved_encounters", []) and bool(first.flags.get(String(case.get("victory_flag", "")), false))
	_expect(deterministic, "%s fixed-seed battle was not deterministic." % encounter_id)
	_expect(battle_victory, "%s was not a viable production auto-resolve battle: %s" % [encounter_id, JSON.stringify(first_result)])
	if not battle_victory:
		return

	ScenarioScriptRulesScript.process_hooks(first)
	var expected_record_hook := String(case.get("record_flag", "")).trim_suffix("_commission_recorded") + "_record_hook"
	var fired_hook_ids: Array = first.overworld.get(ScenarioScriptRulesScript.SCRIPT_STATE_KEY, {}).get("fired_hook_ids", [])
	_expect(bool(first.flags.get(String(case.get("record_flag", "")), false)) and expected_record_hook in fired_hook_ids, "%s did not persist its commission-record hook." % scenario_id)
	var capture_message := OverworldRules.capture_town_by_placement(first, String(case.get("enemy_town_id", "")))
	_expect(capture_message != "", "%s enemy town did not transfer through live capture authority." % scenario_id)
	var scenario_result: Dictionary = ScenarioRulesScript.evaluate_session(first)
	var scenario_victory := String(scenario_result.get("status", "")) == "victory" and String(first.scenario_status) == "victory" and _met_victory_objective_count(first, scenario_id) == 3
	_expect(scenario_victory, "%s did not satisfy all three authored victory objectives: %s" % [scenario_id, JSON.stringify(scenario_result)])
	var restored := _clone_session(first)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == first.to_dict()
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"hero_id":String(case.get("hero_id", "")),"army_id":String(case.get("army_id", "")),"muster_site_id":String(case.get("muster_site_id", "")),"encounter_id":encounter_id,"direct_lead":direct_lead,"muster_claimed":muster_claimed,"battle_victory":battle_victory,"deterministic":deterministic,"exact_art":exact_art,"scenario_victory":scenario_victory,"capture_path":capture_path,"save_round_trip_exact":save_exact})


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


func _army_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	var total := 0
	for stack in session.overworld.get("hero", {}).get("army", {}).get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total


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
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("FIELD_MUSTER_COMMISSION_CAPTURE_DIR")
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
