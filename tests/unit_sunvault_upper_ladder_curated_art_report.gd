extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_SUNVAULT_UPPER_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_sunvault_upper_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_sunvault_solar_array_striders", "label": "Solar Array Striders", "tier": 5, "role": "melee", "growth": 2, "ability_ids": ["solar_array_lane"], "cost": {"gold": 430, "ore": 2},
		"building_id": "building_sunvault_zenith_observatory", "building_growth": 3, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_sunvault_solar_array_striders.png", "portrait_path": "res://art/units/portraits/unit_sunvault_solar_array_striders.png", "icon_path": "res://art/units/battle_icons/unit_sunvault_solar_array_striders.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_sunvault_solar_array_striders.png", "sheet_path": "res://art/animation/runtime/units/unit_sunvault_solar_array_striders.png",
		"source_sha256": "38b54e8fc5921b71641d61385457e3281746b2f3bb585c7c39e82d0f8b52b5ec", "portrait_sha256": "9d5a200cd0e9ab5cbf48c4918f6f30bd439a516bcb624147f971649f49afb29d", "icon_sha256": "88f5d2494b1624be300c8f50dd3a2fc31acf5f2b5d37f2430eb7772902cd3820", "overworld_icon_sha256": "32d05f743c03a38b55f6649acb8b978a6546c3833d6e5f601fd3f6a6d71394b2", "sheet_sha256": "7b61644e7997d23aab889ff8ea38f9774e6852ddd91f99c2b82b87a04dd2bed7",
		"old_portrait_sha256": "c1482941c84d7c1507002c76f9b795d600fc0a8f8d8b80161290fec5cc6f6b48", "old_icon_sha256": "e068227af96084e4ff61da71ffbd352a3f1501905b3fb0743fbea1819cd8c7f3", "old_overworld_icon_sha256": "636f96edcf8d5e1d5b362996d031b51edf245181482e5c7f5b9cb986a3118458", "old_sheet_sha256": "926d054634722e721cfaed0f833a4cd427e5a46e57502de5c5d310f008f47bc4",
	},
	{
		"unit_id": "unit_sunvault_aurora_ballistae", "label": "Aurora Bastions", "tier": 6, "role": "melee", "growth": 1, "ability_ids": ["shielding"], "cost": {"gold": 720, "wood": 2, "ore": 3},
		"building_id": "building_sunvault_aurora_spire", "building_growth": 2, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_sunvault_aurora_ballistae.png", "portrait_path": "res://art/units/portraits/unit_sunvault_aurora_ballistae.png", "icon_path": "res://art/units/battle_icons/unit_sunvault_aurora_ballistae.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_sunvault_aurora_ballistae.png", "sheet_path": "res://art/animation/runtime/units/unit_sunvault_aurora_ballistae.png",
		"source_sha256": "5da13b638c1e3c42999f1f22d095a1f99e43bd5088b2a171cbf1125f649f6222", "portrait_sha256": "b5ab9f7e2a14d05d94359e20056778d614538f74b6b6fbf8da8982c7e97e749e", "icon_sha256": "d26d0cb6e6fc7d7fd83cbe23c36d6441cb6cf2b322b739e7a12f1aab46ce350d", "overworld_icon_sha256": "a3f09c145f59df97d38be7c638f0f81173e137f2bd953e5883a3b33314c4d8ec", "sheet_sha256": "99a9f16f1e068f36dc0c34bf5564cd1afcece580270904018a2c9747542390fb",
		"old_portrait_sha256": "ffbc2c6dae600fc32aadb6720e21f9d682f4abb71c0fec3dadf8bdbf4ab10534", "old_icon_sha256": "272f7f2376a7bf258d9d5b205bf3eddb8db1961e00a6ecdcbbe9d72b60829b28", "old_overworld_icon_sha256": "0116b9cb4c3ea4b765715a8d94610663f8c9dfb299fdece1fa3307e9ee26bd20", "old_sheet_sha256": "7a9014ade06e486b48b5d1f3a2473ce1423c497cecd86e4b9a2f95ca415bdffa",
	},
	{
		"unit_id": "unit_sunvault_daybreak_colossus", "label": "Daybreak Colossus", "tier": 7, "role": "ranged", "growth": 1, "ability_ids": ["volley"], "cost": {"gold": 1450, "ore": 4},
		"building_id": "building_sunvault_daybreak_matrix", "building_growth": 1, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_sunvault_daybreak_colossus.png", "portrait_path": "res://art/units/portraits/unit_sunvault_daybreak_colossus.png", "icon_path": "res://art/units/battle_icons/unit_sunvault_daybreak_colossus.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_sunvault_daybreak_colossus.png", "sheet_path": "res://art/animation/runtime/units/unit_sunvault_daybreak_colossus.png",
		"source_sha256": "41a17f5ace0bb3ec28c3936b68fe5353b85cf901e52e2dc61ea3075e5fb62810", "portrait_sha256": "57c9098b1d215bf165d823cf933f1505f7e470a71d5fc96d8efcba9f88a81aa9", "icon_sha256": "4325fdbf38bd1dc61ca99e365d4766d7a41fda80b260d4f44e95e16a4ae7273d", "overworld_icon_sha256": "bba056e7e779db9c0ed314846552971e75fc1feb8b5cc638a0d0f0537f8460bb", "sheet_sha256": "7f10c8bef3249ecbafea8e54bf12c5dbaae30452ea87c303ad1c212c221bd3c7",
		"old_portrait_sha256": "cdc6ea7d2b0aa7bbddb131b427655a7d3d97269c2de2d15745b68ac508683197", "old_icon_sha256": "783c6cb9830cd4e77cfa54dbb4837494c5c266e7d97106825f138d4cc5ae878e", "old_overworld_icon_sha256": "91e01432b71f489b312314576a468e46b6ae8049a2177f2db68f10ec0b717303", "old_sheet_sha256": "a63556f84e6f26aa3da840f86c1c70c3c15684b9872d4bdcdda52de581c0ecd0",
	},
]
const PRESERVED_CURATED_LADDER := [
	{"unit_id": "unit_sunvault_shard_wardens", "portrait_sha256": "6b764f7953928a9c16536de6034a8c4489dc212d6a8d478adf90a4be00398b2f", "icon_sha256": "c67bd35661ec41e5d418d5f3a460263b75f48ac2107ac8d592be870f9662a828", "overworld_icon_sha256": "166ff2b95577da980e6cecd16e3cfa05cee4db3e6693ea85ade8d22dc0b05502", "sheet_sha256": "03975b8721e998b4157960c7dcfed3e2da69478312c46e05592ac070eeddd77c"},
	{"unit_id": "unit_sunvault_prism_adepts", "portrait_sha256": "b9f5d46310e9912af434b01ebda9e4c82fb4fb438913ed993945c883b0874844", "icon_sha256": "bfcc0c3db10697bbcd238a80ca6231be8ed462397839e98f49c2ffa9fa3e6e36", "overworld_icon_sha256": "16315ed24b76dbae922e8c00687bc10193db7144f1621bceaeb4f6ca795069e9", "sheet_sha256": "06f438a00dbca30b16eed50e3886d78b7fd39aadc0c247c9d747ed90a46131c4"},
	{"unit_id": "unit_sunvault_mirror_duelists", "portrait_sha256": "df279ae76c27858c942b2336b40e0306d5d55898d958c650be2fa88e4e1409d8", "icon_sha256": "7c93928367464f647ebb21c02286a43ab519fccb7d0c83d6a90b251aed82362e", "overworld_icon_sha256": "194f80558265b126b70affa773497ca58eee3a0f9712603b3b860a46ff8afd73", "sheet_sha256": "1383c95ca80ef17dfda7dfbdcbaad4591e2b0ed2500cc9d0c2d89f09e8e16158"},
	{"unit_id": "unit_sunvault_resonant_choristers", "portrait_sha256": "f4b0ef32741aa235cd5a6560c61ab310f1d849ed5739c850302875b69da675f0", "icon_sha256": "42d20bd1d43d0606cd36f5957a1debba7878f8937fbca7a5a5cefd31cdedd24b", "overworld_icon_sha256": "624e93ddb9a3f0d988a50e54b88409fa75f17d17badaa142679d6e99c17dad9c", "sheet_sha256": "18136cffb00f6675592f9cc7d6b25a1e81ac7aee70661dfd7f6d30efd90979f0"},
]
const PRESERVED_SURFACE_DIRS := {"portrait": "units/portraits", "icon": "units/battle_icons", "overworld_icon": "units/overworld_icons", "sheet": "animation/runtime/units"}

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "content": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	_validate_content_authority()
	await _validate_live_sunvault_and_board()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "unit_count": UNITS.size(), "content_row_count": int(_report.get("content", []).size()), "state_count": STATES.size(), "frames_per_state": FRAMES_PER_STATE, "visible_frame_count": UNITS.size() * STATES.size() * FRAMES_PER_STATE, "board_entry_count": int(_report.get("runtime", {}).get("entry_count", 0))})])
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
		_expect(int(source_alpha.get("transparent", 0)) > 50000 and int(source_alpha.get("visible", 0)) > 30000 and int(source_alpha.get("strong", 0)) > 50000, "%s source must retain transparent negative space and a materially strong silhouette." % label)
		_expect(bool(source_alpha.get("corners_transparent", false)), "%s source corners must remain transparent." % label)
		for key in ["source", "portrait", "icon", "overworld_icon", "sheet"]:
			var hash_key := "%s_sha256" % key
			_expect(FileAccess.get_sha256(String(spec["%s_path" % key])) == String(spec[hash_key]), "%s %s hash drifted." % [label, key])
			if key != "source":
				_expect(String(spec[hash_key]) != String(spec["old_%s_sha256" % key]), "%s %s did not replace the generated payload." % [label, key])
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
		rows.append({"unit_id": spec["unit_id"], "source_sha256": spec["source_sha256"], "source_alpha": source_alpha, "states": state_rows})
	for preserved_variant in PRESERVED_CURATED_LADDER:
		var preserved: Dictionary = preserved_variant
		var unit_id := String(preserved["unit_id"])
		for key in ["portrait", "icon", "overworld_icon", "sheet"]:
			var path := "res://art/%s/%s.png" % [String(PRESERVED_SURFACE_DIRS[key]), unit_id]
			_expect(FileAccess.get_sha256(path) == String(preserved["%s_sha256" % key]), "The curated Sunvault tier-1 through tier-4 ladder %s %s changed." % [unit_id, key])
	_report["assets"] = rows

func _validate_content_authority() -> void:
	var faction: Dictionary = ContentService.get_faction("faction_sunvault")
	var ladder := _string_array(faction.get("unit_ladder_ids", []))
	var buildings := _string_array(faction.get("signature_building_ids", []))
	_expect(ladder.slice(4, 7) == _target_ids(), "Sunvault upper-ladder faction order changed.")
	_expect(buildings.slice(4, 7) == _building_ids(), "Sunvault upper-ladder building order changed.")
	_expect(String(faction.get("seed_town_id", "")) == "town_prismhearth", "Sunvault seed town changed.")
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var unit: Dictionary = ContentService.get_unit(String(spec["unit_id"]))
		var building: Dictionary = ContentService.get_building(String(spec["building_id"]))
		_expect(String(unit.get("name", "")) == String(spec["label"]), "%s name changed." % String(spec["label"]))
		_expect(String(unit.get("faction_id", "")) == "faction_sunvault" and int(unit.get("tier", 0)) == int(spec["tier"]) and String(unit.get("role", "")) == String(spec["role"]), "%s faction/tier/role changed." % String(spec["label"]))
		_expect(int(unit.get("growth", 0)) == int(spec["growth"]) and _resource_cost_contract(unit.get("cost", {})) == spec["cost"], "%s growth/cost changed." % String(spec["label"]))
		_expect(_ability_ids(unit.get("abilities", [])) == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		_expect(String(building.get("unlock_unit_id", "")) == String(spec["unit_id"]), "%s building unlock changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("growth_bonus", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_growth"]), "%s building growth changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("recruitment_discount_percent", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_discount"]), "%s building discount changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": _ability_ids(unit.get("abilities", [])), "building_id": spec["building_id"], "building_growth": spec["building_growth"], "building_discount": spec["building_discount"]})
	_report["content"] = rows

func _validate_live_sunvault_and_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("charter-bastion-counterseal", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "Charter Bastion Counterseal must create a live session.")
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var placement := _encounter_placement(session, "counterseal_aurora_battery")
	_expect(not placement.is_empty(), "Counterseal Aurora Battery must remain a live encounter fixture.")
	if placement.is_empty():
		return
	var authored_army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
	var authored_stacks := [{"unit_id": "unit_sunvault_shard_wardens", "count": 5}, {"unit_id": "unit_sunvault_prism_adepts", "count": 2}, {"unit_id": "unit_sunvault_aurora_ballistae", "count": 1}]
	_expect(String(authored_army.get("id", "")) == "army_counterseal_aurora_battery" and _stack_contract(authored_army.get("stacks", [])) == authored_stacks, "The authored Counterseal Aurora Battery changed.")
	var authority_before: Dictionary = session.to_dict()
	var fixture_placement: Dictionary = placement.duplicate(true)
	fixture_placement["placement_id"] = "sunvault_upper_ladder_art_fixture"
	fixture_placement["enemy_army"] = {"id": "army_sunvault_upper_ladder_art_fixture", "name": "Sunvault Upper Ladder Art Fixture", "faction_id": "faction_sunvault", "stacks": [{"unit_id": UNITS[0]["unit_id"], "count": 3}, {"unit_id": UNITS[1]["unit_id"], "count": 2}, {"unit_id": UNITS[2]["unit_id"], "count": 1}]}
	var fixture_payload: Dictionary = BattleRulesScript.create_battle_payload(session, fixture_placement)
	var fixture_enemy: Array = fixture_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(fixture_enemy) == fixture_placement["enemy_army"]["stacks"], "Production battle materialization changed the three-unit upper ladder fixture.")
	var fixture_ability_contract := _battle_target_ability_contract(fixture_enemy)
	_expect(fixture_ability_contract == {"unit_sunvault_solar_array_striders": ["solar_array_lane"], "unit_sunvault_aurora_ballistae": ["shielding"], "unit_sunvault_daybreak_colossus": ["volley"]}, "Production battle materialization changed normalized Sunvault upper-ladder abilities: %s." % JSON.stringify(fixture_ability_contract))
	_expect(session.to_dict() == authority_before, "Upper-ladder battle materialization mutated the session.")
	session.battle = fixture_payload
	var board_authority_before: Dictionary = session.to_dict()
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
			if entry is Dictionary and String(entry.get("battle_id", "")).begins_with("enemy_") and String(entry.get("unit_id", "")) == String(spec["unit_id"]):
				matches.append(entry.duplicate(true))
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_expect(session.to_dict() == board_authority_before, "BattleBoard art observation mutated the battle/session.")
	_expect(entries.size() == UNITS.size(), "BattleBoard must expose all three Sunvault upper-ladder stacks.")
	_report["runtime"] = {"scenario_id": "charter-bastion-counterseal", "authored_army_id": String(authored_army.get("id", "")), "authored_stacks": _stack_contract(authored_army.get("stacks", [])), "fixture_placement_id": "sunvault_upper_ladder_art_fixture", "fixture_stacks": _battle_stack_contract(fixture_enemy), "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == board_authority_before}
	board.queue_free()
	await get_tree().process_frame
	SessionState.set_active_session(null)

func _target_ids() -> Array:
	var result := []
	for spec in UNITS:
		result.append(String(spec["unit_id"]))
	return result

func _building_ids() -> Array:
	var result := []
	for spec in UNITS:
		result.append(String(spec["building_id"]))
	return result

func _string_array(value: Variant) -> Array:
	var result := []
	for item in value if value is Array else []:
		result.append(String(item))
	return result

func _ability_ids(value: Variant) -> Array:
	var result := []
	for ability in value if value is Array else []:
		if ability is Dictionary:
			result.append(String(ability.get("id", "")))
	return result

func _resource_cost_contract(cost_value: Variant) -> Dictionary:
	var result := {}
	if not cost_value is Dictionary:
		return result
	for resource_id in cost_value:
		result[String(resource_id)] = int(cost_value[resource_id])
	return result

func _encounter_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _stack_contract(stacks_value: Variant) -> Array:
	var result := []
	for stack in stacks_value if stacks_value is Array else []:
		if stack is Dictionary:
			result.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0))})
	return result

func _battle_stack_contract(stacks: Array) -> Array:
	var result := []
	for stack in stacks:
		if stack is Dictionary:
			result.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("base_count", 0))})
	return result

func _battle_target_ability_contract(stacks: Array) -> Dictionary:
	var result := {}
	for stack in stacks:
		if not stack is Dictionary:
			continue
		var unit_id := String(stack.get("unit_id", ""))
		if unit_id not in _target_ids():
			continue
		result[unit_id] = _ability_ids(stack.get("abilities", []))
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
				if alpha >= 0.5:
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
