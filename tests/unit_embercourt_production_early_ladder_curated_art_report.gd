extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_EMBERCOURT_PRODUCTION_EARLY_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_embercourt_production_early_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const TARGET_IDS := ["unit_embercourt_lantern_sappers", "unit_embercourt_bargebow_crews"]
const UNITS := [
	{
		"unit_id": "unit_embercourt_lantern_sappers", "label": "Lantern Sappers", "ability_ids": ["counter_ambush_flare"],
		"source_path": "res://art/units/source/curated/unit_embercourt_lantern_sappers.png", "portrait_path": "res://art/units/portraits/unit_embercourt_lantern_sappers.png", "icon_path": "res://art/units/battle_icons/unit_embercourt_lantern_sappers.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_embercourt_lantern_sappers.png", "sheet_path": "res://art/animation/runtime/units/unit_embercourt_lantern_sappers.png",
		"source_sha256": "94eafb9f33268e0213f5741a6009464df52542242b34ece6937c910142811fa7", "portrait_sha256": "064e2d33e73565c29866b45d38bb16df10cb3bae48da44a4ebe9018c015d7977", "icon_sha256": "b8d231cc7ec1f19eda0cb33b607ad8e8b0fe1369961d0683a25f47a729c63535", "overworld_icon_sha256": "96bd9a8baeafec8b9d30f018bdb576e74a4d30cc9fe1768145c3ccd4e87d3adc", "sheet_sha256": "8fabd2323b4d887b3d292e220fc56919ec69b6884edd562e3c1222b7b1678061",
		"old_portrait_sha256": "d865b7c8b3749493d9b1cba4af529a87e6347903542eba78bb895f84aa9fddbe", "old_icon_sha256": "97e1d3e5977f36163f02c88cfdc44c573dbcbdc26be6b9d8be58e357f3e18c26", "old_overworld_icon_sha256": "1ed53f6e4d9efa38d7d390cbbab08d5977611488adb35b68b150069e24a2e755", "old_sheet_sha256": "d6749fd73a60635886bd30feb54bd47eb971b5f535827c17e593507ce45cdacf",
	},
	{
		"unit_id": "unit_embercourt_bargebow_crews", "label": "Bargebow Crews", "ability_ids": ["volley"],
		"source_path": "res://art/units/source/curated/unit_embercourt_bargebow_crews.png", "portrait_path": "res://art/units/portraits/unit_embercourt_bargebow_crews.png", "icon_path": "res://art/units/battle_icons/unit_embercourt_bargebow_crews.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_embercourt_bargebow_crews.png", "sheet_path": "res://art/animation/runtime/units/unit_embercourt_bargebow_crews.png",
		"source_sha256": "cd6ac693e3adadef8729201fbcba35e1164fa03fa0bd5ded01dc8744b04ef6a1", "portrait_sha256": "ade82e81aa78fe54737a8f9642a0a71651ee9f17cba39ddcb34f89b9cad0164b", "icon_sha256": "21471a399e804968c33bbff6fd9a266cef39b4943480f73512fdd779e333af89", "overworld_icon_sha256": "20290de8cbe5fa3d4d3f51f93a6f74c5e69bf100924f47f57be7b90bbb7e9890", "sheet_sha256": "ef9d51712f342cc47c92a9598dfdcb74fe99e2ff57bde4b76424e04b27f9b036",
		"old_portrait_sha256": "ffbb40150ffd958094921c49d648432e9f1ff8d62f2c1d437121fc6670fe645c", "old_icon_sha256": "af5ffbd34ec925ba663e087a68907a26e7f2fb1aa51caa1b17ad6abb827d4faa", "old_overworld_icon_sha256": "237a032288e126ad03b4c28c11920b2edd1144162a1c8a17c7df3cc0cb0b964d", "old_sheet_sha256": "251e277aa62f1df9bd69ab88333c3e7cccecf5cd1e26bf40f3ec191ad4920074",
	},
]
const ENCOUNTERS := [
	{"scenario_id": "clauseworks-counterclaim", "placement_id": "clauseworks_bridge_levies", "army_id": "army_clauseworks_bridge_levies", "stacks": [{"unit_id": "unit_embercourt_fordhook_cadets", "count": 5}, {"unit_id": "unit_embercourt_bargebow_crews", "count": 5}, {"unit_id": "unit_embercourt_sluicefire_lindworms", "count": 1}]},
	{"scenario_id": "clauseworks-counterclaim", "placement_id": "clauseworks_beacon_wardens", "army_id": "army_clauseworks_beacon_wardens", "stacks": [{"unit_id": "unit_embercourt_lantern_sappers", "count": 6}, {"unit_id": "unit_embercourt_fordhook_cadets", "count": 7}, {"unit_id": "unit_embercourt_bargebow_crews", "count": 2}]},
]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "encounters": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	await _validate_live_encounters_and_board()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "unit_count": UNITS.size(), "encounter_count": ENCOUNTERS.size(), "state_count": STATES.size(), "frames_per_state": FRAMES_PER_STATE, "visible_frame_count": UNITS.size() * STATES.size() * FRAMES_PER_STATE, "board_entry_count": int(_report.get("runtime", {}).get("entry_count", 0))})])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_assets_and_provenance() -> void:
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var label := String(spec["label"])
		var source: Image = _load_image(String(spec["source_path"]))
		var portrait: Image = _load_image(String(spec["portrait_path"]))
		var icon: Image = _load_image(String(spec["icon_path"]))
		var overworld_icon: Image = _load_image(String(spec["overworld_icon_path"]))
		var sheet: Image = _load_image(String(spec["sheet_path"]))
		_expect(source != null and source.get_size() == Vector2i(512, 512), "%s source must load at 512x512." % label)
		_expect(portrait != null and portrait.get_size() == Vector2i(384, 512), "%s portrait must load at 384x512." % label)
		_expect(icon != null and icon.get_size() == Vector2i(160, 160), "%s battle icon must load at 160x160." % label)
		_expect(overworld_icon != null and overworld_icon.get_size() == Vector2i(96, 96), "%s overworld icon must load at 96x96." % label)
		_expect(sheet != null and sheet.get_size() == Vector2i(256, 896), "%s sheet must load at 256x896." % label)
		if source == null or portrait == null or icon == null or overworld_icon == null or sheet == null:
			continue
		var source_alpha := _alpha_metrics(source)
		_expect(int(source_alpha.get("transparent", 0)) > 50000 and int(source_alpha.get("visible", 0)) > 50000 and int(source_alpha.get("opaque", 0)) > 0, "%s source must retain transparent negative space and a materially visible full-alpha silhouette." % label)
		_expect(bool(source_alpha.get("corners_transparent", false)), "%s source corners must remain transparent." % label)
		for key in ["source", "portrait", "icon", "overworld_icon", "sheet"]:
			var hash_key := "%s_sha256" % key
			_expect(FileAccess.get_sha256(String(spec["%s_path" % key])) == String(spec[hash_key]), "%s %s hash drifted." % [label, key])
			if key != "source":
				_expect(String(spec[hash_key]) != String(spec["old_%s_sha256" % key]), "%s %s did not replace the abstract payload." % [label, key])
		var art: Dictionary = ContentService.get_unit_art(String(spec["unit_id"]))
		var animation: Dictionary = ContentService.get_unit_animation(String(spec["unit_id"]))
		for record in [art, animation]:
			_expect(String(record.get("art_source_kind", "")) == "curated_original_character_v1", "%s manifest lost curated source kind." % label)
			_expect(String(record.get("curated_source", "")) == String(spec["source_path"]), "%s manifest lost curated source path." % label)
			_expect(String(record.get("curated_source_sha256", "")) == String(spec["source_sha256"]), "%s manifest lost curated source hash." % label)
		_expect(String(art.get("portrait", "")) == String(spec["portrait_path"]) and String(art.get("battle_icon", "")) == String(spec["icon_path"]) and String(art.get("overworld_icon", "")) == String(spec["overworld_icon_path"]), "%s runtime art paths changed." % label)
		_expect(String(animation.get("sprite_sheet", "")) == String(spec["sheet_path"]) and animation.get("states", []) == STATES, "%s runtime sheet/state contract changed." % label)
		var visible_frames := 0
		for state_index in range(STATES.size()):
			var signatures := {}
			var visible := 0
			for frame_index in range(FRAMES_PER_STATE):
				var frame: Image = sheet.get_region(Rect2i(Vector2i(frame_index * FRAME_SIZE.x, state_index * FRAME_SIZE.y), FRAME_SIZE))
				if int(_alpha_metrics(frame).get("visible", 0)) >= 350:
					visible += 1
				signatures[hash(frame.get_data())] = true
			_expect(visible == FRAMES_PER_STATE and signatures.size() >= 2, "%s state %s lost visible frame variation." % [label, STATES[state_index]])
			visible_frames += visible
		rows.append({"unit_id": spec["unit_id"], "source_sha256": spec["source_sha256"], "portrait_sha256": spec["portrait_sha256"], "icon_sha256": spec["icon_sha256"], "overworld_icon_sha256": spec["overworld_icon_sha256"], "sheet_sha256": spec["sheet_sha256"], "source_alpha": source_alpha, "visible_frames": visible_frames})
	_report["assets"] = rows

func _validate_live_encounters_and_board() -> void:
	var encounter_rows := []
	var board_session: SessionStateStoreScript.SessionData = null
	var board_payload := {}
	for encounter_variant in ENCOUNTERS:
		var spec: Dictionary = encounter_variant
		var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(String(spec["scenario_id"]), "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		_expect(session != null, "%s must create a live session." % String(spec["placement_id"]))
		if session == null:
			continue
		OverworldRules.normalize_overworld_state(session)
		var placement := _encounter_placement(session, String(spec["placement_id"]))
		var army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
		_expect(not placement.is_empty() and String(army.get("id", "")) == String(spec["army_id"]) and _stack_contract(army.get("stacks", [])) == spec["stacks"], "%s authored encounter roster changed." % String(spec["placement_id"]))
		var authority_before: Dictionary = session.to_dict()
		var battle_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
		var enemy_stacks: Array = battle_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
		_expect(_battle_stack_contract(enemy_stacks) == spec["stacks"], "%s public battle roster changed." % String(spec["placement_id"]))
		var expected_abilities := _expected_target_abilities(spec["stacks"])
		_expect(_battle_target_ability_contract(enemy_stacks) == expected_abilities, "%s public target abilities changed." % String(spec["placement_id"]))
		_expect(session.to_dict() == authority_before, "%s public battle materialization mutated the session." % String(spec["placement_id"]))
		encounter_rows.append({"scenario_id": spec["scenario_id"], "placement_id": spec["placement_id"], "army_id": spec["army_id"], "stacks": _battle_stack_contract(enemy_stacks), "abilities": _battle_target_ability_contract(enemy_stacks), "session_authority_exact": session.to_dict() == authority_before})
		if String(spec["placement_id"]) == "clauseworks_beacon_wardens":
			board_session = session
			board_payload = battle_payload
	_report["encounters"] = encounter_rows
	_expect(board_session != null and not board_payload.is_empty(), "Clauseworks Beacon Wardens Board fixture must retain both curated Embercourt targets with the frozen Fordhook line.")
	if board_session == null or board_payload.is_empty():
		return
	board_session.battle = board_payload
	var board_authority_before: Dictionary = board_session.to_dict()
	SessionState.set_active_session(board_session)
	var board = BattleBoardViewScript.new()
	board.size = Vector2(900, 560)
	add_child(board)
	board.set_battle_state(board_session)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary: Dictionary = board.validation_unit_art_summary()
	var entries := []
	for spec_variant in UNITS:
		var unit_spec: Dictionary = spec_variant
		var matches := []
		for entry in summary.get("stacks", []):
			if entry is Dictionary and String(entry.get("side", "enemy")) != "player" and String(entry.get("unit_id", "")) == String(unit_spec["unit_id"]):
				matches.append(entry.duplicate(true))
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Clauseworks Beacon Wardens stack." % String(unit_spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(unit_spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(unit_spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(unit_spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(unit_spec["label"]))
			entries.append(entry)
	_expect(board_session.to_dict() == board_authority_before, "BattleBoard art observation must not mutate the Clauseworks battle/session.")
	_report["runtime"] = {"scenario_id": "clauseworks-counterclaim", "placement_id": "clauseworks_beacon_wardens", "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": board_session.to_dict() == board_authority_before}
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)

func _encounter_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _stack_contract(stacks_value: Variant) -> Array:
	var result: Array = []
	for stack in stacks_value if stacks_value is Array else []:
		if stack is Dictionary:
			result.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0))})
	return result

func _battle_stack_contract(stacks: Array) -> Array:
	var result: Array = []
	for stack in stacks:
		if stack is Dictionary:
			result.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("base_count", 0))})
	return result

func _expected_target_abilities(stacks_value: Variant) -> Dictionary:
	var result := {}
	for stack in stacks_value if stacks_value is Array else []:
		if stack is Dictionary:
			for spec_variant in UNITS:
				var spec: Dictionary = spec_variant
				if String(stack.get("unit_id", "")) == String(spec["unit_id"]):
					result[String(spec["unit_id"])] = spec["ability_ids"].duplicate()
	return result

func _battle_target_ability_contract(stacks: Array) -> Dictionary:
	var result := {}
	for stack in stacks:
		if not stack is Dictionary:
			continue
		var unit_id := String(stack.get("unit_id", ""))
		if not unit_id in TARGET_IDS:
			continue
		var ability_ids := []
		for ability in stack.get("abilities", []):
			if ability is Dictionary:
				ability_ids.append(String(ability.get("id", "")))
		result[unit_id] = ability_ids
	return result

func _alpha_metrics(image: Image) -> Dictionary:
	var transparent := 0
	var opaque := 0
	var visible := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha <= 0.001:
				transparent += 1
			else:
				visible += 1
				if alpha >= 0.999:
					opaque += 1
	var max_x := image.get_width() - 1
	var max_y := image.get_height() - 1
	return {"transparent": transparent, "opaque": opaque, "visible": visible, "corners_transparent": image.get_pixel(0, 0).a <= 0.001 and image.get_pixel(max_x, 0).a <= 0.001 and image.get_pixel(0, max_y).a <= 0.001 and image.get_pixel(max_x, max_y).a <= 0.001}

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
