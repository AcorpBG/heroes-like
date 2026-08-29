extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_FACTION_GRAND_CONVERGENCE_MARCHES_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_faction_grand_convergence_marches_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/grand_convergence_marches/grand_convergence_marches_atlas.png"
const GRAND_CONVERGENCE_PLAYER_UNIT_IDS := [
	"unit_embercourt_fordhook_cadets", "unit_embercourt_bargebow_crews", "unit_embercourt_ash_oath_bailiffs", "unit_embercourt_sluicefire_lindworms", "unit_embercourt_charter_colossus",
	"unit_mireclaw_reedsnare_kin", "unit_mireclaw_bogplate_maulers", "unit_mireclaw_ferrychain_lashers", "unit_mireclaw_gorefen_rippers", "unit_mireclaw_drowned_antler_sovereign",
	"unit_sunvault_shard_wardens", "unit_sunvault_mirror_duelists", "unit_sunvault_resonant_choristers", "unit_sunvault_aurora_ballistae", "unit_sunvault_daybreak_colossus",
	"unit_thornwake_seedcutters", "unit_thornwake_sporeglass_menders", "unit_thornwake_barkmantle_rams", "unit_thornwake_graft_matriarchs", "unit_thornwake_worldroot_bastion",
	"unit_brasshollow_scrip_haulers", "unit_brasshollow_furnace_pavis_teams", "unit_brasshollow_boiler_rivetcasters", "unit_brasshollow_crucible_crawlers", "unit_brasshollow_foundry_saint",
	"unit_veilmourn_bellwake_oars", "unit_veilmourn_maskglass_corsairs", "unit_veilmourn_undertow_harpooners", "unit_veilmourn_mirrorkeel_reavers", "unit_veilmourn_fogbound_leviathan",
]
const GRAND_CONVERGENCE_PRIMARY_UNIT_IDS := [
	"unit_neutral_charcoal_mauls", "unit_neutral_emberpack_lobbers",
	"unit_neutral_bogbell_mauls", "unit_neutral_peatflare_jarriers",
	"unit_neutral_icehook_trappers", "unit_neutral_whitepike_keepers",
	"unit_neutral_tunnel_lanterns", "unit_neutral_glimmercap_needlers",
	"unit_brasshollow_rivet_hounds", "unit_brasshollow_boiler_rivetcasters", "unit_brasshollow_debt_engine_exactors",
	"unit_veilmourn_mourning_lanterns", "unit_veilmourn_undertow_harpooners", "unit_veilmourn_obituary_scribes",
]
const GRAND_CONVERGENCE_SPELL_IDS := [
	"spell_beacon_path", "spell_bloodwake_drum", "spell_briar_bind", "spell_bulwark_litany", "spell_coal_rain",
	"spell_fogwake_step", "spell_graft_mend", "spell_pressure_clause", "spell_prism_bastion", "spell_relay_drum",
	"spell_resonant_chorus", "spell_stone_veil", "spell_sunlance_arc", "spell_trailglyph", "spell_waystride",
]
const CASES := [
	{"scenario_id":"rainledger-cinder-convergence","hero_id":"hero_embercourt_belis_rainledger","faction_id":"faction_embercourt","placement_id":"rainledger_charcoal_burners_watch","encounter_id":"encounter_charcoal_burners_watch","army_group_id":"army_neutral_charcoal_burners_watch","player_army_group_id":"army_belis_grand_convergence_company","spell_ids":["spell_trailglyph","spell_stone_veil","spell_bulwark_litany"],"rare_resource_id":"embergrain","victory_flag":"rainledger_charcoal_burners_watch_secured","objective_id":"charcoal_burners_hold","asset_id":"encounter_grand_convergence_charcoal_burners_watch","region":Rect2(0,0,48,48),"combat_seed":26306,"expected_gold":120,"expected_rare":1},
	{"scenario_id":"fenwake-bogbell-convergence","hero_id":"hero_mireclaw_zhorra_fenwake","faction_id":"faction_mireclaw","placement_id":"fenwake_bogbell_croft_watch","encounter_id":"encounter_bogbell_croft_watch","army_group_id":"army_neutral_bogbell_croft_watch","player_army_group_id":"army_zhorra_grand_convergence_company","spell_ids":["spell_relay_drum","spell_bloodwake_drum","spell_coal_rain"],"rare_resource_id":"peatwax","victory_flag":"fenwake_bogbell_croft_watch_secured","objective_id":"bogbell_croft_hold","asset_id":"encounter_grand_convergence_bogbell_croft_watch","region":Rect2(48,0,48,48),"combat_seed":26316,"expected_gold":110,"expected_rare":1},
	{"scenario_id":"halometer-icehook-convergence","hero_id":"hero_sunvault_mirro_halometer","faction_id":"faction_sunvault","placement_id":"halometer_icehook_trapper_lodge_watch","encounter_id":"encounter_icehook_trapper_lodge_watch","army_group_id":"army_neutral_icehook_trapper_lodge_watch","player_army_group_id":"army_mirro_grand_convergence_company","spell_ids":["spell_sunlance_arc","spell_resonant_chorus","spell_beacon_path"],"rare_resource_id":"aetherglass","victory_flag":"halometer_icehook_trapper_lodge_watch_secured","objective_id":"icehook_trapper_lodge_hold","asset_id":"encounter_grand_convergence_icehook_trapper_lodge_watch","region":Rect2(96,0,48,48),"combat_seed":26326,"expected_gold":110,"expected_rare":1},
	{"scenario_id":"graftsibyl-lantern-convergence","hero_id":"hero_thornwake_nara_graftsibyl","faction_id":"faction_thornwake","placement_id":"graftsibyl_lantern_warren_watch","encounter_id":"encounter_lantern_warren_watch","army_group_id":"army_neutral_lantern_warren_watch","player_army_group_id":"army_nara_grand_convergence_company","spell_ids":["spell_graft_mend","spell_briar_bind","spell_prism_bastion"],"rare_resource_id":"verdant_grafts","victory_flag":"graftsibyl_lantern_warren_watch_secured","objective_id":"lantern_warren_hold","asset_id":"encounter_grand_convergence_lantern_warren_watch","region":Rect2(144,0,48,48),"combat_seed":26336,"expected_gold":120,"expected_rare":1},
	{"scenario_id":"debtrune-default-convergence","hero_id":"hero_brasshollow_harro_debtrune","faction_id":"faction_brasshollow","placement_id":"debtrune_default_collectors","encounter_id":"encounter_debtrune_default_collectors","army_group_id":"army_debtrune_default_collectors","player_army_group_id":"army_harro_grand_convergence_company","spell_ids":["spell_pressure_clause","spell_briar_bind","spell_stone_veil"],"rare_resource_id":"brass_scrip","victory_flag":"debtrune_default_collectors_secured","objective_id":"debtrune_writ_press","asset_id":"encounter_grand_convergence_default_clause_collectors","region":Rect2(192,0,48,48),"combat_seed":26346,"expected_gold":180,"expected_rare":2},
	{"scenario_id":"nightchart-meridian-convergence","hero_id":"hero_veilmourn_orso_nightchart","faction_id":"faction_veilmourn","placement_id":"nightchart_false_meridian","encounter_id":"encounter_nightchart_false_meridian","army_group_id":"army_nightchart_false_meridian_pilots","player_army_group_id":"army_orso_grand_convergence_company","spell_ids":["spell_fogwake_step","spell_waystride","spell_beacon_path"],"rare_resource_id":"memory_salt","victory_flag":"nightchart_false_meridian_secured","objective_id":"nightchart_false_beacon","asset_id":"encounter_grand_convergence_false_meridian_pilots","region":Rect2(240,0,48,48),"combat_seed":26356,"expected_gold":180,"expected_rare":2},
]

var _errors: Array[String] = []
var _rows: Array = []
var _player_unit_ids := {}
var _enemy_unit_ids := {}
var _spell_ids := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		print("%s CASE_START %s" % [REPORT_ID, String(case_value.get("scenario_id", ""))])
		await _validate_case(view, case_value)
		print("%s CASE_DONE %s" % [REPORT_ID, String(case_value.get("scenario_id", ""))])
	_expect(_player_unit_ids.size() == GRAND_CONVERGENCE_PLAYER_UNIT_IDS.size(), "All thirty selected faction units must appear in live five-stack companies.")
	_expect(_enemy_unit_ids.size() == GRAND_CONVERGENCE_PRIMARY_UNIT_IDS.size(), "All fourteen primary-front units must appear in live enemy companies.")
	_expect(_spell_ids.size() == GRAND_CONVERGENCE_SPELL_IDS.size(), "The six final command heroes must expose the exact fifteen-spell union.")
	for unit_id in GRAND_CONVERGENCE_PLAYER_UNIT_IDS:
		_expect(_player_unit_ids.has(unit_id), "%s did not reach a live player battle side." % unit_id)
	for unit_id in GRAND_CONVERGENCE_PRIMARY_UNIT_IDS:
		_expect(_enemy_unit_ids.has(unit_id), "%s did not reach a live primary-front battle side." % unit_id)
	for spell_id in GRAND_CONVERGENCE_SPELL_IDS:
		_expect(_spell_ids.has(spell_id), "%s did not reach live hero and battle spellbooks." % spell_id)
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"player_unit_id_count":GRAND_CONVERGENCE_PLAYER_UNIT_IDS.size(),"primary_unit_id_count":GRAND_CONVERGENCE_PRIMARY_UNIT_IDS.size(),"spell_id_count":GRAND_CONVERGENCE_SPELL_IDS.size(),"atlas_path":ATLAS_PATH,"atlas_size":[288,48],"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"spell_id_count":GRAND_CONVERGENCE_SPELL_IDS.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var encounter_id := String(case.get("encounter_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	print("%s STAGE scenario_loaded %s" % [REPORT_ID, scenario_id])
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	var scenario_objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	_expect(bool(availability.get("skirmish", false)) and not bool(availability.get("campaign", true)), "%s must remain skirmish-only." % scenario_id)
	_expect(String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")) and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")), "%s lost its selected hero or faction." % scenario_id)
	_expect(int(map_size.get("width", 0)) == 14 and int(map_size.get("height", 0)) == 9 and (scenario.get("towns", []) as Array).size() == 2 and (scenario.get("resource_nodes", []) as Array).size() == 17 and (scenario.get("artifact_nodes", []) as Array).size() == 6 and (scenario.get("encounters", []) as Array).size() == 7 and (scenario.get("script_hooks", []) as Array).size() == 8 and (scenario_objectives.get("victory", []) as Array).size() == 7, "%s lost its guarded-relic 14x9 grand-convergence contract." % scenario_id)

	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var hero_spells: Array = hero.get("spellbook", {}).get("known_spell_ids", []) if hero.get("spellbook", {}) is Dictionary else []
	_expect(String(session.overworld.get("active_hero_id", "")) == String(case.get("hero_id", "")) and _string_set(hero_spells) == _string_set(case.get("spell_ids", [])), "%s did not construct the exact final-command spellbook." % scenario_id)
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		_error("%s is missing live placement %s." % [scenario_id, placement_id])
		return
	_expect(String(encounter.get("encounter_id", "")) == encounter_id and int(encounter.get("combat_seed", 0)) == int(case.get("combat_seed", -1)) and bool(encounter.get("prefer_identity_landmark", false)), "%s lost its exact encounter, seed, or landmark preference." % placement_id)

	var definition := ContentService.get_encounter(encounter_id)
	var army_group := ContentService.get_army_group(String(case.get("army_group_id", "")))
	var player_army_group := ContentService.get_army_group(String(case.get("player_army_group_id", "")))
	var objectives: Array = definition.get("field_objectives", []) if definition.get("field_objectives", []) is Array else []
	_expect(String(definition.get("enemy_group_id", "")) == String(case.get("army_group_id", "")) and objectives.size() == 1 and String(objectives[0].get("id", "")) == String(case.get("objective_id", "")), "%s lost its army or tactical objective." % encounter_id)

	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var identity: Dictionary = view.call("validation_encounter_presentation_payload", encounter)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(identity.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and bool(identity.get("uses_identity_encounter_sprite", false)) and not bool(identity.get("uses_commander_sprite", true)) and texture is AtlasTexture and texture.region == case.get("region", Rect2()) and texture.atlas is Texture2D and texture.atlas.resource_path == ATLAS_PATH and texture.atlas.get_size() == Vector2(288, 48)
	_expect(exact_art, "%s exact landmark did not reach the live map renderer." % encounter_id)
	var capture_path := await _capture_if_requested(scenario_id)

	var first := _clone_session(session)
	var second := _clone_session(session)
	var resources_before := _resource_snapshot(first)
	var battle := BattleRulesScript.create_battle_payload(first, _encounter(first, placement_id))
	var mirrored_battle := BattleRulesScript.create_battle_payload(second, _encounter(second, placement_id))
	_expect(not battle.is_empty() and not mirrored_battle.is_empty(), "%s did not construct a production battle." % encounter_id)
	if battle.is_empty() or mirrored_battle.is_empty():
		return
	_expect(_side_counts(battle, "enemy") == _army_counts(army_group), "%s enemy stacks diverged from the authored group." % encounter_id)
	_expect(_side_counts(battle, "player") == _army_counts(player_army_group), "%s player stacks diverged from the authored five-stack company." % scenario_id)
	var commander_spells: Array = battle.get("player_commander_state", {}).get("spellbook", {}).get("known_spell_ids", [])
	_expect(_string_set(commander_spells) == _string_set(case.get("spell_ids", [])), "%s starting spells did not reach the production battle commander." % scenario_id)
	for spell_id in commander_spells:
		_spell_ids[String(spell_id)] = true
	_record_battle_units(battle)
	first.battle = battle
	second.battle = mirrored_battle
	first.game_state = "battle"
	second.game_state = "battle"
	first.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	second.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var first_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(first)
	var second_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(second)
	var deterministic := first_result == second_result and JSON.stringify(first.to_dict()) == JSON.stringify(second.to_dict())
	_expect(bool(first_result.get("completed", false)) and String(first_result.get("state", "")) == "victory", "%s did not resolve as a viable medium boss: %s" % [encounter_id, first_result])
	_expect(deterministic, "%s fixed-seed battle was non-deterministic." % encounter_id)
	if String(first_result.get("state", "")) != "victory":
		return
	var resources_after := _resource_snapshot(first)
	var rare_id := String(case.get("rare_resource_id", ""))
	var gold_delta := int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0))
	var rare_delta := int(resources_after.get(rare_id, 0)) - int(resources_before.get(rare_id, 0))
	_expect(gold_delta == int(case.get("expected_gold", -1)) and rare_delta == int(case.get("expected_rare", -1)), "%s reward delta changed: gold=%d %s=%d." % [encounter_id, gold_delta, rare_id, rare_delta])
	_expect(placement_id in first.overworld.get("resolved_encounters", []) and bool(first.flags.get(String(case.get("victory_flag", "")), false)), "%s did not persist resolution and secured state." % encounter_id)
	var restored := _clone_session(first)
	_expect(int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == first.to_dict(), "%s did not round-trip through save version %d." % [encounter_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"hero_id":String(case.get("hero_id", "")),"encounter_id":encounter_id,"army_group_id":String(case.get("army_group_id", "")),"field_objective_id":String(case.get("objective_id", "")),"spell_ids":commander_spells,"capture_path":capture_path,"gold_delta":gold_delta,"rare_resource_delta":rare_delta,"deterministic":deterministic,"save_round_trip_exact":restored.to_dict() == first.to_dict()})

func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("GRAND_CONVERGENCE_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_error("Could not save visual capture %s." % path)
		return ""
	return path

func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}

func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone

func _resource_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	return resources.duplicate(true)

func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _army_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts

func _side_counts(battle: Dictionary, side: String) -> Dictionary:
	var counts := {}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != side:
			continue
		var unit_hp: int = max(1, int(stack.get("unit_hp", 1)))
		counts[String(stack.get("unit_id", ""))] = int(ceil(float(max(0, int(stack.get("total_health", 0)))) / float(unit_hp)))
	return counts

func _record_battle_units(battle: Dictionary) -> void:
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var unit_id := String(stack.get("unit_id", ""))
		if String(stack.get("side", "")) == "player":
			_player_unit_ids[unit_id] = true
		elif String(stack.get("side", "")) == "enemy":
			_enemy_unit_ids[unit_id] = true

func _string_set(values) -> Dictionary:
	var result := {}
	if values is Array:
		for value in values:
			result[String(value)] = true
	return result

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
