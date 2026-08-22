extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_NEUTRAL_BASALT_GATEHOUSE_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_neutral_basalt_gatehouse_curated_art_report"
const SCENARIO_ID := "ninefold-confluence"
const PLACEMENT_ID := "ninefold_basalt_gatehouse_watch"
const LOCAL_ARMY_ID := "army_ninefold_basalt_gatehouse_watch"
const SHARED_ARMY_ID := "army_neutral_basalt_gatehouse_watch"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_neutral_basalt_wardens", "label": "Basalt Wardens", "count": 11, "shared_count": 8, "tier": 3, "role": "melee", "growth": 3, "cost": {"gold": 175, "ore": 1}, "ability_ids": ["shielding"], "hp": 19, "attack": 7, "defense": 9, "min_damage": 4, "max_damage": 7, "speed": 3, "initiative": 5, "retaliations": 1, "ranged": false, "shots": -1,
		"source_path": "res://art/units/source/curated/unit_neutral_basalt_wardens.png", "portrait_path": "res://art/units/portraits/unit_neutral_basalt_wardens.png", "icon_path": "res://art/units/battle_icons/unit_neutral_basalt_wardens.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_neutral_basalt_wardens.png", "sheet_path": "res://art/animation/runtime/units/unit_neutral_basalt_wardens.png",
		"source_sha256": "81f748fafeec18bd318af244059458edc22ca3646acfad8e16685a804dc509c8", "portrait_sha256": "0a905a4f8b3e447d8b2716450762094d204c1746f8b4c072f3c917b1aae9d809", "icon_sha256": "400eb8da94f2ded8bc7082cef09ab5e6ff04e72df19f489f66c1b4bf0c6059bd", "overworld_icon_sha256": "256bb01877ddb922e25eb4f92007219f55a5a53fc026a8ccbcdd1d7b93e8ce0b", "sheet_sha256": "d4ff9267868073e61d792ad6dc8533758f7ab6a08eb837b160d7583f4af57e0d",
		"old_portrait_sha256": "44ac26a1b183ccaa2be6946e34598c88372e7455d69cacaccf2ad2bb564c522a", "old_icon_sha256": "a50aa83ce5f53c69632ce793e7ced87c3e777f8c953fb3af4d92688faa7a44dc", "old_overworld_icon_sha256": "fd826f68af9d5d5cf25c81b1bfc16b25524f5263ee21630f6bb6e8cc8779c4ea", "old_sheet_sha256": "3be09a5d44802c484eaa066f34c49ab6139b7f78435ef603d2606af6c844f250",
	},
	{
		"unit_id": "unit_neutral_tunnelmark_bolters", "label": "Tunnelmark Bolters", "count": 6, "shared_count": 3, "tier": 3, "role": "ranged", "growth": 4, "cost": {"gold": 130, "wood": 1}, "ability_ids": ["volley"], "hp": 9, "attack": 7, "defense": 4, "min_damage": 3, "max_damage": 5, "speed": 3, "initiative": 6, "retaliations": 1, "ranged": true, "shots": 7,
		"source_path": "res://art/units/source/curated/unit_neutral_tunnelmark_bolters.png", "portrait_path": "res://art/units/portraits/unit_neutral_tunnelmark_bolters.png", "icon_path": "res://art/units/battle_icons/unit_neutral_tunnelmark_bolters.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_neutral_tunnelmark_bolters.png", "sheet_path": "res://art/animation/runtime/units/unit_neutral_tunnelmark_bolters.png",
		"source_sha256": "376c11173412cf401b9177089d7a106281b5dd8c62d59ad563d1e89881aedc73", "portrait_sha256": "531f93c4a18c72af9ffcfedbcac7277edad5f60c0172389c8318de9400bc8607", "icon_sha256": "6145163c2ebe434ba84835c30f00a295200b386f87d47f0836925c1fdf8ef89f", "overworld_icon_sha256": "6c32cec9dd4792f9bf38bb192a0630a002187220f5701b8fa44491ca5526068e", "sheet_sha256": "7b8231f0220f5119b6262a674d6e8b2927d6641ac342d835067cef753eb1bf1c",
		"old_portrait_sha256": "33c7c4d529b1228c6ca3d99a80467b617781cac80322251e675ef8fbac0f68d3", "old_icon_sha256": "1f92efd1d341ea701f5b9120aea1d14f825ffa2dc5214a02b66774bdc34e8ac1", "old_overworld_icon_sha256": "632db108196767ff2845b1b59ab619832c840f1c2e7529ef3c6e0794e5f509f8", "old_sheet_sha256": "6543ed3cf367f54fbb5aeddc9c6bf5e56c843ec5558d8164d03c528e1e02ef84",
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
	await _validate_live_basalt_battle_board()
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
		_expect(int(source_alpha.get("transparent", 0)) > 50000 and int(source_alpha.get("visible", 0)) > 40000 and int(source_alpha.get("strong", 0)) > 40000, "%s source must retain transparent negative space and a materially strong character silhouette." % label)
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
	var dwelling: Dictionary = ContentService.get_neutral_dwelling("neutral_dwelling_basalt_gatehouse")
	_expect(dwelling.get("unit_ids", []) == ["unit_neutral_basalt_wardens", "unit_neutral_tunnelmark_bolters"], "Basalt Gatehouse unit order changed.")
	_expect(dwelling.get("army_group_ids", []) == [SHARED_ARMY_ID] and dwelling.get("encounter_ids", []) == ["encounter_basalt_gatehouse_watch"], "Basalt Gatehouse army/encounter graph changed.")
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
		_expect(int(unit.get("hp", 0)) == int(spec["hp"]) and int(unit.get("attack", 0)) == int(spec["attack"]) and int(unit.get("defense", 0)) == int(spec["defense"]), "%s health/attack/defense changed." % String(spec["label"]))
		_expect(int(unit.get("min_damage", 0)) == int(spec["min_damage"]) and int(unit.get("max_damage", 0)) == int(spec["max_damage"]) and int(unit.get("speed", 0)) == int(spec["speed"]) and int(unit.get("initiative", 0)) == int(spec["initiative"]), "%s damage/speed/initiative changed." % String(spec["label"]))
		_expect(int(unit.get("retaliations", 0)) == int(spec["retaliations"]) and bool(unit.get("ranged", false)) == bool(spec["ranged"]) and int(unit.get("shots", -1)) == int(spec["shots"]), "%s retaliation/ranged/shots contract changed." % String(spec["label"]))
		_expect(ability_ids == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": ability_ids})
	_report["content"] = rows

func _validate_live_basalt_battle_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var placement := _encounter_placement(session)
	_expect(not placement.is_empty() and String(placement.get("placement_id", "")) == PLACEMENT_ID, "Ninefold Confluence must retain the Basalt Gatehouse encounter placement.")
	var local_army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
	var expected_local := {"unit_neutral_basalt_wardens": 11, "unit_neutral_tunnelmark_bolters": 6}
	var expected_shared := {"unit_neutral_basalt_wardens": 8, "unit_neutral_tunnelmark_bolters": 3}
	_expect(String(local_army.get("id", "")) == LOCAL_ARMY_ID and _stack_counts(local_army) == expected_local, "Basalt Gatehouse placement-local army ids/counts changed.")
	var shared_army: Dictionary = ContentService.get_army_group(SHARED_ARMY_ID)
	_expect(String(shared_army.get("id", "")) == SHARED_ARMY_ID and _stack_counts(shared_army) == expected_shared, "Shared Basalt Gatehouse Watch ids/counts changed.")
	var battle_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	var enemy_stacks: Array = battle_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_counts(enemy_stacks) == expected_local, "Public Basalt Gatehouse battle payload changed its exact enemy roster.")
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
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Basalt Gatehouse stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_expect(session.to_dict() == authority_before, "BattleBoard art observation must not mutate the live Basalt Gatehouse battle/session.")
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
