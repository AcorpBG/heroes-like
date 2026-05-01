extends Control

const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")

func _ready() -> void:
	ProfileLogScript.emit_general("boot", "ready", "boot_ready", 0.0, {}, {
		"handoff": "deferred_router_boot",
	}, SessionState.ensure_active_session())
	call_deferred("_on_boot_ready")

func _on_boot_ready() -> void:
	var started := ProfileLogScript.begin_usec()
	AppRouter.boot()
	ProfileLogScript.emit_general("boot", "handoff", "boot_router_handoff", ProfileLogScript.elapsed_ms(started), {}, {
		"target": "main_menu",
	}, SessionState.ensure_active_session())
