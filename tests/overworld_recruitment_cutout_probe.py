"""36 recruitment paintings; ordinary scouting to eight original landmarks."""
from overworld_state_cutout_probe import SCRIPT as STATE_SCRIPT
from overworld_route_arcane_cutout_probe import SCRIPT as ROUTE_SCRIPT

SCRIPT=STATE_SCRIPT.replace('specs.size()==34,"all thirty-four original state paintings"','specs.size()==36,"all thirty-six recruitment paintings"')
SCRIPT=SCRIPT.replace('spec.entry.assigned_resource_site_id','spec.site_id').replace('specs[key].entry.assigned_resource_site_id','specs[key].site_id')
SCRIPT=SCRIPT.replace('check(affected_native.size()>0 and captured_states.size()>0,"actual earned affected native states, not only detached coverage")',
                      'check(affected_native.is_empty() and captured_states.is_empty(),"fixed earned native checkpoint contains no recruitment-site records; unchanged control only")')
scout=ROUTE_SCRIPT.split('func seal_scout_route(',1)[1].split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('func run() -> void:','func seal_scout_route('+scout+'func run() -> void:')
needle='    before=normalized(session.to_dict())\n    MusicAudio.stop_music'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,r'''
    var recruitment_cases := [
        ["pikeward-brambleback-concord","mapobj_brambleback_hedgecourt",Vector2i(11,4),Vector2i(8,4)],
        ["glassmarshal-daybreak-veteran-muster","mapobj_mirror_daybreak_drill_prism",Vector2i(12,1),Vector2i(9,1)],
        ["emberwell-censerwing-updraft","mapobj_cindervane_updraft_roost",Vector2i(15,10),Vector2i(12,10)],
        ["fenhook-fenmirror-muster","mapobj_fenmirror_shell_basin",Vector2i(15,10),Vector2i(12,10)],
        ["glasswind-prismwake-crossing","mapobj_prismwake_refraction_shelf",Vector2i(15,10),Vector2i(12,10)],
        ["boltroot-knotstag-circuit","mapobj_knotstag_root_court",Vector2i(15,10),Vector2i(12,10)],
        ["debtrune-gaugecoil-burrow","mapobj_gaugecoil_pressure_burrow",Vector2i(15,10),Vector2i(12,10)],
        ["mistcorsair-gloambell-sounding","mapobj_gloambell_sounding_deep",Vector2i(15,10),Vector2i(12,10)]
    ]
    var recruitment_scouting := []
    for recruitment_case in recruitment_cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(recruitment_case[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        AppRouter.resume_active_session()
        await settle()
        if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
            check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary recruitment-site Town exit")
            await settle()
        var scout_destination: Vector2i=recruitment_case[3]
        if seal_scout_route(session,scout_destination).is_empty():
            var best_route := []
            for y in range(recruitment_case[2].y-3,recruitment_case[2].y+4):
                for x in range(recruitment_case[2].x-3,recruitment_case[2].x+4):
                    var candidate:=Vector2i(x,y)
                    if absi(x-recruitment_case[2].x)+absi(y-recruitment_case[2].y)>3:continue
                    if OverworldRules.tile_has_route_interaction(session,x,y):continue
                    var candidate_route: Array=seal_scout_route(session,candidate)
                    if candidate_route.size()>1 and (best_route.is_empty() or candidate_route.size()<best_route.size()):
                        best_route=candidate_route
                        scout_destination=candidate
        var original_node := {}
        for node in session.overworld.resource_nodes:
            if Vector2i(int(node.x),int(node.y))==recruitment_case[2]:original_node=normalized(node)
        check(not original_node.is_empty(),str(recruitment_case[0])+" original landmark exists")
        var actions := []
        for attempt in range(8):
            if OverworldRules.hero_position(session)==scout_destination:break
            var route: Array=seal_scout_route(session,scout_destination)
            check(route.size()>1,str(recruitment_case[0])+" legal scouting route exists")
            if route.size()<2:break
            var travel: Dictionary=OverworldRules.try_move_along_route(session,route)
            actions.append({"route":route,"travel":travel})
            if OverworldRules.hero_position(session)==scout_destination:break
            var turn: Dictionary=OverworldRules.end_turn(session)
            check(bool(turn.get("ok",false)),str(recruitment_case[0])+" normal end turn while scouting")
            actions.append({"turn":turn})
        AppRouter.resume_active_session()
        await settle()
        view=get_tree().current_scene._map_view
        var node: Dictionary=view._resource_node_at(recruitment_case[2])
        check(OverworldRules.hero_position(session)==scout_destination,str(recruitment_case[0])+" reached legal scouting destination")
        check(normalized(node)==original_node,str(recruitment_case[0])+" complete guarded site preserved")
        check(OverworldRules.is_tile_visible(session,recruitment_case[2].x,recruitment_case[2].y),str(recruitment_case[0])+" original site visible through earned vision")
        check(view._resource_asset_id(node)==recruitment_case[1],str(recruitment_case[0])+" exact original resource identity")
        before=normalized(session.to_dict())
        await capture(view,recruitment_case[2],recruitment_case[1],node,"actual original guarded recruitment site after ordinary scouting; no fog, claim or placement grants")
        await save_control(session,before,"recruitment_"+str(recruitment_case[0]))
        recruitment_scouting.append({"scenario":recruitment_case[0],"day":session.day,"destination":scout_destination,"actions":actions,"site":node})
    authored["recruitment_scouting"]=recruitment_scouting
    before=normalized(session.to_dict())
    MusicAudio.stop_music''')
