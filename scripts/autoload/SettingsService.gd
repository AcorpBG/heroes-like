class_name HeroesSettingsService
extends Node

signal settings_changed(settings: Dictionary)

const SETTINGS_VERSION := 2
const SETTINGS_DIR := "user://config"
const SETTINGS_FILE := "%s/settings.cfg" % SETTINGS_DIR

const PRESENTATION_WINDOWED := "windowed"
const PRESENTATION_BORDERLESS := "borderless"
const PRESENTATION_FULLSCREEN := "fullscreen"
const PRESENTATION_RESOLUTION_DEFAULT := "1920x1080"

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
		},
		"presentation": {
			"mode": PRESENTATION_WINDOWED,
			"resolution": PRESENTATION_RESOLUTION_DEFAULT,
		},
		"accessibility": {
			"large_ui_text": false,
			"reduce_motion": false,
		},
	}

func load_settings() -> void:
	var defaults := build_default_settings()
	settings = defaults.duplicate(true)

	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		settings["version"] = max(int(config.get_value("meta", "version", SETTINGS_VERSION)), SETTINGS_VERSION)
		settings["audio"]["master_volume_percent"] = clampi(int(config.get_value("audio", "master_volume_percent", defaults["audio"]["master_volume_percent"])), 0, 100)
		settings["audio"]["music_volume_percent"] = clampi(int(config.get_value("audio", "music_volume_percent", defaults["audio"]["music_volume_percent"])), 0, 100)
		settings["presentation"]["mode"] = _normalize_presentation_mode(String(config.get_value("presentation", "mode", defaults["presentation"]["mode"])))
		settings["presentation"]["resolution"] = _normalize_presentation_resolution(String(config.get_value("presentation", "resolution", defaults["presentation"]["resolution"])))
		settings["accessibility"]["large_ui_text"] = bool(config.get_value("accessibility", "large_ui_text", defaults["accessibility"]["large_ui_text"]))
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
	config.set_value("presentation", "mode", presentation_mode_id())
	config.set_value("presentation", "resolution", presentation_resolution_id())
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

func presentation_mode_id() -> String:
	return String(ensure_settings().get("presentation", {}).get("mode", PRESENTATION_WINDOWED))

func presentation_resolution_id() -> String:
	return _normalize_presentation_resolution(String(ensure_settings().get("presentation", {}).get("resolution", PRESENTATION_RESOLUTION_DEFAULT)))

func presentation_resolution_size() -> Vector2i:
	var option := _presentation_resolution_option(presentation_resolution_id())
	return Vector2i(int(option.get("width", 1920)), int(option.get("height", 1080)))

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

func large_ui_text_enabled() -> bool:
	return bool(ensure_settings().get("accessibility", {}).get("large_ui_text", false))

func reduced_motion_enabled() -> bool:
	return bool(ensure_settings().get("accessibility", {}).get("reduce_motion", false))

func set_master_volume_percent(value: int) -> void:
	ensure_settings()
	settings["audio"]["master_volume_percent"] = clampi(value, 0, 100)
	_commit_settings()

func set_music_volume_percent(value: int) -> void:
	ensure_settings()
	settings["audio"]["music_volume_percent"] = clampi(value, 0, 100)
	_commit_settings()

func set_presentation_mode(mode_id: String) -> void:
	ensure_settings()
	settings["presentation"]["mode"] = _normalize_presentation_mode(mode_id)
	_commit_settings()

func set_presentation_resolution(resolution_id: String) -> void:
	ensure_settings()
	settings["presentation"]["resolution"] = _normalize_presentation_resolution(resolution_id)
	_commit_settings()

func set_large_ui_text_enabled(enabled: bool) -> void:
	ensure_settings()
	settings["accessibility"]["large_ui_text"] = enabled
	_commit_settings()

func set_reduced_motion_enabled(enabled: bool) -> void:
	ensure_settings()
	settings["accessibility"]["reduce_motion"] = enabled
	_commit_settings()

func describe_settings() -> String:
	var accessibility_parts := []
	accessibility_parts.append("Large UI text %s" % ("On" if large_ui_text_enabled() else "Off"))
	accessibility_parts.append("Reduced motion %s" % ("On" if reduced_motion_enabled() else "Off"))
	return "\n".join(
		[
			"Presentation: %s | %s" % [presentation_mode_label(presentation_mode_id()), presentation_resolution_label(presentation_resolution_id())],
			"Audio: Master %d%% | Music %d%%" % [master_volume_percent(), music_volume_percent()],
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
		root.content_scale_factor = 1.15 if large_ui_text_enabled() else 1.0

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

func _apply_audio_settings() -> void:
	_apply_audio_bus("Master", master_volume_percent(), 0)
	_apply_audio_bus("Music", music_volume_percent(), -1)

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
