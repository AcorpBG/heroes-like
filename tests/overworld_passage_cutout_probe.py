"""Exact resource-state art, unchanged native control and earned open passage."""
from overworld_legacy_cutout_probe import SCRIPT as LEGACY_SCRIPT

SCRIPT=LEGACY_SCRIPT.split('func run() -> void:',1)[0].replace(
    'label.text=key.trim_prefix("resource_site_neutral_").trim_prefix("hero_faction_").trim_prefix("generated_tree_")',
    'label.text=str(specs[key].entry.assigned_resource_site_id).trim_prefix("site_")')+r'''
func node_for(session, placement: String) -> Dictionary:
    for node in session.overworld.get("resource_nodes",[]):
        if str(node.get("placement_id",""))==placement:return node
    return {}
func run() -> void:
    get_tree().current_scene=null
    out=OS.get_environment("CUTOUT_OUTPUT")
    var bytes := FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"complete independent expectations transferred unchanged")
    var specs: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
    check(specs.size()==7,"all seven reviewed state paintings")
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal earned Town exit")
        await settle()
    check(int(session.day)==97,"unchanged earned Medium Day97")
    var before: Dictionary = normalized(session.to_dict())
    var view = get_tree().current_scene._map_view
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/overworld/manifest.json"))
    var textures := {}
    var routes := {}
    for key in specs:
        var spec: Dictionary=specs[key]
        var site: String=spec.entry.assigned_resource_site_id
        var input := {"site_id":site,"kind":"resource_site","collected_by_faction_id":"faction_embercourt"}
        check(view._resource_asset_id(input)==key,key+" exact claimed-state resolver; detached input")
        var unclaimed: String=view._resource_asset_id({"site_id":site,"kind":"resource_site"})
        check(unclaimed!=key and unclaimed==manifest.resource_site_sprites[site].unclaimed_asset_id,key+" exact unchanged dormant-state resolver")
        var texture=view._object_texture_for_asset(key)
        check(texture is AtlasTexture,key+" real original atlas path")
        if not texture is AtlasTexture:continue
        check(view._object_asset_paths.get(key,"")==spec.path,key+" manifest path")
        check(view._object_asset_regions.get(key,[])==spec.atlas_region,key+" exact atlas region")
        var raster: Image=texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,key+" decompression")
        raster.convert(Image.FORMAT_RGBA8)
        check(raster.get_size()==Vector2i(48,48),key+" original logical size")
        check(digest(raster.get_data())==spec.rgba_sha256,key+" exact independent full-atlas PNG oracle")
        textures[key]={"rgba_sha256":digest(raster.get_data()),"bounds":raster.get_used_rect()}
        routes[key]={"claimed":key,"unclaimed":unclaimed,"coverage":"detached resolver dictionaries only"}
    var native_bodies := 0
    for body in view._generated_decorative_bodies_by_tile.values():
        if not body.get("generated_body_visual_anchor",false):continue
        native_bodies+=1
        var asset: String=view._decorative_object_asset_id(body)
        check(asset.begins_with("cohesive_") and view._object_texture_for_asset(asset) is Texture2D,"unchanged manifest-backed native blocker")
        var tile:=Vector2i(int(body.x),int(body.y))
        if captures.is_empty() and OverworldRules.is_tile_visible(session,tile.x,tile.y,int(body.get("level",0))):
            await capture(view,tile,asset,body,"unchanged earned native gameplay control")
    var affected_native := []
    for node in session.overworld.get("resource_nodes",[]):
        var key: String=view._resource_asset_id(node)
        if specs.has(key):affected_native.append({"asset_id":key,"placement":normalized(node)})
    check(native_bodies>0 and captures.size()==1,"native map control; no placement or fog injection")
    var galleries: Array=await gallery(view,specs)
    await save_control(session,before,"native")
    # Ordinary authored start and movement, no collection/position/fog grants.
    session=SessionState.set_active_session(ScenarioFactory.create_session("seedseer-drowned-orchard","normal",SessionState.LAUNCH_MODE_SKIRMISH))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal authored Town exit")
        await settle()
    var moves := []
    for tile in [Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),Vector2i(4,3),Vector2i(4,2),Vector2i(5,2),Vector2i(5,1)]:
        var position: Vector2i=OverworldRules.hero_position(session)
        var result: Dictionary=OverworldRules.try_move(session,tile.x-position.x,tile.y-position.y)
        moves.append({"from":position,"to":tile,"result":result})
        check(bool(result.get("ok",false)),"ordinary authored step: "+str(tile)+" "+JSON.stringify(result))
        if not bool(result.get("ok",false)):break
    AppRouter.resume_active_session()
    await settle()
    var node: Dictionary=node_for(session,"seedseer_dormant_b")
    check(not str(node.get("collected_by_faction_id","")).is_empty(),"Root Pass earned by actual arrival")
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"ordinary arrival remains on Overworld")
    var authored := {"moves":moves,"node":normalized(node)}
    if get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"):
        view=get_tree().current_scene._map_view
        var key: String=view._resource_asset_id(node)
        check(key=="resource_site_land_transit_root_pass_arch_active","earned active Root Pass art")
        var tile:=Vector2i(int(node.get("x",-1)),int(node.get("y",-1)))
        check(OverworldRules.is_tile_visible(session,tile.x,tile.y),"earned passage visible through normal vision")
        before=normalized(session.to_dict())
        await capture(view,tile,key,node,"earned authored Root Pass after ordinary arrival")
        await save_control(session,before,"authored")
    # The multi-scene headless probe must finish its audio owners before quit.
    # Verbose Windows evidence identified Ogg playback references at abrupt
    # teardown, not missing art. Audio remains enabled throughout gameplay.
    before=normalized(session.to_dict())
    MusicAudio.stop_music("passage_probe_complete")
    AmbientAudio.stop_overworld_ambient("passage_probe_complete")
    await settle()
    await get_tree().create_timer(0.1).timeout
    check(int(MusicAudio.validation_summary().active_player_count)==0 and int(AmbientAudio.validation_summary().active_player_count)==0,"existing audio owners finish before headless shutdown")
    check(normalized(session.to_dict())==before,"probe audio teardown preserves full session")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"textures":textures,"routes":routes,"captures":captures,"galleries":galleries,"native_bodies":native_bodies,"affected_native":affected_native,"authored":authored,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
