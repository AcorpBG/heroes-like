extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_BRASSHOLLOW_SCRIP_HAULERS_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_brasshollow_scrip_haulers_curated_art_report"
const UNIT_ID := "unit_brasshollow_scrip_haulers"
const SOURCE_PATH := "res://art/units/source/curated/unit_brasshollow_scrip_haulers.png"
const ICON_PATH := "res://art/units/battle_icons/unit_brasshollow_scrip_haulers.png"
const SHEET_PATH := "res://art/animation/runtime/units/unit_brasshollow_scrip_haulers.png"
const SOURCE_SHA256 := "759022e21b7781df3c88ba853b32905b52a820cafe45d2814a2006629d26e028"
const ICON_SHA256 := "60ce46eee94ee9c180155bdcdc3fdb46e9ef4940e058007d36225856d4877c8c"
const SHEET_SHA256 := "2a20a26526eca2e50591c45cb4f0a07cfebfb310813cbf16832f1a59a6a052ae"
const OLD_ICON_SHA256 := "94970bfed26ba60b29d27bf1f20a1a5182cbecae3fa61a2db5d720a33b239776"
const OLD_SHEET_SHA256 := "16e0441527706acc743bfb7bcc2d728f0dd72de086de8d5729fb2135bfa05fae"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": {}, "runtime": {}, "errors": []}

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
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "source_sha256": SOURCE_SHA256, "icon_sha256": ICON_SHA256, "sheet_sha256": SHEET_SHA256, "state_count": STATES.size(), "frames_per_state": FRAMES_PER_STATE, "runtime_entry_count": int(_report.get("runtime", {}).get("entry_count", 0))})])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_assets_and_provenance() -> void:
	var source: Image = _load_image(SOURCE_PATH)
	var icon: Image = _load_image(ICON_PATH)
	var sheet: Image = _load_image(SHEET_PATH)
	_expect(source != null and source.get_size() == Vector2i(512, 512), "Scrip Haulers curated source must load at 512x512.")
	_expect(icon != null and icon.get_size() == Vector2i(160, 160), "Scrip Haulers icon must load at 160x160.")
	_expect(sheet != null and sheet.get_size() == Vector2i(256, 896), "Scrip Haulers sheet must load at 256x896.")
	if source == null or icon == null or sheet == null:
		return
	var source_alpha := _alpha_metrics(source)
	_expect(int(source_alpha.get("transparent", 0)) > 100000 and int(source_alpha.get("opaque", 0)) > 50000, "Scrip Haulers source must retain transparent negative space and an opaque character silhouette.")
	_expect(bool(source_alpha.get("corners_transparent", false)), "Scrip Haulers source corners must remain transparent.")
	_expect(FileAccess.get_sha256(SOURCE_PATH) == SOURCE_SHA256, "Scrip Haulers source hash drifted.")
	_expect(FileAccess.get_sha256(ICON_PATH) == ICON_SHA256 and ICON_SHA256 != OLD_ICON_SHA256, "Scrip Haulers curated icon is not the exact replacement payload.")
	_expect(FileAccess.get_sha256(SHEET_PATH) == SHEET_SHA256 and SHEET_SHA256 != OLD_SHEET_SHA256, "Scrip Haulers curated sheet is not the exact replacement payload.")
	var art: Dictionary = ContentService.get_unit_art(UNIT_ID)
	var animation: Dictionary = ContentService.get_unit_animation(UNIT_ID)
	for record in [art, animation]:
		_expect(String(record.get("art_source_kind", "")) == "curated_original_character_v1", "Scrip Haulers manifest lost curated source kind.")
		_expect(String(record.get("curated_source", "")) == SOURCE_PATH, "Scrip Haulers manifest lost curated source path.")
		_expect(String(record.get("curated_source_sha256", "")) == SOURCE_SHA256, "Scrip Haulers manifest lost curated source hash.")
	_expect(String(art.get("battle_icon", "")) == ICON_PATH, "Scrip Haulers runtime icon path changed.")
	_expect(String(animation.get("sprite_sheet", "")) == SHEET_PATH and animation.get("states", []) == STATES, "Scrip Haulers runtime sheet/state contract changed.")
	var state_rows := []
	for state_index in range(STATES.size()):
		var signatures := {}
		var visible := 0
		for frame_index in range(FRAMES_PER_STATE):
			var frame: Image = sheet.get_region(Rect2i(Vector2i(frame_index * FRAME_SIZE.x, state_index * FRAME_SIZE.y), FRAME_SIZE))
			if int(_alpha_metrics(frame).get("visible", 0)) >= 350:
				visible += 1
			signatures[hash(frame.get_data())] = true
		_expect(visible == FRAMES_PER_STATE and signatures.size() >= 2, "Scrip Haulers state %s lost visible frame variation." % STATES[state_index])
		state_rows.append({"state": STATES[state_index], "visible_frames": visible, "unique_frames": signatures.size()})
	_report["assets"] = {"source_sha256": SOURCE_SHA256, "icon_sha256": ICON_SHA256, "sheet_sha256": SHEET_SHA256, "source_alpha": source_alpha, "states": state_rows}

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
	for entry in summary.get("stacks", []):
		if entry is Dictionary and String(entry.get("unit_id", "")) == UNIT_ID:
			entries.append(entry.duplicate(true))
	_expect(entries.size() == 1, "BattleBoard must expose exactly one Scrip Haulers stack.")
	if entries.size() == 1:
		var entry: Dictionary = entries[0]
		_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == ICON_PATH, "BattleBoard did not load the exact Scrip Haulers icon.")
		_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == SHEET_PATH, "BattleBoard did not load the exact Scrip Haulers sheet.")
	_report["runtime"] = {"entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0))}
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)

func _session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new("scrip-curated-art-report", "scrip-curated-art-report", "hero_report", 1, {}, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var scrip: Dictionary = BattleRulesScript._build_battle_stack(UNIT_ID, 8, "player", 0, {"source_type": "scrip_curated_art_report"})
	scrip["battle_id"] = "scrip_player"
	scrip["side"] = "player"
	scrip["hex"] = {"q": 3, "r": 3}
	var enemy: Dictionary = BattleRulesScript._build_battle_stack("unit_bog_brute", 7, "enemy", 0, {"source_type": "scrip_curated_art_report"})
	enemy["battle_id"] = "bog_enemy"
	enemy["side"] = "enemy"
	enemy["hex"] = {"q": 7, "r": 3}
	session.battle = {"round": 1, "max_rounds": 20, "distance": 1, "terrain": "plains", "battlefield_tags": [], "combat_seed": 10184, "stacks": [scrip, enemy], "turn_order": ["scrip_player"], "turn_index": 0, "active_stack_id": "scrip_player", "selected_target_id": "bog_enemy", "recent_events": [], "retreat_allowed": true, "surrender_allowed": true, "player_commander_state": {}, "enemy_hero": {}, BattleRulesScript.FIELD_OBJECTIVES_KEY: [], BattleRulesScript.STACK_ANIMATION_STATES_KEY: {}, BattleRulesScript.ANIMATION_EVENT_SERIAL_KEY: 0}
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
