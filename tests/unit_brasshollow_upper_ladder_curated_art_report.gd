extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "UNIT_BRASSHOLLOW_UPPER_LADDER_CURATED_ART_REPORT"
const OUTPUT_DIR := "res://.artifacts/unit_brasshollow_upper_ladder_curated_art_report"
const FRAME_SIZE := Vector2i(64, 64)
const FRAMES_PER_STATE := 4
const STATES := ["idle_hold", "ready_active", "move_path_step", "melee_windup_release", "ranged_aim_release", "hit_stagger", "death_rout_remove", "cast_support_anchor", "status_applied", "status_expired", "defend_brace", "retaliation_release", "retreat_withdraw_column", "surrender_stand_down"]
const UNITS := [
	{
		"unit_id": "unit_brasshollow_boiler_rivetcasters", "label": "Boiler Rivetcasters", "tier": 4, "role": "ranged", "growth": 3, "ability_ids": ["pressure_artillery"], "cost": {"gold": 270, "ore": 2},
		"building_id": "building_brasshollow_boiler_cathedral", "building_growth": 4, "building_discount": 6,
		"source_path": "res://art/units/source/curated/unit_brasshollow_boiler_rivetcasters.png", "portrait_path": "res://art/units/portraits/unit_brasshollow_boiler_rivetcasters.png", "icon_path": "res://art/units/battle_icons/unit_brasshollow_boiler_rivetcasters.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_brasshollow_boiler_rivetcasters.png", "sheet_path": "res://art/animation/runtime/units/unit_brasshollow_boiler_rivetcasters.png",
		"source_sha256": "27df82ca15c6a231a065a421f5663590a74b5cd9ec0654d62b715f57881f3292", "portrait_sha256": "ab8acae9680e8d7543029a435a20ba1358dd3fa3e5009a1be677b72235390045", "icon_sha256": "b97f533ed48f82165872bd39fef8731904d509278e98928d38a309d2ee798b0e", "overworld_icon_sha256": "a8f4c612004e61b99d008dd23c032ce8f2b49a156ab57707b7e22af651aad93d", "sheet_sha256": "763d8cee08f5458db9ad885fbddde1b7f6e08ec442c33e38cce49bab659fe46e",
		"old_portrait_sha256": "9f60c74039f653de522ef412f56900b138f414cbaa8a466ea5d274f41d3300fe", "old_icon_sha256": "2f7c94409beb8a5c265bab9050f9201432a81d814e552dab15ac3d5195443611", "old_overworld_icon_sha256": "29f7ac837c78ba7c3197f36ced5274913d030e556806f450fc93d3c7545123d5", "old_sheet_sha256": "485001c8616ba09677b8b6b76488036cc0a3a4e9fcfdd44adc69faa8532383e0",
	},
	{
		"unit_id": "unit_brasshollow_debt_engine_exactors", "label": "Debt-Engine Exactors", "tier": 5, "role": "melee", "growth": 2, "ability_ids": ["overheat"], "cost": {"gold": 520, "ore": 3},
		"building_id": "building_brasshollow_pressure_rail", "building_growth": 3, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_brasshollow_debt_engine_exactors.png", "portrait_path": "res://art/units/portraits/unit_brasshollow_debt_engine_exactors.png", "icon_path": "res://art/units/battle_icons/unit_brasshollow_debt_engine_exactors.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_brasshollow_debt_engine_exactors.png", "sheet_path": "res://art/animation/runtime/units/unit_brasshollow_debt_engine_exactors.png",
		"source_sha256": "b12d450fa159032b87b9a1d3c24b43b08bf840881b76c0a17998bd46cb1861b7", "portrait_sha256": "7e7f00dd422d017963e4e7732104eafcad36fa03df881ee1288c7a561b679a33", "icon_sha256": "8be5ec19dbf20ccbb63eae299107ae93504f5a8c7f4f00081faa7a37ff30c743", "overworld_icon_sha256": "9ac979c84a94b0c7c38aeb8ede0f25f8b2cff8353abd4b17a5ec7f0f0cbefb81", "sheet_sha256": "ec4c0d42a2d6712b7dde977a95d4d25e0a938bcd0f74840f2b3825c978348088",
		"old_portrait_sha256": "2d5d2eca6bc12344e8092f22c34ffbc25ddf2abb00acd390beb45c1af0ca9c24", "old_icon_sha256": "340c2ac061b38d27a93ae9140a95af1f0792408aa4f4dcb95c271266422f8ab9", "old_overworld_icon_sha256": "7f92792b17d511eb72f92664747e5c52cf562bed40029a99ef8320d0a5011067", "old_sheet_sha256": "3840404fcf620190aea74989d1ed31d4dbb9fd5a287c10d14b86615e15361e86",
	},
	{
		"unit_id": "unit_brasshollow_crucible_crawlers", "label": "Crucible Crawlers", "tier": 6, "role": "ranged", "growth": 1, "ability_ids": ["volley"], "cost": {"gold": 820, "wood": 2, "ore": 4},
		"building_id": "building_brasshollow_crucible_dock", "building_growth": 2, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_brasshollow_crucible_crawlers.png", "portrait_path": "res://art/units/portraits/unit_brasshollow_crucible_crawlers.png", "icon_path": "res://art/units/battle_icons/unit_brasshollow_crucible_crawlers.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_brasshollow_crucible_crawlers.png", "sheet_path": "res://art/animation/runtime/units/unit_brasshollow_crucible_crawlers.png",
		"source_sha256": "4bd38c1d4a6240c77ebcc62cfea8713c583e825c4cb435859808b4d2de8a68b4", "portrait_sha256": "46e94288a7c8c560d99c435b519d3dd5d7e6d693c537762d74faa5e4943bfde8", "icon_sha256": "980fbae0113ae7891efc527892f9d65cdc7feda4654e1d2397547ca256fa2622", "overworld_icon_sha256": "7c061e8d76cf522d3ccb4218c0683746beb9ce6cdeb8f61af97e51563e300264", "sheet_sha256": "1efb305cafe4a7a8227446fcb67645a238ef36ad309d52756474e9aee3121268",
		"old_portrait_sha256": "ac71c3887678e6748f64d0b778c085701a543ba3526a34bf6bf5430b8bb0535c", "old_icon_sha256": "fe4410ded542bd858dc22354e5f516a9cbdaab549cd84b6e3c6b8820c7489a9b", "old_overworld_icon_sha256": "2aaaea9d58853ce86f2e53a6ba353b2520b68806d5b7cd7b069e10620530994a", "old_sheet_sha256": "8ffa8d1a99296edaaf41d208bbf5d2b5d6611678b927b977cd7059d920343bdb",
	},
	{
		"unit_id": "unit_brasshollow_foundry_saint", "label": "Foundry Saint", "tier": 7, "role": "melee", "growth": 1, "ability_ids": ["foundry_aura"], "cost": {"gold": 1500, "ore": 5},
		"building_id": "building_brasshollow_titan_charter_hall", "building_growth": 1, "building_discount": 4,
		"source_path": "res://art/units/source/curated/unit_brasshollow_foundry_saint.png", "portrait_path": "res://art/units/portraits/unit_brasshollow_foundry_saint.png", "icon_path": "res://art/units/battle_icons/unit_brasshollow_foundry_saint.png", "overworld_icon_path": "res://art/units/overworld_icons/unit_brasshollow_foundry_saint.png", "sheet_path": "res://art/animation/runtime/units/unit_brasshollow_foundry_saint.png",
		"source_sha256": "f1ec065a27c9eda3111505577a685ebd5a91929794240a386b5df061e6488615", "portrait_sha256": "deeefd76a89ff008784e121e1007906f5428b45518937705d225da08cc5f8b9b", "icon_sha256": "f4cc70e231717856ec5be2073c996dd9e452a5e81a55b04fa4f90e6d31b396d2", "overworld_icon_sha256": "89759763301e661ee9aa48cb5adc9dcd4742e780d7773a09cab2a35a7e9a3158", "sheet_sha256": "7d7a4ed8d6ab1d9afb98103ce5b175d2257947e9a9321dbb361d88b75e8715a7",
		"old_portrait_sha256": "c555d0b8463dceb9f0183729580276c72b02ccd155c8fca6f0da12c30ddadf14", "old_icon_sha256": "e60c7e24b95030096d47be76a77247e5d426ca4b2dee6a92e9e9f9866b81cc24", "old_overworld_icon_sha256": "c05cf942533d431107afa9b9a24352e205e241fbac58fb56f3b0742231493216", "old_sheet_sha256": "966e675b684aaeb949218f50e457ee3f72002258399ad6684339e855069a5177",
	},
]
const PRESERVED_EARLY_LADDER := [
	{"unit_id": "unit_brasshollow_scrip_haulers", "portrait_sha256": "6c56e7484656c5badd866ae20fca2f12e7c4dee6497566b5d2a8f4996aa51a6c", "icon_sha256": "60ce46eee94ee9c180155bdcdc3fdb46e9ef4940e058007d36225856d4877c8c", "overworld_icon_sha256": "a82851c7a7bdbe50eec799e7afdadefaa7a0c491da54e19b99acc06a6f97559e", "sheet_sha256": "2a20a26526eca2e50591c45cb4f0a07cfebfb310813cbf16832f1a59a6a052ae"},
	{"unit_id": "unit_brasshollow_rivet_hounds", "portrait_sha256": "45f5643f184395d443d2dff024611f6babf5f56549647155599bdfda2f0b24c8", "icon_sha256": "9a03cbf4ca07e1593d2f970373990da1b2e9774bbb3a07c7e427fcb76989c305", "overworld_icon_sha256": "0011ab3afe971268bf0f425fff22413c0588d42b32cb72d0d602aa4189df6819", "sheet_sha256": "a21781b53811e4236e573d5d73cdef492ab30bc890360d18c15f4fd1172d5a0e"},
	{"unit_id": "unit_brasshollow_furnace_pavis_teams", "portrait_sha256": "100d509cbc5eadee35d0354532cc9d5a3192ef856d73cf62c93f947aa3595e2e", "icon_sha256": "c8219bbc6e385dad5daedf72565f958205c588a1192588db3911a7d94f88e8ec", "overworld_icon_sha256": "e8b2a459ff0b50d10ca9ea7ea283e02c8389521595d375e5e2a3386c0270242f", "sheet_sha256": "5ff92a28cdfba8fb62af0e8171fa9f6d8668bb4b9257c8c5778c718dc7a89bbe"},
]
const PRESERVED_SURFACE_DIRS := {"portrait": "units/portraits", "icon": "units/battle_icons", "overworld_icon": "units/overworld_icons", "sheet": "animation/runtime/units"}
const OREVEIN_PLAYER_STACKS := [{"unit_id": "unit_brasshollow_scrip_haulers", "count": 12}, {"unit_id": "unit_brasshollow_rivet_hounds", "count": 8}, {"unit_id": "unit_brasshollow_furnace_pavis_teams", "count": 5}, {"unit_id": "unit_brasshollow_boiler_rivetcasters", "count": 2}]

var _errors: Array[String] = []
var _report := {"ok": false, "assets": [], "content": [], "runtime": {}, "errors": []}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_assets_and_provenance()
	_validate_content_authority()
	await _validate_live_brasshollow_and_board()
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
	for preserved_variant in PRESERVED_EARLY_LADDER:
		var preserved: Dictionary = preserved_variant
		var unit_id := String(preserved["unit_id"])
		for key in ["portrait", "icon", "overworld_icon", "sheet"]:
			var path := "res://art/%s/%s.png" % [String(PRESERVED_SURFACE_DIRS[key]), unit_id]
			_expect(FileAccess.get_sha256(path) == String(preserved["%s_sha256" % key]), "The curated Brasshollow early-ladder %s %s changed." % [unit_id, key])
	_report["assets"] = rows

func _validate_content_authority() -> void:
	var faction: Dictionary = ContentService.get_faction("faction_brasshollow")
	var ladder := _string_array(faction.get("unit_ladder_ids", []))
	var buildings := _string_array(faction.get("signature_building_ids", []))
	_expect(ladder.slice(3, 7) == _target_ids(), "Brasshollow upper-ladder faction order changed.")
	_expect(buildings.slice(3, 7) == _building_ids(), "Brasshollow upper-ladder building order changed.")
	_expect(String(faction.get("seed_town_id", "")) == "town_brasshollow_orevein_gantry", "Brasshollow seed town changed.")
	var rows := []
	for spec_variant in UNITS:
		var spec: Dictionary = spec_variant
		var unit: Dictionary = ContentService.get_unit(String(spec["unit_id"]))
		var building: Dictionary = ContentService.get_building(String(spec["building_id"]))
		_expect(String(unit.get("name", "")) == String(spec["label"]), "%s name changed." % String(spec["label"]))
		_expect(String(unit.get("faction_id", "")) == "faction_brasshollow" and int(unit.get("tier", 0)) == int(spec["tier"]) and String(unit.get("role", "")) == String(spec["role"]), "%s faction/tier/role changed." % String(spec["label"]))
		_expect(int(unit.get("growth", 0)) == int(spec["growth"]) and _resource_cost_contract(unit.get("cost", {})) == spec["cost"], "%s growth/cost changed." % String(spec["label"]))
		_expect(_ability_ids(unit.get("abilities", [])) == spec["ability_ids"], "%s public ability ids changed." % String(spec["label"]))
		_expect(String(building.get("unlock_unit_id", "")) == String(spec["unit_id"]), "%s building unlock changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("growth_bonus", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_growth"]), "%s building growth changed." % String(spec["label"]))
		_expect(int(Dictionary(building.get("recruitment_discount_percent", {})).get(String(spec["unit_id"]), 0)) == int(spec["building_discount"]), "%s building discount changed." % String(spec["label"]))
		rows.append({"unit_id": spec["unit_id"], "tier": unit.get("tier"), "role": unit.get("role"), "growth": unit.get("growth"), "cost": unit.get("cost", {}).duplicate(true), "ability_ids": _ability_ids(unit.get("abilities", [])), "building_id": spec["building_id"], "building_growth": spec["building_growth"], "building_discount": spec["building_discount"]})
	_report["content"] = rows

func _validate_live_brasshollow_and_board() -> void:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("orevein-contract", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "Orevein Contract must create a live session.")
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var player_army: Dictionary = session.overworld.get("army", {}) if session.overworld.get("army", {}) is Dictionary else {}
	var player_stacks: Array = _stack_contract(player_army.get("stacks", []))
	_expect(String(player_army.get("id", "")) == "army_orevein_contract_column", "The live Orevein player army id changed.")
	_expect(player_stacks == OREVEIN_PLAYER_STACKS, "The live Orevein player army stacks changed.")
	var placement := _encounter_placement(session, "orevein_archive_wardens")
	_expect(not placement.is_empty(), "Orevein Archive Wardens must remain a live encounter fixture.")
	if placement.is_empty():
		return
	var authority_before: Dictionary = session.to_dict()
	var fixture_placement: Dictionary = placement.duplicate(true)
	fixture_placement["placement_id"] = "brasshollow_upper_ladder_art_fixture"
	fixture_placement["enemy_army"] = {"id": "army_brasshollow_upper_ladder_art_fixture", "name": "Brasshollow Upper Ladder Art Fixture", "faction_id": "faction_brasshollow", "stacks": [{"unit_id": UNITS[0]["unit_id"], "count": 4}, {"unit_id": UNITS[1]["unit_id"], "count": 3}, {"unit_id": UNITS[2]["unit_id"], "count": 2}, {"unit_id": UNITS[3]["unit_id"], "count": 1}]}
	var fixture_payload: Dictionary = BattleRulesScript.create_battle_payload(session, fixture_placement)
	var fixture_enemy: Array = fixture_payload.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy")
	_expect(_battle_stack_contract(fixture_enemy) == fixture_placement["enemy_army"]["stacks"], "Production battle materialization changed the four-unit upper ladder fixture.")
	var fixture_ability_contract := _battle_target_ability_contract(fixture_enemy)
	_expect(fixture_ability_contract == {"unit_brasshollow_boiler_rivetcasters": ["pressure_artillery"], "unit_brasshollow_debt_engine_exactors": ["overheat"], "unit_brasshollow_crucible_crawlers": ["volley"], "unit_brasshollow_foundry_saint": ["foundry_aura"]}, "Production battle materialization changed normalized Brasshollow upper-ladder abilities: %s." % JSON.stringify(fixture_ability_contract))
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
	_expect(entries.size() == UNITS.size(), "BattleBoard must expose all four Brasshollow upper-ladder stacks.")
	_report["runtime"] = {"scenario_id": "orevein-contract", "player_army_id": String(player_army.get("id", "")), "player_stacks": player_stacks, "fixture_placement_id": "brasshollow_upper_ladder_art_fixture", "fixture_stacks": _battle_stack_contract(fixture_enemy), "entry_count": entries.size(), "entries": entries, "visible_stack_count": int(summary.get("visible_stack_count", 0)), "session_authority_exact": session.to_dict() == board_authority_before}
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
