extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")
const SystemSaveWrittenCuePresenterScript = preload("res://scenes/shared/SystemSaveWrittenCuePresenter.gd")
const SystemLoadResumedCuePresenterScript = preload("res://scenes/shared/SystemLoadResumedCuePresenter.gd")

const UI_ART_TOWN_BANNER_FRAME := "res://art/ui/runtime/town/banner_frame.png"
const UI_ART_TOWN_CREST_MEDALLION := "res://art/ui/runtime/town/crest_medallion.png"
const UI_ART_TOWN_PARCHMENT_PANEL := "res://art/ui/runtime/town/parchment_panel.png"
const UI_ART_TOWN_RECRUIT_ROW := "res://art/ui/runtime/town/recruit_row.png"
const UI_ART_TOWN_RESOURCE_LEDGER := "res://art/ui/runtime/town/resource_ledger.png"
const UI_ART_TOWN_BUILD_PANEL := "res://art/ui/runtime/town/build_panel.png"
const TOWN_COMPACT_MANAGEMENT_RAIL_WIDTH := 304.0
const TOWN_WIDE_MANAGEMENT_RAIL_WIDTH := 400.0
const TOWN_MANAGEMENT_TAB_CONTENT_MARGIN_HORIZONTAL := 4.0
const TOWN_MANAGEMENT_TAB_STATE_STYLES := [
	&"tab_selected",
	&"tab_hovered",
	&"tab_unselected",
	&"tab_disabled",
]
const RETURN_TO_MENU_FAILURE_MESSAGE := "Save failed. The expedition remains open; use Save, then try Return to Main Menu again."

@onready var _banner_panel: PanelContainer = %Banner
@onready var _crest_panel: PanelContainer = %CrestFrame
@onready var _town_stage_panel: PanelContainer = %TownStagePanel
@onready var _town_stage_frame_panel: PanelContainer = %TownStageFrame
@onready var _stage_column: VBoxContainer = %StageColumn
@onready var _town_panel: PanelContainer = %TownPanel
@onready var _outlook_panel: PanelContainer = %OutlookPanel
@onready var _command_ledger_panel: PanelContainer = %CommandLedgerPanel
@onready var _sidebar_shell_panel: PanelContainer = %SidebarShell
@onready var _command_panel: PanelContainer = %CommandPanel
@onready var _management_tabs: TabContainer = %ManagementTabs
@onready var _build_panel: PanelContainer = %BuildPanel
@onready var _recruit_panel: PanelContainer = %RecruitPanel
@onready var _study_panel: PanelContainer = %StudyPanel
@onready var _market_panel: PanelContainer = %MarketPanel
@onready var _logistics_panel: PanelContainer = %LogisticsPanel
@onready var _footer_panel: PanelContainer = %FooterPanel
@onready var _crest_glyph = %CrestGlyph
@onready var _crest_icon: TextureRect = %CrestIcon
@onready var _build_faction_watermark: TextureRect = %BuildFactionWatermark
@onready var _crest_label: Label = %CrestLabel
@onready var _header_label: Label = %Header
@onready var _status_label: Label = %Status
@onready var _resource_chip_panel: PanelContainer = %ResourceChip
@onready var _resource_label: ResourceStockpileMenu = %Resources
@onready var _event_label: Label = %Event
@onready var _town_stage_view = %TownStage
@onready var _outlook_label: Label = %Outlook
@onready var _command_ledger_label: Label = %CommandLedger
@onready var _hero_portrait: HeroPortraitView = %HeroPortrait
@onready var _hero_label: Label = %Hero
@onready var _production_overview_label: Label = %ProductionOverview
@onready var _heroes_label: Label = %Heroes
@onready var _specialty_label: Label = %Specialties
@onready var _hero_actions: Container = %HeroActions
@onready var _specialty_actions: Container = %SpecialtyActions
@onready var _army_label: Label = %Army
@onready var _army_management: ArmyStackBar = %ArmyManagement
@onready var _town_label: Label = %TownSummary
@onready var _defense_label: Label = %Defense
@onready var _pressure_label: Label = %Pressure
@onready var _building_label: Label = %Buildings
@onready var _build_actions: Container = %BuildActions
@onready var _build_plan_label: Label = %BuildPlan
@onready var _confirm_build_button: Button = %ConfirmBuild
@onready var _open_build_catalog_button: Button = %OpenBuildCatalog
@onready var _market_label: Label = %Market
@onready var _market_actions: Container = %MarketActions
@onready var _recruit_label: Label = %Recruitment
@onready var _recruit_actions: Container = %RecruitActions
@onready var _open_muster_catalog_button: Button = %OpenMusterCatalog
@onready var _study_label: Label = %Study
@onready var _study_actions: Container = %StudyActions
@onready var _spellbook_label: Label = %Spellbook
@onready var _tavern_label: Label = %Tavern
@onready var _tavern_actions: Container = %TavernActions
@onready var _transfer_label: Label = %Transfer
@onready var _transfer_actions: Container = %TransferActions
@onready var _response_label: Label = %Responses
@onready var _response_actions: Container = %ResponseActions
@onready var _artifact_label: Label = %Artifacts
@onready var _artifact_actions: Container = %ArtifactActions
@onready var _save_status_label: Label = %SaveStatus
@onready var _town_orders_toggle_button: Button = %TownOrdersToggle
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _leave_button: Button = %Leave
@onready var _guide_button: Button = %Guide
@onready var _settings_button: Button = %Settings
@onready var _menu_button: Button = %Menu
@onready var _town_catalog_overlay: Control = %TownCatalogOverlay
@onready var _town_catalog_panel: PanelContainer = %TownCatalogPanel
@onready var _town_catalog_title_label: Label = %TownCatalogTitle
@onready var _town_catalog_subtitle_label: Label = %TownCatalogSubtitle
@onready var _town_catalog_scroll: ScrollContainer = %TownCatalogScroll
@onready var _town_catalog_close_button: Button = %TownCatalogClose
@onready var _guide_overlay: Control = %TownGuideOverlay
@onready var _guide_panel: PanelContainer = %TownGuidePanel
@onready var _guide_title_label: Label = %TownGuideTitle
@onready var _guide_label: Label = %TownGuideText
@onready var _guide_close_button: Button = %TownGuideClose
@onready var _town_action_input_blocker: Control = %TownActionInputBlocker
@onready var _manual_save_overwrite_dialog = $ManualSaveOverwriteDialog
@onready var _active_play_settings_dialog = %ActivePlaySettingsDialog

var _session: SessionStateStore.SessionData
var _last_message := ""
var _last_return_to_menu_result: Dictionary = {}
var _validation_return_to_menu_request_count := 0
var _last_action_recap := {}
var _last_town_entity_cache_result := {}
var _last_economy_readability_surface := {}
var _last_rendered_build_actions := []
var _last_rendered_recruit_actions := []
var _last_save_surface_profile := {}
var _last_refresh_minimal := false
var _last_town_stage_signature := ""
var _last_departure_confirmation := {}
var _selected_build_action_id := ""
var _town_catalog_mode := ""
var _town_catalog_previous_focus: Control
var _narrow_layout_active := false
var _narrow_orders_open := false
var _last_management_tab_index := 0
var _validation_management_tab_change_sequence := 0
var _validation_management_tab_change_count := 0
var _validation_management_tab_focus_handoff_count := 0
var _validation_management_tab_boundary_retain_count := 0
var _last_management_tab_change_result: Dictionary = {}
var _unit_art_textures: Dictionary = {}
var _unit_art_texture_missing: Dictionary = {}
var _save_written_cue_presenter: SystemSaveWrittenCuePresenter
var _load_resumed_cue_presenter: SystemLoadResumedCuePresenter

static var _town_entity_cache_by_session: Dictionary = {}

func _ready() -> void:
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var phase_started := ProfileLogScript.begin_usec()
	_apply_visual_theme()
	_save_written_cue_presenter = SystemSaveWrittenCuePresenterScript.new()
	_save_written_cue_presenter.name = "SystemSaveWrittenCuePresenter"
	add_child(_save_written_cue_presenter)
	_save_written_cue_presenter.configure(_save_button, _save_status_label, "town")
	_load_resumed_cue_presenter = SystemLoadResumedCuePresenterScript.new()
	_load_resumed_cue_presenter.name = "SystemLoadResumedCuePresenter"
	add_child(_load_resumed_cue_presenter)
	_load_resumed_cue_presenter.configure(_save_status_label, _save_button, "town")
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	buckets["theme"] = ProfileLogScript.elapsed_ms(phase_started)
	_management_tabs.current_tab = 0
	_last_management_tab_index = _management_tabs.current_tab
	_configure_management_tab_accessibility()
	_configure_town_guide_surface()
	_town_action_input_blocker.visible = false
	_town_catalog_overlay.visible = false
	if not _town_stage_view.town_action_presentation_blocking_changed.is_connected(_on_town_action_presentation_blocking_changed):
		_town_stage_view.town_action_presentation_blocking_changed.connect(_on_town_action_presentation_blocking_changed)
	_confirm_build_button.pressed.connect(_on_confirm_build_pressed)
	if not _management_tabs.tab_changed.is_connected(_on_management_tab_changed):
		_management_tabs.tab_changed.connect(_on_management_tab_changed)
	if not _army_management.operation_requested.is_connected(_on_army_slot_operation_requested):
		_army_management.operation_requested.connect(_on_army_slot_operation_requested)
	_session = SessionState.ensure_active_session()
	if _session.scenario_id == "":
		push_warning("Cannot enter a town without an active scenario session.")
		AppRouter.go_to_main_menu()
		return

	phase_started = ProfileLogScript.begin_usec()
	OverworldRules.normalize_overworld_state_for_runtime(_session)
	buckets["normalize_overworld"] = ProfileLogScript.elapsed_ms(phase_started)
	if _session.scenario_status != "in_progress":
		AppRouter.go_to_scenario_outcome()
		return
	if not TownRules.can_visit_active_town(_session):
		AppRouter.go_to_overworld()
		return
	_session.game_state = "town"
	phase_started = ProfileLogScript.begin_usec()
	_configure_save_slot_picker()
	buckets["configure_save_surface"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	MusicAudio.sync_context("town", "town_shell_ready", _town_music_metadata())
	buckets["music_audio"] = ProfileLogScript.elapsed_ms(phase_started)
	phase_started = ProfileLogScript.begin_usec()
	_refresh(true)
	_present_load_resumed_cue()
	buckets["first_refresh"] = ProfileLogScript.elapsed_ms(phase_started)
	ProfileLogScript.emit_general("town", "entry", "town_ready", ProfileLogScript.elapsed_ms(profile_started), buckets, _town_profile_metadata(true), _session)
	call_deferred("_configure_town_keyboard_focus", true)

func _town_music_metadata() -> Dictionary:
	if _session == null:
		return {}
	var town := TownRules.get_active_town(_session)
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	return {
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"day": _session.day,
		"town_placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"town_faction_id": String(town_template.get("faction_id", "")),
	}

func _apply_responsive_layout() -> void:
	if _sidebar_shell_panel == null:
		return
	var available_size := get_viewport_rect().size
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		available_size = parent_control.size
	var compact_layout := available_size.x < 1360.0 or available_size.y < 760.0
	var narrow_layout := available_size.x < 1100.0
	_header_label.clip_text = compact_layout
	_resource_chip_panel.custom_minimum_size.x = 96.0 if compact_layout else 226.0
	_resource_label.custom_minimum_size.x = 80.0 if compact_layout else 210.0
	_resource_label.set_compact_mode(compact_layout)
	_narrow_layout_active = narrow_layout
	if not narrow_layout:
		_narrow_orders_open = false
	_stage_column.visible = not narrow_layout or not _narrow_orders_open
	_sidebar_shell_panel.visible = not narrow_layout or _narrow_orders_open
	_sidebar_shell_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow_layout and _narrow_orders_open else Control.SIZE_FILL
	_sidebar_shell_panel.custom_minimum_size.x = TOWN_COMPACT_MANAGEMENT_RAIL_WIDTH if compact_layout else TOWN_WIDE_MANAGEMENT_RAIL_WIDTH
	_town_orders_toggle_button.visible = narrow_layout
	_town_orders_toggle_button.text = "View Town" if _narrow_orders_open else "Town Orders"
	_town_orders_toggle_button.tooltip_text = "Return to the scenic town view." if _narrow_orders_open else "Open construction, muster, spells, trade, and town-log orders."
	_command_panel.visible = not compact_layout
	_event_label.visible = not compact_layout
	_status_label.visible = not compact_layout
	_building_label.visible = not compact_layout
	_town_stage_view.custom_minimum_size = Vector2(520.0, 280.0) if compact_layout else Vector2(620.0, 320.0)
	if _town_catalog_panel != null:
		_town_catalog_panel.custom_minimum_size = Vector2(
			min(1080.0, max(620.0, available_size.x - 44.0)),
			min(690.0, max(480.0, available_size.y - 44.0))
		)
	var catalog_columns := 2 if available_size.x < 900.0 else (3 if available_size.x < 1320.0 else 4)
	if _build_actions is GridContainer:
		(_build_actions as GridContainer).columns = catalog_columns
	if _recruit_actions is GridContainer:
		(_recruit_actions as GridContainer).columns = catalog_columns

func _on_open_build_catalog_pressed() -> void:
	_open_town_catalog("build")

func _on_open_muster_catalog_pressed() -> void:
	_open_town_catalog("muster")

func _on_town_catalog_close_pressed() -> void:
	_close_town_catalog()

func _town_catalog_is_open() -> bool:
	return _town_catalog_overlay != null and _town_catalog_overlay.visible

func _open_town_catalog(mode: String) -> void:
	if mode not in ["build", "muster"] or _session == null:
		return
	if _town_action_input_blocker != null and _town_action_input_blocker.visible:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if not _town_catalog_is_open() and focus_owner is Control:
		_town_catalog_previous_focus = focus_owner
	_town_catalog_mode = mode
	_build_actions.visible = mode == "build"
	_recruit_actions.visible = mode == "muster"
	_build_plan_label.visible = mode == "build"
	_confirm_build_button.visible = mode == "build"
	if mode == "build":
		var catalog := TownRules.get_build_catalog(_session)
		_town_catalog_title_label.text = "Construction Ledger"
		_town_catalog_subtitle_label.text = "%d town works • standing, available, and locked plans" % catalog.size()
		_rebuild_build_actions(catalog)
	else:
		var catalog := TownRules.get_muster_catalog(_session)
		_town_catalog_title_label.text = "Muster Hall"
		_town_catalog_subtitle_label.text = "%d roster units • tiers, reserves, weekly growth, costs, and dwelling locks" % catalog.size()
		_rebuild_recruit_actions(catalog)
	_town_catalog_scroll.scroll_vertical = 0
	_town_catalog_overlay.visible = true
	call_deferred("_configure_town_keyboard_focus", true)

func _close_town_catalog(restore_focus: bool = true) -> void:
	if not _town_catalog_is_open():
		return
	var focus_target := _town_catalog_previous_focus
	_town_catalog_overlay.visible = false
	_town_catalog_mode = ""
	_town_catalog_previous_focus = null
	if restore_focus and focus_target != null and is_instance_valid(focus_target) and focus_target.is_visible_in_tree():
		call_deferred("_restore_town_catalog_focus", focus_target)
	elif restore_focus:
		call_deferred("_configure_town_keyboard_focus", true)

func _restore_town_catalog_focus(focus_target: Control) -> void:
	await get_tree().process_frame
	if focus_target != null and is_instance_valid(focus_target) and focus_target.is_visible_in_tree() and not _town_catalog_is_open():
		focus_target.grab_focus()

func _on_build_action_pressed(action_id: String) -> void:
	_select_build_action("build:%s" % action_id)

func _on_town_orders_toggle_pressed() -> void:
	if not _narrow_layout_active:
		return
	_narrow_orders_open = not _narrow_orders_open
	_apply_responsive_layout()
	call_deferred("_configure_town_keyboard_focus", true)

func _on_confirm_build_pressed() -> void:
	var action := _selected_build_action()
	if action.is_empty():
		return
	if bool(action.get("market_coverable", false)) and not bool(action.get("direct_affordable", false)):
		_close_town_catalog(false)
		if _management_tabs.current_tab != 3:
			_management_tabs.current_tab = 3
		else:
			_refresh(true)
		return
	if bool(action.get("disabled", false)):
		return
	_commit_build_action(String(action.get("id", "")).trim_prefix("build:"))

func _commit_build_action(action_id: String) -> void:
	_close_town_catalog(false)
	var full_action_id := "build:%s" % action_id
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(full_action_id)
	var result := TownRules.build_active_town(_session, action_id)
	_record_town_action_result("build", full_action_id, action, result, before)
	_invalidate_active_town_entity_cache("build", ["town", "economy", "recruitment"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_action_presentation("build", full_action_id, action, result, before)

func _select_build_action(action_id: String) -> void:
	var action := _build_action_for_id(action_id)
	if action.is_empty():
		return
	_selected_build_action_id = action_id
	_rebuild_build_actions(TownRules.get_build_actions(_session))
	call_deferred("_configure_town_keyboard_focus", false)

func _on_recruit_action_pressed(action_id: String) -> void:
	var full_action_id := "recruit:%s" % action_id
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(full_action_id)
	var result := TownRules.recruit_active_town(_session, action_id)
	_record_town_action_result("recruit", full_action_id, action, result, before)
	_invalidate_active_town_entity_cache("recruit", ["town", "economy", "hero_army"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_action_presentation("recruit", full_action_id, action, result, before)

func _on_market_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := TownRules.perform_market_action(_session, action_id)
	if result.is_empty():
		return
	_record_town_action_result("market", action_id, action, result, before)
	_invalidate_active_town_entity_cache("market", ["economy"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_action_presentation("market", action_id, action, result, before)

func _on_hero_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := {}
	if action_id.begins_with("switch_hero:"):
		result = TownRules.switch_active_hero_at_town(_session, action_id.trim_prefix("switch_hero:"))
	if result.is_empty():
		return
	_record_town_action_result("order", action_id, action, result, before)
	_invalidate_active_town_entity_cache("hero", ["active_hero"])
	if _handle_session_resolution():
		return
	_refresh()

func _on_tavern_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	before["player_hero_ids"] = _town_player_hero_ids()
	var action := _validation_action_for_id(action_id)
	var result := {}
	if action_id.begins_with("hire_hero:"):
		result = TownRules.hire_hero_at_active_town(_session, action_id.trim_prefix("hire_hero:"))
	if result.is_empty():
		return
	_record_town_action_result("order", action_id, action, result, before)
	_invalidate_active_town_entity_cache("tavern", ["town", "economy", "active_hero"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_action_presentation("tavern", action_id, action, result, before)

func _on_transfer_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	before["transfer"] = _town_transfer_holder_snapshot(action_id)
	var action := _validation_action_for_id(action_id)
	var result := TownRules.transfer_in_active_town(_session, action_id)
	if result.is_empty():
		return
	_record_town_action_result("order", action_id, action, result, before)
	_invalidate_active_town_entity_cache("transfer", ["town", "hero_army"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_action_presentation("transfer", action_id, action, result, before)

func _on_army_slot_operation_requested(
	source_holder_id: String,
	source_slot_index: int,
	target_holder_id: String,
	target_slot_index: int,
	amount_token: String
) -> void:
	var result := TownRules.manage_army_slots_in_active_town(
		_session,
		source_holder_id,
		source_slot_index,
		target_holder_id,
		target_slot_index,
		amount_token
	)
	_last_message = String(result.get("message", "Army formation did not change."))
	_army_management.clear_selection()
	if bool(result.get("ok", false)):
		_invalidate_active_town_entity_cache("army_slots", ["town", "hero_army"])
	_refresh()

func _refresh_army_management(town: Dictionary) -> void:
	var holders := []
	var garrison := HeroCommandRules.army_slot_snapshot(_session, town, HeroCommandRules.HOLDER_GARRISON)
	if not garrison.is_empty():
		holders.append(garrison)
	var active_hero_id := String(_session.overworld.get("active_hero_id", ""))
	var active_hero := HeroCommandRules.army_slot_snapshot(_session, town, active_hero_id)
	if not active_hero.is_empty():
		holders.append(active_hero)
	_army_management.configure(holders, not holders.is_empty())

func _on_response_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := TownRules.perform_response_action(_session, action_id)
	if result.is_empty():
		return
	_record_town_action_result("response", action_id, action, result, before)
	_invalidate_active_town_entity_cache("response", ["town", "economy", "active_hero"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_action_presentation("response", action_id, action, result, before)

func _on_study_action_pressed(action_id: String) -> void:
	var full_action_id := "learn_spell:%s" % action_id
	var before := TownRules.town_action_consequence_signature(_session)
	before["known_spell_ids"] = _town_active_known_spell_ids()
	var action := _validation_action_for_id(full_action_id)
	var result := TownRules.learn_spell_at_active_town(_session, action_id)
	_record_town_action_result("order", full_action_id, action, result, before)
	_invalidate_active_town_entity_cache("study", ["active_hero", "spells"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_action_presentation("study", full_action_id, action, result, before)

func _on_artifact_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var hero_before: Dictionary = _session.overworld.get("hero", {}).duplicate(true) if _session.overworld.get("hero", {}) is Dictionary else {}
	before["hero_artifacts"] = ArtifactRules.normalize_hero_artifacts(hero_before.get("artifacts", {}))
	var action := _validation_action_for_id(action_id)
	var result := TownRules.manage_artifact_at_active_town(_session, action_id)
	_record_town_action_result("order", action_id, action, result, before)
	_invalidate_active_town_entity_cache("artifact", ["active_hero", "artifacts"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_artifact_presentation(action_id, action, result, before)

func _on_specialty_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	before["hero_progression"] = HeroProgressionRules.ensure_hero_progression(_session.overworld.get("hero", {})).duplicate(true)
	var action := _validation_action_for_id(action_id)
	var result := {}
	if action_id.begins_with("choose_specialty:"):
		result = TownRules.choose_specialty_at_active_town(_session, action_id.trim_prefix("choose_specialty:"))
	_record_town_action_result("order", action_id, action, result, before)
	_invalidate_active_town_entity_cache("specialty", ["active_hero"])
	if _handle_session_resolution():
		return
	_refresh()
	_record_town_action_presentation("specialty", action_id, action, result, before)

func _on_save_pressed() -> void:
	var action := AppRouter.active_manual_save_action()
	if bool(action.get("disabled", true)):
		_last_message = String(action.get("summary", "The town visit could not be saved."))
		_refresh()
		return
	if bool(action.get("requires_confirmation", false)):
		_manual_save_overwrite_dialog.open_action(action)
		return
	_commit_manual_save(int(action.get("slot", SaveService.get_selected_manual_slot())))

func _commit_manual_save(manual_slot: int) -> void:
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var save_started := ProfileLogScript.begin_usec()
	var result := AppRouter.save_active_session_to_manual_slot(manual_slot)
	buckets["save"] = ProfileLogScript.elapsed_ms(save_started)
	_last_message = String(result.get("message", ""))
	_last_action_recap = {}
	var refresh_started := ProfileLogScript.begin_usec()
	# Saving does not change town gameplay authority. Refresh the visible current
	# tab through the same bounded cache lane used by entry and tab navigation;
	# the full lane would rebuild every hidden management surface after each save.
	_refresh(true)
	buckets["refresh"] = ProfileLogScript.elapsed_ms(refresh_started)
	var save_surface_started := ProfileLogScript.begin_usec()
	_refresh_save_slot_picker(true)
	if bool(result.get("ok", false)):
		_save_written_cue_presenter.present(result, manual_slot)
	buckets["save_surface_force"] = ProfileLogScript.elapsed_ms(save_surface_started)
	ProfileLogScript.emit_general("town", "action", "save", ProfileLogScript.elapsed_ms(profile_started), buckets, _town_profile_metadata(false), _session)

func validation_save_written_cue_snapshot() -> Dictionary:
	return _save_written_cue_presenter.validation_snapshot() if _save_written_cue_presenter != null else {}

func _present_load_resumed_cue() -> void:
	var payload: Dictionary = AppRouter.consume_load_resumed_presentation("town")
	if not payload.is_empty() and _load_resumed_cue_presenter != null:
		_load_resumed_cue_presenter.present(payload)

func validation_load_resumed_cue_snapshot() -> Dictionary:
	return _load_resumed_cue_presenter.validation_snapshot() if _load_resumed_cue_presenter != null else {}

func _on_manual_save_overwrite_confirmed() -> void:
	var manual_slot: int = int(_manual_save_overwrite_dialog.consume_pending_slot())
	if SaveService.get_manual_slot_ids().has(manual_slot):
		_commit_manual_save(manual_slot)

func _on_manual_save_overwrite_canceled() -> void:
	_manual_save_overwrite_dialog.clear_pending()

func _on_save_slot_selected(index: int) -> void:
	if index < 0 or index >= _save_slot_picker.get_item_count():
		return
	SaveService.set_selected_manual_slot(_save_slot_picker.get_item_id(index))
	_refresh_save_slot_picker(true)

func _on_leave_pressed() -> void:
	var town := TownRules.get_active_town(_session)
	AppRouter.begin_overworld_handoff_profile("town_exit", {
		"source_surface": "town",
		"input": "leave_button",
		"town_placement_id": String(town.get("placement_id", "")) if town is Dictionary else "",
		"town_id": String(town.get("town_id", "")) if town is Dictionary else "",
		"save_surface_skipped_hidden": bool(_last_save_surface_profile.get("skipped_hidden", false)),
	})
	AppRouter.note_overworld_handoff_step("town_exit_button_pressed")
	var handoff_started := ProfileLogScript.begin_usec()
	var handoff := _prepare_town_return_handoff()
	AppRouter.note_overworld_handoff_step("town_return_handoff_prepared", {
		"elapsed_ms": ProfileLogScript.elapsed_ms(handoff_started),
		"town_placement_id": String(handoff.get("town_placement_id", "")),
		"has_post_action_recap": handoff.get("post_action_recap", {}) is Dictionary,
	})
	AppRouter.go_to_overworld()

func _on_menu_pressed() -> Dictionary:
	_validation_return_to_menu_request_count += 1
	var result: Dictionary = AppRouter.return_to_main_menu_from_active_play()
	_last_return_to_menu_result = result.duplicate(true)
	if bool(result.get("ok", false)):
		return _last_return_to_menu_result.duplicate(true)
	var message := String(result.get("message", "")).strip_edges().left(180)
	if message == "":
		message = RETURN_TO_MENU_FAILURE_MESSAGE
	_last_return_to_menu_result["message"] = message
	_last_message = message
	_refresh()
	_menu_button.call_deferred("grab_focus")
	return _last_return_to_menu_result.duplicate(true)

func _on_settings_pressed() -> void:
	_active_play_settings_dialog.open_dialog()

func _on_active_play_settings_closed() -> void:
	_settings_button.call_deferred("grab_focus")

func _on_active_play_setting_changed(setting_id: String) -> void:
	if setting_id not in ["ui_scale", "high_contrast", "color_cues"]:
		return
	_apply_visual_theme()
	_apply_responsive_layout()
	_refresh(true)

func _refresh(first_render_minimal: bool = false) -> void:
	_last_refresh_minimal = first_render_minimal
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var section_started := ProfileLogScript.begin_usec()
	OverworldRules.begin_normalized_read_scope(_session)
	TownRules.begin_read_scope(_session)
	if not TownRules.can_visit_active_town(_session):
		TownRules.end_read_scope(_session)
		OverworldRules.end_normalized_read_scope(_session)
		AppRouter.go_to_overworld()
		return
	buckets["read_scope"] = ProfileLogScript.elapsed_ms(section_started)

	section_started = ProfileLogScript.begin_usec()
	var active_town := TownRules.get_active_town(_session)
	# The entity state already contains every management lane. Keep that one full
	# state cached while first-frame and tab refreshes remain presentation-minimal.
	# This avoids replacing one minimal cache entry for every selected tab.
	var view_state := _active_town_entity_view_state(active_town, false)
	var cache_result: Dictionary = _last_town_entity_cache_result
	buckets["town_entity_cache"] = ProfileLogScript.elapsed_ms(section_started)
	buckets["town_entity_cache_hit"] = 1.0 if bool(cache_result.get("hit", false)) else 0.0
	buckets["town_entity_cache_miss"] = 0.0 if bool(cache_result.get("hit", false)) else 1.0
	buckets["town_entity_cache_entries"] = float(int(cache_result.get("entry_count", 0)))
	buckets["town_entity_cache_signature"] = float(cache_result.get("signature_ms", 0.0))
	buckets["town_entity_cache_build"] = float(cache_result.get("build_ms", 0.0))
	buckets["town_entity_cache_dynamic"] = float(cache_result.get("dynamic_ms", 0.0))

	section_started = ProfileLogScript.begin_usec()
	_header_label.text = String(view_state.get("header_text", ""))
	_header_label.tooltip_text = _header_label.text
	_status_label.text = String(view_state.get("status_text", ""))
	_resource_label.sync_stockpile(
		_session.overworld.get("resources", {}),
		String(view_state.get("resources_text", "")),
		String(view_state.get("resources_tooltip_text", ""))
	)
	_last_economy_readability_surface = _duplicate_dictionary(view_state.get("economy_readability_surface", {}))
	_last_rendered_build_actions = _duplicate_action_array(view_state.get("build_actions", []))
	_last_rendered_recruit_actions = _duplicate_action_array(view_state.get("recruit_actions", []))
	_refresh_faction_crest()
	_set_compact_label(_outlook_label, String(view_state.get("outlook_text", "")), 4)
	_set_compact_label(_command_ledger_label, String(view_state.get("command_ledger_text", "")), 4)
	buckets["header_outlook"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_hero_portrait.set_hero_id(_live_player_hero_id())
	_set_compact_label(_hero_label, String(view_state.get("hero_text", "")), 2)
	_set_compact_label(_production_overview_label, String(view_state.get("production_visible_text", "")), 4)
	_production_overview_label.tooltip_text = String(view_state.get("production_tooltip_text", ""))
	_set_compact_label(_heroes_label, String(view_state.get("heroes_text", "")), 2)
	_set_compact_label(_specialty_label, String(view_state.get("specialty_visible_text", "")), 2)
	_specialty_label.tooltip_text = String(view_state.get("specialty_tooltip_text", ""))
	_set_compact_label(_army_label, String(view_state.get("army_text", "")), 2)
	_refresh_army_management(active_town)
	buckets["hero_army"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_set_compact_label(_town_label, String(view_state.get("summary_text", "")), 5)
	_set_compact_label(_defense_label, String(view_state.get("defense_text", "")), 4)
	_set_compact_label(_pressure_label, String(view_state.get("threats_text", "")), 4)
	_set_compact_label(_building_label, String(view_state.get("build_visible_text", "")), 2)
	_building_label.tooltip_text = String(view_state.get("build_tooltip_text", ""))
	_set_compact_label(_market_label, String(view_state.get("market_visible_text", "")), 2)
	_market_label.tooltip_text = String(view_state.get("market_tooltip_text", ""))
	_set_compact_label(_recruit_label, String(view_state.get("recruit_visible_text", "")), 2)
	_recruit_label.tooltip_text = String(view_state.get("recruit_tooltip_text", ""))
	_set_compact_label(_tavern_label, String(view_state.get("tavern_visible_text", "")), 2)
	_tavern_label.tooltip_text = String(view_state.get("tavern_tooltip_text", ""))
	_set_compact_label(_transfer_label, String(view_state.get("transfer_visible_text", "")), 2)
	_transfer_label.tooltip_text = String(view_state.get("transfer_tooltip_text", ""))
	_set_compact_label(_response_label, String(view_state.get("response_visible_text", "")), 2)
	_response_label.tooltip_text = String(view_state.get("response_tooltip_text", ""))
	_set_compact_label(_study_label, String(view_state.get("study_visible_text", "")), 2)
	_study_label.tooltip_text = String(view_state.get("study_tooltip_text", ""))
	_set_compact_label(_spellbook_label, String(view_state.get("spellbook_text", "")), 2)
	_set_compact_label(_artifact_label, String(view_state.get("artifact_visible_text", "")), 2)
	_artifact_label.tooltip_text = String(view_state.get("artifact_tooltip_text", ""))
	buckets["town_tabs_surfaces"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	var dispatch_text := String(view_state.get("dispatch_text", ""))
	var order_target: Dictionary = view_state.get("order_target", {}) if view_state.get("order_target", {}) is Dictionary else {}
	var town_context_surface: Dictionary = view_state.get("town_context_surface", {}) if view_state.get("town_context_surface", {}) is Dictionary else {}
	if town_context_surface.is_empty():
		_set_compact_label(_event_label, "%s\n%s" % [String(order_target.get("visible_text", "")), dispatch_text], 2)
		_event_label.tooltip_text = _join_tooltip_sections([
			String(order_target.get("tooltip_text", "")),
			dispatch_text,
		])
	else:
		_set_compact_label(_event_label, "%s\n%s" % [String(town_context_surface.get("visible_text", "")), String(order_target.get("visible_text", ""))], 2)
		_event_label.tooltip_text = _join_tooltip_sections([
			String(town_context_surface.get("tooltip_text", "")),
			String(order_target.get("tooltip_text", "")),
			dispatch_text,
		])
	buckets["event_context"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_refresh_town_stage_view(view_state)
	buckets["stage"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	_refresh_save_slot_picker(false, view_state)
	buckets["save_surface"] = ProfileLogScript.elapsed_ms(section_started)
	buckets["save_surface_skipped_hidden"] = 1.0 if bool(_last_save_surface_profile.get("skipped_hidden", false)) else 0.0
	section_started = ProfileLogScript.begin_usec()
	_rebuild_current_action_surfaces(view_state, first_render_minimal)
	buckets["actions"] = ProfileLogScript.elapsed_ms(section_started)
	section_started = ProfileLogScript.begin_usec()
	if first_render_minimal:
		_refresh_management_tab_titles_minimal()
	else:
		_refresh_management_tab_cues()
	buckets["tabs"] = ProfileLogScript.elapsed_ms(section_started)
	TownRules.end_read_scope(_session)
	OverworldRules.end_normalized_read_scope(_session)
	ProfileLogScript.emit_general("town", "refresh", "town_refresh", ProfileLogScript.elapsed_ms(profile_started), buckets, _town_profile_metadata(false), _session)
	call_deferred("_configure_town_keyboard_focus", false)

func _complete_town_first_render_full_refresh() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or _session == null:
		return
	_refresh(true)

func _on_management_tab_changed(tab: int) -> void:
	if _session == null:
		return
	var previous_tab := _last_management_tab_index
	_last_management_tab_index = tab
	_validation_management_tab_change_sequence += 1
	_validation_management_tab_change_count += 1
	var change_sequence := _validation_management_tab_change_sequence
	_last_management_tab_change_result = {
		"ok": true,
		"from_tab": previous_tab,
		"to_tab": tab,
		"tab_title": _management_tabs.get_tab_title(tab) if tab >= 0 and tab < _management_tabs.get_tab_count() else "",
		"focus_handoff": false,
		"focus_owner": "",
		"focus_owner_in_active_tab": false,
		"sequence": change_sequence,
	}
	_refresh(true)
	call_deferred("_complete_management_tab_focus_handoff", tab, change_sequence)

func _complete_management_tab_focus_handoff(tab: int, change_sequence: int) -> void:
	if (
		not is_inside_tree()
		or _session == null
		or tab != _management_tabs.current_tab
		or change_sequence != _validation_management_tab_change_sequence
	):
		return
	_configure_town_keyboard_focus(true)
	_validation_management_tab_focus_handoff_count += 1
	var focus_owner := get_viewport().gui_get_focus_owner()
	_last_management_tab_change_result["focus_handoff"] = true
	_last_management_tab_change_result["focus_owner"] = String(focus_owner.name) if focus_owner != null else ""
	_last_management_tab_change_result["focus_owner_in_active_tab"] = _control_is_in_town_focus_surfaces(
		focus_owner,
		_town_keyboard_focus_surfaces()
	)

func _input(event: InputEvent) -> void:
	if _town_action_input_blocker != null and _town_action_input_blocker.visible:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel") and _town_stage_view.has_method("dismiss_town_action_presentation"):
			_town_stage_view.call("dismiss_town_action_presentation")
		return
	if _active_play_settings_dialog != null and _active_play_settings_dialog.is_open():
		return
	if _town_catalog_is_open():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_town_catalog()
		return
	if _town_guide_is_open():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_town_guide()
		return
	if _session == null or not event.is_action_pressed("ui_cancel"):
		return
	if _save_slot_picker != null and _save_slot_picker.get_popup().visible:
		return
	if _manual_save_overwrite_dialog != null and _manual_save_overwrite_dialog.visible:
		return
	get_viewport().set_input_as_handled()
	if _narrow_layout_active and _narrow_orders_open:
		_narrow_orders_open = false
		_apply_responsive_layout()
		call_deferred("_configure_town_keyboard_focus", true)
		return
	_on_leave_pressed()

func _configure_town_keyboard_focus(force: bool = false) -> void:
	if not is_inside_tree() or (_active_play_settings_dialog != null and _active_play_settings_dialog.is_open()):
		return
	if _town_action_input_blocker != null and _town_action_input_blocker.visible:
		_town_action_input_blocker.grab_focus()
		return
	if _town_catalog_is_open():
		var catalog_surfaces := [_town_catalog_close_button]
		if _town_catalog_mode == "build":
			catalog_surfaces.append_array([_build_actions, _confirm_build_button])
		else:
			catalog_surfaces.append(_recruit_actions)
		var catalog_controls := FrontierVisualKit.configure_focus_cycle(catalog_surfaces)
		FrontierVisualKit.grab_keyboard_focus(self, _town_catalog_close_button, catalog_controls, force)
		return
	if _town_guide_is_open():
		var guide_controls := FrontierVisualKit.configure_focus_cycle([_guide_close_button])
		FrontierVisualKit.grab_keyboard_focus(self, _guide_close_button, guide_controls, true)
		return
	var tab_surfaces := _town_keyboard_focus_surfaces()
	var tab_controls := _town_focusable_controls(tab_surfaces)
	var tab_bar := _management_tabs.get_tab_bar()
	var surfaces := [tab_bar]
	surfaces.append_array(tab_surfaces)
	surfaces.append_array([
		_hero_actions,
		_specialty_actions,
		_town_orders_toggle_button,
		_save_slot_picker,
		_save_button,
		_leave_button,
		_guide_button,
		_settings_button,
		_menu_button,
	])
	var controls := FrontierVisualKit.configure_focus_cycle(surfaces)
	var preferred: Control = _town_orders_toggle_button if _narrow_layout_active and not _narrow_orders_open else null
	if preferred == null:
		if not tab_controls.is_empty():
			preferred = tab_controls[0]
		elif FrontierVisualKit.is_keyboard_focusable(tab_bar):
			preferred = tab_bar
	FrontierVisualKit.grab_keyboard_focus(self, preferred, controls, force)

func _configure_town_guide_surface() -> void:
	var guide_text := SettingsService.describe_help_topic("town")
	_guide_title_label.text = "Town Field Manual"
	_guide_label.text = guide_text
	_guide_label.tooltip_text = guide_text
	_guide_button.text = "Guide"
	_guide_button.tooltip_text = "Open the Town Field Manual without building, recruiting, saving, routing, or changing the expedition."
	_guide_close_button.tooltip_text = "Close the Town Field Manual and return focus to Guide."
	_guide_overlay.visible = false

func _town_guide_is_open() -> bool:
	return _guide_overlay != null and _guide_overlay.visible

func _on_guide_pressed() -> void:
	_open_town_guide()

func _open_town_guide() -> void:
	if _town_guide_is_open():
		return
	_configure_town_guide_surface()
	_guide_overlay.visible = true
	call_deferred("_configure_town_keyboard_focus", true)

func _on_town_guide_close_pressed() -> void:
	_close_town_guide()

func _close_town_guide() -> void:
	if not _town_guide_is_open():
		return
	_guide_overlay.visible = false
	_guide_button.call_deferred("grab_focus")

func _on_town_action_presentation_blocking_changed(blocking: bool) -> void:
	if _town_action_input_blocker == null:
		return
	_town_action_input_blocker.visible = blocking
	if blocking:
		_town_action_input_blocker.call_deferred("grab_focus")
	else:
		call_deferred("_configure_town_keyboard_focus", true)

func _configure_management_tab_accessibility() -> void:
	var tab_bar := _management_tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.focus_mode = Control.FOCUS_ALL
	if not tab_bar.gui_input.is_connected(_on_management_tab_bar_gui_input):
		tab_bar.gui_input.connect(_on_management_tab_bar_gui_input)
	_sync_management_tab_tooltip()

func _on_management_tab_bar_gui_input(event: InputEvent) -> void:
	var direction := 0
	if event.is_action_pressed("ui_left", true):
		direction = -1
	elif event.is_action_pressed("ui_right", true):
		direction = 1
	if direction == 0:
		return
	var tab_bar := _management_tabs.get_tab_bar()
	if tab_bar == null or get_viewport().gui_get_focus_owner() != tab_bar:
		return
	if _selectable_management_tab_in_direction(tab_bar, _management_tabs.current_tab, direction) >= 0:
		return
	_validation_management_tab_boundary_retain_count += 1
	tab_bar.accept_event()
	tab_bar.grab_focus()

func _selectable_management_tab_in_direction(tab_bar: TabBar, from_tab: int, direction: int) -> int:
	var candidate := from_tab + direction
	while candidate >= 0 and candidate < tab_bar.tab_count:
		if not tab_bar.is_tab_disabled(candidate) and not tab_bar.is_tab_hidden(candidate):
			return candidate
		candidate += direction
	return -1

func _sync_management_tab_tooltip() -> void:
	var tab_bar := _management_tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.tooltip_text = _join_tooltip_sections([
		"Town management tabs. Use Left and Right while the tabs are focused.",
		_management_tabs.tooltip_text,
	])

func _town_focusable_controls(surfaces: Array) -> Array:
	var controls := []
	for surface in surfaces:
		_collect_town_focusable_controls(surface, controls)
	return controls

func _collect_town_focusable_controls(node: Node, controls: Array) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node is CanvasItem and node.is_inside_tree() and not node.is_visible_in_tree():
		return
	if node is Control and FrontierVisualKit.is_keyboard_focusable(node) and not controls.has(node):
		controls.append(node)
	for child in node.get_children():
		_collect_town_focusable_controls(child, controls)

func _control_is_in_town_focus_surfaces(control: Control, surfaces: Array) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	for surface in surfaces:
		if surface is Node and (surface == control or (surface as Node).is_ancestor_of(control)):
			return true
	return false

func _town_keyboard_focus_surfaces() -> Array:
	match _management_tabs.current_tab:
		0:
			return [_open_build_catalog_button]
		1:
			return [_open_muster_catalog_button]
		2:
			return [_study_actions]
		3:
			return [_market_actions]
		4:
			return [_tavern_actions, _transfer_actions, _response_actions, _artifact_actions]
		_:
			return [_build_actions, _confirm_build_button]

func _rebuild_current_action_surfaces(view_state: Dictionary, minimal: bool) -> void:
	if not minimal:
		_rebuild_hero_actions(view_state.get("hero_actions", []))
		if _town_catalog_is_open() and _town_catalog_mode == "build":
			_rebuild_build_actions(view_state.get("build_actions", []))
		_rebuild_market_actions(view_state.get("market_actions", []))
		if _town_catalog_is_open() and _town_catalog_mode == "muster":
			_rebuild_recruit_actions(view_state.get("recruit_actions", []))
		_rebuild_tavern_actions(view_state.get("tavern_actions", []))
		_rebuild_transfer_actions(view_state.get("transfer_actions", []))
		_rebuild_response_actions(view_state.get("response_actions", []))
		_rebuild_study_actions(view_state.get("study_actions", []))
		_rebuild_specialty_actions(view_state.get("specialty_actions", []))
		_rebuild_artifact_actions(view_state.get("artifact_actions", []))
		return
	var lanes := _current_town_tab_lanes()
	if lanes.has("build") and _town_catalog_is_open() and _town_catalog_mode == "build":
		_rebuild_build_actions(view_state.get("build_actions", []))
	if lanes.has("recruit") and _town_catalog_is_open() and _town_catalog_mode == "muster":
		_rebuild_recruit_actions(view_state.get("recruit_actions", []))
	if lanes.has("study"):
		_rebuild_study_actions(view_state.get("study_actions", []))
	if lanes.has("market"):
		_rebuild_market_actions(view_state.get("market_actions", []))
	if lanes.has("logistics"):
		_rebuild_tavern_actions(view_state.get("tavern_actions", []))
		_rebuild_transfer_actions(view_state.get("transfer_actions", []))
		_rebuild_response_actions(view_state.get("response_actions", []))
		_rebuild_artifact_actions(view_state.get("artifact_actions", []))

func _current_town_tab_lanes() -> Array:
	var current_tab := _management_tabs.current_tab if _management_tabs != null else 0
	match current_tab:
		0:
			return ["build"]
		1:
			return ["recruit"]
		2:
			return ["study"]
		3:
			return ["market"]
		4:
			return ["logistics"]
		_:
			return ["build"]

func _active_town_entity_view_state(town: Dictionary, minimal: bool = false) -> Dictionary:
	var placement_id := String(town.get("placement_id", ""))
	if placement_id == "":
		_last_town_entity_cache_result = {"hit": false, "placement_id": "", "entry_count": 0, "reason": "missing_placement"}
		return _build_active_town_entity_view_state(minimal)
	var session_key := _town_entity_session_cache_key()
	var bucket: Dictionary = _town_entity_cache_by_session.get(session_key, {}) if _town_entity_cache_by_session.get(session_key, {}) is Dictionary else {}
	var signature_started := ProfileLogScript.begin_usec()
	var signature := _town_entity_cache_signature(town, minimal)
	var signature_ms := ProfileLogScript.elapsed_ms(signature_started)
	var cache_key := _town_entity_cache_entry_key(placement_id, minimal)
	var entry: Dictionary = bucket.get(cache_key, {}) if bucket.get(cache_key, {}) is Dictionary else {}
	if String(entry.get("signature", "")) == signature and entry.get("view_state", {}) is Dictionary:
		var dynamic_started := ProfileLogScript.begin_usec()
		var cached_view_state: Dictionary = (entry.get("view_state", {}) as Dictionary).duplicate(true)
		_refresh_active_town_dynamic_view_state(cached_view_state, town, minimal)
		var dynamic_ms := ProfileLogScript.elapsed_ms(dynamic_started)
		_last_town_entity_cache_result = {
			"hit": true,
			"placement_id": placement_id,
			"cache_key": cache_key,
			"entry_count": bucket.size(),
			"signature": signature,
			"signature_ms": signature_ms,
			"build_ms": 0.0,
			"dynamic_ms": dynamic_ms,
			"minimal": bool(entry.get("minimal", false)),
		}
		return cached_view_state
	var build_started := ProfileLogScript.begin_usec()
	var view_state := _build_active_town_entity_view_state(minimal)
	var build_ms := ProfileLogScript.elapsed_ms(build_started)
	bucket[cache_key] = {
		"signature": signature,
		"view_state": view_state.duplicate(true),
		"placement_id": placement_id,
		"minimal": minimal,
	}
	_town_entity_cache_by_session[session_key] = bucket
	_last_town_entity_cache_result = {
		"hit": false,
		"placement_id": placement_id,
		"cache_key": cache_key,
		"entry_count": bucket.size(),
		"signature": signature,
		"signature_ms": signature_ms,
		"build_ms": build_ms,
		"dynamic_ms": 0.0,
		"minimal": minimal,
	}
	return view_state

func _refresh_active_town_dynamic_view_state(view_state: Dictionary, town: Dictionary, minimal: bool = false) -> void:
	var current_lanes := _current_town_tab_lanes()
	var cached_economy_build_actions: Variant = view_state.get("economy_build_actions", view_state.get("build_actions", []))
	var cached_economy_recruit_actions: Variant = view_state.get("economy_recruit_actions", view_state.get("recruit_actions", []))
	var economy_build_actions := _refresh_cached_cost_actions(cached_economy_build_actions, town)
	var economy_recruit_actions := _refresh_cached_recruit_actions(cached_economy_recruit_actions, town)
	view_state["economy_build_actions"] = _duplicate_action_array(economy_build_actions)
	view_state["economy_recruit_actions"] = _duplicate_action_array(economy_recruit_actions)
	view_state["resources_text"] = OverworldRules.describe_resources(_session)
	var economy_surface := _economy_readability_surface(
		economy_build_actions,
		economy_recruit_actions,
		view_state.get("economy_context_surface", {})
	)
	view_state["economy_readability_surface"] = economy_surface.duplicate(true)
	view_state["resources_tooltip_text"] = _resource_ledger_tooltip_text_from_surface(economy_surface)
	var cached_stage: Dictionary = view_state.get("stage_state", {}) if view_state.get("stage_state", {}) is Dictionary else {}
	var departure_build_actions := _refresh_cached_cost_actions(
		cached_stage.get("build_actions", []),
		town,
		view_state.get("build_action_copy_models", {})
	)
	var departure_recruit_actions := _refresh_cached_recruit_actions(
		cached_stage.get("recruit_actions", []),
		town,
		view_state.get("recruit_action_copy_models", {})
	)
	var departure_response_actions := _refresh_cached_response_actions(cached_stage.get("response_actions", []), town)
	var departure_study_actions := _refresh_cached_cost_actions(cached_stage.get("study_actions", []), town)
	var departure_market_actions := _refresh_cached_cost_actions(cached_stage.get("market_actions", []), town)
	var departure := _cached_departure_dynamic(
		view_state.get("departure", {}),
		town,
		departure_build_actions,
		departure_recruit_actions,
		departure_response_actions,
		departure_study_actions,
		departure_market_actions,
		String(view_state.get("departure_fallback_next_action", "")),
		view_state.get("departure_context_surface", {})
	)
	view_state["departure"] = departure
	var dispatch_text := _cached_dispatch_dynamic(String(view_state.get("dispatch_text", "")), departure, town)
	view_state["dispatch_text"] = dispatch_text
	view_state["town_context_surface"] = {} if minimal else _town_action_context_surface(dispatch_text)
	if not minimal:
		view_state["hero_actions"] = _duplicate_action_array(view_state.get("hero_actions", []))
		view_state["specialty_actions"] = _duplicate_action_array(view_state.get("specialty_actions", []))
	if not minimal or current_lanes.has("build"):
		var cached_build_actions := _duplicate_action_array(view_state.get("build_actions", []))
		var build_actions := _refresh_cached_cost_actions(
			cached_build_actions,
			town,
			view_state.get("build_action_copy_models", {})
		)
		view_state["build_actions"] = build_actions
		# A tab-only refresh must preserve the exact full presentation state. Rebuild
		# the compact dynamic readiness copy only when affordability actually changed.
		if build_actions != cached_build_actions:
			_update_cached_build_readiness(view_state, build_actions, town)
	if not minimal or current_lanes.has("market"):
		view_state["market_actions"] = _refresh_cached_cost_actions(view_state.get("market_actions", []), town)
	if not minimal or current_lanes.has("recruit"):
		view_state["recruit_actions"] = _refresh_cached_recruit_actions(
			view_state.get("recruit_actions", []),
			town,
			view_state.get("recruit_action_copy_models", {})
		)
	if not minimal or current_lanes.has("study"):
		view_state["study_actions"] = _refresh_cached_cost_actions(view_state.get("study_actions", []), town)
	if not minimal or current_lanes.has("logistics"):
		view_state["tavern_actions"] = _refresh_cached_cost_actions(view_state.get("tavern_actions", []), town)
		view_state["transfer_actions"] = _duplicate_action_array(view_state.get("transfer_actions", []))
		view_state["response_actions"] = _refresh_cached_response_actions(view_state.get("response_actions", []), town)
		view_state["artifact_actions"] = _duplicate_action_array(view_state.get("artifact_actions", []))
	view_state["stage_state"] = _refresh_cached_stage_dynamic(view_state, town)

func _refresh_cached_cost_actions(actions: Variant, town: Dictionary, copy_models: Variant = null) -> Array:
	var refreshed := _duplicate_action_array(actions)
	var models: Dictionary = copy_models if copy_models is Dictionary else {}
	var resources: Dictionary = _session.overworld.get("resources", {}) if _session.overworld.get("resources", {}) is Dictionary else {}
	for index in range(refreshed.size()):
		var action: Dictionary = refreshed[index]
		var cost: Dictionary = action.get("cost", {}) if action.get("cost", {}) is Dictionary else {}
		if cost.is_empty():
			continue
		var readiness: Dictionary = OverworldRules.town_cost_readiness(
			town,
			resources,
			cost,
			int(_session.day) if _session != null else -1
		)
		var direct_affordable := bool(readiness.get("direct_affordable", false))
		var market_coverable := bool(readiness.get("market_affordable", false)) and not direct_affordable
		var market_summary := TownRules._market_coverage_line(readiness)
		var shortfall_summary := TownRules._cost_shortfall_line(readiness)
		var full_affordability_line := TownRules._cost_readiness_line(resources, cost, readiness)
		var affordability_line := full_affordability_line.trim_suffix(".")
		action["direct_affordable"] = direct_affordable
		action["market_coverable"] = market_coverable
		action["disabled"] = not direct_affordable
		action["market_summary"] = market_summary
		action["shortfall_summary"] = shortfall_summary
		action["affordability_label"] = affordability_line
		action["disabled_reason"] = TownRules._disabled_reason_line(direct_affordable, market_coverable, market_summary, shortfall_summary)
		if action.has("button_label"):
			action["button_label"] = "%s | %s" % [_cached_action_label_prefix(String(action.get("button_label", ""))), _cached_cost_badge(direct_affordable, market_coverable)]
		var copy_model: Dictionary = models.get(String(action.get("id", "")), {}) if models.get(String(action.get("id", "")), {}) is Dictionary else {}
		if not copy_model.is_empty():
			var summary_lines := _duplicate_array(copy_model.get("static_summary_lines", []))
			summary_lines.append(full_affordability_line)
			if direct_affordable:
				var after_spend_line := TownRules._stores_after_cost_line(resources, cost)
				if after_spend_line != "":
					summary_lines.append("After build stores: %s." % after_spend_line)
			elif market_coverable and market_summary != "":
				summary_lines.append("Exchange path: %s" % market_summary)
			elif shortfall_summary != "":
				summary_lines.append("Blocker: %s" % shortfall_summary)
			action["summary"] = "\n".join(summary_lines)
			var ledger_prefix := String(copy_model.get("ledger_prefix", ""))
			if ledger_prefix != "":
				action["ledger_line"] = "%s | %s" % [ledger_prefix, affordability_line]
			action["recommendation_line"] = TownRules._action_recommendation_line(
				"Build",
				String(copy_model.get("action_name", "Build order")),
				direct_affordable,
				market_coverable,
				shortfall_summary,
				String(action.get("impact_line", ""))
			)
		refreshed[index] = action
	return refreshed

func _refresh_cached_recruit_actions(actions: Variant, town: Dictionary, copy_models: Variant = null) -> Array:
	var refreshed := _duplicate_action_array(actions)
	var models: Dictionary = copy_models if copy_models is Dictionary else {}
	var resources: Dictionary = _session.overworld.get("resources", {}) if _session.overworld.get("resources", {}) is Dictionary else {}
	for index in range(refreshed.size()):
		var action: Dictionary = refreshed[index]
		var unit_cost: Dictionary = action.get("unit_cost", {}) if action.get("unit_cost", {}) is Dictionary else {}
		if unit_cost.is_empty():
			continue
		var available: int = max(0, int(action.get("available_count", 0)))
		var direct_count: int = min(available, TownRules._max_affordable_count(_session, unit_cost))
		var market_count: int = TownRules._max_market_affordable_count(_session, town, resources, unit_cost, available)
		var market_summary: String = ""
		if market_count > direct_count:
			market_summary = TownRules._market_coverage_line(OverworldRules.town_cost_readiness(
				town,
				resources,
				TownRules._multiply_resource_cost(unit_cost, market_count),
				int(_session.day) if _session != null else -1
			))
		var shortfall_summary: String = ""
		if market_count <= 0:
			shortfall_summary = TownRules._cost_shortfall_line(OverworldRules.town_cost_readiness(
				town,
				resources,
				unit_cost,
				int(_session.day) if _session != null else -1
			))
		action["direct_affordable_count"] = direct_count
		action["market_affordable_count"] = market_count
		action["market_coverable"] = market_count > direct_count
		action["market_summary"] = market_summary
		action["shortfall_summary"] = shortfall_summary
		action["disabled"] = direct_count <= 0
		action["affordability_label"] = TownRules._recruit_affordability_label(direct_count, market_count, shortfall_summary)
		action["disabled_reason"] = TownRules._disabled_reason_line(direct_count > 0, market_count > direct_count, market_summary, shortfall_summary)
		if action.has("button_label"):
			action["button_label"] = "%s | %s" % [_cached_action_label_prefix(String(action.get("button_label", ""))), _cached_recruit_badge(direct_count, market_count)]
		var copy_model: Dictionary = models.get(String(action.get("id", "")), {}) if models.get(String(action.get("id", "")), {}) is Dictionary else {}
		if not copy_model.is_empty():
			var summary_lines := _duplicate_array(copy_model.get("static_summary_lines", []))
			var impact_line := TownRules._recruit_choice_impact_line(
				String(copy_model.get("unit_id", "")),
				direct_count,
				available
			)
			action["impact_line"] = impact_line
			if impact_line != "":
				summary_lines.append(impact_line)
			if direct_count > 0:
				var direct_recruit_cost: Dictionary = TownRules._multiply_resource_cost(unit_cost, direct_count)
				summary_lines.append("Ready: current stores can field %d now for %s." % [
					direct_count,
					TownRules._describe_resources(direct_recruit_cost),
				])
				var after_recruit_line := TownRules._stores_after_cost_line(resources, direct_recruit_cost)
				if after_recruit_line != "":
					summary_lines.append("After recruit stores: %s | Town reserve remains %d." % [
						after_recruit_line,
						max(0, available - direct_count),
					])
			elif market_count > 0 and market_summary != "":
				summary_lines.append("Exchange can unlock %d now: %s" % [market_count, market_summary])
			elif shortfall_summary != "":
				summary_lines.append("Blocker: %s" % shortfall_summary)
			action["summary"] = "\n".join(summary_lines)
			action["recommendation_line"] = TownRules._action_recommendation_line(
				"Recruit",
				String(copy_model.get("action_name", "Recruit order")),
				direct_count > 0,
				market_count > direct_count,
				shortfall_summary,
				impact_line
			)
		refreshed[index] = action
	return refreshed

func _refresh_cached_response_actions(actions: Variant, town: Dictionary) -> Array:
	var refreshed := _duplicate_action_array(actions)
	var resources: Dictionary = _session.overworld.get("resources", {}) if _session.overworld.get("resources", {}) is Dictionary else {}
	var movement: Dictionary = _session.overworld.get("movement", {}) if _session.overworld.get("movement", {}) is Dictionary else {}
	var movement_left := int(movement.get("current", 0))
	for index in range(refreshed.size()):
		var action: Dictionary = refreshed[index]
		var cost: Dictionary = action.get("resource_cost", {}) if action.get("resource_cost", {}) is Dictionary else {}
		var readiness := OverworldRules.town_cost_readiness(
			town,
			resources,
			cost,
			int(_session.day) if _session != null else -1
		)
		var resource_blocked := not bool(readiness.get("direct_affordable", false))
		var movement_cost := int(action.get("movement_cost", 0))
		var movement_blocked := movement_left < movement_cost
		action["disabled"] = resource_blocked or movement_blocked
		action["resource_blocked"] = resource_blocked
		action["movement_blocked"] = movement_blocked
		action["remaining_movement_after_order"] = max(0, movement_left - movement_cost)
		action["market_coverable"] = bool(readiness.get("market_affordable", false)) and resource_blocked
		action["market_summary"] = TownRules._market_coverage_line(readiness) if bool(action.get("market_coverable", false)) else ""
		refreshed[index] = action
	return refreshed

func _cached_action_label_prefix(label: String) -> String:
	var separator := label.find(" | ")
	if separator >= 0:
		return label.left(separator)
	return label

func _cached_cost_badge(direct_affordable: bool, market_coverable: bool) -> String:
	if direct_affordable:
		return "Ready"
	if market_coverable:
		return "Trade"
	return "Blocked"

func _cached_recruit_badge(direct_count: int, market_count: int) -> String:
	if direct_count > 0:
		return "Ready x%d" % direct_count
	if market_count > 0:
		return "Trade x%d" % market_count
	return "Blocked"

func _update_cached_build_readiness(view_state: Dictionary, actions: Array, town: Dictionary) -> void:
	var ready_orders := 0
	var market_orders := 0
	var blocked_orders := 0
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("direct_affordable", false)):
			ready_orders += 1
		elif bool(action.get("market_coverable", false)):
			market_orders += 1
		else:
			blocked_orders += 1
	var built_count := _normalize_string_array(town.get("built_buildings", [])).size()
	if ready_orders > 0:
		view_state["build_visible_text"] = "Build check: Ready x%d | %d built" % [ready_orders, built_count]
	elif market_orders > 0:
		view_state["build_visible_text"] = "Build check: Trade unlocks x%d" % market_orders
	elif blocked_orders > 0:
		view_state["build_visible_text"] = "Build check: Blocked x%d waiting" % blocked_orders

func _refresh_cached_stage_dynamic(view_state: Dictionary, town: Dictionary) -> Dictionary:
	var stage_state: Dictionary = view_state.get("stage_state", {}) if view_state.get("stage_state", {}) is Dictionary else {}
	if stage_state.is_empty():
		return _build_town_stage_view_state(town)
	var refreshed := stage_state.duplicate(true)
	refreshed["town"] = _town_stage_town_payload(town)
	refreshed["stationed"] = HeroCommandRules.stationed_heroes(_session, town).duplicate(true)
	refreshed["occupation"] = OverworldRules.town_occupation_state(_session, town).duplicate(true)
	refreshed["front"] = OverworldRules.town_front_state(_session, town).duplicate(true)
	for lane in ["build_actions", "recruit_actions", "response_actions", "study_actions", "market_actions"]:
		if view_state.has(lane):
			refreshed[lane] = _duplicate_action_array(view_state.get(lane, []))
	return refreshed

func _cached_departure_dynamic(
	departure_value: Variant,
	town: Dictionary,
	build_actions: Array,
	recruit_actions: Array,
	response_actions: Array,
	study_actions: Array,
	market_actions: Array,
	fallback_next_action: String,
	context_value: Variant
) -> Dictionary:
	# Movement and response availability can change while the broader town view is
	# cached. Rebuild this compact action surface from cached action models so its
	# tooltip and next step stay authoritative without reconstructing projections.
	var departure: Dictionary = departure_value.duplicate(true) if departure_value is Dictionary else {}
	var movement: Dictionary = _session.overworld.get("movement", {}) if _session.overworld.get("movement", {}) is Dictionary else {}
	var move_current := int(movement.get("current", 0))
	var move_max := int(movement.get("max", move_current))
	var ready_response := _first_enabled_validation_action(response_actions)
	var context: Dictionary = context_value if context_value is Dictionary else {}
	var affected := String(departure.get("affected", ""))
	var why_it_matters := String(departure.get("why_it_matters", ""))
	if not context.is_empty():
		affected = TownRules._town_handoff_affected_line(
			String(context.get("town_name", "Town")),
			context.get("front", {}),
			context.get("occupation", {}),
			context.get("logistics", {}),
			ready_response
		)
		why_it_matters = TownRules._town_handoff_why_line(
			town,
			context.get("front", {}),
			context.get("occupation", {}),
			context.get("logistics", {}),
			context.get("recovery", {}),
			ready_response
		)
	var recommendation := _cached_town_recommendation_line(town, build_actions, recruit_actions, fallback_next_action)
	var next_action := _cached_next_town_action_line(
		town,
		build_actions,
		recruit_actions,
		response_actions,
		study_actions,
		market_actions,
		fallback_next_action
	)
	var next_step := ""
	if not ready_response.is_empty():
		var response_label := TownRules._short_action_label(ready_response, "Response order")
		var move_left := int(ready_response.get("remaining_movement_after_order", move_current))
		next_step = "Use %s in Logistics, then return to the field route with %d move." % [response_label, move_left]
	elif move_current <= 0:
		next_step = "%s Then return to the field and choose End Turn to refresh movement." % next_action
	else:
		next_step = "%s Then return to the field route with %d/%d move." % [next_action, move_current, move_max]
	departure["movement_current"] = move_current
	departure["movement_max"] = move_max
	departure["button_label"] = "Return to Field"
	departure["ready_response_action_count"] = 1 if not ready_response.is_empty() else 0
	departure["town_readiness"] = recommendation
	departure["affected"] = affected
	departure["why_it_matters"] = why_it_matters
	departure["next_step"] = next_step
	if not ready_response.is_empty():
		departure["visible_text"] = "Ready check: response order is open before returning to the field."
	elif move_current <= 0:
		departure["visible_text"] = "Ready check: movement is spent; return to the field, then choose End Turn."
	else:
		departure["visible_text"] = "Ready check: finish town orders, then return to the field with %d/%d move." % [move_current, move_max]
	departure["tooltip_text"] = "Departure Check\n- Town readiness: %s\n- Affected: %s\n- Why it matters: %s\n- Next practical action: %s" % [
		recommendation,
		affected,
		why_it_matters,
		next_step,
	]
	_last_departure_confirmation = departure.duplicate(true)
	return departure

func _cached_dispatch_dynamic(cached_text: String, departure: Dictionary, town: Dictionary) -> String:
	# Gameplay actions invalidate the town cache, so only the action recap and the
	# already-refreshed handoff line can differ on a hit. Preserve the invariant
	# action/logistics lines instead of rebuilding their full rule surfaces.
	var lines := cached_text.split("\n")
	if lines.size() < 2:
		return cached_text
	var recap_text := String(_last_action_recap.get("text", ""))
	if recap_text != "":
		lines[1] = recap_text
	else:
		lines[1] = "- Handoff: %s | Why: %s | Next: %s" % [
			TownRules._short_town_handoff_text(String(departure.get("affected", "")), 58),
			TownRules._short_town_handoff_text(String(departure.get("why_it_matters", "")), 70),
			TownRules._short_town_handoff_text(String(departure.get("next_step", "")), 72),
		]
	for index in range(lines.size()):
		if String(lines[index]).begins_with("- Defense readiness: "):
			lines[index] = "- Defense readiness: %s" % OverworldRules.describe_town_defense_readiness_warning(_session, town)
			break
	return "\n".join(lines)

func _cached_town_recommendation_line(town: Dictionary, build_actions: Array, recruit_actions: Array, fallback: String) -> String:
	var recommendation := {}
	var best_score := -999999
	for action_value in build_actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var score := TownRules._town_build_recommendation_score(town, action)
		if score > best_score:
			best_score = score
			recommendation = action
	for action_value in recruit_actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var score := TownRules._town_recruit_recommendation_score(action)
		if score > best_score:
			best_score = score
			recommendation = action
	if recommendation.is_empty():
		return fallback
	var label := TownRules._short_action_label(recommendation, "Town order")
	var impact := String(recommendation.get("impact_line", "")).trim_suffix(".")
	var readiness := String(recommendation.get("affordability_label", ""))
	if readiness == "":
		readiness = String(recommendation.get("disabled_reason", ""))
	if impact != "" and readiness != "":
		return "%s | %s | %s" % [label, readiness, impact]
	if impact != "":
		return "%s | %s" % [label, impact]
	if readiness != "":
		return "%s | %s" % [label, readiness]
	return "%s is the clearest town order." % label

func _cached_next_town_action_line(
	town: Dictionary,
	build_actions: Array,
	recruit_actions: Array,
	response_actions: Array,
	study_actions: Array,
	market_actions: Array,
	fallback: String
) -> String:
	for action_value in build_actions:
		if not (action_value is Dictionary) or bool(action_value.get("disabled", false)):
			continue
		var action: Dictionary = action_value
		var projection := TownRules._action_projection_line(action)
		if projection != "":
			return "%s: %s" % [TownRules._short_action_label(action, "Build order"), projection]
		return "%s is ready." % TownRules._short_action_label(action, "Build order")
	for action_value in recruit_actions:
		if not (action_value is Dictionary) or int(action_value.get("direct_affordable_count", 0)) <= 0:
			continue
		return "%s fields %d now." % [
			TownRules._short_action_label(action_value, "Recruit order"),
			int(action_value.get("direct_affordable_count", 0)),
		]
	for action_value in response_actions:
		if action_value is Dictionary and not bool(action_value.get("disabled", false)):
			return "%s secures the frontier chain." % TownRules._short_action_label(action_value, "Response order")
	for action_value in study_actions:
		if action_value is Dictionary and not bool(action_value.get("disabled", false)):
			return "%s expands the hero spellbook." % TownRules._short_action_label(action_value, "Study order")
	for action_value in market_actions:
		if action_value is Dictionary and not bool(action_value.get("disabled", false)):
			return "%s converts stores for blocked orders." % TownRules._short_action_label(action_value, "Exchange")
	for action_value in build_actions:
		if action_value is Dictionary and bool(action_value.get("market_coverable", false)):
			return "Trade first for %s." % TownRules._short_action_label(action_value, "Build order")
	for action_value in recruit_actions:
		if action_value is Dictionary and bool(action_value.get("market_coverable", false)):
			return "Trade first for %s." % TownRules._short_action_label(action_value, "Recruit order")
	for action_value in build_actions:
		if action_value is Dictionary:
			return "%s blocked: %s." % [
				TownRules._short_action_label(action_value, "Build order"),
				String(action_value.get("disabled_reason", "stores are too thin")).trim_prefix("Blocked: "),
			]
	for action_value in recruit_actions:
		if action_value is Dictionary:
			return "%s blocked: %s." % [
				TownRules._short_action_label(action_value, "Recruit order"),
				String(action_value.get("disabled_reason", "stores are too thin")).trim_prefix("Blocked: "),
			]
	return fallback if fallback != "" else "Leave town; no production order is open."

func _resource_ledger_tooltip_text(build_actions_override: Variant = null, recruit_actions_override: Variant = null) -> String:
	return _resource_ledger_tooltip_text_from_surface(_economy_readability_surface(build_actions_override, recruit_actions_override))

func _resource_ledger_tooltip_text_from_surface(economy_plan: Dictionary) -> String:
	return _join_tooltip_sections([
		"Resource Ledger\nFull stockpile: %s" % OverworldRules.describe_resource_stockpile(
			_session.overworld.get("resources", {}),
			true
		),
		String(economy_plan.get("tooltip_text", "")),
	])

func _economy_readability_surface(
	build_actions_override: Variant = null,
	recruit_actions_override: Variant = null,
	context_override: Variant = null
) -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var resources: Dictionary = _session.overworld.get("resources", {}) if _session.overworld.get("resources", {}) is Dictionary else {}
	var cached_context: Dictionary = context_override if context_override is Dictionary else {}
	var town_income := _duplicate_dictionary(cached_context.get("daily_town_income", {})) if not cached_context.is_empty() else (OverworldRules.town_income(town, _session) if not town.is_empty() else {})
	var site_income := _duplicate_dictionary(cached_context.get("daily_field_income", {})) if not cached_context.is_empty() else OverworldRules.controlled_resource_site_income(_session, "player")
	var build_plan := _economy_build_plan_surface(town, resources, build_actions_override)
	var muster_plan := _economy_muster_plan_surface(town, resources, recruit_actions_override)
	var field_site_count := int(cached_context.get("field_site_count", 0)) if not cached_context.is_empty() else _player_controlled_economy_site_count()
	var field_site_line := "Field sites: %d controlled, daily %s." % [
		field_site_count,
		_economy_delta_line(site_income, "no field-site income"),
	]
	var tooltip_lines := [
		"Economy Plan",
		"- Daily income: town %s; field %s." % [
			_economy_delta_line(town_income, "no town income"),
			_economy_delta_line(site_income, "no field-site income"),
		],
		"- Next build: %s" % String(build_plan.get("player_line", "")),
		"- Build bottleneck: %s" % String(build_plan.get("bottleneck_line", "")),
		"- Next muster: %s" % String(muster_plan.get("player_line", "")),
		"- %s" % field_site_line,
	]
	return {
		"schema": "town_shell_player_economy_readability_surface_v1",
		"tooltip_text": "\n".join(tooltip_lines),
		"daily_town_income": _duplicate_dictionary(town_income),
		"daily_field_income": _duplicate_dictionary(site_income),
		"field_site_count": field_site_count,
		"build_plan_state": String(build_plan.get("state", "")),
		"build_ready_order_count": int(build_plan.get("ready_order_count", 0)),
		"build_market_order_count": int(build_plan.get("market_order_count", 0)),
		"build_blocked_order_count": int(build_plan.get("blocked_order_count", 0)),
		"build_bottleneck_resource_id": String(build_plan.get("bottleneck_resource_id", "")),
		"build_has_bottleneck": bool(build_plan.get("has_bottleneck", false)),
		"player_readable_next_build": String(build_plan.get("player_line", "")),
		"player_readable_build_bottleneck": String(build_plan.get("bottleneck_line", "")),
		"muster_plan_state": String(muster_plan.get("state", "")),
		"muster_ready_unit_count": int(muster_plan.get("ready_unit_count", 0)),
		"muster_market_unit_count": int(muster_plan.get("market_unit_count", 0)),
		"muster_blocked_unit_count": int(muster_plan.get("blocked_unit_count", 0)),
		"player_readable_next_muster": String(muster_plan.get("player_line", "")),
		"field_site_line": field_site_line,
	}

func _economy_context_surface_from_readability(economy_surface: Dictionary) -> Dictionary:
	return {
		"daily_town_income": _duplicate_dictionary(economy_surface.get("daily_town_income", {})),
		"daily_field_income": _duplicate_dictionary(economy_surface.get("daily_field_income", {})),
		"field_site_count": int(economy_surface.get("field_site_count", 0)),
	}

func _economy_build_plan_surface(town: Dictionary, resources: Dictionary, actions_override: Variant = null) -> Dictionary:
	var actions: Array
	if actions_override is Array:
		actions = _duplicate_action_array(actions_override)
	else:
		actions = TownRules.get_build_actions(_session)
	var ready_orders := 0
	var market_orders := 0
	var blocked_orders := 0
	var selected := {}
	var bottleneck := {}
	var bottleneck_resource_id := ""
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var direct_ready := bool(action.get("direct_affordable", false))
		var market_ready := bool(action.get("market_coverable", false))
		if direct_ready:
			ready_orders += 1
			if selected.is_empty():
				selected = action
		elif market_ready:
			market_orders += 1
			if selected.is_empty() or not bool(selected.get("direct_affordable", false)):
				selected = action
		else:
			blocked_orders += 1
			if selected.is_empty():
				selected = action
		var cost: Dictionary = action.get("cost", {}) if action.get("cost", {}) is Dictionary else {}
		var readiness: Dictionary = OverworldRules.town_cost_readiness(town, resources, cost, int(_session.day))
		var short_resource := _first_positive_resource_id(readiness.get("direct_shortfall", {}))
		if short_resource != "" and (bottleneck.is_empty() or short_resource not in ["gold", "wood", "ore"]):
			bottleneck = action
			bottleneck_resource_id = short_resource
			if short_resource not in ["gold", "wood", "ore"]:
				break
	var state := "none"
	if ready_orders > 0:
		state = "ready"
	elif market_orders > 0:
		state = "trade"
	elif blocked_orders > 0:
		state = "blocked"
	var selected_name := _economy_action_name(selected, "No build order")
	var readiness_line := String(selected.get("affordability_label", selected.get("disabled_reason", "No construction order is currently available.")))
	var player_line := "%s - %s" % [selected_name, readiness_line]
	var bottleneck_line := "none blocking current build choices"
	if not bottleneck.is_empty():
		var bottleneck_name := _economy_action_name(bottleneck, "Build order")
		var shortfall := String(bottleneck.get("shortfall_summary", "stores are short"))
		bottleneck_line = "%s is blocked: %s; capture or income-plan %s." % [
			bottleneck_name,
			shortfall,
			_economy_resource_label(bottleneck_resource_id),
		]
	return {
		"state": state,
		"ready_order_count": ready_orders,
		"market_order_count": market_orders,
		"blocked_order_count": blocked_orders,
		"player_line": player_line,
		"bottleneck_line": bottleneck_line,
		"bottleneck_resource_id": bottleneck_resource_id,
		"has_bottleneck": not bottleneck.is_empty(),
	}

func _economy_muster_plan_surface(town: Dictionary, resources: Dictionary, actions_override: Variant = null) -> Dictionary:
	var actions: Array
	if actions_override is Array:
		actions = _duplicate_action_array(actions_override)
	else:
		actions = TownRules.get_recruit_actions(_session)
	var ready_units := 0
	var market_units := 0
	var blocked_units := 0
	var selected := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var available: int = max(0, int(action.get("available_count", 0)))
		var direct_count: int = max(0, int(action.get("direct_affordable_count", 0)))
		var market_count: int = max(0, int(action.get("market_affordable_count", 0)))
		if direct_count > 0:
			ready_units += direct_count
			if selected.is_empty() or direct_count > int(selected.get("direct_affordable_count", 0)):
				selected = action
		elif market_count > 0:
			market_units += market_count
			if selected.is_empty():
				selected = action
		else:
			blocked_units += available
			if selected.is_empty() and available > 0:
				selected = action
	var state := "none"
	if ready_units > 0:
		state = "ready"
	elif market_units > 0:
		state = "trade"
	elif blocked_units > 0:
		state = "blocked"
	var selected_name := _economy_action_name(selected, "No muster order")
	var readiness_line := String(selected.get("affordability_label", selected.get("disabled_reason", "No recruit order is currently available.")))
	return {
		"state": state,
		"ready_unit_count": ready_units,
		"market_unit_count": market_units,
		"blocked_unit_count": blocked_units,
		"player_line": "%s - %s" % [selected_name, readiness_line],
	}

func _economy_build_action_models(actions: Variant) -> Array:
	var models := []
	if not (actions is Array):
		return models
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		models.append({
			"id": String(action.get("id", "")),
			"label": String(action.get("label", "")),
			"button_label": String(action.get("button_label", "")),
			"cost": _duplicate_dictionary(action.get("cost", {})),
			"direct_affordable": bool(action.get("direct_affordable", false)),
			"market_coverable": bool(action.get("market_coverable", false)),
			"affordability_label": String(action.get("affordability_label", "")),
			"disabled_reason": String(action.get("disabled_reason", "")),
			"shortfall_summary": String(action.get("shortfall_summary", "")),
		})
	return models

func _economy_recruit_action_models(actions: Variant) -> Array:
	var models := []
	if not (actions is Array):
		return models
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		models.append({
			"id": String(action.get("id", "")),
			"label": String(action.get("label", "")),
			"button_label": String(action.get("button_label", "")),
			"unit_cost": _duplicate_dictionary(action.get("unit_cost", {})),
			"available_count": int(action.get("available_count", 0)),
			"direct_affordable_count": int(action.get("direct_affordable_count", 0)),
			"market_affordable_count": int(action.get("market_affordable_count", 0)),
			"affordability_label": String(action.get("affordability_label", "")),
			"disabled_reason": String(action.get("disabled_reason", "")),
		})
	return models

func _build_action_copy_models(actions: Variant) -> Dictionary:
	var models := {}
	if not (actions is Array):
		return models
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var action_id := String(action.get("id", ""))
		if action_id == "":
			continue
		var summary_lines := _summary_lines_without_dynamic_tail(
			String(action.get("summary", "")),
			["After build stores:", "Exchange path:", "Blocker:"],
			true
		)
		var ledger_line := String(action.get("ledger_line", ""))
		var ledger_separator := ledger_line.rfind(" | ")
		models[action_id] = {
			"static_summary_lines": summary_lines,
			"ledger_prefix": ledger_line.left(ledger_separator) if ledger_separator >= 0 else ledger_line,
			"action_name": String(action.get("label", "Build order")).trim_prefix("Build "),
		}
	return models

func _recruit_action_copy_models(actions: Variant) -> Dictionary:
	var models := {}
	if not (actions is Array):
		return models
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var action_id := String(action.get("id", ""))
		if action_id == "":
			continue
		var static_summary_lines := _summary_lines_without_dynamic_tail(
			String(action.get("summary", "")),
			["Ready:", "After recruit stores:", "Exchange can unlock", "Blocker:"],
			false
		)
		var cached_impact_line := String(action.get("impact_line", ""))
		if not static_summary_lines.is_empty() and cached_impact_line != "" and String(static_summary_lines.back()) == cached_impact_line:
			static_summary_lines.pop_back()
		models[action_id] = {
			"static_summary_lines": static_summary_lines,
			"action_name": String(action.get("label", "Recruit order")).trim_prefix("Recruit "),
			"unit_id": action_id.trim_prefix("recruit:"),
		}
	return models

func _summary_lines_without_dynamic_tail(summary: String, dynamic_prefixes: Array, remove_affordability_line: bool) -> Array:
	var lines := Array(summary.split("\n", false))
	while not lines.is_empty() and _line_begins_with_any(String(lines.back()), dynamic_prefixes):
		lines.pop_back()
	if remove_affordability_line and not lines.is_empty():
		lines.pop_back()
	return lines

func _line_begins_with_any(line: String, prefixes: Array) -> bool:
	for prefix_value in prefixes:
		if line.begins_with(String(prefix_value)):
			return true
	return false

func _economy_action_name(action: Dictionary, fallback: String) -> String:
	if action.is_empty():
		return fallback
	var label := String(action.get("label", action.get("button_label", fallback))).strip_edges()
	if label == "":
		return fallback
	return label

func _economy_delta_line(resources: Variant, empty_label: String) -> String:
	if not (resources is Dictionary):
		return empty_label
	var parts := []
	for resource_id_value in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(resource_id_value)
		var amount := int((resources as Dictionary).get(resource_id, 0))
		if amount > 0:
			parts.append("%s +%d" % [_economy_resource_label(resource_id), amount])
	return ", ".join(parts) if not parts.is_empty() else empty_label

func _economy_resource_label(resource_id: String) -> String:
	if resource_id == "":
		return "that resource"
	return resource_id.replace("_", " ").capitalize()

func _first_positive_resource_id(resources: Variant) -> String:
	if not (resources is Dictionary):
		return ""
	for resource_id_value in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var resource_id := String(resource_id_value)
		if int((resources as Dictionary).get(resource_id, 0)) > 0:
			return resource_id
	return ""

func _player_controlled_economy_site_count() -> int:
	var count := 0
	for node_value in _session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if String(node.get("controller_id", node.get("owner", ""))) == "player":
			count += 1
	return count

func _build_active_town_entity_view_state(minimal: bool = false) -> Dictionary:
	var current_lanes := _current_town_tab_lanes()
	var active_town := TownRules.get_active_town(_session)
	# The Resource Ledger needs both action models even when the first render only
	# builds the active tab. Retain only the identity, cost, and affordability data
	# that the ledger reads; contextual projection/impact copy remains on the full
	# action surfaces and follows their existing invalidation boundary.
	var full_build_actions := _duplicate_action_array(TownRules.get_build_actions(_session))
	var full_recruit_actions := _duplicate_action_array(TownRules.get_recruit_actions(_session))
	var economy_build_actions := _economy_build_action_models(full_build_actions)
	var economy_recruit_actions := _economy_recruit_action_models(full_recruit_actions)
	var build_action_copy_models := _build_action_copy_models(full_build_actions)
	var recruit_action_copy_models := _recruit_action_copy_models(full_recruit_actions)
	var economy_surface := _economy_readability_surface(economy_build_actions, economy_recruit_actions)
	var economy_context_surface := _economy_context_surface_from_readability(economy_surface)
	var stage_state := _build_town_stage_view_state(active_town)
	var departure_context_surface := {
		"town_name": TownRules._town_name(active_town),
		"front": OverworldRules.town_front_state(_session, active_town).duplicate(true),
		"occupation": OverworldRules.town_occupation_state(_session, active_town).duplicate(true),
		"logistics": _duplicate_dictionary(stage_state.get("logistics", {})),
		"recovery": _duplicate_dictionary(stage_state.get("recovery", {})),
	}
	var defense_check := _defense_check_surface()
	var production_overview := TownRules.describe_production_overview(_session) if (not minimal or current_lanes.has("build")) else ""
	var production_text := _production_overview_with_defense_check(
		production_overview,
		String(defense_check.get("visible_text", "")),
	)
	var specialty_readiness := {} if minimal else _specialty_readiness_surface()
	var specialties_text := "" if minimal else TownRules.describe_specialties(_session)
	var build_readiness := _build_readiness_surface() if (not minimal or current_lanes.has("build")) else {}
	var buildings_text := TownRules.describe_buildings(_session) if (not minimal or current_lanes.has("build")) else ""
	var market_readiness := _market_readiness_surface() if (not minimal or current_lanes.has("market")) else {}
	var market_text := TownRules.describe_market(_session) if (not minimal or current_lanes.has("market")) else ""
	var muster_readiness := _muster_readiness_surface() if (not minimal or current_lanes.has("recruit")) else {}
	var recruitment_text := TownRules.describe_recruitment(_session) if (not minimal or current_lanes.has("recruit")) else ""
	var hire_readiness := _hire_readiness_surface() if (not minimal or current_lanes.has("logistics")) else {}
	var tavern_text := TownRules.describe_tavern(_session) if (not minimal or current_lanes.has("logistics")) else ""
	var transfer_readiness := _transfer_readiness_surface() if (not minimal or current_lanes.has("logistics")) else {}
	var transfer_text := TownRules.describe_transfer(_session) if (not minimal or current_lanes.has("logistics")) else ""
	var response_readiness := _response_readiness_surface() if (not minimal or current_lanes.has("logistics")) else {}
	var response_text := TownRules.describe_responses(_session) if (not minimal or current_lanes.has("logistics")) else ""
	var study_readiness := _study_readiness_surface() if (not minimal or current_lanes.has("study")) else {}
	var study_text := TownRules.describe_spell_access(_session) if (not minimal or current_lanes.has("study")) else ""
	var artifact_readiness := _artifact_readiness_surface() if (not minimal or current_lanes.has("logistics")) else {}
	var artifact_text := TownRules.describe_artifacts(_session) if (not minimal or current_lanes.has("logistics")) else ""
	var departure := TownRules.town_departure_confirmation(_session)
	_last_departure_confirmation = departure.duplicate(true)
	var order_target := TownRules.town_order_target_handoff(_session)
	var dispatch_text := TownRules.describe_event_feed(_session, _last_message, _last_action_recap)
	var town_context_surface := {} if minimal else _town_action_context_surface(dispatch_text)
	return {
		"header_text": TownRules.describe_header(_session),
		"status_text": TownRules.describe_status(_session),
		"resources_text": OverworldRules.describe_resources(_session),
		"resources_tooltip_text": _resource_ledger_tooltip_text_from_surface(economy_surface),
		"economy_readability_surface": economy_surface.duplicate(true),
		"economy_context_surface": economy_context_surface.duplicate(true),
		"economy_build_actions": _duplicate_action_array(economy_build_actions),
		"economy_recruit_actions": _duplicate_action_array(economy_recruit_actions),
		"build_action_copy_models": build_action_copy_models.duplicate(true),
		"recruit_action_copy_models": recruit_action_copy_models.duplicate(true),
		"outlook_text": TownRules.describe_outlook_board(_session),
		"command_ledger_text": TownRules.describe_command_ledger(_session),
		"hero_text": OverworldRules.describe_hero(_session),
		"production_visible_text": production_text,
		"production_tooltip_text": _join_tooltip_sections([String(defense_check.get("tooltip_text", "")), production_overview]),
		"heroes_text": TownRules.describe_heroes(_session),
		"specialty_visible_text": _join_tooltip_sections([String(specialty_readiness.get("visible_text", "")), specialties_text]),
		"specialty_tooltip_text": _join_tooltip_sections([String(specialty_readiness.get("tooltip_text", "")), specialties_text]),
		"army_text": OverworldRules.describe_army(_session),
		"summary_text": TownRules.describe_summary(_session),
		"defense_text": TownRules.describe_defense(_session),
		"threats_text": TownRules.describe_threats(_session),
		"build_visible_text": _join_tooltip_sections([String(build_readiness.get("visible_text", "")), buildings_text]),
		"build_tooltip_text": _join_tooltip_sections([String(build_readiness.get("tooltip_text", "")), buildings_text]),
		"market_visible_text": _join_tooltip_sections([String(market_readiness.get("visible_text", "")), market_text]),
		"market_tooltip_text": _join_tooltip_sections([String(market_readiness.get("tooltip_text", "")), market_text]),
		"recruit_visible_text": _join_tooltip_sections([String(muster_readiness.get("visible_text", "")), recruitment_text]),
		"recruit_tooltip_text": _join_tooltip_sections([String(muster_readiness.get("tooltip_text", "")), recruitment_text]),
		"tavern_visible_text": _join_tooltip_sections([String(hire_readiness.get("visible_text", "")), tavern_text]),
		"tavern_tooltip_text": _join_tooltip_sections([String(hire_readiness.get("tooltip_text", "")), tavern_text]),
		"transfer_visible_text": _join_tooltip_sections([String(transfer_readiness.get("visible_text", "")), transfer_text]),
		"transfer_tooltip_text": _join_tooltip_sections([String(transfer_readiness.get("tooltip_text", "")), transfer_text]),
		"response_visible_text": _join_tooltip_sections([String(response_readiness.get("visible_text", "")), response_text]),
		"response_tooltip_text": _join_tooltip_sections([String(response_readiness.get("tooltip_text", "")), response_text]),
		"study_visible_text": _join_tooltip_sections([String(study_readiness.get("visible_text", "")), study_text]),
		"study_tooltip_text": _join_tooltip_sections([String(study_readiness.get("tooltip_text", "")), study_text]),
		"spellbook_text": OverworldRules.describe_spellbook(_session) if (not minimal or current_lanes.has("study")) else "",
		"artifact_visible_text": _join_tooltip_sections([String(artifact_readiness.get("visible_text", "")), artifact_text]),
		"artifact_tooltip_text": _join_tooltip_sections([String(artifact_readiness.get("tooltip_text", "")), artifact_text]),
		"dispatch_text": dispatch_text,
		"departure": departure,
		"departure_fallback_next_action": TownRules._next_town_action_line(_session, TownRules.get_active_town(_session)),
		"departure_context_surface": departure_context_surface.duplicate(true),
		"order_target": order_target,
		"town_context_surface": town_context_surface,
		"hero_actions": [] if minimal else _duplicate_action_array(TownRules.get_hero_actions(_session)),
		"build_actions": _duplicate_action_array(full_build_actions) if (not minimal or current_lanes.has("build")) else [],
		"market_actions": _duplicate_action_array(TownRules.get_market_actions(_session)) if (not minimal or current_lanes.has("market")) else [],
		"recruit_actions": _duplicate_action_array(full_recruit_actions) if (not minimal or current_lanes.has("recruit")) else [],
		"tavern_actions": _duplicate_action_array(TownRules.get_tavern_actions(_session)) if (not minimal or current_lanes.has("logistics")) else [],
		"transfer_actions": _duplicate_action_array(TownRules.get_transfer_actions(_session)) if (not minimal or current_lanes.has("logistics")) else [],
		"response_actions": _duplicate_action_array(TownRules.get_response_actions(_session)) if (not minimal or current_lanes.has("logistics")) else [],
		"study_actions": _duplicate_action_array(TownRules.get_spell_learning_actions(_session)) if (not minimal or current_lanes.has("study")) else [],
		"specialty_actions": [] if minimal else _duplicate_action_array(TownRules.get_specialty_actions(_session)),
		"artifact_actions": _duplicate_action_array(TownRules.get_artifact_actions(_session)) if (not minimal or current_lanes.has("logistics")) else [],
		"stage_state": stage_state,
	}

func _build_town_stage_view_state(town_override: Dictionary = {}) -> Dictionary:
	var town := town_override if not town_override.is_empty() else TownRules.get_active_town(_session)
	if town.is_empty():
		return {}
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	return {
		"town": _town_stage_town_payload(town),
		"town_template": town_template.duplicate(true),
		"faction": ContentService.get_faction(String(town_template.get("faction_id", ""))).duplicate(true),
		"stationed": HeroCommandRules.stationed_heroes(_session, town).duplicate(true),
		"build_actions": _duplicate_action_array(TownRules.get_build_actions(_session)),
		"recruit_actions": _duplicate_action_array(TownRules.get_recruit_actions(_session)),
		"response_actions": _duplicate_action_array(TownRules.get_response_actions(_session)),
		"study_actions": _duplicate_action_array(TownRules.get_spell_learning_actions(_session)),
		"market_actions": _duplicate_action_array(TownRules.get_market_actions(_session)),
		"logistics": OverworldRules.town_logistics_state(_session, town).duplicate(true),
		"recovery": OverworldRules.town_recovery_state(_session, town).duplicate(true),
		"threat": OverworldRules.town_public_threat_state(_session, town).duplicate(true),
		"occupation": OverworldRules.town_occupation_state(_session, town).duplicate(true),
		"front": OverworldRules.town_front_state(_session, town).duplicate(true),
	}

func _town_stage_town_payload(town: Dictionary) -> Dictionary:
	return {
		"placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"owner": String(town.get("owner", "")),
		"strategic_role": String(town.get("strategic_role", "")),
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
		"built_buildings": _normalize_string_array(town.get("built_buildings", [])),
		"garrison": _duplicate_action_array(town.get("garrison", [])),
		"available_recruits": _duplicate_dictionary(town.get("available_recruits", {})),
		"recovery": _duplicate_dictionary(town.get("recovery", {})),
		"front": _duplicate_dictionary(town.get("front", {})),
		"occupation": _duplicate_dictionary(town.get("occupation", {})),
		"market_state": _duplicate_dictionary(town.get("market_state", town.get("market", {}))),
		"response_state": _duplicate_dictionary(town.get("response_state", town.get("responses", {}))),
	}

func _refresh_town_stage_view(view_state: Dictionary) -> void:
	if _town_stage_view == null:
		return
	var stage_state: Dictionary = view_state.get("stage_state", {}) if view_state.get("stage_state", {}) is Dictionary else {}
	var stage_signature := _town_stage_signature(stage_state)
	if stage_signature != "" and stage_signature == _last_town_stage_signature:
		return
	_last_town_stage_signature = stage_signature
	if not stage_state.is_empty() and _town_stage_view.has_method("set_precomputed_town_state"):
		_town_stage_view.call("set_precomputed_town_state", _session, stage_state)
	else:
		_town_stage_view.set_town_state(_session)

func _town_stage_signature(stage_state: Dictionary) -> String:
	if stage_state.is_empty():
		return ""
	var town: Dictionary = stage_state.get("town", {}) if stage_state.get("town", {}) is Dictionary else {}
	var logistics: Dictionary = stage_state.get("logistics", {}) if stage_state.get("logistics", {}) is Dictionary else {}
	var threat: Dictionary = stage_state.get("threat", {}) if stage_state.get("threat", {}) is Dictionary else {}
	var occupation: Dictionary = stage_state.get("occupation", {}) if stage_state.get("occupation", {}) is Dictionary else {}
	var front: Dictionary = stage_state.get("front", {}) if stage_state.get("front", {}) is Dictionary else {}
	return "|".join([
		String(town.get("placement_id", "")),
		String(town.get("town_id", "")),
		String(town.get("owner", "")),
		_string_array_signature(town.get("built_buildings", [])),
		_stack_collection_signature(town.get("garrison", [])),
		_scalar_pairs_signature(town.get("available_recruits", {})),
		_scalar_pairs_signature(logistics),
		_scalar_pairs_signature(threat),
		_scalar_pairs_signature(occupation),
		_scalar_pairs_signature(front),
		str(_collection_size(stage_state.get("stationed", []))),
		str(_collection_size(stage_state.get("build_actions", []))),
		str(_collection_size(stage_state.get("recruit_actions", []))),
		str(_collection_size(stage_state.get("response_actions", []))),
		str(_collection_size(stage_state.get("study_actions", []))),
		str(_collection_size(stage_state.get("market_actions", []))),
	])

func _collection_size(value: Variant) -> int:
	if value is Array or value is Dictionary:
		return value.size()
	return 0

func _town_entity_cache_signature(town: Dictionary, minimal: bool) -> String:
	if _session == null:
		return "v6|missing-session"
	var parts := []
	var active_tab := _management_tabs.current_tab if _management_tabs != null else -1
	parts.append("v6")
	parts.append("mode:%s" % ("minimal" if minimal else "full"))
	if minimal:
		parts.append("tab:%d" % active_tab)
	parts.append("day:%d" % int(_session.day))
	parts.append("pid:%s" % _signature_token(town.get("placement_id", "")))
	parts.append("town:%s" % _signature_token(town.get("town_id", "")))
	parts.append("owner:%s" % _signature_token(town.get("owner", "")))
	parts.append("role:%s" % _signature_token(town.get("strategic_role", "")))
	parts.append("built:%s" % _string_array_signature(town.get("built_buildings", [])))
	parts.append("recruits:%s" % _scalar_pairs_signature(town.get("available_recruits", {})))
	parts.append("garrison:%s" % _stack_collection_signature(town.get("garrison", [])))
	parts.append("recovery:%s" % _compact_local_state_signature(town.get("recovery", {})))
	parts.append("front:%s" % _compact_local_state_signature(town.get("front", {})))
	parts.append("occupation:%s" % _compact_local_state_signature(town.get("occupation", {})))
	parts.append("market:%s" % _compact_local_state_signature(town.get("market_state", town.get("market", {}))))
	parts.append("response:%s" % _compact_local_state_signature(town.get("response_state", town.get("responses", {}))))
	parts.append("economy_context:%s" % _town_economy_context_signature())
	return "|".join(parts)

func _town_economy_context_signature() -> String:
	var hero: Dictionary = _session.overworld.get("hero", {}) if _session.overworld.get("hero", {}) is Dictionary else {}
	var resolved_encounters := _normalize_string_array(_session.overworld.get("resolved_encounters", []))
	resolved_encounters.sort()
	var town_links := []
	for town_value in _session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var linked_town: Dictionary = town_value
		town_links.append({
			"placement_id": String(linked_town.get("placement_id", "")),
			"owner": String(linked_town.get("owner", "")),
			"x": int(linked_town.get("x", 0)),
			"y": int(linked_town.get("y", 0)),
		})
	var context := {
		"town_links": town_links,
		"resource_nodes": _session.overworld.get("resource_nodes", []),
		"encounters": _session.overworld.get("encounters", []),
		"resolved_encounters": resolved_encounters,
		"active_hero_id": String(_session.overworld.get("active_hero_id", hero.get("id", ""))),
		"active_hero_level": int(hero.get("level", 0)),
		"active_hero_command": _duplicate_dictionary(hero.get("command", {})),
	}
	return JSON.stringify(context).sha256_text()

func _active_hero_cache_signature(town: Dictionary) -> String:
	var hero: Dictionary = _session.overworld.get("hero", {}) if _session.overworld.get("hero", {}) is Dictionary else {}
	var parts := []
	parts.append("id=%s" % _signature_token(_session.overworld.get("active_hero_id", hero.get("id", ""))))
	parts.append("hero=%s" % _signature_token(hero.get("id", "")))
	parts.append("level=%d" % int(hero.get("level", 0)))
	parts.append("xp=%d" % int(hero.get("experience", 0)))
	var movement: Dictionary = hero.get("movement", {}) if hero.get("movement", {}) is Dictionary else {}
	var overworld_movement: Dictionary = _session.overworld.get("movement", {}) if _session.overworld.get("movement", {}) is Dictionary else {}
	parts.append("move=%d/%d" % [
		int(movement.get("current", overworld_movement.get("current", 0))),
		int(movement.get("max", overworld_movement.get("max", 0))),
	])
	parts.append("pos=%s" % _position_signature(hero.get("position", _session.overworld.get("hero_position", {}))))
	parts.append("army=%s" % _army_state_signature(hero.get("army", {})))
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	parts.append("spells=%s" % _string_array_signature(spellbook.get("known_spell_ids", [])))
	parts.append("specialties=%s" % _string_array_signature(hero.get("specialties", [])))
	parts.append("pending_specialties=%s" % _string_array_signature(hero.get("pending_specialty_choices", [])))
	parts.append("artifacts=%s" % _artifact_state_signature(hero.get("artifacts", {})))
	parts.append("town_pos=%s" % _position_signature({"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}))
	return ",".join(parts)

func _stationed_heroes_cache_signature(town: Dictionary) -> String:
	var heroes_value: Variant = _session.overworld.get("player_heroes", [])
	if not (heroes_value is Array):
		return "count=0"
	var town_x := int(town.get("x", 0))
	var town_y := int(town.get("y", 0))
	var stationed := []
	var all_ids := []
	for hero_value in heroes_value:
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		var hero_id := String(hero.get("id", ""))
		if hero_id == "":
			continue
		all_ids.append(_signature_token(hero_id))
		var position: Dictionary = hero.get("position", {}) if hero.get("position", {}) is Dictionary else {}
		if int(position.get("x", -999999)) != town_x or int(position.get("y", -999999)) != town_y:
			continue
		var entry := []
		entry.append(_signature_token(hero_id))
		entry.append("lvl%d" % int(hero.get("level", 0)))
		entry.append(_army_state_signature(hero.get("army", {})))
		stationed.append(":".join(entry))
	all_ids.sort()
	stationed.sort()
	return "count=%d,ids=%s,local=%s" % [
		heroes_value.size(),
		".".join(all_ids),
		".".join(stationed),
	]

func _town_action_recap_cache_signature() -> String:
	var parts := []
	parts.append("msg=%d" % String(_last_message).hash())
	parts.append("active=%d" % (1 if bool(_last_action_recap.get("active", false)) else 0))
	parts.append("kind=%s" % _signature_token(_last_action_recap.get("kind", "")))
	parts.append("action=%s" % _signature_token(_last_action_recap.get("action_id", "")))
	parts.append("text=%d" % String(_last_action_recap.get("text", "")).hash())
	return ",".join(parts)

func _compact_local_state_signature(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var state: Dictionary = value
	var keys := [
		"active",
		"id",
		"kind",
		"state",
		"status",
		"owner",
		"controller_id",
		"source_id",
		"target_id",
		"action_id",
		"action_label",
		"remaining_days",
		"days_remaining",
		"expires_day",
		"last_event_day",
		"pressure",
		"progress_complete",
		"progress_total",
		"relief_per_day",
		"watch_days",
	]
	var parts := []
	for key in keys:
		if state.has(key):
			parts.append("%s=%s" % [_signature_token(key), _signature_scalar_value(state.get(key))])
	if parts.is_empty():
		return _scalar_pairs_signature(state)
	return ",".join(parts)

func _scalar_pairs_signature(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var dictionary: Dictionary = value
	var keys := []
	for key_value in dictionary.keys():
		keys.append(String(key_value))
	keys.sort()
	var pairs := []
	for key in keys:
		pairs.append("%s=%s" % [_signature_token(key), _signature_scalar_value(dictionary.get(key))])
	return ",".join(pairs)

func _signature_scalar_value(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "1" if bool(value) else "0"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return "%.3f" % float(value)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return _signature_token(value)
		TYPE_VECTOR2I:
			var tile: Vector2i = value
			return "%d.%d" % [tile.x, tile.y]
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			if dictionary.has("unit_id") or dictionary.has("count"):
				return _stack_signature(dictionary)
			if dictionary.has("x") or dictionary.has("y"):
				return _position_signature(dictionary)
			return _scalar_pairs_signature(dictionary)
		TYPE_ARRAY:
			return _scalar_array_signature(value)
		_:
			return _signature_token(value)

func _scalar_array_signature(value: Variant) -> String:
	if not (value is Array):
		return ""
	var entries := []
	for entry in value:
		entries.append(_signature_scalar_value(entry))
	entries.sort()
	return ".".join(entries)

func _string_array_signature(value: Variant) -> String:
	var normalized := _normalize_string_array(value)
	normalized.sort()
	var entries := []
	for entry in normalized:
		entries.append(_signature_token(entry))
	return ".".join(entries)

func _army_state_signature(value: Variant) -> String:
	if value is Dictionary:
		var army: Dictionary = value
		if army.has("stacks"):
			return _stack_collection_signature(army.get("stacks", []))
		return _scalar_pairs_signature(army)
	if value is Array:
		return _stack_collection_signature(value)
	return ""

func _stack_collection_signature(value: Variant) -> String:
	if value is Dictionary:
		return _scalar_pairs_signature(value)
	if not (value is Array):
		return ""
	var stacks := []
	for stack_value in value:
		if stack_value is Dictionary:
			stacks.append(_stack_signature(stack_value))
	stacks.sort()
	return ".".join(stacks)

func _stack_signature(stack: Dictionary) -> String:
	return "%s:%d:%d" % [
		_signature_token(stack.get("unit_id", stack.get("id", ""))),
		int(stack.get("count", 0)),
		int(stack.get("wounded", stack.get("damage", 0))),
	]

func _artifact_state_signature(value: Variant) -> String:
	if value is Dictionary:
		var artifacts: Dictionary = value
		var ids := []
		for key_value in artifacts.keys():
			var artifact_value = artifacts.get(key_value)
			if artifact_value is Dictionary:
				ids.append("%s=%s" % [_signature_token(key_value), _signature_token(artifact_value.get("id", ""))])
			elif artifact_value is Array:
				ids.append("%s=%s" % [_signature_token(key_value), _string_array_signature(artifact_value)])
			else:
				ids.append("%s=%s" % [_signature_token(key_value), _signature_token(artifact_value)])
		ids.sort()
		return ".".join(ids)
	if value is Array:
		return _string_array_signature(value)
	return ""

func _position_signature(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var position: Dictionary = value
	return "%d.%d" % [int(position.get("x", 0)), int(position.get("y", 0))]

func _signature_token(value: Variant) -> String:
	return String(value).replace("\\", "\\\\").replace("|", "\\p").replace(",", "\\m").replace("=", "\\e").replace(":", "\\c")

func _town_entity_session_cache_key() -> String:
	if _session == null:
		return ""
	return "%s|%s" % [String(_session.session_id), String(_session.scenario_id)]

func _town_entity_cache_entry_key(placement_id: String, minimal: bool) -> String:
	return "%s|%s" % [placement_id, "minimal" if minimal else "full"]

func _town_entity_cache_has_placement(bucket: Dictionary, placement_id: String) -> bool:
	if placement_id == "":
		return false
	for key_value in bucket.keys():
		var entry: Dictionary = bucket.get(key_value, {}) if bucket.get(key_value, {}) is Dictionary else {}
		if String(entry.get("placement_id", "")) == placement_id:
			return true
		if String(key_value) == placement_id or String(key_value).begins_with("%s|" % placement_id):
			return true
	return false

func _town_entity_cached_placements(bucket: Dictionary) -> Array:
	var by_id := {}
	for key_value in bucket.keys():
		var entry: Dictionary = bucket.get(key_value, {}) if bucket.get(key_value, {}) is Dictionary else {}
		var placement_id := String(entry.get("placement_id", ""))
		if placement_id == "":
			placement_id = String(key_value).split("|", false, 1)[0]
		if placement_id != "":
			by_id[placement_id] = true
	var placements := []
	for placement_id in by_id.keys():
		placements.append(String(placement_id))
	placements.sort()
	return placements

func _invalidate_active_town_entity_cache(reason: String, scopes: Array = []) -> void:
	if _session == null:
		return
	var placement_id := String(_session.flags.get(OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY, ""))
	if placement_id == "":
		var town := TownRules.get_active_town(_session)
		placement_id = String(town.get("placement_id", "")) if town is Dictionary else ""
	if placement_id == "":
		return
	var session_key := _town_entity_session_cache_key()
	var bucket: Dictionary = _town_entity_cache_by_session.get(session_key, {}) if _town_entity_cache_by_session.get(session_key, {}) is Dictionary else {}
	for key_value in bucket.keys().duplicate():
		var key := String(key_value)
		var entry: Dictionary = bucket.get(key_value, {}) if bucket.get(key_value, {}) is Dictionary else {}
		if key == placement_id or key.begins_with("%s|" % placement_id) or String(entry.get("placement_id", "")) == placement_id:
			bucket.erase(key_value)
	_town_entity_cache_by_session[session_key] = bucket
	_last_town_entity_cache_result = {
		"hit": false,
		"invalidated": true,
		"reason": reason,
		"scopes": scopes.duplicate(),
		"placement_id": placement_id,
		"entry_count": bucket.size(),
	}

func _configure_save_slot_picker() -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))

func _refresh_save_slot_picker(force_surface: bool = false, view_state: Dictionary = {}) -> void:
	_last_save_surface_profile = {
		"forced": force_surface,
		"skipped_hidden": false,
		"mode": "full" if force_surface else "lazy_hidden",
	}
	if _save_slot_picker.get_item_count() <= 0:
		return

	var selected_slot := SaveService.get_selected_manual_slot()
	for index in range(_save_slot_picker.get_item_count()):
		if _save_slot_picker.get_item_id(index) == selected_slot:
			_save_slot_picker.select(index)
			break

	if not force_surface:
		_last_save_surface_profile["skipped_hidden"] = true
		_save_status_label.visible = false
		_save_status_label.text = ""
		_save_status_label.tooltip_text = "Save details are refreshed when the save controls are used."
		_save_slot_picker.tooltip_text = "Manual %d selected. Save details are refreshed when the save controls are used." % selected_slot
		_save_button.text = "Save Town"
		_save_button.tooltip_text = "Save the active town visit to the selected manual slot."
		var lazy_departure: Dictionary = view_state.get("departure", {}) if view_state.get("departure", {}) is Dictionary else {}
		if lazy_departure.is_empty():
			lazy_departure = TownRules.town_departure_confirmation(_session)
		_last_departure_confirmation = lazy_departure.duplicate(true)
		_leave_button.text = String(lazy_departure.get("button_label", "Leave"))
		_leave_button.tooltip_text = String(lazy_departure.get("tooltip_text", "Return to the overworld without leaving the current expedition."))
		_menu_button.text = "Main Menu"
		_menu_button.tooltip_text = "Return to the main menu after updating autosave."
		return

	var surface := AppRouter.active_save_surface()

	var summary_value: Variant = surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
	var summary: Dictionary = summary_value if summary_value is Dictionary else SaveService.inspect_manual_slot(selected_slot)
	var latest_context := String(surface.get("latest_context", "Latest ready save: none."))
	var save_check := String(surface.get("save_check", ""))
	var save_handoff := String(surface.get("save_handoff", ""))
	var save_handoff_brief := String(surface.get("save_handoff_brief", ""))
	var return_handoff := String(surface.get("return_handoff", ""))
	var current_save_recap := String(surface.get("current_save_recap", ""))
	_save_status_label.visible = save_handoff_brief != ""
	_save_status_label.text = save_handoff_brief if save_handoff_brief != "" else latest_context
	var current_context := String(surface.get("current_context", ""))
	var save_tooltip_lines := [latest_context]
	if save_handoff != "":
		save_tooltip_lines.append(save_handoff)
	if save_check != "":
		save_tooltip_lines.append(save_check)
	if return_handoff != "":
		save_tooltip_lines.append(return_handoff)
	if current_save_recap != "":
		save_tooltip_lines.append("Saving now recap:\n%s" % current_save_recap)
	if current_context != "":
		save_tooltip_lines.append("Saving now: %s" % current_context)
	save_tooltip_lines.append("Selected slot:\n%s" % SaveService.describe_slot_details(summary))
	_save_status_label.tooltip_text = "\n".join(save_tooltip_lines)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Town"))
	_save_button.tooltip_text = _join_tooltip_sections([
		String(surface.get("save_button_tooltip", "Save the active town visit safely.")),
		save_handoff,
		save_check,
	])
	var departure := _last_departure_confirmation.duplicate(true)
	_last_save_surface_profile["departure_reused"] = not departure.is_empty()
	if departure.is_empty():
		departure = TownRules.town_departure_confirmation(_session)
	_last_departure_confirmation = departure.duplicate(true)
	_leave_button.text = String(departure.get("button_label", "Leave"))
	_leave_button.tooltip_text = String(departure.get("tooltip_text", "Return to the overworld without leaving the current expedition."))
	_menu_button.text = String(surface.get("menu_button_label", "Main Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func validation_snapshot() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var occupation := OverworldRules.town_occupation_state(_session, town)
	var front := OverworldRules.town_front_state(_session, town)
	var handoff := TownRules.town_handoff_recap(_session)
	var departure := TownRules.town_departure_confirmation(_session)
	var order_target := TownRules.town_order_target_handoff(_session)
	var dispatch_text := TownRules.describe_event_feed(_session, _last_message, _last_action_recap)
	var town_context_surface := _town_action_context_surface(dispatch_text)
	var tab_readiness := _management_tab_readiness_payload()
	var build_readiness := _build_readiness_surface()
	var market_readiness := _market_readiness_surface()
	var muster_readiness := _muster_readiness_surface()
	var transfer_readiness := _transfer_readiness_surface()
	var study_readiness := _study_readiness_surface()
	var hire_readiness := _hire_readiness_surface()
	var artifact_readiness := _artifact_readiness_surface()
	var specialty_readiness := _specialty_readiness_surface()
	var response_readiness := _response_readiness_surface()
	var defense_check := _defense_check_surface()
	return {
		"scene_path": scene_file_path,
		"music_audio": MusicAudio.validation_summary(),
		"town_music_metadata": _town_music_metadata(),
		"manual_save_overwrite_dialog": _manual_save_overwrite_dialog.validation_snapshot(),
		"return_to_menu_last_result": _last_return_to_menu_result.duplicate(true),
		"return_to_menu_visible_message": _last_message,
		"return_to_menu_focus_owner": _return_to_menu_focus_owner_name(),
		"return_to_menu_request_count": _validation_return_to_menu_request_count,
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"scenario_status": _session.scenario_status,
		"game_state": _session.game_state,
		"day": _session.day,
		"town_placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"town_owner": String(town.get("owner", "")),
		"faction_crest": _faction_crest_validation_snapshot(),
		"built_building_count": _normalize_string_array(town.get("built_buildings", [])).size(),
		"available_recruits": _duplicate_dictionary(town.get("available_recruits", {})),
		"resources": _duplicate_dictionary(_session.overworld.get("resources", {})),
		"live_stockpile_resource_ids": OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS.duplicate(),
		"resources_text": OverworldRules.describe_resources(_session),
		"resources_visible_text": _resource_label.text,
		"resources_tooltip_text": _resource_label.tooltip_text,
		"resources_full_ledger_text": OverworldRules.describe_resource_stockpile(_session.overworld.get("resources", {}), true),
		"resource_stockpile_menu": _resource_label.validation_snapshot(),
		"hero_text": OverworldRules.describe_hero(_session),
		"hero_portrait": _hero_portrait.validation_snapshot(),
		"hero_visible_text": _hero_label.text,
		"hero_tooltip_text": _hero_label.tooltip_text,
		"heroes_text": TownRules.describe_heroes(_session),
		"heroes_visible_text": _heroes_label.text,
		"heroes_tooltip_text": _heroes_label.tooltip_text,
		"specialty_text": TownRules.describe_specialties(_session),
		"specialty_visible_text": _specialty_label.text if _specialty_label.text.strip_edges() != "" else _join_tooltip_sections([String(specialty_readiness.get("visible_text", "")), TownRules.describe_specialties(_session)]),
		"specialty_tooltip_text": _specialty_label.tooltip_text if _specialty_label.tooltip_text.strip_edges() != "" else _join_tooltip_sections([String(specialty_readiness.get("tooltip_text", "")), TownRules.describe_specialties(_session)]),
		"specialty_readiness": specialty_readiness,
		"specialty_readiness_visible_text": String(specialty_readiness.get("visible_text", "")),
		"specialty_readiness_tooltip_text": String(specialty_readiness.get("tooltip_text", "")),
		"specialty_actions": _duplicate_action_array(TownRules.get_specialty_actions(_session)),
		"summary": TownRules.describe_summary(_session),
		"production_overview": TownRules.describe_production_overview(_session),
		"visible_production_overview": _production_overview_label.text,
		"production_overview_tooltip_text": _production_overview_label.tooltip_text,
		"defense_check": defense_check,
		"defense_check_visible_text": String(defense_check.get("visible_text", "")),
		"defense_check_tooltip_text": String(defense_check.get("tooltip_text", "")),
		"army_text": OverworldRules.describe_army(_session),
		"army_visible_text": _army_label.text,
		"defense_text": TownRules.describe_defense(_session),
		"defense_visible_text": _defense_label.text,
		"build_text": TownRules.describe_buildings(_session),
		"build_visible_text": _building_label.text,
		"build_tooltip_text": _building_label.tooltip_text,
		"build_readiness": build_readiness,
		"build_readiness_visible_text": String(build_readiness.get("visible_text", "")),
		"build_readiness_tooltip_text": String(build_readiness.get("tooltip_text", "")),
		"selected_build_action_id": _selected_build_action_id,
		"selected_build_action": _duplicate_dictionary(_selected_build_action()),
		"build_plan_visible_text": _build_plan_label.text,
		"build_plan_tooltip_text": _build_plan_label.tooltip_text,
		"confirm_build_button_text": _confirm_build_button.text,
		"confirm_build_button_tooltip_text": _confirm_build_button.tooltip_text,
		"confirm_build_button_disabled": _confirm_build_button.disabled,
		"town_catalog": validation_town_catalog_snapshot(),
		"build_catalog": _duplicate_action_array(TownRules.get_build_catalog(_session)),
		"muster_catalog": _duplicate_action_array(TownRules.get_muster_catalog(_session)),
		"narrow_layout_active": _narrow_layout_active,
		"narrow_orders_open": _narrow_orders_open,
		"town_orders_toggle_visible": _town_orders_toggle_button.visible,
		"town_orders_toggle_text": _town_orders_toggle_button.text,
		"market_text": TownRules.describe_market(_session),
		"market_visible_text": _market_label.text if _market_label.text.strip_edges() != "" else String(market_readiness.get("visible_text", "")),
		"market_tooltip_text": _market_label.tooltip_text if _market_label.tooltip_text.strip_edges() != "" else String(market_readiness.get("tooltip_text", "")),
		"market_readiness": market_readiness,
		"market_readiness_visible_text": String(market_readiness.get("visible_text", "")),
		"market_readiness_tooltip_text": String(market_readiness.get("tooltip_text", "")),
		"recruit_text": TownRules.describe_recruitment(_session),
		"recruit_visible_text": _recruit_label.text if _recruit_label.text.strip_edges() != "" else _join_tooltip_sections([String(muster_readiness.get("visible_text", "")), TownRules.describe_recruitment(_session)]),
		"recruit_tooltip_text": _recruit_label.tooltip_text if _recruit_label.tooltip_text.strip_edges() != "" else _join_tooltip_sections([String(muster_readiness.get("tooltip_text", "")), TownRules.describe_recruitment(_session)]),
		"muster_readiness": muster_readiness,
		"muster_readiness_visible_text": String(muster_readiness.get("visible_text", "")),
		"muster_readiness_tooltip_text": String(muster_readiness.get("tooltip_text", "")),
		"study_text": TownRules.describe_spell_access(_session),
		"study_visible_text": _study_label.text,
		"study_tooltip_text": _study_label.tooltip_text,
		"study_readiness": study_readiness,
		"study_readiness_visible_text": String(study_readiness.get("visible_text", "")),
		"study_readiness_tooltip_text": String(study_readiness.get("tooltip_text", "")),
		"spellbook_text": OverworldRules.describe_spellbook(_session),
		"spellbook_visible_text": _spellbook_label.text,
		"spellbook_tooltip_text": _spellbook_label.tooltip_text,
		"tavern_text": TownRules.describe_tavern(_session),
		"tavern_visible_text": _tavern_label.text if _tavern_label.text.strip_edges() != "" else _join_tooltip_sections([String(hire_readiness.get("visible_text", "")), TownRules.describe_tavern(_session)]),
		"tavern_tooltip_text": _tavern_label.tooltip_text if _tavern_label.tooltip_text.strip_edges() != "" else _join_tooltip_sections([String(hire_readiness.get("tooltip_text", "")), TownRules.describe_tavern(_session)]),
		"hire_readiness": hire_readiness,
		"hire_readiness_visible_text": String(hire_readiness.get("visible_text", "")),
		"hire_readiness_tooltip_text": String(hire_readiness.get("tooltip_text", "")),
		"transfer_text": TownRules.describe_transfer(_session),
		"transfer_visible_text": _transfer_label.text if _transfer_label.text.strip_edges() != "" else _join_tooltip_sections([String(transfer_readiness.get("visible_text", "")), TownRules.describe_transfer(_session)]),
		"transfer_tooltip_text": _transfer_label.tooltip_text if _transfer_label.tooltip_text.strip_edges() != "" else _join_tooltip_sections([String(transfer_readiness.get("tooltip_text", "")), TownRules.describe_transfer(_session)]),
		"transfer_readiness": transfer_readiness,
		"transfer_readiness_visible_text": String(transfer_readiness.get("visible_text", "")),
		"transfer_readiness_tooltip_text": String(transfer_readiness.get("tooltip_text", "")),
		"transfer_actions": _duplicate_action_array(TownRules.get_transfer_actions(_session)),
		"army_management": _army_management.validation_snapshot(),
		"response_text": TownRules.describe_responses(_session),
		"response_visible_text": _response_label.text if _response_label.text.strip_edges() != "" else _join_tooltip_sections([String(response_readiness.get("visible_text", "")), TownRules.describe_responses(_session)]),
		"response_tooltip_text": _response_label.tooltip_text if _response_label.tooltip_text.strip_edges() != "" else _join_tooltip_sections([String(response_readiness.get("tooltip_text", "")), TownRules.describe_responses(_session)]),
		"response_readiness": response_readiness,
		"response_readiness_visible_text": String(response_readiness.get("visible_text", "")),
		"response_readiness_tooltip_text": String(response_readiness.get("tooltip_text", "")),
		"response_actions": _duplicate_action_array(TownRules.get_response_actions(_session)),
		"artifact_text": TownRules.describe_artifacts(_session),
		"artifact_visible_text": _artifact_label.text,
		"artifact_tooltip_text": _artifact_label.tooltip_text,
		"artifact_readiness": artifact_readiness,
		"artifact_readiness_visible_text": String(artifact_readiness.get("visible_text", "")),
		"artifact_readiness_tooltip_text": String(artifact_readiness.get("tooltip_text", "")),
		"artifact_actions": _duplicate_action_array(TownRules.get_artifact_actions(_session)),
		"town_action_recap": _duplicate_dictionary(_last_action_recap),
		"town_action_recap_text": String(_last_action_recap.get("text", "")),
		"town_handoff": handoff,
		"town_handoff_visible_text": String(handoff.get("visible_text", "")),
		"town_handoff_tooltip_text": String(handoff.get("tooltip_text", "")),
		"town_departure_confirmation": departure,
		"town_departure_visible_text": String(departure.get("visible_text", "")),
		"town_order_target_handoff": order_target,
		"town_order_target_visible_text": String(order_target.get("visible_text", "")),
		"town_order_target_tooltip_text": String(order_target.get("tooltip_text", "")),
		"town_action_context": town_context_surface,
		"town_action_context_text": String(town_context_surface.get("visible_text", "")),
		"town_action_context_tooltip_text": String(town_context_surface.get("tooltip_text", "")),
		"town_tab_readiness": tab_readiness,
		"town_tab_titles": _management_tab_titles(),
		"town_tab_readiness_tooltip_text": _management_tabs.tooltip_text,
		"town_action_button_tooltips": _town_action_button_tooltip_snapshot(),
		"town_active_tab": _management_tabs.current_tab,
		"leave_button_text": _leave_button.text,
		"leave_button_tooltip_text": _leave_button.tooltip_text,
		"town_guide": _town_guide_validation_snapshot(),
		"save_surface": AppRouter.active_save_surface(),
		"save_handoff_visible_text": _save_status_label.text if _save_status_label.text.strip_edges() != "" else String(AppRouter.active_save_surface().get("save_handoff_brief", "")),
		"save_handoff_visible": _save_status_label.text.strip_edges() != "" or String(AppRouter.active_save_surface().get("save_handoff_brief", "")).strip_edges() != "",
		"save_button_text": _save_button.text,
		"save_button_tooltip_text": _save_button.tooltip_text,
		"save_status_visible_text": _save_status_label.text,
		"save_status_tooltip_text": _save_status_label.tooltip_text,
		"visible_consequence_text": _event_label.text,
		"consequence_tooltip_text": _event_label.tooltip_text,
		"front": front,
		"occupation": occupation,
		"base_income": OverworldRules.town_income(town),
		"income": OverworldRules.town_income(town, _session),
		"base_battle_readiness": OverworldRules.town_battle_readiness(town),
		"battle_readiness": OverworldRules.town_battle_readiness(town, _session),
		"frontier_watch": OverworldRules.describe_frontier_threats(_session),
		"build_action_count": TownRules.get_build_actions(_session).size(),
		"recruit_action_count": TownRules.get_recruit_actions(_session).size(),
		"study_action_count": TownRules.get_spell_learning_actions(_session).size(),
		"latest_save_summary": SaveService.latest_loadable_summary(),
	}

func _town_guide_validation_snapshot() -> Dictionary:
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return {
		"open": _town_guide_is_open(),
		"button_text": _guide_button.text,
		"button_tooltip_text": _guide_button.tooltip_text,
		"title_text": _guide_title_label.text,
		"guide_text": _guide_label.text,
		"guide_tooltip_text": _guide_label.tooltip_text,
		"expected_guide_text": SettingsService.describe_help_topic("town"),
		"overlay_mouse_filter": _guide_overlay.mouse_filter,
		"overlay_rect": _guide_overlay.get_global_rect(),
		"panel_rect": _guide_panel.get_global_rect(),
		"close_button_rect": _guide_close_button.get_global_rect(),
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"close_has_focus": _guide_close_button.has_focus(),
		"narrow_layout_active": _narrow_layout_active,
		"narrow_orders_open": _narrow_orders_open,
	}


func _live_player_hero_id() -> String:
	var hero = _session.overworld.get("hero", {})
	if hero is Dictionary and String(hero.get("id", "")) != "":
		return String(hero.get("id", ""))
	return String(_session.overworld.get("active_hero_id", ""))

func validation_army_management_snapshot() -> Dictionary:
	return _army_management.validation_snapshot()

func validation_open_town_catalog(mode: String) -> Dictionary:
	_open_town_catalog(mode)
	return validation_town_catalog_snapshot()

func validation_close_town_catalog() -> Dictionary:
	_close_town_catalog()
	return validation_town_catalog_snapshot()

func validation_town_catalog_snapshot() -> Dictionary:
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var build_catalog := TownRules.get_build_catalog(_session) if _session != null else []
	var muster_catalog := TownRules.get_muster_catalog(_session) if _session != null else []
	return {
		"open": _town_catalog_is_open(),
		"mode": _town_catalog_mode,
		"title": _town_catalog_title_label.text,
		"subtitle": _town_catalog_subtitle_label.text,
		"build_catalog_count": build_catalog.size(),
		"muster_catalog_count": muster_catalog.size(),
		"build_card_count": _build_actions.get_child_count(),
		"muster_card_count": _recruit_actions.get_child_count(),
		"build_ids": _catalog_ids(build_catalog, "building_id"),
		"muster_ids": _catalog_ids(muster_catalog, "unit_id"),
		"build_statuses": _catalog_status_counts(build_catalog),
		"muster_statuses": _catalog_status_counts(muster_catalog),
		"panel_rect": _town_catalog_panel.get_global_rect(),
		"overlay_rect": _town_catalog_overlay.get_global_rect(),
		"build_grid_visible": _build_actions.visible,
		"muster_grid_visible": _recruit_actions.visible,
		"confirm_build_visible": _confirm_build_button.visible,
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"focus_inside": focus_owner != null and _town_catalog_overlay.is_ancestor_of(focus_owner),
	}

func _catalog_ids(rows: Array, key: String) -> Array:
	var ids := []
	for row_value in rows:
		if row_value is Dictionary:
			ids.append(String(row_value.get(key, "")))
	return ids

func _catalog_status_counts(rows: Array) -> Dictionary:
	var counts := {}
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var status := String(row_value.get("catalog_status", "Unknown"))
		counts[status] = int(counts.get(status, 0)) + 1
	return counts

func validation_perform_army_slot_operation(
	source_holder_id: String,
	source_slot_index: int,
	target_holder_id: String,
	target_slot_index: int,
	amount_token: String = "all"
) -> Dictionary:
	var result := TownRules.manage_army_slots_in_active_town(
		_session,
		source_holder_id,
		source_slot_index,
		target_holder_id,
		target_slot_index,
		amount_token
	)
	_last_message = String(result.get("message", ""))
	_army_management.clear_selection()
	_invalidate_active_town_entity_cache("army_slots_validation", ["town", "hero_army"])
	_refresh()
	result["snapshot"] = _army_management.validation_snapshot()
	return result

func validation_try_progress_action() -> Dictionary:
	var before_signature := JSON.stringify(_validation_progress_signature())
	var lanes := [
		{"lane": "recruit", "actions": TownRules.get_recruit_actions(_session)},
		{"lane": "build", "actions": TownRules.get_build_actions(_session)},
		{"lane": "study", "actions": TownRules.get_spell_learning_actions(_session)},
		{"lane": "market", "actions": TownRules.get_market_actions(_session)},
		{"lane": "response", "actions": TownRules.get_response_actions(_session)},
		{"lane": "tavern", "actions": TownRules.get_tavern_actions(_session)},
		{"lane": "transfer", "actions": TownRules.get_transfer_actions(_session)},
		{"lane": "artifact", "actions": TownRules.get_artifact_actions(_session)},
		{"lane": "specialty", "actions": TownRules.get_specialty_actions(_session)},
		{"lane": "hero", "actions": TownRules.get_hero_actions(_session)},
	]

	for lane_entry in lanes:
		if not (lane_entry is Dictionary):
			continue
		var action := _first_enabled_validation_action(lane_entry.get("actions", []))
		if action.is_empty():
			continue
		var lane := String(lane_entry.get("lane", ""))
		var action_id := String(action.get("id", ""))
		match lane:
			"recruit":
				_on_recruit_action_pressed(action_id.trim_prefix("recruit:"))
			"build":
				_commit_build_action(action_id.trim_prefix("build:"))
			"study":
				_on_study_action_pressed(action_id.trim_prefix("learn_spell:"))
			"market":
				_on_market_action_pressed(action_id)
			"response":
				_on_response_action_pressed(action_id)
			"tavern":
				_on_tavern_action_pressed(action_id)
			"transfer":
				_on_transfer_action_pressed(action_id)
			"artifact":
				_on_artifact_action_pressed(action_id)
			"specialty":
				_on_specialty_action_pressed(action_id)
			"hero":
				_on_hero_action_pressed(action_id)
			_:
				continue

		var after_signature := JSON.stringify(_validation_progress_signature())
		return {
			"ok": before_signature != after_signature,
			"lane": lane,
			"action_id": action_id,
			"label": String(action.get("label", action_id)),
			"message": _last_message,
			"town_action_recap": _duplicate_dictionary(_last_action_recap),
			"town_action_recap_text": String(_last_action_recap.get("text", "")),
			"visible_consequence_text": _event_label.text,
			"consequence_tooltip_text": _event_label.tooltip_text,
			"state_changed": before_signature != after_signature,
		}

	return {
		"ok": false,
		"message": "No enabled town validation action is available.",
	}

func validation_action_catalog() -> Dictionary:
	return {
		"recruit": _duplicate_action_array(TownRules.get_recruit_actions(_session)),
		"build": _duplicate_action_array(TownRules.get_build_actions(_session)),
		"study": _duplicate_action_array(TownRules.get_spell_learning_actions(_session)),
		"market": _duplicate_action_array(TownRules.get_market_actions(_session)),
		"response": _duplicate_action_array(TownRules.get_response_actions(_session)),
		"tavern": _duplicate_action_array(TownRules.get_tavern_actions(_session)),
		"transfer": _duplicate_action_array(TownRules.get_transfer_actions(_session)),
		"artifact": _duplicate_action_array(TownRules.get_artifact_actions(_session)),
		"specialty": _duplicate_action_array(TownRules.get_specialty_actions(_session)),
		"hero": _duplicate_action_array(TownRules.get_hero_actions(_session)),
	}

func validation_select_build_plan(action_id: String) -> Dictionary:
	var normalized_id := action_id if action_id.begins_with("build:") else "build:%s" % action_id
	var before := TownRules.town_action_consequence_signature(_session)
	_select_build_action(normalized_id)
	return {
		"ok": _selected_build_action_id == normalized_id,
		"selected_build_action_id": _selected_build_action_id,
		"state_unchanged": before == TownRules.town_action_consequence_signature(_session),
		"snapshot": validation_snapshot(),
	}

func validation_confirm_build_plan() -> Dictionary:
	var selected_id := _selected_build_action_id
	var before := TownRules.town_action_consequence_signature(_session)
	_on_confirm_build_pressed()
	var after := TownRules.town_action_consequence_signature(_session)
	return {
		"ok": before != after,
		"committed_action_id": selected_id,
		"state_changed": before != after,
		"snapshot": validation_snapshot(),
	}

func validation_toggle_narrow_town_orders() -> Dictionary:
	_on_town_orders_toggle_pressed()
	return {
		"ok": _narrow_layout_active,
		"narrow_layout_active": _narrow_layout_active,
		"narrow_orders_open": _narrow_orders_open,
		"sidebar_visible": _sidebar_shell_panel.visible,
		"stage_visible": _stage_column.visible,
		"toggle_text": _town_orders_toggle_button.text,
	}

func validation_resource_ledger_snapshot() -> Dictionary:
	return {
		"resources": _duplicate_dictionary(_session.overworld.get("resources", {})),
		"live_stockpile_resource_ids": OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS.duplicate(),
		"resources_text": OverworldRules.describe_resources(_session),
		"resources_visible_text": _resource_label.text,
		"resources_tooltip_text": _resource_label.tooltip_text,
		"resources_full_ledger_text": OverworldRules.describe_resource_stockpile(_session.overworld.get("resources", {}), true),
		"resource_stockpile_menu": _resource_label.validation_snapshot(),
		"rendered_economy_readability_surface": _last_economy_readability_surface.duplicate(true),
		"rendered_build_actions": _duplicate_action_array(_last_rendered_build_actions),
		"rendered_recruit_actions": _duplicate_action_array(_last_rendered_recruit_actions),
		"economy_readability_surface": _economy_readability_surface(),
	}

func validation_unit_art_summary() -> Dictionary:
	var action_entries := []
	var loaded_count := 0
	var missing := []
	for action in TownRules.get_recruit_actions(_session):
		if not (action is Dictionary):
			continue
		var unit_id := _unit_id_for_recruit_action(action)
		var path := String(ContentService.get_unit_art(unit_id).get("portrait", ""))
		var loaded := path != "" and _unit_art_texture(path) is Texture2D
		if loaded:
			loaded_count += 1
		else:
			missing.append(unit_id)
		action_entries.append({
			"action_id": String(action.get("id", "")),
			"unit_id": unit_id,
			"portrait": path,
			"loaded": loaded,
		})
	return {
		"recruit_action_count": action_entries.size(),
		"portrait_loaded_count": loaded_count,
		"missing_portrait_units": missing,
		"actions": action_entries,
	}

func validation_force_refresh() -> Dictionary:
	_refresh()
	return validation_town_entity_cache_snapshot()

func validation_force_minimal_refresh() -> Dictionary:
	_refresh(true)
	return validation_town_entity_cache_snapshot()

func validation_reset_town_management_tab_navigation_state() -> Dictionary:
	_validation_management_tab_change_sequence = 0
	_validation_management_tab_change_count = 0
	_validation_management_tab_focus_handoff_count = 0
	_validation_management_tab_boundary_retain_count = 0
	_last_management_tab_change_result = {}
	_last_management_tab_index = _management_tabs.current_tab
	return validation_town_management_tab_navigation_snapshot()

func validation_town_management_tab_navigation_snapshot() -> Dictionary:
	var tab_bar := _management_tabs.get_tab_bar()
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	var tab_surfaces := _town_keyboard_focus_surfaces()
	var active_controls := _town_focusable_controls(tab_surfaces)
	var enabled_commands := []
	for control in active_controls:
		if not (control is Control):
			continue
		enabled_commands.append(_town_focus_control_snapshot(control))
	var first_enabled_command: Dictionary = enabled_commands[0].duplicate(true) if not enabled_commands.is_empty() else {}
	return {
		"active_tab": _management_tabs.current_tab,
		"tab_count": _management_tabs.get_tab_count(),
		"tab_titles": _management_tab_titles(),
		"tab_bar_name": String(tab_bar.name) if tab_bar != null else "",
		"tab_bar_focus_mode": tab_bar.focus_mode if tab_bar != null else Control.FOCUS_NONE,
		"tab_bar_boundary_policy": "retain",
		"tab_bar_has_focus": focus_owner == tab_bar,
		"tab_bar_focus_owner": String(focus_owner.name) if focus_owner == tab_bar else "",
		"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		"focus_owner_in_active_tab": _control_is_in_town_focus_surfaces(focus_owner, tab_surfaces),
		"active_tab_enabled_commands": enabled_commands,
		"first_enabled_command": first_enabled_command,
		"change_sequence": _validation_management_tab_change_sequence,
		"change_count": _validation_management_tab_change_count,
		"focus_handoff_count": _validation_management_tab_focus_handoff_count,
		"boundary_retain_count": _validation_management_tab_boundary_retain_count,
		"last_change_result": _last_management_tab_change_result.duplicate(true),
		"narrow_layout_active": _narrow_layout_active,
		"narrow_orders_open": _narrow_orders_open,
	}

func _town_focus_control_snapshot(control: Control) -> Dictionary:
	return {
		"node_name": String(control.name),
		"text": String(control.text) if control is BaseButton else "",
		"disabled": bool(control.disabled) if control is BaseButton else false,
		"focus_mode": control.focus_mode,
	}

func validation_town_entity_cache_snapshot() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var placement_id := String(town.get("placement_id", "")) if town is Dictionary else ""
	var session_key := _town_entity_session_cache_key()
	var bucket: Dictionary = _town_entity_cache_by_session.get(session_key, {}) if _town_entity_cache_by_session.get(session_key, {}) is Dictionary else {}
	var cached_placements := _town_entity_cached_placements(bucket)
	return {
		"active_placement_id": placement_id,
		"session_cache_key": session_key,
		"cached_placements": cached_placements,
		"entry_count": bucket.size(),
		"active_cached": _town_entity_cache_has_placement(bucket, placement_id),
		"last_cache_result": _last_town_entity_cache_result.duplicate(true),
		"last_cache_hit": bool(_last_town_entity_cache_result.get("hit", false)),
		"last_save_surface_profile": _last_save_surface_profile.duplicate(true),
		"save_surface_skipped_hidden": bool(_last_save_surface_profile.get("skipped_hidden", false)),
	}

func validation_perform_town_action(action_id: String) -> Dictionary:
	var action := _validation_action_for_id(action_id)
	if action.is_empty():
		return {
			"ok": false,
			"action_id": action_id,
			"message": "No enabled town validation action matched the requested id.",
		}

	var before_signature := JSON.stringify(_validation_progress_signature())
	var lane := String(action.get("lane", ""))
	match lane:
		"recruit":
			_on_recruit_action_pressed(action_id.trim_prefix("recruit:"))
		"build":
			_commit_build_action(action_id.trim_prefix("build:"))
		"study":
			_on_study_action_pressed(action_id.trim_prefix("learn_spell:"))
		"market":
			_on_market_action_pressed(action_id)
		"response":
			_on_response_action_pressed(action_id)
		"tavern":
			_on_tavern_action_pressed(action_id)
		"transfer":
			_on_transfer_action_pressed(action_id)
		"artifact":
			_on_artifact_action_pressed(action_id)
		"specialty":
			_on_specialty_action_pressed(action_id)
		"hero":
			_on_hero_action_pressed(action_id)
		_:
			return {
				"ok": false,
				"action_id": action_id,
				"message": "Unsupported town validation action lane.",
			}

	var after_signature := JSON.stringify(_validation_progress_signature())
	return {
		"ok": before_signature != after_signature,
		"lane": lane,
		"action_id": action_id,
		"label": String(action.get("label", action_id)),
		"message": _last_message,
		"town_action_recap": _duplicate_dictionary(_last_action_recap),
		"town_action_recap_text": String(_last_action_recap.get("text", "")),
		"visible_consequence_text": _event_label.text,
		"consequence_tooltip_text": _event_label.tooltip_text,
		"state_changed": before_signature != after_signature,
	}

func validation_select_save_slot(slot: int) -> bool:
	var normalized_slot := int(slot)
	if not SaveService.get_manual_slot_ids().has(normalized_slot):
		return false
	SaveService.set_selected_manual_slot(normalized_slot)
	_refresh_save_slot_picker(true)
	return SaveService.get_selected_manual_slot() == normalized_slot

func validation_save_to_selected_slot() -> Dictionary:
	var selected_slot := SaveService.get_selected_manual_slot()
	_commit_manual_save(selected_slot)
	var summary := SaveService.inspect_manual_slot(selected_slot)
	return {
		"ok": SaveService.can_load_summary(summary),
		"selected_slot": selected_slot,
		"summary": summary,
		"message": _last_message,
	}

func validation_request_manual_save() -> Dictionary:
	_on_save_pressed()
	return _manual_save_overwrite_dialog.validation_snapshot()

func validation_confirm_manual_save_overwrite() -> Dictionary:
	var pending_slot := int(_manual_save_overwrite_dialog.validation_snapshot().get("pending_slot", 0))
	_on_manual_save_overwrite_confirmed()
	return {
		"pending_slot": pending_slot,
		"summary": SaveService.inspect_manual_slot(pending_slot) if SaveService.get_manual_slot_ids().has(pending_slot) else {},
		"message": _last_message,
	}

func validation_cancel_manual_save_overwrite() -> void:
	_on_manual_save_overwrite_canceled()

func validation_open_active_play_settings() -> Dictionary:
	_on_settings_pressed()
	return _active_play_settings_dialog.validation_snapshot()

func validation_active_play_settings_dialog():
	return _active_play_settings_dialog

func validation_return_to_menu() -> Dictionary:
	return _on_menu_pressed()

func validation_active_play_return_snapshot() -> Dictionary:
	return {
		"last_result": _last_return_to_menu_result.duplicate(true),
		"visible_message": _last_message,
		"focus_owner": _return_to_menu_focus_owner_name(),
		"request_count": _validation_return_to_menu_request_count,
		"scenario_id": _session.scenario_id,
		"resume_target": SaveService.resume_target_for_session(_session),
	}

func _return_to_menu_focus_owner_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return String(focus_owner.name) if focus_owner != null else ""

func validation_leave_town() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	_on_leave_pressed()
	return {
		"ok": true,
		"town_placement_id": String(town.get("placement_id", "")),
		"message": "Town route closed.",
	}

func validation_prepare_town_return_handoff() -> Dictionary:
	return _prepare_town_return_handoff()

func _rebuild_hero_actions(actions_override: Variant = null) -> void:
	for child in _hero_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array else TownRules.get_hero_actions(_session)
	if actions.size() <= 1:
		_hero_actions.add_child(_make_placeholder_label("No alternate commanders in town"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Command")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _town_action_button_tooltip(action, "hero")
		_style_action_button(button)
		button.pressed.connect(_on_hero_action_pressed.bind(String(action.get("id", ""))))
		_hero_actions.add_child(button)

func _rebuild_build_actions(actions_override: Variant = null) -> void:
	for child in _build_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array and _catalog_rows_are_complete(actions_override, "building_id") else TownRules.get_build_catalog(_session)
	if actions.is_empty():
		_selected_build_action_id = ""
		_build_actions.add_child(_make_placeholder_label("No construction orders"))
		_refresh_build_plan_surface([])
		return
	_ensure_selected_build_action(actions)

	for action in actions:
		if not (action is Dictionary):
			continue
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(190, 108)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		FrontierVisualKit.apply_panel(card, _catalog_panel_tone(String(action.get("catalog_status", "Locked"))))
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 4)
		card.add_child(card_box)
		var button := Button.new()
		var action_id := String(action.get("id", ""))
		button.text = "%s\n%s • %s" % [
			_short_text(String(action.get("name", action.get("label", "Construction"))).trim_prefix("Build "), 25),
			String(action.get("category", "support")).capitalize(),
			String(action.get("catalog_status", "Locked")),
		]
		button.toggle_mode = true
		button.button_pressed = action_id == _selected_build_action_id
		button.disabled = action_id == ""
		button.tooltip_text = _catalog_build_tooltip(action)
		_style_action_button(button, button.button_pressed)
		button.custom_minimum_size = Vector2(190, 72)
		button.set_meta("catalog_entry_id", action_id)
		button.set_meta("catalog_status", String(action.get("catalog_status", "")))
		_apply_build_action_icon(button, action)
		button.pressed.connect(_on_build_action_pressed.bind(String(action.get("id", "")).trim_prefix("build:")))
		card_box.add_child(button)
		var cost_label := Label.new()
		var cost_text := TownRules._describe_resources(action.get("cost", {}))
		cost_label.text = "Cost: %s" % (cost_text if cost_text != "" else "standing work")
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cost_label.tooltip_text = button.tooltip_text
		FrontierVisualKit.apply_label(cost_label, "muted", 11)
		card_box.add_child(cost_label)
		_build_actions.add_child(card)
	_refresh_build_plan_surface(actions)

func _catalog_rows_are_complete(rows: Variant, identity_key: String) -> bool:
	if not (rows is Array) or rows.is_empty():
		return false
	for row_value in rows:
		if not (row_value is Dictionary) or String(row_value.get(identity_key, "")) == "":
			return false
	return true

func _catalog_panel_tone(status: String) -> String:
	match status:
		"Ready":
			return "green"
		"Built":
			return "gold"
		"Trade":
			return "teal"
		_:
			return "ink"

func _catalog_build_tooltip(action: Dictionary) -> String:
	return _join_tooltip_sections([
		"%s • %s" % [String(action.get("name", "Construction")), String(action.get("catalog_status", "Locked"))],
		String(action.get("description", "")),
		String(action.get("effect_summary", "")),
		"Cost: %s" % TownRules._describe_resources(action.get("cost", {})),
		String(action.get("catalog_status_detail", "")),
		String(action.get("summary", "")),
		"Select this card to inspect it. Construction only occurs after explicit confirmation.",
	])

func _apply_build_action_icon(button: Button, action: Dictionary) -> void:
	var building_id := TownRules.building_id_for_action(String(action.get("id", "")))
	var icon_path := TownRules.building_icon_path(building_id)
	if icon_path == "":
		return
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return
	button.icon = texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 46)

func _ensure_selected_build_action(actions: Array) -> void:
	if not _build_action_for_id(_selected_build_action_id, actions).is_empty():
		return
	_selected_build_action_id = ""
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if not bool(action.get("disabled", false)):
			_selected_build_action_id = String(action.get("id", ""))
			break
	if _selected_build_action_id == "" and not actions.is_empty() and actions[0] is Dictionary:
		_selected_build_action_id = String(actions[0].get("id", ""))

func _selected_build_action(actions_override: Variant = null) -> Dictionary:
	var actions = actions_override if actions_override is Array else TownRules.get_build_catalog(_session)
	return _build_action_for_id(_selected_build_action_id, actions)

func _build_action_for_id(action_id: String, actions_override: Variant = null) -> Dictionary:
	if action_id == "":
		return {}
	var actions = actions_override if actions_override is Array else TownRules.get_build_catalog(_session)
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return action_value
	return {}

func _build_plan_option_label(action: Dictionary) -> String:
	var name := String(action.get("label", action.get("id", "Construction"))).trim_prefix("Build ")
	var readiness := "Blocked"
	if bool(action.get("direct_affordable", false)):
		readiness = "Ready"
	elif bool(action.get("market_coverable", false)):
		readiness = "Trade"
	return "%s | %s" % [_short_text(name, 24), readiness]

func _refresh_build_plan_surface(actions: Array) -> void:
	var action := _selected_build_action(actions)
	if action.is_empty():
		_set_compact_label(_build_plan_label, "No construction plan is available.", 2)
		_build_plan_label.tooltip_text = ""
		_confirm_build_button.text = "No Construction"
		_confirm_build_button.tooltip_text = "No construction order is currently available."
		_confirm_build_button.disabled = true
		return
	var name := String(action.get("label", "Construction")).trim_prefix("Build ")
	var cost := TownRules._describe_resources(action.get("cost", {}))
	var catalog_status := String(action.get("catalog_status", ""))
	if bool(action.get("built", false)) or bool(action.get("locked", false)):
		_set_compact_label(
			_build_plan_label,
			"%s | %s | Cost %s\n%s" % [name, catalog_status, cost, String(action.get("catalog_status_detail", ""))],
			2
		)
		_build_plan_label.tooltip_text = _catalog_build_tooltip(action)
		_confirm_build_button.text = "Already Built" if bool(action.get("built", false)) else "Requirements Locked"
		_confirm_build_button.tooltip_text = String(action.get("catalog_status_detail", "This construction plan is locked."))
		_confirm_build_button.disabled = true
		return
	var readiness := _town_action_button_readiness(action, "build")
	var impact := String(action.get("impact_line", "")).trim_prefix("Defense/frontier: ").trim_suffix(".")
	_set_compact_label(
		_build_plan_label,
		"%s | Cost %s\n%s | %s" % [name, cost, readiness, impact],
		2
	)
	_build_plan_label.tooltip_text = _join_tooltip_sections([
		"Selected construction: %s" % name,
		String(action.get("summary", "")),
		"Selection does not spend resources. Use the command below to commit this plan.",
	])
	var direct_affordable := bool(action.get("direct_affordable", false))
	var market_coverable := bool(action.get("market_coverable", false)) and not direct_affordable
	if direct_affordable:
		_confirm_build_button.text = "Build %s" % _short_text(name, 22)
		_confirm_build_button.tooltip_text = "Commit %s now for %s. This spends resources and uses today's construction order." % [name, cost]
		_confirm_build_button.disabled = false
	elif market_coverable:
		_confirm_build_button.text = "Open Trade for %s" % _short_text(name, 17)
		_confirm_build_button.tooltip_text = _join_tooltip_sections([
			String(action.get("market_summary", "Trade can cover the missing common resources.")),
			"Open the Trade tab without spending resources.",
		])
		_confirm_build_button.disabled = false
	else:
		_confirm_build_button.text = "Resources Missing"
		_confirm_build_button.tooltip_text = String(action.get("disabled_reason", "Current stores cannot fund this plan."))
		_confirm_build_button.disabled = true

func _rebuild_market_actions(actions_override: Variant = null) -> void:
	for child in _market_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array else TownRules.get_market_actions(_session)
	if actions.is_empty():
		_market_actions.add_child(_make_placeholder_label("No exchange orders ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Trade")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _town_action_button_tooltip(action, "market")
		_style_action_button(button)
		button.pressed.connect(_on_market_action_pressed.bind(String(action.get("id", ""))))
		_market_actions.add_child(button)

func _rebuild_recruit_actions(actions_override: Variant = null) -> void:
	for child in _recruit_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array and _catalog_rows_are_complete(actions_override, "unit_id") else TownRules.get_muster_catalog(_session)
	if actions.is_empty():
		_recruit_actions.add_child(_make_placeholder_label("No recruits waiting"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var unit_id := String(action.get("unit_id", _unit_id_for_recruit_action(action)))
		var portrait_path := String(action.get("portrait_path", ContentService.get_unit_art(unit_id).get("portrait", "")))
		var portrait_texture: Variant = _unit_art_texture(portrait_path)
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(190, 232)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		FrontierVisualKit.apply_panel(row, _catalog_panel_tone(String(action.get("catalog_status", "Locked"))))
		var row_box := VBoxContainer.new()
		row_box.add_theme_constant_override("separation", 4)
		row.add_child(row_box)
		if portrait_texture is Texture2D:
			var portrait := TextureRect.new()
			portrait.texture = portrait_texture
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.custom_minimum_size = Vector2(88, 112)
			portrait.tooltip_text = _catalog_muster_tooltip(action)
			row_box.add_child(portrait)
		var identity_label := Label.new()
		identity_label.text = "%s • %s" % [String(action.get("tier_label", "Tier")), String(action.get("name", unit_id))]
		identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		identity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		identity_label.tooltip_text = _catalog_muster_tooltip(action)
		FrontierVisualKit.apply_label(identity_label, "body", 12)
		row_box.add_child(identity_label)
		var reserve_label := Label.new()
		reserve_label.text = "%s • %d reserve • +%d/week" % [
			String(action.get("catalog_status", "Locked")),
			int(action.get("available_count", 0)),
			int(action.get("weekly_growth", 0)),
		]
		reserve_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reserve_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		reserve_label.tooltip_text = _catalog_muster_tooltip(action)
		FrontierVisualKit.apply_label(reserve_label, "muted", 11)
		row_box.add_child(reserve_label)
		var button := Button.new()
		var ready_count := int(action.get("direct_affordable_count", 0))
		button.text = "Recruit %s x%d" % [String(action.get("tier_label", "Tier")), ready_count] if ready_count > 0 else String(action.get("catalog_status", "Unavailable"))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _catalog_muster_tooltip(action)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(button)
		button.set_meta("catalog_entry_id", String(action.get("id", "")))
		button.set_meta("catalog_status", String(action.get("catalog_status", "")))
		button.pressed.connect(_on_recruit_action_pressed.bind(String(action.get("id", "")).trim_prefix("recruit:")))
		row_box.add_child(button)
		_recruit_actions.add_child(row)

func _catalog_muster_tooltip(action: Dictionary) -> String:
	var unit_cost := TownRules._describe_resources(action.get("unit_cost", {}))
	return _join_tooltip_sections([
		"%s • %s • %s" % [String(action.get("tier_label", "Tier")), String(action.get("name", "Unit")), String(action.get("catalog_status", "Locked"))],
		"Role: %s | Cost each: %s" % [String(action.get("role", "unknown")).capitalize(), unit_cost],
		"Reserve %d | Weekly growth +%d" % [int(action.get("available_count", 0)), int(action.get("weekly_growth", 0))],
		String(action.get("catalog_status_detail", "")),
		String(action.get("summary", "")),
	])

func _rebuild_tavern_actions(actions_override: Variant = null) -> void:
	for child in _tavern_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array else TownRules.get_tavern_actions(_session)
	if actions.is_empty():
		_tavern_actions.add_child(_make_placeholder_label("No hires are ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Hire")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _town_action_button_tooltip(action, "tavern")
		_style_action_button(button)
		button.pressed.connect(_on_tavern_action_pressed.bind(String(action.get("id", ""))))
		_tavern_actions.add_child(button)

func _rebuild_transfer_actions(actions_override: Variant = null) -> void:
	for child in _transfer_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array else TownRules.get_transfer_actions(_session)
	if actions.is_empty():
		_transfer_actions.add_child(_make_placeholder_label("No transfers are ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Transfer")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _town_action_button_tooltip(action, "transfer")
		_style_action_button(button)
		button.pressed.connect(_on_transfer_action_pressed.bind(String(action.get("id", ""))))
		_transfer_actions.add_child(button)

func _rebuild_response_actions(actions_override: Variant = null) -> void:
	for child in _response_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array else TownRules.get_response_actions(_session)
	if actions.is_empty():
		_response_actions.add_child(_make_placeholder_label("No response orders ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Respond")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _town_action_button_tooltip(action, "response")
		_style_action_button(button)
		button.pressed.connect(_on_response_action_pressed.bind(String(action.get("id", ""))))
		_response_actions.add_child(button)

func _rebuild_study_actions(actions_override: Variant = null) -> void:
	for child in _study_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array else TownRules.get_spell_learning_actions(_session)
	if actions.is_empty():
		_study_actions.add_child(_make_placeholder_label("No new spells to copy"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Learn")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _town_action_button_tooltip(action, "study")
		_style_action_button(button)
		_apply_spell_action_icon(button, action)
		button.pressed.connect(_on_study_action_pressed.bind(String(action.get("id", "")).trim_prefix("learn_spell:")))
		_study_actions.add_child(button)

func _apply_spell_action_icon(button: Button, action: Dictionary) -> void:
	var spell_id := SpellRules.spell_id_for_action(String(action.get("id", "")))
	var icon_path := SpellRules.spell_icon_path(spell_id)
	if icon_path == "":
		return
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return
	button.icon = texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)

func _rebuild_artifact_actions(actions_override: Variant = null) -> void:
	for child in _artifact_actions.get_children():
		child.queue_free()
	_append_artifact_set_insignia_rows()

	var actions = actions_override if actions_override is Array else TownRules.get_artifact_actions(_session)
	if actions.is_empty():
		_artifact_actions.add_child(_make_placeholder_label("No artifact orders"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Artifact")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _town_action_button_tooltip(action, "artifact")
		_style_action_button(button)
		_apply_artifact_action_icon(button, action)
		button.pressed.connect(_on_artifact_action_pressed.bind(String(action.get("id", ""))))
		_artifact_actions.add_child(button)

func _apply_artifact_action_icon(button: Button, action: Dictionary) -> void:
	var hero: Dictionary = _session.overworld.get("hero", {}) if _session != null else {}
	var artifact_id := ArtifactRules.artifact_id_for_management_action(hero, String(action.get("id", "")))
	var icon_path := ArtifactRules.artifact_icon_path(artifact_id)
	if icon_path == "":
		return
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return
	button.icon = texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)

func _append_artifact_set_insignia_rows() -> void:
	if _session == null:
		return
	var hero: Dictionary = _session.overworld.get("hero", {})
	for set_state_value in ArtifactRules.artifact_set_runtime_state(hero):
		if not (set_state_value is Dictionary):
			continue
		var set_state: Dictionary = set_state_value
		var insignia = set_state.get("insignia", {})
		if not (insignia is Dictionary):
			continue
		var texture := _artifact_set_insignia_texture(insignia)
		if texture == null:
			continue
		var row := HBoxContainer.new()
		row.name = "ArtifactSetInsignia_%s" % String(set_state.get("set_id", "set"))
		row.set_meta("artifact_set_id", String(set_state.get("set_id", "")))
		row.set_meta("artifact_set_complete", bool(set_state.get("complete", false)))
		row.tooltip_text = String(insignia.get("alt_text", ""))
		var icon := TextureRect.new()
		icon.name = "SetInsignia"
		icon.custom_minimum_size = Vector2(28, 28)
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.name = "SetProgress"
		label.text = "%s %d/%d" % [
			String(set_state.get("name", "Artifact Set")),
			int(set_state.get("equipped_piece_count", 0)),
			int(set_state.get("piece_count", 0)),
		]
		label.tooltip_text = row.tooltip_text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row.add_child(label)
		_artifact_actions.add_child(row)

func _artifact_set_insignia_texture(insignia: Dictionary) -> Texture2D:
	var atlas_path := String(insignia.get("atlas_path", "")).strip_edges()
	var region_value = insignia.get("atlas_region", {})
	if atlas_path == "" or not (region_value is Dictionary):
		return null
	var atlas := load(atlas_path) as Texture2D
	if atlas == null:
		return null
	var region: Dictionary = region_value
	var rect := Rect2(
		float(region.get("x", -1)),
		float(region.get("y", -1)),
		float(region.get("width", 0)),
		float(region.get("height", 0))
	)
	var atlas_size := atlas.get_size()
	if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.end.x > atlas_size.x or rect.end.y > atlas_size.y:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = rect
	return texture

func validation_artifact_set_insignia_rows() -> Array:
	var rows: Array = []
	for child in _artifact_actions.get_children():
		if not child.has_meta("artifact_set_id"):
			continue
		var icon := child.get_node_or_null("SetInsignia") as TextureRect
		var label := child.get_node_or_null("SetProgress") as Label
		var atlas_texture := icon.texture as AtlasTexture if icon != null else null
		rows.append({
			"set_id": String(child.get_meta("artifact_set_id", "")),
			"complete": bool(child.get_meta("artifact_set_complete", false)),
			"label": label.text if label != null else "",
			"tooltip": child.tooltip_text,
			"atlas_path": atlas_texture.atlas.resource_path if atlas_texture != null and atlas_texture.atlas != null else "",
			"atlas_region": atlas_texture.region if atlas_texture != null else Rect2(),
			"visible": child.is_visible_in_tree(),
		})
	return rows

func _rebuild_specialty_actions(actions_override: Variant = null) -> void:
	for child in _specialty_actions.get_children():
		child.queue_free()

	var actions = actions_override if actions_override is Array else TownRules.get_specialty_actions(_session)
	if actions.is_empty():
		_specialty_actions.add_child(_make_placeholder_label("No specialty choice waiting"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Choose Specialty")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _join_tooltip_sections([
			_town_action_button_tooltip(action, "specialty"),
			HeroProgressionRules.specialty_insignia_description(
				HeroProgressionRules.specialty_id_for_action(String(action.get("id", "")))
			),
		])
		_style_action_button(button)
		_apply_specialty_action_icon(button, action)
		button.pressed.connect(_on_specialty_action_pressed.bind(String(action.get("id", ""))))
		_specialty_actions.add_child(button)

func _apply_specialty_action_icon(button: Button, action: Dictionary) -> void:
	var specialty_id := HeroProgressionRules.specialty_id_for_action(String(action.get("id", "")))
	var texture := HeroProgressionRules.specialty_insignia_texture(specialty_id)
	if texture == null:
		return
	button.icon = texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)
	button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, 190.0)

func _town_action_button_tooltip(action: Dictionary, lane: String) -> String:
	var summary := String(action.get("summary", "")).strip_edges()
	if lane == "build":
		return _join_tooltip_sections([
			_town_action_button_cue_text(action, lane),
			"Selection previews the construction plan and does not spend resources.",
			summary,
		])
	return _join_tooltip_sections([
		_town_action_button_cue_text(action, lane),
		summary,
	])

func _town_action_button_cue_text(action: Dictionary, lane: String) -> String:
	var label := String(action.get("button_label", action.get("label", action.get("id", "Order")))).strip_edges()
	if label == "":
		label = "Order"
	var lane_label := _town_action_lane_label(lane)
	var surface := _town_action_surface_label(lane)
	var readiness := _town_action_button_readiness(action, lane)
	var impact := _town_action_button_impact(action, lane)
	var next_step := (
		_town_build_plan_next_step(action, label, readiness)
		if lane == "build"
		else _town_action_button_next_step(action, lane, label, surface, readiness)
	)
	return "Command cue: %s | %s | %s | Next: %s" % [
		lane_label,
		_short_text(readiness, 46),
		_short_text(impact, 54),
		_short_text(next_step, 72),
	]

func _town_build_plan_next_step(action: Dictionary, label: String, readiness: String) -> String:
	if bool(action.get("disabled", false)):
		return "Review %s in Build tab to inspect the missing requirements." % label
	if readiness.begins_with("Needs exchange"):
		return "Select %s in Build tab, then use Trade before confirming." % label
	return "Select %s in Build tab, then review and confirm the plan." % label

func _town_action_button_readiness(action: Dictionary, lane: String) -> String:
	if bool(action.get("disabled", false)):
		if lane == "market":
			return "Blocked by current stores"
		return String(action.get("disabled_reason", "Blocked by current town state")).strip_edges()
	if lane == "build":
		if bool(action.get("direct_affordable", false)):
			return "Ready now"
		if bool(action.get("market_coverable", false)):
			var market_summary := String(action.get("market_summary", "")).strip_edges()
			return "Needs exchange first%s" % (": %s" % market_summary if market_summary != "" else "")
	if lane == "recruit":
		var direct_count := int(action.get("direct_affordable_count", 0))
		if direct_count > 0:
			return "Ready x%d" % direct_count
		var market_count := int(action.get("market_affordable_count", 0))
		if market_count > 0:
			var recruit_market := String(action.get("market_summary", "")).strip_edges()
			return "Needs exchange x%d%s" % [market_count, ": %s" % recruit_market if recruit_market != "" else ""]
	var affordability := String(action.get("affordability_label", "")).strip_edges()
	if affordability != "":
		return affordability
	return "Ready now"

func _town_action_button_impact(action: Dictionary, lane: String) -> String:
	for key in ["impact_line", "recommendation_line", "delivery_summary"]:
		var value := String(action.get(key, "")).strip_edges()
		if value != "":
			return value.trim_suffix(".")
	var summary := String(action.get("summary", "")).strip_edges()
	if summary != "":
		for line_value in summary.split("\n", false):
			var line := String(line_value).strip_edges()
			if line != "":
				return line.trim_suffix(".")
	return "%s keeps the town plan moving" % _town_action_lane_label(lane).to_lower()

func _town_action_button_next_step(action: Dictionary, lane: String, label: String, surface: String, readiness: String) -> String:
	if bool(action.get("disabled", false)):
		return "Resolve %s before pressing %s in %s." % [readiness.to_lower(), label, surface]
	if lane in ["build", "recruit"] and readiness.begins_with("Needs exchange"):
		return "Use Trade, then press %s in %s." % [label, surface]
	return "Press %s in %s, or leave when town orders are set." % [label, surface]

func _town_action_lane_label(lane: String) -> String:
	match lane:
		"build":
			return "Construction"
		"recruit":
			return "Recruitment"
		"market":
			return "Exchange"
		"study":
			return "Spell study"
		"hero":
			return "Commander"
		"tavern":
			return "Hero hire"
		"transfer":
			return "Transfer"
		"response":
			return "Strategic response"
		"artifact":
			return "Artifact"
		"specialty":
			return "Specialty"
		_:
			return "Town order"

func _town_action_surface_label(lane: String) -> String:
	match lane:
		"build":
			return "Build tab"
		"recruit", "hero", "tavern", "transfer", "specialty":
			return "Muster tab"
		"study", "artifact":
			return "Spells tab"
		"market":
			return "Trade tab"
		"response":
			return "Log tab"
		_:
			return "Town orders"

func _town_action_button_tooltip_snapshot() -> Dictionary:
	return {
		"build": _button_tooltips_or_actions(_build_actions, "build"),
		"recruit": _button_tooltips_or_actions(_recruit_actions, "recruit"),
		"study": _button_tooltips_or_actions(_study_actions, "study"),
		"market": _button_tooltips_or_actions(_market_actions, "market"),
		"hero": _button_tooltips_or_actions(_hero_actions, "hero"),
		"tavern": _button_tooltips_or_actions(_tavern_actions, "tavern"),
		"transfer": _button_tooltips_or_actions(_transfer_actions, "transfer"),
		"response": _button_tooltips_or_actions(_response_actions, "response"),
		"artifact": _button_tooltips_or_actions(_artifact_actions, "artifact"),
		"specialty": _button_tooltips_or_actions(_specialty_actions, "specialty"),
	}

func _button_tooltips_or_actions(container: Container, lane: String) -> Array:
	var tooltips := _button_tooltips(container)
	if not tooltips.is_empty():
		return tooltips
	return _action_tooltip_entries(_validation_actions_for_lane(lane), lane)

func _button_tooltips(container: Container) -> Array:
	var tooltips := []
	for child in container.get_children():
		if child is Button:
			tooltips.append({
				"text": child.text,
				"tooltip": child.tooltip_text,
				"disabled": child.disabled,
			})
		elif child is Container:
			tooltips.append_array(_button_tooltips(child))
	return tooltips

func _action_tooltip_entries(actions: Array, lane: String) -> Array:
	var entries := []
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		entries.append({
			"text": String(action.get("label", action.get("id", "Order"))),
			"tooltip": _town_action_button_tooltip(action, lane),
			"disabled": bool(action.get("disabled", false)),
		})
	return entries

func _validation_actions_for_lane(lane: String) -> Array:
	var town := TownRules.get_active_town(_session)
	match lane:
		"build":
			return _refresh_cached_cost_actions(TownRules.get_build_actions(_session), town)
		"recruit":
			return _refresh_cached_recruit_actions(TownRules.get_recruit_actions(_session), town)
		"study":
			return _refresh_cached_cost_actions(TownRules.get_spell_learning_actions(_session), town)
		"market":
			return _refresh_cached_cost_actions(TownRules.get_market_actions(_session), town)
		"hero":
			return _duplicate_action_array(TownRules.get_hero_actions(_session))
		"tavern":
			return _refresh_cached_cost_actions(TownRules.get_tavern_actions(_session), town)
		"transfer":
			return _duplicate_action_array(TownRules.get_transfer_actions(_session))
		"response":
			return _duplicate_action_array(TownRules.get_response_actions(_session))
		"artifact":
			return _duplicate_action_array(TownRules.get_artifact_actions(_session))
		"specialty":
			return _duplicate_action_array(TownRules.get_specialty_actions(_session))
		_:
			return []

func _specialty_readiness_surface() -> Dictionary:
	var actions := TownRules.get_specialty_actions(_session)
	var hero_value: Variant = _session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var pending_choices: Array = hero.get("pending_specialty_choices", []) if hero.get("pending_specialty_choices", []) is Array else []
	var chosen_specialties: Array = hero.get("specialties", []) if hero.get("specialties", []) is Array else []
	var hero_name := String(hero.get("name", "Active hero")).strip_edges()
	if hero_name == "":
		hero_name = "Active hero"

	var ready_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if best_blocked.is_empty():
				best_blocked = action
			continue
		ready_orders += 1
		if best_ready.is_empty():
			best_ready = action

	var selected_action := best_ready
	var state_line := "no specialty choice is waiting"
	var visible := "Specialty check: no choice | %d chosen" % chosen_specialties.size()
	if ready_orders > 0:
		state_line = "Ready now: %d specialty choice%s can be selected" % [
			ready_orders,
			"" if ready_orders == 1 else "s",
		]
		visible = "Specialty check: Ready x%d | %d chosen" % [ready_orders, chosen_specialties.size()]
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d specialty choice%s waiting on hero state" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Specialty check: Blocked x0/%d" % blocked_orders
	elif pending_choices.size() > 0:
		state_line = "pending specialty choices need valid options"
		visible = "Specialty check: pending choice needs options"

	var label := "No specialty choice"
	var readiness := state_line
	var impact := "Specialties shape the hero's field, economy, and battle role before leaving town."
	var next_step := "Keep building experience, review current specialties, or leave when town orders are set."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Specialty choice"))).strip_edges()
		if label == "":
			label = "Specialty choice"
		readiness = _town_action_button_readiness(selected_action, "specialty")
		impact = _town_action_button_impact(selected_action, "specialty")
		next_step = _town_action_button_next_step(
			selected_action,
			"specialty",
			label,
			_town_action_surface_label("specialty"),
			readiness
		)
	elif pending_choices.size() > 0:
		next_step = "Resolve the pending hero progression choice after valid options are available."

	var tooltip_lines := [
		"Specialty Readiness",
		"- Hero: %s" % hero_name,
		"- Choices: %d ready, %d blocked, %d pending queue" % [
			ready_orders,
			blocked_orders,
			pending_choices.size(),
		],
		"- Chosen ranks: %d" % chosen_specialties.size(),
		"- %s" % state_line,
		"- Best choice: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
		"- Scope: this check only reads hero progression choices; pressing a specialty button is the action that changes the hero.",
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"listed_order_count": actions.size(),
		"pending_choice_count": pending_choices.size(),
		"chosen_rank_count": chosen_specialties.size(),
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _defense_check_surface() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return {
			"visible_text": "Defense check: no active town",
			"tooltip_text": "Defense Check\n- Town: none.\n- Readiness: unavailable.\n- Next practical action: return to the overworld and select a visitable town.",
			"readiness": 0,
			"base_readiness": 0,
			"state": "none",
			"frontier_state": "No active town.",
			"warning": "No town front is selected.",
			"next_step": "Return to the overworld and select a visitable town.",
		}

	var readiness := OverworldRules.town_battle_readiness(town, _session)
	var base_readiness := OverworldRules.town_battle_readiness(town)
	var occupation := OverworldRules.town_occupation_state(_session, town)
	var front := OverworldRules.town_front_state(_session, town)
	var warning := OverworldRules.describe_town_defense_readiness_warning(_session, town)
	var frontier_state := "steady watch"
	var state := "steady"
	if bool(occupation.get("active", false)):
		state = "occupied"
		frontier_state = String(occupation.get("summary", "occupation pressure is active")).strip_edges()
	elif bool(front.get("active", false)):
		state = "front"
		frontier_state = String(front.get("summary", "front pressure is active")).strip_edges()
	elif readiness < base_readiness:
		state = "reduced"
		frontier_state = "defense readiness is below the town's base posture"
	var visible := "Defense check: Steady | Readiness %d" % readiness
	match state:
		"occupied":
			visible = "Defense check: Occupied | Readiness %d" % readiness
		"front":
			visible = "Defense check: Front active | Readiness %d" % readiness
		"reduced":
			visible = "Defense check: Reduced %d/%d" % [readiness, base_readiness]

	var garrison_line := _first_matching_line(TownRules.describe_defense(_session), ["companies", "Garrison"])
	if garrison_line == "":
		garrison_line = "Garrison state is listed in Defense Posture."
	var threat_line := _first_matching_line(TownRules.describe_threats(_session), ["raid", "Front watch", "Occupation watch", "No hostile"])
	if threat_line == "":
		threat_line = frontier_state.capitalize()
	var next_step := "Leave when town orders are set; keep the frontier watch current."
	if state == "occupied":
		next_step = "Stabilize occupation or reinforce before relying on this town."
	elif state == "front":
		next_step = "Review Strategic Response or leave town to break the hostile lane."
	elif state == "reduced":
		next_step = "Muster or recover defenders before drawing a siege."
	elif readiness < 30:
		next_step = "Muster available troops before leaving town."

	var tooltip_lines := [
		"Defense Check",
		"- Town: %s" % _town_display_name(town),
		"- Readiness: %d current, %d base" % [readiness, base_readiness],
		"- Frontier state: %s" % frontier_state,
		"- Warning: %s" % warning,
		"- Garrison: %s" % garrison_line.trim_prefix("- ").strip_edges(),
		"- Threat watch: %s" % threat_line.trim_prefix("- ").strip_edges(),
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"readiness": readiness,
		"base_readiness": base_readiness,
		"state": state,
		"frontier_state": frontier_state,
		"warning": warning,
		"garrison_line": garrison_line,
		"threat_line": threat_line,
		"next_step": next_step,
	}

func _build_readiness_surface() -> Dictionary:
	var actions := TownRules.get_build_actions(_session)
	var town := TownRules.get_active_town(_session)
	var built_buildings := _normalize_string_array(town.get("built_buildings", []))
	var ready_orders := 0
	var market_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_market := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("direct_affordable", false)):
			ready_orders += 1
			if best_ready.is_empty():
				best_ready = action
			continue
		if bool(action.get("market_coverable", false)):
			market_orders += 1
			if best_market.is_empty():
				best_market = action
			continue
		blocked_orders += 1
		if best_blocked.is_empty():
			best_blocked = action

	var selected_action := best_ready
	var state_line := "no open construction orders"
	var visible := "Build check: no open orders"
	if ready_orders > 0:
		state_line = "Ready now: %d construction order%s" % [ready_orders, "" if ready_orders == 1 else "s"]
		visible = "Build check: Ready x%d | %d built" % [ready_orders, built_buildings.size()]
	elif market_orders > 0:
		selected_action = best_market
		state_line = "Trade path: %d construction order%s can be unlocked through Exchange" % [
			market_orders,
			"" if market_orders == 1 else "s",
		]
		visible = "Build check: Trade unlocks x%d" % market_orders
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d construction order%s waiting on stores or prerequisites" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Build check: Blocked x%d waiting" % blocked_orders
	elif not actions.is_empty() and actions[0] is Dictionary:
		selected_action = actions[0]

	var label := "No build order"
	var readiness := state_line
	var impact := "Construction timing shapes town income, defenses, and future muster options."
	var next_step := "Review another town order or leave when the build plan is set."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Build order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "build")
		impact = _town_action_button_impact(selected_action, "build")
		next_step = _town_action_button_next_step(
			selected_action,
			"build",
			label,
			_town_action_surface_label("build"),
			readiness
		)
	var tooltip_lines := [
		"Build Readiness",
		"- Town works: %d built, %d open order%s" % [
			built_buildings.size(),
			actions.size(),
			"" if actions.size() == 1 else "s",
		],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"built_count": built_buildings.size(),
		"open_order_count": actions.size(),
		"ready_order_count": ready_orders,
		"market_order_count": market_orders,
		"blocked_order_count": blocked_orders,
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _market_readiness_surface() -> Dictionary:
	var actions := TownRules.get_market_actions(_session)
	var ready_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if best_blocked.is_empty():
				best_blocked = action
			continue
		ready_orders += 1
		if best_ready.is_empty():
			best_ready = action

	var selected_action := best_ready
	var state_line := "no exchange orders listed"
	var visible := "Trade check: no exchange orders"
	if ready_orders > 0:
		state_line = "Ready now: %d exchange order%s" % [ready_orders, "" if ready_orders == 1 else "s"]
		visible = "Trade check: Ready x%d/%d" % [ready_orders, actions.size()]
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d exchange order%s waiting on stores" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Trade check: Blocked x0/%d" % blocked_orders

	var label := "No exchange order"
	var readiness := state_line
	var impact := "Exchange timing converts spare stock into the resource needed for build or muster orders."
	var next_step := "Build a market before using Trade orders, or return to Build and Muster planning."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Exchange order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "market")
		impact = _town_action_button_impact(selected_action, "market")
		next_step = _town_action_button_next_step(
			selected_action,
			"market",
			label,
			_town_action_surface_label("market"),
			readiness
		)
	elif actions.is_empty():
		var market_text := TownRules.describe_market(_session)
		if market_text.find("No market square") >= 0:
			state_line = "No market square is built here"
			readiness = state_line
			visible = "Trade check: no market | Exchange Hall"

	var tooltip_lines := [
		"Trade Readiness",
		"- Exchange orders: %d ready, %d blocked, %d listed" % [
			ready_orders,
			blocked_orders,
			actions.size(),
		],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"listed_order_count": actions.size(),
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _study_readiness_surface() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var actions := TownRules.get_spell_learning_actions(_session)
	var hero_value: Variant = _session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var tier := TownRules.current_spell_tier(town) if not town.is_empty() else 0
	var accessible_count := 0
	var known_count := 0
	if not town.is_empty():
		for spell_id_value in TownRules.accessible_spell_ids(town):
			var spell_id := String(spell_id_value)
			if spell_id == "":
				continue
			accessible_count += 1
			if SpellRules.knows_spell(hero, spell_id):
				known_count += 1

	var ready_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if best_blocked.is_empty():
				best_blocked = action
			continue
		ready_orders += 1
		if best_ready.is_empty():
			best_ready = action

	var selected_action := best_ready
	var state_line := "no archive halls are standing"
	var visible := "Study check: no archive"
	if tier > 0:
		state_line = "no uncatalogued spells remain for this hero"
		visible = "Study check: learned %d/%d" % [known_count, accessible_count]
	if ready_orders > 0:
		state_line = "Ready now: %d spell%s can be learned" % [ready_orders, "" if ready_orders == 1 else "s"]
		visible = "Study check: Ready x%d/%d" % [ready_orders, max(accessible_count, ready_orders)]
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d spell stud%s waiting on town or hero state" % [
			blocked_orders,
			"y" if blocked_orders == 1 else "ies",
		]
		visible = "Study check: Blocked x0/%d" % blocked_orders

	var label := "No spell study order"
	var readiness := state_line
	var impact := "Spell study expands the hero's field and battle options before leaving town."
	var next_step := "Build archive halls, review the spellbook, or leave when study is settled."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Spell study order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "study")
		impact = _town_action_button_impact(selected_action, "study")
		next_step = _town_action_button_next_step(
			selected_action,
			"study",
			label,
			_town_action_surface_label("study"),
			readiness
		)
	elif tier > 0:
		next_step = "Review the spellbook or leave when town orders are set."

	var tooltip_lines := [
		"Study Readiness",
		"- Archive tier: %d" % tier,
		"- Catalog: %d known, %d learnable, %d accessible" % [
			known_count,
			ready_orders,
			accessible_count,
		],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"archive_tier": tier,
		"accessible_count": accessible_count,
		"known_count": known_count,
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _muster_readiness_surface() -> Dictionary:
	var actions := TownRules.get_recruit_actions(_session)
	var town := TownRules.get_active_town(_session)
	var reserve_total := 0
	var ready_units := 0
	var market_units := 0
	var blocked_reserve := 0
	var ready_orders := 0
	var market_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_market := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var available := int(action.get("available_count", 0))
		var direct_count := int(action.get("direct_affordable_count", 0))
		var market_count := int(action.get("market_affordable_count", 0))
		reserve_total += max(0, available)
		if direct_count > 0:
			ready_orders += 1
			ready_units += direct_count
			if best_ready.is_empty() or direct_count > int(best_ready.get("direct_affordable_count", 0)):
				best_ready = action
			continue
		if market_count > 0:
			market_orders += 1
			market_units += market_count
			if best_market.is_empty() or market_count > int(best_market.get("market_affordable_count", 0)):
				best_market = action
			continue
		if available > 0:
			blocked_orders += 1
			blocked_reserve += available
			if best_blocked.is_empty() or available > int(best_blocked.get("available_count", 0)):
				best_blocked = action

	var selected_action := best_ready
	var state_line := "no recruits waiting"
	var visible := "Muster check: no recruits waiting"
	if ready_units > 0:
		state_line = "Ready now: %d recruit%s across %d order%s" % [
			ready_units,
			"" if ready_units == 1 else "s",
			ready_orders,
			"" if ready_orders == 1 else "s",
		]
		visible = "Muster check: Ready x%d/%d | %d order%s" % [
			ready_units,
			reserve_total,
			ready_orders,
			"" if ready_orders == 1 else "s",
		]
	elif market_units > 0:
		selected_action = best_market
		state_line = "Trade path: %d recruit%s can be unlocked through Exchange" % [
			market_units,
			"" if market_units == 1 else "s",
		]
		visible = "Muster check: Trade unlocks x%d/%d" % [market_units, reserve_total]
	elif blocked_reserve > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d recruit%s waiting on stores or prerequisites" % [
			blocked_reserve,
			"" if blocked_reserve == 1 else "s",
		]
		visible = "Muster check: Blocked x0/%d waiting" % blocked_reserve
	elif not actions.is_empty() and actions[0] is Dictionary:
		selected_action = actions[0]

	var label := "No recruit order"
	var readiness := state_line
	var impact := "Muster timing shapes field army strength before leaving town."
	var next_step := "Review another town order or leave when the muster plan is set."
	var cap_line := "No recruit stack is waiting in reserve."
	var best_available := 0
	var best_direct := 0
	var best_market_count := 0
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Recruit order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "recruit")
		impact = _town_action_button_impact(selected_action, "recruit")
		best_available = max(0, int(selected_action.get("available_count", 0)))
		best_direct = max(0, int(selected_action.get("direct_affordable_count", 0)))
		best_market_count = max(0, int(selected_action.get("market_affordable_count", 0)))
		var stack_label := _short_text(label.trim_prefix("Recruit "), 32)
		if best_direct > 0:
			cap_line = "%s can field %d of %d now; %d stay in reserve." % [
				stack_label,
				best_direct,
				best_available,
				max(0, best_available - best_direct),
			]
		elif best_market_count > 0:
			cap_line = "%s can unlock %d of %d through Exchange; %d still wait." % [
				stack_label,
				best_market_count,
				best_available,
				max(0, best_available - best_market_count),
			]
		elif best_available > 0:
			cap_line = "%s has %d waiting; stores field 0 now." % [stack_label, best_available]
		else:
			cap_line = "%s has no reserve waiting; next levy refills later." % stack_label
		next_step = _town_action_button_next_step(
			selected_action,
			"recruit",
			label,
			_town_action_surface_label("recruit"),
			readiness
		)
	var weekly_line := ""
	if not town.is_empty():
		weekly_line = "Weekly reserve: %s on Day %d" % [
			TownRules._describe_recruit_delta(OverworldRules.town_weekly_growth(town, _session)),
			OverworldRules.next_weekly_growth_day(_session.day),
		]
	var tooltip_lines := [
		"Muster Readiness",
		"- Town reserve: %d waiting across %d order%s" % [
			reserve_total,
			actions.size(),
			"" if actions.size() == 1 else "s",
		],
		"- %s" % state_line,
	]
	if weekly_line != "":
		tooltip_lines.append("- %s" % weekly_line)
	tooltip_lines.append("- Best order: %s" % label)
	tooltip_lines.append("- Best cap: %s" % cap_line)
	tooltip_lines.append("- Readiness: %s" % readiness)
	tooltip_lines.append("- Why it matters: %s" % impact)
	tooltip_lines.append("- Next practical action: %s" % next_step)
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"reserve_total": reserve_total,
		"ready_units": ready_units,
		"market_units": market_units,
		"blocked_reserve": blocked_reserve,
		"ready_order_count": ready_orders,
		"market_order_count": market_orders,
		"blocked_order_count": blocked_orders,
		"best_order_label": label,
		"best_order_available_count": best_available,
		"best_order_direct_count": best_direct,
		"best_order_market_count": best_market_count,
		"cap_line": cap_line,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _hire_readiness_surface() -> Dictionary:
	var actions := TownRules.get_tavern_actions(_session)
	var ready_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if best_blocked.is_empty():
				best_blocked = action
			continue
		ready_orders += 1
		if best_ready.is_empty():
			best_ready = action

	var heroes = _session.overworld.get("player_heroes", [])
	var roster_count: int = heroes.size() if heroes is Array else 0
	var selected_action := best_ready
	var state_line := "no hire orders listed"
	var visible := "Hire check: no hires"
	var tavern_text := TownRules.describe_tavern(_session)
	if ready_orders > 0:
		state_line = "Ready now: %d commander hire%s" % [ready_orders, "" if ready_orders == 1 else "s"]
		visible = "Hire check: Ready x%d/%d | roster %d" % [ready_orders, actions.size(), roster_count]
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d commander hire%s waiting on current stores" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Hire check: Blocked x0/%d | roster %d" % [blocked_orders, roster_count]
	elif tavern_text.find("Build ") >= 0:
		state_line = "Wayfarers Hall required before hiring"
		visible = "Hire check: build hall first"
	elif tavern_text.find("roster is already full") >= 0:
		state_line = "command roster is already full"
		visible = "Hire check: roster full"
	elif tavern_text.find("No additional commanders") >= 0 or tavern_text.find("No commanders") >= 0:
		state_line = "no additional commanders are currently available"
		visible = "Hire check: no commanders listed"

	var label := "No hire order"
	var readiness := state_line
	var impact := "Hiring adds another field commander before leaving town."
	var next_step := "Build a Wayfarers Hall, review the roster, or leave when command is settled."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Hire order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "tavern")
		impact = _town_action_button_impact(selected_action, "tavern")
		next_step = _town_action_button_next_step(
			selected_action,
			"tavern",
			label,
			_town_action_surface_label("tavern"),
			readiness
		)
	elif state_line == "command roster is already full":
		next_step = "Switch commanders or transfer troops; no additional hire can join this roster."
	elif state_line == "no additional commanders are currently available":
		next_step = "Keep the current command roster or return after new commanders become available."

	var tooltip_lines := [
		"Hire Readiness",
		"- Roster: %d commander%s stationed or traveling" % [roster_count, "" if roster_count == 1 else "s"],
		"- Hire orders: %d ready, %d blocked, %d listed" % [
			ready_orders,
			blocked_orders,
			actions.size(),
		],
		"- Current stores: %s" % TownRules._describe_resources(_session.overworld.get("resources", {})),
		"- %s" % state_line,
		"- Best hire: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"roster_count": roster_count,
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"listed_order_count": actions.size(),
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _transfer_readiness_surface() -> Dictionary:
	var actions := TownRules.get_transfer_actions(_session)
	var transfer_text := TownRules.describe_transfer(_session)
	var ready_orders := 0
	var blocked_orders := 0
	var selected_action := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if selected_action.is_empty():
				selected_action = action
			continue
		ready_orders += 1
		if selected_action.is_empty():
			selected_action = action

	var total_orders := ready_orders + blocked_orders
	var visible := "Transfer check: no moves ready"
	if ready_orders > 0:
		visible = "Transfer check: Ready x%d/%d" % [ready_orders, total_orders]
	elif blocked_orders > 0:
		visible = "Transfer check: Blocked x0/%d" % blocked_orders
	elif transfer_text.contains("No active town"):
		visible = "Transfer check: no active town"

	var label := "No transfer order"
	var route := "No garrison and stationed-hero route is ready."
	var readiness := "Needs a garrison and stationed hero in this town"
	var impact := "Keeps town defense and field army assignments visible before leaving."
	var next_step := "Use this panel after another commander is stationed here, or leave with current stacks."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Transfer order"))).strip_edges()
		if label == "":
			label = "Transfer order"
		route = String(selected_action.get("summary", "")).strip_edges()
		if route == "":
			route = "Move a stack between town holders."
		readiness = _town_action_button_readiness(selected_action, "transfer")
		impact = _town_action_button_impact(selected_action, "transfer")
		next_step = _town_action_button_next_step(
			selected_action,
			"transfer",
			label,
			_town_action_surface_label("transfer"),
			readiness
		)

	var tooltip_lines := [
		"Transfer Check",
		"- Orders: %d ready of %d" % [ready_orders, total_orders],
		"- Best order: %s" % label,
		"- Route: %s" % route,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"ready_count": ready_orders,
		"blocked_count": blocked_orders,
		"total_count": total_orders,
		"best_order": label,
		"route": route,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _response_readiness_surface() -> Dictionary:
	var actions := TownRules.get_response_actions(_session)
	var panel_text := TownRules.describe_responses(_session)
	var movement = _session.overworld.get("movement", {})
	var move_current := int(movement.get("current", 0))
	var move_max := int(movement.get("max", move_current))
	var ready_orders := 0
	var blocked_orders := 0
	var market_orders := 0
	var movement_blocked_orders := 0
	var resource_blocked_orders := 0
	var selected_action := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if bool(action.get("market_coverable", false)):
				market_orders += 1
			if bool(action.get("movement_blocked", false)):
				movement_blocked_orders += 1
			if bool(action.get("resource_blocked", false)):
				resource_blocked_orders += 1
			if selected_action.is_empty():
				selected_action = action
			continue
		ready_orders += 1
		if selected_action.is_empty() or bool(selected_action.get("disabled", false)):
			selected_action = action

	var total_orders := ready_orders + blocked_orders
	var state_line := "no immediate response order is open"
	var visible := "Response check: no route order"
	if ready_orders > 0:
		state_line = "Ready now: %d response order%s" % [ready_orders, "" if ready_orders == 1 else "s"]
		visible = "Response check: Ready x%d/%d | Move %d/%d" % [
			ready_orders,
			total_orders,
			move_current,
			move_max,
		]
	elif market_orders > 0:
		state_line = "Trade path: %d response order%s can be unlocked through Exchange" % [
			market_orders,
			"" if market_orders == 1 else "s",
		]
		visible = "Response check: Trade unlocks x%d/%d" % [market_orders, total_orders]
	elif movement_blocked_orders > 0:
		state_line = "Blocked: %d response order%s need more commander movement" % [
			movement_blocked_orders,
			"" if movement_blocked_orders == 1 else "s",
		]
		visible = "Response check: Move blocked x%d" % movement_blocked_orders
	elif resource_blocked_orders > 0:
		state_line = "Blocked: %d response order%s need more stores" % [
			resource_blocked_orders,
			"" if resource_blocked_orders == 1 else "s",
		]
		visible = "Response check: Store blocked x%d" % resource_blocked_orders
	elif blocked_orders > 0:
		state_line = "Blocked: %d response order%s waiting on town state" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Response check: Blocked x0/%d" % blocked_orders
	elif panel_text.find("Active route orders:") >= 0:
		state_line = "active response order already protects a linked route"
		visible = "Response check: active route order"
	elif panel_text.find("Threat lanes:") >= 0 or panel_text.find("Denied routes:") >= 0:
		state_line = "route pressure is visible, but no town response order is ready"
		visible = "Response check: watch route pressure"
	elif panel_text.find("Recovery steady") >= 0:
		state_line = "recovery is steady and no route order is currently open"

	var label := "No response order"
	var readiness := state_line
	var impact := "Response orders spend commander movement and town stores to steady linked routes, recovery, or threatened economy lines."
	var next_step := "Use the field route or end town orders when no response order is open."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Response order"))).strip_edges()
		if label == "":
			label = "Response order"
		readiness = _town_action_button_readiness(selected_action, "response")
		impact = _town_action_button_impact(selected_action, "response")
		next_step = _town_action_button_next_step(
			selected_action,
			"response",
			label,
			_town_action_surface_label("response"),
			readiness
		)
	elif panel_text.find("Threat lanes:") >= 0 or panel_text.find("Denied routes:") >= 0:
		next_step = "Leave town to reclaim denied sites or intercept the threat lane."
	elif panel_text.find("Active route orders:") >= 0:
		next_step = "Keep the active response in place, then review town orders or leave."

	var tooltip_lines := [
		"Response Readiness",
		"- Orders: %d ready, %d blocked, %d listed" % [
			ready_orders,
			blocked_orders,
			total_orders,
		],
		"- Movement: %d/%d before response orders" % [move_current, move_max],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	if market_orders > 0:
		tooltip_lines.append("- Exchange path: %d response order%s need Trade first" % [
			market_orders,
			"" if market_orders == 1 else "s",
		])
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"listed_order_count": total_orders,
		"market_order_count": market_orders,
		"movement_blocked_count": movement_blocked_orders,
		"resource_blocked_count": resource_blocked_orders,
		"movement_current": move_current,
		"movement_max": move_max,
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _artifact_readiness_surface() -> Dictionary:
	var actions := TownRules.get_artifact_actions(_session)
	var hero_value: Variant = _session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var artifacts := ArtifactRules.normalize_hero_artifacts(hero.get("artifacts", {}))
	var equipped: Dictionary = artifacts.get("equipped", {}) if artifacts.get("equipped", {}) is Dictionary else {}
	var inventory: Array = artifacts.get("inventory", []) if artifacts.get("inventory", []) is Array else []
	var equipped_count := 0
	var empty_slot_count := 0
	for slot in ArtifactRules.EQUIPMENT_SLOTS:
		if String(equipped.get(slot, "")) != "":
			equipped_count += 1
		else:
			empty_slot_count += 1

	var ready_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if best_blocked.is_empty():
				best_blocked = action
			continue
		ready_orders += 1
		if best_ready.is_empty():
			best_ready = action

	var owned_count := ArtifactRules.owned_artifact_ids(hero).size()
	var total_known := ContentService.get_content_ids(ContentService.ARTIFACTS_PATH).size()
	var selected_action := best_ready
	var state_line := "no relics owned yet"
	var visible := "Gear check: no relics"
	if ready_orders > 0:
		state_line = "Ready now: %d gear order%s can adjust the loadout" % [
			ready_orders,
			"" if ready_orders == 1 else "s",
		]
		visible = "Gear check: Ready x%d | %d equipped" % [ready_orders, equipped_count]
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d gear order%s waiting on current loadout state" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Gear check: Blocked x0/%d" % blocked_orders
	elif owned_count > 0:
		state_line = "Loadout set: %d equipped, %d in pack" % [equipped_count, inventory.size()]
		visible = "Gear check: Loadout %d/%d | Pack %d" % [
			equipped_count,
			ArtifactRules.EQUIPMENT_SLOTS.size(),
			inventory.size(),
		]

	var label := "No gear order"
	var readiness := state_line
	var impact := "Gear changes shape field movement, scouting, economy, and battle command before leaving town."
	var next_step := "Recover relics in the field, or leave when the current loadout is settled."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Gear order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "artifact")
		impact = _town_action_button_impact(selected_action, "artifact")
		next_step = _town_action_button_next_step(
			selected_action,
			"artifact",
			label,
			_town_action_surface_label("artifact"),
			readiness
		)
	elif owned_count > 0:
		next_step = "Review the loadout or leave when town orders are set."

	var collection_line := "%d owned" % owned_count
	if total_known > 0:
		collection_line = "%d/%d owned" % [owned_count, total_known]
	var tooltip_lines := [
		"Gear Readiness",
		"- Loadout: %d equipped, %d empty slot%s, %d in pack" % [
			equipped_count,
			empty_slot_count,
			"" if empty_slot_count == 1 else "s",
			inventory.size(),
		],
		"- Collection: %s" % collection_line,
		"- Gear orders: %d ready, %d blocked, %d listed" % [
			ready_orders,
			blocked_orders,
			actions.size(),
		],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"equipped_count": equipped_count,
		"empty_slot_count": empty_slot_count,
		"pack_count": inventory.size(),
		"owned_count": owned_count,
		"known_count": total_known,
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"listed_order_count": actions.size(),
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _record_town_action_result(
	lane: String,
	action_id: String,
	action: Dictionary,
	result: Dictionary,
	before: Dictionary
) -> void:
	var profile_started := ProfileLogScript.begin_usec()
	_last_message = String(result.get("message", ""))
	_last_action_recap = TownRules.build_town_action_recap(_session, lane, action_id, action, result, before)
	if bool(_last_action_recap.get("active", false)):
		_session.flags["last_town_action_recap"] = _last_action_recap.duplicate(true)
	if not result.is_empty() and not bool(result.get("ok", false)):
		UiAudio.play_invalid("TownShell._record_town_action_result", {
			"lane": lane,
			"action_id": action_id,
			"message": _last_message,
		})
	ProfileLogScript.emit_general("town", "action", lane, ProfileLogScript.elapsed_ms(profile_started), {
		"recap": ProfileLogScript.elapsed_ms(profile_started),
	}, _town_profile_metadata(false).merged({
		"action_id": action_id,
		"action_label": String(action.get("label", "")),
		"result_ok": bool(result.get("ok", false)),
	}, true), _session)

func _record_town_action_presentation(
	lane: String,
	action_id: String,
	action: Dictionary,
	result: Dictionary,
	before: Dictionary
) -> void:
	if lane not in ["build", "recruit", "response", "market", "study", "tavern", "specialty", "transfer"] or not bool(result.get("ok", false)):
		return
	if _town_stage_view == null or not _town_stage_view.has_method("present_town_action"):
		return
	var after := TownRules.town_action_consequence_signature(_session)
	if lane == "study":
		after["known_spell_ids"] = _town_active_known_spell_ids()
	elif lane == "tavern":
		after["player_hero_ids"] = _town_player_hero_ids()
	elif lane == "specialty":
		after["hero_progression"] = HeroProgressionRules.ensure_hero_progression(_session.overworld.get("hero", {})).duplicate(true)
	elif lane == "transfer":
		after["transfer"] = _town_transfer_holder_snapshot(action_id)
	var event_id := "town_army_transferred" if lane == "transfer" else ("town_specialty_selected" if lane == "specialty" else ("town_hero_hired" if lane == "tavern" else ("town_spell_studied" if lane == "study" else ("town_market_exchange_completed" if lane == "market" else ("town_route_response_ordered" if lane == "response" else ("town_units_recruited" if lane == "recruit" else "town_building_built"))))))
	var subject_kind := "unit_roster" if lane == "transfer" else ("hero_specialty" if lane == "specialty" else ("hero" if lane == "tavern" else ("spellbook" if lane == "study" else ("resource_stockpile" if lane == "market" else ("map_object" if lane == "response" else ("unit_roster" if lane == "recruit" else "building"))))))
	var policy := AnimationCueCatalog.cue_playback_policy_for_event(
		event_id,
		SettingsService.animation_preferences()
	)
	if (
		String(policy.get("event_id", "")) != event_id
		or String(policy.get("surface", "")) != "town"
		or String(policy.get("subject_kind", "")) != subject_kind
		or String(policy.get("selected_playback_policy", "")) != "queue_resolved"
		or lane in ["recruit", "response", "market", "study", "tavern", "specialty", "transfer"] and String(policy.get("selected_blocking_policy", "")) != "nonblocking"
		or lane == "build" and String(policy.get("selected_blocking_policy", "")) not in ["input_blocking_timeout", "nonblocking_reduced_motion", "nonblocking_fast_resolve"]
	):
		return
	var town := TownRules.get_active_town(_session)
	var presentation := {
		"event_id": event_id,
		"cue_id": String(policy.get("cue_id", "")),
		"town_placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"result_message": String(result.get("message", "")),
		"policy": policy.duplicate(true),
	}
	if lane == "transfer":
		var before_transfer: Dictionary = before.get("transfer", {}) if before.get("transfer", {}) is Dictionary else {}
		var after_transfer: Dictionary = after.get("transfer", {}) if after.get("transfer", {}) is Dictionary else {}
		var source_before := int(before_transfer.get("source_count", -1))
		var source_after := int(after_transfer.get("source_count", -1))
		var target_before := int(before_transfer.get("target_count", -1))
		var target_after := int(after_transfer.get("target_count", -1))
		var transferred_count := source_before - source_after
		if (
			before_transfer.is_empty()
			or after_transfer.is_empty()
			or String(before_transfer.get("source_holder_id", "")) != String(after_transfer.get("source_holder_id", ""))
			or String(before_transfer.get("target_holder_id", "")) != String(after_transfer.get("target_holder_id", ""))
			or String(before_transfer.get("unit_id", "")) != String(after_transfer.get("unit_id", ""))
			or String(before_transfer.get("amount_token", "")) != String(after_transfer.get("amount_token", ""))
			or not bool(before_transfer.get("holders_stationed", false))
			or not bool(after_transfer.get("holders_stationed", false))
			or transferred_count <= 0
			or target_after - target_before != transferred_count
			or source_before + target_before != source_after + target_after
		):
			return
		var unit_id := String(after_transfer.get("unit_id", ""))
		var unit := ContentService.get_unit(unit_id)
		if unit_id == "" or unit.is_empty():
			return
		presentation["action_id"] = action_id
		presentation["source_holder_id"] = String(after_transfer.get("source_holder_id", ""))
		presentation["source_holder_label"] = String(after_transfer.get("source_holder_label", ""))
		presentation["target_holder_id"] = String(after_transfer.get("target_holder_id", ""))
		presentation["target_holder_label"] = String(after_transfer.get("target_holder_label", ""))
		presentation["unit_id"] = unit_id
		presentation["unit_name"] = String(unit.get("name", unit_id))
		presentation["transferred_count"] = transferred_count
		presentation["source_count_before"] = source_before
		presentation["source_count_after"] = source_after
		presentation["target_count_before"] = target_before
		presentation["target_count_after"] = target_after
		presentation["town_action_recap"] = _last_action_recap.duplicate(true)
	elif lane == "specialty":
		var specialty_id := action_id.trim_prefix("choose_specialty:")
		var before_hero: Dictionary = before.get("hero_progression", {}) if before.get("hero_progression", {}) is Dictionary else {}
		var after_hero: Dictionary = after.get("hero_progression", {}) if after.get("hero_progression", {}) is Dictionary else {}
		var specialty := HeroProgressionRules.specialty_definition(specialty_id)
		var before_rank := HeroProgressionRules.specialty_rank(before_hero, specialty_id)
		var after_rank := HeroProgressionRules.specialty_rank(after_hero, specialty_id)
		var before_pending := HeroProgressionRules.pending_choices_remaining(before_hero)
		var after_pending := HeroProgressionRules.pending_choices_remaining(after_hero)
		if (
			specialty_id == ""
			or specialty_id == action_id
			or specialty.is_empty()
			or String(before_hero.get("id", "")) == ""
			or String(after_hero.get("id", "")) != String(before_hero.get("id", ""))
			or String(_session.overworld.get("active_hero_id", after_hero.get("id", ""))) != String(after_hero.get("id", ""))
			or after_rank != before_rank + 1
			or before_pending <= 0
			or after_pending != before_pending - 1
		):
			return
		presentation["action_id"] = action_id
		presentation["hero_id"] = String(after_hero.get("id", ""))
		presentation["hero_name"] = String(after_hero.get("name", "Hero"))
		presentation["specialty_id"] = specialty_id
		presentation["specialty_name"] = String(specialty.get("name", specialty_id))
		presentation["specialty_rank"] = after_rank
		presentation["pending_specialty_choice_count"] = after_pending
		presentation["town_action_recap"] = _last_action_recap.duplicate(true)
	elif lane == "tavern":
		var hero_id := action_id.trim_prefix("hire_hero:")
		var before_hero_ids: Array = before.get("player_hero_ids", []) if before.get("player_hero_ids", []) is Array else []
		var after_hero_ids: Array = after.get("player_hero_ids", []) if after.get("player_hero_ids", []) is Array else []
		var hero_template := ContentService.get_hero(hero_id)
		var recruit_cost := HeroCommandRules.hero_recruit_cost(hero_template)
		var resource_deltas := _town_action_resource_deltas(before, after)
		var cost_exact := not recruit_cost.is_empty() and resource_deltas.size() == recruit_cost.size()
		for resource_id_value in recruit_cost:
			var resource_id := String(resource_id_value)
			var expected_delta := -int(recruit_cost.get(resource_id, 0))
			var matched := false
			for delta_value in resource_deltas:
				if delta_value is Dictionary and String(delta_value.get("resource_id", "")) == resource_id and int(delta_value.get("delta", 0)) == expected_delta:
					matched = true
					break
			if expected_delta >= 0 or not matched:
				cost_exact = false
		if (
			hero_id == ""
			or hero_id == action_id
			or hero_template.is_empty()
			or hero_id in before_hero_ids
			or hero_id not in after_hero_ids
			or after_hero_ids.size() != before_hero_ids.size() + 1
			or not cost_exact
		):
			return
		presentation["hero_id"] = hero_id
		presentation["hero_name"] = String(hero_template.get("name", action.get("label", hero_id)))
		presentation["hero_faction_id"] = String(hero_template.get("faction_id", ""))
		presentation["hero_recruit_cost"] = recruit_cost.duplicate(true)
		presentation["resource_deltas"] = resource_deltas
		presentation["player_hero_count"] = after_hero_ids.size()
	elif lane == "study":
		var spell_id := action_id.trim_prefix("learn_spell:")
		var before_known: Array = before.get("known_spell_ids", []) if before.get("known_spell_ids", []) is Array else []
		var after_known: Array = after.get("known_spell_ids", []) if after.get("known_spell_ids", []) is Array else []
		var spell := ContentService.get_spell(spell_id)
		if (
			spell_id == ""
			or spell_id == action_id
			or spell.is_empty()
			or spell_id in before_known
			or spell_id not in after_known
			or after_known.size() != before_known.size() + 1
		):
			return
		presentation["spell_id"] = spell_id
		presentation["spell_name"] = String(spell.get("name", action.get("label", spell_id)))
		presentation["spell_school_id"] = String(spell.get("school_id", ""))
		presentation["spell_context"] = String(spell.get("context", ""))
		presentation["spell_tier"] = int(spell.get("tier", 0))
		presentation["known_spell_count"] = after_known.size()
	elif lane == "market":
		var parts := action_id.split(":")
		var action_type := String(parts[1]) if parts.size() == 4 else ""
		var resource_id := String(parts[2]) if parts.size() == 4 else ""
		var amount := int(parts[3]) if parts.size() == 4 else 0
		var resource_deltas := _town_action_resource_deltas(before, after)
		var resource_delta := 0
		var gold_delta := 0
		for delta_value in resource_deltas:
			if not (delta_value is Dictionary):
				continue
			if String(delta_value.get("resource_id", "")) == resource_id:
				resource_delta = int(delta_value.get("delta", 0))
			elif String(delta_value.get("resource_id", "")) == "gold":
				gold_delta = int(delta_value.get("delta", 0))
		if (
			parts.size() != 4
			or action_type not in ["buy", "sell"]
			or resource_id not in OverworldRules.NORMAL_MARKET_RESOURCE_KEYS
			or amount <= 0
			or resource_deltas.size() != 2
			or action_type == "buy" and (resource_delta != amount or gold_delta >= 0)
			or action_type == "sell" and (resource_delta != -amount or gold_delta <= 0)
		):
			return
		presentation["exchange_action"] = action_type
		presentation["exchange_resource_id"] = resource_id
		presentation["exchange_amount"] = amount
		presentation["resource_deltas"] = resource_deltas
		presentation["exchange_label"] = String(action.get("label", action_id))
	elif lane == "response":
		var placement_id := action_id.trim_prefix("site_response:")
		var recap: Dictionary = result.get("post_action_recap", {}) if result.get("post_action_recap", {}) is Dictionary else {}
		var node_result := OverworldRules._find_resource_node_by_placement(_session, placement_id)
		var node: Dictionary = node_result.get("node", {}) if node_result.get("node", {}) is Dictionary else {}
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var response_state := OverworldRules._resource_site_response_state(_session, node, site)
		if (
			placement_id == ""
			or placement_id == action_id
			or String(recap.get("kind", "")) != "site_response"
			or int(node_result.get("index", -1)) < 0
			or String(node.get("placement_id", "")) != placement_id
			or String(node.get("response_origin", "")) != "town"
			or int(node.get("response_last_day", -1)) != _session.day
			or not bool(response_state.get("active", false))
		):
			return
		presentation["response_placement_id"] = placement_id
		presentation["response_label"] = String(action.get("label", placement_id))
	elif lane == "recruit":
		var unit_id := action_id.trim_prefix("recruit:")
		var before_army: Dictionary = before.get("army_counts", {}) if before.get("army_counts", {}) is Dictionary else {}
		var after_army: Dictionary = after.get("army_counts", {}) if after.get("army_counts", {}) is Dictionary else {}
		var recruited_count := int(after_army.get(unit_id, 0)) - int(before_army.get(unit_id, 0))
		if unit_id == "" or unit_id == action_id or recruited_count <= 0:
			return
		var unit := ContentService.get_unit(unit_id)
		presentation["unit_id"] = unit_id
		presentation["unit_name"] = String(unit.get("name", action.get("label", unit_id)))
		presentation["recruited_count"] = recruited_count
	else:
		var building_id := action_id.trim_prefix("build:")
		var before_buildings: Array = before.get("built_buildings", []) if before.get("built_buildings", []) is Array else []
		var after_buildings: Array = after.get("built_buildings", []) if after.get("built_buildings", []) is Array else []
		if building_id == "" or building_id == action_id or building_id in before_buildings or building_id not in after_buildings:
			return
		var building := ContentService.get_building(building_id)
		presentation["building_id"] = building_id
		presentation["building_name"] = String(building.get("name", action.get("label", building_id)))
	_town_stage_view.call("present_town_action", presentation)

func _town_transfer_holder_snapshot(action_id: String) -> Dictionary:
	var parts := action_id.split(":")
	if parts.size() != 5 or String(parts[0]) != "transfer":
		return {}
	var source_holder_id := String(parts[1])
	var target_holder_id := String(parts[2])
	var unit_id := String(parts[3])
	var amount_token := String(parts[4])
	var town := TownRules.get_active_town(_session)
	if source_holder_id == "" or target_holder_id == "" or source_holder_id == target_holder_id or unit_id == "" or amount_token == "" or town.is_empty():
		return {}
	var stationed_holder_ids := [HeroCommandRules.HOLDER_GARRISON]
	for hero_value in HeroCommandRules.stationed_heroes(_session, town):
		if hero_value is Dictionary:
			stationed_holder_ids.append(String(hero_value.get("id", "")))
	var holders_stationed := source_holder_id in stationed_holder_ids and target_holder_id in stationed_holder_ids
	if not holders_stationed:
		return {}
	var source_stacks := _town_transfer_holder_stacks(town, source_holder_id)
	var target_stacks := _town_transfer_holder_stacks(town, target_holder_id)
	return {
		"source_holder_id": source_holder_id,
		"source_holder_label": _town_transfer_holder_label(town, source_holder_id),
		"target_holder_id": target_holder_id,
		"target_holder_label": _town_transfer_holder_label(town, target_holder_id),
		"unit_id": unit_id,
		"amount_token": amount_token,
		"source_count": _town_transfer_unit_count(source_stacks, unit_id),
		"target_count": _town_transfer_unit_count(target_stacks, unit_id),
		"holders_stationed": holders_stationed,
	}

func _town_transfer_holder_stacks(town: Dictionary, holder_id: String) -> Array:
	if holder_id == HeroCommandRules.HOLDER_GARRISON:
		return Array(town.get("garrison", [])).duplicate(true) if town.get("garrison", []) is Array else []
	var hero := HeroCommandRules.hero_by_id(_session, holder_id)
	var army: Dictionary = hero.get("army", {}) if hero.get("army", {}) is Dictionary else {}
	return Array(army.get("stacks", [])).duplicate(true) if army.get("stacks", []) is Array else []

func _town_transfer_holder_label(town: Dictionary, holder_id: String) -> String:
	if holder_id == HeroCommandRules.HOLDER_GARRISON:
		var town_template := ContentService.get_town(String(town.get("town_id", "")))
		return "%s garrison" % String(town_template.get("name", town.get("town_id", "Town")))
	var hero := HeroCommandRules.hero_by_id(_session, holder_id)
	return String(hero.get("name", holder_id))

func _town_transfer_unit_count(stacks: Array, unit_id: String) -> int:
	var count := 0
	for stack_value in stacks:
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
			count += int(stack_value.get("count", 0))
	return count

func _town_action_resource_deltas(before: Dictionary, after: Dictionary) -> Array:
	var before_resources: Dictionary = before.get("resources", {}) if before.get("resources", {}) is Dictionary else {}
	var after_resources: Dictionary = after.get("resources", {}) if after.get("resources", {}) is Dictionary else {}
	var deltas := []
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var before_value := int(before_resources.get(resource_id, 0))
		var after_value := int(after_resources.get(resource_id, 0))
		if before_value == after_value:
			continue
		deltas.append({"resource_id": resource_id, "before": before_value, "after": after_value, "delta": after_value - before_value})
	return deltas

func _record_town_artifact_presentation(
	action_id: String,
	action: Dictionary,
	result: Dictionary,
	before: Dictionary
) -> void:
	if not bool(result.get("ok", false)) or action.is_empty():
		return
	if _town_stage_view == null or not _town_stage_view.has_method("present_town_action"):
		return
	var hero_after: Dictionary = _session.overworld.get("hero", {}) if _session.overworld.get("hero", {}) is Dictionary else {}
	var before_artifacts: Dictionary = before.get("hero_artifacts", {}) if before.get("hero_artifacts", {}) is Dictionary else {}
	var hero_before := {"artifacts": before_artifacts.duplicate(true)}
	var after := TownRules.town_action_consequence_signature(_session)
	var event_id := ""
	var artifact_action_kind := ""
	var artifact_id := ""
	var artifact_location := ""
	var artifact_slot := ""
	var building_id := ""
	var reward_table_id := ""
	var reward_source_key := ""
	var artifact_cost := {}
	var resource_deltas := []
	if action_id.begins_with("commission_artifact:"):
		artifact_action_kind = "commission"
		event_id = "artifact_acquired"
		building_id = action_id.trim_prefix("commission_artifact:")
		artifact_id = String(result.get("artifact_id", ""))
		reward_table_id = String(result.get("artifact_reward_table_id", ""))
		artifact_cost = result.get("cost", {}).duplicate(true) if result.get("cost", {}) is Dictionary else {}
		resource_deltas = _town_action_resource_deltas(before, after)
		var town := TownRules.get_active_town(_session)
		var location := ArtifactRules.locate_artifact(hero_after, artifact_id)
		artifact_location = String(location.get("location", ""))
		artifact_slot = String(location.get("slot", ""))
		reward_source_key = String(town.get("artifact_reward_source_key", ""))
		if (
			building_id == ""
			or building_id == action_id
			or artifact_id == ""
			or artifact_id != String(action.get("artifact_id", ""))
			or building_id != String(action.get("building_id", ""))
			or reward_table_id == ""
			or reward_table_id != String(action.get("artifact_reward_table_id", ""))
			or reward_table_id != String(town.get("artifact_reward_table_id", ""))
			or reward_source_key == ""
			or reward_source_key != String(action.get("source_key", ""))
			or artifact_id != String(town.get("artifact_reward_id", ""))
			or building_id != String(town.get("artifact_reward_service_building_id", ""))
			or String(town.get("artifact_reward_claimed_by_owner", "")) != "player"
			or artifact_cost.is_empty()
			or artifact_cost != action.get("cost", {})
			or resource_deltas.size() != artifact_cost.size()
			or artifact_location not in ["equipped", "inventory"]
		):
			return
		for resource_id_value in artifact_cost:
			var resource_id := String(resource_id_value)
			var expected_delta := -int(artifact_cost.get(resource_id, 0))
			var matched := false
			for delta_value in resource_deltas:
				if delta_value is Dictionary and String(delta_value.get("resource_id", "")) == resource_id and int(delta_value.get("delta", 0)) == expected_delta:
					matched = true
					break
			if expected_delta >= 0 or not matched:
				return
	elif action_id.begins_with("equip_artifact:"):
		artifact_action_kind = "equip"
		event_id = "artifact_equipped"
		artifact_id = action_id.trim_prefix("equip_artifact:")
		var before_location := ArtifactRules.locate_artifact(hero_before, artifact_id)
		var after_location := ArtifactRules.locate_artifact(hero_after, artifact_id)
		artifact_location = String(after_location.get("location", ""))
		artifact_slot = String(after_location.get("slot", ""))
		if (
			artifact_id == ""
			or artifact_id == action_id
			or String(before_location.get("location", "")) != "inventory"
			or artifact_location != "equipped"
			or artifact_slot not in ArtifactRules.EQUIPMENT_SLOTS
		):
			return
	elif action_id.begins_with("unequip_artifact:"):
		artifact_action_kind = "stow"
		event_id = "artifact_unequipped"
		artifact_slot = action_id.trim_prefix("unequip_artifact:")
		artifact_id = String(before_artifacts.get("equipped", {}).get(artifact_slot, "")) if before_artifacts.get("equipped", {}) is Dictionary else ""
		var after_location := ArtifactRules.locate_artifact(hero_after, artifact_id)
		var after_artifacts := ArtifactRules.normalize_hero_artifacts(hero_after.get("artifacts", {}))
		artifact_location = String(after_location.get("location", ""))
		if (
			artifact_slot not in ArtifactRules.EQUIPMENT_SLOTS
			or artifact_id == ""
			or artifact_location != "inventory"
			or String(after_artifacts.get("equipped", {}).get(artifact_slot, "")) != ""
		):
			return
	else:
		return
	var artifact := ContentService.get_artifact(artifact_id)
	var artifact_icon_path := ArtifactRules.artifact_icon_path(artifact_id)
	if artifact.is_empty() or artifact_icon_path == "":
		return
	var policy := AnimationCueCatalog.cue_playback_policy_for_event(event_id, SettingsService.animation_preferences())
	var expected_subject_kind := "artifact" if event_id == "artifact_acquired" else "artifact_slot"
	if (
		String(policy.get("event_id", "")) != event_id
		or String(policy.get("surface", "")) != "artifact"
		or String(policy.get("subject_kind", "")) != expected_subject_kind
		or String(policy.get("selected_playback_policy", "")) != "queue_resolved"
		or event_id == "artifact_acquired" and String(policy.get("selected_blocking_policy", "")) not in ["input_blocking_timeout", "nonblocking_reduced_motion", "nonblocking_fast_resolve"]
		or event_id != "artifact_acquired" and String(policy.get("selected_blocking_policy", "")) != "nonblocking"
	):
		return
	var town := TownRules.get_active_town(_session)
	var presentation := {
		"event_id": event_id,
		"cue_id": String(policy.get("cue_id", "")),
		"town_placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"action_id": action_id,
		"artifact_action_kind": artifact_action_kind,
		"artifact_id": artifact_id,
		"artifact_name": String(artifact.get("name", artifact_id)),
		"artifact_icon_path": artifact_icon_path,
		"artifact_location": artifact_location,
		"artifact_slot": artifact_slot,
		"result_message": String(result.get("message", "")),
		"town_action_recap": _last_action_recap.duplicate(true),
		"policy": policy.duplicate(true),
	}
	if event_id == "artifact_acquired":
		presentation["building_id"] = building_id
		presentation["artifact_reward_table_id"] = reward_table_id
		presentation["artifact_reward_source_key"] = reward_source_key
		presentation["artifact_cost"] = artifact_cost.duplicate(true)
		presentation["resource_deltas"] = resource_deltas.duplicate(true)
	_town_stage_view.call("present_town_action", presentation)

func _town_active_known_spell_ids() -> Array:
	var hero_value: Variant = _session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var spellbook_value: Variant = hero.get("spellbook", {})
	var spellbook: Dictionary = spellbook_value if spellbook_value is Dictionary else {}
	var result := []
	for spell_id_value in spellbook.get("known_spell_ids", []):
		var spell_id := String(spell_id_value).strip_edges()
		if spell_id != "" and spell_id not in result:
			result.append(spell_id)
	result.sort()
	return result

func _town_player_hero_ids() -> Array:
	var result := []
	for hero_value in _session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		var hero_id := String(hero_value.get("id", "")).strip_edges()
		if hero_id != "" and hero_id not in result:
			result.append(hero_id)
	result.sort()
	return result

func _town_profile_metadata(first_render: bool) -> Dictionary:
	var town := TownRules.get_active_town(_session) if _session != null else {}
	return {
		"first_render": first_render,
		"first_render_minimal": first_render and _last_refresh_minimal,
		"minimal_current_tab_only": _last_refresh_minimal,
		"active_tab": _management_tabs.current_tab if _management_tabs != null else -1,
		"town_placement_id": String(town.get("placement_id", "")) if town is Dictionary else "",
		"town_id": String(town.get("town_id", "")) if town is Dictionary else "",
		"town_owner": String(town.get("owner", "")) if town is Dictionary else "",
		"town_entity_cache": _last_town_entity_cache_result.duplicate(true),
		"town_entity_cache_hit": bool(_last_town_entity_cache_result.get("hit", false)),
		"town_entity_cache_placement_id": String(_last_town_entity_cache_result.get("placement_id", "")),
		"save_surface": _last_save_surface_profile.duplicate(true),
		"save_surface_skipped_hidden": bool(_last_save_surface_profile.get("skipped_hidden", false)),
	}

func _handle_session_resolution() -> bool:
	if _session.scenario_status == "in_progress":
		return false
	AppRouter.go_to_scenario_outcome()
	return true

func _first_enabled_validation_action(actions: Variant) -> Dictionary:
	if not (actions is Array):
		return {}
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return action
	return {}

func _duplicate_action_array(actions: Variant) -> Array:
	var duplicated := []
	if not (actions is Array):
		return duplicated
	for action in actions:
		if action is Dictionary:
			duplicated.append(action.duplicate(true))
	return duplicated

func _validation_action_for_id(action_id: String) -> Dictionary:
	var catalog := validation_action_catalog()
	for lane in catalog.keys():
		var actions = catalog.get(lane, [])
		if not (actions is Array):
			continue
		for action in actions:
			if not (action is Dictionary):
				continue
			if bool(action.get("disabled", false)):
				continue
			if String(action.get("id", "")) != action_id:
				continue
			var result: Dictionary = action.duplicate(true)
			result["lane"] = String(lane)
			return result
	return {}

func _validation_progress_signature() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var hero_value: Variant = _session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var spellbook_value: Variant = hero.get("spellbook", {})
	var spellbook: Dictionary = spellbook_value if spellbook_value is Dictionary else {}
	return {
		"active_hero_id": String(_session.overworld.get("active_hero_id", "")),
		"resources": _duplicate_dictionary(_session.overworld.get("resources", {})),
		"army": _duplicate_dictionary(_session.overworld.get("army", {})),
		"specialties": _normalize_string_array(hero.get("specialties", [])),
		"pending_specialty_choices": _duplicate_array(hero.get("pending_specialty_choices", [])),
		"built_buildings": _normalize_string_array(town.get("built_buildings", [])),
		"available_recruits": _duplicate_dictionary(town.get("available_recruits", {})),
		"known_spell_ids": _normalize_string_array(spellbook.get("known_spell_ids", [])),
		"artifacts": _duplicate_dictionary(hero.get("artifacts", {})),
	}

func _duplicate_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

func _normalize_string_array(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not (value is Array):
		return normalized
	for entry in value:
		var text := String(entry)
		if text != "":
			normalized.append(text)
	return normalized

func _make_placeholder_label(text: String) -> Label:
	var label := FrontierVisualKit.placeholder_label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.custom_minimum_size = Vector2(188.0, 24.0)
	label.tooltip_text = text
	return label

func _unit_id_for_recruit_action(action: Dictionary) -> String:
	var unit_id := String(action.get("unit_id", "")).strip_edges()
	if unit_id != "":
		return unit_id
	var action_id := String(action.get("id", "")).strip_edges()
	if action_id.begins_with("recruit:"):
		return action_id.trim_prefix("recruit:")
	return action_id

func _unit_art_texture(path: String):
	var normalized_path := path.strip_edges()
	if normalized_path == "":
		return null
	if _unit_art_textures.has(normalized_path):
		return _unit_art_textures.get(normalized_path)
	if _unit_art_texture_missing.has(normalized_path):
		return null
	var texture: Variant = _texture_from_path(normalized_path)
	if texture is Texture2D:
		_unit_art_textures[normalized_path] = texture
		return texture
	_unit_art_texture_missing[normalized_path] = true
	return null

func _texture_from_path(path: String):
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null

func _set_compact_label(label: Label, full_text: String, max_lines: int) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines)

func _town_action_context_surface(dispatch_text: String = "") -> Dictionary:
	if _last_action_recap.is_empty():
		return {}
	var latest_action := String(_last_action_recap.get("happened", "")).strip_edges()
	if latest_action == "":
		latest_action = String(_last_action_recap.get("message", "")).strip_edges()
	if latest_action == "":
		latest_action = _last_message.strip_edges()
	if latest_action == "":
		return {}
	var departure := TownRules.town_departure_confirmation(_session)
	var next_step := String(_last_action_recap.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = String(departure.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = "Review the next town order or leave to the field."
	var handoff_check := _town_action_handoff_check(next_step, departure)
	var visible := "Latest: %s" % _short_text(_strip_sentence(latest_action), 42)
	visible = "%s | Next: %s" % [
		visible,
		_short_text(_strip_sentence(next_step).trim_suffix("."), 36),
	]
	var save_surface := _town_save_surface_for_context(true)
	var save_lines := []
	var save_check := String(save_surface.get("save_check", "")).strip_edges()
	var save_recap := String(save_surface.get("current_save_recap", "")).strip_edges()
	if save_check != "":
		save_lines.append(save_check)
	if save_recap != "":
		save_lines.append("Saving now recap:\n%s" % save_recap)
	var tooltip := _join_tooltip_sections([
		"Town Turn Context\n- Latest action: %s\n- Next practical step: %s\n- Handoff check: %s\n- Town status: %s" % [
			latest_action,
			next_step,
			handoff_check,
			TownRules.describe_status(_session),
		],
		String(_last_action_recap.get("tooltip_text", "")),
		String(departure.get("tooltip_text", "")),
		"\n".join(save_lines),
		dispatch_text,
	])
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"latest_action": latest_action,
		"next_step": next_step,
		"handoff_check": handoff_check,
		"source": "town_action_recap",
	}

func _town_save_surface_for_context(force_surface: bool) -> Dictionary:
	if force_surface:
		_last_save_surface_profile = {"forced": true, "skipped_hidden": false, "mode": "context_full"}
		return AppRouter.active_save_surface()
	_last_save_surface_profile = {"forced": false, "skipped_hidden": true, "mode": "context_lazy_hidden"}
	return {}

func _prepare_town_return_handoff() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return {}
	var town_name := _town_display_name(town)
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {})
	var move_current := int(movement.get("current", 0))
	var move_max := int(movement.get("max", move_current))
	var movement_line := "Move %d/%d" % [move_current, move_max]
	var field_position := "%d,%d" % [hero_pos.x, hero_pos.y]
	var departure: Dictionary = _last_departure_confirmation.duplicate(true) if not _last_departure_confirmation.is_empty() else TownRules.town_departure_confirmation(_session)
	var next_step := String(departure.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = "Select the next destination or end the turn when field orders are spent."
	var visible := "Town return: %s | %s" % [_short_text(town_name, 24), movement_line]
	var tooltip := "Town Return Handoff\n- Returned: Leave closed %s and reopened the overworld.\n- Field position: active hero remains at %s.\n- Movement: %s remains for field orders.\n- Day: Day %d did not advance.\n- Next practical action: %s" % [
		town_name,
		field_position,
		movement_line,
		_session.day,
		next_step,
	]
	var recap := {
		"happened": "Left %s for the field." % town_name,
		"affected": "%s at %s | %s" % [town_name, field_position, movement_line],
		"why_it_matters": "Leaving town returns to overworld control without advancing the day or spending field movement.",
		"next_step": next_step,
		"cue_text": visible,
		"tooltip_text": tooltip,
		"text": "After town: %s Next: %s" % [visible, next_step],
	}
	var handoff := {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"town_name": town_name,
		"town_placement_id": String(town.get("placement_id", "")),
		"field_position": field_position,
		"movement_line": movement_line,
		"day": _session.day,
		"next_step": next_step,
		"post_action_recap": recap,
	}
	_session.flags["town_return_handoff"] = handoff.duplicate(true)
	_session.flags["last_action"] = "left_town"
	return handoff

func _town_display_name(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("name", town.get("placement_id", "Town")))

func _town_action_handoff_check(next_step: String, departure: Dictionary = {}) -> String:
	var cleaned_next := _strip_sentence(next_step).trim_suffix(".")
	if cleaned_next == "":
		cleaned_next = "review the next town order"
	var departure_text := _strip_sentence(String(departure.get("visible_text", ""))).trim_suffix(".")
	if departure_text != "":
		return "%s; %s." % [cleaned_next.capitalize(), departure_text]
	return "%s before leaving, saving, or returning to the menu." % cleaned_next.capitalize()

func _strip_sentence(text: String) -> String:
	var cleaned := text.strip_edges().replace("\n", " ")
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	return cleaned

func _short_text(text: String, max_chars: int) -> String:
	var cleaned := _strip_sentence(text)
	if max_chars <= 0 or cleaned.length() <= max_chars:
		return cleaned
	return "%s..." % cleaned.left(max(0, max_chars - 3)).strip_edges()

func _first_matching_line(text: String, tokens: Array) -> String:
	for line_value in text.split("\n", false):
		var line := String(line_value).strip_edges()
		if line == "":
			continue
		for token_value in tokens:
			if line.find(String(token_value)) >= 0:
				return line
	return ""

func _production_overview_with_defense_check(overview: String, defense_visible: String) -> String:
	if defense_visible.strip_edges() == "":
		return overview
	var lines := overview.split("\n", false)
	for index in range(lines.size()):
		var line := String(lines[index])
		if line.strip_edges().begins_with("- Owner "):
			lines[index] = "- %s | %s" % [defense_visible.strip_edges(), line.strip_edges().trim_prefix("- ")]
			return "\n".join(lines)
	return _join_tooltip_sections([defense_visible, overview])

func _join_tooltip_sections(sections: Array) -> String:
	var lines := []
	for section in sections:
		var text := String(section).strip_edges()
		if text != "":
			lines.append(text)
	return "\n".join(lines)

func _refresh_management_tab_cues() -> void:
	var payload := _management_tab_readiness_payload()
	var tabs: Array = payload.get("tabs", [])
	for index in range(min(_management_tabs.get_tab_count(), tabs.size())):
		var tab: Dictionary = tabs[index]
		_management_tabs.set_tab_title(index, String(tab.get("title", "")))
	_management_tabs.tooltip_text = String(payload.get("tooltip_text", ""))
	_sync_management_tab_tooltip()

func _refresh_management_tab_titles_minimal() -> void:
	var titles := ["Build", "Muster", "Spells", "Trade", "Log"]
	for index in range(min(_management_tabs.get_tab_count(), titles.size())):
		_management_tabs.set_tab_title(index, String(titles[index]))
	_management_tabs.tooltip_text = "Town command tabs refresh after the first town frame."
	_sync_management_tab_tooltip()

func _management_tab_readiness_payload() -> Dictionary:
	var tabs := [
		_tab_readiness_entry("Build", TownRules.get_build_actions(_session)),
		_tab_readiness_entry("Muster", TownRules.get_recruit_actions(_session)),
		_tab_readiness_entry("Spells", TownRules.get_spell_learning_actions(_session)),
		_tab_readiness_entry("Trade", TownRules.get_market_actions(_session)),
		_tab_readiness_entry("Log", _logistics_tab_actions()),
	]
	var selected_index := clampi(_management_tabs.current_tab, 0, max(0, tabs.size() - 1))
	var selected: Dictionary = tabs[selected_index] if selected_index < tabs.size() else {}
	var tooltip_lines := ["Town command tabs:"]
	for tab in tabs:
		tooltip_lines.append("- %s" % String(tab.get("summary", "")))
	if not selected.is_empty():
		tooltip_lines.append("Selected: %s" % String(selected.get("focus", "")))
	return {
		"tabs": tabs,
		"selected_tab": selected.duplicate(true),
		"tooltip_text": "\n".join(tooltip_lines),
	}

func _tab_readiness_entry(base_title: String, actions: Variant) -> Dictionary:
	var total := 0
	var ready := 0
	if actions is Array:
		for action in actions:
			if not (action is Dictionary):
				continue
			total += 1
			if not bool(action.get("disabled", false)):
				ready += 1
	var title := base_title
	if ready > 0:
		title = "%s %d" % [base_title, ready]
	var summary := "%s: %d ready of %d orders" % [base_title, ready, total]
	var focus := "%s has %d ready order%s." % [
		base_title,
		ready,
		"" if ready == 1 else "s",
	]
	if ready <= 0 and total > 0:
		focus = "%s has %d blocked or spent order%s." % [
			base_title,
			total,
			"" if total == 1 else "s",
		]
	elif total <= 0:
		focus = "%s has no listed orders." % base_title
	return {
		"base_title": base_title,
		"title": title,
		"ready_count": ready,
		"total_count": total,
		"summary": summary,
		"focus": focus,
	}

func _logistics_tab_actions() -> Array:
	var actions := []
	actions.append_array(TownRules.get_tavern_actions(_session))
	actions.append_array(TownRules.get_transfer_actions(_session))
	actions.append_array(TownRules.get_response_actions(_session))
	actions.append_array(TownRules.get_artifact_actions(_session))
	return actions

func _management_tab_titles() -> Array:
	var titles := []
	for index in range(_management_tabs.get_tab_count()):
		titles.append(_management_tabs.get_tab_title(index))
	return titles

func _crest_text() -> String:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return "TOWN"
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(template.get("faction_id", "")))
	var name := String(faction.get("name", template.get("faction_id", "Town")))
	return name.left(4).to_upper()

func _active_town_faction_id() -> String:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return ""
	var template := ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("faction_id", "")).strip_edges()

func _refresh_faction_crest() -> void:
	var faction_id := _active_town_faction_id()
	var faction := ContentService.get_faction(faction_id)
	var icon_path := TownRules.faction_crest_icon_path(faction_id)
	var texture: Texture2D = load(icon_path) as Texture2D if icon_path != "" else null
	_crest_label.text = _crest_text()
	_crest_icon.texture = texture
	_crest_icon.visible = texture != null
	_crest_icon.tooltip_text = "%s crest" % String(faction.get("name", faction_id)) if texture != null else ""
	_build_faction_watermark.texture = texture
	_build_faction_watermark.visible = texture != null and not FrontierVisualKit.high_contrast_enabled()
	_crest_glyph.visible = texture == null
	if _crest_glyph.has_method("set_glyph"):
		_crest_glyph.call("set_glyph", "town", _faction_accent())

func _faction_crest_validation_snapshot() -> Dictionary:
	var faction_id := _active_town_faction_id()
	var icon_path := TownRules.faction_crest_icon_path(faction_id)
	var texture_path := _crest_icon.texture.resource_path if _crest_icon.texture != null else ""
	return {
		"faction_id": faction_id,
		"faction_name": String(ContentService.get_faction(faction_id).get("name", "")),
		"icon_path": icon_path,
		"texture_path": texture_path,
		"icon_visible": _crest_icon.visible,
		"fallback_visible": _crest_glyph.visible,
		"fallback_glyph_id": String(_crest_glyph.get("glyph_id")),
		"tooltip_text": _crest_icon.tooltip_text,
		"icon_rect": _crest_icon.get_global_rect(),
		"frame_rect": _crest_panel.get_global_rect(),
		"icon_stretch_mode": int(_crest_icon.stretch_mode),
		"icon_expand_mode": int(_crest_icon.expand_mode),
	}

func _style_action_button(button: Button, primary: bool = false) -> void:
	FrontierVisualKit.apply_button(button, "primary" if primary else "secondary", 108.0, 30.0, 12)

func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_panel(_banner_panel, "banner")
	FrontierVisualKit.apply_badge(_crest_panel, "gold")
	FrontierVisualKit.apply_panel(_town_stage_panel, "earth")
	FrontierVisualKit.apply_panel(_town_stage_frame_panel, "frame")
	FrontierVisualKit.apply_panel(_sidebar_shell_panel, "ink")
	FrontierVisualKit.apply_panel(_command_panel, "ink")
	FrontierVisualKit.apply_panel(_town_panel, "gold")
	FrontierVisualKit.apply_panel(_outlook_panel, "teal")
	FrontierVisualKit.apply_panel(_command_ledger_panel, "earth")
	FrontierVisualKit.apply_panel(_build_panel, "earth")
	FrontierVisualKit.apply_panel(_recruit_panel, "green")
	FrontierVisualKit.apply_panel(_study_panel, "blue")
	FrontierVisualKit.apply_panel(_market_panel, "gold")
	FrontierVisualKit.apply_panel(_logistics_panel, "teal")
	FrontierVisualKit.apply_panel(_town_catalog_panel, "earth")
	FrontierVisualKit.apply_panel(_footer_panel, "banner")
	FrontierVisualKit.apply_art_panel(_banner_panel, UI_ART_TOWN_BANNER_FRAME, "banner", 68, 14, Color(0.78, 0.74, 0.66, 1.0))
	FrontierVisualKit.apply_art_panel(_crest_panel, UI_ART_TOWN_CREST_MEDALLION, "gold", 70, 10, Color(0.82, 0.78, 0.70, 1.0))
	FrontierVisualKit.apply_art_panel(_town_stage_panel, UI_ART_TOWN_BUILD_PANEL, "earth", 58, 12, Color(0.66, 0.60, 0.54, 1.0))
	FrontierVisualKit.apply_art_panel(_town_stage_frame_panel, UI_ART_TOWN_RECRUIT_ROW, "frame", 62, 12, Color(0.66, 0.62, 0.56, 1.0))
	FrontierVisualKit.apply_art_panel(_sidebar_shell_panel, UI_ART_TOWN_PARCHMENT_PANEL, "ink", 66, 12, Color(0.44, 0.42, 0.38, 1.0))
	FrontierVisualKit.apply_art_panel(_command_panel, UI_ART_TOWN_PARCHMENT_PANEL, "ink", 66, 12, Color(0.44, 0.42, 0.38, 1.0))
	FrontierVisualKit.apply_art_panel(_town_panel, UI_ART_TOWN_RESOURCE_LEDGER, "gold", 62, 12, Color(0.56, 0.50, 0.44, 1.0))
	FrontierVisualKit.apply_art_panel(_outlook_panel, UI_ART_TOWN_RESOURCE_LEDGER, "teal", 62, 12, Color(0.50, 0.56, 0.54, 1.0))
	FrontierVisualKit.apply_art_panel(_command_ledger_panel, UI_ART_TOWN_RESOURCE_LEDGER, "earth", 62, 12, Color(0.52, 0.50, 0.46, 1.0))
	FrontierVisualKit.apply_art_panel(_resource_chip_panel, UI_ART_TOWN_RESOURCE_LEDGER, "gold", 62, 8, Color(0.70, 0.62, 0.48, 1.0))
	FrontierVisualKit.apply_art_panel(_build_panel, UI_ART_TOWN_BUILD_PANEL, "earth", 58, 12, Color(0.58, 0.52, 0.46, 1.0))
	FrontierVisualKit.apply_art_panel(_recruit_panel, UI_ART_TOWN_RECRUIT_ROW, "green", 62, 12, Color(0.58, 0.62, 0.52, 1.0))
	FrontierVisualKit.apply_art_panel(_study_panel, UI_ART_TOWN_PARCHMENT_PANEL, "blue", 66, 12, Color(0.42, 0.44, 0.52, 1.0))
	FrontierVisualKit.apply_art_panel(_market_panel, UI_ART_TOWN_RESOURCE_LEDGER, "gold", 62, 12, Color(0.56, 0.50, 0.44, 1.0))
	FrontierVisualKit.apply_art_panel(_logistics_panel, UI_ART_TOWN_BUILD_PANEL, "teal", 58, 12, Color(0.50, 0.56, 0.54, 1.0))
	FrontierVisualKit.apply_art_panel(_town_catalog_panel, UI_ART_TOWN_PARCHMENT_PANEL, "earth", 66, 16, Color(0.60, 0.55, 0.48, 1.0))
	FrontierVisualKit.apply_art_panel(_footer_panel, UI_ART_TOWN_BANNER_FRAME, "banner", 68, 12, Color(0.70, 0.66, 0.60, 1.0))
	FrontierVisualKit.apply_tab_container(_management_tabs)
	_apply_town_management_tab_breathing_room()
	_management_tabs.set_tab_title(0, "Build")
	_management_tabs.set_tab_title(1, "Muster")
	_management_tabs.set_tab_title(2, "Spells")
	_management_tabs.set_tab_title(3, "Trade")
	_management_tabs.set_tab_title(4, "Log")

	for button in [_confirm_build_button, _open_build_catalog_button, _open_muster_catalog_button, _town_orders_toggle_button, _save_button, _leave_button, _guide_button, _settings_button, _menu_button]:
		_style_action_button(button, true)
	FrontierVisualKit.apply_button(_town_catalog_close_button, "secondary", 108.0, 30.0, 12)
	FrontierVisualKit.apply_button(_guide_close_button, "secondary", 108.0, 30.0, 12)
	FrontierVisualKit.apply_panel(_guide_panel, "ink")
	_settings_button.tooltip_text = "Adjust sound, battle pace, and readability without leaving the town."
	_open_build_catalog_button.tooltip_text = "Open a modal catalog of every standing, available, and locked building in this town."
	_open_muster_catalog_button.tooltip_text = "Open a modal catalog of every unit tier, including locked dwellings and empty reserves."
	_town_catalog_close_button.tooltip_text = "Close this town window and return focus to the Town screen."
	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 112.0, 32.0, 12)

	for label in find_children("*Title", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "title", 13)

	FrontierVisualKit.apply_label(_header_label, "title", 20)
	FrontierVisualKit.apply_label(_status_label, "body", 12)
	FrontierVisualKit.apply_button(_resource_label, "secondary", 210.0, 30.0, 12)
	_resource_label.flat = true
	FrontierVisualKit.apply_label(_crest_label, "title", 16)
	FrontierVisualKit.apply_label(_town_catalog_title_label, "title", 20)
	FrontierVisualKit.apply_label(_town_catalog_subtitle_label, "body", 12)
	FrontierVisualKit.apply_label(_event_label, "body", 12)
	FrontierVisualKit.apply_label(_save_status_label, "muted", 12)
	FrontierVisualKit.apply_label(_guide_title_label, "title", 16)
	FrontierVisualKit.apply_label(_guide_label, "body", 13)

	FrontierVisualKit.apply_labels([
		_outlook_label,
		_command_ledger_label,
		_hero_label,
		_production_overview_label,
		_heroes_label,
		_specialty_label,
		_army_label,
		_town_label,
		_defense_label,
		_pressure_label,
		_building_label,
		_build_plan_label,
		_market_label,
		_recruit_label,
		_study_label,
		_spellbook_label,
		_tavern_label,
		_transfer_label,
		_response_label,
		_artifact_label,
	], "body", 12)

func _apply_town_management_tab_breathing_room() -> void:
	for style_name in TOWN_MANAGEMENT_TAB_STATE_STYLES:
		var shared_style := _management_tabs.get_theme_stylebox(style_name)
		var town_style := shared_style.duplicate() as StyleBox
		if town_style == null:
			continue
		town_style.content_margin_left = TOWN_MANAGEMENT_TAB_CONTENT_MARGIN_HORIZONTAL
		town_style.content_margin_right = TOWN_MANAGEMENT_TAB_CONTENT_MARGIN_HORIZONTAL
		_management_tabs.add_theme_stylebox_override(style_name, town_style)

func _faction_accent() -> Color:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return Color(0.88, 0.72, 0.40, 1.0)
	var template := ContentService.get_town(String(town.get("town_id", "")))
	match String(template.get("faction_id", "")):
		"faction_embercourt":
			return Color(0.88, 0.58, 0.34, 1.0)
		"faction_mireclaw":
			return Color(0.52, 0.74, 0.43, 1.0)
		"faction_sunvault":
			return Color(0.89, 0.77, 0.36, 1.0)
		"faction_thornwake":
			return Color(0.54, 0.70, 0.40, 1.0)
		"faction_brasshollow":
			return Color(0.76, 0.57, 0.34, 1.0)
		"faction_veilmourn":
			return Color(0.50, 0.62, 0.72, 1.0)
		_:
			return Color(0.88, 0.72, 0.40, 1.0)
