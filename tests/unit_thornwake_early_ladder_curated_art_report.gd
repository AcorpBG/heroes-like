extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_THORNWAKE_EARLY_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_thornwake_early_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const TARGET_IDS := ["unit_thornwake_seedcutters", "unit_thornwake_thornwhip_carriers", "unit_thornwake_sporeglass_menders"]
const UNITS := [
	{
		"unit_id": "unit_thornwake_seedcutters", "label": "Seedcutters", "ability_ids": [],
		"source_path": "res://art/units/source/curated/unit_thornwake_seedcutters.png", "portrait_path": "res://art/units/portraits/unit_thornwake_seedcutters.png", "icon_path": "res://art/units/battle_icons/unit_thornwake_seedcutters.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_thornwake_seedcutters.png", "sheet_path": "res://art/animation/runtime/units/unit_thornwake_seedcutters.png",
		"source_sha256": "360f2ec2f9baeab2d9243911abbbae9c4a5ce3e9cbc66fa3211f6264dcf20ace", "portrait_sha256": "79edec73359fca75e09d08bcc07261a6fa730946607610f6559117a8a1e72d63", "icon_sha256": "97cfc788d51a4a42b4764f0c26226944dace9a69fc1c802e1e736188171e4b6e", "overworld_icon_sha256": "cd92405fe73418ff044bbfc9700ab9452db6c08adb4af0ec502e6127b1fd7ccd", "sheet_sha256": "258c27af17329b79f14a8b9fd7b57c01fab31f60d0ee6ef9bc2df92724fda64b",
		"old_portrait_sha256": "6afa42b48d5335634982df379c1701649e315cf23f9c9c3aad66415d79dbc142", "old_icon_sha256": "053451d1148443fdb579b6f02c82b78b8a39b5e0f9da2631e0f89e05db0ce2a5", "old_overworld_icon_sha256": "36fcd489794f8db440c2912fc4f20035af209b0bb5491a00c947035fb482e3db", "old_sheet_sha256": "c35cd8b92f056a1cf582983cf4d04682a6d1523bc5e6e982a90d82905f49f0a5",
	},
	{
		"unit_id": "unit_thornwake_thornwhip_carriers", "label": "Thornwhip Carriers", "ability_ids": ["brace"],
		"source_path": "res://art/units/source/curated/unit_thornwake_thornwhip_carriers.png", "portrait_path": "res://art/units/portraits/unit_thornwake_thornwhip_carriers.png", "icon_path": "res://art/units/battle_icons/unit_thornwake_thornwhip_carriers.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_thornwake_thornwhip_carriers.png", "sheet_path": "res://art/animation/runtime/units/unit_thornwake_thornwhip_carriers.png",
		"source_sha256": "65b539dd7ce63fdf410f3d9ce5466c20753664b3d760d8e91b6da0568eacf98b", "portrait_sha256": "c02715b5d765bbba66932e9c73f653cbf5da01264ab39e9ce0b467be95768564", "icon_sha256": "486ffde278196be924835c60bde4a7b832c6ba51d60cc5339dbdf1c40be1f1db", "overworld_icon_sha256": "a54f18c88058d88a90d48c83deceb879b0f1787c21dcad14796604dcc28736ba", "sheet_sha256": "1e7aa7664b7c54431620f5e408486874677f54a064b8aa571a87533cf6c6a1b3",
		"old_portrait_sha256": "f3054860097379b4f394b5cc441cb237091bc91b9d5641fe8634f4f0358c96f8", "old_icon_sha256": "6d880553ffa3248db6cf60f44f9ff944009974a505cbcc6c45b4dea2059d3b58", "old_overworld_icon_sha256": "0b2478aeff397a8d36241a6c451ea601bb5fe514affac240bc1142b2327eefe2", "old_sheet_sha256": "c551466b106797195fb228e9507594e166e8377a5162b865c157eabb9d9566d5",
	},
	{
		"unit_id": "unit_thornwake_sporeglass_menders", "label": "Sporeglass Menders", "ability_ids": ["sporeglass_mend"],
		"source_path": "res://art/units/source/curated/unit_thornwake_sporeglass_menders.png", "portrait_path": "res://art/units/portraits/unit_thornwake_sporeglass_menders.png", "icon_path": "res://art/units/battle_icons/unit_thornwake_sporeglass_menders.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_thornwake_sporeglass_menders.png", "sheet_path": "res://art/animation/runtime/units/unit_thornwake_sporeglass_menders.png",
		"source_sha256": "bb2986e88f2b9974a9e134226385d0ed4edf03dcd49c365423dd4a81fe8b5ec8", "portrait_sha256": "0ad63314f084b8e9e3bcea2834feba41285bdf5b7ff3b5a0a6e62e6921768687", "icon_sha256": "078a1b465434e2e4f9d667113c883f44cf9344da739b719f8e88e6a931a4db6c", "overworld_icon_sha256": "8d31c3a6af9350e77b4acb2af024a8ef7fecded6282cc7382a84102c415c7298", "sheet_sha256": "53b16f5beb08abea0a5536e67b06085122425d84da28f6ec097595f8355d90b7",
		"old_portrait_sha256": "e61371af44b26b2559b12af2f41d011eceb3c697dd7938b8a70db4b4b3281d67", "old_icon_sha256": "de4e64d6a5933b2654aa512f62ec59f4724e96fb4d4527e4bdefc410a9188cca", "old_overworld_icon_sha256": "8aa21c94dd0f8458033fab3036a1cf87954c22e0f0b15c522a62afc3f2b5b330", "old_sheet_sha256": "07a4dcdceaeb57830857f2c18d8ef313f4c9ea00d6cd439c61c8ee8cf56b43dc",
	},
]
const ENCOUNTERS := [
	{"scenario_id": "halo-reserve-refraction-claim", "placement_id": "halo_prism_watch", "army_id": "army_halo_prism_watch", "stacks": [{"unit_id": "unit_thornwake_seedcutters", "count": 10}, {"unit_id": "unit_thornwake_thornwhip_carriers", "count": 7}, {"unit_id": "unit_thornwake_sporeglass_menders", "count": 4}]},
	{"scenario_id": "halo-reserve-refraction-claim", "placement_id": "halo_sporeglass_screen", "army_id": "army_halo_sporeglass_screen", "stacks": [{"unit_id": "unit_thornwake_seedcutters", "count": 13}, {"unit_id": "unit_thornwake_thornwhip_carriers", "count": 9}, {"unit_id": "unit_thornwake_sporeglass_menders", "count": 6}]},
	{"scenario_id": "halo-reserve-refraction-claim", "placement_id": "halo_barkmantle_bastion", "army_id": "army_halo_barkmantle_bastion", "stacks": [{"unit_id": "unit_thornwake_seedcutters", "count": 9}, {"unit_id": "unit_thornwake_sporeglass_menders", "count": 7}, {"unit_id": "unit_thornwake_barkmantle_rams", "count": 4}]},
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
		if String(spec["placement_id"]) == "halo_prism_watch":
			board_session = session
			board_payload = battle_payload
	_report["encounters"] = encounter_rows
	_expect(board_session != null and not board_payload.is_empty(), "Halo Prism Watch Board fixture must retain all three curated Thornwake units.")
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
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Halo Prism Watch stack." % String(unit_spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(unit_spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(unit_spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(unit_spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(unit_spec["label"]))
			entries.append(entry)
	_expect(board_session.to_dict() == board_authority_before, "BattleBoard art observation must not mutate the Halo battle/session.")
	_report["runtime"] = {"scenario_id": "halo-reserve-refraction-claim", "placement_id": "halo_prism_watch", "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": board_session.to_dict() == board_authority_before}
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
