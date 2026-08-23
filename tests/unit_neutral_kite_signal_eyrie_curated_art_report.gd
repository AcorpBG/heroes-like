extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_NEUTRAL_KITE_SIGNAL_EYRIE_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_neutral_kite_signal_eyrie_curated_art_report"
const SHARED_ARMY_ID := "army_neutral_kite_signal_eyrie_watch"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const AUTHORED_SITE_ROWS := [
	{"scenario_id": "ninefold-confluence", "placement_id": "dwelling_kite_signal_eyrie", "site_id": "site_kite_signal_eyrie"},
]
const UNITS := [
	{
		"unit_id": "unit_neutral_kitehook_runners", "label": "Kitehook Runners", "count": 7, "tier": 2, "role": "melee", "growth": 5, "cost": {"gold": 95}, "ability_ids": ["bloodrush"], "hp": 10, "attack": 6, "defense": 3, "min_damage": 3, "max_damage": 5, "speed": 7, "initiative": 8, "retaliations": 1, "ranged": false, "shots": -1,
		"source_path": "res://art/units/source/curated/unit_neutral_kitehook_runners.png", "portrait_path": "res://art/units/portraits/unit_neutral_kitehook_runners.png", "icon_path": "res://art/units/battle_icons/unit_neutral_kitehook_runners.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_neutral_kitehook_runners.png", "sheet_path": "res://art/animation/runtime/units/unit_neutral_kitehook_runners.png",
		"source_sha256": "6da31ee07d76905c4f9f2885ab4c3218f266192a283b35c6a557fed4a0c2c921", "portrait_sha256": "7f14d86aafe80f79d4d47ca7ad71b6d957fe651bcf11bb563241029f899e7874", "icon_sha256": "86a2a404fe73b5a30a447ed5a4563c5084377ae3cbec852bbbe2921c5860ba9d", "overworld_icon_sha256": "ec27161f2916ddab9cdc1151c7ad705e88790bdc8249a5ff167f6630b8f9b267", "sheet_sha256": "8c6a4b54fe2575410bb43a04e5c620f9de0d5287a59fc88cb865286a55217f24",
		"old_portrait_sha256": "c22e0a47fd4eaf5cff9802ee497b0cfa28768b5cd14c6ef4a9e07b375614944d", "old_icon_sha256": "f296e80f0c354c04d05c8376987452e6fa83c2421668faec93c30d90f93ef993", "old_overworld_icon_sha256": "f0ebb4d41a72945cac318d1dca9d94794c61453c94f664eb7a66363e2d2f9ef2", "old_sheet_sha256": "a2baadf7b8e401a7a84602919cfd6056717d530ada69b3bc4ec96e2d87de3d9a",
	},
	{
		"unit_id": "unit_neutral_ridgeflare_shots", "label": "Ridgeflare Shots", "count": 4, "tier": 2, "role": "ranged", "growth": 5, "cost": {"gold": 90}, "ability_ids": ["volley"], "hp": 7, "attack": 5, "defense": 3, "min_damage": 2, "max_damage": 4, "speed": 5, "initiative": 8, "retaliations": 1, "ranged": true, "shots": 8,
		"source_path": "res://art/units/source/curated/unit_neutral_ridgeflare_shots.png", "portrait_path": "res://art/units/portraits/unit_neutral_ridgeflare_shots.png", "icon_path": "res://art/units/battle_icons/unit_neutral_ridgeflare_shots.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_neutral_ridgeflare_shots.png", "sheet_path": "res://art/animation/runtime/units/unit_neutral_ridgeflare_shots.png",
		"source_sha256": "277dd758df76c45f3c63a88ecb80ab261729231254ff12be6dc343b872f404ba", "portrait_sha256": "9371983b189d11e3917e9ff5e980be02f99b43335a110b76e4c590aeec525b23", "icon_sha256": "ac0a35205c94b9f9b41b65bc2d90665e744e4661022b3fa8bfb9eaa76d823df0", "overworld_icon_sha256": "17df016038f73f4bff5e54e20a90e7a1f8f4741beb80f3db8499373f359b2727", "sheet_sha256": "9737cf284f2ffca6a0d40d9ab1aae261df6a2592edf58123043a10c251a05c06",
		"old_portrait_sha256": "6b26f504b8c7d5aa1a5e287ef0bc12e342ce54451f1a1d762bec1abbf9a1cb4d", "old_icon_sha256": "a64a191b91384116ddd143d81081c709acbc4a925b50ed933338fd823bf0de7b", "old_overworld_icon_sha256": "10d332e5d700ea914b49d34e42af7b601c7c713ee5f53d9864484f76c47be25b", "old_sheet_sha256": "893bc3283673d3d0106ed4178603bea0f38fbf7c6f9caf88a3b20eaa0f29d421",
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
	_validate_authored_site_authority()
	await _validate_live_kite_battle_board()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "unit_count": UNITS.size(), "state_count": STATES.size(), "frames_per_state": FRAMES_PER_STATE, "visible_frame_count": UNITS.size() * STATES.size() * FRAMES_PER_STATE, "runtime_entry_count": int(_report.get("runtime", {}).get("entry_count", 0)), "authored_site_count": AUTHORED_SITE_ROWS.size()})])
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
	var dwelling: Dictionary = ContentService.get_neutral_dwelling("neutral_dwelling_kite_signal_eyrie")
	_expect(dwelling.get("unit_ids", []) == ["unit_neutral_kitehook_runners", "unit_neutral_ridgeflare_shots"], "Kite Signal Eyrie unit order changed.")
	_expect(dwelling.get("site_ids", []) == ["site_kite_signal_eyrie"] and dwelling.get("map_object_ids", []) == ["object_kite_signal_eyrie"], "Kite Signal Eyrie site/object graph changed.")
	_expect(dwelling.get("army_group_ids", []) == [SHARED_ARMY_ID] and dwelling.get("encounter_ids", []) == ["encounter_kite_signal_eyrie_watch"], "Kite Signal Eyrie army/encounter graph changed.")
	var proxy_catalog_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/homm3_re_reward_object_proxy_catalog.json"))
	var proxy_entries: Array = proxy_catalog_variant.get("entries", []) if proxy_catalog_variant is Dictionary else []
	var native_proxy_rows: Array = proxy_entries.filter(func(row): return row is Dictionary and String(row.get("id", "")) == "dwelling_creature_generator_pegasus_kite_signal_eyrie_proxy")
	_expect(native_proxy_rows.size() == 1 and int(native_proxy_rows[0].get("homm3_re_object_type_id", -1)) == 17 and int(native_proxy_rows[0].get("homm3_re_object_subtype", -1)) == 50 and int(native_proxy_rows[0].get("homm3_re_object_source_row", -1)) == 168 and String(native_proxy_rows[0].get("homm3_re_object_def_ref", "")) == "AVGpega0.def" and String(native_proxy_rows[0].get("native_proxy_object_id", "")) == "object_kite_signal_eyrie", "Native-RMG Kite Signal Eyrie subtype-50 projection changed.")
	_report["native_rmg_proxy"] = native_proxy_rows[0].duplicate(true) if native_proxy_rows.size() == 1 else {}
	var generated_rows: Array = RandomMapGeneratorRulesScript.DWELLING_SITE_CANDIDATES.filter(func(row): return row is Dictionary and String(row.get("site_id", "")) == "site_kite_signal_eyrie")
	_expect(generated_rows.size() == 1 and String(generated_rows[0].get("object_id", "")) == "object_kite_signal_eyrie" and String(generated_rows[0].get("neutral_dwelling_family_id", "")) == "neutral_dwelling_kite_signal_eyrie" and generated_rows[0].get("biome_ids", []) == ["biome_highland_ridge", "biome_coast_archipelago"] and String(generated_rows[0].get("guard_pressure", "")) == "medium", "Random-map Kite Signal Eyrie candidate changed.")
	_report["random_map_candidate"] = generated_rows[0].duplicate(true) if generated_rows.size() == 1 else {}
	var site: Dictionary = ContentService.get_resource_site("site_kite_signal_eyrie")
	_expect(_resource_cost_contract(site.get("claim_rewards", {})) == {"gold": 75} and _resource_cost_contract(site.get("claim_recruits", {})) == {"unit_neutral_kitehook_runners": 2, "unit_neutral_ridgeflare_shots": 1}, "Kite Signal Eyrie claim reward/recruit contract changed.")
	_expect(_resource_cost_contract(site.get("control_income", {})) == {"gold": 30} and _resource_cost_contract(site.get("weekly_recruits", {})) == {"unit_neutral_kitehook_runners": 1}, "Kite Signal Eyrie control income/weekly muster changed.")
	var encounter: Dictionary = ContentService.get_encounter("encounter_kite_signal_eyrie_watch")
	_expect(String(encounter.get("enemy_group_id", "")) == SHARED_ARMY_ID and String(encounter.get("terrain", "")) == "rough" and int(encounter.get("max_rounds", 0)) == 14, "Kite Signal Eyrie encounter authority changed.")
	_report["site_authority"] = {"claim_rewards": site.get("claim_rewards", {}).duplicate(true), "claim_recruits": site.get("claim_recruits", {}).duplicate(true), "control_income": site.get("control_income", {}).duplicate(true), "weekly_recruits": site.get("weekly_recruits", {}).duplicate(true), "encounter_id": encounter.get("id", ""), "enemy_group_id": encounter.get("enemy_group_id", "")}
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
		for stat_id in ["hp", "attack", "defense", "min_damage", "max_damage", "speed", "initiative", "retaliations"]:
			_expect(int(unit.get(stat_id, -1)) == int(spec[stat_id]), "%s %s changed." % [String(spec["label"]), stat_id])
		_expect(bool(unit.get("ranged", false)) == bool(spec["ranged"]), "%s ranged role flag changed." % String(spec["label"]))
		_expect(ability_ids == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		if int(spec["shots"]) >= 0:
			_expect(int(unit.get("shots", -1)) == int(spec["shots"]), "%s shot count changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": ability_ids})
	_report["content"] = rows

func _validate_authored_site_authority() -> void:
	var rows := []
	for expected_variant in AUTHORED_SITE_ROWS:
		var expected: Dictionary = expected_variant
		var scenario: Dictionary = ContentService.get_scenario(String(expected["scenario_id"]))
		var placement := _resource_placement(scenario, String(expected["placement_id"]))
		_expect(not placement.is_empty() and String(placement.get("site_id", "")) == String(expected["site_id"]), "%s must retain authored Kite Signal Eyrie site %s." % [String(expected["scenario_id"]), String(expected["placement_id"])])
		rows.append({"scenario_id": expected["scenario_id"], "placement_id": expected["placement_id"], "site_id": placement.get("site_id", "")})
	_report["authored_sites"] = rows

func _validate_live_kite_battle_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("ninefold-confluence", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var expected_counts := {"unit_neutral_kitehook_runners": 7, "unit_neutral_ridgeflare_shots": 4}
	var shared_army: Dictionary = ContentService.get_army_group(SHARED_ARMY_ID)
	_expect(String(shared_army.get("id", "")) == SHARED_ARMY_ID and _stack_counts(shared_army) == expected_counts, "Shared Kite Signal Eyrie Watch ids/counts changed.")
	var placement := {"placement_id": "kite_signal_eyrie_curated_art_fixture", "encounter_id": "encounter_kite_signal_eyrie_watch", "enemy_army": shared_army.duplicate(true), "x": 4, "y": 4, "resolved": false}
	var battle_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	var enemy_stacks: Array = battle_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_counts(enemy_stacks) == expected_counts, "Public Kite Signal Eyrie battle payload changed its exact enemy roster.")
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
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Kite Signal Eyrie stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_expect(session.to_dict() == authority_before, "BattleBoard art observation must not mutate the live Kite Signal Eyrie battle/session.")
	_report["runtime"] = {"shared_army_id": SHARED_ARMY_ID, "enemy_stack_counts": _battle_stack_counts(enemy_stacks), "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == authority_before}
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)

func _resource_placement(scenario: Dictionary, placement_id: String) -> Dictionary:
	for row in scenario.get("resource_nodes", []):
		if row is Dictionary and String(row.get("placement_id", "")) == placement_id:
			return row
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
