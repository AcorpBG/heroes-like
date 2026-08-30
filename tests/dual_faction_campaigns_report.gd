extends Node

const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "DUAL_FACTION_CAMPAIGNS_REPORT"
const OUTPUT_DIR := "res://.artifacts/dual_faction_campaigns_report"
const CAMPAIGNS := [
	{
		"campaign_id":"campaign_ashen_ledger", "hero_id":"hero_brasshollow_daxis_chaincaptain", "army_id":"army_daxis_chaincaptain_train", "faction_id":"faction_brasshollow",
		"chapters":[
			{"scenario_id":"cindercoil-reclamation","size":Vector2i(14,8),"flag":"cindercoil_furnace_rekindled","player_town":"town_brasshollow_orevein_gantry"},
			{"scenario_id":"ashen-clausemarch","size":Vector2i(16,10),"flag":"ashen_clausemarch_recorded","player_town":"town_cindercoil_foundry"},
			{"scenario_id":"furnace-reckoning","size":Vector2i(20,12),"flag":"three_hearth_reckoning_sworn","player_town":"town_cindercoil_foundry"},
		]
	},
	{
		"campaign_id":"campaign_last_bell_sounding", "hero_id":"hero_veilmourn_sael_mirrorbell", "army_id":"army_sael_spellwright_cadre", "faction_id":"faction_veilmourn",
		"chapters":[
			{"scenario_id":"gloamwake-recall","size":Vector2i(14,8),"flag":"gloamwake_bell_recalled","player_town":"town_veilmourn_bellwake_harbor"},
			{"scenario_id":"false-channel-pursuit","size":Vector2i(16,10),"flag":"true_channel_sounded","player_town":"town_gloamwake_anchorage"},
			{"scenario_id":"three-harbors-sounding","size":Vector2i(20,12),"flag":"last_bell_three_harbors_sounded","player_town":"town_gloamwake_anchorage"},
		]
	},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for campaign_spec in CAMPAIGNS:
		_validate_campaign_identity(campaign_spec)
		for chapter in campaign_spec.get("chapters", []):
			var session = ScenarioFactory.create_session(String(chapter.get("scenario_id", "")), "normal", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
			_expect(session != null, "%s did not create a campaign session." % String(chapter.get("scenario_id", "")))
			if session == null:
				continue
			OverworldRules.normalize_overworld_state(session)
			_validate_scenario(session, campaign_spec, chapter)
			_validate_battles(session)
			_validate_save_round_trip(session)
			await _capture_map(view, session)
		_validate_progression(campaign_spec)
	_validate_art()
	var battle_count: int = int(_rows.reduce(func(total, row): return total + int(row.get("battle_count", 0)), 0))
	var report := {
		"ok":_errors.is_empty(), "campaign_count":CAMPAIGNS.size(), "scenario_count":_rows.size(),
		"battle_payload_count":battle_count, "save_version":SessionStateStoreScript.SAVE_VERSION,
		"same_hero_progression":_errors.is_empty(), "single_consolidated_smoke":true,
		"rows":_rows, "errors":_errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"campaign_count":2,"scenario_count":6,"battle_payload_count":battle_count,"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_campaign_identity(spec: Dictionary) -> void:
	var campaign := ContentService.get_campaign(String(spec.get("campaign_id", "")))
	_expect(not campaign.is_empty() and (campaign.get("scenarios", []) as Array).size() == 3, "%s is not a complete three-chapter campaign." % String(spec.get("campaign_id", "")))
	_expect(String(campaign.get("emblem_alt_text", "")).length() >= 24, "%s lost its accessible emblem description." % String(spec.get("campaign_id", "")))


func _validate_scenario(session, spec: Dictionary, chapter: Dictionary) -> void:
	var scenario_id := String(chapter.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var size: Dictionary = scenario.get("map_size", {})
	var expected_size: Vector2i = chapter.get("size", Vector2i.ZERO)
	_expect(Vector2i(int(size.get("width", 0)), int(size.get("height", 0))) == expected_size, "%s lost its exact authored map size." % scenario_id)
	_expect(String(scenario.get("hero_id", "")) == String(spec.get("hero_id", "")) and String(scenario.get("player_army_id", "")) == String(spec.get("army_id", "")), "%s lost its production command identity." % scenario_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(spec.get("faction_id", "")) and String(session.overworld.get("active_hero_id", "")) == String(spec.get("hero_id", "")), "%s did not launch for the authored faction and hero." % scenario_id)
	var towns: Array = scenario.get("towns", [])
	var has_player_town := towns.any(func(town): return String(town.get("town_id", "")) == String(chapter.get("player_town", "")) and String(town.get("owner", "")) == "player")
	_expect(has_player_town, "%s lost its authored player-controlled signature town." % scenario_id)
	_expect(towns.size() >= 2 and (scenario.get("resource_nodes", []) as Array).size() >= 11 and (scenario.get("encounters", []) as Array).size() >= 4, "%s lost its playable town, economy, or battle breadth." % scenario_id)
	_expect((scenario.get("objectives", {}).get("victory", []) as Array).size() >= 4 and (scenario.get("objectives", {}).get("defeat", []) as Array).size() >= 4 and (scenario.get("script_hooks", []) as Array).size() >= 5, "%s lost its objective or pacing contract." % scenario_id)
	_rows.append({"campaign_id":String(spec.get("campaign_id", "")),"scenario_id":scenario_id,"map_size":"%dx%d" % [expected_size.x,expected_size.y],"battle_count":0,"save_round_trip_exact":false})


func _validate_battles(session) -> void:
	var count := 0
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var battle := BattleRulesScript.create_battle_payload(session, encounter_value)
		_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == String(encounter_value.get("encounter_id", "")), "%s/%s could not construct its production battle." % [session.scenario_id, String(encounter_value.get("placement_id", ""))])
		if not battle.is_empty():
			count += 1
	if not _rows.is_empty():
		_rows[-1]["battle_count"] = count


func _validate_save_round_trip(session) -> void:
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	var exact: bool = restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION
	_expect(exact, "%s did not round-trip exactly through save version %d." % [session.scenario_id, SessionStateStoreScript.SAVE_VERSION])
	if not _rows.is_empty():
		_rows[-1]["save_round_trip_exact"] = exact


func _validate_progression(spec: Dictionary) -> void:
	var chapters: Array = spec.get("chapters", [])
	var profile := CampaignRulesScript.normalize_profile({})
	for index in range(chapters.size()):
		var chapter: Dictionary = chapters[index]
		var session
		if index == 0:
			session = ScenarioFactory.create_session(String(chapter.get("scenario_id", "")), "normal", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
		else:
			var action := CampaignRulesScript.build_chapter_action(profile, String(spec.get("campaign_id", "")), String(chapter.get("scenario_id", "")))
			_expect(not bool(action.get("disabled", true)), "%s did not unlock from the exact prior victory and flag." % String(chapter.get("scenario_id", "")))
			session = CampaignRulesScript.build_session(profile, String(chapter.get("scenario_id", "")), "normal", String(spec.get("campaign_id", "")))
			var previous: Dictionary = chapters[index - 1]
			_expect(bool(session.flags.get("carryover_%s" % String(previous.get("flag", "")), false)), "%s did not import the exact prior campaign flag." % String(chapter.get("scenario_id", "")))
		_expect(session != null and String(session.overworld.get("active_hero_id", "")) == String(spec.get("hero_id", "")), "%s lost same-hero campaign continuity." % String(chapter.get("scenario_id", "")))
		if session == null:
			return
		session.flags[String(chapter.get("flag", ""))] = true
		session.scenario_status = "victory"
		session.scenario_summary = "%s completed." % String(chapter.get("scenario_id", ""))
		profile = CampaignRulesScript.record_session_completion(profile, session)


func _validate_art() -> void:
	var paths := []
	for spec in CAMPAIGNS:
		var campaign := ContentService.get_campaign(String(spec.get("campaign_id", "")))
		paths.append({"path":String(campaign.get("emblem_path", "")),"size":Vector2i(128,128),"hash":String(campaign.get("emblem_runtime_sha256", ""))})
		for chapter in campaign.get("scenarios", []):
			paths.append({"path":String(chapter.get("seal_path", "")),"size":Vector2i(64,64),"hash":String(chapter.get("seal_runtime_sha256", ""))})
	var hashes := {}
	var strip := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0,0,0,0))
	for index in range(paths.size()):
		var record: Dictionary = paths[index]
		var path := String(record.get("path", ""))
		var absolute := ProjectSettings.globalize_path(path)
		var image := Image.load_from_file(absolute)
		var hash := FileAccess.get_sha256(absolute)
		_expect(not image.is_empty() and image.get_size() == record.get("size") and image.detect_alpha() != Image.ALPHA_NONE and hash == String(record.get("hash", "")), "%s lost its exact alpha-safe campaign art." % path)
		hashes[hash] = true
		if not image.is_empty():
			var position := Vector2i((index % 4) * 128, (index / 4) * 128)
			strip.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), position)
	_expect(hashes.size() == 8, "The two emblems and six seals are not visually distinct runtime assets.")
	_expect(strip.save_png("%s/emblems_and_seals.png" % OUTPUT_DIR) == OK, "Could not save the dual-campaign art strip.")


func _capture_map(view: Control, session) -> void:
	_reveal_all(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(session.overworld.get("position", {}).get("x", 0)), int(session.overworld.get("position", {}).get("y", 0))))
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png("%s/%s.png" % [OUTPUT_DIR, session.scenario_id]) == OK, "Could not capture %s." % session.scenario_id)


func _reveal_all(session) -> void:
	var size := OverworldRules.derive_map_size(session)
	var visible := []
	var explored := []
	for _y in range(size.y):
		var visible_row := []
		var explored_row := []
		for _x in range(size.x):
			visible_row.append(true)
			explored_row.append(true)
		visible.append(visible_row)
		explored.append(explored_row)
	session.overworld["fog"] = {"visible_tiles":visible,"explored_tiles":explored,"visible_count":size.x*size.y,"explored_count":size.x*size.y,"total_tiles":size.x*size.y}


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
