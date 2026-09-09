"""Original recurring sites, unchanged state routes, actual earned gameplay."""
from overworld_legacy_cutout_probe import SCRIPT as LEGACY_SCRIPT

SCRIPT=LEGACY_SCRIPT.split('func run() -> void:',1)[0].replace(
    'label.text=key.trim_prefix("resource_site_neutral_").trim_prefix("hero_faction_").trim_prefix("generated_tree_")',
    'label.text=str(specs[key].entry.assigned_resource_site_id).trim_prefix("site_")')+r'''
func run() -> void:
    get_tree().current_scene=null
    out=OS.get_environment("CUTOUT_OUTPUT")
    var bytes := FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"complete independent expectations unchanged")
    var specs: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
    check(specs.size()==30,"all thirty original site paintings")
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session=SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal earned Town exit")
        await settle()
    check(int(session.day)==97,"unchanged earned Medium Day97")
    var before: Dictionary=normalized(session.to_dict())
    var view=get_tree().current_scene._map_view
    var textures := {}
    var routes := {}
    for key in specs:
        var spec: Dictionary=specs[key]
        var site: String=spec.entry.assigned_resource_site_id
        var mapping: Dictionary=spec.state_mapping
        check(view._resource_site_asset_ids.get(site,"")==mapping.asset_id,key+" registered current state mapping")
        var claimed: String=view._resource_asset_id({"site_id":site,"kind":"resource_site","collected_by_faction_id":"faction_embercourt"})
        var unclaimed: String=view._resource_asset_id({"site_id":site,"kind":"resource_site"})
        check(claimed==mapping.asset_id,key+" current claimed state is not rerouted to legacy art")
        var expected_unclaimed: String="mapobj_greenbranch_copse" if site=="site_greenbranch_copse" else str(mapping.get("unclaimed_asset_id",key))
        check(unclaimed==expected_unclaimed,key+" current unclaimed state retained")
        check(view._standalone_map_object_asset_id({"overworld_sprite_asset_id":key})==key,key+" explicit manifest identity available; detached input")
        var texture=view._object_texture_for_asset(key)
        check(texture is AtlasTexture,key+" authoritative atlas, no fallback")
        if not texture is AtlasTexture:continue
        check(view._object_asset_paths.get(key,"")==spec.path,key+" original path")
        check(view._object_asset_regions.get(key,[])==spec.atlas_region,key+" exact high-resolution region")
        var raster: Image=texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,key+" decompression")
        raster.convert(Image.FORMAT_RGBA8)
        check(raster.get_size()==Vector2i(192,192),key+" high-resolution original-source cell")
        check(digest(raster.get_data())==spec.rgba_sha256,key+" independent full-atlas RGBA oracle")
        textures[key]={"rgba_sha256":digest(raster.get_data()),"bounds":raster.get_used_rect()}
        routes[key]={"claimed":claimed,"unclaimed":unclaimed,"coverage":"detached explicit art and real state resolvers; no placements injected"}
    var native_bodies := 0
    for body in view._generated_decorative_bodies_by_tile.values():
        if not body.get("generated_body_visual_anchor",false):continue
        native_bodies+=1
        var key: String=view._decorative_object_asset_id(body)
        check(key.begins_with("cohesive_") and view._object_texture_for_asset(key) is Texture2D,"unchanged manifest-backed native blocker")
        var tile:=Vector2i(int(body.x),int(body.y))
        if captures.is_empty() and OverworldRules.is_tile_visible(session,tile.x,tile.y,int(body.get("level",0))):
            await capture(view,tile,key,body,"unchanged earned native control")
    check(native_bodies==2380 and captures.size()==1,"complete original native blocker control")
    var affected_native := []
    for node in session.overworld.get("resource_nodes",[]):
        var key: String=view._resource_asset_id(node)
        if not specs.has(key):continue
        affected_native.append({"asset_id":key,"placement":normalized(node)})
        var tile:=Vector2i(int(node.x),int(node.y))
        if OverworldRules.is_tile_visible(session,tile.x,tile.y,int(node.get("level",0))):
            await capture(view,tile,key,node,"actual state-selected original native resource site")
    var galleries: Array=await gallery(view,specs)
    await save_control(session,before,"native")
    session=SessionState.set_active_session(ScenarioFactory.create_session("prismhearth-watch","normal",SessionState.LAUNCH_MODE_SKIRMISH))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary Prismhearth Town exit")
        await settle()
    var position: Vector2i=OverworldRules.hero_position(session)
    var result: Dictionary=OverworldRules.try_move(session,0-position.x,2-position.y)
    check(bool(result.get("ok",false)),"ordinary Prismhearth scouting")
    AppRouter.resume_active_session()
    await settle()
    view=get_tree().current_scene._map_view
    before=normalized(session.to_dict())
    var authored := {"move":result}
    var found := false
    for node in session.overworld.get("resource_nodes",[]):
        if str(node.get("placement_id",""))!="prismhearth_watch_relay":continue
        found=true
        var tile:=Vector2i(int(node.x),int(node.y))
        check(tile==Vector2i(2,3),"original relay placement")
        check(OverworldRules.is_tile_visible(session,tile.x,tile.y),"relay visible through ordinary scouting")
        var key: String=view._resource_asset_id(node)
        check(key=="resource_site_recurring_prism_watch_relay","actual Prism Watch identity")
        authored["node"]=normalized(node)
        await capture(view,tile,key,node,"actual original Prismhearth relay; no state/placement/fog grants")
    check(found,"original Prism Watch Relay exists")
    await save_control(session,before,"authored")
    before=normalized(session.to_dict())
    MusicAudio.stop_music("recurring_site_probe_complete")
    AmbientAudio.stop_overworld_ambient("recurring_site_probe_complete")
    await settle()
    await get_tree().create_timer(0.1).timeout
    check(int(MusicAudio.validation_summary().active_player_count)==0 and int(AmbientAudio.validation_summary().active_player_count)==0,"audio owners finish after gameplay")
    check(normalized(session.to_dict())==before,"probe teardown preserves state")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"textures":textures,"routes":routes,"captures":captures,"galleries":galleries,"native_bodies":native_bodies,"affected_native":affected_native,"authored":authored,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
