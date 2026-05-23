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
	_validate_melee_hit_state()
	_validate_ranged_status_state()
	_validate_death_state()
	_validate_spell_cast_state()
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
	_report["cases"]["move"] = {"state": state, "destination": destination, "events": BattleRulesScript.animation_event_states(session.battle), "queue": BattleRulesScript.animation_event_queue(session.battle)}

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
	_report["cases"]["melee_hit"] = {"attacker_state": attacker_state, "target_state": target_state, "events": BattleRulesScript.animation_event_states(session.battle), "queue": BattleRulesScript.animation_event_queue(session.battle)}

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
	_report["cases"]["ranged_status"] = {"attacker_state": attacker_state, "target_state": target_state, "events": BattleRulesScript.animation_event_states(session.battle), "queue": BattleRulesScript.animation_event_queue(session.battle)}

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
	_report["cases"]["death"] = {"target_state": target_state, "events": BattleRulesScript.animation_event_states(session.battle), "queue": BattleRulesScript.animation_event_queue(session.battle)}

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
	_report["cases"]["spell_cast"] = {"caster_state": caster_state, "target_state": target_state, "events": BattleRulesScript.animation_event_states(session.battle), "queue": BattleRulesScript.animation_event_queue(session.battle)}

func _validate_board_runtime_summary() -> void:
	var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "shoot")
	_expect_ok("board summary source action", result)
	var view := BattleBoardViewScript.new()
	add_child(view)
	view.set_battle_state(session)
	await get_tree().process_frame
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
	_report["cases"]["board_runtime"] = {"observed_states": observed_states, "summary": summary}
	_report["cases"]["board_cue_dispatch"] = {
		"active_cue_playback": cue_playback,
	}

func _validate_board_playback_lifecycle() -> void:
	var session := _basic_session("unit_mire_slinger", "unit_bog_brute", 1, 3, 7, 3)
	_set_stack_field(session.battle, "enemy_0", "total_health", 999)
	var result := BattleRulesScript.perform_player_action(session, "shoot")
	_expect_ok("board lifecycle source action", result)
	var view := BattleBoardViewScript.new()
	add_child(view)
	view.set_battle_state(session)
	await get_tree().process_frame
	var active_summary: Dictionary = view.validation_unit_art_summary()
	var active_states := _observed_animation_states(active_summary)
	var active_playback: Dictionary = active_summary.get("animation_playback", {}) if active_summary.get("animation_playback", {}) is Dictionary else {}
	var active_cue: Dictionary = active_summary.get("cue_playback", {}) if active_summary.get("cue_playback", {}) is Dictionary else {}
	_expect_equal("lifecycle active ranged state", String(active_states.get("player_0", "")), "ranged_aim_release")
	_expect_equal("lifecycle active status state", String(active_states.get("enemy_0", "")), "status_applied")
	if int(active_playback.get("active_playback_count", 0)) < 2:
		_error("Playback lifecycle did not keep both source and target events active: %s" % active_playback)
	if int(active_cue.get("active_cue_record_count", 0)) < 2:
		_error("Cue lifecycle did not keep both source and target cue records active: %s" % active_cue)
	await get_tree().create_timer(0.90).timeout
	var expired_summary: Dictionary = view.validation_unit_art_summary()
	var expired_states := _observed_animation_states(expired_summary)
	var expired_playback: Dictionary = expired_summary.get("animation_playback", {}) if expired_summary.get("animation_playback", {}) is Dictionary else {}
	var expired_cue: Dictionary = expired_summary.get("cue_playback", {}) if expired_summary.get("cue_playback", {}) is Dictionary else {}
	_expect_equal("lifecycle expired source fallback", String(expired_states.get("player_0", "")), "ready_active")
	_expect_equal("lifecycle expired target fallback", String(expired_states.get("enemy_0", "")), "idle_hold")
	if int(expired_playback.get("active_playback_count", -1)) != 0:
		_error("Playback lifecycle did not expire event states: %s" % expired_playback)
	if int(expired_cue.get("active_cue_record_count", -1)) != 0:
		_error("Cue lifecycle did not expire cue records: %s" % expired_cue)
	view.queue_free()
	await get_tree().process_frame
	_report["cases"]["board_playback_lifecycle"] = {
		"active_states": active_states,
		"expired_states": expired_states,
		"active_playback": active_playback,
		"expired_playback": expired_playback,
		"active_cue_playback": active_cue,
		"expired_cue_playback": expired_cue,
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
	_expect_array_contains("player cue vfx", player_cue.get("selected_vfx_cue_ids", []), "vfx_placeholder_projectile_path")
	_expect_array_contains("player cue audio", player_cue.get("selected_audio_cue_ids", []), "audio_placeholder_ranged_release")
	_expect_array_contains("enemy cue vfx", enemy_cue.get("selected_vfx_cue_ids", []), "vfx_placeholder_status_residue")
	_expect_array_contains("enemy cue audio", enemy_cue.get("selected_audio_cue_ids", []), "audio_placeholder_status_apply")
	return cue_playback

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
