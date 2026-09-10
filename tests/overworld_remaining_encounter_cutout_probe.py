"""79 encounter recoveries, six unchanged controls and ordinary authored scouts."""
from overworld_recurring_cutout_probe import SCRIPT as ENCOUNTER_SCRIPT
from overworld_route_arcane_cutout_probe import SCRIPT as ROUTE_SCRIPT

SCRIPT=ENCOUNTER_SCRIPT.replace('specs.size()==31,"all thirty-one source-recovered encounters"','specs.size()==85,"79 source recoveries and six clean faction controls"')
SCRIPT=SCRIPT.replace('asset_id.begins_with("encounter_recurring_")','asset_id.begins_with("encounter_")')
SCRIPT=SCRIPT.replace('label.text=key.trim_prefix("encounter_recurring_")','label.text=key.trim_prefix("encounter_").replace("_"," ")\n            label.size=Vector2(cell.x-12,30)\n            label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART')
SCRIPT=SCRIPT.replace('''        var input := {"encounter_id":spec.entry.assigned_encounter_id}
        check(view._encounter_identity_asset_id(input)==key,key+" exact identity resolver; detached input")''','''        if spec.mode=="preserved_faction":
            var input := {"faction_id":spec.entry.assigned_faction_id}
            check(view._encounter_faction_asset_id(input)==key,key+" unchanged faction route; detached input")
        else:
            var input := {"encounter_id":spec.entry.assigned_encounter_id}
            check(view._encounter_identity_asset_id(input)==key,key+" exact identity route; detached input")''')
SCRIPT=SCRIPT.replace('check(texture is AtlasTexture,key+" authoritative atlas")\n        if not texture is AtlasTexture:continue','check(texture is Texture2D,key+" authoritative raster")\n        if not texture is Texture2D:continue')
SCRIPT=SCRIPT.replace('        check(view._object_asset_regions.get(key,[])==spec.atlas_region,key+" exact high-resolution region")','''        if spec.has("atlas_region"):
            check(texture is AtlasTexture,key+" authoritative atlas")
            check(view._object_asset_regions.get(key,[])==spec.atlas_region,key+" exact high-resolution region")
        else:
            check(not texture is AtlasTexture,key+" unchanged standalone texture route")''')
SCRIPT=SCRIPT.replace('raster.get_size()==Vector2i(192,192)','raster.get_size()==Vector2i(int(spec.size[0]),int(spec.size[1]))')
scout=ROUTE_SCRIPT.split('func seal_scout_route(',1)[1].split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('func run() -> void:','func seal_scout_route('+scout+r'''
func legal_scout_route(session, target: Vector2i) -> Array:
    var best := []
    for dy in range(-2,3):
        for dx in range(-2,3):
            if (dx==0 and dy==0) or absi(dx)+absi(dy)>3:continue
            var destination := target+Vector2i(dx,dy)
            if OverworldRules.tile_has_route_interaction(session,destination.x,destination.y):continue
            var route: Array=seal_scout_route(session,destination)
            if route.size()>1 and (best.is_empty() or route.size()<best.size()):best=route
    return best

func run() -> void:''')
needle='    before=normalized(session.to_dict())\n    MusicAudio.stop_music'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,r'''
    var remaining_cases := [
        ["river-pass","river_pass_reed_totemists","encounter_signature_reed_totemists",Vector2i(4,0)],
        ["bramblehound-worldroot-veteran-muster","fivebough_west_company","encounter_finale_nemesis_debtrune_lastbell_ledger",Vector2i(3,2)],
        ["thorncart-daybreak-tangle","thorncart_front_2","encounter_rival_commander_daynote_refraction_bench",Vector2i(6,4)],
        ["horizon-compact-six-citadels","horizon_rainwrit_gate","encounter_horizon_rainwrit_charter_gate",Vector2i(3,8)],
        ["horizon-compact-six-citadels","horizon_lockglass_citation_field","encounter_dormant_roster_lockglass_citation_field",Vector2i(12,12)],
        ["hollowreed-noonwire-dispute","hollowreed_court_front_2","encounter_horizon_court_meridian_noonwire_tribunal",Vector2i(6,4)],
        ["chainboom-graftwake-cordon","chainboom_watch_contract","encounter_frontier_watch_briarwheel_witness",Vector2i(8,4)],
        ["powderwrit-fogchain-commission","powderwrit_commission","encounter_commission_powderwrit_fogchain_gate",Vector2i(8,4)],
        ["powderwrit-two-lock-vigil","powdervigil_primary_front","encounter_defense_gloamchain_sluice_ram",Vector2i(8,4)],
        ["lockfire-three-seal-pilgrimage","lockfirepilgrim_guardian_1","encounter_relic_lockfire_assize_reliquary",Vector2i(6,1)],
        ["votivejaw-bogglass-fogbreak-survey","bogglass_west_guard","encounter_systemic_blackbranch_reavers",Vector2i(2,2)],
        ["tollbrand-cinderlock-border-oath-seizure","threewrit_west_cordon","encounter_border_oath_mireclaw_moonhook",Vector2i(2,2)]
    ]
    var remaining_scouting := []
    for scout_case in remaining_cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(scout_case[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        AppRouter.resume_active_session()
        await settle()
        if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
            check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal authored Town exit")
            await settle()
        var original_encounter := {}
        for encounter in session.overworld.encounters:
            if encounter.get("placement_id","")==scout_case[1]:original_encounter=normalized(encounter)
        check(not original_encounter.is_empty(),str(scout_case[1])+" original encounter exists")
        var actions := []
        for attempt in range(8):
            if OverworldRules.is_tile_visible(session,scout_case[3].x,scout_case[3].y):break
            var route: Array=legal_scout_route(session,scout_case[3])
            check(route.size()>1,str(scout_case[1])+" legal scouting route exists")
            if route.size()<2:break
            var travel: Dictionary=OverworldRules.try_move_along_route(session,route)
            actions.append({"route":route,"travel":travel})
            if OverworldRules.is_tile_visible(session,scout_case[3].x,scout_case[3].y):break
            var turn: Dictionary=OverworldRules.end_turn(session)
            check(bool(turn.get("ok",false)),str(scout_case[1])+" ordinary scouting end turn")
            actions.append({"turn":turn})
        AppRouter.resume_active_session()
        await settle()
        view=get_tree().current_scene._map_view
        var current_encounter := {}
        for encounter in session.overworld.encounters:
            if encounter.get("placement_id","")==scout_case[1]:current_encounter=encounter
        check(normalized(current_encounter)==original_encounter,str(scout_case[1])+" full original encounter preserved")
        check(Vector2i(int(current_encounter.get("x",-1)),int(current_encounter.get("y",-1)))==scout_case[3],str(scout_case[1])+" exact original coordinates")
        check(not OverworldRules.is_encounter_resolved(session,current_encounter),str(scout_case[1])+" original front unresolved")
        check(OverworldRules.is_tile_visible(session,scout_case[3].x,scout_case[3].y),str(scout_case[1])+" front visible through ordinary vision")
        check(view._encounter_identity_asset_id(current_encounter)==scout_case[2],str(scout_case[1])+" exact original identity")
        before=normalized(session.to_dict())
        await capture(view,scout_case[3],scout_case[2],current_encounter,"actual original encounter; ordinary scouting and unchanged priority")
        await save_control(session,before,"remaining_"+str(scout_case[1]))
        remaining_scouting.append({"scenario":scout_case[0],"day":session.day,"actions":actions,"encounter":normalized(current_encounter)})
    authored["remaining_scouting"]=remaining_scouting
    before=normalized(session.to_dict())
    MusicAudio.stop_music''')
