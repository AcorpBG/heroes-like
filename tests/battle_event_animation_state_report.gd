extends Node

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const OUTPUT_DIR := "res://.artifacts/battle_event_animation_state_report"
const REPORT_ID := "BATTLE_EVENT_ANIMATION_STATE_REPORT"

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"cases": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_fallback_states()
	_validate_defend_state()
	_validate_move_state()
	await _validate_melee_hit_state()
	await _validate_ranged_status_state()
	_validate_death_state()
	await _validate_spell_cast_state()
	await _validate_exit_action_state("retreat", "battle_unit_retreat", "retreat_withdraw_column")
	await _validate_exit_action_state("surrender", "battle_unit_surrender", "surrender_stand_down")
	await _validate_board_runtime_summary()
	await _validate_board_playback_lifecycle()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_fallback_states() -> void:
	var session := _session_for_stacks(
		[
			_stack("unit_river_guard", "player", 0, "player_ready", 8, 0, 3),
			_stack("unit_bog_brute", "enemy", 0, "enemy_idle", 8, 6, 3),
		],
		"player_ready",
		"enemy_idle"
	)
	var ready_state := BattleRulesScript.animation_state_for_stack(session.battle, _stack_by_id(session.battle, "player_ready"))
	var idle_state := BattleRulesScript.animation_state_for_stack(session.battle, _stack_by_id(session.battle, "enemy_idle"))
	_expect_equal("fallback active ready", ready_state, "ready_active")
	_expect_equal("fallback enemy idle", idle_state, "idle_hold")
	_report["cases"]["fallback"] = {"ready_state": ready_state, "idle_state": idle_state}

func _validate_defend_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 5, 3)
	var result := BattleRulesScript.perform_player_action(session, "defend")
	var state := _state_for(session, "player_0")
	_expect_ok("defend action", result)
	_expect_equal("defend animation state", state, "defend_brace")
	_expect_event("defend queue", session.battle, "player_0", "battle_unit_defend", "defend_brace")
	_report["cases"]["defend"] = {"state": state, "events": BattleRulesScript.animation_event_states(session.battle), "queue": BattleRulesScript.animation_event_queue(session.battle)}

func _validate_move_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 0, 3, 7, 3)
	var destinations: Array = BattleRulesScript.legal_destinations_for_active_stack(session.battle)
	if destinations.is_empty():
		_error("Move case has no legal destinations.")
		return
	var destination: Dictionary = destinations[0]
	var result := BattleRulesScript.move_active_stack_to_hex(session, int(destination.get("q", 0)), int(destination.get("r", 0)))
	var state := _state_for(session, "player_0")
	_expect_ok("move action", result)
	_expect_equal("move animation state", state, "move_path_step")
	_expect_event("move queue", session.battle, "player_0", "battle_unit_move", "move_path_step")
	var move_event := _event_record_for(session.battle, "player_0", "battle_unit_move")
	_expect_equal("move event from q", str(int(move_event.get("from_q", -1))), "0")
	_expect_equal("move event from r", str(int(move_event.get("from_r", -1))), "3")
	_expect_equal("move event to q", str(int(move_event.get("to_q", -1))), str(int(destination.get("q", -1))))
	_expect_equal("move event to r", str(int(move_event.get("to_r", -1))), str(int(destination.get("r", -1))))
	var board_summary := _board_summary_for_session(session)
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var path := _vfx_entry_for(vfx_playback, "path_ghost")
	_expect_equal("move path ghost cue", String(path.get("cue_id", "")), "vfx_placeholder_battle_path_ghost")
	if int(path.get("start_q", -1)) == int(path.get("target_q", -1)) and int(path.get("start_r", -1)) == int(path.get("target_r", -1)):
		_error("Move path ghost did not span distinct source and destination cells: %s" % path)
	var moving_stack := _summary_stack_entry(board_summary, "player_0")
	_expect_equal("move token presentation motion active", str(bool(moving_stack.get("presentation_motion_active", false))), "true")
	_expect_equal("move token presentation event", String(moving_stack.get("presentation_motion_event_id", "")), "battle_unit_move")
	_expect_equal("move token presentation from q", str(int(moving_stack.get("presentation_motion_from_q", -1))), "0")
	_expect_equal("move token presentation from r", str(int(moving_stack.get("presentation_motion_from_r", -1))), "3")
	_expect_equal("move token presentation to q", str(int(moving_stack.get("presentation_motion_to_q", -1))), str(int(destination.get("q", -1))))
	_expect_equal("move token presentation to r", str(int(moving_stack.get("presentation_motion_to_r", -1))), str(int(destination.get("r", -1))))
	if float(moving_stack.get("presentation_motion_progress", 1.0)) >= 1.0:
		_error("Move token presentation progress was already complete during active playback: %s." % moving_stack)
	var presentation_x := float(moving_stack.get("presentation_x", 0.0))
	var start_x := float(path.get("start_x", 0.0))
	var end_x := float(path.get("end_x", 0.0))
	if presentation_x < minf(start_x, end_x) - 0.5 or presentation_x > maxf(start_x, end_x) + 0.5:
		_error("Move token presentation center left the event path: stack=%s path=%s." % [moving_stack, path])
	if absf(presentation_x - end_x) <= 1.0:
		_error("Move token presentation snapped directly to destination instead of animating along the event path: stack=%s path=%s." % [moving_stack, path])
	_report["cases"]["move"] = {
		"state": state,
		"destination": destination,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_vfx": vfx_playback,
		"board_stack": moving_stack,
	}

func _validate_melee_hit_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 5, 3)
	_set_stack_field(session.battle, "enemy_0", "retaliations_left", 0)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "strike")
	var attacker_state := _state_for(session, "player_0")
	var target_state := _state_for(session, "enemy_0")
	_expect_ok("melee strike action", result)
	_expect_equal("melee attacker animation state", attacker_state, "melee_windup_release")
	_expect_equal("melee target animation state", target_state, "hit_stagger")
	_expect_event("melee attacker queue", session.battle, "player_0", "battle_unit_melee_attack", "melee_windup_release")
	_expect_event("melee target queue", session.battle, "enemy_0", "battle_unit_hit", "hit_stagger")
	await get_tree().create_timer(0.08).timeout
	var board_summary := _board_summary_for_session(session)
	var attacker_stack := _summary_stack_entry(board_summary, "player_0")
	var target_stack := _summary_stack_entry(board_summary, "enemy_0")
	_expect_equal("melee attacker presentation active", str(bool(attacker_stack.get("presentation_motion_active", false))), "true")
	_expect_equal("melee attacker presentation role", String(attacker_stack.get("presentation_motion_role", "")), "melee_lunge")
	_expect_equal("melee attacker presentation target", String(attacker_stack.get("presentation_motion_target_battle_id", "")), "enemy_0")
	_expect_equal("hit target presentation active", str(bool(target_stack.get("presentation_motion_active", false))), "true")
	_expect_equal("hit target presentation role", String(target_stack.get("presentation_motion_role", "")), "hit_stagger")
	_expect_equal("hit target presentation source", String(target_stack.get("presentation_motion_source_battle_id", "")), "player_0")
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var melee_arc := _vfx_entry_for(vfx_playback, "melee_arc")
	if float(attacker_stack.get("presentation_x", 0.0)) <= float(melee_arc.get("start_x", 0.0)) + 0.05:
		_error("Melee attacker token did not lunge toward the target: attacker=%s melee_arc=%s." % [attacker_stack, melee_arc])
	if float(target_stack.get("presentation_x", 0.0)) <= float(melee_arc.get("end_x", 0.0)) + 0.5:
		_error("Melee target token did not stagger away from the source: target=%s melee_arc=%s." % [target_stack, melee_arc])
	_report["cases"]["melee_hit"] = {
		"attacker_state": attacker_state,
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_vfx": vfx_playback,
		"attacker_stack": attacker_stack,
		"target_stack": target_stack,
	}

func _validate_ranged_status_state() -> void:
	var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "shoot")
	var attacker_state := _state_for(session, "player_0")
	var target_state := _state_for(session, "enemy_0")
	_expect_ok("ranged shoot action", result)
	_expect_equal("ranged attacker animation state", attacker_state, "ranged_aim_release")
	_expect_equal("ranged target status animation state", target_state, "status_applied")
	_expect_event("ranged attacker queue", session.battle, "player_0", "battle_unit_ranged_attack", "ranged_aim_release")
	_expect_event("ranged target status queue", session.battle, "enemy_0", "battle_status_applied", "status_applied")
	await get_tree().create_timer(0.08).timeout
	var board_summary := _board_summary_for_session(session)
	var attacker_stack := _summary_stack_entry(board_summary, "player_0")
	var target_stack := _summary_stack_entry(board_summary, "enemy_0")
	var motion_count := int(board_summary.get("presentation_motion_count", 0))
	var motion_roles: Dictionary = board_summary.get("presentation_motion_roles", {}) if board_summary.get("presentation_motion_roles", {}) is Dictionary else {}
	_expect_equal("ranged attacker presentation role", String(attacker_stack.get("presentation_motion_role", "")), "ranged_recoil")
	_expect_equal("ranged attacker presentation target", String(attacker_stack.get("presentation_motion_target_battle_id", "")), "enemy_0")
	_expect_equal("ranged target presentation role", String(target_stack.get("presentation_motion_role", "")), "status_pulse")
	_expect_equal("ranged target presentation source", String(target_stack.get("presentation_motion_source_battle_id", "")), "player_0")
	if motion_count < 2:
		_error("Ranged/status presentation motion count was too low: %s." % board_summary)
	if int(motion_roles.get("ranged_recoil", 0)) < 1 or int(motion_roles.get("status_pulse", 0)) < 1:
		_error("Ranged/status presentation roles were not counted in board summary: %s." % board_summary)
	var case_payload := {
		"attacker_state": attacker_state,
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
	}
	case_payload["attacker_presentation_role"] = String(attacker_stack.get("presentation_motion_role", ""))
	case_payload["attacker_presentation_target"] = String(attacker_stack.get("presentation_motion_target_battle_id", ""))
	case_payload["target_presentation_role"] = String(target_stack.get("presentation_motion_role", ""))
	case_payload["target_presentation_source"] = String(target_stack.get("presentation_motion_source_battle_id", ""))
	case_payload["presentation_motion_count"] = motion_count
	case_payload["presentation_motion_roles"] = motion_roles
	_report["cases"]["ranged_status"] = case_payload

func _validate_death_state() -> void:
	var session := _session_for_stacks(
		[
			_stack("unit_river_guard", "player", 0, "player_0", 8, 4, 3),
			_stack("unit_bog_brute", "enemy", 0, "enemy_0", 1, 5, 3),
			_stack("unit_bog_brute", "enemy", 1, "enemy_1", 8, 7, 3),
		],
		"player_0",
		"enemy_0"
	)
	_set_stack_field(session.battle, "enemy_0", "retaliations_left", 0)
	_set_stack_field(session.battle, "enemy_0", "total_health", 1)
	var result := BattleRulesScript.perform_player_action(session, "strike")
	var target_state := _state_for(session, "enemy_0")
	_expect_ok("death strike action", result)
	_expect_equal("death target animation state", target_state, "death_rout_remove")
	_expect_event("death target queue", session.battle, "enemy_0", "battle_unit_death", "death_rout_remove")
	var board_summary := _board_summary_for_session(session)
	var observed_states := _observed_animation_states(board_summary)
	var death_stack := _summary_stack_entry(board_summary, "enemy_0")
	var vfx_playback: Dictionary = board_summary.get("vfx_playback", {}) if board_summary.get("vfx_playback", {}) is Dictionary else {}
	var fade := _vfx_entry_for(vfx_playback, "stack_fade")
	_expect_equal("death board target animation state", String(observed_states.get("enemy_0", "")), "death_rout_remove")
	if int(death_stack.get("alive_count", -1)) != 0:
		_error("Death board summary should retain the defeated stack with alive_count 0: %s" % death_stack)
	if not bool(death_stack.get("event_playback_visible", false)):
		_error("Death board summary did not mark the defeated stack as event-playback visible: %s" % death_stack)
	_expect_equal("death target presentation role", String(death_stack.get("presentation_motion_role", "")), "death_fall_back")
	_expect_equal("death target presentation source", String(death_stack.get("presentation_motion_source_battle_id", "")), "player_0")
	_expect_equal("death fade vfx cue", String(fade.get("cue_id", "")), "vfx_placeholder_stack_fade")
	_expect_equal("death fade vfx battle id", String(fade.get("battle_id", "")), "enemy_0")
	_report["cases"]["death"] = {
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
		"board_states": observed_states,
		"board_stack": death_stack,
		"board_vfx": vfx_playback,
	}

func _validate_spell_cast_state() -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	session.battle["player_commander_state"] = _spellcaster_state()
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.cast_player_spell(session, "spell_cinder_burst")
	var caster_state := _state_for(session, "player_0")
	var target_state := _state_for(session, "enemy_0")
	_expect_ok("spell cast action", result)
	_expect_equal("spell caster animation state", caster_state, "cast_support_anchor")
	_expect_equal("spell target animation state", target_state, "status_applied")
	_expect_event("spell caster queue", session.battle, "player_0", "battle_unit_cast", "cast_support_anchor")
	_expect_event("spell target queue", session.battle, "enemy_0", "battle_status_applied", "status_applied")
	await get_tree().create_timer(0.08).timeout
	var board_summary := _board_summary_for_session(session)
	var caster_stack := _summary_stack_entry(board_summary, "player_0")
	var target_stack := _summary_stack_entry(board_summary, "enemy_0")
	var motion_count := int(board_summary.get("presentation_motion_count", 0))
	var motion_roles: Dictionary = board_summary.get("presentation_motion_roles", {}) if board_summary.get("presentation_motion_roles", {}) is Dictionary else {}
	_expect_equal("spell caster presentation role", String(caster_stack.get("presentation_motion_role", "")), "cast_anchor")
	_expect_equal("spell caster presentation target", String(caster_stack.get("presentation_motion_target_battle_id", "")), "enemy_0")
	_expect_equal("spell target presentation role", String(target_stack.get("presentation_motion_role", "")), "status_pulse")
	_expect_equal("spell target presentation source", String(target_stack.get("presentation_motion_source_battle_id", "")), "player_0")
	if motion_count < 2:
		_error("Spell/status presentation motion count was too low: %s." % board_summary)
	if int(motion_roles.get("cast_anchor", 0)) < 1 or int(motion_roles.get("status_pulse", 0)) < 1:
		_error("Spell/status presentation roles were not counted in board summary: %s." % board_summary)
	var case_payload := {
		"caster_state": caster_state,
		"target_state": target_state,
		"events": BattleRulesScript.animation_event_states(session.battle),
		"queue": BattleRulesScript.animation_event_queue(session.battle),
	}
	case_payload["caster_presentation_role"] = String(caster_stack.get("presentation_motion_role", ""))
	case_payload["caster_presentation_target"] = String(caster_stack.get("presentation_motion_target_battle_id", ""))
	case_payload["target_presentation_role"] = String(target_stack.get("presentation_motion_role", ""))
	case_payload["target_presentation_source"] = String(target_stack.get("presentation_motion_source_battle_id", ""))
	case_payload["presentation_motion_count"] = motion_count
	case_payload["presentation_motion_roles"] = motion_roles
	_report["cases"]["spell_cast"] = case_payload

func _validate_exit_action_state(action_id: String, event_id: String, expected_state: String) -> void:
	var session := _basic_session("unit_river_guard", "unit_bog_brute", 4, 3, 6, 3)
	var result := BattleRulesScript.perform_player_action(session, action_id)
	_expect_ok("%s exit action" % action_id, result)
	_expect_equal("%s exit result state" % action_id, String(result.get("state", "")), action_id)
	var snapshot: Dictionary = result.get("battle_exit_animation_snapshot", {}) if result.get("battle_exit_animation_snapshot", {}) is Dictionary else {}
	if snapshot.is_empty():
		_error("%s did not preserve a battle_exit_animation_snapshot before clearing battle." % action_id)
		return
	_expect_equal("%s exit presentation mode" % action_id, String(snapshot.get("presentation_mode", "")), "battle_exit_animation")
	_expect_equal("%s exit presentation outcome" % action_id, String(snapshot.get("presentation_outcome", "")), action_id)
	var player_state := BattleRulesScript.animation_state_for_stack(snapshot, _stack_by_id(snapshot, "player_0"))
	_expect_equal("%s player exit animation state" % action_id, player_state, expected_state)
	_expect_event("%s player exit queue" % action_id, snapshot, "player_0", event_id, expected_state)

	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_presentation_snapshot(snapshot)
	await get_tree().process_frame
	var summary: Dictionary = view.validation_unit_art_summary()
	view.queue_free()
	await get_tree().process_frame
	var observed_states := _observed_animation_states(summary)
	_expect_equal("%s board exit animation state" % action_id, String(observed_states.get("player_0", "")), expected_state)
	var playback: Dictionary = summary.get("animation_playback", {}) if summary.get("animation_playback", {}) is Dictionary else {}
	if int(playback.get("active_playback_count", 0)) < 1:
		_error("%s board exit playback did not keep the exit animation active: %s" % [action_id, playback])
	_report["cases"][action_id] = {
		"result_state": String(result.get("state", "")),
		"snapshot_policy": String(snapshot.get("presentation_policy", "")),
		"player_state": player_state,
		"events": BattleRulesScript.animation_event_states(snapshot),
		"queue": BattleRulesScript.animation_event_queue(snapshot),
		"board_states": observed_states,
		"board_playback": playback,
	}

func _validate_board_runtime_summary() -> void:
	var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "shoot")
	_expect_ok("board summary source action", result)
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().create_timer(0.16).timeout
	var summary: Dictionary = view.validation_unit_art_summary()
	view.queue_free()
	await get_tree().process_frame
	var observed_states := {}
	for entry in summary.get("stacks", []):
		if entry is Dictionary:
			observed_states[String(entry.get("battle_id", ""))] = String(entry.get("animation_state", ""))
	_expect_equal("board runtime ranged attacker state", String(observed_states.get("player_0", "")), "ranged_aim_release")
	_expect_equal("board runtime status target state", String(observed_states.get("enemy_0", "")), "status_applied")
	var cue_playback := _validate_active_cue_dispatch(summary)
	var vfx_playback := _validate_active_vfx_presentation(summary)
	var audio_playback := _validate_active_audio_playback(summary)
	var camera_playback := _validate_active_camera_presentation(summary)
	_report["cases"]["board_runtime"] = {"observed_states": observed_states, "summary": summary}
	_report["cases"]["board_cue_dispatch"] = {
		"active_cue_playback": cue_playback,
	}
	_report["cases"]["board_vfx_presentation"] = {
		"active_vfx_playback": vfx_playback,
	}
	_report["cases"]["board_audio_playback"] = {
		"active_audio_playback": audio_playback,
	}
	_report["cases"]["board_camera_presentation"] = {
		"active_camera_playback": camera_playback,
	}

func _validate_board_playback_lifecycle() -> void:
	var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "shoot")
	_expect_ok("board lifecycle source action", result)
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().create_timer(0.16).timeout
	var active_summary: Dictionary = view.validation_unit_art_summary()
	var active_states := _observed_animation_states(active_summary)
	var active_playback: Dictionary = active_summary.get("animation_playback", {}) if active_summary.get("animation_playback", {}) is Dictionary else {}
	var active_cue: Dictionary = active_summary.get("cue_playback", {}) if active_summary.get("cue_playback", {}) is Dictionary else {}
	var active_vfx: Dictionary = active_summary.get("vfx_playback", {}) if active_summary.get("vfx_playback", {}) is Dictionary else {}
	var active_audio: Dictionary = active_summary.get("audio_playback", {}) if active_summary.get("audio_playback", {}) is Dictionary else {}
	var active_camera: Dictionary = active_summary.get("camera_playback", {}) if active_summary.get("camera_playback", {}) is Dictionary else {}
	_expect_equal("lifecycle active ranged state", String(active_states.get("player_0", "")), "ranged_aim_release")
	_expect_equal("lifecycle active status state", String(active_states.get("enemy_0", "")), "status_applied")
	if int(active_playback.get("active_playback_count", 0)) < 2:
		_error("Playback lifecycle did not keep both source and target events active: %s" % active_playback)
	if int(active_cue.get("active_cue_record_count", 0)) < 2:
		_error("Cue lifecycle did not keep both source and target cue records active: %s" % active_cue)
	if int(active_vfx.get("active_vfx_draw_count", 0)) < 2:
		_error("VFX lifecycle did not keep source and target draw entries active: %s" % active_vfx)
	if int(active_audio.get("active_audio_record_count", 0)) < 2:
		_error("Audio lifecycle did not keep source and target audio records active: %s" % active_audio)
	if int(active_camera.get("active_camera_record_count", 0)) < 2:
		_error("Camera lifecycle did not keep source and target presentation records active: %s" % active_camera)
	await get_tree().create_timer(0.90).timeout
	var expired_summary: Dictionary = view.validation_unit_art_summary()
	var expired_states := _observed_animation_states(expired_summary)
	var expired_playback: Dictionary = expired_summary.get("animation_playback", {}) if expired_summary.get("animation_playback", {}) is Dictionary else {}
	var expired_cue: Dictionary = expired_summary.get("cue_playback", {}) if expired_summary.get("cue_playback", {}) is Dictionary else {}
	var expired_vfx: Dictionary = expired_summary.get("vfx_playback", {}) if expired_summary.get("vfx_playback", {}) is Dictionary else {}
	var expired_audio: Dictionary = expired_summary.get("audio_playback", {}) if expired_summary.get("audio_playback", {}) is Dictionary else {}
	var expired_camera: Dictionary = expired_summary.get("camera_playback", {}) if expired_summary.get("camera_playback", {}) is Dictionary else {}
	_expect_equal("lifecycle expired source fallback", String(expired_states.get("player_0", "")), "ready_active")
	_expect_equal("lifecycle expired target fallback", String(expired_states.get("enemy_0", "")), "idle_hold")
	if int(expired_playback.get("active_playback_count", -1)) != 0:
		_error("Playback lifecycle did not expire event states: %s" % expired_playback)
	if int(expired_cue.get("active_cue_record_count", -1)) != 0:
		_error("Cue lifecycle did not expire cue records: %s" % expired_cue)
	if int(expired_vfx.get("active_vfx_draw_count", -1)) != 0:
		_error("VFX lifecycle did not expire draw entries: %s" % expired_vfx)
	if int(expired_audio.get("active_audio_record_count", -1)) != 0:
		_error("Audio lifecycle did not expire audio records: %s" % expired_audio)
	if int(expired_camera.get("active_camera_record_count", -1)) != 0:
		_error("Camera lifecycle did not expire presentation records: %s" % expired_camera)
	view.queue_free()
	await get_tree().process_frame
	_report["cases"]["board_playback_lifecycle"] = {
		"active_states": active_states,
		"expired_states": expired_states,
		"active_playback": active_playback,
		"expired_playback": expired_playback,
		"active_cue_playback": active_cue,
		"expired_cue_playback": expired_cue,
		"active_vfx_playback": active_vfx,
		"expired_vfx_playback": expired_vfx,
		"active_audio_playback": active_audio,
		"expired_audio_playback": expired_audio,
		"active_camera_playback": active_camera,
		"expired_camera_playback": expired_camera,
	}

func _validate_active_cue_dispatch(summary: Dictionary) -> Dictionary:
	var cue_playback: Dictionary = summary.get("cue_playback", {}) if summary.get("cue_playback", {}) is Dictionary else {}
	if int(cue_playback.get("active_cue_record_count", 0)) < 2:
		_error("Cue dispatch did not keep both source and target cue records active: %s" % cue_playback)
	if int(cue_playback.get("vfx_record_count", 0)) < 2 or int(cue_playback.get("audio_record_count", 0)) < 2:
		_error("Cue dispatch did not resolve VFX/audio ids for both records: %s" % cue_playback)
	var player_cue := _cue_record_for(cue_playback, "player_0")
	var enemy_cue := _cue_record_for(cue_playback, "enemy_0")
	_expect_equal("player cue event id", String(player_cue.get("event_id", "")), "battle_unit_ranged_attack")
	_expect_equal("enemy cue event id", String(enemy_cue.get("event_id", "")), "battle_status_applied")
	_expect_equal("player cue target", String(player_cue.get("target_battle_id", "")), "enemy_0")
	_expect_equal("enemy cue source", String(enemy_cue.get("source_battle_id", "")), "player_0")
	var player_start := int(player_cue.get("started_at_msec", 0))
	var enemy_start := int(enemy_cue.get("started_at_msec", 0))
	if player_start <= 0 or enemy_start <= player_start:
		_error("Cue dispatch did not sequence target reaction after source action: player=%s enemy=%s." % [player_cue, enemy_cue])
	if int(enemy_cue.get("sequence_delay_msec", 0)) <= 0:
		_error("Target reaction cue did not carry a positive sequence delay: %s." % enemy_cue)
	_expect_array_contains("player cue vfx", player_cue.get("selected_vfx_cue_ids", []), "vfx_placeholder_projectile_path")
	_expect_array_contains("player cue audio", player_cue.get("selected_audio_cue_ids", []), "audio_placeholder_ranged_release")
	_expect_array_contains("enemy cue vfx", enemy_cue.get("selected_vfx_cue_ids", []), "vfx_placeholder_status_residue")
	_expect_array_contains("enemy cue audio", enemy_cue.get("selected_audio_cue_ids", []), "audio_placeholder_status_apply")
	return cue_playback

func _validate_active_vfx_presentation(summary: Dictionary) -> Dictionary:
	var vfx_playback: Dictionary = summary.get("vfx_playback", {}) if summary.get("vfx_playback", {}) is Dictionary else {}
	if int(vfx_playback.get("active_vfx_draw_count", 0)) < 2:
		_error("VFX presentation did not materialize both source and target draw entries: %s" % vfx_playback)
	if int(vfx_playback.get("projectile_draw_count", 0)) < 1 or int(vfx_playback.get("status_draw_count", 0)) < 1:
		_error("VFX presentation did not include projectile and status draw entries: %s" % vfx_playback)
	var projectile := _vfx_entry_for(vfx_playback, "projectile_path")
	var status := _vfx_entry_for(vfx_playback, "status_residue")
	_expect_equal("projectile vfx cue", String(projectile.get("cue_id", "")), "vfx_placeholder_projectile_path")
	_expect_equal("projectile vfx source", String(projectile.get("battle_id", "")), "player_0")
	_expect_equal("projectile vfx target", String(projectile.get("target_battle_id", "")), "enemy_0")
	_expect_equal("status vfx cue", String(status.get("cue_id", "")), "vfx_placeholder_status_residue")
	_expect_equal("status vfx target battle id", String(status.get("battle_id", "")), "enemy_0")
	_expect_equal("status vfx source", String(status.get("source_battle_id", "")), "player_0")
	if int(projectile.get("start_q", -1)) == int(projectile.get("target_q", -1)) and int(projectile.get("start_r", -1)) == int(projectile.get("target_r", -1)):
		_error("Projectile VFX did not span distinct source and target cells: %s" % projectile)
	return vfx_playback

func _validate_active_audio_playback(summary: Dictionary) -> Dictionary:
	var audio_playback: Dictionary = summary.get("audio_playback", {}) if summary.get("audio_playback", {}) is Dictionary else {}
	if int(audio_playback.get("active_audio_record_count", 0)) < 2:
		_error("Audio playback did not materialize both source and target audio records: %s" % audio_playback)
	if int(audio_playback.get("generated_waveform_count", 0)) + int(audio_playback.get("scheduled_record_count", 0)) < 2:
		_error("Audio playback did not synthesize or schedule both source and target cue waveforms: %s" % audio_playback)
	var player_audio := _audio_record_for(audio_playback, "player_0")
	var enemy_audio := _audio_record_for(audio_playback, "enemy_0")
	_expect_array_contains("player audio runtime cue", player_audio.get("selected_audio_cue_ids", []), "audio_placeholder_ranged_release")
	_expect_array_contains("enemy audio runtime cue", enemy_audio.get("selected_audio_cue_ids", []), "audio_placeholder_status_apply")
	if int(player_audio.get("generated_waveform_count", 0)) < 1:
		_error("Source audio cue should synthesize immediately: %s" % player_audio)
	if bool(enemy_audio.get("scheduled", false)) and int(enemy_audio.get("sequence_delay_msec", 0)) <= 0:
		_error("Scheduled target audio cue should carry a positive sequence delay: %s" % enemy_audio)
	if String(audio_playback.get("audio_bus", "")) != "Master":
		_error("Audio playback should route generated battle cues through Master bus: %s" % audio_playback)
	return audio_playback

func _validate_active_camera_presentation(summary: Dictionary) -> Dictionary:
	var camera_playback: Dictionary = summary.get("camera_playback", {}) if summary.get("camera_playback", {}) is Dictionary else {}
	if int(camera_playback.get("active_camera_record_count", 0)) < 2:
		_error("Camera presentation did not materialize both source and target event records: %s" % camera_playback)
	if int(camera_playback.get("shake_record_count", 0)) < 2:
		_error("Camera presentation did not mark ranged/status records with impact shake: %s" % camera_playback)
	var focus_counts: Dictionary = camera_playback.get("focus_kind_counts", {}) if camera_playback.get("focus_kind_counts", {}) is Dictionary else {}
	if int(focus_counts.get("source_target", 0)) < 1 or int(focus_counts.get("status", 0)) < 1:
		_error("Camera presentation did not classify source-target and status focus kinds: %s" % camera_playback)
	if String(camera_playback.get("strongest_event_id", "")) == "":
		_error("Camera presentation did not identify a strongest active event: %s" % camera_playback)
	if float(camera_playback.get("strongest_shake_strength", 0.0)) <= 0.0:
		_error("Camera presentation did not expose positive shake strength: %s" % camera_playback)
	var max_offset := float(camera_playback.get("max_offset_px", 0.0))
	if max_offset <= 0.0:
		_error("Camera presentation did not expose a positive max offset: %s" % camera_playback)
	if absf(float(camera_playback.get("offset_x", 0.0))) > max_offset + 0.01 or absf(float(camera_playback.get("offset_y", 0.0))) > max_offset + 0.01:
		_error("Camera presentation offset exceeded its bounded max: %s" % camera_playback)
	return camera_playback

func _basic_session(player_unit_id: String, enemy_unit_id: String, player_q: int, player_r: int, enemy_q: int, enemy_r: int) -> SessionStateStoreScript.SessionData:
	return _session_for_stacks(
		[
			_stack(player_unit_id, "player", 0, "player_0", 8, player_q, player_r),
			_stack(enemy_unit_id, "enemy", 0, "enemy_0", 8, enemy_q, enemy_r),
		],
		"player_0",
		"enemy_0"
	)

func _session_for_stacks(stacks: Array, active_id: String, selected_id: String) -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-event-animation-state-report",
		"battle-event-animation-state-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 1,
		"max_rounds": 99,
		"distance": 1,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 12345,
		"stacks": stacks,
		"turn_order": [active_id],
		"turn_index": 0,
		"active_stack_id": active_id,
		"selected_target_id": selected_id,
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		BattleRulesScript.FIELD_OBJECTIVES_KEY: [],
		BattleRulesScript.STACK_ANIMATION_STATES_KEY: {},
		BattleRulesScript.ANIMATION_EVENT_SERIAL_KEY: 0,
	}
	BattleRulesScript._ensure_battle_hex_state(session.battle)
	return session

func _stack(unit_id: String, side: String, index: int, battle_id: String, count: int, q: int, r: int) -> Dictionary:
	var stack: Dictionary = BattleRulesScript._build_battle_stack(
		unit_id,
		count,
		side,
		index,
		{"source_type": "battle_event_animation_state_report"}
	)
	stack["battle_id"] = battle_id
	stack["side"] = side
	stack["hex"] = {"q": q, "r": r}
	return stack

func _spellcaster_state() -> Dictionary:
	return {
		"name": "Report Caster",
		"command": {"power": 2, "knowledge": 8},
		"spellbook": {
			"known_spell_ids": ["spell_cinder_burst"],
			"mana": {"current": 40, "max": 40},
		},
	}

func _stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	return BattleRulesScript._get_stack_by_id(battle, battle_id)

func _state_for(session: SessionStateStoreScript.SessionData, battle_id: String) -> String:
	return BattleRulesScript.animation_state_for_stack(session.battle, _stack_by_id(session.battle, battle_id))

func _board_summary_for_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	var summary: Dictionary = view.validation_unit_art_summary()
	view.queue_free()
	return summary

func _set_stack_field(battle: Dictionary, battle_id: String, key: String, value: Variant) -> void:
	var stacks: Array = battle.get("stacks", []) if battle.get("stacks", []) is Array else []
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack[key] = value
			stacks[index] = stack
			battle["stacks"] = stacks
			BattleRulesScript._ensure_battle_hex_state(battle)
			return

func _observed_animation_states(summary: Dictionary) -> Dictionary:
	var observed_states := {}
	for entry in summary.get("stacks", []):
		if entry is Dictionary:
			observed_states[String(entry.get("battle_id", ""))] = String(entry.get("animation_state", ""))
	return observed_states

func _cue_record_for(cue_playback: Dictionary, battle_id: String) -> Dictionary:
	var records: Dictionary = cue_playback.get("active_records", {}) if cue_playback.get("active_records", {}) is Dictionary else {}
	return records.get(battle_id, {}) if records.get(battle_id, {}) is Dictionary else {}

func _summary_stack_entry(summary: Dictionary, battle_id: String) -> Dictionary:
	var stacks: Array = summary.get("stacks", []) if summary.get("stacks", []) is Array else []
	for entry in stacks:
		if entry is Dictionary and String(entry.get("battle_id", "")) == battle_id:
			return entry
	_error("Missing board stack entry for %s in %s." % [battle_id, summary])
	return {}

func _vfx_entry_for(vfx_playback: Dictionary, kind: String) -> Dictionary:
	var entries: Array = vfx_playback.get("active_draw_entries", []) if vfx_playback.get("active_draw_entries", []) is Array else []
	for entry in entries:
		if entry is Dictionary and String(entry.get("kind", "")) == kind:
			return entry
	_error("Missing VFX draw entry kind %s in %s." % [kind, vfx_playback])
	return {}

func _audio_record_for(audio_playback: Dictionary, battle_id: String) -> Dictionary:
	var records: Dictionary = audio_playback.get("active_records", {}) if audio_playback.get("active_records", {}) is Dictionary else {}
	return records.get(battle_id, {}) if records.get(battle_id, {}) is Dictionary else {}

func _expect_event(label: String, battle: Dictionary, battle_id: String, event_id: String, state: String) -> void:
	for event in BattleRulesScript.animation_event_queue(battle):
		if not (event is Dictionary):
			continue
		if (
			String(event.get("battle_id", "")) == battle_id
			and String(event.get("event_id", "")) == event_id
			and String(event.get("state", "")) == state
		):
			return
	_error("%s missing event %s/%s for %s in %s." % [label, event_id, state, battle_id, BattleRulesScript.animation_event_queue(battle)])

func _event_record_for(battle: Dictionary, battle_id: String, event_id: String) -> Dictionary:
	for event in BattleRulesScript.animation_event_queue(battle):
		if event is Dictionary and String(event.get("battle_id", "")) == battle_id and String(event.get("event_id", "")) == event_id:
			return event
	_error("Missing event record %s for %s in %s." % [event_id, battle_id, BattleRulesScript.animation_event_queue(battle)])
	return {}

func _expect_ok(label: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_error("%s failed: %s" % [label, result])

func _expect_equal(label: String, actual: String, expected: String) -> void:
	if actual != expected:
		_error("%s expected %s but got %s." % [label, expected, actual])

func _expect_array_contains(label: String, values: Variant, expected: String) -> void:
	if not (values is Array):
		_error("%s expected an array containing %s but got %s." % [label, expected, values])
		return
	if expected not in values:
		_error("%s expected %s in %s." % [label, expected, values])

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to open %s for writing." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _summary_payload() -> Dictionary:
	var cases: Dictionary = _report.get("cases", {}) if _report.get("cases", {}) is Dictionary else {}
	return {
		"ok": bool(_report.get("ok", false)),
		"case_count": cases.size(),
		"cases": cases.keys(),
	}

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
