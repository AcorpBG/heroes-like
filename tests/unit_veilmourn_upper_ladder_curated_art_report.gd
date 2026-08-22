extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_VEILMOURN_UPPER_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_veilmourn_upper_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_veilmourn_undertow_harpooners", "label": "Undertow Harpooners", "tier": 4, "role": "ranged", "growth": 3, "ability_ids": ["harry"], "cost": {"gold": 245, "wood": 1, "ore": 1},
		"building_id": "building_veilmourn_harpoon_gantry", "building_growth": 4, "building_discount": 6,
		"source_path": "res://art/units/source/curated/unit_veilmourn_undertow_harpooners.png", "portrait_path": "res://art/units/portraits/unit_veilmourn_undertow_harpooners.png", "icon_path": "res://art/units/battle_icons/unit_veilmourn_undertow_harpooners.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_veilmourn_undertow_harpooners.png", "sheet_path": "res://art/animation/runtime/units/unit_veilmourn_undertow_harpooners.png",
		"source_sha256": "67fe206ecf232bd288ce8823db020298774727f0f769e2b7b431e0ece237b76d", "portrait_sha256": "c2b6a340e7de84af1e6c0c619b427e84bdec110008b411489e49fc8380c58f1e", "icon_sha256": "3e50b3166574412c3db1253a03cdf6e6419391c9cb992628c9ef515641c68aca", "overworld_icon_sha256": "f09ff26f290a28a817d96217e38190964a5bf65ede644f2006318b1c357a2b2c", "sheet_sha256": "38c5ecb2ae799ae8f5a98766e6cabde4b654fdedcd329bee0a740f1550fcc786",
		"old_portrait_sha256": "c448ecaf760e93d8dec45c6fc40ee8e166dc758deab4f5c00f3cf54fd715b04a", "old_icon_sha256": "3cfd8acecc893daeb67b05f5e76d814278f82aeb27c11b57928f645606b904cf", "old_overworld_icon_sha256": "a355166595570f32a92222d8821bc90cf74ddb9eb82f12890120217979bbfd0b", "old_sheet_sha256": "c4f0669c35ae4f10cd3b46bc17163587699164ef916e225e9cab1c4191ffb4d8",
	},
	{
		"unit_id": "unit_veilmourn_obituary_scribes", "label": "Obituary Scribes", "tier": 5, "role": "ranged", "growth": 2, "ability_ids": ["obituary"], "cost": {"gold": 340, "wood": 1},
		"building_id": "building_veilmourn_obituary_vault", "building_growth": 3, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_veilmourn_obituary_scribes.png", "portrait_path": "res://art/units/portraits/unit_veilmourn_obituary_scribes.png", "icon_path": "res://art/units/battle_icons/unit_veilmourn_obituary_scribes.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_veilmourn_obituary_scribes.png", "sheet_path": "res://art/animation/runtime/units/unit_veilmourn_obituary_scribes.png",
		"source_sha256": "880a6eee35be1d612622ba1d427999bdf1dcea38d2290f2661820ac31136c5c6", "portrait_sha256": "b1aa07fce08de9b3df4415da466d0a077e84489d83b41da1df055245b2d5d23e", "icon_sha256": "a058835f2751adbc0cfb7369e3da1b3ff5929a54973d50abce0a265a01a28743", "overworld_icon_sha256": "f473a70fb33fd4ff2994c72c590dfda1060f66fbe804d9e7a9b29279557fe77b", "sheet_sha256": "b7e06979126561db714df706dee716d5e0cdb353f377de4426fdee0327d4661c",
		"old_portrait_sha256": "c1203c9f71cd65b70ffa94bbc7d4139847bd3f796b4913e914a5db41552de54e", "old_icon_sha256": "92679249f3a279cea72e90a0be3f21f3ef79423432580e017610be1c681aa6ed", "old_overworld_icon_sha256": "dda5a3fd7e2b93f8cf946174fc24664af30425c5ec2cfc873795655861044e29", "old_sheet_sha256": "04a46eb2b18b577f8b69a165f8ccaced4fb1d9fe20a8288bc690b72ab5595f9e",
	},
	{
		"unit_id": "unit_veilmourn_mirrorkeel_reavers", "label": "Mirror-Keel Reavers", "tier": 6, "role": "melee", "growth": 1, "ability_ids": ["reach", "backstab"], "cost": {"gold": 680, "wood": 2, "ore": 1},
		"building_id": "building_veilmourn_mistgate_slip", "building_growth": 2, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_veilmourn_mirrorkeel_reavers.png", "portrait_path": "res://art/units/portraits/unit_veilmourn_mirrorkeel_reavers.png", "icon_path": "res://art/units/battle_icons/unit_veilmourn_mirrorkeel_reavers.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_veilmourn_mirrorkeel_reavers.png", "sheet_path": "res://art/animation/runtime/units/unit_veilmourn_mirrorkeel_reavers.png",
		"source_sha256": "b67a8149e9b36add5c87c20297e1e8cd441af264b78ce2656c66dab81e22df94", "portrait_sha256": "6f7a402828bdd6420cda0c2552e9aebae747809d1fb71c8f5b9f9dd292ed5bfe", "icon_sha256": "9309963c00a64abfa6a13624b1fb9ae24c4b5ccc8b9ffd40f2399f5d8007cef6", "overworld_icon_sha256": "3bd1b80bed86b5617da1bdc0188be30dfc42f217d1c914ace3f519a9f4a286ef", "sheet_sha256": "ddcb90bba1591964b018d279e529ca2c1e671ba1d3a8ea7ca6e0bb90de56bd69",
		"old_portrait_sha256": "b95f38722b54cec52eadeece4852806ab55382f54bcf95516b9a1d4eccd30188", "old_icon_sha256": "1ce5e2f055e38b47375f212b6d70f75d8e0abb781037d1ca4784b24887163cdf", "old_overworld_icon_sha256": "625154ee5ce54d4e9e62f3add70b5e9496516196c85c20436f18dd2b3968c99e", "old_sheet_sha256": "25b63ccad8caa2cd14e0d3c9e564ea7c69d865401816348269194307b030568a",
	},
	{
		"unit_id": "unit_veilmourn_fogbound_leviathan", "label": "Fogbound Leviathan", "tier": 7, "role": "melee", "growth": 1, "ability_ids": ["fogwake"], "cost": {"gold": 1420, "wood": 2, "ore": 3},
		"building_id": "building_veilmourn_leviathan_sounding", "building_growth": 1, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_veilmourn_fogbound_leviathan.png", "portrait_path": "res://art/units/portraits/unit_veilmourn_fogbound_leviathan.png", "icon_path": "res://art/units/battle_icons/unit_veilmourn_fogbound_leviathan.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_veilmourn_fogbound_leviathan.png", "sheet_path": "res://art/animation/runtime/units/unit_veilmourn_fogbound_leviathan.png",
		"source_sha256": "b30e43ca1d825ceedc1dbc407cfc02e217dcaa6ae80abe2e3a16bafce77bf8dd", "portrait_sha256": "03ba814ff3bc486de0185fffabb2cee3fcb0704b44eb306f8ba869fdc7415972", "icon_sha256": "9101bf76c44dd12fe1d253e9e60fad64c72ed13d6c14b6b257d22e1396dbb40e", "overworld_icon_sha256": "3aadc12b4c09c62732a872666b5ff28e5f04dfc38cf14f95f66735325f8e6e29", "sheet_sha256": "4642e3225a8b12b6f66822bc55191db276fba7b4fb308c20d6cf4caabe365c69",
		"old_portrait_sha256": "d67716eaec270b135bebaf832e766559df2b0cc1c5bc24b3618051c90f04f8f1", "old_icon_sha256": "f771ca1e18e6f60ff12d787b2f2cba1fbec387064454e7eebc36557d7bcb1e21", "old_overworld_icon_sha256": "afb41bf1b65f7a55b9df9a44240f6e79a27d350423c11af5ccf1a00312acfaf7", "old_sheet_sha256": "23e327c00701acb51303069c5cc34a282fe9eb32c865abb6ba3eb3aa6b9c75d6",
	},
]
const PRESERVED_EARLY_LADDER := [
	{"unit_id": "unit_veilmourn_bellwake_oars", "portrait_sha256": "c855f95ac00ebc680d28e8c2e4dd8e199060c4fcc2987256564036d54c5f129b", "icon_sha256": "013d7280ab34716646a6d365ad67c9585529c3a2de99a5ecbbd91f0d70419157", "overworld_icon_sha256": "0926921c4ef8ebef3c0a21f60bc2d8afed6f333edaec3f35954b0efdd3b960f1", "sheet_sha256": "1fd65e107918d9e9249857d2f8b471c7e2c552eb7a9c6ee75f99a80abb1dbf7d"},
	{"unit_id": "unit_veilmourn_mourning_lanterns", "portrait_sha256": "bdcfe4c84caee23878f6df6dde922faad92f3c686139a6db7a742c7b6157c112", "icon_sha256": "1a9089f79c9ce3b85cebdd7ae8e9b42e130be7371fe3b4e82ee0d3a3b506db1a", "overworld_icon_sha256": "6d5effedec75121052ab4f0a9a0b162b11e93d1b68895533267292a8a7073067", "sheet_sha256": "b5873d3a40292bf5b2073ca7a3ab200241d95243f1c4cb7e890498e841e61a3d"},
	{"unit_id": "unit_veilmourn_maskglass_corsairs", "portrait_sha256": "069d65156a3db29f03047e3df7299fa6a587ff109e5666a79bdd1ec58349e757", "icon_sha256": "5c4648967854064a465f33e7ccbb8baf7c6ab41b73ea36aa5746b648a51ace1b", "overworld_icon_sha256": "555cbbe5cb52ef6794ba1ed893e3c8966501ef83c064eddb1d6ed7350fee9b61", "sheet_sha256": "ab79dcc966cb0c502806075b476ddfee752c56dfa067be27514351aa9fc6d907"},
]
const PRESERVED_SURFACE_DIRS := {"portrait": "units/portraits", "icon": "units/battle_icons", "overworld_icon": "units/overworld_icons", "sheet": "animation/runtime/units"}
const BELLWAKE_PLAYER_STACKS := [{"unit_id": "unit_veilmourn_bellwake_oars", "count": 14}, {"unit_id": "unit_veilmourn_mourning_lanterns", "count": 8}, {"unit_id": "unit_veilmourn_maskglass_corsairs", "count": 5}, {"unit_id": "unit_veilmourn_undertow_harpooners", "count": 2}]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "content": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	_validate_content_authority()
	await _validate_live_veilmourn_and_board()
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
			_expect(FileAccess.get_sha256(path) == String(preserved["%s_sha256" % key]), "The curated Veilmourn early-ladder %s %s changed." % [unit_id, key])
	_report["assets"] = rows

func _validate_content_authority() -> void:
	var faction: Dictionary = ContentService.get_faction("faction_veilmourn")
	var ladder := _string_array(faction.get("unit_ladder_ids", []))
	var buildings := _string_array(faction.get("signature_building_ids", []))
	_expect(ladder.slice(3, 7) == _target_ids(), "Veilmourn upper-ladder faction order changed.")
	_expect(buildings.slice(3, 7) == _building_ids(), "Veilmourn upper-ladder building order changed.")
	_expect(String(faction.get("seed_town_id", "")) == "town_veilmourn_bellwake_harbor", "Veilmourn seed town changed.")
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var unit: Dictionary = ContentService.get_unit(String(spec["unit_id"]))
		var building: Dictionary = ContentService.get_building(String(spec["building_id"]))
		_expect(String(unit.get("name", "")) == String(spec["label"]), "%s name changed." % String(spec["label"]))
		_expect(String(unit.get("faction_id", "")) == "faction_veilmourn" and int(unit.get("tier", 0)) == int(spec["tier"]) and String(unit.get("role", "")) == String(spec["role"]), "%s faction/tier/role changed." % String(spec["label"]))
		_expect(int(unit.get("growth", 0)) == int(spec["growth"]) and _resource_cost_contract(unit.get("cost", {})) == spec["cost"], "%s growth/cost changed." % String(spec["label"]))
		_expect(_ability_ids(unit.get("abilities", [])) == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		_expect(String(building.get("unlock_unit_id", "")) == String(spec["unit_id"]), "%s building unlock changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("growth_bonus", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_growth"]), "%s building growth changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("recruitment_discount_percent", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_discount"]), "%s building discount changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": _ability_ids(unit.get("abilities", [])), "building_id": spec["building_id"], "building_growth": spec["building_growth"], "building_discount": spec["building_discount"]})
	_report["content"] = rows

func _validate_live_veilmourn_and_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("bellwake-wreck-claim", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "Bellwake Wreck Claim must create a live session.")
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var player_army: Dictionary = session.overworld.get("army", {}) if session.overworld.get("army", {}) is Dictionary else {}
	var player_stacks: Array = _stack_contract(player_army.get("stacks", []))
	_expect(String(player_army.get("id", "")) == "army_bellwake_wreck_claimants", "The live Bellwake player army id changed.")
	_expect(player_stacks == BELLWAKE_PLAYER_STACKS, "The live Bellwake player army stacks changed.")
	var placement := _encounter_placement(session, "bellwake_relay_pickets")
	_expect(not placement.is_empty(), "Bellwake Relay Pickets must remain a live encounter fixture.")
	if placement.is_empty():
		return
	var authority_before: Dictionary = session.to_dict()
	var fixture_placement: Dictionary = placement.duplicate(true)
	fixture_placement["placement_id"] = "veilmourn_upper_ladder_art_fixture"
	fixture_placement["enemy_army"] = {"id": "army_veilmourn_upper_ladder_art_fixture", "name": "Veilmourn Upper Ladder Art Fixture", "faction_id": "faction_veilmourn", "stacks": [{"unit_id": UNITS[0]["unit_id"], "count": 4}, {"unit_id": UNITS[1]["unit_id"], "count": 3}, {"unit_id": UNITS[2]["unit_id"], "count": 2}, {"unit_id": UNITS[3]["unit_id"], "count": 1}]}
	var fixture_payload: Dictionary = BattleRulesScript.create_battle_payload(session, fixture_placement)
	var fixture_enemy: Array = fixture_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(fixture_enemy) == fixture_placement["enemy_army"]["stacks"], "Production battle materialization changed the four-unit upper ladder fixture.")
	var fixture_ability_contract := _battle_target_ability_contract(fixture_enemy)
	_expect(fixture_ability_contract == {"unit_veilmourn_undertow_harpooners": ["harry"], "unit_veilmourn_obituary_scribes": ["obituary"], "unit_veilmourn_mirrorkeel_reavers": ["reach", "backstab"], "unit_veilmourn_fogbound_leviathan": ["fogwake"]}, "Production battle materialization changed normalized Veilmourn upper-ladder abilities: %s." % JSON.stringify(fixture_ability_contract))
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
	_expect(entries.size() == UNITS.size(), "BattleBoard must expose all four Veilmourn upper-ladder stacks.")
	_report["runtime"] = {"scenario_id": "bellwake-wreck-claim", "player_army_id": String(player_army.get("id", "")), "player_stacks": player_stacks, "fixture_placement_id": "veilmourn_upper_ladder_art_fixture", "fixture_stacks": _battle_stack_contract(fixture_enemy), "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == board_authority_before}
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
