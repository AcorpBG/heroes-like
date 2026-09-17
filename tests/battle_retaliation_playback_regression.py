#!/usr/bin/env python3
"""Exercise lethal retaliation through real rules, board and packaged playback."""
import sys

import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/retaliation-casualty-playback-20260917'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scripts/core/BattleRules.gdc', 'scripts/core/BattleActionPlayback.gdc',
                  'scenes/battle/BattleBoardView.gdc', 'scenes/battle/BattleShell.gdc')
SCRIPT = r'''extends Node
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Playback = preload("res://scripts/core/BattleActionPlayback.gd")
const Board = preload("res://scenes/battle/BattleBoardView.gd")
var failures := []
var checks := 0
var cases := 0
var rendered_cases := 0
var out := ""
var requested := Vector2i(1280, 720)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func fixture(enemy: bool, lethal: bool, terminal: bool):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.battle = BattleRules.create_battle_payload(session, session.overworld.encounters[0])
	var side := "enemy" if enemy else "player"
	var other := "player" if enemy else "enemy"
	var attacker := BattleRules._build_battle_stack("unit_river_guard", 1, side, 0)
	var defender := BattleRules._build_battle_stack("unit_river_guard", 100, other, 0)
	var spare := BattleRules._build_battle_stack("unit_river_guard", 100, side, 1)
	var stacks := [attacker, defender] if terminal else [attacker, defender, spare]
	for index in range(stacks.size()):
		var stack: Dictionary = stacks[index]
		stack.total_health = (1 if lethal else 5000) if index == 0 else 10000
		stack.unit_hp = 100
		stack.base_count = int(ceil(float(stack.total_health) / 100.0))
		stack.attack = 0
		stack.defense = 0
		stack.min_damage = 1 if index == 0 else 4
		stack.max_damage = stack.min_damage
		stack.ranged = false
		stack.abilities = []
		stack.effects = []
		stack.retaliations_left = 1
		stack.hex = {"q": 3 + index, "r": 3 if index < 2 else 5}
	session.battle.stacks = stacks
	session.battle.turn_order = [attacker.battle_id, defender.battle_id] if terminal else [attacker.battle_id, spare.battle_id, defender.battle_id]
	session.battle.turn_index = 0
	session.battle.active_stack_id = attacker.battle_id
	session.battle.selected_target_id = defender.battle_id
	session.battle[BattleRules.FIELD_OBJECTIVES_KEY] = []
	BattleRules._sync_occupied_hexes(session.battle)
	BattleRules._sync_distance_from_hexes(session.battle)
	session.game_state = "battle"
	return session
func resolve(session, enemy: bool, capture: bool) -> Dictionary:
	if not enemy:
		return BattleRules.perform_presented_action(session, "strike") if capture else BattleRules.perform_player_action(session, "strike")
	var battle: Dictionary = session.battle
	if capture: Playback.begin(battle)
	var result := BattleRules._resolve_ai_attack(session, battle.stacks[0], battle.stacks[1], false)
	return Playback.finish(battle, result) if capture else result
func is_corpse(board, id: String) -> bool:
	for entry in board._battle_corpse_entries(board._current_hex_layout()):
		if entry.battle_id == id: return true
	return false
func set_clock(board, id: String, elapsed: int) -> void:
	# Controlled headless sampling changes presentation clocks only. Rendered
	# shell coverage below observes unmodified wall clocks at every frame.
	var record: Dictionary = board._stack_animation_playback_records.get(id, {})
	check(not record.is_empty(), "missing reaction clock")
	if record.is_empty(): return
	var started := Time.get_ticks_msec() - elapsed
	var expires := started + int(record.max_duration_ms)
	for records in [board._stack_animation_playback_records, board._stack_animation_cue_playback_records, board._stack_animation_audio_playback_records]:
		if records.has(id):
			records[id].started_at_msec = started
			records[id].expires_at_msec = expires
	board._stack_animation_playback_until_msec[id] = expires
func exercise(board, enemy: bool, lethal: bool, terminal: bool, speed: String, reduced: bool) -> void:
	cases += 1
	var label := str([enemy, lethal, terminal, speed, reduced])
	SettingsService.set_reduced_motion_enabled(reduced)
	var session = fixture(enemy, lethal, terminal)
	BattleRules.set_battle_presentation_speed(session, speed)
	var direct = Store.new_session_data()
	direct.from_dict(session.to_dict().duplicate(true))
	var victim_id := String(session.battle.stacks[0].battle_id)
	var battle: Dictionary = session.battle
	var result := resolve(session, enemy, true)
	var reference := resolve(direct, enemy, false)
	check(result.ok and reference.ok, "attack failed " + label)
	check(session.to_dict() == direct.to_dict(), "captured action changed simulation/RNG/save " + label)
	check(not battle.has(Playback.CAPTURE_KEY), "capture leaked into save")
	var committed: Dictionary = session.to_dict().duplicate(true)
	var deaths := 0
	var counter_index := -1
	var reaction_index := -1
	var frames: Array = result.get("playback_frames", [])
	for index in range(frames.size()):
		var frame: Dictionary = frames[index]
		var event: Dictionary = frame.playback_event
		if event.event_id == "battle_unit_death" and event.battle_id == victim_id: deaths += 1
		if event.event_id == "battle_retaliation" and event.target_battle_id == victim_id: counter_index = index
		if event.event_id in ["battle_unit_hit", "battle_unit_death"] and event.battle_id == victim_id: reaction_index = index
	check(counter_index >= 0 and reaction_index > counter_index, "counterattack/reaction ordering absent " + label)
	check(deaths == (1 if lethal else 0), "death event count wrong " + label)
	if counter_index < 0 or reaction_index < 0: return
	var windup: Dictionary = frames[counter_index]
	var reaction: Dictionary = frames[reaction_index]
	var before := BattleRules._get_stack_by_id(windup, victim_id)
	var after := BattleRules._get_stack_by_id(reaction, victim_id)
	check(int(before.total_health) == (1 if lethal else 5000), "premature retaliation damage/corpse " + label)
	check(int(after.total_health) == 0 if lethal else int(after.total_health) > 0, "unexpected casualty result " + label)
	check(int(reaction.playback_event.damage) == int(before.total_health) - int(after.total_health), "lost retaliation damage delta " + label)
	check(int(reaction.playback_event.casualties) == BattleRules._alive_count(before) - BattleRules._alive_count(after), "lost retaliation casualty count " + label)
	if speed != "instant":
		board.set_battle_presentation_snapshot(windup)
		check(not is_corpse(board, victim_id) and board._stack_visible_for_presentation(before), "corpse during retaliation windup " + label)
		board.set_battle_presentation_snapshot(reaction)
		set_clock(board, victim_id, -1000)
		check(not is_corpse(board, victim_id), "corpse before scheduled reaction " + label)
		set_clock(board, victim_id, 20)
		check(board._animation_state_for_stack(after) == ("death_rout_remove" if lethal else "hit_stagger"), "wrong reaction pose " + label)
		check(not is_corpse(board, victim_id), "corpse competes with reaction animation " + label)
		set_clock(board, victim_id, 10000)
		check(is_corpse(board, victim_id) == lethal, "reaction does not settle correctly " + label)
		check(board._stack_visible_for_presentation(after) != lethal, "casualty rises after reaction " + label)
		for index in range(reaction_index + 1, frames.size()):
			board.set_battle_presentation_snapshot(frames[index])
			check(is_corpse(board, victim_id) == lethal, "later snapshot revives casualty " + label)
	var display = Store.new_session_data()
	display.battle = battle.duplicate(true)
	for repeat in range(2):
		board.finish_action_playback(display)
		check(is_corpse(board, victim_id) == lethal, "final synchronization replays death " + label)
	check(session.to_dict() == committed, "board playback changed session " + label)
	if terminal: check(result.state in ["victory", "defeat"], "terminal fixture did not end battle")
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image.get_size() == requested, "rendered resolution differs from requested viewport")
	image.save_png(out.path_join(name + ".png"))
func rendered_flow(enemy: bool, speed: String, reduced: bool) -> void:
	SettingsService.set_battle_playback_speed_id(speed)
	SettingsService.set_reduced_motion_enabled(reduced)
	SessionState.set_active_session(fixture(false, false, false))
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	for i in range(3): await get_tree().process_frame
	DisplayServer.window_set_size(requested)
	get_tree().root.size = requested
	get_tree().root.content_scale_size = requested
	for i in range(3): await get_tree().process_frame
	var session = fixture(enemy, true, false)
	BattleRules.set_battle_presentation_speed(session, speed)
	# Enter through the shell's normal normalization before committing an
	# action; artificial fixture HP/schema must not normalize only on exit.
	shell._session = session
	shell._refresh()
	var victim_id := String(session.battle.stacks[0].battle_id)
	var result := resolve(session, enemy, true)
	var committed: Dictionary = session.to_dict().duplicate(true)
	check(shell._begin_action_playback(result), "real shell did not start playback")
	var board = shell._battle_board_view
	var seen_corpse := false
	var seen_windup := false
	var seen_death := false
	var deadline := Time.get_ticks_msec() + 20000
	var label := ("enemy" if enemy else "player") + "-" + speed
	while shell._action_playback_in_progress and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var frame: Dictionary = board._battle
		var victim := BattleRules._get_stack_by_id(frame, victim_id)
		if victim.is_empty(): continue
		var corpse := is_corpse(board, victim_id)
		if seen_corpse: check(not board._stack_visible_for_presentation(victim), "visible resurrection in real shell " + label)
		seen_corpse = seen_corpse or corpse
		var event: Dictionary = frame.get("playback_event", {})
		if event.get("event_id") == "battle_retaliation" and not seen_windup:
			check(int(victim.total_health) > 0 and not corpse, "real shell premature corpse " + label)
			seen_windup = true
			await capture(label + "-counterattack")
		if event.get("event_id") == "battle_unit_death" and board._animation_state_for_stack(victim) == "death_rout_remove" and not seen_death:
			seen_death = true
			await capture(label + "-dying")
	check(not shell._action_playback_in_progress, "real shell playback did not finish")
	check(seen_windup and seen_death and is_corpse(board, victim_id), "real shell missed counter/death/corpse sequence " + label)
	await capture(label + "-corpse")
	check(session.to_dict() == committed, "shell changed committed combat state")
	# Instant uses the authoritative final state without replaying any frame.
	var instant = fixture(enemy, true, false)
	BattleRules.set_battle_presentation_speed(instant, "instant")
	check(not shell._begin_action_playback(resolve(instant, enemy, true)), "Instant queued animation")
	shell.queue_free()
	for i in range(3): await get_tree().process_frame
	rendered_cases += 1
func _ready() -> void: call_deferred("run")
func run() -> void:
	out = OS.get_environment("BATTLE_READABILITY_OUT")
	var dims := OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	requested = Vector2i(int(dims[0]), int(dims[1]))
	get_tree().root.size = requested
	get_tree().root.content_scale_size = get_tree().root.size
	var board = Board.new()
	board.size = Vector2(1280, 720)
	add_child(board)
	for enemy in [false, true]:
		for speed in ["normal", "fast", "instant"]:
			for reduced in [false, true]:
				exercise(board, enemy, false, false, speed, reduced)
				exercise(board, enemy, true, false, speed, reduced)
				exercise(board, enemy, true, true, speed, reduced)
	board.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var speed := OS.get_environment("BATTLE_READABILITY_SPEED")
		var reduced := OS.get_environment("BATTLE_READABILITY_REDUCED") == "1"
		for enemy in [false, true]: await rendered_flow(enemy, speed, reduced)
	MusicAudio.stop_stinger()
	MusicAudio.stop_music("retaliation_probe_teardown")
	await get_tree().create_timer(0.15).timeout
	print("BATTLE_READABILITY_REPORT " + JSON.stringify({"ok":failures.is_empty(), "checks":checks, "failures":failures, "cases":cases, "rendered_cases":rendered_cases}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    runner.ROOT, runner.OUTPUT, runner.SCRIPT = ROOT, OUTPUT, SCRIPT
    runner.run_probe, runner.probe_environment = run_probe, probe_environment
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
