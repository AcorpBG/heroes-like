extends Node

const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")

const REPORT_ID := "PACKAGING_PLATFORM_READINESS_REPORT"
const OUTPUT_DIR := "res://.artifacts/packaging_platform_readiness_report"
const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const GDEXTENSION_PATH := "res://src/gdextension/map_persistence.gdextension"
const REQUIRED_EXCLUDES := [".git/*", ".godot/*", ".artifacts/*", "tmp/*", "*.dll.a"]
const REQUIRED_NATIVE_LIBRARIES := {
	"linux.editor.x86_64": "res://bin/libaurelion_map_persistence.linux.template_debug.x86_64.so",
	"linux.debug.x86_64": "res://bin/libaurelion_map_persistence.linux.template_debug.x86_64.so",
	"linux.release.x86_64": "res://bin/libaurelion_map_persistence.linux.template_release.x86_64.so",
	"windows.editor.x86_64": "res://bin/aurelion_map_persistence.windows.template_debug.x86_64.dll",
	"windows.debug.x86_64": "res://bin/aurelion_map_persistence.windows.template_debug.x86_64.dll",
	"windows.release.x86_64": "res://bin/aurelion_map_persistence.windows.template_release.x86_64.dll",
}

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"export_presets": {},
	"native_extension": {},
	"runtime_paths": {},
	"project_boot": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_export_presets()
	_validate_native_extension()
	_validate_runtime_paths()
	_validate_project_boot()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_export_presets() -> void:
	var config := ConfigFile.new()
	var result := config.load(EXPORT_PRESETS_PATH)
	if result != OK:
		_error("Unable to load export presets from %s: %s." % [EXPORT_PRESETS_PATH, result])
		return
	var sections := config.get_sections()
	var presets: Array[Dictionary] = []
	for section in sections:
		if String(section).ends_with(".options"):
			continue
		if not String(section).begins_with("preset."):
			continue
		presets.append(_preset_summary(config, String(section)))
	_report["export_presets"] = {
		"path": EXPORT_PRESETS_PATH,
		"preset_count": presets.size(),
		"presets": presets,
	}
	_expect(presets.size() >= 2, "Expected at least Linux and Windows export presets.")
	_validate_platform_preset(presets, "linux", "build/linux/", ".x86_64")
	_validate_platform_preset(presets, "windows", "build/windows/", ".exe")

func _preset_summary(config: ConfigFile, section: String) -> Dictionary:
	var options_section := "%s.options" % section
	var summary := {
		"section": section,
		"name": String(config.get_value(section, "name", "")),
		"platform": String(config.get_value(section, "platform", "")),
		"runnable": bool(config.get_value(section, "runnable", false)),
		"custom_features": String(config.get_value(section, "custom_features", "")),
		"export_filter": String(config.get_value(section, "export_filter", "")),
		"exclude_filter": String(config.get_value(section, "exclude_filter", "")),
		"export_path": String(config.get_value(section, "export_path", "")),
		"embed_pck": bool(config.get_value(options_section, "binary_format/embed_pck", true)),
	}
	return summary

func _validate_platform_preset(presets: Array[Dictionary], platform_id: String, expected_prefix: String, expected_suffix: String) -> void:
	var matches: Array[Dictionary] = []
	for preset in presets:
		var name := String(preset.get("name", "")).to_lower()
		var platform := String(preset.get("platform", "")).to_lower()
		var features := String(preset.get("custom_features", "")).to_lower()
		if platform_id in name or platform_id in platform or platform_id in features:
			matches.append(preset)
	if matches.is_empty():
		_error("Missing %s export preset." % platform_id)
		return
	var preset := matches[0]
	var export_path := String(preset.get("export_path", ""))
	var features := String(preset.get("custom_features", "")).to_lower()
	var exclude_filter := String(preset.get("exclude_filter", ""))
	_expect(bool(preset.get("runnable", false)), "%s export preset must be runnable." % platform_id)
	_expect(String(preset.get("export_filter", "")) == "all_resources", "%s export preset must export all resources." % platform_id)
	_expect(platform_id in features, "%s export preset must include its platform custom feature." % platform_id)
	_expect("release" in features, "%s export preset must include release custom feature." % platform_id)
	_expect(export_path.begins_with(expected_prefix), "%s export path must begin with %s." % [platform_id, expected_prefix])
	_expect(export_path.ends_with(expected_suffix), "%s export path must end with %s." % [platform_id, expected_suffix])
	_expect(not bool(preset.get("embed_pck", true)), "%s export preset must keep PCK external for package inspection." % platform_id)
	for required in REQUIRED_EXCLUDES:
		_expect(required in exclude_filter, "%s export preset must exclude %s." % [platform_id, required])

func _validate_native_extension() -> void:
	var config := ConfigFile.new()
	var result := config.load(GDEXTENSION_PATH)
	if result != OK:
		_error("Unable to load native extension manifest from %s: %s." % [GDEXTENSION_PATH, result])
		return
	var libraries := {}
	for key in REQUIRED_NATIVE_LIBRARIES.keys():
		var expected_path := String(REQUIRED_NATIVE_LIBRARIES[key])
		var actual_path := String(config.get_value("libraries", key, ""))
		var size := _file_size(actual_path)
		libraries[key] = {
			"path": actual_path,
			"expected_path": expected_path,
			"size": size,
		}
		_expect(actual_path == expected_path, "Native library %s must point at %s, got %s." % [key, expected_path, actual_path])
		_expect(FileAccess.file_exists(actual_path), "Native library file is missing for %s: %s." % [key, actual_path])
		_expect(size > 0, "Native library file is empty for %s: %s." % [key, actual_path])
		if key.begins_with("linux."):
			_expect(actual_path.ends_with(".so"), "Linux native library %s must be a .so." % key)
		if key.begins_with("windows."):
			_expect(actual_path.ends_with(".dll"), "Windows native library %s must be a .dll." % key)
	_report["native_extension"] = {
		"path": GDEXTENSION_PATH,
		"entry_symbol": String(config.get_value("configuration", "entry_symbol", "")),
		"compatibility_minimum": String(config.get_value("configuration", "compatibility_minimum", "")),
		"library_count": libraries.size(),
		"libraries": libraries,
	}
	_expect(String(config.get_value("configuration", "entry_symbol", "")) == "aurelion_map_persistence_init", "Native extension entry symbol changed.")
	_expect(String(config.get_value("configuration", "compatibility_minimum", "")) == "4.6", "Native extension compatibility floor changed.")

func _validate_runtime_paths() -> void:
	var settings_path := String(SettingsService.SETTINGS_FILE)
	var settings_dir := String(SettingsService.SETTINGS_DIR)
	var profile_path := String(ProfileLogScript.GENERAL_PROFILE_LOG_PATH)
	_report["runtime_paths"] = {
		"settings_dir": settings_dir,
		"settings_file": settings_path,
		"profile_log": profile_path,
		"profile_log_absolute": ProjectSettings.globalize_path(profile_path),
	}
	_expect(settings_dir == "user://config", "Settings directory must use user://config for packaged builds.")
	_expect(settings_path == "user://config/settings.cfg", "Settings file must use user://config/settings.cfg.")
	_expect(profile_path == "user://debug/heroes_profile.jsonl", "Profile/debug log must use user://debug/heroes_profile.jsonl.")

func _validate_project_boot() -> void:
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	var app_name := String(ProjectSettings.get_setting("application/config/name", ""))
	var icon := String(ProjectSettings.get_setting("application/config/icon", ""))
	var boot_window_title := ""
	var boot_resource := load(main_scene) as PackedScene
	if boot_resource != null:
		var boot_fixture := boot_resource.instantiate()
		add_child(boot_fixture)
		boot_window_title = get_window().title
		remove_child(boot_fixture)
		boot_fixture.free()
	_report["project_boot"] = {
		"main_scene": main_scene,
		"app_name": app_name,
		"icon": icon,
		"window_title": boot_window_title,
	}
	_expect(app_name == "heroes-like", "Project app name must remain heroes-like.")
	_expect(boot_window_title == "Aurelion Reach", "Live Boot must set the public Aurelion Reach window title.")
	_expect(main_scene == "res://scenes/boot/Boot.tscn", "Project main scene must boot through Boot.tscn.")
	_expect(ResourceLoader.exists(main_scene), "Configured main scene does not exist: %s." % main_scene)
	_expect(icon == "res://icon.svg", "Project icon must point at res://icon.svg.")
	_expect(ResourceLoader.exists(icon), "Configured project icon does not exist: %s." % icon)

func _file_size(path: String) -> int:
	if path == "" or not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := file.get_length()
	file.close()
	return size

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to open %s for writing." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func _summary_payload() -> Dictionary:
	return {
		"ok": bool(_report.get("ok", false)),
		"export_preset_count": int((_report.get("export_presets", {}) as Dictionary).get("preset_count", 0)),
		"native_library_count": int((_report.get("native_extension", {}) as Dictionary).get("library_count", 0)),
		"settings_file": String((_report.get("runtime_paths", {}) as Dictionary).get("settings_file", "")),
		"profile_log": String((_report.get("runtime_paths", {}) as Dictionary).get("profile_log", "")),
		"main_scene": String((_report.get("project_boot", {}) as Dictionary).get("main_scene", "")),
		"window_title": String((_report.get("project_boot", {}) as Dictionary).get("window_title", "")),
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
