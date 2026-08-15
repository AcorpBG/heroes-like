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

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld faction hero sprite row failed: %s" % row)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_FACTION_HERO_SPRITE_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"production_hero_count": 60,
		"faction_count": EXPECTED_FACTION_ASSETS.size(),
		"viewports": [[1280, 720], [1920, 1080]],
		"fallback": "procedural_hero_marker",
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
	_configure_hero_fixture(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_hero_presentation_profiles"):
		shell.queue_free()
		return {"ok": false, "failure": "validation_surface_missing"}
	var authority_before: Dictionary = session.to_dict()
	var profiles: Array = map_view.call("validation_hero_presentation_profiles")
	var exact := _validate_profiles(profiles)
	if not bool(exact.get("ok", false)):
		shell.queue_free()
		return {"ok": false, "failure": "hero_profiles", "detail": exact}

	var heroes: Array = session.overworld.get("player_heroes", [])
	var first_hero: Dictionary = heroes[0]
	first_hero["id"] = "hero_missing_faction_sprite_fixture"
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var first_position: Dictionary = first_hero.get("position", {})
	var fallback_tile := Vector2i(int(first_position.get("x", -1)), int(first_position.get("y", -1)))
	var fallback_presentation: Dictionary = map_view.call("validation_tile_presentation", fallback_tile)
	var fallback: Dictionary = fallback_presentation.get("hero_presentation", {})
	var fallback_exact: bool = String(fallback.get("hero_id", "")) == "hero_missing_faction_sprite_fixture" \
		and String(fallback.get("faction_id", "")) == "" \
		and String(fallback.get("sprite_asset_id", "")) == "" \
		and bool(fallback.get("uses_procedural_fallback", false)) \
		and not bool(fallback.get("uses_faction_sprite", true))

	session.from_dict(authority_before)
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_profiles: Array = map_view.call("validation_hero_presentation_profiles")
	var restored_exact: bool = restored_profiles == profiles and session.to_dict() == authority_before
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var containment_exact := viewport_rect.encloses(shell_rect)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": fallback_exact and restored_exact and containment_exact,
		"viewport": [viewport_size.x, viewport_size.y],
		"profile_count": profiles.size(),
		"asset_ids": exact.get("asset_ids", []),
		"active_identity_exact": exact.get("active_identity_exact", false),
		"grounding_exact": exact.get("grounding_exact", false),
		"fallback_exact": fallback_exact,
		"restored_exact": restored_exact,
		"containment_exact": containment_exact,
	}

func _validate_profiles(profiles: Array) -> Dictionary:
	if profiles.size() != EXPECTED_FACTION_ASSETS.size():
		return {"ok": false, "reason": "profile_count", "actual": profiles.size()}
	var seen_factions: Dictionary = {}
	var seen_assets: Dictionary = {}
	var active_count := 0
	var grounding_exact := true
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			return {"ok": false, "reason": "profile_type"}
		var profile: Dictionary = profile_value
		var hero_id := String(profile.get("hero_id", ""))
		var faction_id := String(profile.get("faction_id", ""))
		var expected_hero_id := String(REPRESENTATIVE_HERO_IDS.get(faction_id, ""))
		var expected_asset_id := String(EXPECTED_FACTION_ASSETS.get(faction_id, ""))
		var expected_path := "res://art/overworld/runtime/heroes/factions/%s.png" % faction_id.trim_prefix("faction_")
		if hero_id != expected_hero_id or String(profile.get("sprite_asset_id", "")) != expected_asset_id:
			return {"ok": false, "reason": "identity", "profile": profile}
		if String(profile.get("sprite_path", "")) != expected_path or not (load(expected_path) is Texture2D):
			return {"ok": false, "reason": "texture", "profile": profile}
		if not bool(profile.get("uses_faction_sprite", false)) or bool(profile.get("uses_procedural_fallback", true)):
			return {"ok": false, "reason": "fallback_state", "profile": profile}
		if bool(profile.get("is_active", false)):
			active_count += 1
		grounding_exact = grounding_exact \
			and String(profile.get("grounding_model", "")) == "hero_foot_contact_without_base_ellipse" \
			and String(profile.get("depth_cue_model", "")) == "hero_foot_contact_shadow_with_boot_occlusion"
		seen_factions[faction_id] = true
		seen_assets[expected_asset_id] = true
	return {
		"ok": seen_factions.size() == 6 and seen_assets.size() == 6 and active_count == 1 and grounding_exact,
		"asset_ids": seen_assets.keys(),
		"active_identity_exact": active_count == 1,
		"grounding_exact": grounding_exact,
	}

func _configure_hero_fixture(session) -> void:
	var source_heroes: Array = session.overworld.get("player_heroes", [])
	var source: Dictionary = source_heroes[0].duplicate(true)
	var heroes: Array = []
	var faction_ids: Array = EXPECTED_FACTION_ASSETS.keys()
	for index in range(faction_ids.size()):
		var faction_id := String(faction_ids[index])
		var hero_id := String(REPRESENTATIVE_HERO_IDS.get(faction_id, ""))
		var template := ContentService.get_hero(hero_id)
		var hero := source.duplicate(true)
		hero["id"] = hero_id
		hero["name"] = String(template.get("name", hero_id))
		hero["is_primary"] = index == 0
		hero["position"] = {"x": 3 + index * 3, "y": 4}
		heroes.append(hero)
	session.hero_id = String(heroes[0].get("id", ""))
	session.overworld["player_heroes"] = heroes
	session.overworld["active_hero_id"] = String(heroes[0].get("id", ""))
	session.overworld["primary_hero_id"] = String(heroes[0].get("id", ""))
	session.overworld["hero"] = heroes[0].duplicate(true)
	session.overworld["hero_position"] = heroes[0].get("position", {}).duplicate(true)
	session.overworld["army"] = heroes[0].get("army", {}).duplicate(true)
	session.overworld["movement"] = heroes[0].get("movement", {}).duplicate(true)
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
	for hero in heroes:
		var position: Dictionary = hero.get("position", {})
		var x := int(position.get("x", -1))
		var y := int(position.get("y", -1))
		visible_tiles[y][x] = true
		explored_tiles[y][x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": heroes.size(),
		"explored_count": heroes.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
