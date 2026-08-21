class_name HeroesSettingsService
extends Node

const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")

signal settings_changed(settings: Dictionary)
signal settings_commit_failed(result: Dictionary)
signal display_change_state_changed(snapshot: Dictionary)

const SETTINGS_VERSION := 14
const SETTINGS_DIR := "user://config"
const SETTINGS_FILE := "%s/settings.cfg" % SETTINGS_DIR
const SETTINGS_CANDIDATE_FILE := "%s.candidate" % SETTINGS_FILE
const SETTINGS_BACKUP_FILE := "%s.backup" % SETTINGS_FILE
const SETTINGS_TRANSACTION_FAILURE_ENV := "HEROES_LIKE_SETTINGS_FAIL_PHASE"
const THIRD_PARTY_NOTICES_PATH := "res://content/third_party_notices.json"

const PRESENTATION_WINDOWED := "windowed"
const PRESENTATION_BORDERLESS := "borderless"
const PRESENTATION_FULLSCREEN := "fullscreen"
const PRESENTATION_RESOLUTION_DEFAULT := "1920x1080"
const DISPLAY_CHANGE_TIMEOUT_SECONDS := 15.0
const DISPLAY_CHANGE_MIN_TIMEOUT_SECONDS := 0.1
const DISPLAY_CHANGE_MAX_TIMEOUT_SECONDS := 60.0
const DISPLAY_CHANGE_FORCE_SAVE_FAILURE_ENV := "HEROES_LIKE_DISPLAY_CHANGE_FORCE_SAVE_FAILURE"
const MUSIC_AUDIO_BUS := "Music"
const EFFECTS_AUDIO_BUS := "Effects"
const RENDER_QUALITY_LOW := "low"
const RENDER_QUALITY_BALANCED := "balanced"
const RENDER_QUALITY_HIGH := "high"
const COLOR_CUE_MODE_STANDARD := "standard"
const COLOR_CUE_MODE_ASSISTED := "assisted"
const BATTLE_CAMERA_SHAKE_FULL := "full"
const BATTLE_CAMERA_SHAKE_REDUCED := "reduced"
const BATTLE_CAMERA_SHAKE_OFF := "off"
const BATTLE_PLAYBACK_SPEED_NORMAL := "normal"
const BATTLE_PLAYBACK_SPEED_FAST := "fast"
const BATTLE_PLAYBACK_SPEED_INSTANT := "instant"
const KEYBOARD_NAVIGATION_LAYOUT_WASD := "wasd"
const KEYBOARD_NAVIGATION_LAYOUT_IJKL := "ijkl"
const KEYBOARD_NAVIGATION_LAYOUT_ARROWS := "arrows"
const CONTROLLER_UI_BUTTON_ACTIONS := {
	&"ui_up": JOY_BUTTON_DPAD_UP,
	&"ui_down": JOY_BUTTON_DPAD_DOWN,
	&"ui_left": JOY_BUTTON_DPAD_LEFT,
	&"ui_right": JOY_BUTTON_DPAD_RIGHT,
	&"ui_accept": JOY_BUTTON_A,
	&"ui_cancel": JOY_BUTTON_B,
	&"ui_focus_next": JOY_BUTTON_RIGHT_SHOULDER,
	&"ui_focus_prev": JOY_BUTTON_LEFT_SHOULDER,
}
const KEYBOARD_NAVIGATION_ACTIONS := {
	&"ui_up": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_W, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_I},
	&"ui_down": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_S, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_K},
	&"ui_left": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_A, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_J},
	&"ui_right": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_D, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_L},
}
const KEYBOARD_HERO_MOVEMENT_ACTIONS := {
	&"hero_move_up": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_W, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_I, KEYBOARD_NAVIGATION_LAYOUT_ARROWS: KEY_UP},
	&"hero_move_down": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_S, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_K, KEYBOARD_NAVIGATION_LAYOUT_ARROWS: KEY_DOWN},
	&"hero_move_left": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_A, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_J, KEYBOARD_NAVIGATION_LAYOUT_ARROWS: KEY_LEFT},
	&"hero_move_right": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_D, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_L, KEYBOARD_NAVIGATION_LAYOUT_ARROWS: KEY_RIGHT},
	&"hero_move_up_left": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_Q, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_U},
	&"hero_move_up_right": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_E, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_O},
	&"hero_move_down_left": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_Z, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_M},
	&"hero_move_down_right": {KEYBOARD_NAVIGATION_LAYOUT_WASD: KEY_C, KEYBOARD_NAVIGATION_LAYOUT_IJKL: KEY_PERIOD},
}
const HERO_DIAGONAL_NUMPAD_ACTIONS := {
	&"hero_move_up_left": KEY_KP_7,
	&"hero_move_up_right": KEY_KP_9,
	&"hero_move_down_left": KEY_KP_1,
	&"hero_move_down_right": KEY_KP_3,
}
const HERO_MOVEMENT_BINDING_OPTIONS := [
	{"action": &"hero_move_up_left", "label": "Up Left"},
	{"action": &"hero_move_up", "label": "Up"},
	{"action": &"hero_move_up_right", "label": "Up Right"},
	{"action": &"hero_move_left", "label": "Left"},
	{"action": &"hero_move_right", "label": "Right"},
	{"action": &"hero_move_down_left", "label": "Down Left"},
	{"action": &"hero_move_down", "label": "Down"},
	{"action": &"hero_move_down_right", "label": "Down Right"},
]
const HERO_MOVEMENT_RESERVED_KEYCODES := [
	KEY_ESCAPE,
	KEY_TAB,
	KEY_BACKTAB,
	KEY_ENTER,
	KEY_KP_ENTER,
	KEY_SPACE,
	KEY_SHIFT,
	KEY_CTRL,
	KEY_ALT,
	KEY_META,
	KEY_UP,
	KEY_DOWN,
	KEY_LEFT,
	KEY_RIGHT,
	KEY_KP_1,
	KEY_KP_3,
	KEY_KP_7,
	KEY_KP_9,
]

const RENDER_QUALITY_OPTIONS := [
	{"id": RENDER_QUALITY_LOW, "label": "Low", "msaa_2d": Viewport.MSAA_DISABLED},
	{"id": RENDER_QUALITY_BALANCED, "label": "Balanced", "msaa_2d": Viewport.MSAA_2X},
	{"id": RENDER_QUALITY_HIGH, "label": "High", "msaa_2d": Viewport.MSAA_4X},
]

const UI_SCALE_OPTIONS := [
	{"value": 100, "label": "100%"},
	{"value": 115, "label": "115%"},
	{"value": 130, "label": "130%"},
]

const COLOR_CUE_OPTIONS := [
	{"id": COLOR_CUE_MODE_STANDARD, "label": "Standard"},
	{"id": COLOR_CUE_MODE_ASSISTED, "label": "Shape + Palette"},
]

const BATTLE_CAMERA_SHAKE_OPTIONS := [
	{"id": BATTLE_CAMERA_SHAKE_FULL, "label": "Full", "scale": 1.0},
	{"id": BATTLE_CAMERA_SHAKE_REDUCED, "label": "Reduced", "scale": 0.35},
	{"id": BATTLE_CAMERA_SHAKE_OFF, "label": "Off", "scale": 0.0},
]

const BATTLE_PLAYBACK_SPEED_OPTIONS := [
	{"id": BATTLE_PLAYBACK_SPEED_NORMAL, "label": "Normal"},
	{"id": BATTLE_PLAYBACK_SPEED_FAST, "label": "Fast"},
	{"id": BATTLE_PLAYBACK_SPEED_INSTANT, "label": "Instant"},
]

const KEYBOARD_NAVIGATION_LAYOUT_OPTIONS := [
	{"id": KEYBOARD_NAVIGATION_LAYOUT_WASD, "label": "WASD + Arrows"},
	{"id": KEYBOARD_NAVIGATION_LAYOUT_IJKL, "label": "IJKL + Arrows"},
	{"id": KEYBOARD_NAVIGATION_LAYOUT_ARROWS, "label": "Arrows Only"},
]

const FRAME_RATE_OPTIONS := [
	{"value": 0, "label": "Unlimited"},
	{"value": 30, "label": "30 FPS"},
	{"value": 60, "label": "60 FPS"},
	{"value": 120, "label": "120 FPS"},
]

const PRESENTATION_OPTIONS := [
	{
		"id": PRESENTATION_WINDOWED,
		"label": "Windowed",
		"summary": "Resizable desktop window for multitasking and quick alt-tab play.",
	},
	{
		"id": PRESENTATION_BORDERLESS,
		"label": "Borderless",
		"summary": "Borderless presentation for a cleaner desktop handoff without a mode switch.",
	},
	{
		"id": PRESENTATION_FULLSCREEN,
		"label": "Fullscreen",
		"summary": "Dedicated fullscreen focus for the cleanest presentation.",
	},
]

const RESOLUTION_OPTIONS := [
	{
		"id": "1280x720",
		"label": "1280 x 720",
		"width": 1280,
		"height": 720,
		"summary": "HD 16:9 desktop window.",
	},
	{
		"id": "1600x900",
		"label": "1600 x 900",
		"width": 1600,
		"height": 900,
		"summary": "Mid-size 16:9 desktop window.",
	},
	{
		"id": PRESENTATION_RESOLUTION_DEFAULT,
		"label": "1920 x 1080",
		"width": 1920,
		"height": 1080,
		"summary": "Default 1080p 16:9 presentation.",
	},
	{
		"id": "2560x1440",
		"label": "2560 x 1440",
		"width": 2560,
		"height": 1440,
		"summary": "1440p 16:9 desktop window.",
	},
]

const HELP_TOPICS := [
	{
		"id": "campaign",
		"label": "Campaign",
		"summary": "Authored chapters with unlocks, carryover, and durable completion state.",
		"details": "Campaigns are the authored progression path. Use the campaign browser to inspect chapter status, read chapter notes, and start the next unlocked objective. Victories can export hero growth, spells, relics, resources, and authored outcome flags into later chapters.",
	},
	{
		"id": "skirmish",
		"label": "Skirmish",
		"summary": "Standalone map launches that reuse authored scenarios without changing campaign progress.",
		"details": "Skirmish launches an authored map as a one-off expedition. Pick a scenario, review its setup summary, choose a difficulty, and start. Skirmish runs reuse the same scenario bootstrap and save flow as campaigns, but they do not unlock campaign chapters or mutate campaign carryover.",
	},
	{
		"id": "overworld",
		"label": "Overworld",
		"summary": "Move heroes, gather resources, contest towns, and manage weekly tempo.",
		"details": "The overworld is the strategy layer. Movement points, scouting, town capture, map pickups, scripted events, and pressure growth all resolve here. Use the active hero to claim resources, trigger encounters, and position for the next town or battle objective before ending the day.",
	},
	{
		"id": "town",
		"label": "Town",
		"summary": "Build structures, recruit units, study spells, and shape faction identity.",
		"details": "Owned towns are strategic engines rather than generic shop screens. Build through authored prerequisites and dwelling upgrades, review weekly growth and economy output, recruit from current reserves, and use town access to study spells or reorganize your force before returning to the map.",
	},
	{
		"id": "battle",
		"label": "Battle",
		"summary": "Resolve encounters through initiative, ranged pressure, retaliation, and hero influence.",
		"details": "Battles are tactical confrontations launched from map encounters. Use Strike, Shoot, and Defend to manage tempo, retaliation, and range pressure while hero command, spells, artifacts, and unit abilities shape the outcome. Surviving forces and scenario results flow back into the active expedition.",
	},
	{
		"id": "outcome",
		"label": "Outcome",
		"summary": "Review the resolved scenario, save the result, and choose the next route.",
		"details": "The outcome screen is a resolved expedition checkpoint. Save preserves the result in the selected manual slot, Return to Menu keeps Continue Latest pointed at this outcome, and retry or continue actions start a fresh expedition or next campaign chapter without changing the saved outcome unless you save again.",
	},
	{
		"id": "saves",
		"label": "Save Flow",
		"summary": "Campaign progression and expedition saves are separate systems.",
		"details": "Campaign unlocks and carryover live in progression data, while current expeditions live in manual slots plus autosave. Continue Latest resumes the freshest valid expedition. The Saves tab inspects manual slots and autosave metadata before loading. Settings are stored separately from both systems and survive restarts on their own.",
	},
	{
		"id": "credits_notices",
		"label": "Credits & Notices",
		"summary": "Aurelion Reach contributor credit and the notices for software included in the desktop builds.",
		"details": "Open Credits & Notices below to read the complete scrollable Godot Engine, engine-component, and godot-cpp notices sourced from the running build. This reference does not launch play, change settings, or state a license for Aurelion Reach.",
	},
]

var settings: Dictionary = {}
var _pending_display_change: Dictionary = {}
var _display_change_last_countdown := -1
var _committed_settings: Dictionary = {}
var _last_settings_commit_result: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	ensure_controller_ui_actions()
	load_settings()

func _process(_delta: float) -> void:
	if not display_change_pending():
		set_process(false)
		return
	if Time.get_ticks_msec() >= int(_pending_display_change.get("deadline_msec", 0)):
		revert_display_change("timeout")
		return
	var countdown := display_change_countdown_seconds()
	if countdown != _display_change_last_countdown:
		_display_change_last_countdown = countdown
		display_change_state_changed.emit(display_change_snapshot())

func ensure_controller_ui_actions() -> void:
	for action in CONTROLLER_UI_BUTTON_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var button_index := int(CONTROLLER_UI_BUTTON_ACTIONS[action])
		var has_button := false
		for input_event in InputMap.action_get_events(action):
			if input_event is InputEventJoypadButton and int(input_event.button_index) == button_index:
				has_button = true
				break
		if has_button:
			continue
		var joypad_event := InputEventJoypadButton.new()
		joypad_event.button_index = button_index
		InputMap.action_add_event(action, joypad_event)

func ensure_settings() -> Dictionary:
	if settings.is_empty():
		load_settings()
	return settings

func build_default_settings() -> Dictionary:
	return {
		"version": SETTINGS_VERSION,
		"audio": {
			"master_volume_percent": 80,
			"music_volume_percent": 65,
			"effects_volume_percent": 75,
		},
		"presentation": {
			"mode": PRESENTATION_WINDOWED,
			"resolution": PRESENTATION_RESOLUTION_DEFAULT,
			"render_quality": RENDER_QUALITY_BALANCED,
			"vsync_enabled": true,
			"frame_rate_limit": 0,
		},
		"gameplay": {
			"battle_playback_speed": BATTLE_PLAYBACK_SPEED_NORMAL,
			"keyboard_navigation_layout": KEYBOARD_NAVIGATION_LAYOUT_WASD,
			"hero_movement_bindings": {},
		},
		"accessibility": {
			"ui_scale_percent": 100,
			"large_ui_text": false,
			"high_contrast_ui": false,
			"color_cue_mode": COLOR_CUE_MODE_STANDARD,
			"battle_camera_shake": BATTLE_CAMERA_SHAKE_FULL,
			"reduce_flashes": false,
			"reduce_motion": false,
			"reduce_repetitive_sounds": false,
		},
	}

func load_settings() -> void:
	if display_change_pending():
		revert_display_change("settings_reload")
	var recovery := _recover_settings_transaction()
	var defaults := build_default_settings()
	settings = defaults.duplicate(true)
	var live := _read_settings_file(SETTINGS_FILE)
	if bool(live.get("valid", false)):
		settings = (live.get("settings", defaults) as Dictionary).duplicate(true)
	_committed_settings = settings.duplicate(true)
	_last_settings_commit_result = {
		"ok": bool(live.get("valid", false)) or not bool(live.get("exists", false)),
		"path": SETTINGS_FILE if bool(live.get("valid", false)) else "",
		"changed": false,
		"reason": "recovered" if bool(recovery.get("recovered", false)) else ("loaded" if bool(live.get("valid", false)) else "defaults"),
		"message": "",
		"settings": settings.duplicate(true),
	}

	apply_settings()
	settings_changed.emit(settings.duplicate(true))

func save_settings() -> String:
	ensure_settings()
	var result := _persist_settings_transaction(settings)
	if bool(result.get("ok", false)):
		var persisted_settings: Dictionary = result.get("settings", settings) if result.get("settings", settings) is Dictionary else settings
		settings = persisted_settings.duplicate(true)
		_committed_settings = persisted_settings.duplicate(true)
		_last_settings_commit_result = result.duplicate(true)
		return SETTINGS_FILE
	_last_settings_commit_result = result.duplicate(true)
	return ""

func restore_default_settings(defer_display_change: bool = false) -> Dictionary:
	if display_change_pending():
		revert_display_change("restore_defaults")
	ensure_settings()
	var previous_settings := settings.duplicate(true)
	var default_settings := build_default_settings()
	var display_candidate := {
		"mode": String(default_settings.get("presentation", {}).get("mode", PRESENTATION_WINDOWED)),
		"resolution": String(default_settings.get("presentation", {}).get("resolution", PRESENTATION_RESOLUTION_DEFAULT)),
	}
	if defer_display_change:
		default_settings["presentation"]["mode"] = presentation_mode_id()
		default_settings["presentation"]["resolution"] = presentation_resolution_id()
	var changed := previous_settings != build_default_settings()
	settings = default_settings.duplicate(true)
	var commit := _commit_settings()
	if not bool(commit.get("ok", false)):
		return {
			"ok": false,
			"path": "",
			"settings": settings.duplicate(true),
			"changed": false,
			"display_change_deferred": defer_display_change,
			"display_candidate": display_candidate,
			"message": "Defaults could not be saved. Your previous settings remain active.",
		}
	return {
		"ok": true,
		"path": String(commit.get("path", SETTINGS_FILE)),
		"settings": settings.duplicate(true),
		"changed": changed,
		"display_change_deferred": defer_display_change,
		"display_candidate": display_candidate,
		"message": "Default sound, gameplay, readability, and quality settings restored and saved; display mode awaits confirmation." if defer_display_change else "Default settings restored and saved on this device.",
	}

func build_presentation_options() -> Array:
	var selected_mode := presentation_mode_id()
	var options := []
	for option in PRESENTATION_OPTIONS:
		options.append(
			{
				"id": String(option.get("id", "")),
				"label": String(option.get("label", option.get("id", "Mode"))),
				"summary": String(option.get("summary", "")),
				"selected": String(option.get("id", "")) == selected_mode,
			}
		)
	return options

func build_resolution_options() -> Array:
	var selected_resolution := presentation_resolution_id()
	var options := []
	for option in RESOLUTION_OPTIONS:
		options.append(
			{
				"id": String(option.get("id", "")),
				"label": String(option.get("label", option.get("id", "Resolution"))),
				"width": int(option.get("width", 0)),
				"height": int(option.get("height", 0)),
				"summary": String(option.get("summary", "")),
				"selected": String(option.get("id", "")) == selected_resolution,
			}
		)
	return options

func build_frame_rate_options() -> Array:
	var selected_limit := frame_rate_limit()
	var options := []
	for option in FRAME_RATE_OPTIONS:
		options.append({
			"value": int(option.get("value", 0)),
			"label": String(option.get("label", "Unlimited")),
			"selected": int(option.get("value", 0)) == selected_limit,
		})
	return options

func build_render_quality_options() -> Array:
	var selected_quality := render_quality_id()
	var options := []
	for option in RENDER_QUALITY_OPTIONS:
		options.append({
			"id": String(option.get("id", RENDER_QUALITY_BALANCED)),
			"label": String(option.get("label", "Balanced")),
			"msaa_2d": int(option.get("msaa_2d", Viewport.MSAA_2X)),
			"selected": String(option.get("id", "")) == selected_quality,
		})
	return options

func build_ui_scale_options() -> Array:
	var selected_scale := ui_scale_percent()
	var options := []
	for option in UI_SCALE_OPTIONS:
		options.append({
			"value": int(option.get("value", 100)),
			"label": String(option.get("label", "100%")),
			"selected": int(option.get("value", 100)) == selected_scale,
		})
	return options

func build_color_cue_options() -> Array:
	var selected_mode := color_cue_mode_id()
	var options := []
	for option in COLOR_CUE_OPTIONS:
		options.append({
			"id": String(option.get("id", COLOR_CUE_MODE_STANDARD)),
			"label": String(option.get("label", "Standard")),
			"selected": String(option.get("id", COLOR_CUE_MODE_STANDARD)) == selected_mode,
		})
	return options

func build_battle_camera_shake_options() -> Array:
	var selected_mode := battle_camera_shake_mode_id()
	var options := []
	for option in BATTLE_CAMERA_SHAKE_OPTIONS:
		options.append({
			"id": String(option.get("id", BATTLE_CAMERA_SHAKE_FULL)),
			"label": String(option.get("label", "Full")),
			"scale": float(option.get("scale", 1.0)),
			"selected": String(option.get("id", BATTLE_CAMERA_SHAKE_FULL)) == selected_mode,
		})
	return options

func build_battle_playback_speed_options() -> Array:
	var selected_speed := battle_playback_speed_id()
	var options := []
	for option in BATTLE_PLAYBACK_SPEED_OPTIONS:
		options.append({
			"id": String(option.get("id", BATTLE_PLAYBACK_SPEED_NORMAL)),
			"label": String(option.get("label", "Normal")),
			"selected": String(option.get("id", BATTLE_PLAYBACK_SPEED_NORMAL)) == selected_speed,
		})
	return options

func build_keyboard_navigation_layout_options() -> Array:
	var selected_layout := keyboard_navigation_layout_id()
	var options := []
	for option in KEYBOARD_NAVIGATION_LAYOUT_OPTIONS:
		options.append({
			"id": String(option.get("id", KEYBOARD_NAVIGATION_LAYOUT_WASD)),
			"label": String(option.get("label", "WASD + Arrows")),
			"selected": String(option.get("id", KEYBOARD_NAVIGATION_LAYOUT_WASD)) == selected_layout,
		})
	return options

func build_hero_movement_binding_options() -> Array:
	var bindings := _effective_hero_movement_bindings()
	var custom_bindings := custom_hero_movement_bindings()
	var options := []
	for option in HERO_MOVEMENT_BINDING_OPTIONS:
		var action := StringName(option.get("action", &""))
		var keycode := int(bindings.get(String(action), 0))
		options.append({
			"action": String(action),
			"label": String(option.get("label", String(action))),
			"keycode": keycode,
			"key_label": hero_movement_key_label(keycode),
			"custom": custom_bindings.has(String(action)),
		})
	return options

func presentation_mode_id() -> String:
	return String(ensure_settings().get("presentation", {}).get("mode", PRESENTATION_WINDOWED))

func presentation_resolution_id() -> String:
	return _normalize_presentation_resolution(String(ensure_settings().get("presentation", {}).get("resolution", PRESENTATION_RESOLUTION_DEFAULT)))

func presentation_resolution_size() -> Vector2i:
	var option := _presentation_resolution_option(presentation_resolution_id())
	return Vector2i(int(option.get("width", 1920)), int(option.get("height", 1080)))

func render_quality_id() -> String:
	return _normalize_render_quality(String(ensure_settings().get("presentation", {}).get("render_quality", RENDER_QUALITY_BALANCED)))

func render_quality_label() -> String:
	return String(_render_quality_option(render_quality_id()).get("label", "Balanced"))

func render_quality_msaa_2d() -> int:
	return int(_render_quality_option(render_quality_id()).get("msaa_2d", Viewport.MSAA_2X))

func vsync_enabled() -> bool:
	return bool(ensure_settings().get("presentation", {}).get("vsync_enabled", true))

func frame_rate_limit() -> int:
	return _normalize_frame_rate_limit(int(ensure_settings().get("presentation", {}).get("frame_rate_limit", 0)))

func frame_rate_limit_label() -> String:
	for option in FRAME_RATE_OPTIONS:
		if int(option.get("value", 0)) == frame_rate_limit():
			return String(option.get("label", "Unlimited"))
	return "Unlimited"

func battle_playback_speed_id() -> String:
	return _normalize_battle_playback_speed(String(ensure_settings().get("gameplay", {}).get("battle_playback_speed", BATTLE_PLAYBACK_SPEED_NORMAL)))

func battle_playback_speed_label() -> String:
	for option in BATTLE_PLAYBACK_SPEED_OPTIONS:
		if String(option.get("id", "")) == battle_playback_speed_id():
			return String(option.get("label", "Normal"))
	return "Normal"

func keyboard_navigation_layout_id() -> String:
	return _normalize_keyboard_navigation_layout(String(ensure_settings().get("gameplay", {}).get("keyboard_navigation_layout", KEYBOARD_NAVIGATION_LAYOUT_WASD)))

func keyboard_navigation_layout_label() -> String:
	for option in KEYBOARD_NAVIGATION_LAYOUT_OPTIONS:
		if String(option.get("id", "")) == keyboard_navigation_layout_id():
			return String(option.get("label", "WASD + Arrows"))
	return "WASD + Arrows"

func keyboard_navigation_layout_summary() -> String:
	if has_custom_hero_movement_bindings():
		return "Custom hero movement keys are active from the %s preset. Arrows retain interface navigation, and numpad diagonals remain available." % keyboard_navigation_layout_label()
	match keyboard_navigation_layout_id():
		KEYBOARD_NAVIGATION_LAYOUT_IJKL:
			return "I/J/K/L move cardinally; U/O/M/Period move diagonally. Arrows retain interface navigation, and numpad diagonals remain available."
		KEYBOARD_NAVIGATION_LAYOUT_ARROWS:
			return "Arrow keys retain interface navigation and available cardinal movement; numpad 7/9/1/3 provide diagonal movement."
		_:
			return "W/A/S/D move cardinally; Q/E/Z/C move diagonally. Arrows retain interface navigation, and numpad diagonals remain available."

func custom_hero_movement_bindings() -> Dictionary:
	return _normalize_hero_movement_bindings(ensure_settings().get("gameplay", {}).get("hero_movement_bindings", {}))

func has_custom_hero_movement_bindings() -> bool:
	return not custom_hero_movement_bindings().is_empty()

func hero_movement_keycode(action: StringName) -> int:
	return int(_effective_hero_movement_bindings().get(String(action), 0))

func hero_movement_key_label(keycode: int) -> String:
	if keycode <= 0:
		return "Unbound"
	var label := OS.get_keycode_string(keycode)
	return label if label != "" else "Key %d" % keycode

func hero_movement_action_label(action: StringName) -> String:
	for option in HERO_MOVEMENT_BINDING_OPTIONS:
		if StringName(option.get("action", &"")) == action:
			return String(option.get("label", String(action)))
	return String(action)

func is_hero_movement_key_allowed(keycode: int) -> bool:
	return keycode > 0 and keycode not in HERO_MOVEMENT_RESERVED_KEYCODES

func presentation_mode_label(mode_id: String) -> String:
	for option in PRESENTATION_OPTIONS:
		if String(option.get("id", "")) == mode_id:
			return String(option.get("label", mode_id))
	return "Windowed"

func presentation_resolution_label(resolution_id: String) -> String:
	var option := _presentation_resolution_option(resolution_id)
	return String(option.get("label", "1920 x 1080"))

func master_volume_percent() -> int:
	return int(ensure_settings().get("audio", {}).get("master_volume_percent", 80))

func music_volume_percent() -> int:
	return int(ensure_settings().get("audio", {}).get("music_volume_percent", 65))

func effects_volume_percent() -> int:
	return int(ensure_settings().get("audio", {}).get("effects_volume_percent", 75))

func music_audio_bus_name() -> String:
	var bus_index := _ensure_audio_bus(MUSIC_AUDIO_BUS, "Master")
	AudioServer.set_bus_volume_db(bus_index, _percent_to_db(music_volume_percent()))
	return MUSIC_AUDIO_BUS

func effects_audio_bus_name() -> String:
	var bus_index := _ensure_audio_bus(EFFECTS_AUDIO_BUS, "Master")
	AudioServer.set_bus_volume_db(bus_index, _percent_to_db(effects_volume_percent()))
	return EFFECTS_AUDIO_BUS

func effects_audio_muted() -> bool:
	return master_volume_percent() <= 0 or effects_volume_percent() <= 0

func ui_scale_percent() -> int:
	return _normalize_ui_scale_percent(int(ensure_settings().get("accessibility", {}).get("ui_scale_percent", 100)))

func ui_scale_label() -> String:
	return "%d%%" % ui_scale_percent()

func large_ui_text_enabled() -> bool:
	return ui_scale_percent() > 100

func high_contrast_ui_enabled() -> bool:
	return bool(ensure_settings().get("accessibility", {}).get("high_contrast_ui", false))

func color_cue_mode_id() -> String:
	return _normalize_color_cue_mode(String(ensure_settings().get("accessibility", {}).get("color_cue_mode", COLOR_CUE_MODE_STANDARD)))

func color_cue_mode_label() -> String:
	for option in COLOR_CUE_OPTIONS:
		if String(option.get("id", "")) == color_cue_mode_id():
			return String(option.get("label", "Standard"))
	return "Standard"

func color_cue_assist_enabled() -> bool:
	return color_cue_mode_id() == COLOR_CUE_MODE_ASSISTED

func battle_camera_shake_mode_id() -> String:
	return _normalize_battle_camera_shake(String(ensure_settings().get("accessibility", {}).get("battle_camera_shake", BATTLE_CAMERA_SHAKE_FULL)))

func battle_camera_shake_label() -> String:
	for option in BATTLE_CAMERA_SHAKE_OPTIONS:
		if String(option.get("id", "")) == battle_camera_shake_mode_id():
			return String(option.get("label", "Full"))
	return "Full"

func battle_camera_shake_scale() -> float:
	for option in BATTLE_CAMERA_SHAKE_OPTIONS:
		if String(option.get("id", "")) == battle_camera_shake_mode_id():
			return float(option.get("scale", 1.0))
	return 1.0

func reduced_motion_enabled() -> bool:
	return bool(ensure_settings().get("accessibility", {}).get("reduce_motion", false))

func reduced_flashes_enabled() -> bool:
	return bool(ensure_settings().get("accessibility", {}).get("reduce_flashes", false))

func reduced_repetitive_sounds_enabled() -> bool:
	return bool(ensure_settings().get("accessibility", {}).get("reduce_repetitive_sounds", false))

func animation_preferences(overrides: Dictionary = {}) -> Dictionary:
	var reduced_motion := reduced_motion_enabled()
	if overrides.has("reduced_motion") or overrides.has("reduce_motion"):
		reduced_motion = bool(overrides.get("reduced_motion", overrides.get("reduce_motion", reduced_motion)))
	var reduced_flashes := reduced_flashes_enabled()
	if overrides.has("reduced_flashes") or overrides.has("reduce_flashes"):
		reduced_flashes = bool(overrides.get("reduced_flashes", overrides.get("reduce_flashes", reduced_flashes)))
	var fast_mode := bool(overrides.get("fast_mode", false))
	return {
		"accessibility": {
			"reduce_motion": reduced_motion,
			"reduce_flashes": reduced_flashes,
		},
		"animation": {
			"fast_mode": fast_mode,
		},
	}

func preview_display_change(
	mode_id: String,
	resolution_id: String,
	timeout_seconds: float = DISPLAY_CHANGE_TIMEOUT_SECONDS
) -> Dictionary:
	ensure_settings()
	var replaced := display_change_pending()
	if replaced:
		revert_display_change("replaced")
	var normalized_mode := _normalize_presentation_mode(mode_id)
	var normalized_resolution := _normalize_presentation_resolution(resolution_id)
	var requested_size := _presentation_resolution_size_for_id(normalized_resolution)
	var committed_mode := presentation_mode_id()
	var committed_resolution := presentation_resolution_id()
	if normalized_mode == committed_mode and normalized_resolution == committed_resolution:
		var unchanged := display_change_snapshot()
		unchanged.merge({
			"ok": true,
			"changed": false,
			"replaced": replaced,
			"message": "Display settings already match this selection.",
		}, true)
		return unchanged
	var bounded_timeout := clampf(timeout_seconds, DISPLAY_CHANGE_MIN_TIMEOUT_SECONDS, DISPLAY_CHANGE_MAX_TIMEOUT_SECONDS)
	var prior_runtime := _capture_runtime_display_state()
	var applied_size := _apply_display_candidate(normalized_mode, requested_size)
	_pending_display_change = {
		"mode": normalized_mode,
		"resolution": normalized_resolution,
		"requested_size": requested_size,
		"applied_size": applied_size,
		"prior_mode": committed_mode,
		"prior_resolution": committed_resolution,
		"prior_runtime": prior_runtime,
		"timeout_seconds": bounded_timeout,
		"deadline_msec": Time.get_ticks_msec() + int(ceil(bounded_timeout * 1000.0)),
	}
	_display_change_last_countdown = display_change_countdown_seconds()
	set_process(true)
	var result := display_change_snapshot()
	result.merge({
		"ok": true,
		"changed": true,
		"replaced": replaced,
		"message": "Previewing display settings. Keep the change before the countdown ends.",
	}, true)
	display_change_state_changed.emit(result.duplicate(true))
	return result

func confirm_display_change() -> Dictionary:
	if not display_change_pending():
		return {
			"ok": false,
			"pending": false,
			"confirmed": false,
			"reason": "no_pending_change",
			"message": "There is no display change waiting for confirmation.",
		}
	var pending := _pending_display_change.duplicate(true)
	var previous_settings := ensure_settings().duplicate(true)
	settings["presentation"]["mode"] = String(pending.get("mode", PRESENTATION_WINDOWED))
	settings["presentation"]["resolution"] = String(pending.get("resolution", PRESENTATION_RESOLUTION_DEFAULT))
	var forced_failure := OS.get_environment(DISPLAY_CHANGE_FORCE_SAVE_FAILURE_ENV) == "1"
	var commit := {
		"ok": false,
		"path": "",
		"changed": false,
		"reason": "display_forced_failure",
		"message": "Display settings could not be saved. The previous display has been restored.",
		"settings": previous_settings.duplicate(true),
	} if forced_failure else _persist_settings_transaction(settings)
	if not bool(commit.get("ok", false)):
		settings = previous_settings
		_restore_runtime_display_state(pending.get("prior_runtime", {}))
		_clear_pending_display_change()
		_last_settings_commit_result = commit.duplicate(true)
		var failure := {
			"ok": false,
			"path": "",
			"changed": false,
			"pending": false,
			"confirmed": false,
			"reason": "save_failed",
			"mode": String(pending.get("mode", PRESENTATION_WINDOWED)),
			"resolution": String(pending.get("resolution", PRESENTATION_RESOLUTION_DEFAULT)),
			"settings": settings.duplicate(true),
			"message": "Display settings could not be saved. The previous display has been restored.",
		}
		settings_commit_failed.emit(failure.duplicate(true))
		display_change_state_changed.emit(failure.duplicate(true))
		return failure
	var persisted_settings: Dictionary = commit.get("settings", settings) if commit.get("settings", settings) is Dictionary else settings
	settings = persisted_settings.duplicate(true)
	_committed_settings = persisted_settings.duplicate(true)
	_last_settings_commit_result = commit.duplicate(true)
	_clear_pending_display_change()
	settings_changed.emit(settings.duplicate(true))
	var result := {
		"ok": true,
		"pending": false,
		"confirmed": true,
		"reason": "confirmed",
		"mode": presentation_mode_id(),
		"resolution": presentation_resolution_id(),
		"requested_size": pending.get("requested_size", Vector2i.ZERO),
		"applied_size": pending.get("applied_size", Vector2i.ZERO),
		"path": String(commit.get("path", SETTINGS_FILE)),
		"message": "Display settings kept and saved on this device.",
	}
	display_change_state_changed.emit(result.duplicate(true))
	return result

func revert_display_change(reason: String = "canceled") -> Dictionary:
	if not display_change_pending():
		return {
			"ok": true,
			"pending": false,
			"reverted": false,
			"reason": "no_pending_change",
			"message": "There is no display change to restore.",
		}
	var pending := _pending_display_change.duplicate(true)
	_restore_runtime_display_state(pending.get("prior_runtime", {}))
	_clear_pending_display_change()
	var normalized_reason := reason.strip_edges().to_lower()
	if normalized_reason == "":
		normalized_reason = "canceled"
	var result := {
		"ok": true,
		"pending": false,
		"reverted": true,
		"reason": normalized_reason,
		"mode": String(pending.get("mode", PRESENTATION_WINDOWED)),
		"resolution": String(pending.get("resolution", PRESENTATION_RESOLUTION_DEFAULT)),
		"prior_mode": String(pending.get("prior_mode", presentation_mode_id())),
		"prior_resolution": String(pending.get("prior_resolution", presentation_resolution_id())),
		"message": "Previous display settings restored.",
	}
	display_change_state_changed.emit(result.duplicate(true))
	return result

func display_change_pending() -> bool:
	return not _pending_display_change.is_empty()

func display_change_countdown_seconds() -> int:
	if not display_change_pending():
		return 0
	var remaining_msec := maxi(0, int(_pending_display_change.get("deadline_msec", 0)) - Time.get_ticks_msec())
	return int(ceil(float(remaining_msec) / 1000.0))

func display_change_snapshot() -> Dictionary:
	if not display_change_pending():
		var committed_size := presentation_resolution_size()
		return {
			"pending": false,
			"mode": presentation_mode_id(),
			"resolution": presentation_resolution_id(),
			"requested_size": committed_size,
			"applied_size": DisplayServer.window_get_size(),
			"seconds_remaining": 0,
			"timeout_seconds": 0.0,
			"deadline_msec": 0,
			"prior_mode": presentation_mode_id(),
			"prior_resolution": presentation_resolution_id(),
			"prior_runtime": {},
			"current_runtime": _capture_runtime_display_state(),
		}
	return {
		"pending": true,
		"mode": String(_pending_display_change.get("mode", PRESENTATION_WINDOWED)),
		"resolution": String(_pending_display_change.get("resolution", PRESENTATION_RESOLUTION_DEFAULT)),
		"requested_size": _pending_display_change.get("requested_size", Vector2i.ZERO),
		"applied_size": _pending_display_change.get("applied_size", Vector2i.ZERO),
		"seconds_remaining": display_change_countdown_seconds(),
		"timeout_seconds": float(_pending_display_change.get("timeout_seconds", DISPLAY_CHANGE_TIMEOUT_SECONDS)),
		"deadline_msec": int(_pending_display_change.get("deadline_msec", 0)),
		"prior_mode": String(_pending_display_change.get("prior_mode", PRESENTATION_WINDOWED)),
		"prior_resolution": String(_pending_display_change.get("prior_resolution", PRESENTATION_RESOLUTION_DEFAULT)),
		"prior_runtime": (_pending_display_change.get("prior_runtime", {}) as Dictionary).duplicate(true),
		"current_runtime": _capture_runtime_display_state(),
	}

func set_master_volume_percent(value: int) -> Dictionary:
	ensure_settings()
	settings["audio"]["master_volume_percent"] = clampi(value, 0, 100)
	return _commit_settings()

func set_music_volume_percent(value: int) -> Dictionary:
	ensure_settings()
	settings["audio"]["music_volume_percent"] = clampi(value, 0, 100)
	return _commit_settings()

func set_effects_volume_percent(value: int) -> Dictionary:
	ensure_settings()
	settings["audio"]["effects_volume_percent"] = clampi(value, 0, 100)
	return _commit_settings()

func set_presentation_mode(mode_id: String) -> Dictionary:
	ensure_settings()
	settings["presentation"]["mode"] = _normalize_presentation_mode(mode_id)
	return _commit_settings()

func set_presentation_resolution(resolution_id: String) -> Dictionary:
	ensure_settings()
	settings["presentation"]["resolution"] = _normalize_presentation_resolution(resolution_id)
	return _commit_settings()

func set_render_quality_id(quality_id: String) -> Dictionary:
	ensure_settings()
	settings["presentation"]["render_quality"] = _normalize_render_quality(quality_id)
	return _commit_settings()

func set_vsync_enabled(enabled: bool) -> Dictionary:
	ensure_settings()
	settings["presentation"]["vsync_enabled"] = enabled
	return _commit_settings()

func set_frame_rate_limit(value: int) -> Dictionary:
	ensure_settings()
	settings["presentation"]["frame_rate_limit"] = _normalize_frame_rate_limit(value)
	return _commit_settings()

func set_battle_playback_speed_id(speed_id: String) -> Dictionary:
	ensure_settings()
	settings["gameplay"]["battle_playback_speed"] = _normalize_battle_playback_speed(speed_id)
	return _commit_settings()

func set_keyboard_navigation_layout_id(layout_id: String) -> Dictionary:
	ensure_settings()
	settings["gameplay"]["keyboard_navigation_layout"] = _normalize_keyboard_navigation_layout(layout_id)
	settings["gameplay"]["hero_movement_bindings"] = {}
	return _commit_settings()

func set_hero_movement_key(action: StringName, keycode: int) -> Dictionary:
	ensure_settings()
	if not KEYBOARD_HERO_MOVEMENT_ACTIONS.has(action):
		return {
			"ok": false,
			"path": "",
			"changed": false,
			"reason": "unknown_action",
			"message": "That movement action is unavailable.",
			"settings": settings.duplicate(true),
		}
	if not is_hero_movement_key_allowed(keycode):
		return {
			"ok": false,
			"path": "",
			"changed": false,
			"reason": "reserved_key",
			"message": "That key is reserved.",
			"settings": settings.duplicate(true),
		}
	var bindings := _effective_hero_movement_bindings()
	var action_id := String(action)
	var previous_keycode := int(bindings.get(action_id, 0))
	if keycode == previous_keycode:
		var unchanged_commit := _commit_settings()
		unchanged_commit.merge({
			"ok": true,
			"action": action_id,
			"keycode": keycode,
			"swapped_action": "",
			"previous_keycode": previous_keycode,
			"unchanged": true,
		}, false)
		return unchanged_commit
	var swapped_action := ""
	for option in HERO_MOVEMENT_BINDING_OPTIONS:
		var candidate_action := String(option.get("action", ""))
		if candidate_action == action_id or int(bindings.get(candidate_action, 0)) != keycode:
			continue
		swapped_action = candidate_action
		if previous_keycode > 0 and is_hero_movement_key_allowed(previous_keycode):
			bindings[candidate_action] = previous_keycode
		else:
			bindings.erase(candidate_action)
		break
	bindings[action_id] = keycode
	settings["gameplay"]["hero_movement_bindings"] = _normalize_hero_movement_bindings(bindings)
	var commit := _commit_settings()
	commit.merge({
		"ok": true,
		"action": action_id,
		"keycode": keycode,
		"swapped_action": swapped_action,
		"previous_keycode": previous_keycode,
	}, false)
	return commit

func reset_hero_movement_bindings() -> Dictionary:
	ensure_settings()
	settings["gameplay"]["hero_movement_bindings"] = {}
	return _commit_settings()

func set_large_ui_text_enabled(enabled: bool) -> Dictionary:
	return set_ui_scale_percent(115 if enabled else 100)

func set_ui_scale_percent(value: int) -> Dictionary:
	ensure_settings()
	settings["accessibility"]["ui_scale_percent"] = _normalize_ui_scale_percent(value)
	settings["accessibility"]["large_ui_text"] = ui_scale_percent() > 100
	return _commit_settings()

func set_high_contrast_ui_enabled(enabled: bool) -> Dictionary:
	ensure_settings()
	settings["accessibility"]["high_contrast_ui"] = enabled
	return _commit_settings()

func set_color_cue_mode_id(mode_id: String) -> Dictionary:
	ensure_settings()
	settings["accessibility"]["color_cue_mode"] = _normalize_color_cue_mode(mode_id)
	return _commit_settings()

func set_battle_camera_shake_mode_id(mode_id: String) -> Dictionary:
	ensure_settings()
	settings["accessibility"]["battle_camera_shake"] = _normalize_battle_camera_shake(mode_id)
	return _commit_settings()

func set_reduced_motion_enabled(enabled: bool) -> Dictionary:
	ensure_settings()
	settings["accessibility"]["reduce_motion"] = enabled
	return _commit_settings()

func set_reduced_flashes_enabled(enabled: bool) -> Dictionary:
	ensure_settings()
	settings["accessibility"]["reduce_flashes"] = enabled
	return _commit_settings()

func set_reduced_repetitive_sounds_enabled(enabled: bool) -> Dictionary:
	ensure_settings()
	settings["accessibility"]["reduce_repetitive_sounds"] = enabled
	return _commit_settings()

func describe_settings() -> String:
	var accessibility_parts := []
	accessibility_parts.append("UI scale %s" % ui_scale_label())
	accessibility_parts.append("High contrast %s" % ("On" if high_contrast_ui_enabled() else "Off"))
	accessibility_parts.append("Color cues %s" % color_cue_mode_label())
	accessibility_parts.append("Battle shake %s" % battle_camera_shake_label())
	accessibility_parts.append("Reduced flashes %s" % ("On" if reduced_flashes_enabled() else "Off"))
	accessibility_parts.append("Reduced motion %s" % ("On" if reduced_motion_enabled() else "Off"))
	accessibility_parts.append("Reduced repetitive sounds %s" % ("On" if reduced_repetitive_sounds_enabled() else "Off"))
	return "\n".join(
		[
			"Presentation: %s | %s | %s quality | VSync %s | %s" % [presentation_mode_label(presentation_mode_id()), presentation_resolution_label(presentation_resolution_id()), render_quality_label(), "On" if vsync_enabled() else "Off", frame_rate_limit_label()],
			"Audio: Master %d%% | Music %d%% | Effects %d%%" % [master_volume_percent(), music_volume_percent(), effects_volume_percent()],
			"Gameplay: Battle playback %s | Navigation %s" % [battle_playback_speed_label(), keyboard_navigation_layout_label()],
			"Accessibility: %s" % " | ".join(accessibility_parts),
			describe_settings_persistence_check(),
		]
	)

func describe_settings_persistence_check() -> String:
	return "Settings check: most changes apply immediately and are stored in device config; display previews are stored only after Keep; campaign progress and expedition saves stay unchanged."

func help_browser_summary() -> String:
	return "Review the core modes and controls before launching a run. Campaign progression, skirmish starts, town growth, battle resolution, and save flow each have their own system boundaries."

func build_help_topics() -> Array:
	var topics := []
	for topic in HELP_TOPICS:
		topics.append(
			{
				"id": String(topic.get("id", "")),
				"label": String(topic.get("label", topic.get("id", "Guide"))),
				"summary": String(topic.get("summary", "")),
			}
		)
	return topics

func default_help_topic_id() -> String:
	if HELP_TOPICS.is_empty():
		return ""
	return String(HELP_TOPICS[0].get("id", ""))

func help_topic_label(topic_id: String) -> String:
	for topic in HELP_TOPICS:
		if String(topic.get("id", "")) == topic_id:
			return String(topic.get("label", topic_id))
	return "Campaign"

func describe_help_topic(topic_id: String) -> String:
	for topic in HELP_TOPICS:
		if String(topic.get("id", "")) == topic_id:
			return "%s\n%s\n\n%s" % [
				String(topic.get("label", topic_id)),
				String(topic.get("summary", "")),
				String(topic.get("details", "")),
			]
	return "Select a guide topic to review its mode summary and controls."

func credits_notices_payload() -> Dictionary:
	var authored: Dictionary = ContentService.load_json(THIRD_PARTY_NOTICES_PATH)
	var product: Dictionary = authored.get("product", {}) if authored.get("product", {}) is Dictionary else {}
	var items: Array = authored.get("items", []) if authored.get("items", []) is Array else []
	return {
		"schema_id": String(authored.get("schema_id", "")),
		"schema_version": int(authored.get("schema_version", 0)),
		"product": product.duplicate(true),
		"authored_items": items.duplicate(true),
		"engine_version": Engine.get_version_info().duplicate(true),
		"engine_license_text": Engine.get_license_text(),
		"engine_license_info": Engine.get_license_info().duplicate(true),
		"engine_copyright_info": Engine.get_copyright_info().duplicate(true),
	}

func credits_notices_text() -> String:
	var payload: Dictionary = credits_notices_payload()
	var product: Dictionary = payload.get("product", {}) if payload.get("product", {}) is Dictionary else {}
	var version: Dictionary = payload.get("engine_version", {}) if payload.get("engine_version", {}) is Dictionary else {}
	var lines: Array[String] = [
		String(product.get("name", "Aurelion Reach")),
		String(product.get("credit", "")),
		String(product.get("scope", "")),
		"",
		"Godot Engine %s" % String(version.get("string", "runtime")),
		"https://godotengine.org/license/",
		"",
		String(payload.get("engine_license_text", "")),
		"",
		"Godot Engine component notices",
	]
	var copyright_info: Array = payload.get("engine_copyright_info", []) if payload.get("engine_copyright_info", []) is Array else []
	for component_value in copyright_info:
		if not (component_value is Dictionary):
			continue
		var component: Dictionary = component_value
		lines.append("")
		lines.append(String(component.get("name", "Component")))
		var parts: Array = component.get("parts", []) if component.get("parts", []) is Array else []
		for part_value in parts:
			if not (part_value is Dictionary):
				continue
			var part: Dictionary = part_value
			var copyrights: Array = part.get("copyright", []) if part.get("copyright", []) is Array else []
			for copyright_value in copyrights:
				lines.append(String(copyright_value))
			var license_id := String(part.get("license", "")).strip_edges()
			if license_id != "":
				lines.append("License: %s" % license_id)
	var license_info: Dictionary = payload.get("engine_license_info", {}) if payload.get("engine_license_info", {}) is Dictionary else {}
	var license_ids: Array = license_info.keys()
	license_ids.sort()
	lines.append("")
	lines.append("Godot Engine component license texts")
	for license_id_value in license_ids:
		var license_id := String(license_id_value)
		lines.append("")
		lines.append(license_id)
		lines.append(String(license_info.get(license_id_value, "")))
	var authored_items: Array = payload.get("authored_items", []) if payload.get("authored_items", []) is Array else []
	lines.append("")
	lines.append("Aurelion Reach native binding notices")
	for item_value in authored_items:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value
		lines.append("")
		lines.append("%s %s" % [String(item.get("name", "Component")), String(item.get("version", ""))])
		lines.append(String(item.get("source_url", "")))
		lines.append("License: %s" % String(item.get("license_id", "")))
		lines.append(String(item.get("license_text", "")))
	return "\n".join(lines)

func apply_settings() -> void:
	_apply_keyboard_navigation_layout()
	_apply_accessibility_settings()
	_apply_presentation_settings()
	_apply_audio_settings()

func _commit_settings() -> Dictionary:
	if display_change_pending():
		revert_display_change("direct_settings_commit")
	var prior_settings := _committed_settings.duplicate(true) if not _committed_settings.is_empty() else build_default_settings()
	var candidate := settings.duplicate(true)
	var prior_runtime := _capture_runtime_display_state()
	var prior_input_map := _capture_managed_input_map()
	apply_settings()
	var persisted := _persist_settings_transaction(candidate)
	if not bool(persisted.get("ok", false)):
		settings = prior_settings
		apply_settings()
		_restore_managed_input_map(prior_input_map)
		_restore_runtime_display_state(prior_runtime)
		var failure := persisted.duplicate(true)
		failure["changed"] = false
		failure["settings"] = settings.duplicate(true)
		failure["message"] = "Settings could not be saved. Your previous settings remain active."
		_last_settings_commit_result = failure.duplicate(true)
		settings_changed.emit(settings.duplicate(true))
		settings_commit_failed.emit(failure.duplicate(true))
		return failure
	var committed_settings: Dictionary = persisted.get("settings", candidate) if persisted.get("settings", candidate) is Dictionary else candidate
	settings = committed_settings.duplicate(true)
	_committed_settings = committed_settings.duplicate(true)
	var result := persisted.duplicate(true)
	result["changed"] = committed_settings != prior_settings
	result["settings"] = committed_settings.duplicate(true)
	result["message"] = "Settings saved on this device."
	_last_settings_commit_result = result.duplicate(true)
	settings_changed.emit(settings.duplicate(true))
	return result

func last_settings_commit_result() -> Dictionary:
	return _last_settings_commit_result.duplicate(true)

func validation_settings_transaction_snapshot() -> Dictionary:
	return {
		"settings_file": SETTINGS_FILE,
		"candidate_file": SETTINGS_CANDIDATE_FILE,
		"backup_file": SETTINGS_BACKUP_FILE,
		"live_exists": FileAccess.file_exists(SETTINGS_FILE),
		"candidate_exists": FileAccess.file_exists(SETTINGS_CANDIDATE_FILE),
		"backup_exists": FileAccess.file_exists(SETTINGS_BACKUP_FILE),
		"settings": settings.duplicate(true),
		"committed_settings": _committed_settings.duplicate(true),
		"last_result": _last_settings_commit_result.duplicate(true),
		"runtime_display": _capture_runtime_display_state(),
		"input_map": _capture_managed_input_map(),
	}

func _apply_accessibility_settings() -> void:
	var root := get_tree().root
	if root != null:
		root.content_scale_factor = float(ui_scale_percent()) / 100.0
	FrontierVisualKitScript.set_high_contrast_enabled(high_contrast_ui_enabled())
	FrontierVisualKitScript.set_color_cue_mode(color_cue_mode_id())

func _apply_keyboard_navigation_layout() -> void:
	var managed_keycodes := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_Z, KEY_C, KEY_I, KEY_J, KEY_K, KEY_L, KEY_U, KEY_O, KEY_M, KEY_PERIOD]
	for action_value in KEYBOARD_NAVIGATION_ACTIONS:
		var action := StringName(action_value)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for input_event in InputMap.action_get_events(action):
			if not (input_event is InputEventKey):
				continue
			var key_event := input_event as InputEventKey
			if int(key_event.physical_keycode) in managed_keycodes or int(key_event.keycode) in managed_keycodes:
				InputMap.action_erase_event(action, input_event)
	for action_value in KEYBOARD_HERO_MOVEMENT_ACTIONS:
		var action := StringName(action_value)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for input_event in InputMap.action_get_events(action):
			if input_event is InputEventKey:
				InputMap.action_erase_event(action, input_event)
	var layout_id := keyboard_navigation_layout_id()
	if layout_id != KEYBOARD_NAVIGATION_LAYOUT_ARROWS:
		for action_value in KEYBOARD_NAVIGATION_ACTIONS:
			var action := StringName(action_value)
			var keycode := int(KEYBOARD_NAVIGATION_ACTIONS[action].get(layout_id, 0))
			_add_physical_key_event(action, keycode)
	for action_value in KEYBOARD_HERO_MOVEMENT_ACTIONS:
		var action := StringName(action_value)
		_add_physical_key_event(action, hero_movement_keycode(action))
	_ensure_hero_diagonal_numpad_actions()

func _add_physical_key_event(action: StringName, keycode: int) -> void:
	if keycode <= 0:
		return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)

func _ensure_hero_diagonal_numpad_actions() -> void:
	for action_value in HERO_DIAGONAL_NUMPAD_ACTIONS:
		var action := StringName(action_value)
		var keycode := int(HERO_DIAGONAL_NUMPAD_ACTIONS[action])
		var has_key := false
		for input_event in InputMap.action_get_events(action):
			if input_event is InputEventKey and int((input_event as InputEventKey).keycode) == keycode:
				has_key = true
				break
		if has_key:
			continue
		var key_event := InputEventKey.new()
		key_event.keycode = keycode
		InputMap.action_add_event(action, key_event)

func _apply_presentation_settings() -> void:
	_apply_display_candidate(presentation_mode_id(), presentation_resolution_size())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled() else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = frame_rate_limit()
	var root := get_tree().root
	if root != null:
		match render_quality_id():
			RENDER_QUALITY_LOW:
				root.msaa_2d = Viewport.MSAA_DISABLED
			RENDER_QUALITY_HIGH:
				root.msaa_2d = Viewport.MSAA_4X
			_:
				root.msaa_2d = Viewport.MSAA_2X

func _apply_display_candidate(mode_id: String, requested_size: Vector2i) -> Vector2i:
	var normalized_mode := _normalize_presentation_mode(mode_id)
	var applied_size := _clamped_display_size(normalized_mode, requested_size)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	match normalized_mode:
		PRESENTATION_FULLSCREEN:
			_set_runtime_window_size(applied_size)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		PRESENTATION_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_set_runtime_window_size(applied_size)
			_center_window(applied_size)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_set_runtime_window_size(applied_size)
			_center_window(applied_size)
	return applied_size

func _set_runtime_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	var root := get_tree().root
	if root == null:
		return
	root.size = size
	root.content_scale_size = size

func _apply_audio_settings() -> void:
	_apply_audio_bus("Master", master_volume_percent(), 0)
	music_audio_bus_name()
	effects_audio_bus_name()

func _ensure_audio_bus(bus_name: String, send_bus_name: String) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus()
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	if send_bus_name != "" and AudioServer.get_bus_index(send_bus_name) >= 0:
		AudioServer.set_bus_send(bus_index, send_bus_name)
	return bus_index

func _apply_audio_bus(bus_name: String, volume_percent: int, fallback_index: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0 and fallback_index >= 0 and AudioServer.get_bus_count() > fallback_index:
		bus_index = fallback_index
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, _percent_to_db(volume_percent))

func _percent_to_db(volume_percent: int) -> float:
	var clamped := clampi(volume_percent, 0, 100)
	if clamped <= 0:
		return -80.0
	return linear_to_db(float(clamped) / 100.0)

func _normalize_presentation_mode(mode_id: String) -> String:
	for option in PRESENTATION_OPTIONS:
		if String(option.get("id", "")) == mode_id:
			return mode_id
	return PRESENTATION_WINDOWED

func _normalize_presentation_resolution(resolution_id: String) -> String:
	for option in RESOLUTION_OPTIONS:
		if String(option.get("id", "")) == resolution_id:
			return resolution_id
	return PRESENTATION_RESOLUTION_DEFAULT

func _normalize_frame_rate_limit(value: int) -> int:
	for option in FRAME_RATE_OPTIONS:
		if int(option.get("value", 0)) == value:
			return value
	return 0

func _normalize_render_quality(quality_id: String) -> String:
	for option in RENDER_QUALITY_OPTIONS:
		if String(option.get("id", "")) == quality_id:
			return quality_id
	return RENDER_QUALITY_BALANCED

func _normalize_ui_scale_percent(value: int) -> int:
	for option in UI_SCALE_OPTIONS:
		if int(option.get("value", 100)) == value:
			return value
	return 100

func _normalize_color_cue_mode(mode_id: String) -> String:
	for option in COLOR_CUE_OPTIONS:
		if String(option.get("id", COLOR_CUE_MODE_STANDARD)) == mode_id:
			return mode_id
	return COLOR_CUE_MODE_STANDARD

func _normalize_battle_camera_shake(mode_id: String) -> String:
	var normalized := mode_id.strip_edges().to_lower()
	for option in BATTLE_CAMERA_SHAKE_OPTIONS:
		if String(option.get("id", BATTLE_CAMERA_SHAKE_FULL)) == normalized:
			return normalized
	return BATTLE_CAMERA_SHAKE_FULL

func _normalize_battle_playback_speed(speed_id: String) -> String:
	var normalized := speed_id.strip_edges().to_lower()
	for option in BATTLE_PLAYBACK_SPEED_OPTIONS:
		if String(option.get("id", BATTLE_PLAYBACK_SPEED_NORMAL)) == normalized:
			return normalized
	return BATTLE_PLAYBACK_SPEED_NORMAL

func _normalize_keyboard_navigation_layout(layout_id: String) -> String:
	var normalized := layout_id.strip_edges().to_lower()
	for option in KEYBOARD_NAVIGATION_LAYOUT_OPTIONS:
		if String(option.get("id", KEYBOARD_NAVIGATION_LAYOUT_WASD)) == normalized:
			return normalized
	return KEYBOARD_NAVIGATION_LAYOUT_WASD

func _normalize_hero_movement_bindings(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	var normalized := {}
	var used_keycodes := {}
	for option in HERO_MOVEMENT_BINDING_OPTIONS:
		var action := String(option.get("action", ""))
		var keycode := int(source.get(action, 0))
		if not is_hero_movement_key_allowed(keycode) or used_keycodes.has(keycode):
			continue
		normalized[action] = keycode
		used_keycodes[keycode] = true
	return normalized

func _effective_hero_movement_bindings() -> Dictionary:
	var layout_id := keyboard_navigation_layout_id()
	var bindings := {}
	for action_value in KEYBOARD_HERO_MOVEMENT_ACTIONS:
		var action := StringName(action_value)
		var keycode := int(KEYBOARD_HERO_MOVEMENT_ACTIONS[action].get(layout_id, 0))
		if keycode > 0:
			bindings[String(action)] = keycode
	var custom_bindings := custom_hero_movement_bindings()
	for action in custom_bindings:
		bindings[String(action)] = int(custom_bindings[action])
	return bindings

func _render_quality_option(quality_id: String) -> Dictionary:
	var normalized := _normalize_render_quality(quality_id)
	for option in RENDER_QUALITY_OPTIONS:
		if String(option.get("id", "")) == normalized:
			return option
	return RENDER_QUALITY_OPTIONS[1]

func _presentation_resolution_option(resolution_id: String) -> Dictionary:
	var normalized := _normalize_presentation_resolution(resolution_id)
	for option in RESOLUTION_OPTIONS:
		if String(option.get("id", "")) == normalized:
			return option
	return RESOLUTION_OPTIONS[2]

func _presentation_resolution_size_for_id(resolution_id: String) -> Vector2i:
	var option := _presentation_resolution_option(resolution_id)
	return Vector2i(int(option.get("width", 1920)), int(option.get("height", 1080)))

func _clamped_display_size(mode_id: String, requested_size: Vector2i) -> Vector2i:
	var safe_requested := Vector2i(maxi(1, requested_size.x), maxi(1, requested_size.y))
	if mode_id == PRESENTATION_FULLSCREEN:
		return safe_requested
	var screen_index := DisplayServer.window_get_current_screen()
	if screen_index < 0:
		return safe_requested
	var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return safe_requested
	var uniform_scale := minf(
		1.0,
		minf(
			float(usable_rect.size.x) / float(safe_requested.x),
			float(usable_rect.size.y) / float(safe_requested.y)
		)
	)
	return Vector2i(
		maxi(1, int(floor(float(safe_requested.x) * uniform_scale))),
		maxi(1, int(floor(float(safe_requested.y) * uniform_scale)))
	)

func _capture_runtime_display_state() -> Dictionary:
	var root := get_tree().root
	return {
		"mode": DisplayServer.window_get_mode(),
		"borderless": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
		"size": root.size if root != null else DisplayServer.window_get_size(),
		"position": DisplayServer.window_get_position(),
		"screen": DisplayServer.window_get_current_screen(),
	}

func _restore_runtime_display_state(runtime_state: Variant) -> void:
	if not (runtime_state is Dictionary) or (runtime_state as Dictionary).is_empty():
		_apply_display_candidate(presentation_mode_id(), presentation_resolution_size())
		return
	var previous := runtime_state as Dictionary
	var mode := int(previous.get("mode", DisplayServer.WINDOW_MODE_WINDOWED))
	var size: Vector2i = previous.get("size", presentation_resolution_size())
	var position: Vector2i = previous.get("position", DisplayServer.window_get_position())
	var screen := int(previous.get("screen", DisplayServer.window_get_current_screen()))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if screen >= 0 and screen < DisplayServer.get_screen_count():
		DisplayServer.window_set_current_screen(screen)
	_set_runtime_window_size(size)
	DisplayServer.window_set_position(position)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, bool(previous.get("borderless", false)))
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(mode)

func _clear_pending_display_change() -> void:
	_pending_display_change = {}
	_display_change_last_countdown = -1
	set_process(false)

func _persist_settings_transaction(candidate_value: Dictionary) -> Dictionary:
	if not _ensure_settings_dir():
		return _settings_transaction_failure("settings_dir_unavailable")
	var recovery := _recover_settings_transaction()
	if not bool(recovery.get("ok", false)):
		return _settings_transaction_failure(String(recovery.get("reason", "recovery_failed")))
	if _settings_path_exists(SETTINGS_FILE) and not FileAccess.file_exists(SETTINGS_FILE):
		return _settings_transaction_failure("live_not_regular_file")
	if not _remove_settings_artifact(SETTINGS_CANDIDATE_FILE):
		return _settings_transaction_failure("candidate_cleanup_failed")
	if _settings_path_exists(SETTINGS_BACKUP_FILE) and not _remove_settings_artifact(SETTINGS_BACKUP_FILE):
		return _settings_transaction_failure("backup_cleanup_failed")

	var canonical := _canonical_settings(candidate_value)
	var config := _settings_config(canonical)
	var expected_bytes := config.encode_to_text().to_utf8_buffer()
	var file := FileAccess.open(SETTINGS_CANDIDATE_FILE, FileAccess.WRITE)
	if file == null:
		return _settings_transaction_failure("candidate_open_failed")
	file.store_buffer(expected_bytes)
	file.flush()
	var write_error := file.get_error()
	var written_bytes := file.get_length()
	file.close()
	if write_error != OK or written_bytes != expected_bytes.size():
		_remove_settings_artifact(SETTINGS_CANDIDATE_FILE)
		return _settings_transaction_failure("candidate_write_failed")
	var candidate := _read_settings_file(SETTINGS_CANDIDATE_FILE)
	if (
		not bool(candidate.get("valid", false))
		or candidate.get("bytes", PackedByteArray()) != expected_bytes
		or candidate.get("settings", {}) != canonical
	):
		_remove_settings_artifact(SETTINGS_CANDIDATE_FILE)
		return _settings_transaction_failure("candidate_verification_failed")
	var fail_phase := OS.get_environment(SETTINGS_TRANSACTION_FAILURE_ENV).strip_edges().to_lower()
	if fail_phase == "precommit":
		_remove_settings_artifact(SETTINGS_CANDIDATE_FILE)
		return _settings_transaction_failure("precommit")

	var had_live := _settings_path_exists(SETTINGS_FILE)
	var prior_bytes := FileAccess.get_file_as_bytes(SETTINGS_FILE) if FileAccess.file_exists(SETTINGS_FILE) else PackedByteArray()
	if had_live:
		var backup_error := _rename_settings_path(SETTINGS_FILE, SETTINGS_BACKUP_FILE)
		if backup_error != OK:
			_remove_settings_artifact(SETTINGS_CANDIDATE_FILE)
			return _settings_transaction_failure("backup_preserve_failed")
	if fail_phase == "after_backup":
		var rolled_back := _rollback_settings_transaction(had_live, prior_bytes)
		return _settings_transaction_failure("after_backup" if rolled_back else "after_backup_rollback_failed")

	var commit_error := _rename_settings_path(SETTINGS_CANDIDATE_FILE, SETTINGS_FILE)
	if commit_error != OK:
		var rolled_back := _rollback_settings_transaction(had_live, prior_bytes)
		return _settings_transaction_failure("commit_rename_failed" if rolled_back else "commit_rollback_failed")
	var committed := _read_settings_file(SETTINGS_FILE)
	if (
		not bool(committed.get("valid", false))
		or committed.get("bytes", PackedByteArray()) != expected_bytes
		or committed.get("settings", {}) != canonical
	):
		var rolled_back := _rollback_settings_transaction(had_live, prior_bytes)
		return _settings_transaction_failure("commit_verification_failed" if rolled_back else "verification_rollback_failed")
	if not _remove_settings_artifact(SETTINGS_BACKUP_FILE):
		var rolled_back := _rollback_settings_transaction(had_live, prior_bytes)
		return _settings_transaction_failure("backup_cleanup_failed" if rolled_back else "cleanup_rollback_failed")
	return {
		"ok": true,
		"path": SETTINGS_FILE,
		"changed": true,
		"reason": "committed",
		"message": "Settings saved on this device.",
		"settings": canonical.duplicate(true),
	}

func _recover_settings_transaction() -> Dictionary:
	var live := _read_settings_file(SETTINGS_FILE)
	if bool(live.get("valid", false)):
		if not _remove_settings_artifact(SETTINGS_CANDIDATE_FILE):
			return {"ok": false, "recovered": false, "reason": "candidate_cleanup_failed"}
		if not _remove_settings_artifact(SETTINGS_BACKUP_FILE):
			return {"ok": false, "recovered": false, "reason": "backup_cleanup_failed"}
		return {"ok": true, "recovered": false, "live_valid": true, "reason": "live_valid"}

	var backup := _read_settings_file(SETTINGS_BACKUP_FILE)
	if bool(backup.get("valid", false)):
		if _settings_path_exists(SETTINGS_FILE) and not _remove_settings_artifact(SETTINGS_FILE):
			return {"ok": false, "recovered": false, "reason": "invalid_live_remove_failed"}
		var restore_error := _rename_settings_path(SETTINGS_BACKUP_FILE, SETTINGS_FILE)
		if restore_error != OK:
			return {"ok": false, "recovered": false, "reason": "backup_restore_failed", "error": restore_error}
		var restored := _read_settings_file(SETTINGS_FILE)
		if not bool(restored.get("valid", false)) or restored.get("bytes", PackedByteArray()) != backup.get("bytes", PackedByteArray()):
			return {"ok": false, "recovered": false, "reason": "backup_restore_verification_failed"}
		if not _remove_settings_artifact(SETTINGS_CANDIDATE_FILE):
			return {"ok": false, "recovered": true, "reason": "candidate_cleanup_failed"}
		return {"ok": true, "recovered": true, "live_valid": true, "reason": "backup_restored"}

	# A candidate is staging only and never recovery authority. Invalid live and
	# backup bytes remain available for diagnosis until a later explicit commit.
	if not _remove_settings_artifact(SETTINGS_CANDIDATE_FILE):
		return {"ok": false, "recovered": false, "reason": "candidate_cleanup_failed"}
	return {
		"ok": true,
		"recovered": false,
		"live_valid": false,
		"reason": "no_valid_backup" if bool(live.get("exists", false)) else "live_missing",
	}

func _read_settings_file(file_path: String) -> Dictionary:
	var result := {
		"exists": _settings_path_exists(file_path),
		"valid": false,
		"bytes": PackedByteArray(),
		"settings": {},
		"reason": "missing",
	}
	if not FileAccess.file_exists(file_path):
		if bool(result.get("exists", false)):
			result["reason"] = "not_regular_file"
		return result
	result["bytes"] = FileAccess.get_file_as_bytes(file_path)
	var config := ConfigFile.new()
	var load_error := config.load(file_path)
	if load_error != OK:
		result["reason"] = "parse_failed"
		result["error"] = load_error
		return result
	var semantic := _settings_config_semantic_report(config)
	if not bool(semantic.get("ok", false)):
		result["reason"] = String(semantic.get("reason", "semantic_invalid"))
		return result
	result["valid"] = true
	result["reason"] = "valid"
	result["settings"] = _settings_from_config(config)
	return result

func _settings_config_semantic_report(config: ConfigFile) -> Dictionary:
	if not config.has_section_key("meta", "version"):
		return {"ok": false, "reason": "missing_version"}
	var version_value: Variant = config.get_value("meta", "version", 0)
	if not (version_value is int):
		return {"ok": false, "reason": "invalid_version_type"}
	var version := int(version_value)
	if version < 1 or version > SETTINGS_VERSION:
		return {"ok": false, "reason": "unsupported_version"}
	var required := [
		[1, "audio", "master_volume_percent", TYPE_INT],
		[1, "audio", "music_volume_percent", TYPE_INT],
		[1, "presentation", "mode", TYPE_STRING],
		[1, "accessibility", "large_ui_text", TYPE_BOOL],
		[1, "accessibility", "reduce_motion", TYPE_BOOL],
		[2, "presentation", "resolution", TYPE_STRING],
		[3, "audio", "effects_volume_percent", TYPE_INT],
		[4, "presentation", "vsync_enabled", TYPE_BOOL],
		[4, "presentation", "frame_rate_limit", TYPE_INT],
		[5, "presentation", "render_quality", TYPE_STRING],
		[6, "accessibility", "ui_scale_percent", TYPE_INT],
		[7, "accessibility", "high_contrast_ui", TYPE_BOOL],
		[8, "accessibility", "color_cue_mode", TYPE_STRING],
		[9, "gameplay", "battle_playback_speed", TYPE_STRING],
		[10, "gameplay", "keyboard_navigation_layout", TYPE_STRING],
		[11, "gameplay", "hero_movement_bindings", TYPE_DICTIONARY],
		[12, "accessibility", "battle_camera_shake", TYPE_STRING],
		[13, "accessibility", "reduce_flashes", TYPE_BOOL],
		[14, "accessibility", "reduce_repetitive_sounds", TYPE_BOOL],
	]
	for requirement in required:
		if version < int(requirement[0]):
			continue
		var section := String(requirement[1])
		var key := String(requirement[2])
		if not config.has_section_key(section, key):
			return {"ok": false, "reason": "missing_required_key", "section": section, "key": key}
		if typeof(config.get_value(section, key)) != int(requirement[3]):
			return {"ok": false, "reason": "invalid_required_type", "section": section, "key": key}
	return {"ok": true, "version": version}

func _settings_from_config(config: ConfigFile) -> Dictionary:
	var defaults := build_default_settings()
	var loaded := defaults.duplicate(true)
	loaded["version"] = SETTINGS_VERSION
	loaded["audio"]["master_volume_percent"] = clampi(int(config.get_value("audio", "master_volume_percent", defaults["audio"]["master_volume_percent"])), 0, 100)
	loaded["audio"]["music_volume_percent"] = clampi(int(config.get_value("audio", "music_volume_percent", defaults["audio"]["music_volume_percent"])), 0, 100)
	loaded["audio"]["effects_volume_percent"] = clampi(int(config.get_value("audio", "effects_volume_percent", defaults["audio"]["effects_volume_percent"])), 0, 100)
	loaded["presentation"]["mode"] = _normalize_presentation_mode(String(config.get_value("presentation", "mode", defaults["presentation"]["mode"])))
	loaded["presentation"]["resolution"] = _normalize_presentation_resolution(String(config.get_value("presentation", "resolution", defaults["presentation"]["resolution"])))
	loaded["presentation"]["render_quality"] = _normalize_render_quality(String(config.get_value("presentation", "render_quality", defaults["presentation"]["render_quality"])))
	loaded["presentation"]["vsync_enabled"] = bool(config.get_value("presentation", "vsync_enabled", defaults["presentation"]["vsync_enabled"]))
	loaded["presentation"]["frame_rate_limit"] = _normalize_frame_rate_limit(int(config.get_value("presentation", "frame_rate_limit", defaults["presentation"]["frame_rate_limit"])))
	loaded["gameplay"]["battle_playback_speed"] = _normalize_battle_playback_speed(String(config.get_value("gameplay", "battle_playback_speed", defaults["gameplay"]["battle_playback_speed"])))
	loaded["gameplay"]["keyboard_navigation_layout"] = _normalize_keyboard_navigation_layout(String(config.get_value("gameplay", "keyboard_navigation_layout", defaults["gameplay"]["keyboard_navigation_layout"])))
	loaded["gameplay"]["hero_movement_bindings"] = _normalize_hero_movement_bindings(config.get_value("gameplay", "hero_movement_bindings", defaults["gameplay"]["hero_movement_bindings"]))
	var legacy_large_text := bool(config.get_value("accessibility", "large_ui_text", defaults["accessibility"]["large_ui_text"]))
	var migrated_scale := 115 if legacy_large_text else 100
	loaded["accessibility"]["ui_scale_percent"] = _normalize_ui_scale_percent(int(config.get_value("accessibility", "ui_scale_percent", migrated_scale)))
	loaded["accessibility"]["large_ui_text"] = int(loaded["accessibility"]["ui_scale_percent"]) > 100
	loaded["accessibility"]["high_contrast_ui"] = bool(config.get_value("accessibility", "high_contrast_ui", defaults["accessibility"]["high_contrast_ui"]))
	loaded["accessibility"]["color_cue_mode"] = _normalize_color_cue_mode(String(config.get_value("accessibility", "color_cue_mode", defaults["accessibility"]["color_cue_mode"])))
	loaded["accessibility"]["battle_camera_shake"] = _normalize_battle_camera_shake(String(config.get_value("accessibility", "battle_camera_shake", defaults["accessibility"]["battle_camera_shake"])))
	loaded["accessibility"]["reduce_flashes"] = bool(config.get_value("accessibility", "reduce_flashes", defaults["accessibility"]["reduce_flashes"]))
	loaded["accessibility"]["reduce_motion"] = bool(config.get_value("accessibility", "reduce_motion", defaults["accessibility"]["reduce_motion"]))
	loaded["accessibility"]["reduce_repetitive_sounds"] = bool(config.get_value("accessibility", "reduce_repetitive_sounds", defaults["accessibility"]["reduce_repetitive_sounds"]))
	return loaded

func _canonical_settings(value: Dictionary) -> Dictionary:
	var config := _settings_config_unchecked(value)
	return _settings_from_config(config)

func _settings_config(value: Dictionary) -> ConfigFile:
	return _settings_config_unchecked(_canonical_settings_unchecked(value))

func _canonical_settings_unchecked(value: Dictionary) -> Dictionary:
	var defaults := build_default_settings()
	var canonical := defaults.duplicate(true)
	for section in ["audio", "presentation", "gameplay", "accessibility"]:
		var source: Dictionary = value.get(section, {}) if value.get(section, {}) is Dictionary else {}
		for key in (canonical[section] as Dictionary).keys():
			if source.has(key):
				canonical[section][key] = source[key]
	canonical["version"] = SETTINGS_VERSION
	return _settings_from_config(_settings_config_unchecked(canonical))

func _settings_config_unchecked(value: Dictionary) -> ConfigFile:
	var defaults := build_default_settings()
	var audio: Dictionary = value.get("audio", {}) if value.get("audio", {}) is Dictionary else {}
	var presentation: Dictionary = value.get("presentation", {}) if value.get("presentation", {}) is Dictionary else {}
	var gameplay: Dictionary = value.get("gameplay", {}) if value.get("gameplay", {}) is Dictionary else {}
	var accessibility: Dictionary = value.get("accessibility", {}) if value.get("accessibility", {}) is Dictionary else {}
	var config := ConfigFile.new()
	config.set_value("meta", "version", SETTINGS_VERSION)
	config.set_value("audio", "master_volume_percent", clampi(int(audio.get("master_volume_percent", defaults["audio"]["master_volume_percent"])), 0, 100))
	config.set_value("audio", "music_volume_percent", clampi(int(audio.get("music_volume_percent", defaults["audio"]["music_volume_percent"])), 0, 100))
	config.set_value("audio", "effects_volume_percent", clampi(int(audio.get("effects_volume_percent", defaults["audio"]["effects_volume_percent"])), 0, 100))
	config.set_value("presentation", "mode", _normalize_presentation_mode(String(presentation.get("mode", defaults["presentation"]["mode"]))))
	config.set_value("presentation", "resolution", _normalize_presentation_resolution(String(presentation.get("resolution", defaults["presentation"]["resolution"]))))
	config.set_value("presentation", "render_quality", _normalize_render_quality(String(presentation.get("render_quality", defaults["presentation"]["render_quality"]))))
	config.set_value("presentation", "vsync_enabled", bool(presentation.get("vsync_enabled", defaults["presentation"]["vsync_enabled"])))
	config.set_value("presentation", "frame_rate_limit", _normalize_frame_rate_limit(int(presentation.get("frame_rate_limit", defaults["presentation"]["frame_rate_limit"]))))
	config.set_value("gameplay", "battle_playback_speed", _normalize_battle_playback_speed(String(gameplay.get("battle_playback_speed", defaults["gameplay"]["battle_playback_speed"]))))
	config.set_value("gameplay", "keyboard_navigation_layout", _normalize_keyboard_navigation_layout(String(gameplay.get("keyboard_navigation_layout", defaults["gameplay"]["keyboard_navigation_layout"]))))
	config.set_value("gameplay", "hero_movement_bindings", _normalize_hero_movement_bindings(gameplay.get("hero_movement_bindings", defaults["gameplay"]["hero_movement_bindings"])))
	var scale := _normalize_ui_scale_percent(int(accessibility.get("ui_scale_percent", defaults["accessibility"]["ui_scale_percent"])))
	config.set_value("accessibility", "ui_scale_percent", scale)
	config.set_value("accessibility", "large_ui_text", scale > 100)
	config.set_value("accessibility", "high_contrast_ui", bool(accessibility.get("high_contrast_ui", defaults["accessibility"]["high_contrast_ui"])))
	config.set_value("accessibility", "color_cue_mode", _normalize_color_cue_mode(String(accessibility.get("color_cue_mode", defaults["accessibility"]["color_cue_mode"]))))
	config.set_value("accessibility", "battle_camera_shake", _normalize_battle_camera_shake(String(accessibility.get("battle_camera_shake", defaults["accessibility"]["battle_camera_shake"]))))
	config.set_value("accessibility", "reduce_flashes", bool(accessibility.get("reduce_flashes", defaults["accessibility"]["reduce_flashes"])))
	config.set_value("accessibility", "reduce_motion", bool(accessibility.get("reduce_motion", defaults["accessibility"]["reduce_motion"])))
	config.set_value("accessibility", "reduce_repetitive_sounds", bool(accessibility.get("reduce_repetitive_sounds", defaults["accessibility"]["reduce_repetitive_sounds"])))
	return config

func _rollback_settings_transaction(had_live: bool, prior_bytes: PackedByteArray) -> bool:
	var rolled_back := true
	if _settings_path_exists(SETTINGS_FILE):
		rolled_back = _remove_settings_artifact(SETTINGS_FILE) and rolled_back
	if had_live:
		if FileAccess.file_exists(SETTINGS_BACKUP_FILE):
			rolled_back = _rename_settings_path(SETTINGS_BACKUP_FILE, SETTINGS_FILE) == OK and rolled_back
		else:
			rolled_back = false
	elif not had_live:
		rolled_back = _remove_settings_artifact(SETTINGS_BACKUP_FILE) and rolled_back
	rolled_back = _remove_settings_artifact(SETTINGS_CANDIDATE_FILE) and rolled_back
	if had_live and FileAccess.file_exists(SETTINGS_FILE):
		rolled_back = FileAccess.get_file_as_bytes(SETTINGS_FILE) == prior_bytes and rolled_back
	elif had_live:
		rolled_back = false
	elif _settings_path_exists(SETTINGS_FILE):
		rolled_back = false
	if _settings_path_exists(SETTINGS_CANDIDATE_FILE) or _settings_path_exists(SETTINGS_BACKUP_FILE):
		rolled_back = false
	return rolled_back

func _settings_transaction_failure(reason: String) -> Dictionary:
	return {
		"ok": false,
		"path": "",
		"changed": false,
		"reason": reason,
		"message": "Settings could not be saved. Your previous settings remain active.",
		"settings": (_committed_settings if not _committed_settings.is_empty() else settings).duplicate(true),
	}

func _settings_path_exists(file_path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(file_path)
	return FileAccess.file_exists(file_path) or DirAccess.dir_exists_absolute(absolute)

func _remove_settings_artifact(file_path: String) -> bool:
	if not _settings_path_exists(file_path):
		return true
	if not FileAccess.file_exists(file_path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path)) == OK

func _rename_settings_path(from_path: String, to_path: String) -> int:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path))

func _managed_input_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for action_value in KEYBOARD_NAVIGATION_ACTIONS.keys():
		actions.append(StringName(action_value))
	for action_value in KEYBOARD_HERO_MOVEMENT_ACTIONS.keys():
		var action := StringName(action_value)
		if action not in actions:
			actions.append(action)
	return actions

func _capture_managed_input_map() -> Dictionary:
	var snapshot := {}
	for action in _managed_input_actions():
		var events := []
		if InputMap.has_action(action):
			for input_event in InputMap.action_get_events(action):
				events.append(input_event.duplicate(true))
		snapshot[String(action)] = {
			"exists": InputMap.has_action(action),
			"deadzone": InputMap.action_get_deadzone(action) if InputMap.has_action(action) else 0.5,
			"events": events,
		}
	return snapshot

func _restore_managed_input_map(snapshot: Dictionary) -> void:
	for action in _managed_input_actions():
		var action_id := String(action)
		var state: Dictionary = snapshot.get(action_id, {}) if snapshot.get(action_id, {}) is Dictionary else {}
		if not bool(state.get("exists", false)):
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action, float(state.get("deadzone", 0.5)))
		else:
			InputMap.action_set_deadzone(action, float(state.get("deadzone", 0.5)))
		InputMap.action_erase_events(action)
		var events: Variant = state.get("events", [])
		if events is Array:
			for input_event in events:
				if input_event is InputEvent:
					InputMap.action_add_event(action, input_event.duplicate(true))

func _center_window(resolution: Vector2i) -> void:
	var screen_index := DisplayServer.window_get_current_screen()
	if screen_index < 0:
		return
	var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return
	var offset := Vector2i(
		maxi(0, int((usable_rect.size.x - resolution.x) / 2)),
		maxi(0, int((usable_rect.size.y - resolution.y) / 2))
	)
	DisplayServer.window_set_position(usable_rect.position + offset)

func _ensure_settings_dir() -> bool:
	var absolute_path := ProjectSettings.globalize_path(SETTINGS_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Unable to create settings directory: %s" % absolute_path)
		return false
	return true
