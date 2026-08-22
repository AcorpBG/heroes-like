extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_BRASSHOLLOW_EARLY_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_brasshollow_early_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_brasshollow_rivet_hounds",
		"label": "Rivet Hounds",
		"source_path": "res://art/units/source/curated/unit_brasshollow_rivet_hounds.png",
		"icon_path": "res://art/units/battle_icons/unit_brasshollow_rivet_hounds.png",
		"sheet_path": "res://art/animation/runtime/units/unit_brasshollow_rivet_hounds.png",
		"source_sha256": "46aa988fafeb9052785bbae6735e210a9fb841f2e3f5fece76328e2cbc596ccf",
		"icon_sha256": "9a03cbf4ca07e1593d2f970373990da1b2e9774bbb3a07c7e427fcb76989c305",
		"sheet_sha256": "a21781b53811e4236e573d5d73cdef492ab30bc890360d18c15f4fd1172d5a0e",
		"old_icon_sha256": "26a10fc0be0de16be1eabb8e1f987008fe28175126217da5b01f0b15ee1fb9c1",
		"old_sheet_sha256": "d1b5bc56d743033ea365d2601192a1d72d16c1809456e538d40b20fd7effcf1f",
		"ability_ids": ["shielding", "harry"],
	},
	{
		"unit_id": "unit_brasshollow_furnace_pavis_teams",
		"label": "Furnace Pavis Teams",
		"source_path": "res://art/units/source/curated/unit_brasshollow_furnace_pavis_teams.png",
		"icon_path": "res://art/units/battle_icons/unit_brasshollow_furnace_pavis_teams.png",
		"sheet_path": "res://art/animation/runtime/units/unit_brasshollow_furnace_pavis_teams.png",
		"source_sha256": "d02f57e6c89d5bf24265ab27df052e333e3ea2c9833c3d71915745253dbbb0e4",
		"icon_sha256": "c8219bbc6e385dad5daedf72565f958205c588a1192588db3911a7d94f88e8ec",
		"sheet_sha256": "5ff92a28cdfba8fb62af0e8171fa9f6d8668bb4b9257c8c5778c718dc7a89bbe",
		"old_icon_sha256": "fc73af5e3e5ea68c97455bce47afcdad0cd4b20c42556ac150ca3ba8d4aa2b69",
		"old_sheet_sha256": "4a4f16f849f3c5f7430795b149a0e5ec87ff17470b058cff8f75c38ab4d5ffcf",
		"ability_ids": ["shielding"],
	},
]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	await _validate_battle_board_runtime()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "unit_count": UNITS.size(), "state_count": STATES.size(), "frames_per_state": FRAMES_PER_STATE, "runtime_entry_count": int(_report.get("runtime", {}).get("entry_count", 0))})])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_assets_and_provenance() -> void:
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var label := String(spec["label"])
		var source_path := String(spec["source_path"])
		var icon_path := String(spec["icon_path"])
		var sheet_path := String(spec["sheet_path"])
		var source: Image = _load_image(source_path)
		var icon: Image = _load_image(icon_path)
		var sheet: Image = _load_image(sheet_path)
		_expect(source != null and source.get_size() == Vector2i(512, 512), "%s curated source must load at 512x512." % label)
		_expect(icon != null and icon.get_size() == Vector2i(160, 160), "%s icon must load at 160x160." % label)
		_expect(sheet != null and sheet.get_size() == Vector2i(256, 896), "%s sheet must load at 256x896." % label)
		if source == null or icon == null or sheet == null:
			continue
		var source_alpha := _alpha_metrics(source)
		_expect(int(source_alpha.get("transparent", 0)) > 100000 and int(source_alpha.get("visible", 0)) > 50000 and int(source_alpha.get("opaque", 0)) > 40000, "%s source must retain transparent negative space and a materially opaque character silhouette." % label)
		_expect(bool(source_alpha.get("corners_transparent", false)), "%s source corners must remain transparent." % label)
		_expect(FileAccess.get_sha256(source_path) == String(spec["source_sha256"]), "%s source hash drifted." % label)
		_expect(FileAccess.get_sha256(icon_path) == String(spec["icon_sha256"]) and String(spec["icon_sha256"]) != String(spec["old_icon_sha256"]), "%s curated icon is not the exact replacement payload." % label)
		_expect(FileAccess.get_sha256(sheet_path) == String(spec["sheet_sha256"]) and String(spec["sheet_sha256"]) != String(spec["old_sheet_sha256"]), "%s curated sheet is not the exact replacement payload." % label)
		var art: Dictionary = ContentService.get_unit_art(String(spec["unit_id"]))
		var animation: Dictionary = ContentService.get_unit_animation(String(spec["unit_id"]))
		for record in [art, animation]:
			_expect(String(record.get("art_source_kind", "")) == "curated_original_character_v1", "%s manifest lost curated source kind." % label)
			_expect(String(record.get("curated_source", "")) == source_path, "%s manifest lost curated source path." % label)
			_expect(String(record.get("curated_source_sha256", "")) == String(spec["source_sha256"]), "%s manifest lost curated source hash." % label)
		_expect(String(art.get("battle_icon", "")) == icon_path, "%s runtime icon path changed." % label)
		_expect(String(animation.get("sprite_sheet", "")) == sheet_path and animation.get("states", []) == STATES, "%s runtime sheet/state contract changed." % label)
		var state_rows := []
		for state_index in range(STATES.size()):
			var signatures := {}
			var visible := 0
			for frame_index in range(FRAMES_PER_STATE):
				var frame: Image = sheet.get_region(Rect2i(Vector2i(frame_index * FRAME_SIZE.x, state_index * FRAME_SIZE.y), FRAME_SIZE))
				if int(_alpha_metrics(frame).get("visible", 0)) >= 350:
					visible += 1
				signatures[hash(frame.get_data())] = true
			_expect(visible == FRAMES_PER_STATE and signatures.size() >= 2, "%s state %s lost visible frame variation." % [label, STATES[state_index]])
			state_rows.append({"state": STATES[state_index], "visible_frames": visible, "unique_frames": signatures.size()})
		rows.append({"unit_id": spec["unit_id"], "source_sha256": spec["source_sha256"], "icon_sha256": spec["icon_sha256"], "sheet_sha256": spec["sheet_sha256"], "source_alpha": source_alpha, "states": state_rows})
	_report["assets"] = rows

func _validate_battle_board_runtime() -> void:
	var session := _session()
	SessionState.set_active_session(session)
	var board = BattleBoardViewScript.new()
	board.size = Vector2(900, 560)
	add_child(board)
	board.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary: Dictionary = board.validation_unit_art_summary()
	var entries := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var matches := []
		for entry in summary.get("stacks", []):
			if entry is Dictionary and String(entry.get("unit_id", "")) == String(spec["unit_id"]):
				matches.append(entry.duplicate(true))
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_report["runtime"] = {"entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0))}
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)

func _session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new("brasshollow-early-curated-art-report", "brasshollow-early-curated-art-report", "hero_report", 1, {}, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var rivet: Dictionary = BattleRulesScript._build_battle_stack("unit_brasshollow_rivet_hounds", 7, "player", 0, {"source_type": "brasshollow_early_curated_art_report"})
	var pavis: Dictionary = BattleRulesScript._build_battle_stack("unit_brasshollow_furnace_pavis_teams", 4, "player", 0, {"source_type": "brasshollow_early_curated_art_report"})
	var enemy: Dictionary = BattleRulesScript._build_battle_stack("unit_bog_brute", 7, "enemy", 0, {"source_type": "brasshollow_early_curated_art_report"})
	var stacks := [rivet, pavis, enemy]
	var ids := ["rivet_player", "pavis_player", "bog_enemy"]
	var sides := ["player", "player", "enemy"]
	var hexes := [{"q": 3, "r": 2}, {"q": 3, "r": 4}, {"q": 7, "r": 3}]
	for index in range(stacks.size()):
		stacks[index]["battle_id"] = ids[index]
		stacks[index]["side"] = sides[index]
		stacks[index]["hex"] = hexes[index]
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var stack: Dictionary = rivet if String(spec["unit_id"]) == "unit_brasshollow_rivet_hounds" else pavis
		var ability_ids := []
		for ability in stack.get("abilities", []):
			if ability is Dictionary:
				ability_ids.append(String(ability.get("id", "")))
		_expect(ability_ids == spec["ability_ids"], "%s runtime ability ids changed during the art-only slice." % String(spec["label"]))
	session.battle = {"round": 1, "max_rounds": 20, "distance": 1, "terrain": "plains", "battlefield_tags": [], "combat_seed": 10184, "stacks": stacks, "turn_order": ["rivet_player", "pavis_player"], "turn_index": 0, "active_stack_id": "rivet_player", "selected_target_id": "bog_enemy", "recent_events": [], "retreat_allowed": true, "surrender_allowed": true, "player_commander_state": {}, "enemy_hero": {}, BattleRulesScript.FIELD_OBJECTIVES_KEY: [], BattleRulesScript.STACK_ANIMATION_STATES_KEY: {}, BattleRulesScript.ANIMATION_EVENT_SERIAL_KEY: 0}
	BattleRulesScript._ensure_battle_hex_state(session.battle)
	return session

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
