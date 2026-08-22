extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_MIRECLAW_EARLY_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_mireclaw_early_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_mireclaw_reedsnare_kin", "label": "Reedsnare Kin", "ability_ids": ["harry"],
		"source_path": "res://art/units/source/curated/unit_mireclaw_reedsnare_kin.png", "portrait_path": "res://art/units/portraits/unit_mireclaw_reedsnare_kin.png", "icon_path": "res://art/units/battle_icons/unit_mireclaw_reedsnare_kin.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_mireclaw_reedsnare_kin.png", "sheet_path": "res://art/animation/runtime/units/unit_mireclaw_reedsnare_kin.png",
		"source_sha256": "f13f170113fe2d8ae0ccd354c8332ba293e376c764f95d2c7de491ccf8b4c68c", "portrait_sha256": "de351dd6a31c66fdecaa968a9585ca89c200d5c4675acf0fc8482d6bff3b82db", "icon_sha256": "5ccfd386ead4d0d09cb9f98110b447f246b52c32731843eac49eec8bf55d417a", "overworld_icon_sha256": "7e1ce98553a7d2f4cc4430ab68b9b48d918a734df45a1bd671688494fe0a7135", "sheet_sha256": "362464d9e7587bd0ac8c3a2cd6bbc19467e4bcd8363c16939a98ae1ad0ad1dbc",
		"old_portrait_sha256": "04b988d594c1eb6b7a3441e925eb877fcfaa2b5b35c1f36d4643bbc83aa0050d", "old_icon_sha256": "e27a9179bddcb4e24dc46fcf7d4392edfd0f0363d5ab321800ff09b5e50b9aec", "old_overworld_icon_sha256": "865f75b3019b4b75e613ae87f050b0d0702a53ab58f04f96f821463c4d8b147a", "old_sheet_sha256": "c2968af60cc5a57cea78aafbafee7be44bfb62e02931095ad043a85e3ba1af9b",
	},
	{
		"unit_id": "unit_mireclaw_mudglass_slingers", "label": "Mudglass Slingers", "ability_ids": ["harry"],
		"source_path": "res://art/units/source/curated/unit_mireclaw_mudglass_slingers.png", "portrait_path": "res://art/units/portraits/unit_mireclaw_mudglass_slingers.png", "icon_path": "res://art/units/battle_icons/unit_mireclaw_mudglass_slingers.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_mireclaw_mudglass_slingers.png", "sheet_path": "res://art/animation/runtime/units/unit_mireclaw_mudglass_slingers.png",
		"source_sha256": "838808890927847fecb1e74c9bf1fde0a1bb434927b40152ed6b2e849874aaf5", "portrait_sha256": "46ef6708018099cb9ec71439eb86144af3ff4719190c9c4792208e2c4f646734", "icon_sha256": "a6f3bee140a6324879e2cf80581267529a6088fc64f70dd4092e8c4d2ce75008", "overworld_icon_sha256": "f3a044e380a5f4cd12a6001e85c66a4184f500a5914631f8b6220d07e3d5abc6", "sheet_sha256": "ce95c827903ec85065093bb110e857b98e88a8dd1f1f441738d4d36cdbbba1c8",
		"old_portrait_sha256": "8e4740a1f5426fae61673d09e542a27904b9c7f14e06a89a4882bf9e4dd1f9fd", "old_icon_sha256": "6e378a836d59de2dba7615c9ccd74219f8a9a7bfd851c8a3dd8361ae61635b6f", "old_overworld_icon_sha256": "bb20212ceddaaa2f63f614dc5d52c8a7d43f01e658f3ebbd86435211598a12b2", "old_sheet_sha256": "568547f0eeefb900c38bcd015d627dd9b1a0c418d37dec89018e4cb6644db164",
	},
	{
		"unit_id": "unit_mireclaw_bogplate_maulers", "label": "Bogplate Maulers", "ability_ids": ["shielding"],
		"source_path": "res://art/units/source/curated/unit_mireclaw_bogplate_maulers.png", "portrait_path": "res://art/units/portraits/unit_mireclaw_bogplate_maulers.png", "icon_path": "res://art/units/battle_icons/unit_mireclaw_bogplate_maulers.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_mireclaw_bogplate_maulers.png", "sheet_path": "res://art/animation/runtime/units/unit_mireclaw_bogplate_maulers.png",
		"source_sha256": "c77d8b089bf4a8aa352825621db0a65efac291bb5ada040a67feb13d73150ecd", "portrait_sha256": "579311b6d40327d62ec8fa5656f1cc0603a64bc03aad08735bea60eb271ec07b", "icon_sha256": "9b7b6a0ee7e9eb562e138f7a9f8c9ca6a5c5b5915c87cbe47cc75e8fc6dad16f", "overworld_icon_sha256": "7dda59077c755bb3a35d34602005b22018cf3f4c5b69fce94b5d5caf7e44a6f8", "sheet_sha256": "f377cf60369681cf214564de0348648107f662804f251f9e698dee0fcf7e18d5",
		"old_portrait_sha256": "094d4afce534381caa7480515256b51a605ca4f2e21b932b4949fe117827d898", "old_icon_sha256": "0fffdb46dca17b1b1f03bb38fcb4c372937431a30bab3b7d7e3ef61b3b6b6869", "old_overworld_icon_sha256": "3b2cc46c17e6c6a4d56d4386f4107872f52219ef09b391b546d7dd8181b0816b", "old_sheet_sha256": "1481ba8b4896025fcd7e4dd676369118d26546eb0d36ffcfcb3cce49bf9f7c17",
	},
]
const ENCOUNTERS := [
	{
		"scenario_id": "river-pass", "launch_mode": SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN, "placement_id": "river_pass_ghoul_grove", "army_id": "army_river_pass_ghoul_grove_watch",
		"stacks": [{"unit_id": "unit_blackbranch_cutthroat", "count": 8}, {"unit_id": "unit_mire_slinger", "count": 17}, {"unit_id": "unit_bog_brute", "count": 2}, {"unit_id": "unit_mireclaw_mudglass_slingers", "count": 1}],
	},
	{
		"scenario_id": "river-pass", "launch_mode": SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN, "placement_id": "river_pass_hollow_mire", "army_id": "army_river_pass_hollow_mire_watch",
		"stacks": [{"unit_id": "unit_mireclaw_bogplate_maulers", "count": 4}, {"unit_id": "unit_mireclaw_mudglass_slingers", "count": 3}],
	},
	{
		"scenario_id": "causeway-stand", "launch_mode": SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN, "placement_id": "causeway_reed_camp", "army_id": "army_causeway_reed_camp_pickets",
		"stacks": [{"unit_id": "unit_mireclaw_reedsnare_kin", "count": 7}, {"unit_id": "unit_mireclaw_mudglass_slingers", "count": 4}, {"unit_id": "unit_mireclaw_bogplate_maulers", "count": 1}],
	},
	{
		"scenario_id": "mireford-skirmish", "launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH, "placement_id": "bridge_silt_hunters", "army_id": "army_mireford_silt_hunters_watch",
		"stacks": [{"unit_id": "unit_mireclaw_bogplate_maulers", "count": 6}, {"unit_id": "unit_mireclaw_reedsnare_kin", "count": 9}, {"unit_id": "unit_mireclaw_mudglass_slingers", "count": 5}],
	},
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
		_expect(source != null and source.get_size() == Vector2i(512, 512), "%s curated source must load at 512x512." % label)
		_expect(portrait != null and portrait.get_size() == Vector2i(384, 512), "%s portrait must load at 384x512." % label)
		_expect(icon != null and icon.get_size() == Vector2i(160, 160), "%s battle icon must load at 160x160." % label)
		_expect(overworld_icon != null and overworld_icon.get_size() == Vector2i(96, 96), "%s overworld icon must load at 96x96." % label)
		_expect(sheet != null and sheet.get_size() == Vector2i(256, 896), "%s sheet must load at 256x896." % label)
		if source == null or portrait == null or icon == null or overworld_icon == null or sheet == null:
			continue
		var source_alpha := _alpha_metrics(source)
		_expect(int(source_alpha.get("transparent", 0)) > 50000 and int(source_alpha.get("visible", 0)) > 40000 and int(source_alpha.get("opaque", 0)) > 30000, "%s source must retain transparent negative space and a materially opaque character silhouette." % label)
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

func _validate_live_encounters_and_board() -> void:
	var encounter_rows := []
	var causeway_session: SessionStateStoreScript.SessionData = null
	var causeway_payload := {}
	for encounter_variant in ENCOUNTERS:
		var spec: Dictionary = encounter_variant
		var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(String(spec["scenario_id"]), "normal", String(spec["launch_mode"]))
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
		if String(spec["placement_id"]) == "causeway_reed_camp":
			causeway_session = session
			causeway_payload = battle_payload
	_report["encounters"] = encounter_rows
	_expect(causeway_session != null and not causeway_payload.is_empty(), "Causeway Board fixture must retain all three curated Mireclaw units.")
	if causeway_session == null or causeway_payload.is_empty():
		return
	causeway_session.battle = causeway_payload
	var board_authority_before: Dictionary = causeway_session.to_dict()
	SessionState.set_active_session(causeway_session)
	var board = BattleBoardViewScript.new()
	board.size = Vector2(900, 560)
	add_child(board)
	board.set_battle_state(causeway_session)
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
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Causeway stack." % String(unit_spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(unit_spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(unit_spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(unit_spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(unit_spec["label"]))
			entries.append(entry)
	_expect(causeway_session.to_dict() == board_authority_before, "BattleBoard art observation must not mutate the Causeway battle/session.")
	_report["runtime"] = {"scenario_id": "causeway-stand", "placement_id": "causeway_reed_camp", "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": causeway_session.to_dict() == board_authority_before}
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
		if not unit_id in ["unit_mireclaw_reedsnare_kin", "unit_mireclaw_mudglass_slingers", "unit_mireclaw_bogplate_maulers"]:
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
