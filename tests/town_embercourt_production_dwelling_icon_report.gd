extends Node

const TownConstructionBoardScript = preload("res://scripts/core/TownConstructionBoard.gd")

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const TARGET_BUILDING_IDS := [
	"building_muster_yard",
	"building_bowyer_lodge",
	"building_embercourt_bargebow_slip",
	"building_embercourt_oath_pikehall",
	"building_embercourt_beacon_court",
	"building_embercourt_drake_sluice",
	"building_embercourt_charter_bastion",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var catalog := _catalog_contract()
	if not bool(catalog.get("ok", false)):
		_fail("Building icon catalog failed: %s" % JSON.stringify(catalog), original_window_size)
		return
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _live_case(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Building icon live case failed: %s" % JSON.stringify(row), original_window_size)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [_report_marker(), JSON.stringify({"ok": true, "catalog": catalog, "rows": rows})])
	get_tree().quit(0)

func _catalog_contract() -> Dictionary:
	var source_hashes := []
	var icon_hashes := []
	var icon_paths := []
	for building_id in _target_building_ids():
		var art: Dictionary = ContentService.get_building_art(building_id)
		var source_path := String(art.get("source_path", ""))
		var icon_path := String(art.get("icon_path", ""))
		var texture := load(icon_path) as Texture2D
		if String(art.get("id", "")) != building_id or String(art.get("building_id", "")) != building_id:
			return {"ok": false, "failure": "identity", "building_id": building_id, "art": art}
		if String(art.get("source_kind", "")) != "curated_original_building" or texture == null or texture.get_size() != Vector2(256.0, 256.0):
			return {"ok": false, "failure": "asset", "building_id": building_id, "art": art}
		if FileAccess.get_sha256(source_path) != String(art.get("source_sha256", "")) or FileAccess.get_sha256(icon_path) != String(art.get("icon_sha256", "")):
			return {"ok": false, "failure": "provenance", "building_id": building_id}
		if TownRules.building_icon_path(building_id) != icon_path:
			return {"ok": false, "failure": "resolver", "building_id": building_id}
		source_hashes.append(String(art.get("source_sha256", "")))
		icon_hashes.append(String(art.get("icon_sha256", "")))
		icon_paths.append(icon_path)
	var fallback_exact := true
	var target_count := 0
	var specific_count := 0
	var fallback_count := 0
	for building_id in ContentService.get_content_ids(ContentService.BUILDINGS_PATH):
		if not ContentService.get_building_art(building_id).is_empty():
			specific_count += 1
			if building_id in _target_building_ids():
				target_count += 1
		else:
			fallback_count += 1
			fallback_exact = fallback_exact and TownRules.building_icon_path(building_id) == TownRules.building_category_icon_path(building_id)
	return {
		"ok": target_count == _target_building_ids().size() and specific_count == 160 and fallback_count == 0 and fallback_exact and source_hashes.size() == _target_building_ids().size() and icon_hashes.size() == _target_building_ids().size() and icon_paths.size() == _target_building_ids().size() and _unique(source_hashes) and _unique(icon_hashes) and _unique(icon_paths),
		"target_count": target_count,
		"specific_count": specific_count,
		"fallback_count": fallback_count,
		"fallback_exact": fallback_exact,
		"source_hashes": source_hashes,
		"icon_hashes": icon_hashes,
		"icon_paths": icon_paths,
	}

func _live_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	_move_active_hero_to_town(session, town)
	SessionState.set_active_session(session)
	var before: Dictionary = session.to_dict()
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_town_catalog", "build")
	await get_tree().process_frame
	await get_tree().process_frame
	var construction = shell.get("_construction_screen")
	var board: Dictionary = construction.board() if construction != null else {}
	var faction_id := String(board.get("faction_id", ""))
	var direct_icons_exact: bool = construction != null
	for building_id in _target_building_ids():
		var art: TextureRect = construction.call("_art_rect", building_id, false) if construction != null else null
		direct_icons_exact = direct_icons_exact and art != null and art.texture != null and art.texture.resource_path == TownRules.building_icon_path(building_id, faction_id)
		if art != null:
			art.free()
	var live_exact: bool = construction != null and int(board.get("slot_count", 0)) == 23
	for slot in TownConstructionBoardScript.ordered_slots(board):
		var tile := construction.find_child("Slot_%s" % String(slot.get("id", "")), true, false) as Button
		var tile_art: TextureRect = tile.find_child("Art", true, false) as TextureRect if tile != null else null
		live_exact = live_exact and tile_art != null and tile_art.texture != null and tile_art.texture.resource_path == TownRules.building_icon_path(String(slot.get("art_building_id", "")), faction_id)
	var all_production_specific := true
	for building_id in ContentService.get_content_ids(ContentService.BUILDINGS_PATH):
		var art: Dictionary = ContentService.get_building_art(building_id)
		all_production_specific = all_production_specific and not art.is_empty() and TownRules.building_icon_path(building_id) == String(art.get("icon_path", "")) and TownRules.building_icon_path(building_id) != TownRules.building_category_icon_path(building_id)
	var invalid_art: TextureRect = construction.call("_art_rect", "missing_building", false) if construction != null else null
	var invalid_fail_closed: bool = invalid_art != null and invalid_art.texture == null
	if invalid_art != null:
		invalid_art.free()
	var authority_exact := session.to_dict() == before and int(session.save_version) == SessionStateStore.SAVE_VERSION
	var result := {"ok": get_window().size == viewport_size and direct_icons_exact and live_exact and all_production_specific and invalid_fail_closed and authority_exact, "viewport_size": viewport_size, "direct_icons_exact": direct_icons_exact, "live_exact": live_exact, "all_production_specific": all_production_specific, "invalid_fail_closed": invalid_fail_closed, "authority_exact": authority_exact}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	await get_tree().process_frame
	return result

func _buttons_in(node: Node) -> Array:
	var buttons := []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_buttons_in(child))
	return buttons

func _unique(values: Array) -> bool:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size() == values.size()

func _target_building_ids() -> Array:
	return TARGET_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_EMBERCOURT_PRODUCTION_DWELLING_ICON_REPORT"

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

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)
