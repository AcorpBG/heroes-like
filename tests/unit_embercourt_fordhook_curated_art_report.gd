extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_EMBERCOURT_FORDHOOK_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_embercourt_fordhook_curated_art_report"
const UNIT_ID := "unit_embercourt_fordhook_cadets"
const SOURCE_PATH := "res://art/units/source/curated/unit_embercourt_fordhook_cadets.png"
const BATTLE_ICON_PATH := "res://art/units/battle_icons/unit_embercourt_fordhook_cadets.png"
const ANIMATION_PATH := "res://art/animation/runtime/units/unit_embercourt_fordhook_cadets.png"
const SOURCE_SHA256 := "e9eddd43ef9b1b1a44a40fd609676bb31c8db90cd612a17bb3e87aef0fce6ff4"
const BATTLE_ICON_SHA256 := "9ed1ac039d88abfd06d83ad1bcf7e5b970df999d245010be651b3cc3b96e1d87"
const ANIMATION_SHA256 := "1aa44e4b02fd4177b0d9980f19fe3d00c38865083e96fab1bec0166a6b6382a8"
const PREVIOUS_ABSTRACT_BATTLE_ICON_SHA256 := "7d0c43a207f7adbb4641ae9b2729b5bfeab7b828d8d675d22879c761081b2851"
const PREVIOUS_ABSTRACT_ANIMATION_SHA256 := "668a50c68087b09ab4c3e245d965faa7a4f205ae3f812f8d8114ac3e7bb07576"
const EXPECTED_SOURCE_SIZE := Vector2i(512, 512)
const EXPECTED_BATTLE_ICON_SIZE := Vector2i(160, 160)
const EXPECTED_FRAME_SIZE := Vector2i(64, 64)
const EXPECTED_FRAMES_PER_STATE := 4
const EXPECTED_STATE_NAMES := [
	"idle_hold",
	"ready_active",
	"move_path_step",
	"melee_windup_release",
	"ranged_aim_release",
	"hit_stagger",
	"death_rout_remove",
	"cast_support_anchor",
	"status_applied",
	"status_expired",
	"defend_brace",
	"retaliation_release",
	"retreat_withdraw_column",
	"surrender_stand_down",
]

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"source": {},
	"battle_icon": {},
	"animation": {},
	"runtime": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_source_and_manifest_provenance()
	_validate_battle_icon()
	_validate_animation_sheet()
	await _validate_runtime_board_ownership()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_source_and_manifest_provenance() -> void:
	var source: Image = _load_image(SOURCE_PATH)
	_expect(source != null, "Fordhook curated source failed to load.")
	if source == null:
		return
	_expect(source.get_size() == EXPECTED_SOURCE_SIZE, "Fordhook curated source must be 512x512.")
	_expect(FileAccess.get_sha256(SOURCE_PATH) == SOURCE_SHA256, "Fordhook curated source hash drifted.")
	var alpha_metrics := _alpha_metrics(source)
	_expect(int(alpha_metrics.get("transparent_pixels", 0)) > 100000, "Fordhook curated source needs transparent negative space.")
	_expect(int(alpha_metrics.get("opaque_pixels", 0)) > 50000, "Fordhook curated source needs a substantial opaque character silhouette.")
	_expect(bool(alpha_metrics.get("corners_transparent", false)), "Fordhook curated source corners must stay transparent.")

	var art_record: Dictionary = ContentService.get_unit_art(UNIT_ID)
	var animation_record: Dictionary = ContentService.get_unit_animation(UNIT_ID)
	for record in [art_record, animation_record]:
		_expect(String(record.get("art_source_kind", "")) == "curated_original_character_v1", "Fordhook manifest record lost curated source kind.")
		_expect(String(record.get("curated_source", "")) == SOURCE_PATH, "Fordhook manifest record lost curated source path.")
		_expect(String(record.get("curated_source_sha256", "")) == SOURCE_SHA256, "Fordhook manifest record lost curated source hash.")
	_expect(String(art_record.get("battle_icon", "")) == BATTLE_ICON_PATH, "Fordhook battle icon runtime path changed.")
	_expect(String(animation_record.get("sprite_sheet", "")) == ANIMATION_PATH, "Fordhook animation runtime path changed.")
	_expect(animation_record.get("states", []) == EXPECTED_STATE_NAMES, "Fordhook animation state order changed.")
	_report["source"] = {
		"path": SOURCE_PATH,
		"sha256": FileAccess.get_sha256(SOURCE_PATH),
		"size": source.get_size(),
		"alpha": alpha_metrics,
		"manifest_provenance_exact": true,
	}

func _validate_battle_icon() -> void:
	var icon: Image = _load_image(BATTLE_ICON_PATH)
	_expect(icon != null, "Fordhook curated battle icon failed to load.")
	if icon == null:
		return
	var hash := FileAccess.get_sha256(BATTLE_ICON_PATH)
	var alpha_metrics := _alpha_metrics(icon)
	_expect(icon.get_size() == EXPECTED_BATTLE_ICON_SIZE, "Fordhook battle icon must remain 160x160.")
	_expect(hash == BATTLE_ICON_SHA256, "Fordhook curated battle icon is not reproducible.")
	_expect(hash != PREVIOUS_ABSTRACT_BATTLE_ICON_SHA256, "Fordhook battle icon still uses the previous abstract payload.")
	_expect(int(alpha_metrics.get("opaque_pixels", 0)) > 5000, "Fordhook battle icon character surface is too sparse.")
	_expect(bool(alpha_metrics.get("corners_transparent", false)), "Fordhook battle icon corners must remain transparent.")
	_report["battle_icon"] = {
		"path": BATTLE_ICON_PATH,
		"sha256": hash,
		"previous_abstract_replaced": hash != PREVIOUS_ABSTRACT_BATTLE_ICON_SHA256,
		"size": icon.get_size(),
		"alpha": alpha_metrics,
	}

func _validate_animation_sheet() -> void:
	var sheet: Image = _load_image(ANIMATION_PATH)
	_expect(sheet != null, "Fordhook curated animation sheet failed to load.")
	if sheet == null:
		return
	var expected_sheet_size := Vector2i(
		EXPECTED_FRAME_SIZE.x * EXPECTED_FRAMES_PER_STATE,
		EXPECTED_FRAME_SIZE.y * EXPECTED_STATE_NAMES.size()
	)
	var hash := FileAccess.get_sha256(ANIMATION_PATH)
	_expect(sheet.get_size() == expected_sheet_size, "Fordhook animation sheet dimensions changed.")
	_expect(hash == ANIMATION_SHA256, "Fordhook curated animation sheet is not reproducible.")
	_expect(hash != PREVIOUS_ABSTRACT_ANIMATION_SHA256, "Fordhook animation sheet still uses the previous abstract payload.")
	var state_rows := []
	for state_index in range(EXPECTED_STATE_NAMES.size()):
		var frame_signatures := {}
		var visible_frame_count := 0
		for frame_index in range(EXPECTED_FRAMES_PER_STATE):
			var frame: Image = sheet.get_region(Rect2i(
				Vector2i(frame_index * EXPECTED_FRAME_SIZE.x, state_index * EXPECTED_FRAME_SIZE.y),
				EXPECTED_FRAME_SIZE
			))
			var metrics := _alpha_metrics(frame)
			if int(metrics.get("visible_pixels", 0)) >= 350:
				visible_frame_count += 1
			frame_signatures[hash(frame.get_data())] = true
		_expect(visible_frame_count == EXPECTED_FRAMES_PER_STATE, "Fordhook state %s contains a blank/sparse frame." % EXPECTED_STATE_NAMES[state_index])
		_expect(frame_signatures.size() >= 2, "Fordhook state %s does not animate across frames." % EXPECTED_STATE_NAMES[state_index])
		state_rows.append({
			"state": EXPECTED_STATE_NAMES[state_index],
			"visible_frame_count": visible_frame_count,
			"unique_frame_count": frame_signatures.size(),
		})
	_report["animation"] = {
		"path": ANIMATION_PATH,
		"sha256": hash,
		"previous_abstract_replaced": hash != PREVIOUS_ABSTRACT_ANIMATION_SHA256,
		"size": sheet.get_size(),
		"state_count": EXPECTED_STATE_NAMES.size(),
		"frames_per_state": EXPECTED_FRAMES_PER_STATE,
		"states": state_rows,
	}

func _validate_runtime_board_ownership() -> void:
	var session := _session_for_fordhook()
	SessionState.set_active_session(session)
	var board = BattleBoardViewScript.new()
	board.size = Vector2(900, 560)
	add_child(board)
	board.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary: Dictionary = board.validation_unit_art_summary()
	var target_entries := []
	for entry in summary.get("stacks", []):
		if entry is Dictionary and String(entry.get("unit_id", "")) == UNIT_ID:
			target_entries.append(entry.duplicate(true))
	_expect(target_entries.size() == 1, "BattleBoard must expose exactly one focused Fordhook stack.")
	if target_entries.size() == 1:
		var entry: Dictionary = target_entries[0]
		_expect(bool(entry.get("loaded", false)), "BattleBoard did not load the Fordhook curated battle icon.")
		_expect(bool(entry.get("animation_loaded", false)), "BattleBoard did not load the Fordhook curated animation sheet.")
		_expect(String(entry.get("battle_icon", "")) == BATTLE_ICON_PATH, "BattleBoard Fordhook icon path drifted.")
		_expect(String(entry.get("animation_sheet", "")) == ANIMATION_PATH, "BattleBoard Fordhook animation path drifted.")
	_report["runtime"] = {
		"target_entry_count": target_entries.size(),
		"target_entries": target_entries,
		"visible_stack_count": int(summary.get("visible_stack_count", 0)),
		"battle_icon_loaded_count": int(summary.get("battle_icon_loaded_count", 0)),
		"animation_sheet_loaded_count": int(summary.get("animation_sheet_loaded_count", 0)),
	}
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)

func _session_for_fordhook() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"fordhook-curated-art-report",
		"fordhook-curated-art-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var player_stack: Dictionary = BattleRulesScript._build_battle_stack(
		UNIT_ID,
		7,
		"player",
		0,
		{"source_type": "fordhook_curated_art_report"}
	)
	player_stack["battle_id"] = "fordhook_player"
	player_stack["side"] = "player"
	player_stack["hex"] = {"q": 3, "r": 3}
	var enemy_stack: Dictionary = BattleRulesScript._build_battle_stack(
		"unit_bog_brute",
		7,
		"enemy",
		0,
		{"source_type": "fordhook_curated_art_report"}
	)
	enemy_stack["battle_id"] = "bog_enemy"
	enemy_stack["side"] = "enemy"
	enemy_stack["hex"] = {"q": 7, "r": 3}
	session.battle = {
		"round": 1,
		"max_rounds": 20,
		"distance": 1,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 10184,
		"stacks": [player_stack, enemy_stack],
		"turn_order": ["fordhook_player"],
		"turn_index": 0,
		"active_stack_id": "fordhook_player",
		"selected_target_id": "bog_enemy",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		BattleRulesScript.FIELD_OBJECTIVES_KEY: [],
		BattleRulesScript.STACK_ANIMATION_STATES_KEY: {},
		BattleRulesScript.ANIMATION_EVENT_SERIAL_KEY: 0,
	}
	BattleRulesScript._ensure_battle_hex_state(session.battle)
	return session

func _alpha_metrics(image: Image) -> Dictionary:
	var transparent_pixels := 0
	var opaque_pixels := 0
	var visible_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha <= 0.001:
				transparent_pixels += 1
			else:
				visible_pixels += 1
				if alpha >= 0.999:
					opaque_pixels += 1
	var max_x := image.get_width() - 1
	var max_y := image.get_height() - 1
	return {
		"transparent_pixels": transparent_pixels,
		"opaque_pixels": opaque_pixels,
		"visible_pixels": visible_pixels,
		"corners_transparent": (
			image.get_pixel(0, 0).a <= 0.001
			and image.get_pixel(max_x, 0).a <= 0.001
			and image.get_pixel(0, max_y).a <= 0.001
			and image.get_pixel(max_x, max_y).a <= 0.001
		),
	}

func _load_image(path: String) -> Image:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _summary_payload() -> Dictionary:
	return {
		"ok": _errors.is_empty(),
		"source_sha256": SOURCE_SHA256,
		"battle_icon_sha256": BATTLE_ICON_SHA256,
		"animation_sha256": ANIMATION_SHA256,
		"state_count": EXPECTED_STATE_NAMES.size(),
		"frames_per_state": EXPECTED_FRAMES_PER_STATE,
		"runtime_target_entry_count": int(_report.get("runtime", {}).get("target_entry_count", 0)),
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error(message)

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_errors.append("Failed to write report: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t") + "\n")
