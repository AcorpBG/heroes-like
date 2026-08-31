extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")

const REPORT_ID := "TWIN_COMMAND_FIELD_COUNCILS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/twin_command_field_councils_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/twin_command_field_councils_atlas.png"
const CASES := [
	{"scenario_id":"pikeward-cinderquill-twin-beacon-council","prefix":"twinbeacon","primary_id":"hero_torren","partner_id":"hero_embercourt_orra_cinderquill","site_id":"site_embercourt_twin_beacon_field_council","asset_id":"resource_site_twin_command_embercourt_council","region":Rect2(0,0,48,48)},
	{"scenario_id":"fenhook-votivejaw-two-mask-council","prefix":"twomask","primary_id":"hero_tarn","partner_id":"hero_mireclaw_nix_votivejaw","site_id":"site_mireclaw_two_mask_field_council","asset_id":"resource_site_twin_command_mireclaw_council","region":Rect2(48,0,48,48)},
	{"scenario_id":"lenscaptain-sunvein-split-ray-council","prefix":"splitray","primary_id":"hero_sunvault_dovan_lenscaptain","partner_id":"hero_sunvault_calis_sunvein","site_id":"site_sunvault_split_ray_field_council","asset_id":"resource_site_twin_command_sunvault_council","region":Rect2(96,0,48,48)},
	{"scenario_id":"greenbarrow-seedseer-forkroot-council","prefix":"forkroot","primary_id":"hero_thornwake_merek_greenbarrow","partner_id":"hero_thornwake_veyra_seedseer","site_id":"site_thornwake_forkroot_field_council","asset_id":"resource_site_twin_command_thornwake_council","region":Rect2(144,0,48,48)},
	{"scenario_id":"bellfounder-quench-double-gauge-council","prefix":"doublegauge","primary_id":"hero_brasshollow_oren_bellfounder","partner_id":"hero_brasshollow_vellum_quench","site_id":"site_brasshollow_double_gauge_field_council","asset_id":"resource_site_twin_command_brasshollow_council","region":Rect2(192,0,48,48)},
	{"scenario_id":"vanehook-obituaryink-twin-wake-council","prefix":"twinwake","primary_id":"hero_veilmourn_ruln_vanehook","partner_id":"hero_veilmourn_thir_obituaryink","site_id":"site_veilmourn_twin_wake_field_council","asset_id":"resource_site_twin_command_veilmourn_council","region":Rect2(240,0,48,48)},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Twin Command council atlas must remain exactly 288x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"exact_art_count": _count_rows("exact_art"),
		"missing_partner_control_count": _count_rows("missing_partner_control"),
		"wrong_town_control_count": _count_rows("wrong_town_control"),
		"enemy_owned_town_control_count": _count_rows("enemy_owned_town_control"),
		"wrong_hero_control_count": _count_rows("wrong_hero_control"),
		"production_hire_count": _count_rows("production_hire"),
		"production_transfer_count": _rows.reduce(func(total, row): return total + int(row.get("production_transfer_count", 0)), 0),
		"production_battle_count": _rows.reduce(func(total, row): return total + int(row.get("production_battle_count", 0)), 0),
		"production_claim_count": _count_rows("production_claim"),
		"production_capture_count": _count_rows("production_capture"),
		"paired_station_count": _count_rows("paired_station"),
		"scoped_dependency_count": _count_rows("scoped_dependency"),
		"scenario_victory_count": _count_rows("scenario_victory"),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_hire_count":6,"production_transfer_count":12,"production_battle_count":18,"paired_station_count":6,"scenario_victory_count":6,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var primary_id := String(case.get("primary_id", ""))
	var partner_id := String(case.get("partner_id", ""))
	var home_id := "%s_home" % prefix
	var forward_id := "%s_forward" % prefix
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(scenario_id)
	var victory: Array = scenario.get("objectives", {}).get("victory", [])
	var primary_objective: Dictionary = victory[0]
	var partner_objective: Dictionary = victory[1]
	var missing_partner_control := not ScenarioRulesScript.is_objective_met(session, String(partner_objective.get("id", "")), "victory")
	_expect(missing_partner_control, "%s accepted an unrecruited partner commander." % scenario_id)

	var node_result := _resource_node_result(session, "%s_council" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact council atlas region." % scenario_id)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x", 0)), int(node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var home := _town(session, home_id)
	_set_hero_position(session, primary_id, Vector2i(int(home.get("x", 0)), int(home.get("y", 0))))
	var tavern_ids: Array = TownRulesScript.get_tavern_actions(session).map(func(action): return String(action.get("id", "")))
	var hire: Dictionary = TownRulesScript.hire_hero_at_active_town(session, partner_id)
	var production_hire := bool(hire.get("ok", false)) and "hire_hero:%s" % partner_id in tavern_ids and not HeroCommandRulesScript.hero_by_id(session, partner_id).is_empty()
	_expect(production_hire, "%s did not hire its exact partner through the production tavern path: %s" % [scenario_id, JSON.stringify(hire)])

	var wrong_town_probe := _clone_session(session)
	OverworldRules.capture_town_by_placement(wrong_town_probe, forward_id)
	var wrong_town_control := not ScenarioRulesScript.is_objective_met(wrong_town_probe, String(partner_objective.get("id", "")), "victory")
	_expect(wrong_town_control, "%s accepted the partner at the wrong controlled town." % scenario_id)
	var enemy_probe := _clone_session(session)
	_set_hero_position(enemy_probe, partner_id, _town_position(enemy_probe, forward_id))
	_set_town_owner(enemy_probe, forward_id, "enemy")
	var enemy_owned_town_control := not ScenarioRulesScript.is_objective_met(enemy_probe, String(partner_objective.get("id", "")), "victory")
	_expect(enemy_owned_town_control, "%s accepted a partner stationed in an enemy-owned town." % scenario_id)
	var wrong_hero_probe := _clone_session(session)
	OverworldRules.capture_town_by_placement(wrong_hero_probe, forward_id)
	_set_hero_position(wrong_hero_probe, primary_id, _town_position(wrong_hero_probe, forward_id))
	var wrong_hero_control := not ScenarioRulesScript.is_objective_met(wrong_hero_probe, String(partner_objective.get("id", "")), "victory")
	_expect(wrong_hero_control, "%s accepted the wrong commander at the forward seat." % scenario_id)

	var opening_stacks: Array = session.overworld.get("hero", {}).get("army", {}).get("stacks", [])
	var production_transfer_count := 0
	for stack_value in opening_stacks.slice(3, 5):
		if stack_value is Dictionary:
			var transfer := HeroCommandRulesScript.transfer_town_stack(session, home, primary_id, partner_id, String(stack_value.get("unit_id", "")), "all")
			if bool(transfer.get("ok", false)):
				production_transfer_count += 1
	_expect(production_transfer_count == 2 and HeroCommandRulesScript.hero_by_id(session, partner_id).get("army", {}).get("stacks", []).size() == 2, "%s did not transfer two complete stacks through stationed town authority." % scenario_id)
	var switch_result: Dictionary = TownRulesScript.switch_active_hero_at_town(session, partner_id)
	_expect(bool(switch_result.get("ok", false)) and String(session.overworld.get("active_hero_id", "")) == partner_id, "%s did not switch active command at the home town." % scenario_id)

	var production_battle_count := 0
	for suffix in ["north_dispatch", "council_guard", "south_dispatch"]:
		if _resolve_guard(session, "%s_%s" % [prefix, suffix]):
			production_battle_count += 1
	_expect(production_battle_count == 3, "%s did not clear all three fronts through production battle authority." % scenario_id)

	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var partner_stack_count_before: int = HeroCommandRulesScript.hero_by_id(session, partner_id).get("army", {}).get("stacks", []).size()
	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_council" % prefix), true)
	var claim_authority := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_council" % prefix), true)
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	var claim_flag := String(site.get("claim_flags", {}).keys()[0])
	var rare_id := String(site.get("claim_rewards", {}).keys().filter(func(key): return String(key) != "gold")[0])
	var production_claim: bool = bool(claim.get("ok", false)) and bool(session.flags.get(claim_flag, false)) and int(session.overworld.get("resources", {}).get("gold", 0)) == int(resources_before.get("gold", 0)) + 700 and int(session.overworld.get("resources", {}).get(rare_id, 0)) == int(resources_before.get(rare_id, 0)) + 2 and HeroCommandRulesScript.hero_by_id(session, partner_id).get("army", {}).get("stacks", []).size() >= partner_stack_count_before and not bool(repeat.get("ok", true)) and session.to_dict() == claim_authority
	_expect(production_claim, "%s did not grant its exact one-time stores, recruits, and council flag." % scenario_id)

	_set_hero_position(session, partner_id, _town_position(session, forward_id))
	var capture_message := OverworldRules.capture_town_by_placement(session, forward_id)
	var production_capture := capture_message != "" and String(_town(session, forward_id).get("owner", "")) == "player"
	_expect(production_capture, "%s did not transfer its forward town through live capture authority." % scenario_id)
	var paired_station := ScenarioRulesScript.is_objective_met(session, String(primary_objective.get("id", "")), "victory") and ScenarioRulesScript.is_objective_met(session, String(partner_objective.get("id", "")), "victory")
	_expect(paired_station, "%s did not recognize both exact controlled commanders at their exact towns." % scenario_id)

	var scoped_result: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"hero_moved","hero_ids":[partner_id],"town_placement_ids":[forward_id]})
	var scoped_profile: Dictionary = scoped_result.get("profile", {})
	var scoped_dependency := String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked", 0)) >= 1
	_expect(scoped_dependency, "%s did not expose scoped hero-and-town stationing dependencies." % scenario_id)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(victory_result.get("status", "")) == "victory" and session.day < 18
	_expect(scenario_victory, "%s did not win after the paired deployment and three live fronts: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and ScenarioRulesScript.is_objective_met(restored, String(partner_objective.get("id", "")), "victory")
	_expect(save_exact, "%s did not preserve both stationed commanders through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_art":exact_art,"missing_partner_control":missing_partner_control,"wrong_town_control":wrong_town_control,"enemy_owned_town_control":enemy_owned_town_control,"wrong_hero_control":wrong_hero_control,"production_hire":production_hire,"production_transfer_count":production_transfer_count,"production_battle_count":production_battle_count,"production_claim":production_claim,"production_capture":production_capture,"paired_station":paired_station,"scoped_dependency":scoped_dependency,"scenario_victory":scenario_victory,"completion_day":session.day,"capture_path":capture_path,"save_round_trip_exact":save_exact})


func _resolve_guard(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		return false
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		return false
	session.battle = payload
	session.game_state = "battle"
	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			session.battle["stacks"][index] = stack
	var result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	return String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])


func _set_hero_position(session, hero_id: String, position: Vector2i) -> void:
	var normalized := {"x":position.x,"y":position.y}
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index].duplicate(true)
			hero["position"] = normalized.duplicate(true)
			heroes[index] = hero
			if String(session.overworld.get("active_hero_id", "")) == hero_id:
				session.overworld["hero"] = hero.duplicate(true)
				session.overworld["hero_position"] = normalized.duplicate(true)
			break
	session.overworld["player_heroes"] = heroes
	HeroCommandRulesScript.normalize_session(session)


func _set_town_owner(session, placement_id: String, owner: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			var town: Dictionary = towns[index].duplicate(true)
			town["owner"] = owner
			towns[index] = town
			break
	session.overworld["towns"] = towns


func _town_position(session, placement_id: String) -> Vector2i:
	var town := _town(session, placement_id)
	return Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))


func _town(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _clone_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("TWIN_COMMAND_FIELD_COUNCILS_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
