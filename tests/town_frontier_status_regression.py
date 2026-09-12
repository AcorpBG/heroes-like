#!/usr/bin/env python3
"""Retain the existing occupation/retake contract beside the new troop plaques."""
import battle_readability_regression as base

SCRIPT = r'''extends "res://tests/town_battle_visual_smoke.gd"
func _ready()->void:call_deferred("run_frontier")
func run_frontier()->void:
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var town:=_first_player_town(session)
	_move_active_hero_to_town(session,town)
	var stage=TownStageViewScript.new()
	add_child(stage)
	stage.size=Vector2(1180,640)
	stage.set_town_state(session)
	await get_tree().process_frame
	var ok:bool=await _assert_town_capture_frontier_status_contract(stage,session)
	stage.queue_free()
	for i in range(3):await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":ok,"contract":"existing ordinary, occupation, retake, combined, detached and day-refresh frontier plaques"}))
	get_tree().quit(0 if ok else 1)
'''

if __name__ == '__main__':
    base.OUTPUT = base.ROOT / '.artifacts/town_defender_clarity_20260912'
    base.SCRIPT = SCRIPT
    raise SystemExit(base.main())
