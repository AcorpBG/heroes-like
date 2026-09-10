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
