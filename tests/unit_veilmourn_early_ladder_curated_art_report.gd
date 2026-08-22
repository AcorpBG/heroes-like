extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_VEILMOURN_EARLY_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_veilmourn_early_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const TARGET_IDS := ["unit_veilmourn_bellwake_oars", "unit_veilmourn_mourning_lanterns", "unit_veilmourn_maskglass_corsairs"]
const UNITS := [
	{
		"unit_id": "unit_veilmourn_bellwake_oars", "label": "Bellwake Oars", "ability_ids": [],
		"source_path": "res://art/units/source/curated/unit_veilmourn_bellwake_oars.png", "portrait_path": "res://art/units/portraits/unit_veilmourn_bellwake_oars.png", "icon_path": "res://art/units/battle_icons/unit_veilmourn_bellwake_oars.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_veilmourn_bellwake_oars.png", "sheet_path": "res://art/animation/runtime/units/unit_veilmourn_bellwake_oars.png",
		"source_sha256": "81b03a91ce36b024c7d244120055539bd4f790106291d1e669eb9fd013accafa", "portrait_sha256": "c855f95ac00ebc680d28e8c2e4dd8e199060c4fcc2987256564036d54c5f129b", "icon_sha256": "013d7280ab34716646a6d365ad67c9585529c3a2de99a5ecbbd91f0d70419157", "overworld_icon_sha256": "0926921c4ef8ebef3c0a21f60bc2d8afed6f333edaec3f35954b0efdd3b960f1", "sheet_sha256": "1fd65e107918d9e9249857d2f8b471c7e2c552eb7a9c6ee75f99a80abb1dbf7d",
		"old_portrait_sha256": "6d9032208b7f200a856277cd59207018747b5be204a3ef5f8730a86f8c19a6f3", "old_icon_sha256": "e9809d51256a7cca09e306fcf83d388a8482004a2f8ee710e4aa7ef0480516fe", "old_overworld_icon_sha256": "ac7a4d71c11352efbfb4c37da3971d9cd9d6838f1082fb7ae4871382314e09a5", "old_sheet_sha256": "dce8957bc65333d894a9d7e69ead3d718c2822cd1b1429a4364390ec131d6fa9",
	},
	{
		"unit_id": "unit_veilmourn_mourning_lanterns", "label": "Mourning Lanterns", "ability_ids": ["harry"],
		"source_path": "res://art/units/source/curated/unit_veilmourn_mourning_lanterns.png", "portrait_path": "res://art/units/portraits/unit_veilmourn_mourning_lanterns.png", "icon_path": "res://art/units/battle_icons/unit_veilmourn_mourning_lanterns.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_veilmourn_mourning_lanterns.png", "sheet_path": "res://art/animation/runtime/units/unit_veilmourn_mourning_lanterns.png",
		"source_sha256": "b12f75e6b7b7419544194b3dd22ca672fce76207ab988c46025755d81e87591b", "portrait_sha256": "bdcfe4c84caee23878f6df6dde922faad92f3c686139a6db7a742c7b6157c112", "icon_sha256": "1a9089f79c9ce3b85cebdd7ae8e9b42e130be7371fe3b4e82ee0d3a3b506db1a", "overworld_icon_sha256": "6d5effedec75121052ab4f0a9a0b162b11e93d1b68895533267292a8a7073067", "sheet_sha256": "b5873d3a40292bf5b2073ca7a3ab200241d95243f1c4cb7e890498e841e61a3d",
		"old_portrait_sha256": "18968a8aba805393357a2b5441e29ac72c3995ddb3898a1e7aaaf5890a4fe59e", "old_icon_sha256": "4524010157d48ebfb3aa2db4c2d3192c8890c890cebe936696f5caee0f742aa8", "old_overworld_icon_sha256": "7a7ff6bb57ec2790d2abc988a9761d568e4fa19df8b5e297c23242fff176e69a", "old_sheet_sha256": "b5a8f9592428018601670728641a569c921d0b59d65e28a333726cd747ca25e3",
	},
	{
		"unit_id": "unit_veilmourn_maskglass_corsairs", "label": "Maskglass Corsairs", "ability_ids": ["backstab"],
		"source_path": "res://art/units/source/curated/unit_veilmourn_maskglass_corsairs.png", "portrait_path": "res://art/units/portraits/unit_veilmourn_maskglass_corsairs.png", "icon_path": "res://art/units/battle_icons/unit_veilmourn_maskglass_corsairs.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_veilmourn_maskglass_corsairs.png", "sheet_path": "res://art/animation/runtime/units/unit_veilmourn_maskglass_corsairs.png",
		"source_sha256": "4c715c8d0e20d69592d7dbc124de33cadb89b2b1e10ad0a0cd5efcb89950ea27", "portrait_sha256": "069d65156a3db29f03047e3df7299fa6a587ff109e5666a79bdd1ec58349e757", "icon_sha256": "5c4648967854064a465f33e7ccbb8baf7c6ab41b73ea36aa5746b648a51ace1b", "overworld_icon_sha256": "555cbbe5cb52ef6794ba1ed893e3c8966501ef83c064eddb1d6ed7350fee9b61", "sheet_sha256": "ab79dcc966cb0c502806075b476ddfee752c56dfa067be27514351aa9fc6d907",
		"old_portrait_sha256": "fa34c6ab246682921d8e4886ef0081c64dba7014f5a2672f9eb2e41e455e44c5", "old_icon_sha256": "983468602a601df7a0412b3eaffe05210aefce5d597b284cc263873143647226", "old_overworld_icon_sha256": "a548b79761e2a72739b07dd236c6f46d7d34696ba26b050c7d567594148ed427", "old_sheet_sha256": "8c7dea80a0b96f810033733f1d2c456e80974c441695130c86bc5d65ab7c154f",
	},
]
const PLAYER_ARMIES := [
	{"scenario_id": "bellwake-wreck-claim", "army_id": "army_bellwake_wreck_claimants", "stacks": [{"unit_id": "unit_veilmourn_bellwake_oars", "count": 14}, {"unit_id": "unit_veilmourn_mourning_lanterns", "count": 8}, {"unit_id": "unit_veilmourn_maskglass_corsairs", "count": 5}, {"unit_id": "unit_veilmourn_undertow_harpooners", "count": 2}]},
	{"scenario_id": "fogchart-mooring", "army_id": "army_bellwake_privateers", "stacks": [{"unit_id": "unit_veilmourn_bellwake_oars", "count": 12}, {"unit_id": "unit_veilmourn_mourning_lanterns", "count": 7}, {"unit_id": "unit_veilmourn_maskglass_corsairs", "count": 4}]},
]
const ENCOUNTERS := [
	{"scenario_id": "ninefold-confluence", "placement_id": "ninefold_bellwake_privateers", "encounter_id": "encounter_bellwake_privateers", "army_id": "army_bellwake_privateers", "stacks": [{"unit_id": "unit_veilmourn_bellwake_oars", "count": 12}, {"unit_id": "unit_veilmourn_mourning_lanterns", "count": 7}, {"unit_id": "unit_veilmourn_maskglass_corsairs", "count": 4}]},
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
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "unit_count": UNITS.size(), "front_count": PLAYER_ARMIES.size() + ENCOUNTERS.size(), "state_count": STATES.size(), "frames_per_state": FRAMES_PER_STATE, "visible_frame_count": UNITS.size() * STATES.size() * FRAMES_PER_STATE, "board_entry_count": int(_report.get("runtime", {}).get("entry_count", 0))})])
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
	for army_variant in PLAYER_ARMIES:
		var army_spec: Dictionary = army_variant
		var player_session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(String(army_spec["scenario_id"]), "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		_expect(player_session != null, "%s must create a live player session." % String(army_spec["scenario_id"]))
		if player_session == null:
			continue
		OverworldRules.normalize_overworld_state(player_session)
		var player_army: Dictionary = player_session.overworld.get("army", {}) if player_session.overworld.get("army", {}) is Dictionary else {}
		_expect(String(player_army.get("id", "")) == String(army_spec["army_id"]) and _stack_contract(player_army.get("stacks", [])) == army_spec["stacks"], "%s opening player army changed." % String(army_spec["scenario_id"]))
		encounter_rows.append({"scenario_id": army_spec["scenario_id"], "army_id": army_spec["army_id"], "stacks": _stack_contract(player_army.get("stacks", [])), "session_authority_exact": true})
	for encounter_variant in ENCOUNTERS:
		var spec: Dictionary = encounter_variant
		var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(String(spec["scenario_id"]), "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		_expect(session != null, "%s must create a live session." % String(spec["placement_id"]))
		if session == null:
			continue
		OverworldRules.normalize_overworld_state(session)
		var placement := _encounter_placement(session, String(spec["placement_id"]))
		var army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
		_expect(not placement.is_empty() and String(placement.get("encounter_id", "")) == String(spec["encounter_id"]), "%s authored encounter identity changed." % String(spec["placement_id"]))
		var authority_before: Dictionary = session.to_dict()
		var battle_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
		var enemy_stacks: Array = battle_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
		_expect(_battle_stack_contract(enemy_stacks) == spec["stacks"], "%s public battle roster changed." % String(spec["placement_id"]))
		var expected_abilities := _expected_target_abilities(spec["stacks"])
		_expect(_battle_target_ability_contract(enemy_stacks) == expected_abilities, "%s public target abilities changed." % String(spec["placement_id"]))
		_expect(session.to_dict() == authority_before, "%s public battle materialization mutated the session." % String(spec["placement_id"]))
		encounter_rows.append({"scenario_id": spec["scenario_id"], "placement_id": spec["placement_id"], "army_id": spec["army_id"], "stacks": _battle_stack_contract(enemy_stacks), "abilities": _battle_target_ability_contract(enemy_stacks), "session_authority_exact": session.to_dict() == authority_before})
		if String(spec["placement_id"]) == "ninefold_bellwake_privateers":
			board_session = session
			board_payload = battle_payload
	_report["encounters"] = encounter_rows
	_expect(board_session != null and not board_payload.is_empty(), "Ninefold Bellwake Privateers Board fixture must retain all three curated Veilmourn units.")
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
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Ninefold privateer stack." % String(unit_spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(unit_spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(unit_spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(unit_spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(unit_spec["label"]))
			entries.append(entry)
	_expect(board_session.to_dict() == board_authority_before, "BattleBoard art observation must not mutate the Ninefold battle/session.")
	_report["runtime"] = {"scenario_id": "ninefold-confluence", "placement_id": "ninefold_bellwake_privateers", "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": board_session.to_dict() == board_authority_before}
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
