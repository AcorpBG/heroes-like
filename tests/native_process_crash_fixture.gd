extends Node

const CRASH_MARKER := "NATIVE_PROCESS_CRASH_FIXTURE_MARKER"

func _ready() -> void:
	call_deferred("_crash_process")

func _crash_process() -> void:
	print(CRASH_MARKER)
	OS.delay_msec(100)
	OS.crash("Intentional packaged native-process recovery smoke crash")
