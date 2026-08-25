extends Node

const SCENARIO_ID := "ninefold-confluence"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const EXPECTED_FACTION_ASSETS := {
	"faction_embercourt": "hero_faction_embercourt",
	"faction_mireclaw": "hero_faction_mireclaw",
	"faction_sunvault": "hero_faction_sunvault",
	"faction_thornwake": "hero_faction_thornwake",
	"faction_brasshollow": "hero_faction_brasshollow",
	"faction_veilmourn": "hero_faction_veilmourn",
}
const REPRESENTATIVE_HERO_IDS := {
	"faction_embercourt": "hero_lyra",
	"faction_mireclaw": "hero_mireclaw_zhorra_fenwake",
	"faction_sunvault": "hero_sunvault_ilyr_glassmarshal",
	"faction_thornwake": "hero_thornwake_ardren_briarmarshal",
	"faction_brasshollow": "hero_brasshollow_daxis_chaincaptain",
	"faction_veilmourn": "hero_veilmourn_ruln_vanehook",
}
const FALLBACK_CASES := ["commanderless", "unknown_hero", "commander_faction_mismatch", "spawned_faction_mismatch"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld enemy commander sprite row failed: %s" % row, original_window_size)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_ENEMY_COMMANDER_SPRITE_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"faction_count": EXPECTED_FACTION_ASSETS.size(),
		"viewports": [[1280, 720], [1920, 1080]],
		"fallback_cases": FALLBACK_CASES,
		"fallback_order": ["primary_unit_icon", "mapped_or_default_encounter_sprite"],
		"rows": rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var session = ScenarioFactory.create_session(SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	_configure_commander_fixture(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_enemy_commander_presentation_profiles"):
		return await _finish_case(shell, {"ok": false, "failure": "validation_surface_missing"})

	var authority_before: Dictionary = session.to_dict()
	var profiles: Array = map_view.call("validation_enemy_commander_presentation_profiles")
	var exact: Dictionary = _validate_profiles(profiles)
	if not bool(exact.get("ok", false)):
		return await _finish_case(shell, {"ok": false, "failure": "commander_profiles", "detail": exact})

	var fallback_rows: Array = []
	for case_id in FALLBACK_CASES:
		session.from_dict(authority_before)
		if not _apply_fallback_case(session, "enemy_commander_fixture:faction_embercourt", case_id):
			return await _finish_case(shell, {"ok": false, "failure": "fallback_fixture_mutation", "case": case_id})
		_set_map_view_from_session(map_view, session)
		await get_tree().process_frame
		await get_tree().process_frame
		var fallback_profiles: Array = map_view.call("validation_enemy_commander_presentation_profiles")
		var fallback := _profile_by_placement(fallback_profiles, "enemy_commander_fixture:faction_embercourt")
		var fallback_exact: bool = not fallback.is_empty() \
			and String(fallback.get("sprite_asset_id", "")) == "" \
			and not bool(fallback.get("uses_commander_sprite", true)) \
			and bool(fallback.get("uses_unit_icon_fallback", false)) \
			and not bool(fallback.get("uses_encounter_sprite_fallback", true)) \
			and String(fallback.get("unit_icon_path", "")) != "" \
			and load(String(fallback.get("unit_icon_path", ""))) is Texture2D
		fallback_rows.append({"case": case_id, "exact": fallback_exact})
		if not fallback_exact:
			return await _finish_case(shell, {"ok": false, "failure": "fallback", "case": case_id, "profile": fallback})

	session.from_dict(authority_before)
	_set_map_view_from_session(map_view, session)
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_profiles: Array = map_view.call("validation_enemy_commander_presentation_profiles")
	var restored_exact: bool = restored_profiles == profiles and session.to_dict() == authority_before
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var containment_exact: bool = viewport_rect.encloses(shell_rect)
	return await _finish_case(shell, {
		"ok": restored_exact and containment_exact and fallback_rows.all(func(row): return bool(row.get("exact", false))),
		"viewport": [viewport_size.x, viewport_size.y],
		"profile_count": profiles.size(),
		"asset_ids": exact.get("asset_ids", []),
		"hostile_treatment_exact": exact.get("hostile_treatment_exact", false),
		"fallback_rows": fallback_rows,
		"restored_exact": restored_exact,
		"containment_exact": containment_exact,
	})

func _validate_profiles(profiles: Array) -> Dictionary:
	if profiles.size() != EXPECTED_FACTION_ASSETS.size():
		return {"ok": false, "reason": "profile_count", "actual": profiles.size()}
	var seen_factions: Dictionary = {}
	var seen_assets: Dictionary = {}
	var hostile_treatment_exact := true
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			return {"ok": false, "reason": "profile_type"}
		var profile: Dictionary = profile_value
		var faction_id := String(profile.get("spawned_by_faction_id", ""))
		var expected_hero_id := String(REPRESENTATIVE_HERO_IDS.get(faction_id, ""))
		var expected_asset_id := String(EXPECTED_FACTION_ASSETS.get(faction_id, ""))
		var expected_path := "res://art/overworld/runtime/heroes/factions/%s.png" % faction_id.trim_prefix("faction_")
		if String(profile.get("hero_id", "")) != expected_hero_id \
			or String(profile.get("commander_faction_id", "")) != faction_id \
			or String(profile.get("authored_faction_id", "")) != faction_id \
			or String(profile.get("sprite_asset_id", "")) != expected_asset_id:
			return {"ok": false, "reason": "identity", "profile": profile}
		if String(profile.get("sprite_path", "")) != expected_path or not (load(expected_path) is Texture2D):
			return {"ok": false, "reason": "texture", "profile": profile}
		if not bool(profile.get("uses_commander_sprite", false)) \
			or bool(profile.get("uses_unit_icon_fallback", true)) \
			or bool(profile.get("uses_encounter_sprite_fallback", true)):
			return {"ok": false, "reason": "fallback_state", "profile": profile}
		if String(profile.get("primary_unit_id", "")) == "" or String(profile.get("unit_icon_path", "")) == "":
			return {"ok": false, "reason": "unit_fallback_authority", "profile": profile}
		hostile_treatment_exact = hostile_treatment_exact \
			and String(profile.get("hostile_treatment", "")) == "encounter_ring" \
			and is_equal_approx(float(profile.get("visible_extent_tiles", 0.0)), 0.46) \
			and String(profile.get("grounding_model", "")) == "family_specific_contact_scuffs_no_marker_plate" \
			and String(profile.get("contact_model", "")) == "localized_object_contact_shadow"
		seen_factions[faction_id] = true
		seen_assets[expected_asset_id] = true
	return {
		"ok": seen_factions.size() == 6 and seen_assets.size() == 6 and hostile_treatment_exact,
		"asset_ids": seen_assets.keys(),
		"hostile_treatment_exact": hostile_treatment_exact,
	}

func _configure_commander_fixture(session) -> void:
	var encounters: Array = []
	var faction_ids: Array = EXPECTED_FACTION_ASSETS.keys()
	for index in range(faction_ids.size()):
		var faction_id := String(faction_ids[index])
		var hero_id := String(REPRESENTATIVE_HERO_IDS.get(faction_id, ""))
		var encounter := {
			"placement_id": "enemy_commander_fixture:%s" % faction_id,
			"encounter_id": "encounter_town_assault",
			"enemy_group_id": "army_mireclaw_raiding_party",
			"x": 4 + index * 4,
			"y": 4,
			"spawned_by_faction_id": faction_id,
			"target_kind": "town",
			"target_placement_id": "enemy_commander_fixture_target",
			"enemy_commander_state": {"roster_hero_id": hero_id, "faction_id": faction_id},
		}
		encounter["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(encounter, hero_id, faction_id, session)
		encounters.append(encounter)
	session.overworld["encounters"] = encounters
	session.overworld["resolved_encounters"] = []
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for encounter in encounters:
		var x := int(encounter.get("x", -1))
		var y := int(encounter.get("y", -1))
		visible_tiles[y][x] = true
		explored_tiles[y][x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": encounters.size(),
		"explored_count": encounters.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _apply_fallback_case(session, placement_id: String, case_id: String) -> bool:
	var encounters_value = session.overworld.get("encounters", [])
	if not (encounters_value is Array):
		return false
	var encounters: Array = encounters_value
	for index in range(encounters.size()):
		if not (encounters[index] is Dictionary):
			continue
		var encounter: Dictionary = encounters[index].duplicate(true)
		if String(encounter.get("placement_id", "")) != placement_id:
			continue
		match case_id:
			"commanderless":
				encounter.erase("enemy_commander_state")
			"unknown_hero":
				var state: Dictionary = encounter.get("enemy_commander_state", {})
				state["roster_hero_id"] = "hero_missing_enemy_commander_fixture"
				encounter["enemy_commander_state"] = state
			"commander_faction_mismatch":
				var state: Dictionary = encounter.get("enemy_commander_state", {})
				state["faction_id"] = "faction_mireclaw"
				encounter["enemy_commander_state"] = state
			"spawned_faction_mismatch":
				encounter["spawned_by_faction_id"] = "faction_mireclaw"
			_:
				return false
		encounters[index] = encounter
		session.overworld["encounters"] = encounters
		return _fallback_case_mutation_exact(encounter, case_id)
	return false

func _fallback_case_mutation_exact(encounter: Dictionary, case_id: String) -> bool:
	var state: Dictionary = encounter.get("enemy_commander_state", {}) if encounter.get("enemy_commander_state", {}) is Dictionary else {}
	match case_id:
		"commanderless":
			return not encounter.has("enemy_commander_state")
		"unknown_hero":
			return String(state.get("roster_hero_id", "")) == "hero_missing_enemy_commander_fixture"
		"commander_faction_mismatch":
			return String(state.get("faction_id", "")) == "faction_mireclaw"
		"spawned_faction_mismatch":
			return String(encounter.get("spawned_by_faction_id", "")) == "faction_mireclaw"
	return false

func _set_map_view_from_session(map_view, session) -> void:
	map_view.call(
		"set_map_state",
		session,
		session.overworld.get("map", []),
		OverworldRules.derive_map_size(session),
		OverworldRules.hero_position(session)
	)

func _profile_by_placement(profiles: Array, placement_id: String) -> Dictionary:
	for profile_value in profiles:
		if profile_value is Dictionary and String(profile_value.get("placement_id", "")) == placement_id:
			return profile_value
	return {}

func _finish_case(shell, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)
