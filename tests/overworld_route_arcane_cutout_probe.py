"""All 54 route/arcane paintings, actual earned map state and isolated art gallery."""
from overworld_state_cutout_probe import SCRIPT as STATE_SCRIPT

needle='specs.size()==34,"all thirty-four original state paintings"'
assert needle in STATE_SCRIPT
SCRIPT=STATE_SCRIPT.replace(needle,'specs.size()==54,"all fifty-four route and arcane paintings"')
# The source manifest intentionally has map-object ownership on base rows. Use
# the separately asserted authoritative state mapping, never inject a site id.
SCRIPT=SCRIPT.replace('spec.entry.assigned_resource_site_id','spec.site_id')
SCRIPT=SCRIPT.replace('specs[key].entry.assigned_resource_site_id','specs[key].site_id')
SCRIPT=SCRIPT.replace('str(mapping.get("unclaimed_asset_id",key))','str(mapping.get("unclaimed_asset_id",mapping.asset_id))')
needle='        check(unclaimed==expected_unclaimed,key+" current unclaimed state retained")'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,'''        if site in ["site_pactwright_waydesk","site_siltglass_index","site_greenline_lens_table","site_reedflame_votive_frame","site_ossuary_prism_choir","site_glowcap_echo_bell","site_kite_signal_countermast"]:
            check(ContentService.get_resource_site(site).get("family","")=="frontier_shrine","existing frontier-shrine mapping fallback retained")
            expected_unclaimed=mapping.asset_id
        check(unclaimed==expected_unclaimed,key+" current unclaimed state retained")''')
# This fixed earned Medium checkpoint contains none of these 54 exact states.
# Keep it as a 2380-body native control, not invented affected-play evidence.
SCRIPT=SCRIPT.replace('check(affected_native.size()>0 and captured_states.size()>0,"actual earned affected native states, not only detached coverage")',
                      'check(affected_native.is_empty() and captured_states.is_empty(),"fixed native checkpoint is an unchanged control; no affected route/arcane placements present")')
needle='    await save_control(session,before,"authored")'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,needle+r'''
    session=SessionState.set_active_session(ScenarioFactory.create_session("horizon-compact-six-citadels","normal",SessionState.LAUNCH_MODE_SKIRMISH))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal Horizon Town exit")
        await settle()
    view=get_tree().current_scene._map_view
    var wharf: Dictionary=view._resource_node_at(Vector2i(0,10))
    check(wharf.get("placement_id","")=="horizon_stormseal_powder_wharf","original Horizon wharf coordinates")
    check(view._resource_asset_id(wharf)=="mapobj_stormseal_powder_wharf","actual unclaimed original painting")
    check(OverworldRules.is_tile_visible(session,0,10),"wharf visible through ordinary starting vision")
    await capture(view,Vector2i(0,10),"mapobj_stormseal_powder_wharf",wharf,"actual starting Horizon site; ordinary town/hero vision")
    check(OverworldRules.hero_position(session)==Vector2i(2,8),"original Horizon hero start")
    var approach: Dictionary=OverworldRules.try_move_along_route(session,[Vector2i(2,8),Vector2i(1,9),Vector2i(0,10)])
    check(bool(approach.get("ok",false)),"ordinary original Horizon wharf approach: "+JSON.stringify(approach))
    AppRouter.resume_active_session()
    await settle()
    view=get_tree().current_scene._map_view
    wharf=view._resource_node_at(Vector2i(0,10))
    check(wharf.get("collected_by_faction_id","")=="player","ordinary wharf claim retains existing player-controller authority")
    check(view._resource_asset_id(wharf)=="resource_site_company_stormseal_powder_wharf_controlled","ordinary wharf claim uses distinct controlled painting")
    await capture(view,Vector2i(0,10),"resource_site_company_stormseal_powder_wharf_controlled",wharf,"actual ordinary Horizon claim, no direct ownership mutation")
    before=normalized(session.to_dict())
    await save_control(session,before,"horizon")
''')

# A deterministic ordinary scouting route, not fog/ownership/placement grants.
# The seven frontier-shrine identities already select their state painting before
# collection. Preserve that content rule and show actual still-guarded sites.
SCRIPT=SCRIPT.replace('func run() -> void:',r'''
func seal_scout_route(session, destination: Vector2i) -> Array:
    var start: Vector2i=OverworldRules.hero_position(session)
    var queue: Array=[start]
    var parents: Dictionary={start:start}
    var size: Vector2i=OverworldRules.derive_map_size(session)
    while not queue.is_empty():
        var current: Vector2i=queue.pop_front()
        if current==destination:
            var path: Array=[current]
            while current!=start:
                current=parents[current]
                path.push_front(current)
            return path
        for dy in range(-1,2):
            for dx in range(-1,2):
                var next: Vector2i=current+Vector2i(dx,dy)
                if parents.has(next) or next.x<0 or next.y<0 or next.x>=size.x or next.y>=size.y:continue
                if OverworldRules._tile_blocks_route_step(session,next,next==destination):continue
                if OverworldRules.tile_step_cuts_blocked_corner(session,current,next):continue
                if next!=destination and OverworldRules.tile_has_route_interaction(session,next.x,next.y):continue
                if int(OverworldRules._find_guard_engagement_at_tile(session,next.x,next.y).get("index",-1))>=0:continue
                parents[next]=current
                queue.append(next)
    return []

func run() -> void:''')
needle='    before=normalized(session.to_dict())\n    MusicAudio.stop_music'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,r'''
    var seal_cases := [
        ["tollglass-relief-run","resource_site_pactwright_waydesk_witnessed",Vector2i(8,5),Vector2i(5,5)],
        ["mudkeel-hive-foreclosure","resource_site_siltglass_index_countersealed",Vector2i(8,5),Vector2i(5,5)],
        ["lenscaptain-greenline-survey","resource_site_greenline_lens_table_countersealed",Vector2i(8,5),Vector2i(5,5)],
        ["votivejaw-reedflame-vigil","resource_site_reedflame_votive_frame_countersealed",Vector2i(8,5),Vector2i(5,5)],
        ["glassmarshal-ossuary-battery","resource_site_ossuary_prism_choir_countersealed",Vector2i(8,5),Vector2i(5,5)],
        ["rotlamp-glowcap-refrain","resource_site_glowcap_echo_bell_countersealed",Vector2i(10,4),Vector2i(9,6)],
        ["daynote-kite-signal-accord","resource_site_kite_signal_countermast_countersealed",Vector2i(10,4),Vector2i(9,6)]
    ]
    for seal_case in seal_cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(seal_case[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        AppRouter.resume_active_session()
        await settle()
        if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
            check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary state-site Town exit")
            await settle()
        var original_site: Dictionary={}
        for candidate in session.overworld.resource_nodes:
            if Vector2i(int(candidate.x),int(candidate.y))==seal_case[2]:original_site=normalized(candidate)
        check(not original_site.is_empty(),str(seal_case[0])+" actual authored placement exists")
        var approach_tiles: Array=seal_scout_route(session,seal_case[3])
        check(approach_tiles.size()>1,str(seal_case[0])+" safe ordinary scouting route exists")
        if approach_tiles.size()>1:
            var scout: Dictionary=OverworldRules.try_move_along_route(session,approach_tiles)
            check(bool(scout.get("ok",false)),str(seal_case[0])+" ordinary scouting: "+JSON.stringify(scout))
            check(OverworldRules.hero_position(session)==seal_case[3],str(seal_case[0])+" complete legal scouting route")
            if seal_case[2]==Vector2i(10,4):
                # Manhattan vision radius is three. This original artifact
                # tile is the safe approach; use its ordinary pickup, not a
                # fog grant or bypass of the adjacent site guard.
                var pickup_found := false
                for artifact in session.overworld.artifact_nodes:
                    if Vector2i(int(artifact.x),int(artifact.y))==seal_case[3]:
                        pickup_found=bool(artifact.get("collected",false))
                check(pickup_found,str(seal_case[0])+" ordinary original artifact pickup during approach")
        AppRouter.resume_active_session()
        await settle()
        view=get_tree().current_scene._map_view
        var seal_node: Dictionary=view._resource_node_at(seal_case[2])
        check(normalized(seal_node)==original_site,str(seal_case[0])+" scouting preserves complete site state")
        check(OverworldRules.is_tile_visible(session,seal_case[2].x,seal_case[2].y),str(seal_case[0])+" site visible through ordinary hero vision")
        check(view._resource_asset_id(seal_node)==seal_case[1],str(seal_case[0])+" actual state route unchanged")
        before=normalized(session.to_dict())
        await capture(view,seal_case[2],seal_case[1],seal_node,"original guarded frontier shrine after ordinary scouting, not a synthetic claim")
        await save_control(session,before,"seal_"+str(seal_case[0]))
    before=normalized(session.to_dict())
    MusicAudio.stop_music''')
