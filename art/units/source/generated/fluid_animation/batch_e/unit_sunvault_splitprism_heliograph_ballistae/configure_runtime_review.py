"""Observe actual normal/fast/reduced shell actions in both real facings."""


def configure(f, clip, reflected=False):
    def replace(old, new, count=1):
        assert f.SCRIPT.count(old) == count, (old, f.SCRIPT.count(old))
        f.SCRIPT = f.SCRIPT.replace(old, new)

    action = 'shoot' if clip == 'ranged' else 'strike'
    if reflected:
        replace('rendered.battle.stacks[0].unit_id=attack_id', 'rendered.battle.stacks[1].unit_id=attack_id')
        replace('rendered.battle.stacks[0].name=ContentService.get_unit(attack_id).name', 'rendered.battle.stacks[1].name=ContentService.get_unit(attack_id).name')
        replace('rendered.battle.stacks[0].battle_id', 'rendered.battle.stacks[1].battle_id', 3)
        setup = ('\t\trendered.battle.active_stack_id=rendered.battle.stacks[1].battle_id\n'
                 '\t\trendered.battle.turn_index=1\n'
                 '\t\trendered.battle.commander_spell_cast_rounds={"enemy":int(rendered.battle.get("round",1))}\n')
        if clip == 'ranged':
            replace('stacks[index].ranged = index==0', 'stacks[index].ranged = index==1')
        else:
            setup = ('\t\trendered.battle.stacks[1].hex={"q":3,"r":3}\n'
                     '\t\tBattleRules._sync_occupied_hexes(rendered.battle)\n'
                     '\t\tBattleRules._sync_distance_from_hexes(rendered.battle)\n') + setup
        needle = '\t\tvar action:Dictionary=shell._perform_action("'+action+'")'
        replace(needle, setup+needle.replace('"'+action+'"', '"ready"'))

    # The observer timeout follows the committed event list, original timings
    # and path lengths. The action clocks and every strict assertion stay intact.
    replace('\t\tvar deadline:=Time.get_ticks_msec()+20000', '''\t\tvar planned_observation_msec:int=5000
\t\tvar observation_frames:Array=[shell._battle_board_view._battle]
\t\tobservation_frames.append_array(shell._action_playback_frames)
\t\tfor queued_frame in observation_frames:
\t\t\tvar queued_event:Dictionary=queued_frame.get("playback_event",{})
\t\t\tvar queued_actor:Dictionary=BattleRules._get_stack_by_id(queued_frame,String(queued_event.get("battle_id","")))
\t\t\tvar queued_animation:Dictionary=ContentService.get_unit_animation(String(queued_actor.get("unit_id","")))
\t\t\tvar queued_state:String=String(queued_event.get("state",""))
\t\t\tvar queued_name:String=Pose.clip_name(queued_state)
\t\t\tvar queued_spec:Dictionary=Pose.clip(queued_animation,queued_state)
\t\t\tvar queued_duration:int=700
\t\t\tif queued_name!="idle" and queued_animation.get("pose_clips",{}).has(queued_name) and bool(queued_spec.get("authored_timing",false)):
\t\t\t\tqueued_duration=Pose.clip_duration_msec(queued_spec)
\t\t\t\tif queued_event.get("event_id","")=="battle_unit_move":queued_duration*=maxi(1,queued_event.get("walk_path",[]).size()-1)
\t\t\tplanned_observation_msec+=queued_duration+1000
\t\tcheck(planned_observation_msec<70000,"committed observation plan exceeds bounded fixture")
\t\tprint("HELIOGRAPH_OBSERVATION_PLAN "+str(planned_observation_msec))
\t\tvar deadline:=Time.get_ticks_msec()+maxi(20000,planned_observation_msec)''')
    needle = '\t\tcheck(not shell._action_playback_in_progress,"shell animation queue did not finish")'
    replace(needle, '\t\tprint("HELIOGRAPH_DRAWN_POSES "+JSON.stringify({"seen":seen_attack_frames,"captured":captured_poses}))\n'+needle)
    start = f.SCRIPT.index('\tif DisplayServer.get_name()!="headless" and not attack_id.is_empty() and OS.get_environment("FLUID_CONTACTS_ONLY")!="1":')
    end = f.SCRIPT.index('\tprint("FLUID_ANIMATION_REPORT ', start)
    block = f.SCRIPT[start:end]
    block = block.replace('SettingsService.set_reduced_motion_enabled(false)', 'SettingsService.set_reduced_motion_enabled(review_mode=="reduced")')
    block = block.replace('SettingsService.set_battle_playback_speed_id("normal")', 'SettingsService.set_battle_playback_speed_id("fast" if review_mode=="fast" else "normal")')
    block = block.replace('"battle-phase-"+str(i)', '"battle-"+review_mode+"-phase-"+str(i)')
    block = block.replace('"captured":captured_poses', '"captured":captured_poses,"mode":review_mode')
    assertion = '\t\tcheck(seen_attack_frames.size()==int(ContentService.get_unit_animation(attack_id).pose_clips.'+clip+'.frames),"shell did not show every authored attack pose including recovery; observed="+str(seen_attack_frames))'
    assert block.count(assertion) == 1
    block = block.replace(assertion,
        '\t\tif review_mode=="reduced":\n'
        '\t\t\tcheck(seen_attack_frames==[int(ContentService.get_unit_animation(attack_id).pose_clips.'+clip+'.get("static_frame",0))],"reduced actual action did not hold authored static pose; observed="+str(seen_attack_frames))\n'
        '\t\telse:\n\t'+assertion)
    lines = block.splitlines()
    f.SCRIPT = f.SCRIPT[:start]+lines[0]+'\n\t\tfor review_mode in ["normal","fast","reduced"]:\n'+'\n'.join('\t'+line for line in lines[1:])+'\n'+f.SCRIPT[end:]
    # One bounded engine invocation now observes three actual modes. This is
    # a process watchdog, not a production animation duration or relaxed check.
    original_run = f.subprocess.run
    def run(*args, **kwargs):
        if kwargs.get('timeout') == 90:
            kwargs['timeout'] = 240
        return original_run(*args, **kwargs)
    f.subprocess.run = run
