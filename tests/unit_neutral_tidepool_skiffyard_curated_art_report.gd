extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_NEUTRAL_TIDEPOOL_SKIFFYARD_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_neutral_tidepool_skiffyard_curated_art_report"
const SCENARIO_ID := "ninefold-confluence"
const PLACEMENT_ID := "ninefold_drowned_reliquary_watch"
const LOCAL_ARMY_ID := "army_ninefold_drowned_reliquary_watch"
const SHARED_ARMY_ID := "army_neutral_tidepool_skiffyard_watch"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_neutral_tidepool_cutters", "label": "Tidepool Cutters", "count": 6, "shared_count": 7, "tier": 2, "role": "melee", "growth": 5, "cost": {"gold": 90}, "ability_ids": ["backstab"],
		"source_path": "res://art/units/source/curated/unit_neutral_tidepool_cutters.png", "portrait_path": "res://art/units/portraits/unit_neutral_tidepool_cutters.png", "icon_path": "res://art/units/battle_icons/unit_neutral_tidepool_cutters.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_neutral_tidepool_cutters.png", "sheet_path": "res://art/animation/runtime/units/unit_neutral_tidepool_cutters.png",
		"source_sha256": "58b773cffd1684670dbc4fda36a1e01eff991a850d8038f88c266cd5184510f0", "portrait_sha256": "3f69a298b3b9ed3f16bb45da94ea77a8e7a45c23d62440e7db8d2562210811ac", "icon_sha256": "9f307707b0395deda1d4470e8b1cdc7af3ed37011f8aee1078e5a7968aad8dfb", "overworld_icon_sha256": "8dfd5ee3e71a4db0c02b81dc62bca6034b2b25cd6bf821ad534936622a5fc202", "sheet_sha256": "a40659a4fb16bb0763a75e8bd95aded5c941912d76902a9d7a3b4bc0e99e974a",
		"old_portrait_sha256": "1c8d0452749c16737b46a514f7a2efae199a7da9b699d3e159cd531a15309945", "old_icon_sha256": "5e15a6bf15c0b88c6c75e05c94749fac7b9aba016e7a5ff685fd4c4e2ba0ad33", "old_overworld_icon_sha256": "7cedc2d3e8491a92b3e6d167252d8d3961cf4419059343cdf5ce7918af71893b", "old_sheet_sha256": "e352adbba3ecd3e2ccffcdac41ae5ee1bf8fc4842653d9dc9eec0123954bbb2f",
	},
	{
		"unit_id": "unit_neutral_reefbolt_crews", "label": "Reefbolt Crews", "count": 11, "shared_count": 2, "tier": 2, "role": "ranged", "growth": 5, "cost": {"gold": 95}, "ability_ids": ["volley"],
		"source_path": "res://art/units/source/curated/unit_neutral_reefbolt_crews.png", "portrait_path": "res://art/units/portraits/unit_neutral_reefbolt_crews.png", "icon_path": "res://art/units/battle_icons/unit_neutral_reefbolt_crews.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_neutral_reefbolt_crews.png", "sheet_path": "res://art/animation/runtime/units/unit_neutral_reefbolt_crews.png",
		"source_sha256": "5b5a3914013dd48a07b661b8541be781fc0f56f1b8dc57cf1a2fa88df580b8f3", "portrait_sha256": "68ff5b1807df9cb621c93f68fc8058c6e15f532221ec90f752bef4c047a7267d", "icon_sha256": "55eca466e33a5334b7a93e9f5e10c045ecabf6eb0e350cca04b4c641947e59c3", "overworld_icon_sha256": "abf614710ae347659847beea190d8efa5637d0c9ca0dbcda8a078ed8327fbd4f", "sheet_sha256": "496699de9268590fd2a21918ef8fd88eb5cbad9fc60403a5aab1b062d83b8f31",
		"old_portrait_sha256": "cac856a969af726c2554753c235f258872d8ba28ad5ca7e1ca352d32f65305f8", "old_icon_sha256": "bdfed5d9efba6450cdc2ccd0833a60f1b56eece9237ee38563ce9c2e3fa8d4d5", "old_overworld_icon_sha256": "34cfd47309e19d83e90a578b07cf4fac74a15f54a2ae8548eeba2f77e7ca34a0", "old_sheet_sha256": "455a083a2e1ae56bbe98baeb08e031f83c641655bfd3e13fb831a579f288f9c3",
	},
]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	_validate_content_authority()
	await _validate_live_tidepool_battle_board()
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
		_expect(int(source_alpha.get("transparent", 0)) > 50000 and int(source_alpha.get("visible", 0)) > 40000 and int(source_alpha.get("strong", 0)) > 50000, "%s source must retain transparent negative space and a materially strong character silhouette." % label)
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

func _validate_content_authority() -> void:
	var dwelling: Dictionary = ContentService.get_neutral_dwelling("neutral_dwelling_tidepool_skiffyard")
	_expect(dwelling.get("unit_ids", []) == ["unit_neutral_tidepool_cutters", "unit_neutral_reefbolt_crews"], "Tidepool Skiffyard unit order changed.")
	_expect(dwelling.get("army_group_ids", []) == [SHARED_ARMY_ID] and dwelling.get("encounter_ids", []) == ["encounter_tidepool_skiffyard_watch"], "Tidepool Skiffyard army/encounter graph changed.")
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var unit: Dictionary = ContentService.get_unit(String(spec["unit_id"]))
		var ability_ids := []
		for ability in unit.get("abilities", []):
			if ability is Dictionary:
				ability_ids.append(String(ability.get("id", "")))
		_expect(String(unit.get("name", "")) == String(spec["label"]), "%s name changed." % String(spec["label"]))
		_expect(String(unit.get("affiliation", "")) == "neutral" and int(unit.get("tier", 0)) == int(spec["tier"]) and String(unit.get("role", "")) == String(spec["role"]), "%s neutral tier/role changed." % String(spec["label"]))
		_expect(int(unit.get("growth", 0)) == int(spec["growth"]) and _resource_cost_contract(unit.get("cost", {})) == spec["cost"], "%s growth/cost changed." % String(spec["label"]))
		_expect(ability_ids == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": ability_ids})
	_report["content"] = rows

func _validate_live_tidepool_battle_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var placement := _encounter_placement(session)
	_expect(not placement.is_empty() and String(placement.get("placement_id", "")) == PLACEMENT_ID, "Ninefold Confluence must retain the Drowned Reliquary encounter placement.")
	var local_army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
	var expected_local := {"unit_neutral_tidepool_cutters": 6, "unit_neutral_reefbolt_crews": 11}
	var expected_shared := {"unit_neutral_tidepool_cutters": 7, "unit_neutral_reefbolt_crews": 2}
	_expect(String(local_army.get("id", "")) == LOCAL_ARMY_ID and _stack_counts(local_army) == expected_local, "Drowned Reliquary placement-local army ids/counts changed.")
	var shared_army: Dictionary = ContentService.get_army_group(SHARED_ARMY_ID)
	_expect(String(shared_army.get("id", "")) == SHARED_ARMY_ID and _stack_counts(shared_army) == expected_shared, "Shared Tidepool Skiffyard Watch ids/counts changed.")
	var battle_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	_expect(String(battle_payload.get("terrain", "")) == "coast", "Ninefold Drowned Reliquary did not enter the coast battlefield.")
	var enemy_stacks: Array = battle_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_counts(enemy_stacks) == expected_local, "Public Drowned Reliquary battle payload changed its exact enemy roster.")
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
			if entry is Dictionary and String(entry.get("unit_id", "")) == String(spec["unit_id"]):
				matches.append(entry.duplicate(true))
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Drowned Reliquary stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_expect(session.to_dict() == authority_before, "BattleBoard art observation must not mutate the live Drowned Reliquary battle/session.")
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

func _resource_cost_contract(cost_value: Variant) -> Dictionary:
	var result := {}
	for resource_id in cost_value if cost_value is Dictionary else {}:
		result[String(resource_id)] = int(cost_value[resource_id])
	return result

func _alpha_metrics(image: Image) -> Dictionary:
	var transparent := 0
	var opaque := 0
	var strong := 0
	var visible := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha <= 0.001:
				transparent += 1
			else:
				visible += 1
				if alpha >= 0.75:
					strong += 1
				if alpha >= 0.999:
					opaque += 1
	var max_x := image.get_width() - 1
	var max_y := image.get_height() - 1
	return {"transparent": transparent, "opaque": opaque, "strong": strong, "visible": visible, "corners_transparent": image.get_pixel(0, 0).a <= 0.001 and image.get_pixel(max_x, 0).a <= 0.001 and image.get_pixel(0, max_y).a <= 0.001 and image.get_pixel(max_x, max_y).a <= 0.001}

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
