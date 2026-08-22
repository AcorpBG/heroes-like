extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_MIRECLAW_UPPER_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_mireclaw_upper_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_mireclaw_ferrychain_lashers", "label": "Ferrychain Lashers", "tier": 4, "role": "melee", "growth": 3, "ability_ids": ["hookline"], "cost": {"gold": 230, "wood": 1, "ore": 1},
		"building_id": "building_mireclaw_chainboom_ferry", "building_growth": 4, "building_discount": 6,
		"source_path": "res://art/units/source/curated/unit_mireclaw_ferrychain_lashers.png", "portrait_path": "res://art/units/portraits/unit_mireclaw_ferrychain_lashers.png", "icon_path": "res://art/units/battle_icons/unit_mireclaw_ferrychain_lashers.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_mireclaw_ferrychain_lashers.png", "sheet_path": "res://art/animation/runtime/units/unit_mireclaw_ferrychain_lashers.png",
		"source_sha256": "1bb4d8c1b469ecd69be9517017f1afc5fadeb2dc4a0a6cf8494c7bd8d51b791b", "portrait_sha256": "c80dbed1ddab446248272df97fa813b43ee1073c0dee5843ad6a5d6519859343", "icon_sha256": "1819caad399b3c90361b64e780b386d3e1d84acce88b977ac156fce134f31c82", "overworld_icon_sha256": "17040da6bbefb286efedf5ca722b1f16581030026912f16b3244d7f0524c83a8", "sheet_sha256": "55089cb996e30b1b4427f78900fa467dae54205723d1810aac2e3ee7bfe3f61a",
		"old_portrait_sha256": "9ec29c665d1f2fcd8c6dcd708311cea1be3869977bbbd33c2dd0ef430ac15ab3", "old_icon_sha256": "0a8cdb6aac1f42458070f70970748d6ae01bce4f8061df0fab1693eb36a1c8d9", "old_overworld_icon_sha256": "9b3cd4e37dadfc66f6e93d2873e2d9dad449b6815cdd93180200e356b160336d", "old_sheet_sha256": "168df583320c19cedf903d050e80e044b09591dd30732c59ab94dca264e907b6",
	},
	{
		"unit_id": "unit_mireclaw_sporewake_chanters", "label": "Sporewake Chanters", "tier": 5, "role": "ranged", "growth": 2, "ability_ids": ["rot_cant"], "cost": {"gold": 330, "wood": 1},
		"building_id": "building_mireclaw_sporewake_shrine", "building_growth": 3, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_mireclaw_sporewake_chanters.png", "portrait_path": "res://art/units/portraits/unit_mireclaw_sporewake_chanters.png", "icon_path": "res://art/units/battle_icons/unit_mireclaw_sporewake_chanters.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_mireclaw_sporewake_chanters.png", "sheet_path": "res://art/animation/runtime/units/unit_mireclaw_sporewake_chanters.png",
		"source_sha256": "7ffe7aa6b4aee625433eecc930a7761f3346a1e657f006f4e1b073c8d268a55f", "portrait_sha256": "240be6e73beafeaaae55186aea2b9c066332a5d4f3e541955d37ece5f06089c5", "icon_sha256": "61e63dab8da54021821aaa21611736fc6272e5946dcc0d9c5aba3c427c59d789", "overworld_icon_sha256": "9e56db29e11cf29f5c9b1250d517bd417d13778dff0ac7b452b7b012e738de28", "sheet_sha256": "64c8efa87dd62823775b9b865f92e303f4981d5535004cdf41dc72da1cfe6396",
		"old_portrait_sha256": "f062255d9fb02a3576fcaa5082fad9351a6bf6179bb95ff83ae48bc26619c765", "old_icon_sha256": "f008c669bd85aa57d2f52f6b0c4772c1516fc9020f4bded4b4e6e8a28b2bf202", "old_overworld_icon_sha256": "78b83a47bfc1f4f52e99058250068ffc9426f39e6bd4ddd217a86febe19a7cad", "old_sheet_sha256": "76e83c4e1040d58c577e18aa3253556e780c93ea4b833453f30e0eb294dcbefe",
	},
	{
		"unit_id": "unit_mireclaw_gorefen_rippers", "label": "Gorefen Rippers", "tier": 6, "role": "melee", "growth": 1, "ability_ids": ["bloodrush"], "cost": {"gold": 660, "ore": 1},
		"building_id": "building_mireclaw_nightglass_dominion", "building_growth": 2, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_mireclaw_gorefen_rippers.png", "portrait_path": "res://art/units/portraits/unit_mireclaw_gorefen_rippers.png", "icon_path": "res://art/units/battle_icons/unit_mireclaw_gorefen_rippers.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_mireclaw_gorefen_rippers.png", "sheet_path": "res://art/animation/runtime/units/unit_mireclaw_gorefen_rippers.png",
		"source_sha256": "427ae1f80f021e3583e4607a0fc77e4b8e1a66497224139ee404c26ae03cb54c", "portrait_sha256": "3727f6174e0cdee0cc3be490cd17bda876f83e592a9d968e36a9df39a5adc8f0", "icon_sha256": "592fb26bbd45a21767e404623f4b6602b0efbaf4d10b8324265913107f0b7ae8", "overworld_icon_sha256": "9fdb5a6eaeac41d71ecc9c797ca925657dac623376c875a4725504d3cd9e1273", "sheet_sha256": "0d39a3ac450de7f0a9005e359068484214ead6e16947768eaeac4a833c9790e1",
		"old_portrait_sha256": "13efda6ff67e346b2b7c6504c32a16738b5723af1a022f0279c38374b3d9198d", "old_icon_sha256": "86017220c10f087ea99d74be9300bd2063df475190ffcdbde0de7dba927e3f3d", "old_overworld_icon_sha256": "8bafe3428de52ac18c0a1ad53410249c92aeffdb85c35f5fac9aafd435921adf", "old_sheet_sha256": "45fe916168ed08b121a185c91e0c388952a0cf52c55c67da4d63972884214955",
	},
	{
		"unit_id": "unit_mireclaw_drowned_antler_sovereign", "label": "Drowned Antler Sovereign", "tier": 7, "role": "melee", "growth": 1, "ability_ids": ["bloodrush"], "cost": {"gold": 1320, "wood": 2, "ore": 2},
		"building_id": "building_mireclaw_antler_pit", "building_growth": 1, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_mireclaw_drowned_antler_sovereign.png", "portrait_path": "res://art/units/portraits/unit_mireclaw_drowned_antler_sovereign.png", "icon_path": "res://art/units/battle_icons/unit_mireclaw_drowned_antler_sovereign.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_mireclaw_drowned_antler_sovereign.png", "sheet_path": "res://art/animation/runtime/units/unit_mireclaw_drowned_antler_sovereign.png",
		"source_sha256": "0e0fbb099326b16e32b3b79945e5af5f34a69819e7a1fe1c4156649e1ded97a2", "portrait_sha256": "08ea9785b0d661e19ba41b0dcedfaedc881113b1f7843947836a1585e17be89b", "icon_sha256": "0cc87654eec2695aea82792b6714027c1abed973e29f2e9db9b1ceb01216a862", "overworld_icon_sha256": "c557d8fe48292da020116ad783dc5897ab50045332134749699ca9bf6febfda7", "sheet_sha256": "333646ac8023e33f473f1bf1633006a5f37f83b61bab0fe8d73a932f62f8c76c",
		"old_portrait_sha256": "9d22f8a728c9ddd812d001f231fce292fdc3a88647e1beaceeaf1cb173712768", "old_icon_sha256": "e7296d13131ee2457b1ab6e81b9cd8bbb01992cadcdf4e56e5237870b8848a1d", "old_overworld_icon_sha256": "e4eab1946444f3d3f2a09c84d8f2dc93cced74e6b12431e761115e39bfc8b649", "old_sheet_sha256": "14b2bd9d3f3dacd44894fedfcdc2da1ee4c102fb9c27e6da99d18cfaae87313a",
	},
]
const PRESERVED_TIER3 := {
	"unit_id": "unit_gorefen_ripper",
	"portrait_path": "res://art/units/portraits/unit_gorefen_ripper.png", "portrait_sha256": "079071cd197c307a26e3cd23816a34e5c428aad6540c4d647947c57d39933d4c",
	"icon_path": "res://art/units/battle_icons/unit_gorefen_ripper.png", "icon_sha256": "cb46422658713dca7bf1fd507268c98b1b97d2ab01839f4f159fafb2ff6b1828",
	"overworld_icon_path": "res://art/units/overworld_icons/unit_gorefen_ripper.png", "overworld_icon_sha256": "c527f5ddb16804cff7d4d9e398d6206261252a5ff026b6b8b19a4408d633a499",
	"sheet_path": "res://art/animation/runtime/units/unit_gorefen_ripper.png", "sheet_sha256": "d6795b67f7cd5e00ce4c7b6121cfa48521fb5099aa43674ddaa596b0528c5095",
}
const MIREFORD_STACKS := [{"unit_id": "unit_blackbranch_cutthroat", "count": 15}, {"unit_id": "unit_mire_slinger", "count": 11}, {"unit_id": "unit_mireclaw_gorefen_rippers", "count": 2}]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "content": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	_validate_content_authority()
	await _validate_live_mireford_and_board()
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
	for key in ["portrait", "icon", "overworld_icon", "sheet"]:
		_expect(FileAccess.get_sha256(String(PRESERVED_TIER3["%s_path" % key])) == String(PRESERVED_TIER3["%s_sha256" % key]), "The curated tier-3 Gorefen Ripper %s changed." % key)
	_report["assets"] = rows

func _validate_content_authority() -> void:
	var faction: Dictionary = ContentService.get_faction("faction_mireclaw")
	var ladder := _string_array(faction.get("unit_ladder_ids", []))
	var buildings := _string_array(faction.get("signature_building_ids", []))
	_expect(ladder.slice(3, 7) == _target_ids(), "Mireclaw upper-ladder faction order changed.")
	_expect(buildings.slice(3, 7) == _building_ids(), "Mireclaw upper-ladder building order changed.")
	_expect(String(faction.get("seed_town_id", "")) == "town_nightglass_redoubt", "Mireclaw seed town changed.")
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var unit: Dictionary = ContentService.get_unit(String(spec["unit_id"]))
		var building: Dictionary = ContentService.get_building(String(spec["building_id"]))
		_expect(String(unit.get("name", "")) == String(spec["label"]), "%s name changed." % String(spec["label"]))
		_expect(String(unit.get("faction_id", "")) == "faction_mireclaw" and int(unit.get("tier", 0)) == int(spec["tier"]) and String(unit.get("role", "")) == String(spec["role"]), "%s faction/tier/role changed." % String(spec["label"]))
		_expect(int(unit.get("growth", 0)) == int(spec["growth"]) and _resource_cost_contract(unit.get("cost", {})) == spec["cost"], "%s growth/cost changed." % String(spec["label"]))
		_expect(_ability_ids(unit.get("abilities", [])) == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		_expect(String(building.get("unlock_unit_id", "")) == String(spec["unit_id"]), "%s building unlock changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("growth_bonus", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_growth"]), "%s building growth changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("recruitment_discount_percent", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_discount"]), "%s building discount changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": _ability_ids(unit.get("abilities", [])), "building_id": spec["building_id"], "building_growth": spec["building_growth"], "building_discount": spec["building_discount"]})
	_report["content"] = rows

func _validate_live_mireford_and_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("mireford-skirmish", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "Mireford must create a live session.")
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var placement := _encounter_placement(session, "bridge_ford_reavers")
	var authored_army: Dictionary = placement.get("enemy_army", {}) if placement.get("enemy_army", {}) is Dictionary else {}
	_expect(String(authored_army.get("id", "")) == "army_mireford_ford_reavers_watch" and _stack_contract(authored_army.get("stacks", [])) == MIREFORD_STACKS, "The authored Mireford Gorefen encounter changed.")
	var authority_before: Dictionary = session.to_dict()
	var authored_payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	var authored_enemy: Array = authored_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(authored_enemy) == MIREFORD_STACKS, "The public Mireford Gorefen battle roster changed.")
	_expect(_battle_target_ability_contract(authored_enemy) == {"unit_mireclaw_gorefen_rippers": ["bloodrush"]}, "The public Mireford Gorefen ability changed.")
	_expect(session.to_dict() == authority_before, "Public Mireford battle materialization mutated the session.")
	var fixture_placement: Dictionary = placement.duplicate(true)
	fixture_placement["placement_id"] = "mireclaw_upper_ladder_art_fixture"
	fixture_placement["enemy_army"] = {"id": "army_mireclaw_upper_ladder_art_fixture", "name": "Mireclaw Upper Ladder Art Fixture", "faction_id": "faction_mireclaw", "stacks": [{"unit_id": UNITS[0]["unit_id"], "count": 4}, {"unit_id": UNITS[1]["unit_id"], "count": 3}, {"unit_id": UNITS[2]["unit_id"], "count": 2}, {"unit_id": UNITS[3]["unit_id"], "count": 1}]}
	var fixture_payload: Dictionary = BattleRulesScript.create_battle_payload(session, fixture_placement)
	var fixture_enemy: Array = fixture_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(fixture_enemy) == fixture_placement["enemy_army"]["stacks"], "Production battle materialization changed the four-unit upper ladder fixture.")
	_expect(_battle_target_ability_contract(fixture_enemy) == {"unit_mireclaw_ferrychain_lashers": ["hookline"], "unit_mireclaw_sporewake_chanters": ["rot_cant"], "unit_mireclaw_gorefen_rippers": ["bloodrush"], "unit_mireclaw_drowned_antler_sovereign": ["bloodrush"]}, "Production battle materialization changed upper-ladder abilities.")
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
	_report["runtime"] = {"scenario_id": "mireford-skirmish", "authored_placement_id": "bridge_ford_reavers", "authored_stacks": _battle_stack_contract(authored_enemy), "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == board_authority_before}
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
