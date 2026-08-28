extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_NEUTRAL_HARBOR_PILOT_HOUSE_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_neutral_harbor_pilot_house_curated_art_report"
const SHARED_ARMY_ID := "army_neutral_harbor_pilot_house_watch"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const AUTHORED_SITE_ROWS := [
	{"scenario_id": "ninefold-confluence", "placement_id": "dwelling_harbor_pilot_house", "site_id": "site_harbor_pilot_house", "x": 52, "y": 24},
]
const UNITS := [
	{
		"unit_id": "unit_neutral_harbor_polearms", "label": "Harbor Polearms", "count": 6, "tier": 1, "role": "melee", "growth": 7, "cost": {"gold": 60}, "ability_ids": ["reach"], "hp": 9, "attack": 4, "defense": 4, "min_damage": 2, "max_damage": 4, "speed": 5, "initiative": 7, "retaliations": 1, "ranged": false, "shots": -1,
		"source_path": "res://art/units/source/curated/unit_neutral_harbor_polearms.png", "portrait_path": "res://art/units/portraits/unit_neutral_harbor_polearms.png", "icon_path": "res://art/units/battle_icons/unit_neutral_harbor_polearms.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_neutral_harbor_polearms.png", "sheet_path": "res://art/animation/runtime/units/unit_neutral_harbor_polearms.png",
		"source_sha256": "34c08101e5264935c71230fc4efef3f0974b2f060e126b500e4bdd3b75f5bc0e", "portrait_sha256": "ac2d9d73562312d8ed41958c21439d45ab9ed91d76fbd1ad6b14b6af1a2b0df9", "icon_sha256": "308c6f8b394248ad89420a60e62fc0235b6f03bb9855f034e80a2a47fe1176fa", "overworld_icon_sha256": "4f5aac270722c788d851a5619be7bf6a341fda6e82d91216055aa73374e1c30f", "sheet_sha256": "bfa195928549022183d326a617cfd59c217f6e33ad5c665ebcfab5e3977ef602",
		"old_portrait_sha256": "ad5df9cfc7ed4632a6801d442adbe5f99c802531826782cdc4af32378e5d31c6", "old_icon_sha256": "c7b945909963b37983aa388f6ce3de4f8950d5f548297f1110a6dd01732b3484", "old_overworld_icon_sha256": "bc0a74c02a674a04462a56caeada915bf6df20c584d7a24b0503eb0df11144c4", "old_sheet_sha256": "d9799da71d30d7e95dee8a3a83883be4a302dc2195d4f361cf073623f45b91bb",
	},
	{
		"unit_id": "unit_neutral_flaremast_crews", "label": "Flaremast Crews", "count": 3, "tier": 2, "role": "ranged", "growth": 5, "cost": {"gold": 85}, "ability_ids": ["volley"], "hp": 7, "attack": 5, "defense": 3, "min_damage": 2, "max_damage": 4, "speed": 4, "initiative": 7, "retaliations": 1, "ranged": true, "shots": 7,
		"source_path": "res://art/units/source/curated/unit_neutral_flaremast_crews.png", "portrait_path": "res://art/units/portraits/unit_neutral_flaremast_crews.png", "icon_path": "res://art/units/battle_icons/unit_neutral_flaremast_crews.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_neutral_flaremast_crews.png", "sheet_path": "res://art/animation/runtime/units/unit_neutral_flaremast_crews.png",
		"source_sha256": "23e7a25a6d651c1b4f3a56b588c5586689462f8a9d720ba82fb0b3c2c1935af7", "portrait_sha256": "5ebdc1ce6962ba97d238014689f4b28fd97f78b029e51570dd930ab1251ec6d7", "icon_sha256": "e3e153bf298be7f22b0e5ceded4ff792934f20165580d979fb13e4beedf847d1", "overworld_icon_sha256": "42a57f5f6a4a2319ade2239dd28fd05d397d4d9512638608b043560d6a4e786f", "sheet_sha256": "d4be2eef86ba1efe121f9cb8b123cb38d36ffe6b3923c61e15d38020b555610f",
		"old_portrait_sha256": "32009ffe4e009ddb62fe229a6b68c5ff4098f46d0d252f8361da16d5ccb5b6e8", "old_icon_sha256": "6f6fa3780380a59fe8b74c6344651967d2720088ed28d90fb65086f5698fef5f", "old_overworld_icon_sha256": "1399fd204ff94fe586ab68e58d3e2b038eb11ff8441d48eff5368810fec52d70", "old_sheet_sha256": "954e40ff4952dbb53f21e6d3d45973725325aeeed802bc7093b81394d5de6bb1",
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
	await _validate_live_harbor_pilot_house_battle_board()
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
	var dwelling: Dictionary = ContentService.get_neutral_dwelling("neutral_dwelling_harbor_pilot_house")
	_expect(dwelling.get("unit_ids", []) == ["unit_neutral_harbor_polearms", "unit_neutral_flaremast_crews"], "Harbor Pilot House unit order changed.")
	_expect(dwelling.get("site_ids", []) == ["site_harbor_pilot_house"] and dwelling.get("map_object_ids", []) == ["object_harbor_pilot_house"], "Harbor Pilot House site/object graph changed.")
	_expect(dwelling.get("army_group_ids", []) == [SHARED_ARMY_ID] and dwelling.get("encounter_ids", []) == ["encounter_harbor_pilot_house_watch"], "Harbor Pilot House army/encounter graph changed.")
	var generated_site_rows: Array = RandomMapGeneratorRulesScript.DWELLING_SITE_CANDIDATES.filter(func(row): return row is Dictionary and String(row.get("site_id", "")) == "site_harbor_pilot_house")
	_expect(generated_site_rows.is_empty(), "Harbor Pilot House must not gain a RandomMapGeneratorRules candidate as part of its art-only slice.")
	_report["generated_map_site_rows"] = generated_site_rows.duplicate(true)
	var proxy_catalog_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/homm3_re_reward_object_proxy_catalog.json"))
	var proxy_entries: Array = proxy_catalog_variant.get("entries", []) if proxy_catalog_variant is Dictionary else []
	var native_proxy_rows: Array = proxy_entries.filter(func(row): return row is Dictionary and String(row.get("native_proxy_object_id", "")) == "object_harbor_pilot_house")
	_expect(native_proxy_rows.is_empty(), "Harbor Pilot House must not gain a Native-RMG proxy as part of its art-only slice.")
	_report["native_rmg_proxy_rows"] = native_proxy_rows.duplicate(true)
	var site: Dictionary = ContentService.get_resource_site("site_harbor_pilot_house")
	_expect(_resource_cost_contract(site.get("claim_rewards", {})) == {"gold": 60} and _resource_cost_contract(site.get("claim_recruits", {})) == {"unit_neutral_flaremast_crews": 1, "unit_neutral_harbor_polearms": 2}, "Harbor Pilot House claim reward/recruit contract changed.")
	_expect(_resource_cost_contract(site.get("control_income", {})) == {"gold": 25} and _resource_cost_contract(site.get("weekly_recruits", {})) == {"unit_neutral_harbor_polearms": 1}, "Harbor Pilot House control income/weekly muster changed.")
	var encounter: Dictionary = ContentService.get_encounter("encounter_harbor_pilot_house_watch")
	_expect(String(encounter.get("enemy_group_id", "")) == SHARED_ARMY_ID and String(encounter.get("terrain", "")) == "coast" and encounter.get("battlefield_tags", []) == ["open_lane", "fog_bank"] and int(encounter.get("max_rounds", 0)) == 13, "Harbor Pilot House encounter authority changed.")
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
		_expect(not placement.is_empty() and String(placement.get("site_id", "")) == String(expected["site_id"]) and int(placement.get("x", -1)) == int(expected["x"]) and int(placement.get("y", -1)) == int(expected["y"]), "%s must retain authored Harbor Pilot House site %s at its exact placement." % [String(expected["scenario_id"]), String(expected["placement_id"])])
		rows.append({"scenario_id": expected["scenario_id"], "placement_id": expected["placement_id"], "site_id": placement.get("site_id", ""), "x": placement.get("x", -1), "y": placement.get("y", -1)})
	_report["authored_sites"] = rows

func _validate_live_harbor_pilot_house_battle_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("ninefold-confluence", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var expected_counts := {"unit_neutral_harbor_polearms": 6, "unit_neutral_flaremast_crews": 3}
	var shared_army: Dictionary = ContentService.get_army_group(SHARED_ARMY_ID)
	_expect(String(shared_army.get("id", "")) == SHARED_ARMY_ID and _stack_counts(shared_army) == expected_counts, "Shared Harbor Pilot House Watch ids/counts changed.")
	var placement := {"placement_id": "harbor_pilot_house_curated_art_fixture", "encounter_id": "encounter_harbor_pilot_house_watch", "enemy_army": shared_army.duplicate(true), "x": 4, "y": 4, "resolved": false}
	var battle_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	var enemy_stacks: Array = battle_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_counts(enemy_stacks) == expected_counts, "Public Harbor Pilot House battle payload changed its exact enemy roster.")
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
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s Harbor Pilot House stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_expect(session.to_dict() == authority_before, "BattleBoard art observation must not mutate the live Harbor Pilot House battle/session.")
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
