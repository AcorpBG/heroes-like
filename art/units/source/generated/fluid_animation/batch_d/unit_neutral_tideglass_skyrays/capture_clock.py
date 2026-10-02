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
