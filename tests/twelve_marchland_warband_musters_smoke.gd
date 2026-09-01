extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "TWELVE_MARCHLAND_WARBAND_MUSTERS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/twelve_marchland_warband_musters_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/marchland_warband_musters_atlas.png"
const BATCH_ID := "content-twelve-marchland-warband-musters-10184"
const CASES := [
	{"scenario_id":"tollbrand-toll-chain-muster","prefix":"tollchain","hero_id":"hero_embercourt_helva_tollbrand","faction_id":"faction_embercourt","site_id":"site_tollbrand_toll_chain_standard","asset_id":"resource_site_muster_tollbrand_toll_chain_standard","region":Rect2(0,0,48,48),"width":16,"height":10,"nodes":10,"rare":"embergrain","unit_a":"unit_embercourt_amberweir_lockpike_wardens","unit_b":"unit_embercourt_amberweir_sluicebrand_mangonels"},
	{"scenario_id":"beaconscribe-beacon-ledger-muster","prefix":"beaconledger","hero_id":"hero_embercourt_jorun_beaconscribe","faction_id":"faction_embercourt","site_id":"site_beaconscribe_beacon_ledger_post","asset_id":"resource_site_muster_beaconscribe_beacon_ledger_post","region":Rect2(48,0,48,48),"width":20,"height":12,"nodes":12,"rare":"embergrain","unit_a":"unit_embercourt_amberweir_lockpike_wardens","unit_b":"unit_embercourt_amberweir_sluicebrand_mangonels"},
	{"scenario_id":"mudkeel-keel-drum-muster","prefix":"keeldrum","hero_id":"hero_mireclaw_brakka_mudkeel","faction_id":"faction_mireclaw","site_id":"site_mudkeel_keel_drum_rally","asset_id":"resource_site_muster_mudkeel_keel_drum_rally","region":Rect2(96,0,48,48),"width":16,"height":10,"nodes":10,"rare":"peatwax","unit_a":"unit_mireclaw_moonbite_votive_drummers","unit_b":"unit_mireclaw_moonbite_mirehorn_breakers"},
	{"scenario_id":"rotlamp-muster-cage","prefix":"rotlamp","hero_id":"hero_mireclaw_edda_rotlamp","faction_id":"faction_mireclaw","site_id":"site_rotlamp_muster_cage","asset_id":"resource_site_muster_rotlamp_muster_cage","region":Rect2(144,0,48,48),"width":20,"height":12,"nodes":12,"rare":"peatwax","unit_a":"unit_mireclaw_moonbite_votive_drummers","unit_b":"unit_mireclaw_moonbite_mirehorn_breakers"},
	{"scenario_id":"sunvein-sun-thread-muster","prefix":"sunthread","hero_id":"hero_sunvault_calis_sunvein","faction_id":"faction_sunvault","site_id":"site_sunvein_sun_thread_standard","asset_id":"resource_site_muster_sunvein_sun_thread_standard","region":Rect2(192,0,48,48),"width":16,"height":10,"nodes":10,"rare":"aetherglass","unit_a":"unit_sunvault_splitprism_parallax_fencers","unit_b":"unit_sunvault_splitprism_heliograph_ballistae"},
	{"scenario_id":"lenscaptain-range-lens-muster","prefix":"rangelens","hero_id":"hero_sunvault_dovan_lenscaptain","faction_id":"faction_sunvault","site_id":"site_lenscaptain_range_lens_rally","asset_id":"resource_site_muster_lenscaptain_range_lens_rally","region":Rect2(240,0,48,48),"width":20,"height":12,"nodes":12,"rare":"aetherglass","unit_a":"unit_sunvault_splitprism_parallax_fencers","unit_b":"unit_sunvault_splitprism_heliograph_ballistae"},
	{"scenario_id":"loamchant-chorus-bough-muster","prefix":"chorusbough","hero_id":"hero_thornwake_elian_loamchant","faction_id":"faction_thornwake","site_id":"site_loamchant_chorus_bough","asset_id":"resource_site_muster_loamchant_chorus_bough","region":Rect2(288,0,48,48),"width":16,"height":10,"nodes":10,"rare":"verdant_grafts","unit_a":"unit_thornwake_woundroot_hearthseed_slingers","unit_b":"unit_thornwake_woundroot_rootmaul_behemoths"},
	{"scenario_id":"thorncart-cart-crown-muster","prefix":"cartcrown","hero_id":"hero_thornwake_halen_thorncart","faction_id":"faction_thornwake","site_id":"site_thorncart_cart_crown_rally","asset_id":"resource_site_muster_thorncart_cart_crown_rally","region":Rect2(336,0,48,48),"width":20,"height":12,"nodes":12,"rare":"verdant_grafts","unit_a":"unit_thornwake_woundroot_hearthseed_slingers","unit_b":"unit_thornwake_woundroot_rootmaul_behemoths"},
	{"scenario_id":"debtrune-debt-seal-muster","prefix":"debtseal","hero_id":"hero_brasshollow_harro_debtrune","faction_id":"faction_brasshollow","site_id":"site_debtrune_debt_seal_gantry","asset_id":"resource_site_muster_debtrune_debt_seal_gantry","region":Rect2(384,0,48,48),"width":16,"height":10,"nodes":10,"rare":"brass_scrip","unit_a":"unit_brasshollow_whitegauge_datum_lancers","unit_b":"unit_brasshollow_whitegauge_datum_breach_cannons"},
	{"scenario_id":"pitmarshal-pit-bell-muster","prefix":"pitbell","hero_id":"hero_brasshollow_selka_pitmarshal","faction_id":"faction_brasshollow","site_id":"site_pitmarshal_pit_bell_rally","asset_id":"resource_site_muster_pitmarshal_pit_bell_rally","region":Rect2(432,0,48,48),"width":20,"height":12,"nodes":12,"rare":"brass_scrip","unit_a":"unit_brasshollow_whitegauge_datum_lancers","unit_b":"unit_brasshollow_whitegauge_datum_breach_cannons"},
	{"scenario_id":"mistcorsair-fog-sail-muster","prefix":"fogsail","hero_id":"hero_veilmourn_cela_mistcorsair","faction_id":"faction_veilmourn","site_id":"site_mistcorsair_fog_sail_muster","asset_id":"resource_site_muster_mistcorsair_fog_sail","region":Rect2(480,0,48,48),"width":16,"height":10,"nodes":10,"rare":"memory_salt","unit_a":"unit_veilmourn_dreamwake_tideglass_oracles","unit_b":"unit_veilmourn_dreamwake_foganchor_colossi"},
	{"scenario_id":"keelwarden-keel-sounding-muster","prefix":"keelsounding","hero_id":"hero_veilmourn_jessa_keelwarden","faction_id":"faction_veilmourn","site_id":"site_keelwarden_keel_sounding_frame","asset_id":"resource_site_muster_keelwarden_keel_sounding_frame","region":Rect2(528,0,48,48),"width":20,"height":12,"nodes":12,"rare":"memory_salt","unit_a":"unit_veilmourn_dreamwake_tideglass_oracles","unit_b":"unit_veilmourn_dreamwake_foganchor_colossi"},
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
	_expect(atlas != null and atlas.get_size() == Vector2(576, 48), "Marchland Warband Musters atlas must remain exactly 576x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok":_errors.is_empty(), "case_count":CASES.size(), "exact_launch_count":_count_rows("exact_launch"),
		"production_battle_count":_sum_rows("production_battles"), "production_claim_count":_count_rows("production_claim"),
		"exact_art_count":_count_rows("exact_art"), "objective_victory_count":_count_rows("objective_victory"),
		"save_round_trip_count":_count_rows("save_round_trip"), "capture_count":_count_rows("capture_written"),
		"save_version":SessionStateStoreScript.SAVE_VERSION, "single_consolidated_smoke":true, "rows":_rows, "errors":_errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":12,"production_battle_count":48,"production_claim_count":12,"objective_victory_count":12,"save_round_trip_count":12,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s could not create a live skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var exact_launch: bool = (
		String(session.hero_id) == String(case.get("hero_id", ""))
		and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", ""))
		and String(scenario.get("content_batch_id", "")) == BATCH_ID
		and int(scenario.get("map_size", {}).get("width", 0)) == int(case.get("width", 0))
		and int(scenario.get("map_size", {}).get("height", 0)) == int(case.get("height", 0))
		and session.overworld.get("army", {}).get("stacks", []).size() == 5
		and scenario.get("towns", []).size() == 2
		and scenario.get("encounters", []).size() == 4
		and scenario.get("resource_nodes", []).size() == int(case.get("nodes", 0))
		and scenario.get("script_hooks", []).size() == 5
		and scenario.get("objectives", {}).get("victory", []).size() == 6
	)
	_expect(exact_launch, "%s lost its exact board, hero, faction, five-stack, two-town, four-front muster contract." % scenario_id)

	var node_result := _resource_node_result(session, "%s_landmark" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact rally-landmark atlas region." % scenario_id)
	var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var production_battles := 0
	for index in range(1, 5):
		var placement_id := "%s_front_%d" % [prefix, index]
		var battle_probe := _clone_session(session)
		if _resolve_front(battle_probe, placement_id):
			production_battles += 1
			var resolved: Array = session.overworld.get("resolved_encounters", [])
			if placement_id not in resolved:
				resolved.append(placement_id)
			session.overworld["resolved_encounters"] = resolved
	_expect(production_battles == 4, "%s did not win all four production battle probes." % scenario_id)

	var rare_key := String(case.get("rare", ""))
	var unit_a := String(case.get("unit_a", ""))
	var unit_b := String(case.get("unit_b", ""))
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var unit_a_before := _army_unit_count(session, unit_a)
	var unit_b_before := _army_unit_count(session, unit_b)
	var xp_before := int(session.overworld.get("hero", {}).get("experience", 0))
	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_landmark" % prefix), true)
	var claimed_state := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_landmark" % prefix), true)
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	var flag := String(site.get("claim_flags", {}).keys()[0])
	var production_claim: bool = (
		bool(claim.get("ok", false)) and bool(session.flags.get(flag, false))
		and int(session.overworld.get("hero", {}).get("experience", 0)) == xp_before + 150
		and int(session.overworld.get("resources", {}).get("gold", 0)) == int(resources_before.get("gold", 0)) + 2200
		and int(session.overworld.get("resources", {}).get(rare_key, 0)) == int(resources_before.get(rare_key, 0)) + 1
		and _army_unit_count(session, unit_a) == unit_a_before + 5
		and _army_unit_count(session, unit_b) == unit_b_before + 1
		and not bool(repeat.get("ok", true)) and session.to_dict() == claimed_state
	)
	_expect(production_claim, "%s claim mismatch: ok=%s flag=%s xp_delta=%d gold_delta=%d rare_delta=%d unit_a_delta=%d unit_b_delta=%d repeat_ok=%s repeat_exact=%s" % [scenario_id, bool(claim.get("ok", false)), bool(session.flags.get(flag, false)), int(session.overworld.get("hero", {}).get("experience", 0)) - xp_before, int(session.overworld.get("resources", {}).get("gold", 0)) - int(resources_before.get("gold", 0)), int(session.overworld.get("resources", {}).get(rare_key, 0)) - int(resources_before.get(rare_key, 0)), _army_unit_count(session, unit_a) - unit_a_before, _army_unit_count(session, unit_b) - unit_b_before, bool(repeat.get("ok", true)), session.to_dict() == claimed_state])

	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var deadline := 21 if int(case.get("width", 0)) == 16 else 24
	var objective_victory: bool = String(victory_result.get("status", "")) == "victory" and _met_victory_objective_count(session, scenario_id) == 6 and session.day < deadline
	_expect(objective_victory, "%s did not complete all six live objectives: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_round_trip: bool = int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict() and _met_victory_objective_count(restored, scenario_id) == 6
	_expect(save_round_trip, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_launch":exact_launch,"production_battles":production_battles,"production_claim":production_claim,"exact_art":exact_art,"objective_victory":objective_victory,"save_round_trip":save_round_trip,"capture_written":capture_path != "","capture_path":capture_path,"completion_day":session.day})
	SessionState.set_active_session(null)


func _resolve_front(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		return false
	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		return false
	session.battle = payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	return bool(result.get("completed", false)) and String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])


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


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = tile.x
	hero["y"] = tile.y
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["x"] = tile.x
			roster_hero["y"] = tile.y
			roster_hero["position"] = position.duplicate(true)
			heroes[index] = roster_hero
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


func _army_unit_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	for stack in session.overworld.get("army", {}).get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			return int(stack.get("count", 0))
	return 0


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("TWELVE_MARCHLAND_WARBAND_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _sum_rows(key: String) -> int:
	return _rows.reduce(func(total, row): return total + int(row.get(key, 0)), 0)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])
