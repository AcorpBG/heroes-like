extends SceneTree
## G1 (tools/battle_port_g1/g1.py convert): the whole-battle conversion of each captured resolve, timed in this
## checkout's rules library at the pool size the replay reached (AurelionRules.state_conversion_timing).
##
##     godot --headless --path . -s res://tools/battle_port_g1/g1_conversion.gd -- JOBS.json OUT.jsonl ROUNDS
##
## JOBS.json is [{file, made_arrays, made_dicts}]; OUT.jsonl gets one line per capture.


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var rounds := int(args[2])
	var api = ClassDB.instantiate(&"AurelionRules")
	if not (jobs is Array) or api == null:
		printerr("G1 conversion: no jobs or no AurelionRules")
		quit(1)
		return
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	for job in jobs:
		var capture: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(String(job.file)))
		var start = bytes_to_var(capture.start)
		var end = start if (capture.end as PackedByteArray).is_empty() else bytes_to_var(capture.end)
		var timing: Dictionary = api.state_conversion_timing(start, end, int(job.made_arrays), int(job.made_dicts), rounds)
		if timing.is_empty():
			printerr("G1 conversion failed for %s" % job.file)
			quit(1)
			return
		timing["key"] = capture.key
		timing["t_load_us"] = timing.load_us
		timing["t_store_us"] = timing.store_us
		out.store_line(JSON.stringify(timing))
	out.close()
	quit(0)
