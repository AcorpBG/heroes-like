"""52 encounter paintings; nine original fronts reached by ordinary scouting."""
from overworld_recurring_cutout_probe import SCRIPT as ENCOUNTER_SCRIPT
from overworld_route_arcane_cutout_probe import SCRIPT as ROUTE_SCRIPT

SCRIPT=ENCOUNTER_SCRIPT.replace('specs.size()==31,"all thirty-one source-recovered encounters"',
                               'specs.size()==52,"all fifty-two source-recovered contract encounters"')
SCRIPT=SCRIPT.replace('asset_id.begins_with("encounter_recurring_")','asset_id.begins_with("encounter_")')
SCRIPT=SCRIPT.replace('label.text=key.trim_prefix("encounter_recurring_")',
                      'label.text=key.trim_prefix("encounter_").split("_",true,1)[1].replace("_"," ")\n            label.size=Vector2(cell.x-12,30)\n            label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART')
# These eleven earned native fronts are already cleared. Assert the actual
# draw index suppresses them, not manufacture unresolved gameplay screenshots.
needle='    check(native_bodies>0 and captures.size()==1,"actual native control; no placement/fog injection")'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,r'''
    check(affected_native.size()==11,"eleven exact affected native records retained")
    for item in affected_native:
        check(bool(item.resolved),"earned native encounter remains resolved")
        var original_tile:=Vector2i(int(item.placement.x),int(item.placement.y))
        check(view._encounter_node_at(original_tile).is_empty(),"actual draw index does not resurrect cleared native encounters")
    '''+needle.strip())
scout=ROUTE_SCRIPT.split('func seal_scout_route(',1)[1].split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('func run() -> void:','func seal_scout_route('+scout+'func run() -> void:')
needle='    before=normalized(session.to_dict())\n    MusicAudio.stop_music'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,r'''
    var contract_cases := [
        ["causeway-stand","causeway_lockflame_turncoats","encounter_dissident_lockflame_turncoats",Vector2i(2,4),Vector2i(0,3)],
        ["tollglass-relief-run","tollglass_drowned_tally","encounter_contract_tollglass_drowned_tally",Vector2i(8,4),Vector2i(6,5)],
        ["pitmarshal-peat-chain-seizure","pitmarshal_peat_chain_levy","encounter_outer_reach_peat_chain_tally_pit",Vector2i(8,4),Vector2i(5,5)],
        ["mudkeel-hive-foreclosure","mudkeel_hive_foreclosure","encounter_mire_sun_hive_chain_foreclosure",Vector2i(8,4),Vector2i(6,5)],
        ["tollbrand-blackwake-levy","tollbrand_blackwake_levy","encounter_ascendant_blackwake_obituary_mooring",Vector2i(8,4),Vector2i(5,5)],
        ["lockmaster-cinder-kiln","lockmaster_cinder_kiln_watch","encounter_waywatch_cinder_kiln_watch",Vector2i(8,4),Vector2i(6,5)],
        ["cinderquill-fenhound-lexicon","cinderquill_fenhound_kennel_watch","encounter_spellwright_fenhound_kennel_watch",Vector2i(9,4),Vector2i(6,4)],
        ["reedscript-reedbarge-circuit","reedscript_reedbarge_mooring_watch","encounter_ritual_relay_reedbarge_mooring_watch",Vector2i(9,5),Vector2i(6,5)],
        ["rainledger-cinder-convergence","rainledger_charcoal_burners_watch","encounter_grand_convergence_charcoal_burners_watch",Vector2i(10,5),Vector2i(7,5)]
    ]
    var contract_scouting := []
    for contract_case in contract_cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(contract_case[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        AppRouter.resume_active_session()
        await settle()
        if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
            check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary contract Town exit")
            await settle()
        var original_encounter := {}
        for encounter in session.overworld.encounters:
            if encounter.get("placement_id","")==contract_case[1]:original_encounter=normalized(encounter)
        check(not original_encounter.is_empty(),str(contract_case[0])+" original encounter exists")
        var actions := []
        for attempt in range(8):
            if OverworldRules.hero_position(session)==contract_case[4]:break
            var route: Array=seal_scout_route(session,contract_case[4])
            check(route.size()>1,str(contract_case[0])+" legal scouting route exists")
            if route.size()<2:break
            var travel: Dictionary=OverworldRules.try_move_along_route(session,route)
            actions.append({"route":route,"travel":travel})
            if OverworldRules.hero_position(session)==contract_case[4]:break
            var turn: Dictionary=OverworldRules.end_turn(session)
            check(bool(turn.get("ok",false)),str(contract_case[0])+" normal end turn while scouting")
            actions.append({"turn":turn})
        AppRouter.resume_active_session()
        await settle()
        view=get_tree().current_scene._map_view
        var current_encounter := {}
        for encounter in session.overworld.encounters:
            if encounter.get("placement_id","")==contract_case[1]:current_encounter=encounter
        check(OverworldRules.hero_position(session)==contract_case[4],str(contract_case[0])+" reached legal scouting destination")
        check(normalized(current_encounter)==original_encounter,str(contract_case[0])+" complete original encounter record preserved")
        check(Vector2i(int(current_encounter.get("x",-1)),int(current_encounter.get("y",-1)))==contract_case[3],str(contract_case[0])+" exact original coordinates")
        check(not OverworldRules.is_encounter_resolved(session,current_encounter),str(contract_case[0])+" original front remains unresolved")
        check(OverworldRules.is_tile_visible(session,contract_case[3].x,contract_case[3].y),str(contract_case[0])+" original front visible through earned vision")
        check(view._encounter_identity_asset_id(current_encounter)==contract_case[2],str(contract_case[0])+" exact original encounter identity")
        before=normalized(session.to_dict())
        await capture(view,contract_case[3],contract_case[2],current_encounter,"actual original encounter after ordinary scouting; unchanged commander priority, fog and placement")
        await save_control(session,before,"contract_"+str(contract_case[0]))
        contract_scouting.append({"scenario":contract_case[0],"day":session.day,"actions":actions,"encounter":normalized(current_encounter)})
    authored["contract_scouting"]=contract_scouting
    before=normalized(session.to_dict())
    MusicAudio.stop_music''')
