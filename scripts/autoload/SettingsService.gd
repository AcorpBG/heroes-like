class_name HeroesSettingsService
extends Node

signal settings_changed(settings: Dictionary)

const SETTINGS_VERSION := 6
const SETTINGS_DIR := "user://config"
const SETTINGS_FILE := "%s/settings.cfg" % SETTINGS_DIR

const PRESENTATION_WINDOWED := "windowed"
const PRESENTATION_BORDERLESS := "borderless"
const PRESENTATION_FULLSCREEN := "fullscreen"
const PRESENTATION_RESOLUTION_DEFAULT := "1920x1080"
const MUSIC_AUDIO_BUS := "Music"
const EFFECTS_AUDIO_BUS := "Effects"
const RENDER_QUALITY_LOW := "low"
const RENDER_QUALITY_BALANCED := "balanced"
const RENDER_QUALITY_HIGH := "high"

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
]

var settings: Dictionary = {}

func _ready() -> void:
	load_settings()

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
		"accessibility": {
			"ui_scale_percent": 100,
			"large_ui_text": false,
			"reduce_motion": false,
		},
	}

func load_settings() -> void:
	var defaults := build_default_settings()
	settings = defaults.duplicate(true)

	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		var stored_version := int(config.get_value("meta", "version", SETTINGS_VERSION))
		settings["version"] = max(stored_version, SETTINGS_VERSION)
		settings["audio"]["master_volume_percent"] = clampi(int(config.get_value("audio", "master_volume_percent", defaults["audio"]["master_volume_percent"])), 0, 100)
		settings["audio"]["music_volume_percent"] = clampi(int(config.get_value("audio", "music_volume_percent", defaults["audio"]["music_volume_percent"])), 0, 100)
		settings["audio"]["effects_volume_percent"] = clampi(int(config.get_value("audio", "effects_volume_percent", defaults["audio"]["effects_volume_percent"])), 0, 100)
		settings["presentation"]["mode"] = _normalize_presentation_mode(String(config.get_value("presentation", "mode", defaults["presentation"]["mode"])))
		settings["presentation"]["resolution"] = _normalize_presentation_resolution(String(config.get_value("presentation", "resolution", defaults["presentation"]["resolution"])))
		settings["presentation"]["render_quality"] = _normalize_render_quality(String(config.get_value("presentation", "render_quality", defaults["presentation"]["render_quality"])))
		settings["presentation"]["vsync_enabled"] = bool(config.get_value("presentation", "vsync_enabled", defaults["presentation"]["vsync_enabled"]))
		settings["presentation"]["frame_rate_limit"] = _normalize_frame_rate_limit(int(config.get_value("presentation", "frame_rate_limit", defaults["presentation"]["frame_rate_limit"])))
		var legacy_large_text := bool(config.get_value("accessibility", "large_ui_text", defaults["accessibility"]["large_ui_text"]))
		var migrated_scale := 115 if legacy_large_text else 100
		settings["accessibility"]["ui_scale_percent"] = _normalize_ui_scale_percent(int(config.get_value("accessibility", "ui_scale_percent", migrated_scale)))
		settings["accessibility"]["large_ui_text"] = ui_scale_percent() > 100
		settings["accessibility"]["reduce_motion"] = bool(config.get_value("accessibility", "reduce_motion", defaults["accessibility"]["reduce_motion"]))

	apply_settings()
	settings_changed.emit(settings.duplicate(true))

func save_settings() -> String:
	ensure_settings()
	if not _ensure_settings_dir():
		return ""

	var config := ConfigFile.new()
	config.set_value("meta", "version", int(settings.get("version", SETTINGS_VERSION)))
	config.set_value("audio", "master_volume_percent", master_volume_percent())
	config.set_value("audio", "music_volume_percent", music_volume_percent())
	config.set_value("audio", "effects_volume_percent", effects_volume_percent())
	config.set_value("presentation", "mode", presentation_mode_id())
	config.set_value("presentation", "resolution", presentation_resolution_id())
	config.set_value("presentation", "render_quality", render_quality_id())
	config.set_value("presentation", "vsync_enabled", vsync_enabled())
	config.set_value("presentation", "frame_rate_limit", frame_rate_limit())
	config.set_value("accessibility", "ui_scale_percent", ui_scale_percent())
	config.set_value("accessibility", "large_ui_text", large_ui_text_enabled())
	config.set_value("accessibility", "reduce_motion", reduced_motion_enabled())
	var error := config.save(SETTINGS_FILE)
	if error != OK:
		push_error("Unable to save settings file: %s" % SETTINGS_FILE)
		return ""
	return SETTINGS_FILE

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

func reduced_motion_enabled() -> bool:
	return bool(ensure_settings().get("accessibility", {}).get("reduce_motion", false))

func animation_preferences(overrides: Dictionary = {}) -> Dictionary:
	var reduced_motion := reduced_motion_enabled()
	if overrides.has("reduced_motion") or overrides.has("reduce_motion"):
		reduced_motion = bool(overrides.get("reduced_motion", overrides.get("reduce_motion", reduced_motion)))
	var fast_mode := bool(overrides.get("fast_mode", false))
	return {
		"accessibility": {
			"reduce_motion": reduced_motion,
		},
		"animation": {
			"fast_mode": fast_mode,
		},
	}

func set_master_volume_percent(value: int) -> void:
	ensure_settings()
	settings["audio"]["master_volume_percent"] = clampi(value, 0, 100)
	_commit_settings()

func set_music_volume_percent(value: int) -> void:
	ensure_settings()
	settings["audio"]["music_volume_percent"] = clampi(value, 0, 100)
	_commit_settings()

func set_effects_volume_percent(value: int) -> void:
	ensure_settings()
	settings["audio"]["effects_volume_percent"] = clampi(value, 0, 100)
	_commit_settings()

func set_presentation_mode(mode_id: String) -> void:
	ensure_settings()
	settings["presentation"]["mode"] = _normalize_presentation_mode(mode_id)
	_commit_settings()

func set_presentation_resolution(resolution_id: String) -> void:
	ensure_settings()
	settings["presentation"]["resolution"] = _normalize_presentation_resolution(resolution_id)
	_commit_settings()

func set_render_quality_id(quality_id: String) -> void:
	ensure_settings()
	settings["presentation"]["render_quality"] = _normalize_render_quality(quality_id)
	_commit_settings()

func set_vsync_enabled(enabled: bool) -> void:
	ensure_settings()
	settings["presentation"]["vsync_enabled"] = enabled
	_commit_settings()

func set_frame_rate_limit(value: int) -> void:
	ensure_settings()
	settings["presentation"]["frame_rate_limit"] = _normalize_frame_rate_limit(value)
	_commit_settings()

func set_large_ui_text_enabled(enabled: bool) -> void:
	set_ui_scale_percent(115 if enabled else 100)

func set_ui_scale_percent(value: int) -> void:
	ensure_settings()
	settings["accessibility"]["ui_scale_percent"] = _normalize_ui_scale_percent(value)
	settings["accessibility"]["large_ui_text"] = ui_scale_percent() > 100
	_commit_settings()

func set_reduced_motion_enabled(enabled: bool) -> void:
	ensure_settings()
	settings["accessibility"]["reduce_motion"] = enabled
	_commit_settings()

func describe_settings() -> String:
	var accessibility_parts := []
	accessibility_parts.append("UI scale %s" % ui_scale_label())
	accessibility_parts.append("Reduced motion %s" % ("On" if reduced_motion_enabled() else "Off"))
	return "\n".join(
		[
			"Presentation: %s | %s | %s quality | VSync %s | %s" % [presentation_mode_label(presentation_mode_id()), presentation_resolution_label(presentation_resolution_id()), render_quality_label(), "On" if vsync_enabled() else "Off", frame_rate_limit_label()],
			"Audio: Master %d%% | Music %d%% | Effects %d%%" % [master_volume_percent(), music_volume_percent(), effects_volume_percent()],
			"Accessibility: %s" % " | ".join(accessibility_parts),
			describe_settings_persistence_check(),
		]
	)

func describe_settings_persistence_check() -> String:
	return "Settings check: applies immediately; stored in device config; campaign progress and expedition saves stay unchanged."

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

func apply_settings() -> void:
	_apply_accessibility_settings()
	_apply_presentation_settings()
	_apply_audio_settings()

func _commit_settings() -> void:
	apply_settings()
	save_settings()
	settings_changed.emit(settings.duplicate(true))

func _apply_accessibility_settings() -> void:
	var root := get_tree().root
	if root != null:
		root.content_scale_factor = float(ui_scale_percent()) / 100.0

func _apply_presentation_settings() -> void:
	var resolution := presentation_resolution_size()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	match presentation_mode_id():
		PRESENTATION_FULLSCREEN:
			DisplayServer.window_set_size(resolution)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		PRESENTATION_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			_center_window(resolution)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			_center_window(resolution)
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
