extends Node

const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const TownShellScene = preload("res://scenes/town/TownShell.tscn")

const REPORT_ID := "UNIT_CURATED_CROSS_SURFACE_IDENTITY_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_curated_cross_surface_identity_report"
const UNITS := [
	{
		"unit_id": "unit_embercourt_fordhook_cadets",
		"portrait": "res://art/units/portraits/unit_embercourt_fordhook_cadets.png",
		"portrait_sha256": "ea1cce2c724f85b39f44756a1cea689c6ed75cc2d9ca9a5143ed2803d6375d07",
		"old_portrait_sha256": "936b792f1aadd9d489681492aa34b204c36ecfb0aaa325ed08264ee7528e00b8",
		"overworld_icon": "res://art/units/overworld_icons/unit_embercourt_fordhook_cadets.png",
		"overworld_sha256": "5b610954d52052f7e04e056af4ab84adf84a70bdb056ff711f4218e30472ed15",
		"old_overworld_sha256": "f5f3c0df9c8abac63cdcf9d32d4ab2c09fa71eb92c5458d9815ebb7f1e57c641",
		"battle_icon_sha256": "9ed1ac039d88abfd06d83ad1bcf7e5b970df999d245010be651b3cc3b96e1d87",
		"battle_sheet_sha256": "1aa44e4b02fd4177b0d9980f19fe3d00c38865083e96fab1bec0166a6b6382a8",
	},
	{
		"unit_id": "unit_brasshollow_scrip_haulers",
		"portrait": "res://art/units/portraits/unit_brasshollow_scrip_haulers.png",
		"portrait_sha256": "6c56e7484656c5badd866ae20fca2f12e7c4dee6497566b5d2a8f4996aa51a6c",
		"old_portrait_sha256": "60a64abbe720dea5cad32fe903b7eb78174b01f898f1bd3c1b75b8db0dba8b76",
		"overworld_icon": "res://art/units/overworld_icons/unit_brasshollow_scrip_haulers.png",
		"overworld_sha256": "a82851c7a7bdbe50eec799e7afdadefaa7a0c491da54e19b99acc06a6f97559e",
		"old_overworld_sha256": "9159c57f3e948e4cf946619e8501a7d6b3377f3f3503bf079958981cb220076f",
		"battle_icon_sha256": "60ce46eee94ee9c180155bdcdc3fdb46e9ef4940e058007d36225856d4877c8c",
		"battle_sheet_sha256": "2a20a26526eca2e50591c45cb4f0a07cfebfb310813cbf16832f1a59a6a052ae",
	},
	{
		"unit_id": "unit_brasshollow_rivet_hounds",
		"portrait": "res://art/units/portraits/unit_brasshollow_rivet_hounds.png",
		"portrait_sha256": "45f5643f184395d443d2dff024611f6babf5f56549647155599bdfda2f0b24c8",
		"old_portrait_sha256": "276871efb5cf50af0436adecde871d0293e0fa5c2532c68c9283a1721cf9c327",
		"overworld_icon": "res://art/units/overworld_icons/unit_brasshollow_rivet_hounds.png",
		"overworld_sha256": "0011ab3afe971268bf0f425fff22413c0588d42b32cb72d0d602aa4189df6819",
		"old_overworld_sha256": "296733a2a609c45e0fc17e12c7161179e1b84bd0b0250d3002b01820c89e1a4f",
		"battle_icon_sha256": "9a03cbf4ca07e1593d2f970373990da1b2e9774bbb3a07c7e427fcb76989c305",
		"battle_sheet_sha256": "a21781b53811e4236e573d5d73cdef492ab30bc890360d18c15f4fd1172d5a0e",
	},
	{
		"unit_id": "unit_brasshollow_furnace_pavis_teams",
		"portrait": "res://art/units/portraits/unit_brasshollow_furnace_pavis_teams.png",
		"portrait_sha256": "100d509cbc5eadee35d0354532cc9d5a3192ef856d73cf62c93f947aa3595e2e",
		"old_portrait_sha256": "20ef7fb91c6c085a0e494a3dd39ba08de4a4ebec8f3ef26c35f663c6ca0cc699",
		"overworld_icon": "res://art/units/overworld_icons/unit_brasshollow_furnace_pavis_teams.png",
		"overworld_sha256": "e8b2a459ff0b50d10ca9ea7ea283e02c8389521595d375e5e2a3386c0270242f",
		"old_overworld_sha256": "d9e857d799eba60abbb36d6c9956b1d654864b42e4ad6873735d3cd2f552da2f",
		"battle_icon_sha256": "c8219bbc6e385dad5daedf72565f958205c588a1192588db3911a7d94f88e8ec",
		"battle_sheet_sha256": "5ff92a28cdfba8fb62af0e8171fa9f6d8668bb4b9257c8c5778c718dc7a89bbe",
	},
]
const LIVE_STOCKPILE_RESOURCE_IDS := ["gold", "wood", "ore", "aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "town": [], "overworld": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets()
	_report["town"].append(await _validate_town_case("faction_embercourt", ["unit_embercourt_fordhook_cadets"]))
	_report["town"].append(await _validate_town_case("faction_brasshollow", ["unit_brasshollow_scrip_haulers", "unit_brasshollow_rivet_hounds", "unit_brasshollow_furnace_pavis_teams"]))
	_report["overworld"] = await _validate_overworld_case()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "unit_count": UNITS.size(), "town_case_count": _report["town"].size(), "town_target_count": 4, "overworld_target_count": int(_report["overworld"].get("target_count", 0))})])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_assets() -> void:
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var unit_id := String(spec["unit_id"])
		var art: Dictionary = ContentService.get_unit_art(unit_id)
		var animation: Dictionary = ContentService.get_unit_animation(unit_id)
		var portrait_path := String(spec["portrait"])
		var overworld_path := String(spec["overworld_icon"])
		var portrait: Image = _load_image(portrait_path)
		var overworld: Image = _load_image(overworld_path)
		_expect(portrait != null and portrait.get_size() == Vector2i(384, 512), "%s portrait must load at 384x512." % unit_id)
		_expect(overworld != null and overworld.get_size() == Vector2i(96, 96), "%s overworld icon must load at 96x96." % unit_id)
		if portrait == null or overworld == null:
			continue
		_expect(_visible_pixel_count(portrait) > 150000, "%s portrait lost its character-readable surface." % unit_id)
		_expect(_visible_pixel_count(overworld) > 2500, "%s overworld icon lost its character-readable surface." % unit_id)
		_expect(FileAccess.get_sha256(portrait_path) == String(spec["portrait_sha256"]) and String(spec["portrait_sha256"]) != String(spec["old_portrait_sha256"]), "%s portrait is not the exact curated replacement." % unit_id)
		_expect(FileAccess.get_sha256(overworld_path) == String(spec["overworld_sha256"]) and String(spec["overworld_sha256"]) != String(spec["old_overworld_sha256"]), "%s overworld icon is not the exact curated replacement." % unit_id)
		_expect(FileAccess.get_sha256(String(art.get("battle_icon", ""))) == String(spec["battle_icon_sha256"]), "%s battle icon changed during cross-surface derivation." % unit_id)
		_expect(FileAccess.get_sha256(String(animation.get("sprite_sheet", ""))) == String(spec["battle_sheet_sha256"]), "%s battle sheet changed during cross-surface derivation." % unit_id)
		_expect(String(art.get("portrait", "")) == portrait_path and String(art.get("overworld_icon", "")) == overworld_path, "%s manifest runtime paths drifted." % unit_id)
		_expect(String(art.get("art_source_kind", "")) == "curated_original_character_v1" and String(animation.get("art_source_kind", "")) == "curated_original_character_v1", "%s curated source provenance drifted." % unit_id)
		rows.append({"unit_id": unit_id, "portrait_sha256": spec["portrait_sha256"], "overworld_sha256": spec["overworld_sha256"], "portrait_visible": _visible_pixel_count(portrait), "overworld_visible": _visible_pixel_count(overworld)})
	_report["assets"] = rows

func _validate_town_case(faction_id: String, target_ids: Array) -> Dictionary:
	var faction: Dictionary = ContentService.get_faction(faction_id)
	var ladder_ids: Array = faction.get("unit_ladder_ids", []).duplicate()
	var signature_ids: Array = faction.get("signature_building_ids", []).duplicate()
	var town_template: Dictionary = ContentService.get_town(String(faction.get("seed_town_id", "")))
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var placement_id := "curated_cross_surface_%s" % faction_id
	var town_state := _town_state(town_template, faction_id, placement_id, signature_ids, ladder_ids)
	session.overworld["towns"] = [town_state]
	session.overworld["resources"] = _deep_resources()
	session.day = 30
	_move_active_hero_to_town(session, town_state)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	_expect(bool(visit_result.get("ok", false)), "%s TownShell fixture could not open its live town." % faction_id)
	SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_force_refresh")
	await get_tree().process_frame
	var summary: Dictionary = shell.call("validation_unit_art_summary")
	var matches := []
	for target_id_variant in target_ids:
		var target_id := String(target_id_variant)
		var expected_path := String(ContentService.get_unit_art(target_id).get("portrait", ""))
		var rows := []
		for entry in summary.get("actions", []):
			if entry is Dictionary and String(entry.get("unit_id", "")) == target_id:
				rows.append(entry.duplicate(true))
		_expect(rows.size() == 1, "TownShell must expose exactly one %s recruit portrait." % target_id)
		if rows.size() == 1:
			_expect(bool(rows[0].get("loaded", false)) and String(rows[0].get("portrait", "")) == expected_path, "TownShell did not load the exact %s portrait." % target_id)
			matches.append(rows[0])
	_expect(int(summary.get("portrait_loaded_count", 0)) == int(summary.get("recruit_action_count", 0)) and int(summary.get("recruit_action_count", 0)) == 7, "%s TownShell did not load all seven ladder portraits." % faction_id)
	var row := {"faction_id": faction_id, "target_count": matches.size(), "targets": matches, "recruit_action_count": int(summary.get("recruit_action_count", 0))}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _validate_overworld_case() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	var encounters := []
	for index in range(UNITS.size()):
		var spec: Dictionary = UNITS[index]
		encounters.append({"placement_id": "curated_cross_surface_%d" % index, "encounter_id": "curated_cross_surface_%d" % index, "unit_id": spec["unit_id"], "x": 4 + index, "y": 3, "difficulty": "medium", "resolved": false})
	session.overworld["encounters"] = encounters
	var view = OverworldMapViewScript.new()
	view.size = Vector2(960, 640)
	add_child(view)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(3, 1))
	await get_tree().process_frame
	var summary: Dictionary = view.validation_unit_art_summary()
	var matches := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var rows := []
		for entry in summary.get("encounters", []):
			if entry is Dictionary and String(entry.get("unit_id", "")) == String(spec["unit_id"]):
				rows.append(entry.duplicate(true))
		_expect(rows.size() == 1, "OverworldMap must expose exactly one %s encounter icon." % String(spec["unit_id"]))
		if rows.size() == 1:
			_expect(bool(rows[0].get("loaded", false)) and String(rows[0].get("overworld_icon", "")) == String(spec["overworld_icon"]), "OverworldMap did not load the exact %s icon." % String(spec["unit_id"]))
			matches.append(rows[0])
	_expect(int(summary.get("overworld_icon_loaded_count", 0)) == UNITS.size() and int(summary.get("encounter_count", 0)) == UNITS.size(), "OverworldMap did not load exactly four curated encounter icons.")
	view.queue_free()
	await get_tree().process_frame
	return {"target_count": matches.size(), "targets": matches, "encounter_count": int(summary.get("encounter_count", 0))}

func _town_state(town_template: Dictionary, faction_id: String, placement_id: String, signature_ids: Array, ladder_ids: Array) -> Dictionary:
	var built := []
	for building_id in town_template.get("starting_building_ids", []):
		if not built.has(String(building_id)):
			built.append(String(building_id))
	for building_id in signature_ids:
		if not built.has(String(building_id)):
			built.append(String(building_id))
	var recruits := {}
	for unit_id in ladder_ids:
		recruits[String(unit_id)] = 6
	return {"placement_id": placement_id, "town_id": String(town_template.get("id", "")), "owner": "player", "controlling_faction_id": faction_id, "x": 4, "y": 4, "built_buildings": built, "available_recruits": recruits, "last_build_day": 0, "garrison": [], "recovery": {}, "front": {}, "occupation": {}}

func _deep_resources() -> Dictionary:
	var resources := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		resources[String(resource_id)] = 99999
	return resources

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero

func _visible_pixel_count(image: Image) -> int:
	var visible := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.001:
				visible += 1
	return visible

func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error(message)

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_errors.append("Failed to write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t") + "\n")
