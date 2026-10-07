extends Node

## Regression report for scene transitions (owner report, 2026-10-07: "entering
## battle shows a gray screen and takes a bit of time").
## SceneTree removes the outgoing scene at once and adds the incoming one at the
## next frame's scene flush. A change requested from a timer callback runs after
## that flush, so one frame has no scene. This report drives real AppRouter routes
## from timers and records every frame:
## - overworld -> battle: the battle-approach walk ends on its timer, the router
##   writes the entry checkpoint and changes scene; no frame without a scene may
##   be drawn uncovered; the checkpoint caches its own summary on the trusted
##   (already normalized) path; the battle shell's first refresh does not build
##   the save surface: the save bar shows its real status at once and builds its
##   tooltips when a save control is hovered; the collapsed Tactical Details
##   sidebar is built when it opens, without changing the battle state;
## - battle -> next scene after Quick Resolve, and overworld -> town -> overworld,
##   each requested from a timer, must not show an empty frame either.
## Headless runs force the transition cover on and read the frame state at each
## frame's start (nothing between a draw and the next frame changes scenes).
## Windowed runs also check every drawn frame; --shots=<dir> saves them.

const REPORT_ID := "BATTLE_ENTRY_TRANSITION_REPORT"
const BattleArtPrewarmScript = preload("res://scripts/ui/BattleArtPrewarm.gd")
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleShell.tscn"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"
const BATTLE_REPORT_SCENE := "res://scenes/battle/BattleReportShell.tscn"
const ENCOUNTER_ID := "encounter_ghoul_grove"
const MAX_WAIT_MSEC := 20000
const TIMER_SEC := 0.05
const WATCHDOG_SEC := 300.0

var _failures := []
var _checks := 0
var _evidence := {}
var _frames := []
var _phase := ""
var _battle_added := {}
var _battle_ready := {}
var _shots_dir := ""
var _shot_count := 0
var _reduced_motion_before := false
var _finished := false


func _ready() -> void:
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	_detach_for_scene_transitions()
	get_tree().create_timer(WATCHDOG_SEC).timeout.connect(_on_watchdog)
	call_deferred("_run")


func _on_watchdog() -> void:
	_failures.append("the report did not finish within %d s (phase %s)" % [int(WATCHDOG_SEC), _phase])
	_finish()


## AppRouter replaces the current scene; keep the report alive beside it.
func _detach_for_scene_transitions() -> void:
	var tree := get_tree()
	if tree.current_scene != self:
		return
	get_parent().remove_child(self)
	tree.root.add_child(self)
	var anchor := Node.new()
	anchor.name = "BattleEntryTransitionSceneAnchor"
	tree.root.add_child(anchor)
	tree.current_scene = anchor


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shots="):
			_shots_dir = String(arg).trim_prefix("--shots=")
	_reduced_motion_before = SettingsService.reduced_motion_enabled()
	if _reduced_motion_before:
		SettingsService.set_reduced_motion_enabled(false)
	AppRouter.validation_set_transition_cover_mode("enabled")
	BattleArtPrewarmScript.validation_set_enabled(true)
	get_tree().process_frame.connect(_on_process_frame)
	get_tree().node_added.connect(_on_node_added)
	if _windowed():
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	await _check_battle_entry()
	await _check_battle_exit()
	await _check_town_round_trip()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if get_tree().process_frame.is_connected(_on_process_frame):
		get_tree().process_frame.disconnect(_on_process_frame)
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	AppRouter.validation_set_transition_cover_mode("")
	BattleArtPrewarmScript.validation_set_enabled(false)
	if _reduced_motion_before:
		SettingsService.set_reduced_motion_enabled(true)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "evidence": _evidence}
	if _failures.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	else:
		push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(label)
	return condition


# --- overworld -> battle --------------------------------------------------------

func _check_battle_entry() -> void:
	_phase = "open_overworld"
	var enemy_tile := Vector2i(8, 3)
	var shell = await _open_overworld(_fixture_session(Vector2i(2, 3), [_encounter("transition_ghouls", enemy_tile)]))
	if not _check(shell != null, "the fixture overworld opens through the router"):
		return
	shell.call("validation_set_battle_approach_presentation_enabled", true)
	AppRouter.validation_reset_battle_entry_state()
	var cover_before: Dictionary = AppRouter.validation_transition_cover_snapshot()
	_battle_added = {}
	_battle_ready = {}

	_phase = "battle_entry"
	shell.call("_on_map_tile_pressed", enemy_tile)
	shell.call("_on_map_tile_pressed", enemy_tile)
	_check(bool(shell.call("validation_battle_approach_pending")), "the attack order walks first; the battle waits for its timer")
	_check(not BattleArtPrewarmScript.pending_paths().is_empty(), "the battle's board art starts loading when the walk starts")
	var battle = await _wait_for_scene(BATTLE_SCENE)
	if not _check(battle != null, "the battle opens after the walk"):
		return
	await _wait_presented()

	var rows := _phase_rows("battle_entry")
	_check(_uncovered_empty(rows).is_empty(), "no frame without a scene is shown uncovered between overworld and battle")
	_check(_covered_empty(rows).size() >= 1, "the timer-driven change leaves a frame without a scene, and the cover holds it")
	var entry: Dictionary = AppRouter.validation_battle_entry_snapshot()
	var last_result: Dictionary = entry.get("last_result", {})
	_check(bool(last_result.get("ok", false)) and bool(last_result.get("saved", false)) and bool(last_result.get("routed", false)), "battle entry wrote its checkpoint and routed")
	var cover: Dictionary = AppRouter.validation_transition_cover_snapshot()
	_check(String(cover.get("state", "")) == "idle" and int(cover.get("release_count", 0)) > int(cover_before.get("release_count", 0)), "the cover clears once the battle is on screen")
	_check(String(cover.get("last_released_scene_path", "")) == BATTLE_SCENE, "the cover was released for the battle scene")

	var checkpoint: Dictionary = _battle_added.get("save_profile", {})
	_check(String(checkpoint.get("slot_type", "")) == "autosave" and bool(checkpoint.get("cache_summary", false)), "the entry checkpoint is an autosave that caches its summary")
	_check(bool(checkpoint.get("restore_normalize_skipped", false)), "the entry checkpoint trusts the overworld normalized before the handoff")
	_check(String(_battle_added.get("autosave_summary_resume_target", "")) == "battle", "the cached checkpoint summary resumes into this battle")

	_check(int(_battle_ready.get("save_surface_build_count", -1)) == 0, "the battle shell's first frame does not build the save surface")
	var stale_at_ready: Array = _battle_ready.get("stale_surfaces", [])
	_check(stale_at_ready.has("save_bar_details") and stale_at_ready.has("tactical_details"), "the first frame leaves the save tooltips and the collapsed Tactical Details for when they are shown")
	_check(String(_battle_ready.get("system_body_text", "")) != "" and bool(_battle_ready.get("system_body_visible", false)), "the first frame already shows the save status")
	_check(String(_battle_ready.get("save_button_text", "")) != "" and String(_battle_ready.get("menu_button_text", "")) != "", "the first frame already shows the final save bar buttons")
	_check(String(_battle_ready.get("action_guide_text", "")) != "" and String(_battle_ready.get("action_panel_tooltip", "")) != "", "the first frame builds the action guide")
	var presented: Dictionary = battle.call("validation_lazy_surfaces_snapshot")
	_check(int(presented.get("save_surface_build_count", -1)) == 0, "nothing builds the save surface until a save control is shown")
	var battle_before_hover: Dictionary = (battle.get("_session").battle as Dictionary).duplicate(true)
	battle.get_node("%Save").mouse_entered.emit()
	var hovered: Dictionary = battle.call("validation_lazy_surfaces_snapshot")
	_check(int(hovered.get("save_surface_build_count", 0)) == 1 and not (hovered.get("stale_surfaces", []) as Array).has("save_bar_details"), "hovering Save builds the save surface once")
	_check(String(hovered.get("save_button_tooltip", "")) != String(presented.get("save_button_tooltip", "")) and String(hovered.get("system_body_tooltip", "")) != "", "the hovered save bar has its tooltips")
	_check(hovered.get("system_body_text") == presented.get("system_body_text") and hovered.get("save_button_text") == presented.get("save_button_text") and hovered.get("menu_button_text") == presented.get("menu_button_text"), "the quick save status matches the full save surface")
	battle.call("_on_tactical_details_pressed")
	var opened: Dictionary = battle.call("validation_lazy_surfaces_snapshot")
	_check(bool(opened.get("sidebar_visible", false)) and (opened.get("stale_surfaces", ["x"]) as Array).is_empty(), "opening Tactical Details builds it")
	_check(String(opened.get("active_focus_text", "")) != String(presented.get("active_focus_text", "")), "the opened sidebar shows the current focus")
	_check((battle.get("_session").battle as Dictionary) == battle_before_hover, "building the save tooltips and the sidebar leaves the battle state unchanged")
	battle.call("_on_tactical_details_pressed")
	var surfaces: Dictionary = battle.call("validation_lazy_surfaces_snapshot")
	_check(BattleArtPrewarmScript.pending_paths().is_empty(), "the board art requests are collected after the first frame")
	_evidence["battle_entry"] = {
		"frames": rows.size(),
		"covered_empty_frames": _covered_empty(rows).size(),
		"cover": cover,
		"checkpoint_buckets_ms": checkpoint.get("buckets_ms", {}),
		"ready_surfaces": _battle_ready,
		"final_surfaces": surfaces,
	}


# --- battle -> next scene -----------------------------------------------------------

func _check_battle_exit() -> void:
	var battle := get_tree().current_scene
	if battle == null or String(battle.scene_file_path) != BATTLE_SCENE:
		_check(false, "a battle is open for the exit check")
		return
	_phase = "battle_exit"
	battle.call("validation_request_quick_resolve_confirmation")
	# The in-game exit handoff also routes from a timer callback.
	get_tree().create_timer(TIMER_SEC).timeout.connect(func(): battle.call("validation_confirm_quick_resolve_confirmation"))
	var next_scene = await _wait_for_scene_change(BATTLE_SCENE)
	if not _check(next_scene != null, "quick resolve leaves the battle"):
		return
	var destination := String(next_scene.scene_file_path)
	await _wait_presented()
	if destination == BATTLE_REPORT_SCENE:
		get_tree().create_timer(TIMER_SEC).timeout.connect(func(): AppRouter.complete_battle_report(true))
		var after_report = await _wait_for_scene_change(BATTLE_REPORT_SCENE)
		_check(after_report != null, "the battle report continues")
		await _wait_presented()
	var rows := _phase_rows("battle_exit")
	_check(_uncovered_empty(rows).is_empty(), "no frame without a scene is shown uncovered when the battle closes")
	_check(_covered_empty(rows).size() >= 1, "the battle exit also crosses a covered frame without a scene")
	_evidence["battle_exit"] = {
		"destination": destination,
		"frames": rows.size(),
		"covered_empty_frames": _covered_empty(rows).size(),
	}


# --- overworld -> town -> overworld ---------------------------------------------------

func _check_town_round_trip() -> void:
	_phase = "open_overworld"
	var shell = await _open_overworld(_fixture_session(Vector2i(0, 0), []))
	if not _check(shell != null, "the town fixture overworld opens"):
		return
	_phase = "town_round_trip"
	get_tree().create_timer(TIMER_SEC).timeout.connect(AppRouter.go_to_town)
	var town = await _wait_for_scene(TOWN_SCENE)
	_check(town != null, "the town opens from a timer callback")
	await _wait_presented()
	get_tree().create_timer(TIMER_SEC).timeout.connect(AppRouter.go_to_overworld)
	var overworld = await _wait_for_scene_change(TOWN_SCENE)
	_check(overworld != null and String(overworld.scene_file_path) == OVERWORLD_SCENE, "the town returns to the overworld from a timer callback")
	await _wait_presented()
	var rows := _phase_rows("town_round_trip")
	_check(_uncovered_empty(rows).is_empty(), "no frame without a scene is shown uncovered entering or leaving a town")
	_check(_covered_empty(rows).size() >= 2, "both town transitions cross a covered frame without a scene")
	_evidence["town_round_trip"] = {"frames": rows.size(), "covered_empty_frames": _covered_empty(rows).size()}


# --- frame monitor ----------------------------------------------------------------------

## At a frame's start nothing has changed scenes since the previous draw, so this
## is the state the previous frame was drawn with.
func _on_process_frame() -> void:
	_frames.append({
		"phase": _phase,
		"at": "frame_start",
		"scene": _scene_path(),
		"covering": AppRouter.scene_transition_cover_active(),
	})


func _on_post_draw() -> void:
	var row := {
		"phase": _phase,
		"at": "post_draw",
		"scene": _scene_path(),
		"covering": AppRouter.scene_transition_cover_active(),
	}
	_frames.append(row)
	if _shots_dir != "" and _phase == "battle_entry" and _shot_count < 240:
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			DirAccess.make_dir_recursive_absolute(_shots_dir)
			image.resize(640, 360)
			var cover: Dictionary = AppRouter.validation_transition_cover_snapshot()
			var label := String(row.scene).get_file().get_basename() if String(row.scene) != "" else "no_scene"
			image.save_png(_shots_dir.path_join("battle_entry_%03d_%s_%s_%.2f.png" % [_shot_count, label, String(cover.get("state", "")), float(cover.get("alpha", 0.0))]))
			_shot_count += 1


func _on_node_added(node: Node) -> void:
	if node.get_parent() != get_tree().root or String(node.scene_file_path) != BATTLE_SCENE or _phase != "battle_entry":
		return
	var autosave_summary := {}
	for value in SaveService.validation_summary_cache_snapshot().values():
		if value is Dictionary and String(value.get("summary", {}).get("slot_type", "")) == "autosave":
			autosave_summary = value.get("summary", {})
	_battle_added = {
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"autosave_summary_resume_target": String(autosave_summary.get("resume_target", "")),
	}
	node.ready.connect(func(): _battle_ready = node.call("validation_lazy_surfaces_snapshot"), CONNECT_ONE_SHOT)


func _phase_rows(phase: String) -> Array:
	var rows := []
	for row in _frames:
		if String(row.get("phase", "")) == phase:
			rows.append(row)
	return rows


func _uncovered_empty(rows: Array) -> Array:
	var found := []
	for row in rows:
		if String(row.get("scene", "")) == "" and not bool(row.get("covering", false)):
			found.append(row)
	return found


func _covered_empty(rows: Array) -> Array:
	var found := []
	for row in rows:
		if String(row.get("scene", "")) == "" and bool(row.get("covering", false)) and String(row.get("at", "")) == "frame_start":
			found.append(row)
	return found


# --- helpers ------------------------------------------------------------------------------

func _windowed() -> bool:
	return DisplayServer.get_name() != "headless"


func _scene_path() -> String:
	var scene := get_tree().current_scene
	return String(scene.scene_file_path) if scene != null else ""


func _open_overworld(session) -> Node:
	SessionState.set_active_session(session)
	AppRouter.go_to_overworld()
	var shell = await _wait_for_scene(OVERWORLD_SCENE)
	await _wait_presented()
	return shell


func _wait_for_scene(scene_path: String) -> Node:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < MAX_WAIT_MSEC:
		var scene := get_tree().current_scene
		if scene != null and String(scene.scene_file_path) == scene_path and scene.is_node_ready():
			return scene
		await get_tree().process_frame
	return null


func _wait_for_scene_change(from_path: String) -> Node:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < MAX_WAIT_MSEC:
		var scene := get_tree().current_scene
		if scene != null and String(scene.scene_file_path) != from_path and String(scene.scene_file_path) != "" and scene.is_node_ready():
			return scene
		await get_tree().process_frame
	return null


## Waits until the cover has cleared and the shell's after-first-frame work ran.
func _wait_presented() -> void:
	var started := Time.get_ticks_msec()
	while AppRouter.scene_transition_cover_active() and Time.get_ticks_msec() - started < MAX_WAIT_MSEC:
		await get_tree().process_frame
	for _frame in range(4):
		await get_tree().process_frame


func _encounter(placement_id: String, tile: Vector2i) -> Dictionary:
	return {"placement_id": placement_id, "encounter_id": ENCOUNTER_ID, "x": tile.x, "y": tile.y, "difficulty": "low"}


func _fixture_session(hero_tile: Vector2i, encounters: Array):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var width := 16
	var height := 6
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [{"placement_id": "riverwatch_hold", "town_id": "town_riverwatch", "x": 0, "y": 0, "owner": "player"}]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = encounters.duplicate(true)
	session.overworld["resolved_encounters"] = []
	var active_id := String(session.overworld.get("active_hero_id", ""))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if String(heroes[index].get("id", "")) == active_id:
			var hero: Dictionary = heroes[index]
			hero["position"] = {"x": hero_tile.x, "y": hero_tile.y}
			hero["base_movement"] = 12
			hero["specialties"] = []
			hero["movement"] = {"current": 12, "max": 12}
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	HeroCommandRules._sync_active_hero_mirror(session)
	OverworldRules.normalize_overworld_state(session)
	HeroCommandRules.commit_active_hero(session)
	var explored := []
	for _y in range(height):
		var explored_row := []
		for _x in range(width):
			explored_row.append(true)
		explored.append(explored_row)
	session.overworld["fog"] = {OverworldRules.EXPLORED_TILES_KEY: explored}
	OverworldRules.refresh_fog_of_war(session)
	return session
