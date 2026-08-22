extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_THORNWAKE_UPPER_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_thornwake_upper_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_thornwake_barkmantle_rams", "label": "Barkmantle Rams", "tier": 4, "role": "melee", "growth": 3, "ability_ids": ["brace", "shielding"], "cost": {"gold": 290, "wood": 2, "ore": 1},
		"building_id": "building_thornwake_barkmantle_run", "building_growth": 4, "building_discount": 6,
		"source_path": "res://art/units/source/curated/unit_thornwake_barkmantle_rams.png", "portrait_path": "res://art/units/portraits/unit_thornwake_barkmantle_rams.png", "icon_path": "res://art/units/battle_icons/unit_thornwake_barkmantle_rams.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_thornwake_barkmantle_rams.png", "sheet_path": "res://art/animation/runtime/units/unit_thornwake_barkmantle_rams.png",
		"source_sha256": "e0f123ac134cc74a2e7d46428092f4d85fffaa31cda37b1fff11b5dc40350639", "portrait_sha256": "82372ccd15e8477b6a646ee67445df375e96161e3360cb976b90714636104977", "icon_sha256": "0fa0b3868c38e87cac3304607e0bea18431a1712c0be2ab365203a5b62f97b7c", "overworld_icon_sha256": "b2ed5772897d101a60b9e90151c9e61b2f3a362525c502c09416540ce5e1ce89", "sheet_sha256": "76c7c61e2b810d9d1dce9469d2774f996b09286e35e1f093a989843b296b91ef",
		"old_portrait_sha256": "8a24cca1262b252cf42b4681e884b2e34bc46c61c7329b97860b98a15e16b287", "old_icon_sha256": "032ebdbd74ec520190fb8d9529eb73e0e333e82ab7625623e6740df368376172", "old_overworld_icon_sha256": "254a56d715ee451373ec2e22ca03c7b5c445b336f647bde473b5666752076410", "old_sheet_sha256": "55bd9d31469ace7a7805286705ac19cfcf1eee26b0b98813056a7e0b68153d46",
	},
	{
		"unit_id": "unit_thornwake_stagknot_runners", "label": "Stag-Knot Runners", "tier": 5, "role": "melee", "growth": 2, "ability_ids": ["reach"], "cost": {"gold": 410, "wood": 2},
		"building_id": "building_thornwake_pilgrim_orchard", "building_growth": 3, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_thornwake_stagknot_runners.png", "portrait_path": "res://art/units/portraits/unit_thornwake_stagknot_runners.png", "icon_path": "res://art/units/battle_icons/unit_thornwake_stagknot_runners.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_thornwake_stagknot_runners.png", "sheet_path": "res://art/animation/runtime/units/unit_thornwake_stagknot_runners.png",
		"source_sha256": "78c5788c806a5f9f02e6518feb66a111946db0300dba218472f30a03a002585f", "portrait_sha256": "6940ede6b28292c0ce78743c26fea9a1b0b4ac04c931fedeb284629b1fc1a47d", "icon_sha256": "7dd2c644ed82e7cc9ab105c503e654cda56f4e5aa68d3fe8edd22222258a83f4", "overworld_icon_sha256": "cbdaca0ad186f7e0e50be2a6040f2b55bc234f12ebf0d9794e19d2760ba36ffe", "sheet_sha256": "c9d1ea318e6b3d35703a2efdc900d92db81e4faa8a67ced214075a7aff75ae0f",
		"old_portrait_sha256": "c13b1f8b915141a02289b1f8b973d2aae2d1afcb14cd9eae58a70ab5a3c1b3e4", "old_icon_sha256": "24d64ea0b7b3b0c044213165f9bdf1d840fa2d445e500636ba056eecb50414c4", "old_overworld_icon_sha256": "6af36c6f0ea96003a9db0c69b2a180a2c5605f39474d58e05db4699f0b70e2ad", "old_sheet_sha256": "9f6890e910c81ae6116fde1275619539c20641ab24f78491ca7579c6d419fbaa",
	},
	{
		"unit_id": "unit_thornwake_graft_matriarchs", "label": "Graft Matriarchs", "tier": 6, "role": "ranged", "growth": 1, "ability_ids": ["volley"], "cost": {"gold": 720, "wood": 3, "ore": 1},
		"building_id": "building_thornwake_graftworks", "building_growth": 2, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_thornwake_graft_matriarchs.png", "portrait_path": "res://art/units/portraits/unit_thornwake_graft_matriarchs.png", "icon_path": "res://art/units/battle_icons/unit_thornwake_graft_matriarchs.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_thornwake_graft_matriarchs.png", "sheet_path": "res://art/animation/runtime/units/unit_thornwake_graft_matriarchs.png",
		"source_sha256": "d4338c77cebd077fb261e8c3c9402d71071b8a993dbb761b1cd9971dc94e809b", "portrait_sha256": "fd7de476ca6b0ceedf9503236e948bd3c6d9f78260fe49aecbefa1bf1fd88e23", "icon_sha256": "aa467f7c151c869dfad0f4185b257623fd4c92d8a5bfcb5d48dce82592521c5c", "overworld_icon_sha256": "b3af48543a12b1d0151365428b908f713f6c67c71e005b5e0020d3466dfb7141", "sheet_sha256": "0a99d401add68609c2052997a4454829c098627dd73d034f01c1ce4b5f673b14",
		"old_portrait_sha256": "5e9c93288f2c51539c038aa3bed3bd00d54c25318ef4073732454f276b678678", "old_icon_sha256": "d4fc476800ca8122c21cd71c9822075e68f49d92ab79747205108107f8c9e715", "old_overworld_icon_sha256": "7ef4d0bebf2c6f8589e7894fee642658621ed7a1f954cc2ed8805d75e52ef4fc", "old_sheet_sha256": "6d199e38ad8972256a10b21e6df953ef38383caa72051d35ae38b77e9b2d544f",
	},
	{
		"unit_id": "unit_thornwake_worldroot_bastion", "label": "Worldroot Bastion", "tier": 7, "role": "melee", "growth": 1, "ability_ids": ["shielding"], "cost": {"gold": 1380, "wood": 4, "ore": 2},
		"building_id": "building_thornwake_worldroot_gate", "building_growth": 1, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_thornwake_worldroot_bastion.png", "portrait_path": "res://art/units/portraits/unit_thornwake_worldroot_bastion.png", "icon_path": "res://art/units/battle_icons/unit_thornwake_worldroot_bastion.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_thornwake_worldroot_bastion.png", "sheet_path": "res://art/animation/runtime/units/unit_thornwake_worldroot_bastion.png",
		"source_sha256": "c6c10c9322cb00c5131ebdafbdbb6f1d7ed99dca8a291d5ec345249bf6e0196f", "portrait_sha256": "8033080d74ae9532b47976c4742cc60d3825fe7d6d2352a63ad3e76470100d04", "icon_sha256": "ae821ee6c9aa98ce0974c946e5fa400e890f3876f3fb283251550b1b5e772d53", "overworld_icon_sha256": "04ca10984924736313fb6f59f997b5438e684f017f5ba5d1fcd9458edb1040f5", "sheet_sha256": "af361e095aa49e17b8dca2c71e763f41eb8c8d631588ea8ef14a7da265c10370",
		"old_portrait_sha256": "6853ec4efc46ad5341aed80bdeef049fda3a8bca72a7b149cd021bffbc647a77", "old_icon_sha256": "fbf498c1b3e2f72f4add596a9c9a931cabf3d96453ffbbc24115789d3b9dad21", "old_overworld_icon_sha256": "9fe204f7de68285526e02940ceb3bd4043578ad95a413cc00feec54def280059", "old_sheet_sha256": "482b1af6d5d87dd25c950a4b2e6d73b72182f1e0d813fab1bf7ba74055824974",
	},
]
const PRESERVED_EARLY_LADDER := [
	{"unit_id": "unit_thornwake_seedcutters", "portrait_sha256": "79edec73359fca75e09d08bcc07261a6fa730946607610f6559117a8a1e72d63", "icon_sha256": "97cfc788d51a4a42b4764f0c26226944dace9a69fc1c802e1e736188171e4b6e", "overworld_icon_sha256": "cd92405fe73418ff044bbfc9700ab9452db6c08adb4af0ec502e6127b1fd7ccd", "sheet_sha256": "258c27af17329b79f14a8b9fd7b57c01fab31f60d0ee6ef9bc2df92724fda64b"},
	{"unit_id": "unit_thornwake_thornwhip_carriers", "portrait_sha256": "c02715b5d765bbba66932e9c73f653cbf5da01264ab39e9ce0b467be95768564", "icon_sha256": "486ffde278196be924835c60bde4a7b832c6ba51d60cc5339dbdf1c40be1f1db", "overworld_icon_sha256": "a54f18c88058d88a90d48c83deceb879b0f1787c21dcad14796604dcc28736ba", "sheet_sha256": "1e7aa7664b7c54431620f5e408486874677f54a064b8aa571a87533cf6c6a1b3"},
	{"unit_id": "unit_thornwake_sporeglass_menders", "portrait_sha256": "0ad63314f084b8e9e3bcea2834feba41285bdf5b7ff3b5a0a6e62e6921768687", "icon_sha256": "078a1b465434e2e4f9d667113c883f44cf9344da739b719f8e88e6a931a4db6c", "overworld_icon_sha256": "8d31c3a6af9350e77b4acb2af024a8ef7fecded6282cc7382a84102c415c7298", "sheet_sha256": "53b16f5beb08abea0a5536e67b06085122425d84da28f6ec097595f8355d90b7"},
]
const PRESERVED_SURFACE_DIRS := {"portrait": "units/portraits", "icon": "units/battle_icons", "overworld_icon": "units/overworld_icons", "sheet": "animation/runtime/units"}
const HALO_BARKMANTLE_STACKS := [{"unit_id": "unit_thornwake_seedcutters", "count": 9}, {"unit_id": "unit_thornwake_sporeglass_menders", "count": 7}, {"unit_id": "unit_thornwake_barkmantle_rams", "count": 4}]
const ROOTBOUND_WARDEN_STACKS := [{"unit_id": "unit_thornwake_seedcutters", "count": 12}, {"unit_id": "unit_thornwake_thornwhip_carriers", "count": 8}, {"unit_id": "unit_thornwake_sporeglass_menders", "count": 4}, {"unit_id": "unit_thornwake_barkmantle_rams", "count": 3}]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "content": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	_validate_content_authority()
	await _validate_live_thornwake_and_board()
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
			_expect(FileAccess.get_sha256(path) == String(preserved["%s_sha256" % key]), "The curated Thornwake early-ladder %s %s changed." % [unit_id, key])
	_report["assets"] = rows

func _validate_content_authority() -> void:
	var faction: Dictionary = ContentService.get_faction("faction_thornwake")
	var ladder := _string_array(faction.get("unit_ladder_ids", []))
	var buildings := _string_array(faction.get("signature_building_ids", []))
	_expect(ladder.slice(3, 7) == _target_ids(), "Thornwake upper-ladder faction order changed.")
	_expect(buildings.slice(3, 7) == _building_ids(), "Thornwake upper-ladder building order changed.")
	_expect(String(faction.get("seed_town_id", "")) == "town_thornwake_graftroot_caravan", "Thornwake seed town changed.")
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var unit: Dictionary = ContentService.get_unit(String(spec["unit_id"]))
		var building: Dictionary = ContentService.get_building(String(spec["building_id"]))
		_expect(String(unit.get("name", "")) == String(spec["label"]), "%s name changed." % String(spec["label"]))
		_expect(String(unit.get("faction_id", "")) == "faction_thornwake" and int(unit.get("tier", 0)) == int(spec["tier"]) and String(unit.get("role", "")) == String(spec["role"]), "%s faction/tier/role changed." % String(spec["label"]))
		_expect(int(unit.get("growth", 0)) == int(spec["growth"]) and _resource_cost_contract(unit.get("cost", {})) == spec["cost"], "%s growth/cost changed." % String(spec["label"]))
		_expect(_ability_ids(unit.get("abilities", [])) == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		_expect(String(building.get("unlock_unit_id", "")) == String(spec["unit_id"]), "%s building unlock changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("growth_bonus", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_growth"]), "%s building growth changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("recruitment_discount_percent", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_discount"]), "%s building discount changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": _ability_ids(unit.get("abilities", [])), "building_id": spec["building_id"], "building_growth": spec["building_growth"], "building_discount": spec["building_discount"]})
	_report["content"] = rows

func _validate_live_thornwake_and_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("halo-reserve-refraction-claim", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "Halo Reserve Refraction Claim must create a live session.")
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var placement := _encounter_placement(session, "halo_barkmantle_bastion")
	var authored_army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
	_expect(String(authored_army.get("id", "")) == "army_halo_barkmantle_bastion" and _stack_contract(authored_army.get("stacks", [])) == HALO_BARKMANTLE_STACKS, "The authored Halo Barkmantle Bastion encounter changed.")
	var authority_before: Dictionary = session.to_dict()
	var authored_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	var authored_enemy: Array = authored_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(authored_enemy) == HALO_BARKMANTLE_STACKS, "The public Halo Barkmantle Bastion battle roster changed.")
	_expect(_battle_target_ability_contract(authored_enemy) == {"unit_thornwake_barkmantle_rams": ["brace", "shielding"]}, "The public Halo Barkmantle ability changed.")
	_expect(session.to_dict() == authority_before, "Public Halo battle materialization mutated the session.")
	var mireford_session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("mireford-skirmish", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(mireford_session != null, "Rootbound Mireford must create a live session.")
	var rootbound_player_stacks: Array = []
	if mireford_session != null:
		var rootbound_player_army: Dictionary = mireford_session.overworld.get("army", {}) if mireford_session.overworld.get("army", {}) is Dictionary else {}
		rootbound_player_stacks = _stack_contract(rootbound_player_army.get("stacks", []))
		_expect(String(rootbound_player_army.get("id", "")) == "army_rootbound_mireford_wardens" and rootbound_player_stacks == ROOTBOUND_WARDEN_STACKS, "The authored Rootbound Mireford Wardens player army changed.")
	var fixture_placement: Dictionary = placement.duplicate(true)
	fixture_placement["placement_id"] = "thornwake_upper_ladder_art_fixture"
	fixture_placement["enemy_army"] = {"id": "army_thornwake_upper_ladder_art_fixture", "name": "Thornwake Upper Ladder Art Fixture", "faction_id": "faction_thornwake", "stacks": [{"unit_id": UNITS[0]["unit_id"], "count": 4}, {"unit_id": UNITS[1]["unit_id"], "count": 3}, {"unit_id": UNITS[2]["unit_id"], "count": 2}, {"unit_id": UNITS[3]["unit_id"], "count": 1}]}
	var fixture_payload: Dictionary = BattleRulesScript.create_battle_payload(session, fixture_placement)
	var fixture_enemy: Array = fixture_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(fixture_enemy) == fixture_placement["enemy_army"]["stacks"], "Production battle materialization changed the four-unit upper ladder fixture.")
	var fixture_ability_contract := _battle_target_ability_contract(fixture_enemy)
	_expect(fixture_ability_contract == {"unit_thornwake_barkmantle_rams": ["brace", "shielding"], "unit_thornwake_stagknot_runners": ["reach"], "unit_thornwake_graft_matriarchs": ["volley"], "unit_thornwake_worldroot_bastion": ["shielding"]}, "Production battle materialization changed normalized Thornwake upper-ladder abilities: %s." % JSON.stringify(fixture_ability_contract))
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
	_expect(entries.size() == UNITS.size(), "BattleBoard must expose all four Thornwake upper-ladder stacks.")
	_report["runtime"] = {"scenario_id": "halo-reserve-refraction-claim", "authored_placement_id": "halo_barkmantle_bastion", "authored_stacks": _battle_stack_contract(authored_enemy), "rootbound_player_stacks": rootbound_player_stacks, "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == board_authority_before}
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
