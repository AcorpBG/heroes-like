extends Control

const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")
const PUBLIC_WINDOW_TITLE := "Aurelion Reach"

var _menu_load_started_usec := 0

func _ready() -> void:
	get_window().title = PUBLIC_WINDOW_TITLE
	ProfileLogScript.emit_general("boot", "ready", "boot_ready", 0.0, {}, {
		"handoff": "threaded_main_menu_load",
	}, SessionState.ensure_active_session())
	# The main menu compiles most of the game's scripts. Loading it on worker
	# threads keeps this screen drawing; a blocking load froze the window long
	# enough for Windows to report the game as not responding.
	_menu_load_started_usec = ProfileLogScript.begin_usec()
	AppRouter.request_scene_load(AppRouter.MAIN_MENU_SCENE, true)

func _process(_delta: float) -> void:
	if AppRouter.scene_load_pending(AppRouter.MAIN_MENU_SCENE):
		return
	set_process(false)
	_on_boot_ready()

func _on_boot_ready() -> void:
	var menu_load_ms := ProfileLogScript.elapsed_ms(_menu_load_started_usec)
	var started := ProfileLogScript.begin_usec()
	AppRouter.boot()
	ProfileLogScript.emit_general("boot", "handoff", "boot_router_handoff", ProfileLogScript.elapsed_ms(started), {
		"main_menu_load": menu_load_ms,
	}, {
		"target": "main_menu",
	}, SessionState.ensure_active_session())
