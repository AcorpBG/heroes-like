extends Node

const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")

const REPORT_ID := "PACKAGED_SETTINGS_PERSISTENCE_REPORT"
const SCHEMA_ID := "packaged_settings_persistence_v1"
const TEST_VALUES := {
	"master_volume_percent": 37,
	"music_volume_percent": 42,
	"effects_volume_percent": 48,
	"presentation_mode": "windowed",
	"presentation_resolution": "1600x900",
	"render_quality": "low",
	"vsync_enabled": false,
	"frame_rate_limit": 120,
	"battle_playback_speed": "fast",
	"keyboard_navigation_layout": "ijkl",
	"hero_move_up_key": KEY_P,
	"ui_scale_percent": 130,
	"large_ui_text": true,
	"high_contrast_ui": true,
	"color_cue_mode": "assisted",
	"battle_camera_shake": "reduced",
	"reduce_flashes": true,
	"reduce_motion": true,
	"reduce_repetitive_sounds": true,
}

var _errors: Array[String] = []
var _report := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report_path := _report_path_from_args()
	var original := _read_original_settings_file()
	_report = {
		"schema_id": SCHEMA_ID,
		"report_id": REPORT_ID,
		"ok": false,
		"settings_file": SettingsService.SETTINGS_FILE,
		"settings_dir": SettingsService.SETTINGS_DIR,
		"settings_file_absolute": ProjectSettings.globalize_path(SettingsService.SETTINGS_FILE),
		"settings_dir_absolute": ProjectSettings.globalize_path(SettingsService.SETTINGS_DIR),
		"res_root_absolute": ProjectSettings.globalize_path("res://"),
		"ran_from_pack_scene": ResourceLoader.exists("res://tests/packaged_settings_persistence_report.tscn"),
		"original_settings_existed": bool(original.get("existed", false)),
		"expected_values": TEST_VALUES.duplicate(true),
		"saved_path": "",
		"direct_config_values": {},
		"reloaded_values": {},
		"restored_original_settings": false,
		"errors": [],
	}

	_run_persistence_check()
	_restore_original_settings_file(original)
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	if report_path != "":
		_write_report_file(report_path, _report)
	print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_persistence_check() -> void:
	_expect(SettingsService.SETTINGS_FILE == "user://config/settings.cfg", "Settings file must stay under user://config/settings.cfg.")
	_expect(SettingsService.SETTINGS_DIR == "user://config", "Settings directory must stay user://config.")
	_expect(bool(_report.get("ran_from_pack_scene", false)), "Packaged settings report scene must be loadable from res://.")

	_write_legacy_large_text_config()
	SettingsService.settings = {}
	SettingsService.load_settings()
	_report["legacy_large_text_migration"] = {
		"source_version": 5,
		"source_large_ui_text": true,
		"migrated_ui_scale_percent": SettingsService.ui_scale_percent(),
		"migrated_color_cue_mode": SettingsService.color_cue_mode_id(),
		"migrated_battle_camera_shake": SettingsService.battle_camera_shake_mode_id(),
		"migrated_reduce_flashes": SettingsService.reduced_flashes_enabled(),
		"migrated_reduce_repetitive_sounds": SettingsService.reduced_repetitive_sounds_enabled(),
		"migrated_battle_playback_speed": SettingsService.battle_playback_speed_id(),
		"migrated_keyboard_navigation_layout": SettingsService.keyboard_navigation_layout_id(),
		"migrated_custom_hero_movement_bindings": SettingsService.custom_hero_movement_bindings(),
		"runtime_content_scale_factor": get_tree().root.content_scale_factor,
	}
	_expect(SettingsService.ui_scale_percent() == 115, "Legacy Large Text must migrate to 115% UI scale.")
	_expect(SettingsService.color_cue_mode_id() == SettingsService.COLOR_CUE_MODE_STANDARD, "Legacy settings must default to standard color cues.")
	_expect(SettingsService.battle_camera_shake_mode_id() == SettingsService.BATTLE_CAMERA_SHAKE_FULL, "Legacy settings must default to Full battle shake.")
	_expect(not SettingsService.reduced_flashes_enabled(), "Legacy settings must default to full flash feedback.")
	_expect(not SettingsService.reduced_repetitive_sounds_enabled(), "Legacy settings must default to normal sound repetition.")
	_expect(SettingsService.battle_playback_speed_id() == SettingsService.BATTLE_PLAYBACK_SPEED_NORMAL, "Legacy settings must default to Normal battle playback.")
	_expect(SettingsService.keyboard_navigation_layout_id() == SettingsService.KEYBOARD_NAVIGATION_LAYOUT_WASD, "Legacy settings must default to WASD + Arrows navigation.")
	_expect(not SettingsService.has_custom_hero_movement_bindings(), "Legacy settings must default to preset hero movement bindings.")
	_expect(is_equal_approx(get_tree().root.content_scale_factor, 1.15), "Legacy Large Text migration must apply 115% to the root window.")

	SettingsService.load_settings()
	SettingsService.set_master_volume_percent(int(TEST_VALUES["master_volume_percent"]))
	SettingsService.set_music_volume_percent(0)
	var muted_music_record := MusicAudio.sync_context("menu", "packaged_settings_zero_music_check")
	_expect(bool(muted_music_record.get("muted", false)), "Zero Music volume must mute live music playback.")
	SettingsService.set_music_volume_percent(int(TEST_VALUES["music_volume_percent"]))
	SettingsService.set_effects_volume_percent(0)
	_expect(SettingsService.effects_audio_muted(), "Zero Effects volume must mute live effects playback.")
	SettingsService.set_effects_volume_percent(int(TEST_VALUES["effects_volume_percent"]))
	SettingsService.set_presentation_mode(String(TEST_VALUES["presentation_mode"]))
	SettingsService.set_presentation_resolution(String(TEST_VALUES["presentation_resolution"]))
	SettingsService.set_render_quality_id("high")
	_expect(get_tree().root.msaa_2d == Viewport.MSAA_4X, "High renderer quality must apply 4x 2D MSAA immediately.")
	SettingsService.set_render_quality_id(String(TEST_VALUES["render_quality"]))
	SettingsService.set_vsync_enabled(bool(TEST_VALUES["vsync_enabled"]))
	SettingsService.set_frame_rate_limit(int(TEST_VALUES["frame_rate_limit"]))
	SettingsService.set_battle_playback_speed_id(String(TEST_VALUES["battle_playback_speed"]))
	SettingsService.set_keyboard_navigation_layout_id(String(TEST_VALUES["keyboard_navigation_layout"]))
	var custom_binding_result := SettingsService.set_hero_movement_key(&"hero_move_up", int(TEST_VALUES["hero_move_up_key"]))
	_expect(bool(custom_binding_result.get("ok", false)), "Custom hero movement key must apply before packaged persistence validation: %s." % custom_binding_result)
	SettingsService.set_ui_scale_percent(int(TEST_VALUES["ui_scale_percent"]))
	SettingsService.set_high_contrast_ui_enabled(bool(TEST_VALUES["high_contrast_ui"]))
	SettingsService.set_color_cue_mode_id(String(TEST_VALUES["color_cue_mode"]))
	SettingsService.set_battle_camera_shake_mode_id(String(TEST_VALUES["battle_camera_shake"]))
	SettingsService.set_reduced_flashes_enabled(bool(TEST_VALUES["reduce_flashes"]))
	SettingsService.set_reduced_motion_enabled(bool(TEST_VALUES["reduce_motion"]))
	SettingsService.set_reduced_repetitive_sounds_enabled(bool(TEST_VALUES["reduce_repetitive_sounds"]))
	var saved_path := SettingsService.save_settings()
	_report["saved_path"] = saved_path
	_expect(saved_path == SettingsService.SETTINGS_FILE, "SettingsService.save_settings must return the user:// settings path.")
	_expect(FileAccess.file_exists(SettingsService.SETTINGS_FILE), "Settings file must exist after save_settings.")

	var direct_values := _read_settings_config_values()
	_report["direct_config_values"] = direct_values
	_expect(int(direct_values.get("version", 0)) == SettingsService.SETTINGS_VERSION, "Direct config settings version mismatch.")
	_expect(int(direct_values.get("master_volume_percent", -1)) == int(TEST_VALUES["master_volume_percent"]), "Direct config master volume mismatch.")
	_expect(int(direct_values.get("music_volume_percent", -1)) == int(TEST_VALUES["music_volume_percent"]), "Direct config music volume mismatch.")
	_expect(int(direct_values.get("effects_volume_percent", -1)) == int(TEST_VALUES["effects_volume_percent"]), "Direct config effects volume mismatch.")
	var music_bus_index := AudioServer.get_bus_index(SettingsService.MUSIC_AUDIO_BUS)
	_expect(music_bus_index >= 0, "SettingsService must create an independent Music audio bus.")
	if music_bus_index >= 0:
		var expected_music_db := linear_to_db(float(TEST_VALUES["music_volume_percent"]) / 100.0)
		var applied_music_db := AudioServer.get_bus_volume_db(music_bus_index)
		_report["music_bus"] = {
			"name": AudioServer.get_bus_name(music_bus_index),
			"send": AudioServer.get_bus_send(music_bus_index),
			"expected_volume_db": expected_music_db,
			"applied_volume_db": applied_music_db,
		}
		_expect(is_equal_approx(applied_music_db, expected_music_db), "Music bus gain does not match the configured Music volume.")
	_expect(SettingsService.music_audio_bus_name() == SettingsService.MUSIC_AUDIO_BUS, "Music playback must target the independent Music audio bus.")
	var effects_bus_index := AudioServer.get_bus_index(SettingsService.EFFECTS_AUDIO_BUS)
	_expect(effects_bus_index >= 0, "SettingsService must create an independent Effects audio bus.")
	if effects_bus_index >= 0:
		var expected_effects_db := linear_to_db(float(TEST_VALUES["effects_volume_percent"]) / 100.0)
		var applied_effects_db := AudioServer.get_bus_volume_db(effects_bus_index)
		_report["effects_bus"] = {
			"name": AudioServer.get_bus_name(effects_bus_index),
			"send": AudioServer.get_bus_send(effects_bus_index),
			"expected_volume_db": expected_effects_db,
			"applied_volume_db": applied_effects_db,
		}
		_expect(is_equal_approx(applied_effects_db, expected_effects_db), "Effects bus gain does not match the configured Effects volume.")
	_expect(SettingsService.effects_audio_bus_name() == SettingsService.EFFECTS_AUDIO_BUS, "Effects playback must target the independent Effects audio bus.")
	_expect(String(direct_values.get("presentation_mode", "")) == String(TEST_VALUES["presentation_mode"]), "Direct config presentation mode mismatch.")
	_expect(String(direct_values.get("presentation_resolution", "")) == String(TEST_VALUES["presentation_resolution"]), "Direct config presentation resolution mismatch.")
	_expect(String(direct_values.get("render_quality", "")) == String(TEST_VALUES["render_quality"]), "Direct config renderer quality mismatch.")
	_report["renderer_quality"] = {
		"quality_id": SettingsService.render_quality_id(),
		"quality_label": SettingsService.render_quality_label(),
		"configured_msaa_2d": SettingsService.render_quality_msaa_2d(),
		"runtime_msaa_2d": get_tree().root.msaa_2d,
		"options": SettingsService.build_render_quality_options(),
	}
	_expect(get_tree().root.msaa_2d == Viewport.MSAA_DISABLED, "Low renderer quality must disable 2D MSAA immediately.")
	_expect(bool(direct_values.get("vsync_enabled", true)) == bool(TEST_VALUES["vsync_enabled"]), "Direct config VSync mismatch.")
	_expect(int(direct_values.get("frame_rate_limit", -1)) == int(TEST_VALUES["frame_rate_limit"]), "Direct config frame-rate limit mismatch.")
	_expect(String(direct_values.get("battle_playback_speed", "")) == String(TEST_VALUES["battle_playback_speed"]), "Direct config battle playback speed mismatch.")
	_expect(String(direct_values.get("keyboard_navigation_layout", "")) == String(TEST_VALUES["keyboard_navigation_layout"]), "Direct config keyboard navigation layout mismatch.")
	var direct_hero_bindings: Dictionary = direct_values.get("hero_movement_bindings", {})
	_expect(int(direct_hero_bindings.get("hero_move_up", 0)) == int(TEST_VALUES["hero_move_up_key"]), "Direct config custom hero movement binding mismatch.")
	_report["keyboard_navigation"] = {
		"layout": SettingsService.keyboard_navigation_layout_id(),
		"options": SettingsService.build_keyboard_navigation_layout_options(),
		"up_has_i": _action_has_key(&"ui_up", KEY_I),
		"up_has_w": _action_has_key(&"ui_up", KEY_W),
		"hero_move_up_has_p": _action_has_key(&"hero_move_up", KEY_P),
		"hero_move_up_has_i": _action_has_key(&"hero_move_up", KEY_I),
		"hero_move_up_right_has_o": _action_has_key(&"hero_move_up_right", KEY_O),
		"hero_move_up_right_has_e": _action_has_key(&"hero_move_up_right", KEY_E),
		"hero_move_up_right_has_numpad9": _action_has_key(&"hero_move_up_right", KEY_KP_9),
		"controller_up_preserved": _action_has_joypad_button(&"ui_up", JOY_BUTTON_DPAD_UP),
	}
	_expect(SettingsService.build_keyboard_navigation_layout_options().size() == 3, "Keyboard navigation must expose all three layout options.")
	_expect(_action_has_key(&"ui_up", KEY_I) and not _action_has_key(&"ui_up", KEY_W), "IJKL layout must apply I and remove managed W from ui_up immediately.")
	_expect(_action_has_key(&"hero_move_up", KEY_P) and not _action_has_key(&"hero_move_up", KEY_I) and not _action_has_key(&"hero_move_up", KEY_W), "Custom hero movement binding must replace the selected IJKL key immediately.")
	_expect(_action_has_key(&"hero_move_up_right", KEY_O) and not _action_has_key(&"hero_move_up_right", KEY_E), "IJKL layout must apply O and remove managed E from diagonal hero movement immediately.")
	_expect(_action_has_key(&"hero_move_up_right", KEY_KP_9), "IJKL layout must preserve numpad diagonal hero movement.")
	_expect(_action_has_joypad_button(&"ui_up", JOY_BUTTON_DPAD_UP), "Keyboard layout changes must preserve controller D-pad navigation.")
	var display_driver := DisplayServer.get_name()
	var runtime_vsync_verifiable := display_driver != "headless"
	_report["display_pacing"] = {
		"display_driver": display_driver,
		"vsync_enabled": SettingsService.vsync_enabled(),
		"runtime_vsync_mode": DisplayServer.window_get_vsync_mode(),
		"runtime_vsync_verifiable": runtime_vsync_verifiable,
		"frame_rate_limit": SettingsService.frame_rate_limit(),
		"battle_playback_speed": SettingsService.battle_playback_speed_id(),
		"keyboard_navigation_layout": SettingsService.keyboard_navigation_layout_id(),
		"hero_move_up_key": SettingsService.hero_movement_keycode(&"hero_move_up"),
		"runtime_max_fps": Engine.max_fps,
	}
	if runtime_vsync_verifiable:
		_expect(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "Runtime VSync mode must apply the disabled setting.")
	_expect(Engine.max_fps == int(TEST_VALUES["frame_rate_limit"]), "Runtime max FPS must match the configured frame-rate limit.")
	_expect(int(direct_values.get("ui_scale_percent", -1)) == int(TEST_VALUES["ui_scale_percent"]), "Direct config UI scale mismatch.")
	_expect(bool(direct_values.get("large_ui_text", false)) == bool(TEST_VALUES["large_ui_text"]), "Direct config large UI text mismatch.")
	_expect(bool(direct_values.get("high_contrast_ui", false)) == bool(TEST_VALUES["high_contrast_ui"]), "Direct config high-contrast UI mismatch.")
	_expect(String(direct_values.get("color_cue_mode", "")) == String(TEST_VALUES["color_cue_mode"]), "Direct config color-cue mode mismatch.")
	_expect(String(direct_values.get("battle_camera_shake", "")) == String(TEST_VALUES["battle_camera_shake"]), "Direct config battle-camera shake mismatch.")
	_expect(bool(direct_values.get("reduce_flashes", false)) == bool(TEST_VALUES["reduce_flashes"]), "Direct config reduce flashes mismatch.")
	_expect(is_equal_approx(SettingsService.battle_camera_shake_scale(), 0.35), "Reduced battle-camera shake must apply a 35 percent scale.")
	_report["accessibility_scaling"] = {
		"ui_scale_percent": SettingsService.ui_scale_percent(),
		"compatibility_large_ui_text": SettingsService.large_ui_text_enabled(),
		"runtime_content_scale_factor": get_tree().root.content_scale_factor,
		"options": SettingsService.build_ui_scale_options(),
	}
	_expect(is_equal_approx(get_tree().root.content_scale_factor, 1.30), "Runtime root window must apply the configured 130% UI scale.")
	var contrast_panel := FrontierVisualKitScript.panel_style("ink")
	var contrast_focus := FrontierVisualKitScript._button_focus_style()
	var contrast_body: Color = FrontierVisualKitScript.text_color("body")
	_report["high_contrast_ui"] = {
		"enabled": FrontierVisualKitScript.high_contrast_enabled(),
		"body_text_color": contrast_body,
		"panel_background_color": contrast_panel.bg_color,
		"panel_border_color": contrast_panel.border_color,
		"focus_border_color": contrast_focus.border_color,
		"focus_border_width": contrast_focus.border_width_left,
	}
	_expect(FrontierVisualKitScript.high_contrast_enabled(), "Shared visual kit must receive the high-contrast setting.")
	_expect(contrast_body.r >= 0.95 and contrast_body.g >= 0.95 and contrast_body.b >= 0.95, "High-contrast body text must be near white.")
	_expect(contrast_panel.bg_color.get_luminance() <= 0.03, "High-contrast panels must use a near-black solid background.")
	_expect(contrast_panel.border_color.get_luminance() >= 0.80, "High-contrast panel borders must remain strongly visible.")
	_expect(contrast_focus.border_width_left >= 4, "High-contrast focus rings must be at least four pixels wide.")
	var assisted_green: Color = FrontierVisualKitScript.text_color("green")
	var assisted_red: Color = FrontierVisualKitScript.text_color("red")
	var assisted_player: Color = FrontierVisualKitScript.semantic_color("player", Color.RED)
	var assisted_enemy: Color = FrontierVisualKitScript.semantic_color("enemy", Color.GREEN)
	_report["color_cue_assist"] = {
		"mode": FrontierVisualKitScript.color_cue_mode(),
		"enabled": FrontierVisualKitScript.color_cue_assist_enabled(),
		"green_semantic_color": assisted_green,
		"red_semantic_color": assisted_red,
		"player_ownership_color": assisted_player,
		"enemy_ownership_color": assisted_enemy,
		"options": SettingsService.build_color_cue_options(),
	}
	_expect(FrontierVisualKitScript.color_cue_assist_enabled(), "Shared visual kit must receive the assisted color-cue setting.")
	_expect(assisted_green.b > assisted_green.r, "Assisted success styling must use a blue/cyan-biased cue instead of green.")
	_expect(assisted_red.r > assisted_red.g and assisted_red.g > assisted_red.b, "Assisted danger styling must use an orange-biased cue instead of red.")
	_expect(assisted_player.b > assisted_player.r and assisted_enemy.r > assisted_enemy.b, "Assisted ownership colors must separate player blue from enemy orange.")
	_expect(bool(direct_values.get("reduce_motion", false)) == bool(TEST_VALUES["reduce_motion"]), "Direct config reduce motion mismatch.")
	_expect(bool(direct_values.get("reduce_repetitive_sounds", false)) == bool(TEST_VALUES["reduce_repetitive_sounds"]), "Direct config reduced repetitive sounds mismatch.")

	SettingsService.settings = {}
	SettingsService.load_settings()
	var reloaded := {
		"master_volume_percent": SettingsService.master_volume_percent(),
		"music_volume_percent": SettingsService.music_volume_percent(),
		"effects_volume_percent": SettingsService.effects_volume_percent(),
		"presentation_mode": SettingsService.presentation_mode_id(),
		"presentation_resolution": SettingsService.presentation_resolution_id(),
		"render_quality": SettingsService.render_quality_id(),
		"vsync_enabled": SettingsService.vsync_enabled(),
		"frame_rate_limit": SettingsService.frame_rate_limit(),
		"battle_playback_speed": SettingsService.battle_playback_speed_id(),
		"keyboard_navigation_layout": SettingsService.keyboard_navigation_layout_id(),
		"hero_move_up_key": SettingsService.hero_movement_keycode(&"hero_move_up"),
		"ui_scale_percent": SettingsService.ui_scale_percent(),
		"large_ui_text": SettingsService.large_ui_text_enabled(),
		"high_contrast_ui": SettingsService.high_contrast_ui_enabled(),
		"color_cue_mode": SettingsService.color_cue_mode_id(),
		"battle_camera_shake": SettingsService.battle_camera_shake_mode_id(),
		"battle_camera_shake_scale": SettingsService.battle_camera_shake_scale(),
		"reduce_flashes": SettingsService.reduced_flashes_enabled(),
		"reduce_motion": SettingsService.reduced_motion_enabled(),
		"reduce_repetitive_sounds": SettingsService.reduced_repetitive_sounds_enabled(),
		"description_has_persistence_check": "Settings check:" in SettingsService.describe_settings(),
	}
	_report["reloaded_values"] = reloaded
	_expect(int(reloaded["master_volume_percent"]) == int(TEST_VALUES["master_volume_percent"]), "Reloaded master volume mismatch.")
	_expect(int(reloaded["music_volume_percent"]) == int(TEST_VALUES["music_volume_percent"]), "Reloaded music volume mismatch.")
	_expect(int(reloaded["effects_volume_percent"]) == int(TEST_VALUES["effects_volume_percent"]), "Reloaded effects volume mismatch.")
	_expect(String(reloaded["presentation_mode"]) == String(TEST_VALUES["presentation_mode"]), "Reloaded presentation mode mismatch.")
	_expect(String(reloaded["presentation_resolution"]) == String(TEST_VALUES["presentation_resolution"]), "Reloaded presentation resolution mismatch.")
	_expect(String(reloaded["render_quality"]) == String(TEST_VALUES["render_quality"]), "Reloaded renderer quality mismatch.")
	_expect(get_tree().root.msaa_2d == Viewport.MSAA_DISABLED, "Reloaded low renderer quality must retain disabled 2D MSAA.")
	_expect(bool(reloaded["vsync_enabled"]) == bool(TEST_VALUES["vsync_enabled"]), "Reloaded VSync mismatch.")
	_expect(int(reloaded["frame_rate_limit"]) == int(TEST_VALUES["frame_rate_limit"]), "Reloaded frame-rate limit mismatch.")
	_expect(String(reloaded["battle_playback_speed"]) == String(TEST_VALUES["battle_playback_speed"]), "Reloaded battle playback speed mismatch.")
	_expect(String(reloaded["keyboard_navigation_layout"]) == String(TEST_VALUES["keyboard_navigation_layout"]), "Reloaded keyboard navigation layout mismatch.")
	_expect(_action_has_key(&"ui_up", KEY_I) and not _action_has_key(&"ui_up", KEY_W), "Reloaded IJKL layout must remain applied to InputMap.")
	_expect(int(reloaded["hero_move_up_key"]) == int(TEST_VALUES["hero_move_up_key"]), "Reloaded custom hero movement key mismatch.")
	_expect(_action_has_key(&"hero_move_up", KEY_P) and not _action_has_key(&"hero_move_up", KEY_I) and not _action_has_key(&"hero_move_up", KEY_W), "Reloaded custom hero movement binding must remain applied.")
	_expect(_action_has_key(&"hero_move_up_right", KEY_O) and not _action_has_key(&"hero_move_up_right", KEY_E) and _action_has_key(&"hero_move_up_right", KEY_KP_9), "Reloaded IJKL diagonal and numpad movement must remain applied.")
	_expect(int(reloaded["ui_scale_percent"]) == int(TEST_VALUES["ui_scale_percent"]), "Reloaded UI scale mismatch.")
	_expect(bool(reloaded["large_ui_text"]) == bool(TEST_VALUES["large_ui_text"]), "Reloaded large UI text mismatch.")
	_expect(bool(reloaded["high_contrast_ui"]) == bool(TEST_VALUES["high_contrast_ui"]), "Reloaded high-contrast UI mismatch.")
	_expect(FrontierVisualKitScript.high_contrast_enabled(), "Reloaded high-contrast UI must remain applied to the shared visual kit.")
	_expect(String(reloaded["color_cue_mode"]) == String(TEST_VALUES["color_cue_mode"]), "Reloaded color-cue mode mismatch.")
	_expect(FrontierVisualKitScript.color_cue_assist_enabled(), "Reloaded color-cue mode must remain applied to the shared visual kit.")
	_expect(String(reloaded["battle_camera_shake"]) == String(TEST_VALUES["battle_camera_shake"]), "Reloaded battle-camera shake mismatch.")
	_expect(is_equal_approx(float(reloaded["battle_camera_shake_scale"]), 0.35), "Reloaded Reduced battle shake must retain its 35 percent scale.")
	_expect(bool(reloaded["reduce_flashes"]) == bool(TEST_VALUES["reduce_flashes"]), "Reloaded reduce flashes mismatch.")
	_expect(is_equal_approx(get_tree().root.content_scale_factor, 1.30), "Reloaded 130% UI scale must remain applied to the root window.")
	_expect(bool(reloaded["reduce_motion"]) == bool(TEST_VALUES["reduce_motion"]), "Reloaded reduce motion mismatch.")
	_expect(bool(reloaded["reduce_repetitive_sounds"]) == bool(TEST_VALUES["reduce_repetitive_sounds"]), "Reloaded reduced repetitive sounds mismatch.")
	_expect(bool(reloaded["description_has_persistence_check"]), "Settings description must include the persistence check copy.")

func _read_settings_config_values() -> Dictionary:
	var config := ConfigFile.new()
	var error := config.load(SettingsService.SETTINGS_FILE)
	if error != OK:
		_error("Unable to reload settings config directly: %s." % error)
		return {}
	return {
		"version": int(config.get_value("meta", "version", 0)),
		"master_volume_percent": int(config.get_value("audio", "master_volume_percent", -1)),
		"music_volume_percent": int(config.get_value("audio", "music_volume_percent", -1)),
		"effects_volume_percent": int(config.get_value("audio", "effects_volume_percent", -1)),
		"presentation_mode": String(config.get_value("presentation", "mode", "")),
		"presentation_resolution": String(config.get_value("presentation", "resolution", "")),
		"render_quality": String(config.get_value("presentation", "render_quality", "")),
		"vsync_enabled": bool(config.get_value("presentation", "vsync_enabled", true)),
		"frame_rate_limit": int(config.get_value("presentation", "frame_rate_limit", -1)),
		"battle_playback_speed": String(config.get_value("gameplay", "battle_playback_speed", "")),
		"keyboard_navigation_layout": String(config.get_value("gameplay", "keyboard_navigation_layout", "")),
		"hero_movement_bindings": config.get_value("gameplay", "hero_movement_bindings", {}),
		"ui_scale_percent": int(config.get_value("accessibility", "ui_scale_percent", -1)),
		"large_ui_text": bool(config.get_value("accessibility", "large_ui_text", false)),
		"high_contrast_ui": bool(config.get_value("accessibility", "high_contrast_ui", false)),
		"color_cue_mode": String(config.get_value("accessibility", "color_cue_mode", "")),
		"battle_camera_shake": String(config.get_value("accessibility", "battle_camera_shake", "")),
		"reduce_flashes": bool(config.get_value("accessibility", "reduce_flashes", false)),
		"reduce_motion": bool(config.get_value("accessibility", "reduce_motion", false)),
		"reduce_repetitive_sounds": bool(config.get_value("accessibility", "reduce_repetitive_sounds", false)),
	}

func _action_has_key(action: StringName, keycode: Key) -> bool:
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			if int(key_event.physical_keycode) == int(keycode) or int(key_event.keycode) == int(keycode):
				return true
	return false

func _action_has_joypad_button(action: StringName, button_index: int) -> bool:
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventJoypadButton and int(input_event.button_index) == button_index:
			return true
	return false

func _write_legacy_large_text_config() -> void:
	var absolute_dir := ProjectSettings.globalize_path(SettingsService.SETTINGS_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_error("Unable to create settings directory for legacy migration check: %s." % dir_error)
		return
	var config := ConfigFile.new()
	config.set_value("meta", "version", 5)
	config.set_value("accessibility", "large_ui_text", true)
	var save_error := config.save(SettingsService.SETTINGS_FILE)
	_expect(save_error == OK, "Legacy Large Text migration fixture could not be saved.")

func _read_original_settings_file() -> Dictionary:
	if not FileAccess.file_exists(SettingsService.SETTINGS_FILE):
		return {"existed": false, "content": ""}
	var file := FileAccess.open(SettingsService.SETTINGS_FILE, FileAccess.READ)
	if file == null:
		return {"existed": false, "content": ""}
	var content := file.get_as_text()
	file.close()
	return {"existed": true, "content": content}

func _restore_original_settings_file(original: Dictionary) -> void:
	var absolute_dir := ProjectSettings.globalize_path(SettingsService.SETTINGS_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_error("Unable to recreate settings directory during restore: %s." % dir_error)
		return
	if bool(original.get("existed", false)):
		var file := FileAccess.open(SettingsService.SETTINGS_FILE, FileAccess.WRITE)
		if file == null:
			_error("Unable to restore original settings file.")
			return
		file.store_string(String(original.get("content", "")))
		file.close()
		_report["restored_original_settings"] = true
	else:
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsService.SETTINGS_FILE))
		if remove_error != OK and remove_error != ERR_FILE_NOT_FOUND:
			_error("Unable to remove temporary settings file during restore: %s." % remove_error)
			return
		_report["restored_original_settings"] = true
	SettingsService.settings = {}
	SettingsService.load_settings()

func _report_path_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-json="):
			return arg.trim_prefix("--report-json=")
	return ""

func _write_report_file(path: String, payload: Dictionary) -> void:
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Unable to write packaged settings report: %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func _summary_payload() -> Dictionary:
	return {
		"ok": bool(_report.get("ok", false)),
		"settings_file": String(_report.get("settings_file", "")),
		"ran_from_pack_scene": bool(_report.get("ran_from_pack_scene", false)),
		"restored_original_settings": bool(_report.get("restored_original_settings", false)),
		"reloaded_values": _report.get("reloaded_values", {}),
		"errors": _errors.duplicate(),
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
