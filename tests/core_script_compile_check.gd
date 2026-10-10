extends Node
## Core suite: every game script under scripts/ and scenes/ loads and compiles.
## Catches parse errors, broken preloads and bad class references before any scene runs.

const REPORT_ID := "CORE_SCRIPT_COMPILE_CHECK"
const ROOTS := ["res://scripts", "res://scenes"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths: Array[String] = []
	for root in ROOTS:
		_collect(root, paths)
	var failures: Array[String] = []
	for path in paths:
		var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if script == null or not (script is Script) or not script.can_instantiate():
			failures.append(path)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": failures.is_empty(), "scripts": paths.size(), "failures": failures})])
	get_tree().quit(0 if failures.is_empty() and paths.size() > 0 else 1)

func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
