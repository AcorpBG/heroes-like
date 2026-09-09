"""All claimed originals through existing source/package, state and save probe.

Detached galleries exercise every original painting; earned native placements
are captured only when the current normal state resolver actually selects one.
The unchanged Prismhearth relay is a gameplay/save control, not claimed coverage.
"""
from overworld_recurring_site_cutout_probe import SCRIPT as SITE_SCRIPT

SCRIPT=SITE_SCRIPT.replace('specs.size()==30,"all thirty original site paintings"',
                           'specs.size()==31,"all thirty-one claimed original paintings"')

# A real authored enemy-controlled dwelling, observed through ordinary scouting.
# Never inject a placement, defeated guard, owner, hero position or fog visibility.
SCOUT=r'''
    session=SessionState.set_active_session(ScenarioFactory.create_session("ninefold-confluence","normal",SessionState.LAUNCH_MODE_SKIRMISH))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal Ninefold Town exit")
        await settle()
    var selection: Dictionary=get_tree().current_scene.validation_select_tile(18,19)
    var scouting: Dictionary=get_tree().current_scene.validation_perform_primary_action()
    scouting["selected_route"]=selection.get("selected_route_preview",{})
    check(bool(scouting.get("ok",false)),"ordinary Ninefold scouting: "+JSON.stringify(scouting))
    AppRouter.resume_active_session()
    await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"scouting remains on Overworld")
    var observed := false
    if get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"):
        view=get_tree().current_scene._map_view
        before=normalized(session.to_dict())
        for node in session.overworld.get("resource_nodes",[]):
            if node.get("placement_id","")!="dwelling_bramble_hedge":continue
            var tile:=Vector2i(int(node.x),int(node.y))
            var key: String=view._resource_asset_id(node)
            check(tile==Vector2i(16,18) and node.get("collected_by_faction_id","")=="faction_thornwake","original Bramble ownership and coordinates")
            check(key=="resource_site_neutral_bramble_hedge_claimed","actual controlled-state painting")
            observed=OverworldRules.is_tile_visible(session,tile.x,tile.y)
            if observed:await capture(view,tile,key,node,"actual authored Bramble Hedge after normal scouting; enemy ownership unchanged")
        check(observed,"original claimed Bramble visible through ordinary scouting")
        authored["ninefold_scouting"]=scouting
        await save_control(session,before,"ninefold")
'''
SCRIPT=SCRIPT.replace('    before=normalized(session.to_dict())\n    MusicAudio.stop_music',SCOUT+'    before=normalized(session.to_dict())\n    MusicAudio.stop_music')
