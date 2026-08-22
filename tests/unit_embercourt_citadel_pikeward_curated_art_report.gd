extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_EMBERCOURT_CITADEL_PIKEWARD_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_embercourt_citadel_pikeward_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const TARGET_IDS := ["unit_citadel_pikeward"]
const UNITS := [
	{
		"unit_id": "unit_citadel_pikeward", "label": "Citadel Pikeward", "ability_ids": ["reach", "formation_guard"],
		"source_path": "res://art/units/source/curated/unit_citadel_pikeward.png", "portrait_path": "res://art/units/portraits/unit_citadel_pikeward.png", "icon_path": "res://art/units/battle_icons/unit_citadel_pikeward.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_citadel_pikeward.png", "sheet_path": "res://art/animation/runtime/units/unit_citadel_pikeward.png",
		"source_sha256": "92c79e97dea6f8261272874990bdb6d12255a6201e4dd3b53fff100a51d81ca0", "portrait_sha256": "a4a860c5bcd813599260e50bcf7f4400940701d9bdba4716af27a4830e2cc6ce", "icon_sha256": "35992c391ef181e5dfe867657b2d68d86a3930b47bdee5d0c5753413de12ba9a", "overworld_icon_sha256": "fc4096a34c96ce4fc75657ada31fa2f2421c80ba4b8fc9bdd819bd0ac1301641", "sheet_sha256": "482ad10ff59237dc65af3377f59576275a59f35157c947b0959b5da6ca7864c9",
		"old_portrait_sha256": "9f22286d608bdfaf94d32ac443c91199456c26c3195fba57059e542f2a05820d", "old_icon_sha256": "43a3cf5b58e207c538b19d3e4dd1598410a1ea826f84278f43561afced9153bc", "old_overworld_icon_sha256": "abc74debb461f2ad8a98c394f80c1a6f6c01b66f0b920cabcec2ef7f48cde0d8", "old_sheet_sha256": "248a293ed3609c82dfc29c1d36c43f64596401af0570426ee499c408dcb3be35",
	},
]
const ENCOUNTERS := [
	{"scenario_id": "bogbound-oath", "placement_id": "bogbound_archive_wardens", "army_id": "army_bogbound_archive_wardens_watch", "stacks": [{"unit_id": "unit_river_guard", "count": 8}, {"unit_id": "unit_ember_archer", "count": 12}, {"unit_id": "unit_citadel_pikeward", "count": 6}]},
	{"scenario_id": "charter-pyre", "placement_id": "charter_granary_levies", "army_id": "army_charter_granary_levies_watch", "stacks": [{"unit_id": "unit_river_guard", "count": 11}, {"unit_id": "unit_ember_archer", "count": 8}, {"unit_id": "unit_citadel_pikeward", "count": 2}]},
	{"scenario_id": "lockmarsh-surge", "placement_id": "surge_road_chaplains", "army_id": "army_lockmarsh_road_chaplains_watch", "stacks": [{"unit_id": "unit_river_guard", "count": 9}, {"unit_id": "unit_ember_archer", "count": 10}, {"unit_id": "unit_citadel_pikeward", "count": 6}]},
	{"scenario_id": "lockmarsh-surge", "placement_id": "surge_charter_guard", "army_id": "army_lockmarsh_charter_guard_watch", "stacks": [{"unit_id": "unit_river_guard", "count": 7}, {"unit_id": "unit_ember_archer", "count": 6}, {"unit_id": "unit_citadel_pikeward", "count": 2}]},
	{"scenario_id": "lockmarsh-surge", "placement_id": "lockmarsh_archive_wardens", "army_id": "army_lockmarsh_archive_wardens_watch", "stacks": [{"unit_id": "unit_river_guard", "count": 7}, {"unit_id": "unit_ember_archer", "count": 9}, {"unit_id": "unit_citadel_pikeward", "count": 2}]},
	{"scenario_id": "glassroad-sundering", "placement_id": "glassroad_archive_wardens", "army_id": "army_glassroad_archive_line_watch", "stacks": [{"unit_id": "unit_river_guard", "count": 5}, {"unit_id": "unit_ember_archer", "count": 7}, {"unit_id": "unit_citadel_pikeward", "count": 3}]},
	{"scenario_id": "orevein-contract", "placement_id": "orevein_archive_wardens", "army_id": "army_orevein_archive_wardens_watch", "stacks": [{"unit_id": "unit_river_guard", "count": 11}, {"unit_id": "unit_ember_archer", "count": 11}, {"unit_id": "unit_citadel_pikeward", "count": 4}]},
	{"scenario_id": "orevein-contract", "placement_id": "orevein_bridgeward_levies", "army_id": "army_orevein_bridgeward_levies", "stacks": [{"unit_id": "unit_river_guard", "count": 5}, {"unit_id": "unit_citadel_pikeward", "count": 4}, {"unit_id": "unit_ember_archer", "count": 6}]},
	{"scenario_id": "orevein-contract", "placement_id": "orevein_beacon_wardens", "army_id": "army_orevein_beacon_wardens", "stacks": [{"unit_id": "unit_ember_archer", "count": 4}, {"unit_id": "unit_river_guard", "count": 5}, {"unit_id": "unit_citadel_pikeward", "count": 1}]},
	{"scenario_id": "clauseworks-counterclaim", "placement_id": "clauseworks_archive_wardens", "army_id": "army_clauseworks_archive_wardens", "stacks": [{"unit_id": "unit_river_guard", "count": 8}, {"unit_id": "unit_ember_archer", "count": 8}, {"unit_id": "unit_citadel_pikeward", "count": 3}]},
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
		if String(spec["placement_id"]) == "clauseworks_archive_wardens":
			board_session = session
			board_payload = battle_payload
	_report["encounters"] = encounter_rows
	_expect(board_session != null and not board_payload.is_empty(), "Clauseworks Archive Wardens Board fixture must retain the Citadel Pikeward with the frozen River Guard and Ember Archer line.")
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
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Clauseworks Archive Wardens stack." % String(unit_spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(unit_spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(unit_spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(unit_spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(unit_spec["label"]))
			entries.append(entry)
	_expect(board_session.to_dict() == board_authority_before, "BattleBoard art observation must not mutate the Clauseworks battle/session.")
	_report["runtime"] = {"scenario_id": "clauseworks-counterclaim", "placement_id": "clauseworks_archive_wardens", "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": board_session.to_dict() == board_authority_before}
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
