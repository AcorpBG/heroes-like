extends "res://tests/eight_neutral_dwelling_musters_report.gd"

const BATCH_REPORT_ID := "UNBOUND_WILD_CONCORDS_SMOKE"
const BATCH_OUTPUT_DIR := "res://.artifacts/unbound_wild_concords_smoke"
const BATCH_ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/unbound_wild_concords_atlas.png"
const CONTENT_BATCH_ID := "content-six-unbound-wild-concords-10184"
const BATCH_CASES := [
	{"scenario_id":"pikeward-brambleback-concord","site_id":"site_brambleback_hedgecourt","placement_id":"brambleconcord_dwelling","guard_id":"brambleconcord_dwelling_guard","encounter_id":"encounter_brambleback_hedgecourt_watch","unit_ids":["unit_neutral_brambleback_knucklebears","unit_neutral_orchard_halberds"],"unclaimed":"mapobj_brambleback_hedgecourt","claimed":"resource_site_neutral_brambleback_hedgecourt_controlled","identity_asset_id":"encounter_unbound_wild_brambleback_hedgecourt_watch","region":Rect2(48,0,48,48)},
	{"scenario_id":"mudkeel-mireglass-concord","site_id":"site_mireglass_bellfen","placement_id":"mireglassconcord_dwelling","guard_id":"mireglassconcord_dwelling_guard","encounter_id":"encounter_mireglass_bellfen_watch","unit_ids":["unit_neutral_mireglass_belltoads","unit_neutral_reedbarge_poles"],"unclaimed":"mapobj_mireglass_bellfen","claimed":"resource_site_neutral_mireglass_bellfen_controlled","identity_asset_id":"encounter_unbound_wild_mireglass_bellfen_watch","region":Rect2(144,0,48,48)},
	{"scenario_id":"daynote-windcairn-concord","site_id":"site_windcairn_wayhouse","placement_id":"windcairnconcord_dwelling","guard_id":"windcairnconcord_dwelling_guard","encounter_id":"encounter_windcairn_wayhouse_watch","unit_ids":["unit_neutral_cairnshield_porters","unit_neutral_windglass_slingers"],"unclaimed":"mapobj_windcairn_wayhouse","claimed":"resource_site_neutral_windcairn_wayhouse_controlled","identity_asset_id":"encounter_unbound_wild_windcairn_wayhouse_watch","region":Rect2(240,0,48,48)},
	{"scenario_id":"thorncart-greenbranch-concord","site_id":"site_sapwhistle_greenward","placement_id":"greenbranchconcord_dwelling","guard_id":"greenbranchconcord_dwelling_guard","encounter_id":"encounter_sapwhistle_greenward_watch","unit_ids":["unit_neutral_greenbranch_cudgels","unit_neutral_sapwhistle_callers"],"unclaimed":"mapobj_sapwhistle_greenward","claimed":"resource_site_neutral_sapwhistle_greenward_controlled","identity_asset_id":"encounter_unbound_wild_sapwhistle_greenward_watch","region":Rect2(336,0,48,48)},
	{"scenario_id":"varn-scarshield-concord","site_id":"site_scarshield_breakyard","placement_id":"scarshieldconcord_dwelling","guard_id":"scarshieldconcord_dwelling_guard","encounter_id":"encounter_scarshield_breakyard_watch","unit_ids":["unit_neutral_scarshield_veterans","unit_neutral_scrapbow_teams"],"unclaimed":"mapobj_scarshield_breakyard","claimed":"resource_site_neutral_scarshield_breakyard_controlled","identity_asset_id":"encounter_unbound_wild_scarshield_breakyard_watch","region":Rect2(432,0,48,48)},
	{"scenario_id":"mistcorsair-flaremast-concord","site_id":"site_flaremast_pilotage","placement_id":"flaremastconcord_dwelling","guard_id":"flaremastconcord_dwelling_guard","encounter_id":"encounter_flaremast_pilotage_watch","unit_ids":["unit_neutral_harbor_polearms","unit_neutral_flaremast_crews"],"unclaimed":"mapobj_flaremast_pilotage","claimed":"resource_site_neutral_flaremast_pilotage_controlled","identity_asset_id":"encounter_unbound_wild_flaremast_pilotage_watch","region":Rect2(528,0,48,48)},
]

var _audio_runtime_validated := false


func _validate_case(view: Control, case: Dictionary) -> void:
	await super._validate_case(view, case)
	var scenario_id := String(case.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	_expect(String(scenario.get("content_batch_id", "")) == CONTENT_BATCH_ID, "%s lost its content-batch identity." % scenario_id)
	var map_size: Dictionary = scenario.get("map_size", {})
	_expect(int(map_size.get("width", 0)) == 14 and int(map_size.get("height", 0)) == 9, "%s map size changed." % scenario_id)
	_expect(scenario.get("encounters", []).size() == 3 and scenario.get("script_hooks", []).size() == 5, "%s lost its three-battle, five-hook route." % scenario_id)

	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var battle_payload_count := 0
	var combat_seeds := {}
	for placement_value in session.overworld.get("encounters", []):
		if not (placement_value is Dictionary):
			continue
		var placement: Dictionary = placement_value
		var battle := BattleRules.create_battle_payload(session, placement)
		_expect(not battle.is_empty(), "%s could not construct battle %s." % [scenario_id, String(placement.get("placement_id", ""))])
		battle_payload_count += 1 if not battle.is_empty() else 0
		combat_seeds[int(placement.get("combat_seed", -1))] = true
		_resolve_guard(session, String(placement.get("placement_id", "")))
	_expect(battle_payload_count == 3 and combat_seeds.size() == 3, "%s did not retain three independently seeded production battles." % scenario_id)

	var guard := _encounter(session, String(case.get("guard_id", "")))
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", guard)
	var primary_unit_id := String(case.get("unit_ids", [""])[0])
	var primary_art := ContentService.get_unit_art(primary_unit_id)
	_expect(String(presentation.get("identity_encounter_asset_id", "")) == String(case.get("identity_asset_id", "")) and String(presentation.get("identity_encounter_path", "")) == String(primary_art.get("overworld_icon", "")) and bool(presentation.get("uses_identity_encounter_sprite", false)), "%s lost its exact guard-company identity art." % scenario_id)

	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, String(case.get("placement_id", ""))), true)
	_expect(bool(claim.get("ok", false)), "%s could not claim its concord after all three battles." % scenario_id)
	var victory_objectives: Array = scenario.get("objectives", {}).get("victory", [])
	var army_objective_id := String(victory_objectives[0].get("id", "")) if not victory_objectives.is_empty() else ""
	var army_objective_met := ScenarioRules.is_objective_met(session, army_objective_id, "victory")
	var outcome := ScenarioRules.evaluate_session(session)
	_expect(army_objective_met and String(outcome.get("status", "")) == "victory", "%s did not reach victory after both companies assembled and all guards cleared: %s" % [scenario_id, JSON.stringify(outcome)])

	for unit_id_value in case.get("unit_ids", []):
		var unit_id := String(unit_id_value)
		var art := ContentService.get_unit_art(unit_id)
		_expect(not ContentService.get_unit(unit_id).is_empty(), "%s is missing from live content." % unit_id)
		for art_key in ["portrait", "battle_icon", "battle_standee", "overworld_icon"]:
			var art_path := String(art.get(art_key, ""))
			_expect(art_path != "" and load(art_path) is Texture2D, "%s lost its %s runtime art." % [unit_id, art_key])

	if not _audio_runtime_validated:
		_validate_ogg_runtime(session)
		_audio_runtime_validated = true
	if not _rows.is_empty():
		_rows[-1]["battle_payload_count"] = battle_payload_count
		_rows[-1]["army_objective_met"] = army_objective_met
		_rows[-1]["scenario_victory"] = String(outcome.get("status", "")) == "victory"
		_rows[-1]["exact_identity_art"] = bool(presentation.get("uses_identity_encounter_sprite", false))
		_rows[-1]["unit_ids"] = case.get("unit_ids", []).duplicate()
		_rows[-1]["audio_runtime_validated"] = _audio_runtime_validated


func _validate_ogg_runtime(session: SessionStateStoreScript.SessionData) -> void:
	var manifests := [
		{"path":"res://content/music_runtime_manifest.json","count":75,"duration":8000},
		{"path":"res://content/ambient_sfx_manifest.json","count":11,"duration":12000},
	]
	for spec_value in manifests:
		var spec: Dictionary = spec_value
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(spec.get("path", ""))))
		_expect(parsed is Dictionary, "%s did not parse." % String(spec.get("path", "")))
		if not (parsed is Dictionary):
			continue
		var manifest: Dictionary = parsed
		var cues: Dictionary = manifest.get("cues", {})
		_expect(manifest.get("runtime_codec") == "vorbis" and manifest.get("runtime_container") == "ogg" and int(manifest.get("encoder_quality", -1)) == 4, "%s lost its Vorbis q4 runtime contract." % String(spec.get("path", "")))
		_expect(cues.size() == int(spec.get("count", 0)), "%s cue count changed." % String(spec.get("path", "")))
		for cue_value in cues.values():
			var cue: Dictionary = cue_value
			var asset_path := String(cue.get("path", ""))
			_expect(asset_path.ends_with(".ogg") and int(cue.get("duration_msec", 0)) == int(spec.get("duration", 0)) and load(asset_path) is AudioStreamOggVorbis, "%s is not an imported production OGG cue." % asset_path)

	MusicAudio.validation_reset()
	var music_record: Dictionary = MusicAudio.sync_context("menu", "unbound_wild_concords_smoke", {"scenario_id":String(session.scenario_id)})
	_expect(int(music_record.get("layer_count", 0)) == 3 and _all_layers_use_ogg(music_record.get("layers", [])), "MusicAudio did not play all three menu layers from imported Vorbis.")
	MusicAudio.validation_reset()
	AmbientAudio.validation_reset()
	var ambient_record: Dictionary = AmbientAudio.sync_overworld_session(session, "unbound_wild_concords_smoke")
	_expect(int(ambient_record.get("layer_count", 0)) >= 1 and _all_layers_use_ogg(ambient_record.get("layers", [])), "AmbientAudio did not play the overworld layer from imported Vorbis.")
	AmbientAudio.validation_reset()


func _all_layers_use_ogg(layers: Variant) -> bool:
	if not (layers is Array) or layers.is_empty():
		return false
	for layer_value in layers:
		if not (layer_value is Dictionary):
			return false
		var layer: Dictionary = layer_value
		if String(layer.get("playback_source", "")) != "imported_ogg" or String(layer.get("stream_codec", "")) != "vorbis" or int(layer.get("mix_rate", 0)) != 44100 or not bool(layer.get("stereo", false)):
			return false
	return true


func _report_id() -> String:
	return BATCH_REPORT_ID


func _output_dir() -> String:
	return BATCH_OUTPUT_DIR


func _atlas_path() -> String:
	return BATCH_ATLAS_PATH


func _capture_environment_name() -> String:
	return "UNBOUND_WILD_CONCORD_CAPTURE_DIR"


func _cases() -> Array:
	return BATCH_CASES
