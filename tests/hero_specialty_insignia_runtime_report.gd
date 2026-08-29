extends Node

const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SPECIALTY_IDS := [
	"wayfinder",
	"ledgerkeeper",
	"spellwright",
	"drillmaster",
	"armsmaster",
	"mustercaptain",
	"borderwarden",
]
const EXPECTED_REGIONS := {
	"wayfinder": Rect2(0, 0, 28, 28),
	"ledgerkeeper": Rect2(28, 0, 28, 28),
	"spellwright": Rect2(56, 0, 28, 28),
	"drillmaster": Rect2(84, 0, 28, 28),
	"armsmaster": Rect2(112, 0, 28, 28),
	"mustercaptain": Rect2(140, 0, 28, 28),
	"borderwarden": Rect2(168, 0, 28, 28),
}
const OFFER_IDS := ["spellwright", "drillmaster", "borderwarden"]
const PLACEMENT_ID := "riverwatch_hold"
const CAPTURE_DIR := "res://.artifacts/hero_specialty_insignia/captures"

var _original_content_scale_size := Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_size := get_window().size
	_original_content_scale_size = get_window().content_scale_size
	var catalog := _catalog_contract()
	if not bool(catalog.get("ok", false)):
		_fail("Insignia catalog failed", catalog, original_size)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var overworld_row: Dictionary = await _run_overworld_case(viewport_size)
		rows.append(overworld_row)
		if not bool(overworld_row.get("ok", false)):
			_fail("Overworld specialty surface failed", overworld_row, original_size)
			return
		var town_row: Dictionary = await _run_town_case(viewport_size)
		rows.append(town_row)
		if not bool(town_row.get("ok", false)):
			_fail("Town specialty surface failed", town_row, original_size)
			return
	get_window().size = original_size
	get_window().content_scale_size = _original_content_scale_size
	SessionState.reset_session()
	print("HERO_SPECIALTY_INSIGNIA_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"catalog": catalog,
		"rows": rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _catalog_contract() -> Dictionary:
	var regions := []
	var descriptions := []
	for specialty_id in SPECIALTY_IDS:
		var definition := HeroProgressionRules.specialty_definition(specialty_id)
		var texture := HeroProgressionRules.specialty_insignia_texture(specialty_id)
		if definition.is_empty() or not (texture is AtlasTexture):
			return {"ok": false, "failure": "missing_exact_texture", "specialty_id": specialty_id}
		var atlas_texture := texture as AtlasTexture
		var region: Rect2 = atlas_texture.region
		var description := HeroProgressionRules.specialty_insignia_description(specialty_id)
		if (
			String(definition.get("icon_id", "")) != "specialty_insignia_%s" % specialty_id
			or region != EXPECTED_REGIONS[specialty_id]
			or atlas_texture.atlas == null
			or atlas_texture.atlas.resource_path != HeroProgressionRules.SPECIALTY_INSIGNIA_ATLAS_PATH
			or atlas_texture.atlas.get_size() != Vector2(196, 28)
			or description.length() < 24
		):
			return {
				"ok": false,
				"failure": "ownership_mismatch",
				"specialty_id": specialty_id,
				"region": region,
				"description": description,
			}
		regions.append(region)
		descriptions.append(description)
	var invalid_exact := (
		HeroProgressionRules.specialty_id_for_action("choose_specialty:not_real") == ""
		and HeroProgressionRules.specialty_id_for_action("not_an_action") == ""
		and HeroProgressionRules.specialty_insignia_texture("not_real") == null
		and HeroProgressionRules.specialty_insignia_description("not_real") == ""
	)
	return {
		"ok": regions.size() == 7 and _unique(regions).size() == 7 and _unique(descriptions).size() == 7 and invalid_exact,
		"specialty_count": regions.size(),
		"unique_region_count": _unique(regions).size(),
		"unique_description_count": _unique(descriptions).size(),
		"invalid_fail_closed": invalid_exact,
		"atlas_path": HeroProgressionRules.SPECIALTY_INSIGNIA_ATLAS_PATH,
	}

func _run_overworld_case(viewport_size: Vector2i) -> Dictionary:
	get_window().content_scale_size = viewport_size
	get_window().size = viewport_size
	await get_tree().process_frame
	var session = _session_with_specialty_offer(false)
	var authority_before: Dictionary = session.to_dict()
	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for unused in range(3):
		await get_tree().process_frame
	shell.call("_apply_responsive_layout")
	var drawer_state: Dictionary = shell.call("validation_open_command_drawer")
	for unused in range(3):
		await get_tree().process_frame
	drawer_state = shell.call("validation_open_command_drawer")
	await get_tree().process_frame
	var container := shell.get_node_or_null("%SpecialtyActions") as Control
	var presentation := _surface_contract(container, OFFER_IDS)
	var invalid_button := Button.new()
	shell.call("_apply_specialty_action_icon", invalid_button, {"id": "choose_specialty:not_real"})
	var invalid_fail_closed := invalid_button.icon == null
	invalid_button.free()
	var capture_path := "%s/overworld_%dx%d.png" % [CAPTURE_DIR, viewport_size.x, viewport_size.y]
	var capture_ok := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(capture_path)) == OK
	var authority_exact: bool = session.to_dict() == authority_before
	var row := {
		"ok": bool(presentation.get("ok", false)) and invalid_fail_closed and capture_ok and authority_exact,
		"surface": "overworld",
		"viewport": [viewport_size.x, viewport_size.y],
		"presentation": presentation,
		"drawer_state": drawer_state,
		"invalid_fail_closed": invalid_fail_closed,
		"capture_ok": capture_ok,
		"capture_path": capture_path,
		"authority_exact": authority_exact,
	}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _run_town_case(viewport_size: Vector2i) -> Dictionary:
	get_window().content_scale_size = viewport_size
	get_window().size = viewport_size
	await get_tree().process_frame
	var session = _session_with_specialty_offer(true)
	var authority_before: Dictionary = session.to_dict()
	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	for unused in range(5):
		await get_tree().process_frame
	shell.call("_apply_responsive_layout")
	shell.call("_rebuild_specialty_actions", TownRules.get_specialty_actions(session))
	await get_tree().process_frame
	var container := shell.get_node_or_null("%SpecialtyActions") as Control
	var presentation := _surface_contract(container, OFFER_IDS)
	var invalid_button := Button.new()
	shell.call("_apply_specialty_action_icon", invalid_button, {"id": "choose_specialty:not_real"})
	var invalid_fail_closed := invalid_button.icon == null
	invalid_button.free()
	var capture_path := "%s/town_%dx%d.png" % [CAPTURE_DIR, viewport_size.x, viewport_size.y]
	var capture_ok := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(capture_path)) == OK
	var authority_exact: bool = session.to_dict() == authority_before
	var row := {
		"ok": bool(presentation.get("ok", false)) and invalid_fail_closed and capture_ok and authority_exact,
		"surface": "town",
		"viewport": [viewport_size.x, viewport_size.y],
		"presentation": presentation,
		"invalid_fail_closed": invalid_fail_closed,
		"capture_ok": capture_ok,
		"capture_path": capture_path,
		"authority_exact": authority_exact,
	}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _surface_contract(container: Control, expected_ids: Array) -> Dictionary:
	if container == null:
		return {"ok": false, "failure": "container_missing"}
	var buttons := _buttons_in(container)
	if buttons.size() != expected_ids.size():
		return {"ok": false, "failure": "button_count", "actual": buttons.size(), "expected": expected_ids.size()}
	var rows := []
	var exact := true
	var contained_when_visible := true
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		var specialty_id := String(expected_ids[index])
		var expected_texture := HeroProgressionRules.specialty_insignia_texture(specialty_id) as AtlasTexture
		var texture := button.icon as AtlasTexture
		var description := HeroProgressionRules.specialty_insignia_description(specialty_id)
		var row_exact := (
			texture != null
			and expected_texture != null
			and texture.region == expected_texture.region
			and texture.atlas != null
			and texture.atlas.resource_path == HeroProgressionRules.SPECIALTY_INSIGNIA_ATLAS_PATH
			and button.expand_icon
			and button.get_theme_constant("icon_max_width") == 24
			and button.text.find(String(HeroProgressionRules.specialty_definition(specialty_id).get("short_name", ""))) >= 0
			and button.tooltip_text.find(description) >= 0
		)
		if container.is_visible_in_tree():
			contained_when_visible = contained_when_visible and container.get_global_rect().encloses(button.get_global_rect())
		exact = exact and row_exact
		rows.append({"specialty_id": specialty_id, "region": texture.region if texture != null else Rect2(), "exact": row_exact})
	return {
		"ok": exact and contained_when_visible,
		"button_count": buttons.size(),
		"container_visible": container.visible,
		"container_visible_in_tree": container.is_visible_in_tree(),
		"container_rect": container.get_global_rect(),
		"contained_when_visible": contained_when_visible,
		"rows": rows,
	}

func _session_with_specialty_offer(at_town: bool):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["level"] = 2
	hero["specialties"] = []
	hero["pending_specialty_choices"] = [{"level": 2, "options": OFFER_IDS.duplicate()}]
	hero = HeroProgressionRules.ensure_hero_progression(hero)
	session.overworld["hero"] = hero.duplicate(true)
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(hero.get("id", "")):
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes
	if at_town:
		var town := _town(session, PLACEMENT_ID)
		var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
		session.overworld["hero_position"] = position.duplicate(true)
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero.duplicate(true)
		for index in range(heroes.size()):
			if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(hero.get("id", "")):
				heroes[index] = hero.duplicate(true)
		session.overworld["player_heroes"] = heroes
		OverworldRules.set_active_town_visit(session, PLACEMENT_ID)
	return session

func _town(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _buttons_in(node: Node) -> Array:
	var buttons := []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_buttons_in(child))
	return buttons

func _unique(values: Array) -> Array:
	var result := []
	for value in values:
		if value not in result:
			result.append(value)
	return result

func _fail(message: String, payload: Dictionary, original_size: Vector2i) -> void:
	get_window().size = original_size
	get_window().content_scale_size = _original_content_scale_size
	SessionState.reset_session()
	push_error("HERO_SPECIALTY_INSIGNIA_RUNTIME_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
