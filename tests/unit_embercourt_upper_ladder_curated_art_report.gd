extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_EMBERCOURT_UPPER_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_embercourt_upper_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_embercourt_ash_oath_bailiffs", "label": "Ash-Oath Bailiffs", "tier": 4, "role": "melee", "growth": 3, "ability_ids": ["brace"], "cost": {"gold": 260, "ore": 1},
		"building_id": "building_embercourt_oath_pikehall", "building_growth": 4, "building_discount": 6,
		"source_path": "res://art/units/source/curated/unit_embercourt_ash_oath_bailiffs.png", "portrait_path": "res://art/units/portraits/unit_embercourt_ash_oath_bailiffs.png", "icon_path": "res://art/units/battle_icons/unit_embercourt_ash_oath_bailiffs.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_embercourt_ash_oath_bailiffs.png", "sheet_path": "res://art/animation/runtime/units/unit_embercourt_ash_oath_bailiffs.png",
		"source_sha256": "fe7e30b782f0034eff222a82c96d8c97be3a6d1a6bc49b1c5be54f1005dd43cb", "portrait_sha256": "064af6ad7722b0e536fc0791afb6d50afc13e216a932084e3b3107349d44d212", "icon_sha256": "383754fec3a50433c471c17cabcc18403bb197e44a6049845f33c1495306a4bc", "overworld_icon_sha256": "9d62c0dbe216507507fa7a9e5e33ba14b646d11dde8cea1289559ac136631acf", "sheet_sha256": "4103027a7c743349668ee935acf4f4bf4258206d55f180dc6baaf8c6e191417e",
		"old_portrait_sha256": "6ee0877ef266215b3c5e801a366d4257ab8128bafdf1836146ddf7b92b71dd92", "old_icon_sha256": "bfc754f60ef6d04476fe6db92c33a41ab56af0f8713a5440db14efc7d82001d0", "old_overworld_icon_sha256": "9979fa5e8637be51456450774c93694a42bc5463f003aa56a21b764602ebda1d", "old_sheet_sha256": "89cccfdb0e03eeddfa731c4b2346f0e207b3dc7bef5c94f14ddc9071e94bef3f",
	},
	{
		"unit_id": "unit_embercourt_beacon_lectors", "label": "Beacon Lectors", "tier": 5, "role": "ranged", "growth": 2, "ability_ids": ["harry", "readiness_writ"], "cost": {"gold": 360, "wood": 1, "ore": 1},
		"building_id": "building_embercourt_beacon_court", "building_growth": 3, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_embercourt_beacon_lectors.png", "portrait_path": "res://art/units/portraits/unit_embercourt_beacon_lectors.png", "icon_path": "res://art/units/battle_icons/unit_embercourt_beacon_lectors.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_embercourt_beacon_lectors.png", "sheet_path": "res://art/animation/runtime/units/unit_embercourt_beacon_lectors.png",
		"source_sha256": "eac36ce8dd45c0ba99bb363a16c5fdae1aa561e572ad2e431ec906b92df8cd27", "portrait_sha256": "984465d0fe0540859f9477aadd91165a90efa0264fb073da6f16fadbfae1c538", "icon_sha256": "bc6e4ec1d605ef234326766da1cdddec492b44e20cafdc0b649f743a1eb8aa44", "overworld_icon_sha256": "b9e1c3f026237b2b9120771b2b30524d0f953c55e9ff8fd4a37581d626b376a2", "sheet_sha256": "e6ac1a4b85e0eb59be4af5426f8c987ddc4dd424e068bee3669bf6f004eafe84",
		"old_portrait_sha256": "60f69def204a2f4f8f78f74530156f96ca88a552567a7e04ebf90acbba2b360b", "old_icon_sha256": "5d853e1205d5dbfbe3be84b8a02b3d2f3f0dac1b7f12e5d4aa0d24b7216115a5", "old_overworld_icon_sha256": "ab0a31b6822cccd76b9e02e310cce08b738019986cb739c931a20ebe55422152", "old_sheet_sha256": "af23c4f804b3ed8c3f797fb83de0f15efcf88bcc060828650e9da2466b799376",
	},
	{
		"unit_id": "unit_embercourt_sluicefire_lindworms", "label": "Sluicefire Lindworms", "tier": 6, "role": "melee", "growth": 1, "ability_ids": ["bloodrush"], "cost": {"gold": 700, "ore": 2},
		"building_id": "building_embercourt_drake_sluice", "building_growth": 2, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_embercourt_sluicefire_lindworms.png", "portrait_path": "res://art/units/portraits/unit_embercourt_sluicefire_lindworms.png", "icon_path": "res://art/units/battle_icons/unit_embercourt_sluicefire_lindworms.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_embercourt_sluicefire_lindworms.png", "sheet_path": "res://art/animation/runtime/units/unit_embercourt_sluicefire_lindworms.png",
		"source_sha256": "1130c1b2ca3cf24264cfe21d54409401c365d18e71403180bc9f052134cd1f29", "portrait_sha256": "7f0a3a6cb8aa9dd10d541e7a2a452d40e5c1ad97e1b202826ae55f96d1886c4f", "icon_sha256": "7868148dc56b82426be10630b75ad7711d1f8d719846bad87a38ffebbcdf4a81", "overworld_icon_sha256": "c23d05ec665ee2fd2c7b4333377643e372157e1cc88c6a93dbf6c2f94470f761", "sheet_sha256": "dc93b0aef0322a4583aaf5ca5183dc885dff05bc736a9f8dab5e4dc39141ed9e",
		"old_portrait_sha256": "f27cf06850cdf99563bc74f66ecd2d3692d427c51c1ea2827fe6682279d67192", "old_icon_sha256": "f1cdf4c400b8925229edab0cca55293a58b9103389a5d0073a8532f454a050e9", "old_overworld_icon_sha256": "8b3d84f61d96ef5cdb434ad5a043bb5897dadf6894fa21f15c0745d891069d51", "old_sheet_sha256": "14477a1a27be160ea8d4ac2b36866df6783e6dc15c525e7699362835320b87cf",
	},
	{
		"unit_id": "unit_embercourt_charter_colossus", "label": "Charter Colossus", "tier": 7, "role": "melee", "growth": 1, "ability_ids": ["brace"], "cost": {"gold": 1400, "wood": 2, "ore": 3},
		"building_id": "building_embercourt_charter_bastion", "building_growth": 1, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_embercourt_charter_colossus.png", "portrait_path": "res://art/units/portraits/unit_embercourt_charter_colossus.png", "icon_path": "res://art/units/battle_icons/unit_embercourt_charter_colossus.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_embercourt_charter_colossus.png", "sheet_path": "res://art/animation/runtime/units/unit_embercourt_charter_colossus.png",
		"source_sha256": "3618421aabafc6112bd5b46e4bdf350bbe7826c87dbaaa2e34c6df24763d6478", "portrait_sha256": "612359cb3899cbcd55daf93f27e5eb149a6205d10d4fae600c9cad6cb512d767", "icon_sha256": "9a4d60a514d5f21a8e2350bc63a739156010d59cc6b29dcb418ffc4c58ccd1b7", "overworld_icon_sha256": "42ad4fc00e882946fea6cd376d952f6e2e8080cdab77e2c70f7a1c7d557bc26e", "sheet_sha256": "247b52cbe40912852eabfd8723345c355eb06d7a72adfe1b7663b8e7cc3670ab",
		"old_portrait_sha256": "6da68f9df4c890510dec9ec9243251dee27c37cbfd1d451bf6265e0595905a1f", "old_icon_sha256": "f3b02d818754b0938a16221a2408eda03ec681aedc564149846ca610789c3519", "old_overworld_icon_sha256": "7c82091cf9571fd1cc9ecd91077d390bd6bdcd478a82cc557d5387f35b951161", "old_sheet_sha256": "762ca19c2ec8e92592be2452f49993e458505195528e29d3da1bb7befdc0e547",
	},
]
const PRESERVED_EARLY_LADDER := [
	{"unit_id": "unit_embercourt_fordhook_cadets", "portrait_sha256": "ea1cce2c724f85b39f44756a1cea689c6ed75cc2d9ca9a5143ed2803d6375d07", "icon_sha256": "9ed1ac039d88abfd06d83ad1bcf7e5b970df999d245010be651b3cc3b96e1d87", "overworld_icon_sha256": "5b610954d52052f7e04e056af4ab84adf84a70bdb056ff711f4218e30472ed15", "sheet_sha256": "1aa44e4b02fd4177b0d9980f19fe3d00c38865083e96fab1bec0166a6b6382a8"},
	{"unit_id": "unit_embercourt_lantern_sappers", "portrait_sha256": "064e2d33e73565c29866b45d38bb16df10cb3bae48da44a4ebe9018c015d7977", "icon_sha256": "b8d231cc7ec1f19eda0cb33b607ad8e8b0fe1369961d0683a25f47a729c63535", "overworld_icon_sha256": "96bd9a8baeafec8b9d30f018bdb576e74a4d30cc9fe1768145c3ccd4e87d3adc", "sheet_sha256": "8fabd2323b4d887b3d292e220fc56919ec69b6884edd562e3c1222b7b1678061"},
	{"unit_id": "unit_embercourt_bargebow_crews", "portrait_sha256": "ade82e81aa78fe54737a8f9642a0a71651ee9f17cba39ddcb34f89b9cad0164b", "icon_sha256": "21471a399e804968c33bbff6fd9a266cef39b4943480f73512fdd779e333af89", "overworld_icon_sha256": "20290de8cbe5fa3d4d3f51f93a6f74c5e69bf100924f47f57be7b90bbb7e9890", "sheet_sha256": "ef9d51712f342cc47c92a9598dfdcb74fe99e2ff57bde4b76424e04b27f9b036"},
]
const PRESERVED_SURFACE_DIRS := {"portrait": "units/portraits", "icon": "units/battle_icons", "overworld_icon": "units/overworld_icons", "sheet": "animation/runtime/units"}
const CLAUSEWORKS_STACKS := [{"unit_id": "unit_embercourt_fordhook_cadets", "count": 5}, {"unit_id": "unit_embercourt_bargebow_crews", "count": 5}, {"unit_id": "unit_embercourt_sluicefire_lindworms", "count": 1}]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "content": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	_validate_content_authority()
	await _validate_live_clauseworks_and_board()
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
		_expect(int(source_alpha.get("transparent", 0)) > 50000 and int(source_alpha.get("visible", 0)) > 30000 and int(source_alpha.get("opaque", 0)) > 10000, "%s source must retain transparent negative space and a materially opaque silhouette." % label)
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
	for preserved_variant in PRESERVED_EARLY_LADDER:
		var preserved: Dictionary = preserved_variant
		var unit_id := String(preserved["unit_id"])
		for key in ["portrait", "icon", "overworld_icon", "sheet"]:
			var path := "res://art/%s/%s.png" % [String(PRESERVED_SURFACE_DIRS[key]), unit_id]
			_expect(FileAccess.get_sha256(path) == String(preserved["%s_sha256" % key]), "The curated Embercourt early-ladder %s %s changed." % [unit_id, key])
	_report["assets"] = rows

func _validate_content_authority() -> void:
	var faction: Dictionary = ContentService.get_faction("faction_embercourt")
	var ladder := _string_array(faction.get("unit_ladder_ids", []))
	var buildings := _string_array(faction.get("signature_building_ids", []))
	_expect(ladder.slice(3, 7) == _target_ids(), "Embercourt upper-ladder faction order changed.")
	_expect(buildings.slice(3, 7) == _building_ids(), "Embercourt upper-ladder building order changed.")
	_expect(String(faction.get("seed_town_id", "")) == "town_highwater_keep", "Embercourt seed town changed.")
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var unit: Dictionary = ContentService.get_unit(String(spec["unit_id"]))
		var building: Dictionary = ContentService.get_building(String(spec["building_id"]))
		_expect(String(unit.get("name", "")) == String(spec["label"]), "%s name changed." % String(spec["label"]))
		_expect(String(unit.get("faction_id", "")) == "faction_embercourt" and int(unit.get("tier", 0)) == int(spec["tier"]) and String(unit.get("role", "")) == String(spec["role"]), "%s faction/tier/role changed." % String(spec["label"]))
		_expect(int(unit.get("growth", 0)) == int(spec["growth"]) and _resource_cost_contract(unit.get("cost", {})) == spec["cost"], "%s growth/cost changed." % String(spec["label"]))
		_expect(_ability_ids(unit.get("abilities", [])) == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		_expect(String(building.get("unlock_unit_id", "")) == String(spec["unit_id"]), "%s building unlock changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("growth_bonus", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_growth"]), "%s building growth changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("recruitment_discount_percent", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_discount"]), "%s building discount changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": _ability_ids(unit.get("abilities", [])), "building_id": spec["building_id"], "building_growth": spec["building_growth"], "building_discount": spec["building_discount"]})
	_report["content"] = rows

func _validate_live_clauseworks_and_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("clauseworks-counterclaim", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "Clauseworks Counterclaim must create a live session.")
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var placement := _encounter_placement(session, "clauseworks_bridge_levies")
	var authored_army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
	_expect(String(authored_army.get("id", "")) == "army_clauseworks_bridge_levies" and _stack_contract(authored_army.get("stacks", [])) == CLAUSEWORKS_STACKS, "The authored Clauseworks Bridge Levies encounter changed.")
	var authority_before: Dictionary = session.to_dict()
	var authored_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	var authored_enemy: Array = authored_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(authored_enemy) == CLAUSEWORKS_STACKS, "The public Clauseworks Bridge Levies battle roster changed.")
	_expect(_battle_target_ability_contract(authored_enemy) == {"unit_embercourt_sluicefire_lindworms": ["bloodrush"]}, "The public Clauseworks Sluicefire ability changed.")
	_expect(session.to_dict() == authority_before, "Public Clauseworks battle materialization mutated the session.")
	var fixture_placement: Dictionary = placement.duplicate(true)
	fixture_placement["placement_id"] = "embercourt_upper_ladder_art_fixture"
	fixture_placement["enemy_army"] = {"id": "army_embercourt_upper_ladder_art_fixture", "name": "Embercourt Upper Ladder Art Fixture", "faction_id": "faction_embercourt", "stacks": [{"unit_id": UNITS[0]["unit_id"], "count": 4}, {"unit_id": UNITS[1]["unit_id"], "count": 3}, {"unit_id": UNITS[2]["unit_id"], "count": 2}, {"unit_id": UNITS[3]["unit_id"], "count": 1}]}
	var fixture_payload: Dictionary = BattleRulesScript.create_battle_payload(session, fixture_placement)
	var fixture_enemy: Array = fixture_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(fixture_enemy) == fixture_placement["enemy_army"]["stacks"], "Production battle materialization changed the four-unit upper ladder fixture.")
	var fixture_ability_contract := _battle_target_ability_contract(fixture_enemy)
	_expect(fixture_ability_contract == {"unit_embercourt_ash_oath_bailiffs": ["brace"], "unit_embercourt_beacon_lectors": ["harry"], "unit_embercourt_sluicefire_lindworms": ["bloodrush"], "unit_embercourt_charter_colossus": ["brace"]}, "Production battle materialization changed normalized upper-ladder abilities: %s." % JSON.stringify(fixture_ability_contract))
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
			if entry is Dictionary and String(entry.get("side", "enemy")) != "player" and String(entry.get("unit_id", "")) == String(spec["unit_id"]):
				matches.append(entry.duplicate(true))
		_expect(matches.size() == 1, "BattleBoard must expose exactly one %s stack." % String(spec["label"]))
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_expect(bool(entry.get("loaded", false)) and String(entry.get("battle_icon", "")) == String(spec["icon_path"]), "BattleBoard did not load the exact %s icon." % String(spec["label"]))
			_expect(bool(entry.get("animation_loaded", false)) and String(entry.get("animation_sheet", "")) == String(spec["sheet_path"]), "BattleBoard did not load the exact %s sheet." % String(spec["label"]))
			entries.append(entry)
	_expect(session.to_dict() == board_authority_before, "BattleBoard art observation mutated the battle/session.")
	_report["runtime"] = {"scenario_id": "clauseworks-counterclaim", "authored_placement_id": "clauseworks_bridge_levies", "authored_stacks": _battle_stack_contract(authored_enemy), "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == board_authority_before}
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
