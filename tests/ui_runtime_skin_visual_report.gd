extends Node

const OUTPUT_DIR := "res://.artifacts/ui_runtime_skin_visual_report"

const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleShell.tscn"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const EXPECTED_PANELS := {
	"overworld": {
		"scene": OVERWORLD_SCENE,
		"screenshot": "overworld.png",
		"panels": {
			"Shell": "res://art/ui/runtime/overworld/wood_panel.png",
			"TopStrip": "res://art/ui/runtime/overworld/resource_bar.png",
			"SidebarShell": "res://art/ui/runtime/overworld/sidebar_frame.png",
			"MapFrame": "res://art/ui/runtime/overworld/minimap_frame.png",
			"HeroPanel": "res://art/ui/runtime/overworld/hero_frame.png",
			"CommandPanel": "res://art/ui/runtime/overworld/wood_panel.png",
		},
		"buttons": {
			"PrimaryAction": "res://art/ui/runtime/shared/button_primary_normal.png",
			"EndTurn": "res://art/ui/runtime/shared/button_primary_normal.png",
			"Save": "res://art/ui/runtime/shared/button_secondary_normal.png",
		},
	},
	"battle": {
		"scene": BATTLE_SCENE,
		"screenshot": "battle.png",
		"panels": {
			"Banner": "res://art/ui/runtime/battle/initiative_bar.png",
			"BattlefieldFrame": "res://art/ui/runtime/battle/combat_log_panel.png",
			"SidebarShell": "res://art/ui/runtime/battle/unit_card.png",
			"InitiativePanel": "res://art/ui/runtime/battle/initiative_bar.png",
			"Footer": "res://art/ui/runtime/battle/battle_footer_panel.png",
			"SystemPanel": "res://art/ui/runtime/battle/combat_log_panel.png",
		},
		"buttons": {
			"Advance": "res://art/ui/runtime/shared/button_primary_normal.png",
			"Retreat": "res://art/ui/runtime/shared/button_primary_normal.png",
			"Surrender": "res://art/ui/runtime/shared/button_primary_normal.png",
		},
	},
	"town": {
		"scene": TOWN_SCENE,
		"screenshot": "town.png",
		"panels": {
			"Banner": "res://art/ui/runtime/town/banner_frame.png",
			"CrestFrame": "res://art/ui/runtime/town/crest_medallion.png",
			"TownStageFrame": "res://art/ui/runtime/town/recruit_row.png",
			"SidebarShell": "res://art/ui/runtime/town/parchment_panel.png",
			"BuildPanel": "res://art/ui/runtime/town/build_panel.png",
			"FooterPanel": "res://art/ui/runtime/town/banner_frame.png",
		},
		"buttons": {
			"Save": "res://art/ui/runtime/shared/button_primary_normal.png",
			"Leave": "res://art/ui/runtime/shared/button_primary_normal.png",
			"Menu": "res://art/ui/runtime/shared/button_primary_normal.png",
		},
	},
}

var _report := {
	"ok": false,
	"screenshots": [],
	"shells": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dir()
	_report["viewports"] = []
	for viewport_size in VIEWPORT_SIZES:
		var viewport_key := _viewport_key(viewport_size)
		var viewport_report := {
			"size": {"width": viewport_size.x, "height": viewport_size.y},
			"shells": {},
		}
		for shell_id in ["overworld", "battle", "town"]:
			var shell_report := await _run_shell(shell_id, EXPECTED_PANELS[shell_id], viewport_size)
			viewport_report["shells"][shell_id] = shell_report
			if not _report["shells"].has(shell_id):
				_report["shells"][shell_id] = {}
			_report["shells"][shell_id][viewport_key] = shell_report
		_report["viewports"].append(viewport_report)
	_report["ok"] = _report["errors"].is_empty()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	get_tree().quit(0 if bool(_report["ok"]) else 1)

func _run_shell(shell_id: String, spec: Dictionary, viewport_size: Vector2i) -> Dictionary:
	_prepare_session(shell_id)
	var render_viewport := SubViewport.new()
	render_viewport.name = "%sRenderViewport%s" % [shell_id.capitalize(), _viewport_key(viewport_size)]
	render_viewport.size = viewport_size
	render_viewport.disable_3d = true
	render_viewport.transparent_bg = false
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(render_viewport)

	var shell: Node = load(String(spec["scene"])).instantiate()
	render_viewport.add_child(shell)
	if shell is Control:
		var shell_control := shell as Control
		shell_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		shell_control.offset_left = 0.0
		shell_control.offset_top = 0.0
		shell_control.offset_right = 0.0
		shell_control.offset_bottom = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var shell_report := {
		"scene": spec["scene"],
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"panels": {},
		"buttons": {},
		"screenshot": "",
		"screenshot_size": {},
	}
	for panel_name in Dictionary(spec["panels"]).keys():
		var expected_path := String(spec["panels"][panel_name])
		var actual_path := _panel_texture_path(shell, String(panel_name))
		shell_report["panels"][panel_name] = {
			"expected": expected_path,
			"actual": actual_path,
			"ok": actual_path == expected_path,
		}
		if actual_path != expected_path:
			_error("%s panel %s expected %s but got %s" % [shell_id, panel_name, expected_path, actual_path])
	for button_name in Dictionary(spec.get("buttons", {})).keys():
		var expected_button_path := String(spec["buttons"][button_name])
		var actual_button_path := _button_texture_path(shell, String(button_name), "normal")
		shell_report["buttons"][button_name] = {
			"expected": expected_button_path,
			"actual": actual_button_path,
			"ok": actual_button_path == expected_button_path,
		}
		if actual_button_path != expected_button_path:
			_error("%s button %s expected %s but got %s" % [shell_id, button_name, expected_button_path, actual_button_path])

	var screenshot_name := "%s_%s" % [shell_id, _viewport_key(viewport_size)]
	var screenshot_path := "%s/%s.png" % [OUTPUT_DIR, screenshot_name]
	var screenshot_size := await _save_screenshot(render_viewport, screenshot_path)
	shell_report["screenshot"] = screenshot_path
	shell_report["screenshot_size"] = {"width": screenshot_size.x, "height": screenshot_size.y}
	_report["screenshots"].append(screenshot_path)
	if screenshot_size != viewport_size:
		_error("%s screenshot at %s expected %s but got %s" % [shell_id, _viewport_key(viewport_size), viewport_size, screenshot_size])

	render_viewport.queue_free()
	await get_tree().process_frame
	return shell_report

func _prepare_session(shell_id: String) -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	if shell_id == "town":
		var town := _first_player_town(session)
		if not town.is_empty():
			_move_active_hero_to_town(session, town)
	elif shell_id == "battle":
		var encounter := _first_encounter(session)
		if not encounter.is_empty():
			session.battle = BattleRules.create_battle_payload(session, encounter)
	SessionState.set_active_session(session)

func _panel_texture_path(shell: Node, panel_name: String) -> String:
	var panel := shell.find_child(panel_name, true, false)
	if panel == null:
		return "<missing panel>"
	if not panel is PanelContainer:
		return "<not panel>"
	var style := (panel as PanelContainer).get_theme_stylebox("panel")
	if not style is StyleBoxTexture:
		return "<not texture stylebox>"
	var texture := (style as StyleBoxTexture).texture
	if texture == null:
		return "<missing texture>"
	return texture.resource_path

func _button_texture_path(shell: Node, button_name: String, style_name: String) -> String:
	var button := shell.find_child(button_name, true, false)
	if button == null:
		return "<missing button>"
	if not button is BaseButton:
		return "<not button>"
	var style := (button as BaseButton).get_theme_stylebox(style_name)
	if not style is StyleBoxTexture:
		return "<not texture stylebox>"
	var texture := (style as StyleBoxTexture).texture
	if texture == null:
		return "<missing texture>"
	return texture.resource_path

func _save_screenshot(render_viewport: SubViewport, path: String) -> Vector2i:
	await RenderingServer.frame_post_draw
	var image := render_viewport.get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(path)
	var result := image.save_png(absolute_path)
	if result != OK:
		_error("Failed to save screenshot %s: %s" % [path, result])
	return Vector2i(image.get_width(), image.get_height())

func _viewport_key(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to write report %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _error(message: String) -> void:
	push_error(message)
	_report["errors"].append(message)
