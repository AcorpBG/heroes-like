"""36 recruitment paintings; ordinary scouting to eight original landmarks."""
from overworld_state_cutout_probe import SCRIPT as STATE_SCRIPT
from overworld_route_arcane_cutout_probe import SCRIPT as ROUTE_SCRIPT

SCRIPT=STATE_SCRIPT.replace('specs.size()==34,"all thirty-four original state paintings"','specs.size()==36,"all thirty-six recruitment paintings"')
SCRIPT=SCRIPT.replace('spec.entry.assigned_resource_site_id','spec.site_id').replace('specs[key].entry.assigned_resource_site_id','specs[key].site_id')
SCRIPT=SCRIPT.replace('check(affected_native.size()>0 and captured_states.size()>0,"actual earned affected native states, not only detached coverage")',
                      'check(affected_native.is_empty() and captured_states.is_empty(),"fixed earned native checkpoint contains no recruitment-site records; unchanged control only")')
scout=ROUTE_SCRIPT.split('func seal_scout_route(',1)[1].split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('func run() -> void:','func seal_scout_route('+scout+'func run() -> void:')
# A guard may be the explicit final action, never an intermediate scouting tile.
SCRIPT=SCRIPT.replace('if int(OverworldRules._find_guard_engagement_at_tile(session,next.x,next.y).get("index",-1))>=0:continue',
                      'if next!=destination and int(OverworldRules._find_guard_engagement_at_tile(session,next.x,next.y).get("index",-1))>=0:continue')
SCRIPT=SCRIPT.replace('func run() -> void:',r'''
var mast_battle_actions := []
func mast_settle() -> void:
    await settle()
    var started:=Time.get_ticks_msec()
    while true:
        var scene=get_tree().current_scene
        if scene!=null and not (scene.scene_file_path.ends_with("BattleShell.tscn") and scene._battle_exit_handoff_in_progress):return
        if Time.get_ticks_msec()-started>30000:
            check(false,"mast battle exit handoff timeout")
            return
        await get_tree().process_frame

func mast_resolve_routes() -> bool:
    await mast_settle()
    for attempt in range(6):
        var scene=get_tree().current_scene
        if scene.scene_file_path.ends_with("BattleShell.tscn"):
            var request: Dictionary=scene.validation_request_quick_resolve_confirmation()
            await settle()
            var result: Dictionary=scene.validation_confirm_quick_resolve_confirmation()
            check(request.get("ok",false) and result.get("performed",false),"ordinary veteran guard Quick Resolve")
            mast_battle_actions.append({"request_ok":request.get("ok",false),"performed":result.get("performed",false),"terminal_result":result.get("terminal_result",{})})
            await mast_settle()
        elif scene.scene_file_path.ends_with("BattleReportShell.tscn"):
            scene.get_node("%Continue").pressed.emit()
            check(scene._last_continue_result.get("ok",false),"veteran guard casualty acknowledgement and save")
            await mast_settle()
        else:
            return scene.scene_file_path.ends_with("OverworldShell.tscn")
    check(false,"veteran battle report routing did not finish")
    return false

func run() -> void:''')
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
    var mast_claims := []
    for mast_case in [
        ["pitmarshal-foundry-veteran-muster","threegauge_muster_guard","resource_site_veteran_three_gauge_chapter_foundry_controlled"],
        ["keelwarden-fogkeel-veteran-muster","fogkeel_muster_guard","resource_site_veteran_fog_keel_lastwatch_mooring_controlled"]
    ]:
        session=SessionState.set_active_session(ScenarioFactory.create_session(mast_case[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        AppRouter.resume_active_session()
        await settle()
        if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
            check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary veteran Town exit")
            await settle()
        var mast_actions := []
        var overworld_available := true
        for destination in [Vector2i(12,2),Vector2i(12,1)]:
            if not overworld_available:break
            for attempt in range(12):
                var guard_finished := false
                for encounter in session.overworld.encounters:
                    if encounter.get("placement_id","")==mast_case[1]:guard_finished=OverworldRules.is_encounter_resolved(session,encounter)
                var site_owned := false
                for site in session.overworld.resource_nodes:
                    if Vector2i(int(site.x),int(site.y))==Vector2i(12,1):site_owned=site.get("collected_by_faction_id","")=="player"
                if (destination==Vector2i(12,2) and guard_finished) or (destination==Vector2i(12,1) and site_owned):break
                var path: Array=seal_scout_route(session,destination)
                check(path.size()>1,str(mast_case[0])+" ordinary guard/claim route exists")
                if path.size()<2:break
                var movement: Dictionary=OverworldRules.try_move_along_route(session,path)
                mast_actions.append({"destination":destination,"route":path,"movement":movement})
                AppRouter.resume_active_session()
                await settle()
                overworld_available=await mast_resolve_routes()
                if not overworld_available:break
                if int(session.overworld.get("movement",{}).get("current",0))<=0:
                    var turn: Dictionary=OverworldRules.end_turn(session)
                    check(turn.get("ok",false),"ordinary veteran end turn")
                    mast_actions.append({"turn":turn})
                    AppRouter.resume_active_session()
                    await settle()
        if not get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"):
            # The direct Foundry starter-army assault is not an earned claim.
            # Retain its genuine loss and complete save, never zero enemy health
            # or substitute the controlled fixture for gameplay evidence.
            check(mast_case[0]=="pitmarshal-foundry-veteran-muster" and session.scenario_status=="defeat" and get_tree().current_scene.scene_file_path.ends_with("ScenarioOutcomeShell.tscn"),
                  "original Foundry starter assault reaches a real defeat, not a claimed-art capture: "+str(session.scenario_status)+" / "+get_tree().current_scene.scene_file_path)
            before=normalized(session.to_dict())
            await save_control(session,before,"mast_"+str(mast_case[0]))
            mast_claims.append({"scenario":mast_case[0],"day":session.day,"actions":mast_actions,"status":session.scenario_status,"art_capture":false})
            continue
        # Leave the claimed site by ordinary movement so the hero does not
        # obscure the repaired mast. Stay within the existing vision radius.
        for attempt in range(4):
            if OverworldRules.hero_position(session)==Vector2i(9,1):break
            var retreat: Array=seal_scout_route(session,Vector2i(9,1))
            check(retreat.size()>1,"legal veteran post-claim observation route")
            if retreat.size()<2:break
            mast_actions.append({"post_claim_route":retreat,"movement":OverworldRules.try_move_along_route(session,retreat)})
            if OverworldRules.hero_position(session)!=Vector2i(9,1):
                var turn: Dictionary=OverworldRules.end_turn(session)
                check(turn.get("ok",false),"ordinary post-claim scouting turn")
                mast_actions.append({"turn":turn})
        AppRouter.resume_active_session()
        await settle()
        view=get_tree().current_scene._map_view
        var mast_site: Dictionary=view._resource_node_at(Vector2i(12,1))
        check(OverworldRules.hero_position(session)==Vector2i(9,1),"hero leaves mast visible after legal scouting")
        check(OverworldRules.is_tile_visible(session,12,1),"claimed mast remains visible through earned vision")
        check(mast_site.get("collected_by_faction_id","")=="player",str(mast_case[0])+" earned controlled state after original guard battle")
        check(view._resource_asset_id(mast_site)==mast_case[2],str(mast_case[0])+" exact restored mast state")
        await capture(view,Vector2i(12,1),mast_case[2],mast_site,"actual ordinary guard battle and claim; original army, movement, fog, costs and casualty report")
        before=normalized(session.to_dict())
        await save_control(session,before,"mast_"+str(mast_case[0]))
        mast_claims.append({"scenario":mast_case[0],"day":session.day,"actions":mast_actions,"site":mast_site})
    authored["mast_claims"]=mast_claims
    authored["mast_battle_actions"]=mast_battle_actions
    before=normalized(session.to_dict())
    MusicAudio.stop_music''')
