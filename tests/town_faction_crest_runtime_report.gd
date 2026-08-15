extends Node

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const FACTION_IDS := [
	"faction_embercourt",
	"faction_mireclaw",
	"faction_sunvault",
	"faction_thornwake",
	"faction_brasshollow",
	"faction_veilmourn",
]
const EXPECTED_PATHS := {
	"faction_embercourt": "res://art/factions/runtime/crests/embercourt.png",
	"faction_mireclaw": "res://art/factions/runtime/crests/mireclaw.png",
	"faction_sunvault": "res://art/factions/runtime/crests/sunvault.png",
	"faction_thornwake": "res://art/factions/runtime/crests/thornwake.png",
	"faction_brasshollow": "res://art/factions/runtime/crests/brasshollow.png",
	"faction_veilmourn": "res://art/factions/runtime/crests/veilmourn.png",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var catalog := _catalog_contract()
	if not bool(catalog.get("ok", false)):
		_fail("Faction crest catalog failed: %s" % JSON.stringify(catalog), original_window_size)
		return
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_live_case(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Faction crest live case failed: %s" % JSON.stringify(row), original_window_size)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_FACTION_CREST_RUNTIME_REPORT %s" % JSON.stringify({"ok": true, "catalog": catalog, "rows": rows}))
	get_tree().quit(0)

func _catalog_contract() -> Dictionary:
	var faction_ids: Array[String] = ContentService.get_content_ids(ContentService.FACTIONS_PATH)
	var crest_ids: Array[String] = ContentService.get_content_ids(ContentService.FACTION_CRESTS_PATH)
	var paths := []
	var rows := []
	for faction_id in FACTION_IDS:
		var faction := ContentService.get_faction(faction_id)
		var crest := ContentService.get_faction_crest(faction_id)
		var path := TownRules.faction_crest_icon_path(faction_id)
		var texture := load(path) as Texture2D if path != "" else null
		var row_ok: bool = not faction.is_empty() \
			and String(crest.get("id", "")) == faction_id \
			and String(crest.get("crest_id", "")) == "faction_crest_%s" % faction_id.trim_prefix("faction_") \
			and String(crest.get("material_language", "")).strip_edges() != "" \
			and path == String(EXPECTED_PATHS.get(faction_id, "")) \
			and texture != null \
			and texture.get_size() == Vector2(256.0, 256.0)
		rows.append({"faction_id": faction_id, "path": path, "size": texture.get_size() if texture != null else Vector2.ZERO, "ok": row_ok})
		if path != "" and path not in paths:
			paths.append(path)
	return {
		"ok": faction_ids == FACTION_IDS and crest_ids == FACTION_IDS and paths.size() == FACTION_IDS.size() and rows.all(func(row): return bool(row.get("ok", false))) and TownRules.faction_crest_icon_path("faction_missing") == "",
		"faction_ids": faction_ids,
		"crest_ids": crest_ids,
		"unique_paths": paths,
		"rows": rows,
		"invalid_faction_fail_closed": TownRules.faction_crest_icon_path("faction_missing") == "",
	}

func _run_live_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_move_active_hero_to_town(session, town)
	SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if not shell.has_method("_faction_crest_validation_snapshot"):
		return await _finish_case(shell, {"ok": false, "failure": "crest_validation_missing"})
	var live_session = SessionState.ensure_active_session()
	town = _first_player_town(live_session)
	var authority_before: Dictionary = live_session.to_dict()
	var original_town: Dictionary = town.duplicate(true)
	var action_catalog_before: Dictionary = shell.validation_action_catalog()
	var top_bar := shell.get_node_or_null("ContentMargin/Content/Banner/BannerPad/TopBar") as Control
	var crest_icon := shell.get_node_or_null("%CrestIcon") as TextureRect
	if top_bar == null or crest_icon == null:
		return await _finish_case(shell, {"ok": false, "failure": "crest_nodes_missing"})
	var top_bar_rect := top_bar.get_global_rect()
	var crest_frame_rect := Rect2()
	var rows := []
	var all_exact := true
	for faction_id in FACTION_IDS:
		var faction := ContentService.get_faction(faction_id)
		town["town_id"] = String(faction.get("seed_town_id", ""))
		var fixture_authority_before: Dictionary = live_session.to_dict()
		shell._refresh_faction_crest()
		await get_tree().process_frame
		var summary: Dictionary = shell._faction_crest_validation_snapshot()
		var texture_size := crest_icon.texture.get_size() if crest_icon.texture != null else Vector2.ZERO
		var icon_rect: Rect2 = summary.get("icon_rect", Rect2())
		var frame_rect: Rect2 = summary.get("frame_rect", Rect2())
		if crest_frame_rect == Rect2():
			crest_frame_rect = frame_rect
		var row_ok: bool = String(summary.get("faction_id", "")) == faction_id \
			and String(summary.get("faction_name", "")) == String(faction.get("name", "")) \
			and String(summary.get("icon_path", "")) == String(EXPECTED_PATHS.get(faction_id, "")) \
			and String(summary.get("texture_path", "")) == String(EXPECTED_PATHS.get(faction_id, "")) \
			and bool(summary.get("icon_visible", false)) \
			and not bool(summary.get("fallback_visible", true)) \
			and String(summary.get("fallback_glyph_id", "")) == "town" \
			and String(summary.get("tooltip_text", "")) == "%s crest" % String(faction.get("name", "")) \
			and int(summary.get("icon_stretch_mode", -1)) == TextureRect.STRETCH_KEEP_ASPECT_CENTERED \
			and int(summary.get("icon_expand_mode", -1)) == TextureRect.EXPAND_IGNORE_SIZE \
			and texture_size == Vector2(256.0, 256.0) \
			and icon_rect.size == Vector2(42.0, 40.0) \
			and frame_rect.encloses(icon_rect) \
			and frame_rect == crest_frame_rect \
			and top_bar.get_global_rect() == top_bar_rect \
			and live_session.to_dict() == fixture_authority_before
		rows.append({"faction_id": faction_id, "ok": row_ok, "path": summary.get("texture_path", ""), "icon_rect": icon_rect, "frame_rect": frame_rect, "texture_size": texture_size})
		all_exact = all_exact and row_ok
	town["town_id"] = "town_missing_faction_crest_fixture"
	var fallback_authority_before: Dictionary = live_session.to_dict()
	shell._refresh_faction_crest()
	await get_tree().process_frame
	var fallback: Dictionary = shell._faction_crest_validation_snapshot()
	var fallback_exact: bool = String(fallback.get("faction_id", "")) == "" \
		and String(fallback.get("icon_path", "")) == "" \
		and String(fallback.get("texture_path", "")) == "" \
		and not bool(fallback.get("icon_visible", true)) \
		and bool(fallback.get("fallback_visible", false)) \
		and String(fallback.get("fallback_glyph_id", "")) == "town" \
		and live_session.to_dict() == fallback_authority_before \
		and top_bar.get_global_rect() == top_bar_rect \
		and fallback.get("frame_rect", Rect2()) == crest_frame_rect
	town.clear()
	town.merge(original_town, true)
	shell._refresh_faction_crest()
	await get_tree().process_frame
	var restored: Dictionary = shell._faction_crest_validation_snapshot()
	var restored_exact: bool = live_session.to_dict() == authority_before \
		and shell.validation_action_catalog() == action_catalog_before \
		and String(restored.get("faction_id", "")) == "faction_embercourt" \
		and String(restored.get("texture_path", "")) == String(EXPECTED_PATHS["faction_embercourt"]) \
		and top_bar.get_global_rect() == top_bar_rect \
		and restored.get("frame_rect", Rect2()) == crest_frame_rect \
		and int(live_session.save_version) == SessionStateStore.SAVE_VERSION
	return await _finish_case(shell, {
		"ok": all_exact and fallback_exact and restored_exact,
		"viewport_size": viewport_size,
		"faction_rows": rows,
		"fallback_exact": fallback_exact,
		"restored_exact": restored_exact,
		"top_bar_rect": top_bar_rect,
		"crest_frame_rect": crest_frame_rect,
		"save_version": int(live_session.save_version),
	})

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	SessionState.reset_session()
	await get_tree().process_frame
	return result

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)
