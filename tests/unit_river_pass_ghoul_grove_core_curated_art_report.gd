extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_RIVER_PASS_GHOUL_GROVE_CORE_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_river_pass_ghoul_grove_core_curated_art_report"
const SCENARIO_ID := "river-pass"
const PLACEMENT_ID := "river_pass_ghoul_grove"
const LOCAL_ARMY_ID := "army_river_pass_ghoul_grove_watch"
const SHARED_ARMY_ID := "army_blackbranch_raiders"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_blackbranch_cutthroat", "label": "Blackbranch Cutthroat", "count": 8, "shared_count": 11,
		"source_path": "res://art/units/source/curated/unit_blackbranch_cutthroat.png", "portrait_path": "res://art/units/portraits/unit_blackbranch_cutthroat.png", "icon_path": "res://art/units/battle_icons/unit_blackbranch_cutthroat.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_blackbranch_cutthroat.png", "sheet_path": "res://art/animation/runtime/units/unit_blackbranch_cutthroat.png",
		"source_sha256": "eb0af47ab0292c278335f76092420e9dba0073c84f3507f0b0d11b85b50fa143", "portrait_sha256": "1fbc28056c6e891c777e3db21b0c2281eb797fd47099747ed79ba17df9d17643", "icon_sha256": "170f13ace6d36b528ce492227af28f24fd5ce307b458f7008e6a731bd1f0d82e", "overworld_icon_sha256": "a450211867d43e4b73b0e0928624fe9f5ac26ace2424d00e3cb487940538d0a6", "sheet_sha256": "6a5f8443d3b7882a2638f7bb9c5d4426497506fc5f3cd665102b9aeafff33c87",
		"old_portrait_sha256": "0d3181b05fab185f8ab5b581a9ec260475bc0fc76178d71184efd349c517edd8", "old_icon_sha256": "e0fb7087076d30bc493d9778660ca58462ec996f2dc5915ddcb5a23672845922", "old_overworld_icon_sha256": "77940bc17eee95be85453e9aeeab5766a88c3469a18494b0387b1acf6685c745", "old_sheet_sha256": "38bbbdadfc558f7b8370783eaad1b5829dfb64e18e04ee22db7bfe1bcea05310", "ability_ids": ["backstab"],
	},
	{
		"unit_id": "unit_mire_slinger", "label": "Mire Slinger", "count": 17, "shared_count": 6,
		"source_path": "res://art/units/source/curated/unit_mire_slinger.png", "portrait_path": "res://art/units/portraits/unit_mire_slinger.png", "icon_path": "res://art/units/battle_icons/unit_mire_slinger.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_mire_slinger.png", "sheet_path": "res://art/animation/runtime/units/unit_mire_slinger.png",
		"source_sha256": "21b98fd2f90d738b168ddb0b1b160dc6c8c731dd7a590d848255175589ac2c55", "portrait_sha256": "aa6f1fd3000a589fcfb6bf03224cb375730b435ba7ff124f36937b009c834af4", "icon_sha256": "905e3d7af90ec7f95206d6bdc2ace68df79cc14d3ac87c9f51cd4f17b259c5f4", "overworld_icon_sha256": "2e9a3b15e91f0d9d0c9efe15ae0e9a4e0c571cd9165b70df74f34cff1b381bd0", "sheet_sha256": "e3fecd429cf8b8ec5ef59afff7335840f7179ed96ee7c8719c135e9c80d7b16e",
		"old_portrait_sha256": "457045b182834012fff2e087754f0b7b2279a328421eb2a45a22690a364897c6", "old_icon_sha256": "2fa2c5cb412652c541149e516ae9d42afe5dd76abb167a9cf8b45f76e49284cc", "old_overworld_icon_sha256": "2ebf62da57fcfa868c567df9f4640531554f7c8fa7a60cbc9950267e6f2edf31", "old_sheet_sha256": "827f73307e1a7294b10ff6b8ff47f0b20c1f474f00dd685e9149ff4490704abd", "ability_ids": ["harry"],
	},
	{
		"unit_id": "unit_bog_brute", "label": "Bog Brute", "count": 2, "shared_count": 2,
		"source_path": "res://art/units/source/curated/unit_bog_brute.png", "portrait_path": "res://art/units/portraits/unit_bog_brute.png", "icon_path": "res://art/units/battle_icons/unit_bog_brute.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_bog_brute.png", "sheet_path": "res://art/animation/runtime/units/unit_bog_brute.png",
		"source_sha256": "6e971e93ab527beff8702d16ffe4e69b4e40a8e4b63ff9fe1d3411f8d2daea85", "portrait_sha256": "25a6ad9fef1f54b4c64ce5ed6e26129f4b665d438214724853ccd7145f1e8661", "icon_sha256": "7f45f2824f16d1fd9f884f430221cb3e329b0d6a5a211193620d2b73ef291410", "overworld_icon_sha256": "acb0c66d430682bb68754af61572e75088e8890159f5f9031078f320ec1aadf7", "sheet_sha256": "709c79ae82d281db4da8119c36a9a93f16422856bf2ee3b6942710b56582516b",
		"old_portrait_sha256": "7698c3d3d7128becaa8f72a66999bfbed3af527a3fa939ebedc09fb65af020c3", "old_icon_sha256": "a449fc32476bbab0f74d408d3c7034e974d93c7f86ebc7c10ea5471aa999435c", "old_overworld_icon_sha256": "d8839c0e759d1f1690066a8dba82b25a7a8e841e7f2fa640b7af6308021ea279", "old_sheet_sha256": "61722a60abcf0b05356c0b624c03729cba89029c56642b020e477349d28777ed", "ability_ids": ["shielding"],
	},
]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	await _validate_live_ghoul_grove_battle_board()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "unit_count": UNITS.size(), "state_count": STATES.size(), "frames_per_state": FRAMES_PER_STATE, "visible_frame_count": UNITS.size() * STATES.size() * FRAMES_PER_STATE, "runtime_entry_count": int(_report.get("runtime", {}).get("entry_count", 0))})])
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
		_expect(source != null and source.get_size() == Vector2i(512, 512), "%s curated source must load at 512x512." % label)
		_expect(portrait != null and portrait.get_size() == Vector2i(384, 512), "%s portrait must load at 384x512." % label)
		_expect(icon != null and icon.get_size() == Vector2i(160, 160), "%s battle icon must load at 160x160." % label)
		_expect(overworld_icon != null and overworld_icon.get_size() == Vector2i(96, 96), "%s overworld icon must load at 96x96." % label)
		_expect(sheet != null and sheet.get_size() == Vector2i(256, 896), "%s sheet must load at 256x896." % label)
		if source == null or portrait == null or icon == null or overworld_icon == null or sheet == null:
			continue
		var source_alpha := _alpha_metrics(source)
		_expect(int(source_alpha.get("transparent", 0)) > 50000 and int(source_alpha.get("visible", 0)) > 40000 and int(source_alpha.get("opaque", 0)) > 35000, "%s source must retain transparent negative space and a materially opaque character silhouette." % label)
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
		rows.append({"unit_id": spec["unit_id"], "source_sha256": spec["source_sha256"], "portrait_sha256": spec["portrait_sha256"], "icon_sha256": spec["icon_sha256"], "overworld_icon_sha256": spec["overworld_icon_sha256"], "sheet_sha256": spec["sheet_sha256"], "source_alpha": source_alpha, "states": state_rows})
	_report["assets"] = rows

func _validate_live_ghoul_grove_battle_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var placement := _encounter_placement(session)
	_expect(not placement.is_empty() and String(placement.get("placement_id", "")) == PLACEMENT_ID, "River Pass must retain the Ghoul Grove encounter placement.")
	var local_army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
	var expected_local := {"unit_blackbranch_cutthroat": 8, "unit_mire_slinger": 17, "unit_bog_brute": 2, "unit_mireclaw_mudglass_slingers": 1}
	var expected_shared := {"unit_blackbranch_cutthroat": 11, "unit_mire_slinger": 6, "unit_bog_brute": 2}
	_expect(String(local_army.get("id", "")) == LOCAL_ARMY_ID and _stack_counts(local_army) == expected_local, "Ghoul Grove placement-local army ids/order/counts changed.")
	var shared_army: Dictionary = ContentService.get_army_group(SHARED_ARMY_ID)
	_expect(String(shared_army.get("id", "")) == SHARED_ARMY_ID and _stack_counts(shared_army) == expected_shared, "Shared Blackbranch Raiders ids/counts changed.")
	var battle_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	var enemy_stacks: Array = battle_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_counts(enemy_stacks) == expected_local, "Public Ghoul Grove battle payload changed its exact enemy roster.")
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var matches: Array = enemy_stacks.filter(func(stack): return String(stack.get("unit_id", "")) == String(spec["unit_id"]))
		_expect(matches.size() == 1 and int(matches[0].get("base_count", -1)) == int(spec["count"]), "%s public battle stack count changed." % String(spec["label"]))
		if matches.size() == 1:
			var ability_ids := []
			for ability in matches[0].get("abilities", []):
				if ability is Dictionary:
					ability_ids.append(String(ability.get("id", "")))
			_expect(ability_ids == spec["ability_ids"], "%s public battle ability ids changed during the art-only slice." % String(spec["label"]))
	var mudglass_matches: Array = enemy_stacks.filter(func(stack): return String(stack.get("unit_id", "")) == "unit_mireclaw_mudglass_slingers")
	_expect(mudglass_matches.size() == 1 and int(mudglass_matches[0].get("base_count", -1)) == 1, "Ghoul Grove production Mudglass control stack changed.")
	session.battle = battle_payload
	var authority_before: Dictionary = session.to_dict()
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
			if entry is Dictionary and String(entry.get("side", "enemy")) != "player" and String(entry.get("unit_id", "")) == String(spec["unit_id"]):
				matches.append(entry.duplicate(true))
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Ghoul Grove stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_expect(session.to_dict() == authority_before, "BattleBoard art observation must not mutate the live Ghoul Grove battle/session.")
	_report["runtime"] = {"scenario_id": SCENARIO_ID, "placement_id": PLACEMENT_ID, "local_army_id": LOCAL_ARMY_ID, "shared_army_id": SHARED_ARMY_ID, "enemy_stack_counts": _battle_stack_counts(enemy_stacks), "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == authority_before}
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)

func _encounter_placement(session: SessionStateStoreScript.SessionData) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == PLACEMENT_ID:
			return encounter
	return {}

func _stack_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts

func _battle_stack_counts(stacks: Array) -> Dictionary:
	var counts := {}
	for stack in stacks:
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("base_count", 0))
	return counts

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
