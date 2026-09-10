"""54 site paintings, actual ordinary scouting/claims and complete saved states."""
from overworld_state_cutout_probe import SCRIPT as STATE_SCRIPT
from overworld_remaining_encounter_cutout_probe import SCRIPT as SCOUT_SCRIPT

SCRIPT=STATE_SCRIPT.replace('specs.size()==34,"all thirty-four original state paintings"','specs.size()==54,"all fifty-four original resource-site paintings"')
# Separate evidence filenames from the exact authoritative asset identity.
SCRIPT=SCRIPT.replace('placement: Dictionary, category: String) -> void:',
                      'placement: Dictionary, category: String, screenshot_id: String = "") -> void:\n    if screenshot_id=="":screenshot_id=asset_id')
SCRIPT=SCRIPT.replace('captured.has(asset_id)', 'captured.has(screenshot_id)').replace('captured[asset_id]=true','captured[screenshot_id]=true')
SCRIPT=SCRIPT.replace('out.path_join(asset_id+".png")','out.path_join(screenshot_id+".png")')
SCRIPT=SCRIPT.replace('captures.append({"asset_id":asset_id,','captures.append({"asset_id":asset_id,"screenshot_id":screenshot_id,')
SCRIPT=SCRIPT.replace('check(affected_native.size()>0 and captured_states.size()>0,"actual earned affected native states, not only detached coverage")',
                      'check(affected_native.is_empty() and captured_states.is_empty(),"fixed earned native save has no selected site records; unchanged control only")')
SCRIPT=SCRIPT.replace('label.text=str(specs[key].entry.assigned_resource_site_id).trim_prefix("site_")',
'''label.text=str(specs[key].entry.assigned_resource_site_id).trim_prefix("site_").replace("_"," ")
            label.size=Vector2(cell.x-12,30)
            label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART''')
helpers='func seal_scout_route('+SCOUT_SCRIPT.split('func seal_scout_route(',1)[1].split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('func run() -> void:',helpers+r'''
func site_overworld() -> void:
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary site Town exit")
        await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"normal site Overworld entry")

func run() -> void:''')
needle='    before=normalized(session.to_dict())\n    MusicAudio.stop_music'
assert SCRIPT.count(needle)==1
SCRIPT=SCRIPT.replace(needle,r'''
    var site_cases := [
        ["lockfire-upper-circle-trial","lockfiretrial_academy","resource_site_triune_arcanum_lockfire_rostrum",Vector2i(7,3),true],
        ["rainwrit-stormseal-charter-race","rainwritworks_survey","resource_site_great_work_rainwrit_survey_cairn",Vector2i(10,4),false],
        ["rainwrit-five-writ-grand-muster","rainwritmuster_standard","resource_site_grand_muster_rainwrit_standard",Vector2i(10,4),false],
        ["tollbrand-locklantern-relief-run","locklantern_relay","resource_site_relief_route_embercourt_relay",Vector2i(1,4),true],
        ["cinderquill-ashline-fogbreak-survey","ashline_survey_west","resource_site_fogbreak_embercourt_compass",Vector2i(2,1),false],
        ["powderwrit-rainwrit-treasury-commission","rainledger_treasury_west","resource_site_frontier_treasury_embercourt_brazier",Vector2i(2,1),false],
        ["cinderquill-lockward-charter-assembly","lockwardassembly_reliquary","resource_site_regalia_lockward_charter_reliquary",Vector2i(11,4),false],
        ["beaconscribe-dawnwrit-convocation","dawnwrit_academy","resource_site_grand_arcanum_dawnwrit_column",Vector2i(14,8),false],
        ["powderwrit-cinderlock-charter-ascent","cinderlock_throne","resource_site_uncrowned_cinderlock_throne",Vector2i(16,8),false]
    ]
    var scouting := []
    for item in site_cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(item[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        await site_overworld()
        var original_node := {}
        for node in session.overworld.resource_nodes:
            if node.get("placement_id","")==item[1]:original_node=normalized(node)
        check(not original_node.is_empty(),str(item[1])+" original site exists")
        check(Vector2i(int(original_node.get("x",-1)),int(original_node.get("y",-1)))==item[3],str(item[1])+" original coordinates")
        var actions := []
        for attempt in range(8):
            if OverworldRules.is_tile_visible(session,item[3].x,item[3].y):break
            var route: Array=legal_scout_route(session,item[3])
            check(route.size()>1,str(item[1])+" legal ordinary scouting route")
            if route.size()<2:break
            var travel: Dictionary=OverworldRules.try_move_along_route(session,route)
            check(bool(travel.get("ok",false)),str(item[1])+" ordinary scouting move")
            actions.append({"route":route,"travel":travel})
            if OverworldRules.is_tile_visible(session,item[3].x,item[3].y):break
            var turn: Dictionary=OverworldRules.end_turn(session)
            check(bool(turn.get("ok",false)),str(item[1])+" ordinary end turn")
            actions.append({"turn":turn})
        await site_overworld()
        view=get_tree().current_scene._map_view
        var current_node: Dictionary=view._resource_node_at(item[3])
        check(normalized(current_node)==original_node,str(item[1])+" full original site and guard preserved")
        check(OverworldRules.is_tile_visible(session,item[3].x,item[3].y),str(item[1])+" actual earned vision")
        check(view._resource_asset_id(current_node)==item[2],str(item[1])+" exact selected site identity")
        before=normalized(session.to_dict())
        await capture(view,item[3],item[2],current_node,"original resource site after ordinary scouting; no state or fog grants")
        await save_control(session,before,"scout_"+str(item[1]))
        session=SessionState.active_session
        if item[4]:
            if OverworldRules.hero_position(session)==item[3]:
                await site_overworld()
                var claim: Dictionary=get_tree().current_scene.validation_perform_primary_action()
                check(bool(claim.get("ok",false)),str(item[1])+" ordinary current-tile primary action")
                actions.append({"claim":claim})
            else:
                var route: Array=seal_scout_route(session,item[3])
                check(route.size()>1,str(item[1])+" ordinary claim route exists")
                if route.size()>1:
                    var claim: Dictionary=OverworldRules.try_move_along_route(session,route)
                    check(bool(claim.get("ok",false)),str(item[1])+" ordinary site claim move")
                    actions.append({"claim":claim})
            await site_overworld()
            view=get_tree().current_scene._map_view
            var claimed := {}
            for node in session.overworld.resource_nodes:
                if node.get("placement_id","")==item[1]:claimed=normalized(node)
            check(claimed.get("collected_by_faction_id","")!="",str(item[1])+" original site claimed through ordinary action")
            check(view._resource_asset_id(claimed)==item[2],str(item[1])+" claimed site retains original painting")
            before=normalized(session.to_dict())
            if item[1]=="lockfiretrial_academy":
                # A one-use shrine is consumed under the original gameplay rule.
                # Its retained save record is not an extra visible placement.
                check(bool(claimed.get("collected",false)) and not OverworldRules.resource_node_is_present(claimed),"ordinary Triune claim consumes original one-use shrine")
                check(view._resource_node_at(item[3]).is_empty(),"consumed Triune shrine remains absent under unchanged presentation rule")
                view.focus_on_tile(item[3])
                await settle()
                check(item[2] not in view.validation_tile_presentation(item[3]).get("art_presentation",{}).get("sprite_asset_ids",[]),"no ghost Triune painting after consumption")
                if DisplayServer.get_name()!="headless":
                    await RenderingServer.frame_post_draw
                    get_viewport().get_texture().get_image().save_png(out.path_join("consumed_triune_shrine.png"))
            else:
                check(OverworldRules.resource_node_is_present(claimed) and normalized(view._resource_node_at(item[3]))==claimed,"original persistent relay remains present after claim")
                await capture(view,item[3],item[2],claimed,"actual claimed original site; unchanged state route",str(item[2])+"_claimed")
            await save_control(session,before,"claim_"+str(item[1]))
        scouting.append({"scenario":item[0],"placement":original_node,"day":session.day,"actions":actions})
    authored["remaining_site_scouting"]=scouting
    before=normalized(session.to_dict())
    MusicAudio.stop_music''')
