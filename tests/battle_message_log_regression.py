#!/usr/bin/env python3
"""Persistent history checks alongside the actual battle playback regression."""
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/battle_message_log_20260911'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
SCRIPT = runner.SCRIPT.replace(
    '\tif DisplayServer.get_name()!="headless":',
    '''\tvar audio_before_log=UiAudio.validation_records().duplicate(true)
\tvar log_control=load("res://scenes/battle/BattleMessageLog.gd").new()
\tadd_child(log_control)
\tlog_control.size=Vector2(1000,88)
\tfor i in range(205): log_control.append_message("Message %d"%i)
\tfor i in range(4): await get_tree().process_frame
\tcheck(log_control.entries.size()==200 and log_control.entries[0]=="Message 5","history bound/order failed")
\tcheck(log_control.history.text.ends_with("Message 204"),"last message missing")
\tvar bar=log_control.history.get_v_scroll_bar()
\tcheck(bar.value>=bar.max_value-bar.page-2,"history did not follow newest message")
\tbar.value=0
\tlog_control.append_message("Message 205")
\tfor i in range(4): await get_tree().process_frame
\tcheck(bar.value==0,"new message interrupted reading history")
\tcheck(log_control.history.focus_mode==Control.FOCUS_ALL,"history not keyboard focusable")
\tcheck(UiAudio.validation_records()==audio_before_log,"history scrolling emitted adjustment audio")
\tlog_control.queue_free()
\tif DisplayServer.get_name()=="headless":
\t\tSessionState.set_active_session(fixture())
\t\tvar headless_shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
\t\tadd_child(headless_shell)
\t\tfor i in range(4): await get_tree().process_frame
\t\tvar headless_action:Dictionary=headless_shell._perform_action("strike")
\t\tcheck(headless_action.ok and headless_shell._message_log.entries.size()>2,"headless shell did not retain actual action history")
\t\tcheck("damage" in "\\n".join(headless_shell._message_log.entries),"headless shell lost damage history")
\t\theadless_shell.queue_free()
\t\tfor i in range(3): await get_tree().process_frame
\tif DisplayServer.get_name()!="headless":''', 1)
SCRIPT = SCRIPT.replace(
    '\t\t\t\trendered_events.append(displayed.playback_event.event_id)',
    '\t\t\t\trendered_events.append(displayed.playback_event.event_id)\n'
    '\t\t\t\tcheck(shell._message_log.entries.back().ends_with(displayed.playback_caption),"history is out of sync with displayed action")', 1)
SCRIPT = SCRIPT.replace(
    '\t\tSettingsService.set_battle_playback_speed_id("instant")',
    '''\t\tvar retained:Array=shell._message_log.entries.duplicate()
\t\tcheck("BattleHistory" in shell._last_battle_keyboard_focus_cycle_names,"history absent from keyboard cycle")
\t\tcheck(retained.size()>2,"played actions not retained")
\t\tcheck("damage" in "\\n".join(retained) and "lost" in "\\n".join(retained),"damage/casualty history missing")
\t\tawait get_tree().create_timer(1.2).timeout
\t\tshell._refresh()
\t\tfor i in range(4): await get_tree().process_frame
\t\tcheck(shell._message_log.entries==retained,"refresh/timeout erased history")
\t\tvar bounds=Rect2(Vector2.ZERO,Vector2(requested))
\t\tcheck(bounds.encloses(shell._message_log.get_global_rect()),"history clips viewport")
\t\tcheck(not shell._message_log.get_global_rect().intersects(shell._battle_board_view.get_global_rect()),"history covers battlefield")
\t\tcheck(not shell._message_log.get_global_rect().intersects(shell._footer_panel.get_global_rect()),"history covers commands")
\t\tawait RenderingServer.frame_post_draw
\t\tget_viewport().get_texture().get_image().save_png(out.path_join("retained-log.png"))
\t\tSettingsService.set_battle_playback_speed_id("instant")''', 1)
SCRIPT = SCRIPT.replace(
    '\t\tshell.queue_free()',
    '''\t\tcheck(shell._message_log.entries.size()>retained.size(),"instant action lost its history")
\t\tshell.queue_free()''', 1)

def main():
    runner.OUTPUT = OUTPUT
    runner.SCRIPT = SCRIPT
    runner.run_probe = run_probe
    runner.probe_environment = probe_environment
    return runner.main()

if __name__ == '__main__':
    raise SystemExit(main())
