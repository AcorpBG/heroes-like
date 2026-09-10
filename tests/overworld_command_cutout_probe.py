"""34 exact command paintings; ordinary scouting to three original landmarks."""
from overworld_state_cutout_probe import SCRIPT as STATE_SCRIPT
from overworld_route_arcane_cutout_probe import SCRIPT as ROUTE_SCRIPT

SCRIPT=STATE_SCRIPT.replace('all thirty-four original state paintings','all thirty-four original command paintings')
SCRIPT=SCRIPT.replace('check(affected_native.size()>0 and captured_states.size()>0,"actual earned affected native states, not only detached coverage")',
                      'check(affected_native.is_empty() and captured_states.is_empty(),"fixed earned native checkpoint contains no command-site records; unchanged control only")')
scout=ROUTE_SCRIPT.split('func seal_scout_route(',1)[1].split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('func run() -> void:','func seal_scout_route('+scout+'func run() -> void:')
needle='    before=normalized(session.to_dict())\n    MusicAudio.stop_music'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,r'''
    var command_cases := [
        ["tollbrand-toll-chain-muster","resource_site_muster_tollbrand_toll_chain_standard",Vector2i(12,5),Vector2i(9,5)],
        ["cinderquill-grand-route-kiln","resource_site_route_cinderquill_kiln_desk",Vector2i(20,7),Vector2i(17,7)],
        ["vellum-quenchline-dominion-siege","resource_site_dominion_quench_cantilever_gauge",Vector2i(19,7),Vector2i(16,7)]
    ]
    var command_scouting := []
    for command_case in command_cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(command_case[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        AppRouter.resume_active_session()
        await settle()
        if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
            check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary command-site Town exit")
            await settle()
        var original_node := {}
        for node in session.overworld.resource_nodes:
            if Vector2i(int(node.x),int(node.y))==command_case[2]:original_node=normalized(node)
        check(not original_node.is_empty(),str(command_case[0])+" original landmark exists")
        var actions := []
        for attempt in range(8):
            if OverworldRules.hero_position(session)==command_case[3]:break
            var route: Array=seal_scout_route(session,command_case[3])
            check(route.size()>1,str(command_case[0])+" legal scouting route exists")
            if route.size()<2:break
            var travel: Dictionary=OverworldRules.try_move_along_route(session,route)
            actions.append({"route":route,"travel":travel})
            if OverworldRules.hero_position(session)==command_case[3]:break
            var turn: Dictionary=OverworldRules.end_turn(session)
            check(bool(turn.get("ok",false)),str(command_case[0])+" normal end turn while scouting")
            actions.append({"turn":turn})
        AppRouter.resume_active_session()
        await settle()
        view=get_tree().current_scene._map_view
        var node: Dictionary=view._resource_node_at(command_case[2])
        check(OverworldRules.hero_position(session)==command_case[3],str(command_case[0])+" reached legal scouting destination")
        check(normalized(node)==original_node,str(command_case[0])+" complete guarded site preserved")
        check(OverworldRules.is_tile_visible(session,command_case[2].x,command_case[2].y),str(command_case[0])+" original site visible through earned vision")
        check(view._resource_asset_id(node)==command_case[1],str(command_case[0])+" exact original resource identity")
        before=normalized(session.to_dict())
        await capture(view,command_case[2],command_case[1],node,"actual original guarded command site after ordinary scouting; no fog, claim or placement grants")
        await save_control(session,before,"command_"+str(command_case[0]))
        command_scouting.append({"scenario":command_case[0],"day":session.day,"actions":actions,"site":node})
    authored["command_scouting"]=command_scouting
    before=normalized(session.to_dict())
    MusicAudio.stop_music''')
