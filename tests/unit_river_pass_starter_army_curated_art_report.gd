extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_RIVER_PASS_STARTER_ARMY_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_river_pass_starter_army_curated_art_report"
const SCENARIO_ID := "river-pass"
const ARMY_ID := "army_emberwell_vanguard"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_river_guard",
		"label": "River Guard",
		"count": 10,
		"source_path": "res://art/units/source/curated/unit_river_guard.png",
		"portrait_path": "res://art/units/portraits/unit_river_guard.png",
		"icon_path": "res://art/units/battle_icons/unit_river_guard.png",
		"overworld_icon_path": "res://art/units/overworld_icons/unit_river_guard.png",
		"sheet_path": "res://art/animation/runtime/units/unit_river_guard.png",
		"source_sha256": "95e7c9fc8dfddeebe0d5cd7439347dc1e6538b4d0e1f52584dac8cbaf76354eb",
		"portrait_sha256": "db56bc222683c9fc9b55e33626508488681fb9a214e6f0f8c0ee06190ee0cba5",
		"icon_sha256": "375f75e8e3df69ae4f54037862705c448e366d3276aed9e3cc2698775112c027",
		"overworld_icon_sha256": "fa0ba72bbe51430617ecf8aae15db442857f6a68f52edefcebd272a07e985581",
		"sheet_sha256": "c951d9f589462f2753c16a575ccb9f4283bb9155f8eb00043ae4b55f7299c38d",
		"old_portrait_sha256": "d1487d6f809e02f1e87c118210ab6e8f4b842196726100b5280a6133f1adb9a4",
		"old_icon_sha256": "98ed815cbccc0bb34864dee0d1968bbbdafa69058132bed722d02bfc99cd1441",
		"old_overworld_icon_sha256": "1ccfe1a6ab9fc94587368639f643951d5b7d26020d4a8c2c14ddaf512ded24f8",
		"old_sheet_sha256": "b77a7759b2ce145eae8713c85913f3f4d244ebcf902edb7fe27122440da40d8c",
		"ability_ids": ["reach", "brace"],
	},
	{
		"unit_id": "unit_ember_archer",
		"label": "Ember Archer",
		"count": 5,
		"source_path": "res://art/units/source/curated/unit_ember_archer.png",
		"portrait_path": "res://art/units/portraits/unit_ember_archer.png",
		"icon_path": "res://art/units/battle_icons/unit_ember_archer.png",
		"overworld_icon_path": "res://art/units/overworld_icons/unit_ember_archer.png",
		"sheet_path": "res://art/animation/runtime/units/unit_ember_archer.png",
		"source_sha256": "d019d88e87184ac8b68c852444d4be3b1a7fbd54282c13aa61f78170b885ce83",
		"portrait_sha256": "07a76383708521a8d61a146800f18b9d4eb82731b27661e5cfa5529e5f6e8a0f",
		"icon_sha256": "7ccab2a36ce94f17cb7c3c9a14bed81125a08386acf5740b867e92bfd5034396",
		"overworld_icon_sha256": "42a6d4bcff88e4d4348148a60941dd4908b824a8fb63e87c115b25a0a439069d",
		"sheet_sha256": "81ff7d7ddf6b022e6f6ea6126510168669ab029cd243e1244a9f46ef1b35b68e",
		"old_portrait_sha256": "09eff6bef0862c3b15ccff8044bfafee6be7505c5398a60383aa8655d9be99b9",
		"old_icon_sha256": "428ba13f119a977e464800292e69cbe9b5dbfcf56989ab7de711a4583b3c8ff0",
		"old_overworld_icon_sha256": "1235c19570240dcd783bf2aba5b0da5bdd624792b2518e3a4cfc45d769f0c6d3",
		"old_sheet_sha256": "9f2d8583a0783349fed80e83d9f27c67cb3dbd83d1829e8d95e6cbd3485feba6",
		"ability_ids": ["volley", "harry"],
	},
]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	await _validate_river_pass_battle_board_runtime()
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
		_expect(int(source_alpha.get("transparent", 0)) > 50000 and int(source_alpha.get("visible", 0)) > 40000 and int(source_alpha.get("opaque", 0)) > 40000, "%s source must retain transparent negative space and a materially opaque character silhouette." % label)
		_expect(bool(source_alpha.get("corners_transparent", false)), "%s source corners must remain transparent." % label)
		for key in ["source", "portrait", "icon", "overworld_icon", "sheet"]:
			var path_key := "%s_path" % key
			var hash_key := "%s_sha256" % key
			_expect(FileAccess.get_sha256(String(spec[path_key])) == String(spec[hash_key]), "%s %s hash drifted." % [label, key])
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

func _validate_river_pass_battle_board_runtime() -> void:
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	var authored_army: Dictionary = ContentService.get_army_group(ARMY_ID)
	_expect(String(scenario.get("player_army_id", "")) == ARMY_ID, "River Pass must retain Emberwell Vanguard as its player army.")
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var live_army: Dictionary = session.overworld.get("army", {})
	_expect(String(live_army.get("id", "")) == ARMY_ID, "River Pass live session must resolve Emberwell Vanguard.")
	var expected_stacks := [{"unit_id": "unit_river_guard", "count": 10}, {"unit_id": "unit_ember_archer", "count": 5}]
	var authored_stacks := []
	for stack in authored_army.get("stacks", []):
		if stack is Dictionary:
			authored_stacks.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0))})
	var live_stacks := []
	for stack in live_army.get("stacks", []):
		if stack is Dictionary:
			live_stacks.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0))})
	_expect(authored_stacks == expected_stacks and live_stacks == expected_stacks, "River Pass authored and live starter armies must preserve the exact stack ids, order, and counts.")
	var battle_stacks := []
	for stack_index in range(live_army.get("stacks", []).size()):
		var live_stack: Dictionary = live_army.get("stacks", [])[stack_index]
		var battle_stack: Dictionary = BattleRulesScript._build_battle_stack(String(live_stack.get("unit_id", "")), int(live_stack.get("count", 0)), "player", stack_index, {"source_type": "river_pass_live_starter_army", "hero_id": session.hero_id})
		battle_stack["hex"] = {"q": 2, "r": 2 + stack_index * 2}
		battle_stacks.append(battle_stack)
	var enemy: Dictionary = BattleRulesScript._build_battle_stack("unit_bog_brute", 7, "enemy", 0, {"source_type": "river_pass_live_starter_army_control"})
	enemy["hex"] = {"q": 7, "r": 3}
	battle_stacks.append(enemy)
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var matches := battle_stacks.filter(func(stack): return String(stack.get("unit_id", "")) == String(spec["unit_id"]))
		_expect(matches.size() == 1 and int(matches[0].get("base_count", -1)) == int(spec["count"]), "%s live battle stack count changed." % String(spec["label"]))
		if matches.size() == 1:
			var ability_ids := []
			for ability in matches[0].get("abilities", []):
				if ability is Dictionary:
					ability_ids.append(String(ability.get("id", "")))
			_expect(ability_ids == spec["ability_ids"], "%s live runtime ability ids changed during the art-only slice." % String(spec["label"]))
	session.battle = {"round": 1, "max_rounds": 20, "distance": 1, "terrain": "plains", "battlefield_tags": [], "combat_seed": 10184, "stacks": battle_stacks, "turn_order": [String(battle_stacks[0].get("battle_id", "")), String(battle_stacks[1].get("battle_id", ""))], "turn_index": 0, "active_stack_id": String(battle_stacks[0].get("battle_id", "")), "selected_target_id": String(enemy.get("battle_id", "")), "recent_events": [], "retreat_allowed": true, "surrender_allowed": true, "player_commander_state": {}, "enemy_hero": {}, BattleRulesScript.FIELD_OBJECTIVES_KEY: [], BattleRulesScript.STACK_ANIMATION_STATES_KEY: {}, BattleRulesScript.ANIMATION_EVENT_SERIAL_KEY: 0}
	BattleRulesScript._ensure_battle_hex_state(session.battle)
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
			if entry is Dictionary and String(entry.get("unit_id", "")) == String(spec["unit_id"]):
				matches.append(entry.duplicate(true))
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s live starter stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_expect(session.to_dict() == authority_before, "BattleBoard art observation must not mutate the River Pass live session.")
	_report["runtime"] = {"scenario_id": SCENARIO_ID, "army_id": ARMY_ID, "starter_stacks": live_army.get("stacks", []).duplicate(true), "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == authority_before}
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)

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
