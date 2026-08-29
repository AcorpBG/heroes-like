extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_FACTION_SPELLWRIGHT_EXPEDITIONS_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_faction_spellwright_expeditions_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/spellwright_expeditions/spellwright_expeditions_atlas.png"
const SPELLWRIGHT_PLAYER_UNIT_IDS := [
	"unit_embercourt_beacon_lectors", "unit_embercourt_ash_oath_bailiffs", "unit_embercourt_sluicefire_lindworms",
	"unit_mireclaw_sporewake_chanters", "unit_mireclaw_ferrychain_lashers", "unit_mireclaw_gorefen_rippers",
	"unit_sunvault_resonant_choristers", "unit_sunvault_solar_array_striders", "unit_sunvault_daybreak_colossus",
	"unit_thornwake_sporeglass_menders", "unit_thornwake_barkmantle_rams", "unit_thornwake_graft_matriarchs",
	"unit_brasshollow_boiler_rivetcasters", "unit_brasshollow_debt_engine_exactors", "unit_brasshollow_crucible_crawlers",
	"unit_veilmourn_undertow_harpooners", "unit_veilmourn_obituary_scribes", "unit_veilmourn_mirrorkeel_reavers",
]
const SPELLWRIGHT_NEUTRAL_UNIT_IDS := [
	"unit_neutral_fenhound_runners", "unit_neutral_mossglass_sentinels",
	"unit_neutral_glowcap_bulwarks", "unit_neutral_sporelamp_tossers",
	"unit_neutral_kitehook_runners", "unit_neutral_ridgeflare_shots",
	"unit_neutral_orchard_halberds", "unit_neutral_millstone_slingers",
	"unit_neutral_milestone_bucklers", "unit_neutral_cartbow_tenders",
	"unit_neutral_harbor_polearms", "unit_neutral_flaremast_crews",
]
const SPELLWRIGHT_SPELL_IDS := [
	"spell_beacon_path", "spell_bloodwake_drum", "spell_briar_bind", "spell_cinder_burst", "spell_coal_rain",
	"spell_fogwake_step", "spell_graft_mend", "spell_heat_rite", "spell_obituary_mark", "spell_pressure_clause",
	"spell_prism_bastion", "spell_resonant_chorus", "spell_stone_veil", "spell_sunlance_arc",
]
const CASES := [
	{"scenario_id":"cinderquill-fenhound-lexicon","hero_id":"hero_embercourt_orra_cinderquill","faction_id":"faction_embercourt","placement_id":"cinderquill_fenhound_kennel_watch","encounter_id":"encounter_fenhound_kennel_watch","army_group_id":"army_neutral_fenhound_kennel_watch","player_army_group_id":"army_orra_spellwright_cadre","spell_ids":["spell_cinder_burst","spell_coal_rain","spell_beacon_path"],"rare_resource_id":"embergrain","victory_flag":"cinderquill_fenhound_kennel_watch_secured","objective_id":"kennel_mire_run","asset_id":"encounter_spellwright_fenhound_kennel_watch","region":Rect2(0,0,48,48),"combat_seed":26104,"expected_gold":100},
	{"scenario_id":"rotlamp-glowcap-refrain","hero_id":"hero_mireclaw_edda_rotlamp","faction_id":"faction_mireclaw","placement_id":"rotlamp_glowcap_croft_watch","encounter_id":"encounter_glowcap_croft_watch","army_group_id":"army_neutral_glowcap_croft_watch","player_army_group_id":"army_edda_spellwright_cadre","spell_ids":["spell_coal_rain","spell_stone_veil","spell_bloodwake_drum"],"rare_resource_id":"peatwax","victory_flag":"rotlamp_glowcap_croft_watch_secured","objective_id":"glowcap_croft_hold","asset_id":"encounter_spellwright_glowcap_croft_watch","region":Rect2(48,0,48,48),"combat_seed":26114,"expected_gold":120},
	{"scenario_id":"daynote-kite-signal-accord","hero_id":"hero_sunvault_essa_daynote","faction_id":"faction_sunvault","placement_id":"daynote_kite_signal_eyrie_watch","encounter_id":"encounter_kite_signal_eyrie_watch","army_group_id":"army_neutral_kite_signal_eyrie_watch","player_army_group_id":"army_essa_spellwright_cadre","spell_ids":["spell_resonant_chorus","spell_prism_bastion","spell_sunlance_arc"],"rare_resource_id":"aetherglass","victory_flag":"daynote_kite_signal_eyrie_watch_secured","objective_id":"kite_signal_eyrie_hold","asset_id":"encounter_spellwright_kite_signal_eyrie_watch","region":Rect2(96,0,48,48),"combat_seed":26124,"expected_gold":120},
	{"scenario_id":"loamchant-orchard-binding","hero_id":"hero_thornwake_elian_loamchant","faction_id":"faction_thornwake","placement_id":"loamchant_orchard_levy_watch","encounter_id":"encounter_orchard_levy_watch","army_group_id":"army_neutral_orchard_levy_watch","player_army_group_id":"army_elian_spellwright_cadre","spell_ids":["spell_briar_bind","spell_coal_rain","spell_graft_mend"],"rare_resource_id":"verdant_grafts","victory_flag":"loamchant_orchard_levy_watch_secured","objective_id":"orchard_levy_hold","asset_id":"encounter_spellwright_orchard_levy_watch","region":Rect2(144,0,48,48),"combat_seed":26134,"expected_gold":100},
	{"scenario_id":"gaugesavant-milestone-calibration","hero_id":"hero_brasshollow_lina_gaugesavant","faction_id":"faction_brasshollow","placement_id":"gaugesavant_milestone_arsenal_watch","encounter_id":"encounter_milestone_arsenal_watch","army_group_id":"army_neutral_milestone_arsenal_watch","player_army_group_id":"army_lina_spellwright_cadre","spell_ids":["spell_pressure_clause","spell_heat_rite","spell_resonant_chorus"],"rare_resource_id":"brass_scrip","victory_flag":"gaugesavant_milestone_arsenal_watch_secured","objective_id":"milestone_arsenal_hold","asset_id":"encounter_spellwright_milestone_arsenal_watch","region":Rect2(192,0,48,48),"combat_seed":26144,"expected_gold":100},
	{"scenario_id":"mirrorbell-harbor-echo","hero_id":"hero_veilmourn_sael_mirrorbell","faction_id":"faction_veilmourn","placement_id":"mirrorbell_harbor_pilot_house_watch","encounter_id":"encounter_harbor_pilot_house_watch","army_group_id":"army_neutral_harbor_pilot_house_watch","player_army_group_id":"army_sael_spellwright_cadre","spell_ids":["spell_fogwake_step","spell_obituary_mark","spell_resonant_chorus"],"rare_resource_id":"memory_salt","victory_flag":"mirrorbell_harbor_pilot_house_watch_secured","objective_id":"harbor_pilot_house_hold","asset_id":"encounter_spellwright_harbor_pilot_house_watch","region":Rect2(240,0,48,48),"combat_seed":26154,"expected_gold":120},
]

var _errors: Array[String] = []
var _rows: Array = []
var _player_unit_ids: Dictionary = {}
var _enemy_unit_ids: Dictionary = {}
var _spell_ids: Dictionary = {}

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
	_expect(_player_unit_ids.size() == SPELLWRIGHT_PLAYER_UNIT_IDS.size(), "All eighteen selected faction units must appear in live player cadres.")
	_expect(_enemy_unit_ids.size() == SPELLWRIGHT_NEUTRAL_UNIT_IDS.size(), "All twelve dormant watch units must appear in live enemy companies.")
	_expect(_spell_ids.size() == SPELLWRIGHT_SPELL_IDS.size(), "The six live spellwrights must expose the exact fourteen-spell union.")
	for unit_id in SPELLWRIGHT_PLAYER_UNIT_IDS:
		_expect(_player_unit_ids.has(unit_id), "%s did not reach a live player battle side." % unit_id)
	for unit_id in SPELLWRIGHT_NEUTRAL_UNIT_IDS:
		_expect(_enemy_unit_ids.has(unit_id), "%s did not reach a live neutral-watch battle side." % unit_id)
	for spell_id in SPELLWRIGHT_SPELL_IDS:
		_expect(_spell_ids.has(spell_id), "%s did not reach live hero and battle spellbooks." % spell_id)
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"player_unit_id_count":SPELLWRIGHT_PLAYER_UNIT_IDS.size(),"neutral_unit_id_count":SPELLWRIGHT_NEUTRAL_UNIT_IDS.size(),"spell_id_count":SPELLWRIGHT_SPELL_IDS.size(),"atlas_path":ATLAS_PATH,"atlas_size":[288,48],"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"spell_id_count":SPELLWRIGHT_SPELL_IDS.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
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
	_expect(bool(availability.get("skirmish", false)) and not bool(availability.get("campaign", true)), "%s must remain skirmish-only." % scenario_id)
	_expect(String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")) and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")), "%s lost its selected hero or faction." % scenario_id)
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	var scenario_objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	_expect(int(map_size.get("width", 0)) == 12 and int(map_size.get("height", 0)) == 7 and (scenario.get("towns", []) as Array).size() == 2 and (scenario.get("resource_nodes", []) as Array).size() == 12 and (scenario.get("artifact_nodes", []) as Array).size() == 4 and (scenario.get("encounters", []) as Array).size() == 4 and (scenario.get("script_hooks", []) as Array).size() == 6 and (scenario_objectives.get("victory", []) as Array).size() == 5, "%s lost its complete 12x7 expedition contract." % scenario_id)

	print("%s STAGE session_create_start %s" % [REPORT_ID, scenario_id])
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	print("%s STAGE session_create_done %s" % [REPORT_ID, scenario_id])
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var hero_spells: Array = hero.get("spellbook", {}).get("known_spell_ids", []) if hero.get("spellbook", {}) is Dictionary else []
	_expect(String(session.overworld.get("active_hero_id", "")) == String(case.get("hero_id", "")) and _string_set(hero_spells) == _string_set(case.get("spell_ids", [])), "%s did not construct the exact spellwright hero spellbook." % scenario_id)
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		_error("%s is missing live placement %s." % [scenario_id, placement_id])
		return
	_expect(String(encounter.get("encounter_id", "")) == encounter_id and int(encounter.get("combat_seed", 0)) == int(case.get("combat_seed", -1)), "%s resolves the wrong encounter or seed." % placement_id)
	_expect(bool(encounter.get("prefer_identity_landmark", false)), "%s lost exact-landmark preference." % placement_id)

	var definition := ContentService.get_encounter(encounter_id)
	var army_group := ContentService.get_army_group(String(case.get("army_group_id", "")))
	var player_army_group := ContentService.get_army_group(String(case.get("player_army_group_id", "")))
	_expect(String(definition.get("enemy_group_id", "")) == String(case.get("army_group_id", "")), "%s lost its army owner." % encounter_id)
	var objectives: Array = definition.get("field_objectives", []) if definition.get("field_objectives", []) is Array else []
	_expect(objectives.size() == 1 and String(objectives[0].get("id", "")) == String(case.get("objective_id", "")), "%s lost its tactical objective." % encounter_id)

	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	print("%s STAGE map_rendered %s" % [REPORT_ID, scenario_id])
	var identity: Dictionary = view.call("validation_encounter_presentation_payload", encounter)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(identity.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and bool(identity.get("uses_identity_encounter_sprite", false)) and not bool(identity.get("uses_commander_sprite", true)) and texture is AtlasTexture and texture.region == case.get("region", Rect2()) and texture.atlas is Texture2D and texture.atlas.resource_path == ATLAS_PATH and texture.atlas.get_size() == Vector2(288, 48)
	_expect(exact_art, "%s exact landmark did not reach the live map renderer." % encounter_id)
	var capture_path := await _capture_if_requested(scenario_id)
	print("%s STAGE capture_done %s" % [REPORT_ID, scenario_id])

	var first := _clone_session(session)
	var second := _clone_session(session)
	var resources_before := _resource_snapshot(first)
	var battle := BattleRulesScript.create_battle_payload(first, _encounter(first, placement_id))
	var mirrored_battle := BattleRulesScript.create_battle_payload(second, _encounter(second, placement_id))
	_expect(not battle.is_empty() and not mirrored_battle.is_empty(), "%s did not construct a production battle." % encounter_id)
	if battle.is_empty() or mirrored_battle.is_empty():
		return
	_expect(_side_counts(battle, "enemy") == _army_counts(army_group), "%s enemy battle stacks diverged from its authored group." % encounter_id)
	_expect(_side_counts(battle, "player") == _army_counts(player_army_group), "%s player battle stacks diverged from its authored spellwright cadre." % scenario_id)
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
	print("%s STAGE battle_resolve_start %s" % [REPORT_ID, scenario_id])
	var first_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(first)
	var second_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(second)
	print("%s STAGE battle_resolve_done %s" % [REPORT_ID, scenario_id])
	var deterministic := first_result == second_result and JSON.stringify(first.to_dict()) == JSON.stringify(second.to_dict())
	_expect(bool(first_result.get("completed", false)) and String(first_result.get("state", "")) == "victory", "%s did not resolve as a viable medium boss: %s" % [encounter_id, first_result])
	_expect(deterministic, "%s fixed-seed battle was non-deterministic." % encounter_id)
	if String(first_result.get("state", "")) != "victory":
		return
	var resources_after := _resource_snapshot(first)
	var rare_id := String(case.get("rare_resource_id", ""))
	var gold_delta := int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0))
	var rare_delta := int(resources_after.get(rare_id, 0)) - int(resources_before.get(rare_id, 0))
	_expect(gold_delta == int(case.get("expected_gold", -1)) and rare_delta == 1, "%s reward delta changed: gold=%d %s=%d." % [encounter_id, gold_delta, rare_id, rare_delta])
	_expect(placement_id in first.overworld.get("resolved_encounters", []) and bool(first.flags.get(String(case.get("victory_flag", "")), false)), "%s did not persist resolution and victory state." % encounter_id)
	var restored := _clone_session(first)
	_expect(int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == first.to_dict(), "%s did not round-trip through save version %d." % [encounter_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"hero_id":String(case.get("hero_id", "")),"encounter_id":encounter_id,"army_group_id":String(case.get("army_group_id", "")),"field_objective_id":String(case.get("objective_id", "")),"spell_ids":commander_spells,"capture_path":capture_path,"gold_delta":gold_delta,"rare_resource_delta":rare_delta,"deterministic":deterministic,"save_round_trip_exact":restored.to_dict() == first.to_dict()})

func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("SPELLWRIGHT_EXPEDITION_CAPTURE_DIR")
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
