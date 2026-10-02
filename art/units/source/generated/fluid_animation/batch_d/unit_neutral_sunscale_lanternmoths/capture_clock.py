"""Observe every drawn battle frame without a second screenshot-only yield."""
def observe_after_draw(fixture):
    # The shared probe observes process_frame, then yields frame_post_draw
    # again for selected screenshots. That can miss short authored poses in
    # its observation list. Sample each rendered frame once and read back
    # that same completed viewport. All pose/timing assertions stay intact.
    before='while shell._action_playback_in_progress and Time.get_ticks_msec()<deadline:\n\t\t\tawait get_tree().process_frame'
    assert fixture.SCRIPT.count(before)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(before,before.replace('await get_tree().process_frame','await RenderingServer.frame_post_draw'))
    before='\t\t\t\t\t\tawait RenderingServer.frame_post_draw\n\t\t\t\t\t\tphase_captures.append'
    assert fixture.SCRIPT.count(before)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(before,'\t\t\t\t\t\tphase_captures.append')
    # GPU readback can cross a pose boundary after the real draw. Observe the
    # exact atlas region selected by the unchanged renderer, not a later clock
    # calculation. The preview subclass only records; it never freezes or
    # substitutes playback, source pixels, timing, or simulation state.
    observer='''class ObservedBoard extends Board:
\tvar drawn_pose_regions:Dictionary={}
\tvar observing_draw:bool=false
\tfunc _draw():
\t\tdrawn_pose_regions.clear();observing_draw=true
\t\tsuper._draw()
\t\tobserving_draw=false
\tfunc _animation_frame_region_for_stack(stack:Dictionary)->Rect2:
\t\tvar region:Rect2=super._animation_frame_region_for_stack(stack)
\t\tif observing_draw:drawn_pose_regions[String(stack.battle_id)]=region
\t\treturn region
'''
    needle='class ContactSheet extends Control:';assert fixture.SCRIPT.count(needle)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(needle,observer+'\n'+needle)
    needle='\t\tadd_child(shell)';assert fixture.SCRIPT.count(needle)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(needle,'\t\tshell.get_node("%BattleBoard").set_script(ObservedBoard)\n'+needle)
    lines=fixture.SCRIPT.splitlines();candidates=[line for line in lines if 'var pose_index:int=Pose.timed_frame(' in line];assert len(candidates)==1
    old=candidates[0];name='ranged' if '.pose_clips.ranged' in old else 'attack'
    replacement='''\t\t\t\t\tvar pose_index:int=-1
\t\t\t\t\tvar drawn:Rect2=shell._battle_board_view.drawn_pose_regions.get(rendered.battle.stacks[0].battle_id,Rect2())
\t\t\t\t\tvar animation:Dictionary=ContentService.get_unit_animation(attack_id)
\t\t\t\t\tvar indices:Array=animation.pose_clips.CLIP.indices
\t\t\t\t\tfor i in range(indices.size()):
\t\t\t\t\t\tvar r:Array=animation.pose_frame_rects[int(indices[i])]
\t\t\t\t\t\tif drawn==Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])):pose_index=i;break
'''.rstrip().replace('CLIP',name)
    fixture.SCRIPT=fixture.SCRIPT.replace(old,replacement)
    needle='if pose_index not in seen_attack_frames:seen_attack_frames.append(pose_index)';assert fixture.SCRIPT.count(needle)==1
    fixture.SCRIPT=fixture.SCRIPT.replace(needle,'if pose_index>=0 and pose_index not in seen_attack_frames:seen_attack_frames.append(pose_index)')
