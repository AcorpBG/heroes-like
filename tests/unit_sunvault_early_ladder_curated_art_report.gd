extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_SUNVAULT_EARLY_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_sunvault_early_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const TARGET_IDS := ["unit_sunvault_shard_wardens", "unit_sunvault_prism_adepts", "unit_sunvault_mirror_duelists"]
const UNITS := [
	{
		"unit_id": "unit_sunvault_shard_wardens", "label": "Shard Wardens", "ability_ids": ["shielding"],
		"source_path": "res://art/units/source/curated/unit_sunvault_shard_wardens.png", "portrait_path": "res://art/units/portraits/unit_sunvault_shard_wardens.png", "icon_path": "res://art/units/battle_icons/unit_sunvault_shard_wardens.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_sunvault_shard_wardens.png", "sheet_path": "res://art/animation/runtime/units/unit_sunvault_shard_wardens.png",
		"source_sha256": "8b5721abc52e6ba60237f84bc766434cb9b6c4b4ec1ecb66e36ecf584075821a", "portrait_sha256": "6b764f7953928a9c16536de6034a8c4489dc212d6a8d478adf90a4be00398b2f", "icon_sha256": "c67bd35661ec41e5d418d5f3a460263b75f48ac2107ac8d592be870f9662a828", "overworld_icon_sha256": "166ff2b95577da980e6cecd16e3cfa05cee4db3e6693ea85ade8d22dc0b05502", "sheet_sha256": "03975b8721e998b4157960c7dcfed3e2da69478312c46e05592ac070eeddd77c",
		"old_portrait_sha256": "3c16746cb3cc2f0eb2e7dbb6e2cb2d7aa5c6ac7d1dccb61dcba214dff448bbe6", "old_icon_sha256": "cdc96d5af8ab5e2a6742519c97fa5747bf3c8152eeebcf44b041aa35403208fd", "old_overworld_icon_sha256": "2d1f61dbedf5377047414a68ef0dd781676a3d440d8c0d123ed433585ad857ac", "old_sheet_sha256": "1a489717d3a588b0eb873feb63e40e7d74d8e19733e7670fc51205169cec93ea",
	},
	{
		"unit_id": "unit_sunvault_prism_adepts", "label": "Prism Adepts", "ability_ids": ["volley"],
		"source_path": "res://art/units/source/curated/unit_sunvault_prism_adepts.png", "portrait_path": "res://art/units/portraits/unit_sunvault_prism_adepts.png", "icon_path": "res://art/units/battle_icons/unit_sunvault_prism_adepts.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_sunvault_prism_adepts.png", "sheet_path": "res://art/animation/runtime/units/unit_sunvault_prism_adepts.png",
		"source_sha256": "71b5d4e1ee79e191e9032ffb3451e5ec398bbd37242bb325f96f96dfcb2c98b2", "portrait_sha256": "b9f5d46310e9912af434b01ebda9e4c82fb4fb438913ed993945c883b0874844", "icon_sha256": "bfcc0c3db10697bbcd238a80ca6231be8ed462397839e98f49c2ffa9fa3e6e36", "overworld_icon_sha256": "16315ed24b76dbae922e8c00687bc10193db7144f1621bceaeb4f6ca795069e9", "sheet_sha256": "06f438a00dbca30b16eed50e3886d78b7fd39aadc0c247c9d747ed90a46131c4",
		"old_portrait_sha256": "a68c122639dbbe1fce7871d6b4cfc38ba1ac5db568c2b9aa9fb41eae91feaf28", "old_icon_sha256": "3caad8054497bac6bd43eb51c361c82c09bac51a9ee557d046d0310ca9d27a77", "old_overworld_icon_sha256": "bb1e03d59f0c841c928bd663cade819eaf13855a503638722f1eb1a7a092d431", "old_sheet_sha256": "fb1b4f37afd970ee2931d736eba734b6e6e7476337365fc3951ebc18d7921785",
	},
	{
		"unit_id": "unit_sunvault_mirror_duelists", "label": "Mirror Duelists", "ability_ids": ["reach", "backstab"],
		"source_path": "res://art/units/source/curated/unit_sunvault_mirror_duelists.png", "portrait_path": "res://art/units/portraits/unit_sunvault_mirror_duelists.png", "icon_path": "res://art/units/battle_icons/unit_sunvault_mirror_duelists.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_sunvault_mirror_duelists.png", "sheet_path": "res://art/animation/runtime/units/unit_sunvault_mirror_duelists.png",
		"source_sha256": "3419a5ba83826bb78f37b2950d95302f9f575a1e276b24aacdbe48a727078a06", "portrait_sha256": "df279ae76c27858c942b2336b40e0306d5d55898d958c650be2fa88e4e1409d8", "icon_sha256": "7c93928367464f647ebb21c02286a43ab519fccb7d0c83d6a90b251aed82362e", "overworld_icon_sha256": "194f80558265b126b70affa773497ca58eee3a0f9712603b3b860a46ff8afd73", "sheet_sha256": "1383c95ca80ef17dfda7dfbdcbaad4591e2b0ed2500cc9d0c2d89f09e8e16158",
		"old_portrait_sha256": "683ad822ee64e98373f1671c00a88dc9c185b674408a01dd110146fe0b7e31cd", "old_icon_sha256": "314ad9df7ae7f6ac101f5426d389b8e10b5211b1a41c1bfb70615a7f37b52cd1", "old_overworld_icon_sha256": "84752b73365ec039aea143ca701164cc900e3bbc4ee0421caad276c3c69350fb", "old_sheet_sha256": "2932bada22217c1cf75bce4ffe0bf31bc7164abe2074007261d6fede5f1fff2d",
	},
]
const ENCOUNTERS := [
	{"scenario_id": "glassfen-breakers", "placement_id": "glassfen_relay_pickets", "army_id": "army_glassfen_relay_pickets_watch", "stacks": [{"unit_id": "unit_sunvault_shard_wardens", "count": 6}, {"unit_id": "unit_sunvault_prism_adepts", "count": 2}, {"unit_id": "unit_sunvault_mirror_duelists", "count": 1}]},
	{"scenario_id": "glassfen-breakers", "placement_id": "glassfen_glasswing_sortie", "army_id": "army_glassfen_glasswing_sortie_watch", "stacks": [{"unit_id": "unit_sunvault_prism_adepts", "count": 4}, {"unit_id": "unit_sunvault_shard_wardens", "count": 4}, {"unit_id": "unit_sunvault_mirror_duelists", "count": 1}]},
	{"scenario_id": "bellwake-wreck-claim", "placement_id": "bellwake_relay_pickets", "army_id": "army_bellwake_relay_pickets_watch", "stacks": [{"unit_id": "unit_sunvault_shard_wardens", "count": 9}, {"unit_id": "unit_sunvault_prism_adepts", "count": 7}, {"unit_id": "unit_sunvault_mirror_duelists", "count": 8}]},
	{"scenario_id": "ninefold-confluence", "placement_id": "ninefold_prism_matrix", "army_id": "army_ninefold_prism_matrix_watch", "stacks": [{"unit_id": "unit_sunvault_shard_wardens", "count": 6}, {"unit_id": "unit_sunvault_prism_adepts", "count": 2}, {"unit_id": "unit_sunvault_mirror_duelists", "count": 2}]},
	{"scenario_id": "fogchart-mooring", "placement_id": "fogchart_aurora_battery", "army_id": "army_fogchart_aurora_battery", "stacks": [{"unit_id": "unit_sunvault_shard_wardens", "count": 5}, {"unit_id": "unit_sunvault_prism_adepts", "count": 5}, {"unit_id": "unit_aurora_ballista", "count": 2}]},
	{"scenario_id": "charter-bastion-counterseal", "placement_id": "counterseal_relay_pickets", "army_id": "army_counterseal_relay_pickets", "stacks": [{"unit_id": "unit_sunvault_shard_wardens", "count": 7}, {"unit_id": "unit_sunvault_prism_adepts", "count": 5}, {"unit_id": "unit_sunvault_resonant_choristers", "count": 1}]},
	{"scenario_id": "charter-bastion-counterseal", "placement_id": "counterseal_mirror_lancers", "army_id": "army_counterseal_mirror_lancers", "stacks": [{"unit_id": "unit_sunvault_shard_wardens", "count": 6}, {"unit_id": "unit_sunvault_prism_adepts", "count": 5}, {"unit_id": "unit_sunvault_mirror_duelists", "count": 3}]},
	{"scenario_id": "charter-bastion-counterseal", "placement_id": "counterseal_aurora_battery", "army_id": "army_counterseal_aurora_battery", "stacks": [{"unit_id": "unit_sunvault_shard_wardens", "count": 5}, {"unit_id": "unit_sunvault_prism_adepts", "count": 2}, {"unit_id": "unit_sunvault_aurora_ballistae", "count": 1}]},
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
		if String(spec["placement_id"]) == "glassfen_relay_pickets":
			board_session = session
			board_payload = battle_payload
	_report["encounters"] = encounter_rows
	_expect(board_session != null and not board_payload.is_empty(), "Glassfen Board fixture must retain all three curated Sunvault units.")
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
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Glassfen stack." % String(unit_spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(unit_spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(unit_spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(unit_spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(unit_spec["label"]))
			entries.append(entry)
	_expect(board_session.to_dict() == board_authority_before, "BattleBoard art observation must not mutate the Glassfen battle/session.")
	_report["runtime"] = {"scenario_id": "glassfen-breakers", "placement_id": "glassfen_relay_pickets", "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": board_session.to_dict() == board_authority_before}
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
