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
	for viewport_size in _selected_viewport_sizes():
		var viewport_key := _viewport_key(viewport_size)
		var viewport_report := {
			"size": {"width": viewport_size.x, "height": viewport_size.y},
			"shells": {},
		}
		for shell_id in _selected_shell_ids():
			var shell_report := await _run_shell(shell_id, EXPECTED_PANELS[shell_id], viewport_size)
			viewport_report["shells"][shell_id] = shell_report
			if not _report["shells"].has(shell_id):
				_report["shells"][shell_id] = {}
			_report["shells"][shell_id][viewport_key] = shell_report
		_report["viewports"].append(viewport_report)
	_report["ok"] = _report["errors"].is_empty()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	get_tree().quit(0 if bool(_report["ok"]) else 1)

func _selected_viewport_sizes() -> Array:
	var viewport_index := OS.get_environment("UI_RUNTIME_VISUAL_VIEWPORT_INDEX").strip_edges()
	if viewport_index == "":
		return VIEWPORT_SIZES
	var index := int(viewport_index)
	if index < 0 or index >= VIEWPORT_SIZES.size():
		_error("UI_RUNTIME_VISUAL_VIEWPORT_INDEX is outside the supported range: %s" % viewport_index)
		return []
	return [VIEWPORT_SIZES[index]]

func _selected_shell_ids() -> Array:
	var shell_id := OS.get_environment("UI_RUNTIME_VISUAL_SHELL").strip_edges().to_lower()
	if shell_id == "":
		return ["overworld", "battle", "town"]
	if not EXPECTED_PANELS.has(shell_id):
		_error("UI_RUNTIME_VISUAL_SHELL is unsupported: %s" % shell_id)
		return []
	return [shell_id]

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
	if shell_id == "battle":
		var banner_contract := _battle_banner_contract(shell, viewport_size)
		shell_report["battle_banner"] = banner_contract
		if not bool(banner_contract.get("ok", false)):
			_error("Battle banner status containment failed at %s: %s" % [_viewport_key(viewport_size), banner_contract])
		var movement_range_contract := _battle_movement_range_contract(shell)
		shell_report["battle_movement_range"] = movement_range_contract
		if not bool(movement_range_contract.get("ok", false)):
			_error("Battle movement-range visual restraint failed at %s: %s" % [_viewport_key(viewport_size), movement_range_contract])
		var terrain_cohesion_contract := _battle_terrain_cohesion_contract(shell)
		shell_report["battle_terrain_cohesion"] = terrain_cohesion_contract
		if not bool(terrain_cohesion_contract.get("ok", false)):
			_error("Battle terrain cohesion failed at %s: %s" % [_viewport_key(viewport_size), terrain_cohesion_contract])
		var sidebar_contract := await _battle_sidebar_tactical_card_contract(shell, viewport_size)
		shell_report["battle_sidebar_tactical_card"] = sidebar_contract
		if not bool(sidebar_contract.get("ok", false)):
			_error("Battle sidebar tactical-card containment failed at %s: %s" % [_viewport_key(viewport_size), sidebar_contract])
	elif shell_id == "town":
		var management_contract := await _town_management_card_contract(shell, viewport_size)
		shell_report["town_management_card"] = management_contract
		if not bool(management_contract.get("ok", false)):
			_error("Town management-card containment failed at %s: %s" % [_viewport_key(viewport_size), management_contract])
	for panel_name in Dictionary(spec["panels"]).keys():
		var expected_path := _expected_panel_style(shell_id, String(panel_name), viewport_size, String(spec["panels"][panel_name]))
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

func _battle_banner_contract(shell: Node, viewport_size: Vector2i) -> Dictionary:
	var header := shell.get_node_or_null("%Header") as Label
	var status := shell.get_node_or_null("%Status") as Label
	var pressure := shell.get_node_or_null("%Pressure") as Label
	if header == null or status == null or pressure == null:
		return {"ok": false, "missing_authored_label": true}
	var top_bar := status.get_parent() as Control
	if top_bar == null:
		return {"ok": false, "missing_top_bar": true}
	var session = SessionState.active_session
	var expected_header := BattleRules.describe_header(session)
	var expected_status := BattleRules.describe_status(session)
	var expected_pressure := BattleRules.describe_pressure(session)
	var font := status.get_theme_font("font")
	var font_size := status.get_theme_font_size("font_size")
	var full_status_width := font.get_string_size(expected_status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x if font != null else 0.0
	var top_rect := top_bar.get_global_rect()
	var header_rect := header.get_global_rect()
	var status_rect := status.get_global_rect()
	var pressure_rect := pressure.get_global_rect()
	var status_overflow := full_status_width > status_rect.size.x + 0.5
	var width_fit_exact := status_overflow if viewport_size.x == 1280 else (not status_overflow if viewport_size.x >= 1920 else true)
	var ok := header.is_visible_in_tree() \
		and status.is_visible_in_tree() \
		and pressure.is_visible_in_tree() \
		and header.text == expected_header \
		and status.text == expected_status \
		and status.tooltip_text == expected_status \
		and pressure.tooltip_text == expected_pressure \
		and status.clip_text \
		and pressure.clip_text \
		and status.text_overrun_behavior == TextServer.OVERRUN_TRIM_WORD_ELLIPSIS \
		and top_rect.encloses(header_rect) \
		and top_rect.encloses(status_rect) \
		and top_rect.encloses(pressure_rect) \
		and header_rect.end.x <= status_rect.position.x + 0.5 \
		and status_rect.end.x <= pressure_rect.position.x + 0.5 \
		and not header_rect.intersects(status_rect) \
		and not status_rect.intersects(pressure_rect) \
		and width_fit_exact
	return {
		"ok": ok,
		"expected_header": expected_header,
		"expected_status": expected_status,
		"expected_pressure": expected_pressure,
		"header_visible": header.is_visible_in_tree(),
		"status_visible": status.is_visible_in_tree(),
		"pressure_visible": pressure.is_visible_in_tree(),
		"status_overflow": status_overflow,
		"full_status_width": full_status_width,
		"top_rect": top_rect,
		"header_rect": header_rect,
		"status_rect": status_rect,
		"pressure_rect": pressure_rect,
	}

func _battle_movement_range_contract(shell: Node) -> Dictionary:
	var board = shell.get_node_or_null("%BattleBoard")
	if board == null or not board.has_method("validation_hex_layout_summary"):
		return {"ok": false, "missing_board_summary": true}
	var summary: Dictionary = board.call("validation_hex_layout_summary")
	var legal_destination_count := int(summary.get("legal_destination_count", -1))
	var ok := legal_destination_count > 0 \
		and int(summary.get("movement_range_cell_count", -2)) == legal_destination_count \
		and String(summary.get("movement_range_visual_model", "")) == "alternating_edge_ticks_center_pip_near_transparent_fill" \
		and is_equal_approx(float(summary.get("movement_range_fill_radius_factor", 0.0)), 0.66) \
		and is_equal_approx(float(summary.get("movement_range_fill_alpha", 0.0)), 0.020) \
		and is_equal_approx(float(summary.get("movement_range_tick_radius_factor", 0.0)), 0.74) \
		and is_equal_approx(float(summary.get("movement_range_tick_segment_factor", 0.0)), 0.36) \
		and is_equal_approx(float(summary.get("movement_range_tick_alpha", 0.0)), 0.58) \
		and is_equal_approx(float(summary.get("movement_range_tick_width", 0.0)), 1.4) \
		and int(summary.get("movement_range_tick_edge_count", 0)) == 3 \
		and is_equal_approx(float(summary.get("movement_range_pip_radius_factor", 0.0)), 0.045) \
		and is_equal_approx(float(summary.get("movement_range_pip_alpha", 0.0)), 0.52) \
		and not bool(summary.get("movement_range_complete_outline", true)) \
		and bool(summary.get("movement_range_all_legal_cells_drawn", false)) \
		and not bool(summary.get("movement_range_hover_only", true)) \
		and bool(summary.get("movement_range_below_active_targets_and_stacks", false)) \
		and String(summary.get("movement_range_action_authority", "")) == "legal_destinations_for_active_stack"
	return {
		"ok": ok,
		"legal_destination_count": legal_destination_count,
		"movement_range_cell_count": summary.get("movement_range_cell_count", -1),
		"visual_model": summary.get("movement_range_visual_model", ""),
		"fill_radius_factor": summary.get("movement_range_fill_radius_factor", 0.0),
		"fill_alpha": summary.get("movement_range_fill_alpha", 0.0),
		"tick_radius_factor": summary.get("movement_range_tick_radius_factor", 0.0),
		"tick_segment_factor": summary.get("movement_range_tick_segment_factor", 0.0),
		"tick_alpha": summary.get("movement_range_tick_alpha", 0.0),
		"tick_width": summary.get("movement_range_tick_width", 0.0),
		"tick_edge_count": summary.get("movement_range_tick_edge_count", 0),
		"pip_radius_factor": summary.get("movement_range_pip_radius_factor", 0.0),
		"pip_alpha": summary.get("movement_range_pip_alpha", 0.0),
		"complete_outline": summary.get("movement_range_complete_outline", true),
		"all_legal_cells_drawn": summary.get("movement_range_all_legal_cells_drawn", false),
		"hover_only": summary.get("movement_range_hover_only", true),
		"below_active_targets_and_stacks": summary.get("movement_range_below_active_targets_and_stacks", false),
	}

func _battle_terrain_cohesion_contract(shell: Node) -> Dictionary:
	var board = shell.get_node_or_null("%BattleBoard")
	if board == null \
		or not board.has_method("validation_hex_layout_summary") \
		or not board.has_method("validation_terrain_rendering_summary"):
		return {"ok": false, "missing_board_terrain_summary": true}
	var session = SessionState.active_session
	var authority_before: Dictionary = session.to_dict()
	var hex_summary: Dictionary = board.call("validation_hex_layout_summary")
	var terrain_summary: Dictionary = board.call("validation_terrain_rendering_summary")
	var context_alpha := float(terrain_summary.get("terrain_context_texture_modulate_alpha", 0.0))
	var variation_alpha := float(terrain_summary.get("texture_modulate_alpha", 0.0))
	var ok := bool(terrain_summary.get("texture_loaded", false)) \
		and String(terrain_summary.get("rendering_mode", "")) == "continuous_field_with_hex_variation" \
		and String(terrain_summary.get("texture_sample_mode", "")) == "continuous_field_plus_subordinate_per_hex_variation" \
		and String(terrain_summary.get("terrain_context_model", "")) == "continuous_primary_field_with_subordinate_hex_variation" \
		and bool(terrain_summary.get("single_board_backdrop", false)) \
		and bool(terrain_summary.get("hex_snapped", false)) \
		and bool(terrain_summary.get("terrain_context_covers_full_field", false)) \
		and bool(terrain_summary.get("terrain_context_preserves_hex_authority", false)) \
		and bool(terrain_summary.get("terrain_context_primary", false)) \
		and bool(terrain_summary.get("terrain_hex_variation_subordinate", false)) \
		and is_equal_approx(context_alpha, 0.92) \
		and is_equal_approx(variation_alpha, 0.24) \
		and context_alpha > variation_alpha \
		and int(terrain_summary.get("hex_tile_count", 0)) == 77 \
		and int(terrain_summary.get("texture_source_sample_count", 0)) == 77 \
		and int(hex_summary.get("hex_count", 0)) == 77 \
		and bool(terrain_summary.get("texture_uv_within_0_1", false)) \
		and bool(terrain_summary.get("texture_source_within_texture", false)) \
		and bool(terrain_summary.get("texture_visible", false)) \
		and session.to_dict() == authority_before
	return {
		"ok": ok,
		"rendering_mode": terrain_summary.get("rendering_mode", ""),
		"texture_sample_mode": terrain_summary.get("texture_sample_mode", ""),
		"terrain_context_model": terrain_summary.get("terrain_context_model", ""),
		"context_alpha": context_alpha,
		"variation_alpha": variation_alpha,
		"hex_tile_count": terrain_summary.get("hex_tile_count", 0),
		"texture_source_sample_count": terrain_summary.get("texture_source_sample_count", 0),
		"texture_id": terrain_summary.get("texture_id", ""),
		"texture_path": terrain_summary.get("texture_path", ""),
		"authority_exact": session.to_dict() == authority_before,
	}

func _battle_sidebar_tactical_card_contract(shell: Node, viewport_size: Vector2i) -> Dictionary:
	var sidebar_shell := shell.get_node_or_null("%SidebarShell") as PanelContainer
	var command_panel := shell.get_node_or_null("%CommandPanel") as PanelContainer
	var tabs := shell.get_node_or_null("%BattleTabs") as TabContainer
	var panels: Array[Control] = [
		shell.get_node_or_null("%InitiativePanel") as Control,
		shell.get_node_or_null("%ContextPanel") as Control,
		shell.get_node_or_null("%SpellPanel") as Control,
		shell.get_node_or_null("%TimingPanel") as Control,
	]
	if sidebar_shell == null or command_panel == null or tabs == null or panels.any(func(panel): return panel == null):
		return {"ok": false, "missing_authored_control": true}
	var session = SessionState.active_session
	var authority_before: Dictionary = session.to_dict()
	var original_tab := tabs.current_tab
	var expected_titles := ["Order", "Focus", "Spell", "Timing"]
	var tab_plaque_contract := _shared_tab_plaque_contract(tabs, expected_titles, 1.0)
	var titles: Array[String] = []
	var heights: Array[float] = []
	var pages_contained := true
	for index in range(panels.size()):
		tabs.current_tab = index
		await get_tree().process_frame
		await get_tree().process_frame
		titles.append(tabs.get_tab_title(index))
		heights.append(tabs.size.y)
		pages_contained = pages_contained and tabs.get_global_rect().encloses(panels[index].get_global_rect())
	var sidebar_rect := sidebar_shell.get_global_rect()
	var command_rect := command_panel.get_global_rect()
	var tabs_rect := tabs.get_global_rect()
	var compact := viewport_size.x < 1360 or viewport_size.y < 760
	var remaining_rail_gutter := sidebar_rect.end.y - tabs_rect.end.y
	var authored_height_exact := is_equal_approx(tabs.custom_minimum_size.y, 248.0) \
		and tabs.size_flags_vertical == Control.SIZE_FILL
	var wide_geometry_exact := sidebar_shell.is_visible_in_tree() \
		and heights.all(func(height): return is_equal_approx(height, 248.0)) \
		and sidebar_rect.encloses(command_rect) \
		and sidebar_rect.encloses(tabs_rect) \
		and command_rect.end.y <= tabs_rect.position.y + 0.01 \
		and not command_rect.intersects(tabs_rect) \
		and pages_contained \
		and remaining_rail_gutter >= 80.0
	var compact_geometry_exact := not sidebar_shell.is_visible_in_tree()
	tabs.current_tab = original_tab
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_exact := session.to_dict() == authority_before
	var ok := authored_height_exact \
		and titles == expected_titles \
		and bool(tab_plaque_contract.get("ok", false)) \
		and authority_exact \
		and (compact_geometry_exact if compact else wide_geometry_exact)
	return {
		"ok": ok,
		"compact": compact,
		"authored_height_exact": authored_height_exact,
		"titles": titles,
		"tab_plaques": tab_plaque_contract,
		"heights": heights,
		"sidebar_visible": sidebar_shell.is_visible_in_tree(),
		"sidebar_rect": sidebar_rect,
		"command_rect": command_rect,
		"tabs_rect": tabs_rect,
		"pages_contained": pages_contained,
		"remaining_rail_gutter": remaining_rail_gutter,
		"authority_exact": authority_exact,
	}

func _town_management_card_contract(shell: Node, viewport_size: Vector2i) -> Dictionary:
	var sidebar_shell := shell.get_node_or_null("%SidebarShell") as PanelContainer
	var command_panel := shell.get_node_or_null("%CommandPanel") as PanelContainer
	var tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
	var sidebar_box := tabs.get_parent() as VBoxContainer if tabs != null else null
	var rows := [
		{"title": "Build", "page": shell.get_node_or_null("%BuildPanel"), "controls": [shell.get_node_or_null("%Buildings"), shell.get_node_or_null("%BuildActions"), shell.get_node_or_null("%BuildPlan"), shell.get_node_or_null("%ConfirmBuild")]},
		{"title": "Muster", "page": shell.get_node_or_null("%RecruitPanel"), "controls": [shell.get_node_or_null("%Recruitment"), shell.get_node_or_null("%RecruitActions")]},
		{"title": "Spells", "page": shell.get_node_or_null("%StudyPanel"), "controls": [shell.get_node_or_null("%StudyScroll")]},
		{"title": "Trade", "page": shell.get_node_or_null("%MarketPanel"), "controls": [shell.get_node_or_null("%Market"), shell.get_node_or_null("%MarketActions")]},
		{"title": "Log", "page": shell.get_node_or_null("%LogisticsPanel"), "controls": [shell.get_node_or_null("%LogisticsScroll")]},
	]
	if sidebar_shell == null or command_panel == null or tabs == null or sidebar_box == null:
		return {"ok": false, "missing_authored_control": true}
	for row_value in rows:
		var row: Dictionary = row_value
		if not (row.get("page") is Control) or Array(row.get("controls", [])).any(func(control): return not (control is Control)):
			return {"ok": false, "missing_page_control": row.get("title", "")}
	var session = SessionState.active_session
	var authority_before: Dictionary = session.to_dict()
	var original_tab := tabs.current_tab
	var expected_titles := ["Build", "Muster", "Spells", "Trade", "Log"]
	var tab_plaque_contract := _shared_tab_plaque_contract(tabs, expected_titles, 4.0)
	var tab_bar := tabs.get_tab_bar()
	var first_tab_rect := tab_bar.get_tab_rect(0) if tab_bar != null else Rect2()
	var last_tab_rect := tab_bar.get_tab_rect(tabs.get_tab_count() - 1) if tab_bar != null else Rect2()
	var tab_group_centered := tab_bar != null \
		and tabs.tab_alignment == HORIZONTAL_ALIGNMENT_CENTER \
		and absf(first_tab_rect.position.x - (tab_bar.size.x - last_tab_rect.end.x)) <= 1.0
	var titles: Array[String] = []
	var heights: Array[float] = []
	var pages_contained := true
	var controls_contained := true
	var overflow_controls: Array[Dictionary] = []
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		tabs.current_tab = index
		await get_tree().process_frame
		await get_tree().process_frame
		var page: Control = row.get("page")
		titles.append(tabs.get_tab_title(index))
		heights.append(tabs.size.y)
		pages_contained = pages_contained and tabs.get_global_rect().encloses(page.get_global_rect())
		for control_value in Array(row.get("controls", [])):
			var control: Control = control_value
			if control.is_visible_in_tree() and not page.get_global_rect().encloses(control.get_global_rect()):
				controls_contained = false
				overflow_controls.append({"tab": row.get("title", ""), "control": control.name, "page_rect": page.get_global_rect(), "control_rect": control.get_global_rect()})
	var logistics_scroll: ScrollContainer = shell.get_node("%LogisticsScroll")
	var artifacts: Control = shell.get_node("%Artifacts")
	var response_actions: Control = shell.get_node("%ResponseActions")
	var logistics_scroll_rect := logistics_scroll.get_global_rect()
	var logistics_top_reachable := logistics_scroll_rect.encloses(artifacts.get_global_rect())
	var logistics_scroll_required := logistics_scroll.get_v_scroll_bar().max_value > logistics_scroll.get_v_scroll_bar().page + 0.01
	logistics_scroll.scroll_vertical = int(logistics_scroll.get_v_scroll_bar().max_value)
	await get_tree().process_frame
	await get_tree().process_frame
	var logistics_end_reachable := logistics_scroll.get_global_rect().encloses(response_actions.get_global_rect())
	logistics_scroll.scroll_vertical = 0
	await get_tree().process_frame
	var sidebar_rect := sidebar_shell.get_global_rect()
	var sidebar_box_rect := sidebar_box.get_global_rect()
	var command_rect := command_panel.get_global_rect()
	var tabs_rect := tabs.get_global_rect()
	var compact := viewport_size.x < 1360 or viewport_size.y < 760
	var remaining_rail_gutter := sidebar_box_rect.end.y - tabs_rect.end.y
	var authored_height_exact := is_equal_approx(tabs.custom_minimum_size.y, 460.0) \
		and tabs.size_flags_vertical == Control.SIZE_EXPAND_FILL
	var geometry_exact := heights.all(func(height): return height + 0.01 >= 460.0) \
		and sidebar_box_rect.encloses(tabs_rect) \
		and absf(remaining_rail_gutter) <= 1.0 \
		and (viewport_size.y < 1080 or tabs_rect.size.y >= 600.0) \
		and pages_contained \
		and controls_contained \
		and logistics_top_reachable \
		and logistics_scroll_required \
		and logistics_end_reachable \
		and ((not command_panel.is_visible_in_tree()) if compact else (sidebar_box_rect.encloses(command_rect) and command_rect.end.y <= tabs_rect.position.y + 0.01 and not command_rect.intersects(tabs_rect)))
	tabs.current_tab = original_tab
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_exact := session.to_dict() == authority_before
	return {
		"ok": authored_height_exact and geometry_exact and titles == expected_titles and bool(tab_plaque_contract.get("ok", false)) and tab_group_centered and authority_exact,
		"compact": compact,
		"authored_height_exact": authored_height_exact,
		"titles": titles,
		"tab_plaques": tab_plaque_contract,
		"tab_group_centered": tab_group_centered,
		"heights": heights,
		"sidebar_rect": sidebar_rect,
		"sidebar_box_rect": sidebar_box_rect,
		"command_rect": command_rect,
		"tabs_rect": tabs_rect,
		"command_visible": command_panel.is_visible_in_tree(),
		"pages_contained": pages_contained,
		"controls_contained": controls_contained,
		"overflow_controls": overflow_controls,
		"logistics_top_reachable": logistics_top_reachable,
		"logistics_scroll_required": logistics_scroll_required,
		"logistics_end_reachable": logistics_end_reachable,
		"remaining_rail_gutter": remaining_rail_gutter,
		"authority_exact": authority_exact,
	}

func _shared_tab_plaque_contract(tabs: TabContainer, expected_titles: Array, expected_horizontal_content_margin: float) -> Dictionary:
	var current_tab_before := tabs.current_tab
	var tab_bar := tabs.get_tab_bar()
	if tab_bar == null or tabs.get_tab_count() != expected_titles.size():
		return {"ok": false, "missing_tab_bar": tab_bar == null, "tab_count": tabs.get_tab_count()}
	var font := tab_bar.get_theme_font("font")
	var font_size := tab_bar.get_theme_font_size("font_size")
	var titles: Array[String] = []
	var rects: Array[Rect2] = []
	var live_fit_required := tabs.is_visible_in_tree()
	var contained := true
	var ordered_without_overlap := true
	var text_safe_insets := font != null and font_size > 0
	for index in range(tabs.get_tab_count()):
		var title := tabs.get_tab_title(index)
		titles.append(title)
		var tab_rect: Rect2 = tab_bar.get_tab_rect(index)
		rects.append(tab_rect)
		contained = contained \
			and tab_rect.size.x > 0.0 \
			and tab_rect.size.y > 0.0 \
			and tab_rect.position.x >= -0.5 \
			and tab_rect.position.y >= -0.5 \
			and tab_rect.end.x <= tab_bar.size.x + 0.5 \
			and tab_rect.end.y <= tab_bar.size.y + 0.5
		if font != null and font_size > 0:
			var text_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			text_safe_insets = text_safe_insets and tab_rect.size.x + 0.5 >= text_width + expected_horizontal_content_margin * 2.0
		if index > 0:
			ordered_without_overlap = ordered_without_overlap and rects[index - 1].end.x <= tab_rect.position.x + 0.5
	var expected_paths := {
		"tab_selected": "res://art/ui/runtime/shared/button_primary_pressed.png",
		"tab_hovered": "res://art/ui/runtime/shared/button_secondary_hover.png",
		"tab_unselected": "res://art/ui/runtime/shared/button_secondary_normal.png",
		"tab_disabled": "res://art/ui/runtime/shared/button_secondary_disabled.png",
	}
	var style_paths := {}
	var styles_exact := true
	for style_name_value in expected_paths:
		var style_name := String(style_name_value)
		var style := tabs.get_theme_stylebox(style_name)
		if not (style is StyleBoxTexture):
			styles_exact = false
			style_paths[style_name] = "<not texture stylebox>"
			continue
		var texture_style := style as StyleBoxTexture
		var texture := texture_style.texture
		var texture_path := texture.resource_path if texture != null else ""
		style_paths[style_name] = texture_path
		styles_exact = styles_exact \
			and texture_path == String(expected_paths[style_name]) \
			and is_equal_approx(texture_style.texture_margin_left, 6.0) \
			and is_equal_approx(texture_style.texture_margin_top, 6.0) \
			and is_equal_approx(texture_style.texture_margin_right, 6.0) \
			and is_equal_approx(texture_style.texture_margin_bottom, 6.0) \
			and is_equal_approx(texture_style.content_margin_left, expected_horizontal_content_margin) \
			and is_equal_approx(texture_style.content_margin_top, 2.0) \
			and is_equal_approx(texture_style.content_margin_right, expected_horizontal_content_margin) \
			and is_equal_approx(texture_style.content_margin_bottom, 2.0)
		if style_name == "tab_disabled":
			styles_exact = styles_exact and texture_style.modulate_color.is_equal_approx(Color(0.72, 0.72, 0.72, 0.76))
	var focus := tabs.get_theme_stylebox("tab_focus")
	var focus_exact := focus is StyleBoxFlat
	if focus_exact:
		var focus_flat := focus as StyleBoxFlat
		focus_exact = focus_flat.bg_color.a <= 0.001 \
			and focus_flat.border_color.is_equal_approx(Color(0.97, 0.88, 0.61, 1.0)) \
			and focus_flat.border_width_left == 2 \
			and focus_flat.border_width_top == 2 \
			and focus_flat.border_width_right == 2 \
			and focus_flat.border_width_bottom == 2 \
			and focus_flat.corner_radius_top_left == 6 \
			and focus_flat.corner_radius_top_right == 6 \
			and focus_flat.corner_radius_bottom_left == 6 \
			and focus_flat.corner_radius_bottom_right == 6
	return {
		"ok": titles == expected_titles \
			and styles_exact \
			and focus_exact \
			and text_safe_insets \
			and (not live_fit_required or (contained and ordered_without_overlap)) \
			and tabs.current_tab == current_tab_before,
		"titles": titles,
		"style_paths": style_paths,
		"focus_exact": focus_exact,
		"tab_rects": rects,
		"live_fit_required": live_fit_required,
		"contained": contained,
		"ordered_without_overlap": ordered_without_overlap,
		"text_safe_insets": text_safe_insets,
		"horizontal_content_margin": expected_horizontal_content_margin,
		"tab_bar_size": tab_bar.size,
		"current_tab_unchanged": tabs.current_tab == current_tab_before,
	}

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
	if style is StyleBoxEmpty:
		return "<empty stylebox>"
	if not style is StyleBoxTexture:
		return "<not texture stylebox>"
	var texture := (style as StyleBoxTexture).texture
	if texture == null:
		return "<missing texture>"
	return texture.resource_path

func _expected_panel_style(shell_id: String, panel_name: String, viewport_size: Vector2i, authored_path: String) -> String:
	if shell_id == "battle" and panel_name == "SystemPanel" and (viewport_size.x < 1360 or viewport_size.y < 760):
		return "<empty stylebox>"
	return authored_path

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
