extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")

const REPORT_ID := "TRIUNE_ARCANUM_TRIALS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/triune_arcanum_trials_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/triune_arcanum_trials_atlas.png"
const CASES := [
	{"scenario_id":"lockfire-upper-circle-trial","hero_id":"hero_seren","faction_id":"faction_embercourt","prefix":"lockfiretrial","site_id":"site_lockfire_triune_rostrum","asset_id":"resource_site_triune_arcanum_lockfire_rostrum","region":Rect2(0,0,48,48),"spells":["spell_beacon_bell_ward_09","spell_beacon_crown_signal_19","spell_beacon_lockfire_muster"]},
	{"scenario_id":"moonfen-upper-circle-trial","hero_id":"hero_sable","faction_id":"faction_mireclaw","prefix":"moonfentrial","site_id":"site_moonfen_triune_drumcourt","asset_id":"resource_site_triune_arcanum_moonfen_drumcourt","region":Rect2(48,0,48,48),"spells":["spell_mire_silt_rot_04","spell_mire_sluice_poultice_14","spell_mire_brine_fenlight_24"]},
	{"scenario_id":"three-facet-upper-circle-trial","hero_id":"hero_varis","faction_id":"faction_sunvault","prefix":"facettrial","site_id":"site_three_facet_meridian_orrery","asset_id":"resource_site_triune_arcanum_three_facet_orrery","region":Rect2(96,0,48,48),"spells":["spell_lens_mirror_prism_04","spell_lens_focus_array_14","spell_lens_starlens_prism_28"]},
	{"scenario_id":"heartwood-upper-circle-trial","hero_id":"hero_thornwake_tova_rootwright","faction_id":"faction_thornwake","prefix":"heartwoodtrial","site_id":"site_heartwood_three_vow_arbor","asset_id":"resource_site_triune_arcanum_heartwood_arbor","region":Rect2(144,0,48,48),"spells":["spell_root_bloom_briar_04","spell_root_branch_bloom_14","spell_root_bark_rootway_24"]},
	{"scenario_id":"redline-upper-circle-trial","hero_id":"hero_brasshollow_marka_ironclause","faction_id":"faction_brasshollow","prefix":"redlinetrial","site_id":"site_redline_triune_assay_forge","asset_id":"resource_site_triune_arcanum_redline_forge","region":Rect2(192,0,48,48),"spells":["spell_furnace_ash_mantle_09","spell_furnace_kiln_rite_19","spell_furnace_redline_overdrive"]},
	{"scenario_id":"drowned-bell-upper-circle-trial","hero_id":"hero_veilmourn_ivara_blacktide","faction_id":"faction_veilmourn","prefix":"drownedbelltrial","site_id":"site_drowned_bell_three_wake_archive","asset_id":"resource_site_triune_arcanum_drowned_bell_archive","region":Rect2(240,0,48,48),"spells":["spell_veil_mourning_mark_04","spell_veil_wraith_duel_14","spell_veil_tide_drift_24"]},
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
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "The triune academy atlas must remain exactly 288x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"lesson_count": _rows.reduce(func(total, row): return total + int(row.get("lesson_count", 0)), 0),
		"scoped_dependency_count": _rows.reduce(func(total, row): return total + int(row.get("scoped_dependency_count", 0)), 0),
		"spell_resolution_count": _rows.reduce(func(total, row): return total + int(row.get("spell_resolution_count", 0)), 0),
		"exact_art_count": _rows.filter(func(row): return bool(row.get("exact_art", false))).size(),
		"missing_spell_control_count": _rows.filter(func(row): return bool(row.get("missing_spell_control", false))).size(),
		"transferred_spell_count": _rows.filter(func(row): return bool(row.get("transferred_spell", false))).size(),
		"battle_victory_count": _rows.reduce(func(total, row): return total + int(row.get("battle_victory_count", 0)), 0),
		"scenario_victory_count": _rows.filter(func(row): return bool(row.get("scenario_victory", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"lesson_count":18,"spell_resolution_count":18,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var spells: Array = case.get("spells", [])
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(scenario_id)
	_expect(String(session.overworld.get("hero", {}).get("id", "")) == String(case.get("hero_id", "")), "%s launched the wrong direct lead." % scenario_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")), "%s launched the wrong faction." % scenario_id)
	_remove_spells(session, spells)
	for index in range(spells.size()):
		_expect(not ScenarioRulesScript.is_objective_met(session, "%s_learn_%d" % [prefix, index + 1], "victory"), "%s began with trial spell %s." % [scenario_id, spells[index]])

	var node_result := _resource_node_result(session, "%s_academy" % prefix)
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(case.get("site_id", "")))
	_expect(not node.is_empty() and String(node.get("site_id", "")) == String(case.get("site_id", "")), "%s lost its academy placement." % scenario_id)
	_expect(site.get("learn_spell_ids", []) == spells and String(site.get("runtime_boundary", {}).get("status", "")) == "triune_arcanum_live", "%s lost its exact three-lesson contract." % scenario_id)
	var asset_id := String(view.call("_resource_asset_id", node))
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_art: bool = asset_id == String(case.get("asset_id", "")) and texture is AtlasTexture and texture.atlas.resource_path == ATLAS_PATH and texture.region == case.get("region")
	_expect(exact_art, "%s did not resolve its exact academy atlas region." % scenario_id)

	var before_xp := int(session.overworld.get("hero", {}).get("experience", 0))
	var claim: Dictionary = OverworldRules._collect_resource_node_result(session, node_result, true)
	_expect(bool(claim.get("ok", false)), "%s academy claim failed: %s" % [scenario_id, JSON.stringify(claim)])
	var after_known: Array = _known_spell_ids(session.overworld.get("hero", {}))
	var lesson_count := spells.filter(func(spell_id): return spell_id in after_known).size()
	_expect(lesson_count == 3, "%s learned %d of 3 spells." % [scenario_id, lesson_count])
	_expect(int(session.overworld.get("hero", {}).get("experience", 0)) - before_xp >= 180, "%s lost its lesson experience reward." % scenario_id)
	var mutation_facts: Dictionary = claim.get("interaction_result", {}).get("mutation_facts", {})
	_expect(mutation_facts.get("spell_ids", []) == spells, "%s did not expose all three learned spell ids in its interaction event." % scenario_id)
	var scoped: Dictionary = ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"spell_lesson_completed","spell_ids":spells})
	var profile: Dictionary = scoped.get("profile", {})
	var scoped_count := 3 if String(profile.get("dependency_mode", "")) == "scoped" and int(profile.get("objectives_checked", 0)) >= 3 else 0
	_expect(scoped_count == 3, "%s did not use exact scoped spell-objective dependencies: %s" % [scenario_id, JSON.stringify(profile)])
	var authority_after := session.to_dict()
	var repeat: Dictionary = OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_academy" % prefix), true)
	_expect(not bool(repeat.get("ok", true)) and session.to_dict() == authority_after, "%s repeat academy claim mutated authority." % scenario_id)

	var spell_resolution_count := 0
	for spell_id_value in spells:
		if _resolve_spell(session.overworld.get("hero", {}), String(spell_id_value)):
			spell_resolution_count += 1
	_expect(spell_resolution_count == 3, "%s resolved %d of 3 learned spell behaviors." % [scenario_id, spell_resolution_count])

	var missing_probe := _clone_session(session)
	_remove_spells(missing_probe, [spells[2]])
	_mark_exam_resolved(missing_probe, prefix)
	var missing_result: Dictionary = ScenarioRulesScript.evaluate_session(missing_probe)
	var missing_spell_control := String(missing_result.get("status", "")) == "in_progress" and not ScenarioRulesScript.is_objective_met(missing_probe, "%s_learn_3" % prefix, "victory")
	_expect(missing_spell_control, "%s won while its third spell remained unknown." % scenario_id)

	var active: Dictionary = session.overworld.get("hero", {})
	var active_spellbook: Dictionary = active.get("spellbook", {}).duplicate(true)
	var active_known: Array = active_spellbook.get("known_spell_ids", []).duplicate(true)
	active_known.erase(spells[2])
	active_spellbook["known_spell_ids"] = active_known
	active["spellbook"] = active_spellbook
	session.overworld["hero"] = active
	var secondary := {"id":"%s_apprentice" % prefix,"name":"Trial Apprentice","spellbook":{"known_spell_ids":[spells[2]],"mana":{"current":20,"max":20}}}
	var heroes: Array = session.overworld.get("player_heroes", [])
	heroes.append(secondary)
	session.overworld["player_heroes"] = heroes
	var transferred_spell := ScenarioRulesScript.is_objective_met(session, "%s_learn_3" % prefix, "victory")
	_expect(transferred_spell, "%s did not recognize the third lesson on a secondary player hero." % scenario_id)

	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(node.get("x", 0)), int(node.get("y", 0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)
	var battle_victory_count := 0
	for exam_index in range(1, 4):
		if _resolve_exam(session, "%s_exam_%d" % [prefix, exam_index]):
			battle_victory_count += 1
	_expect(battle_victory_count == 3, "%s won %d of 3 production examinations." % [scenario_id, battle_victory_count])
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory := String(victory_result.get("status", "")) == "victory" and _met_victory_objective_count(session, scenario_id) == 6
	_expect(scenario_victory, "%s did not complete its six-condition victory chain: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"lesson_count":lesson_count,"scoped_dependency_count":scoped_count,"spell_resolution_count":spell_resolution_count,"exact_art":exact_art,"missing_spell_control":missing_spell_control,"transferred_spell":transferred_spell,"battle_victory_count":battle_victory_count,"scenario_victory":scenario_victory,"capture_path":capture_path,"save_round_trip_exact":save_exact})


func _resolve_spell(hero: Dictionary, spell_id: String) -> bool:
	hero = hero.duplicate(true)
	var command: Dictionary = hero.get("command", {}).duplicate(true)
	command["knowledge"] = maxi(5, int(command.get("knowledge", 0)))
	hero["command"] = command
	var spellbook: Dictionary = hero.get("spellbook", {}).duplicate(true)
	spellbook["mana"] = {"current":80,"max":80}
	hero["spellbook"] = spellbook
	var spell := ContentService.get_spell(spell_id)
	if String(spell.get("context", "")) == "overworld":
		var overworld_result := SpellRulesScript.cast_overworld_spell(hero, {"current":0,"max":24,"base":24}, spell_id)
		if not bool(overworld_result.get("ok", false)):
			print("%s SPELL_FAILED %s %s" % [REPORT_ID, spell_id, JSON.stringify(overworld_result)])
		return bool(overworld_result.get("ok", false))
	var active := _battle_stack("trial_caster", "player")
	var hostile_effect := String(spell.get("effect", {}).get("type", "")) in ["damage_enemy", "control_enemy"]
	var target_side := "enemy" if hostile_effect else "player"
	var target := _battle_stack("trial_target", target_side)
	var battle := {"round":1,"resistance_seed":"triune_%s" % spell_id,"player_hero":{"battle_spell_resistance_pct":0,"battle_control_resistance_pct":0,"battle_school_resistance_pct":{}},"enemy_hero_payload":{"battle_spell_resistance_pct":0,"battle_control_resistance_pct":0,"battle_school_resistance_pct":{}},"stacks":[active,target]}
	var battle_result := SpellRulesScript.resolve_battle_spell(hero, battle, active, target, spell_id)
	if not bool(battle_result.get("ok", false)):
		print("%s SPELL_FAILED %s context=%s %s" % [REPORT_ID, spell_id, String(spell.get("context", "")), JSON.stringify(battle_result)])
	return bool(battle_result.get("ok", false))


func _resolve_exam(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		return false
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		return false
	session.battle = payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	return bool(result.get("completed", false)) and String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])


func _battle_stack(battle_id: String, side: String) -> Dictionary:
	return {"battle_id":battle_id,"side":side,"name":battle_id.capitalize(),"base_count":12,"unit_hp":12,"total_health":144,"attack":7,"defense":7,"initiative":7,"cohesion":7,"effects":[],"spell_resistance_pct":0,"control_resistance_pct":0,"spell_school_resistance_pct":{},"status_immunity_ids":[]}


func _remove_spells(session: SessionStateStoreScript.SessionData, spell_ids: Array) -> void:
	var hero: Dictionary = session.overworld.get("hero", {})
	var spellbook: Dictionary = hero.get("spellbook", {}).duplicate(true)
	var known: Array = spellbook.get("known_spell_ids", []).duplicate(true)
	for spell_id in spell_ids:
		known.erase(spell_id)
	spellbook["known_spell_ids"] = known
	spellbook["mana"] = {"current":80,"max":80}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero
	var active_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_id:
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes


func _known_spell_ids(hero: Dictionary) -> Array:
	return hero.get("spellbook", {}).get("known_spell_ids", []) if hero.get("spellbook", {}) is Dictionary else []


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


func _mark_exam_resolved(session: SessionStateStoreScript.SessionData, prefix: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	for exam_index in range(1, 4):
		var placement_id := "%s_exam_%d" % [prefix, exam_index]
		if placement_id not in resolved:
			resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved


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
	var capture_dir := OS.get_environment("TRIUNE_ARCANUM_TRIAL_CAPTURE_DIR")
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
