extends RefCounted
## The snapshot file format the rules tools outside Godot read
## (src/gdextension/rules/cli: battle_sim_cli, match_sim_cli), NativeRules
## snapshot_encode: the AI match runner scene writes its prepared matches with
## it. Nothing here is loaded by the game. The content snapshot comes from
## match_sim_cli --write-content (src/gdextension/rules/cli/content_snapshot.hpp).
##
## Static funcs only: a -s script compiles before autoloads exist.


## value as a snapshot file at path (an absolute or res:// path). It is written
## under a name of this process first and takes its name when whole, so a
## reader never sees half a file.
static func write(path: String, value: Variant) -> bool:
	var bytes: PackedByteArray = load("res://scripts/core/NativeRules.gd").api().snapshot_encode(value)
	if bytes.is_empty():
		return false
	var part := "%s.%d.part" % [path, OS.get_process_id()]
	var file := FileAccess.open(part, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	var target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(target)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(part), target) == OK:
		return true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
	return FileAccess.file_exists(path)
