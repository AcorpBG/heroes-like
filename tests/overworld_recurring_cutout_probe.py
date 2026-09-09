"""Exact encounter raster routes, ordinary scouting and unchanged native control."""
from overworld_legacy_cutout_probe import SCRIPT as LEGACY_SCRIPT

SCRIPT=LEGACY_SCRIPT.split('func run() -> void:',1)[0].replace(
    'label.text=key.trim_prefix("resource_site_neutral_").trim_prefix("hero_faction_").trim_prefix("generated_tree_")',
    'label.text=key.trim_prefix("encounter_recurring_")').replace(
    'check(asset_id in art.get("sprite_asset_ids",[]),category+" exact art at original coordinates: "+asset_id)',
    '''if asset_id.begins_with("encounter_recurring_"):
        # The generic tile report lists hostile_camp; the draw owner resolves
        # commander/identity/faction priority separately. Check that exact owner.
        var encounter_art: Dictionary=view._enemy_commander_presentation_payload(placement)
        check(bool(encounter_art.get("uses_identity_encounter_sprite",false)),category+" actual renderer selects identity art")
        check(encounter_art.get("identity_encounter_asset_id","")==asset_id,category+" exact rendered encounter identity")
        check(is_equal_approx(float(encounter_art.get("faction_landmark_visible_extent_tiles",0.0)),1.08),category+" unchanged world draw extent despite higher raster resolution")
        presentation["exact_encounter_renderer"]=encounter_art
    else:
        check(asset_id in art.get("sprite_asset_ids",[]),category+" exact art at original coordinates: "+asset_id)''')+r'''
func run() -> void:
    get_tree().current_scene=null
    out=OS.get_environment("CUTOUT_OUTPUT")
    var bytes := FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"complete independent expectations transferred unchanged")
    var specs: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
    check(specs.size()==31,"all thirty-one source-recovered encounters")
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session=SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal earned Town exit")
        await settle()
    check(int(session.day)==97,"unchanged earned native Medium Day97")
    var before: Dictionary=normalized(session.to_dict())
    var view=get_tree().current_scene._map_view
    var textures := {}
    var routes := {}
    for key in specs:
        var spec: Dictionary=specs[key]
        var input := {"encounter_id":spec.entry.assigned_encounter_id}
        check(view._encounter_identity_asset_id(input)==key,key+" exact identity resolver; detached input")
        var texture=view._object_texture_for_asset(key)
        check(texture is AtlasTexture,key+" authoritative atlas")
        if not texture is AtlasTexture:continue
        check(view._object_asset_paths.get(key,"")==spec.path,key+" exact path")
        check(view._object_asset_regions.get(key,[])==spec.atlas_region,key+" exact high-resolution region")
        var raster: Image=texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,key+" decompress")
        raster.convert(Image.FORMAT_RGBA8)
        check(raster.get_size()==Vector2i(192,192),key+" high-resolution original-source canvas")
        check(digest(raster.get_data())==spec.rgba_sha256,key+" independent full-atlas PNG oracle")
        textures[key]={"rgba_sha256":digest(raster.get_data()),"bounds":raster.get_used_rect()}
        routes[key]={"identity":key,"coverage":"detached identity input; no commander priority bypass"}
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
    for encounter in session.overworld.get("encounters",[]):
        var key: String=view._encounter_identity_asset_id(encounter)
        if specs.has(key):affected_native.append({"asset_id":key,"placement":normalized(encounter),"resolved":OverworldRules.is_encounter_resolved(session,encounter)})
    check(native_bodies>0 and captures.size()==1,"actual native control; no placement/fog injection")
    var galleries: Array=await gallery(view,specs)
    await save_control(session,before,"native")
    session=SessionState.set_active_session(ScenarioFactory.create_session("charter-pyre","normal",SessionState.LAUNCH_MODE_SKIRMISH))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal authored Town exit")
        await settle()
    var moves := []
    for tile in [Vector2i(1,2),Vector2i(2,2)]:
        var position: Vector2i=OverworldRules.hero_position(session)
        var result: Dictionary=OverworldRules.try_move(session,tile.x-position.x,tile.y-position.y)
        moves.append({"from":position,"to":tile,"result":result})
        check(bool(result.get("ok",false)),"ordinary scout step: "+str(tile)+" "+JSON.stringify(result))
        if not bool(result.get("ok",false)):break
    AppRouter.resume_active_session()
    await settle()
    view=get_tree().current_scene._map_view
    before=normalized(session.to_dict())
    var found := false
    var authored := {"moves":moves}
    for encounter in session.overworld.get("encounters",[]):
        if str(encounter.get("placement_id",""))!="charter_beacon_wardens":continue
        found=true
        var tile:=Vector2i(int(encounter.x),int(encounter.y))
        check(tile==Vector2i(4,1),"original Beacon Wardens placement")
        check(OverworldRules.is_tile_visible(session,tile.x,tile.y),"Beacon Wardens scouted through normal vision")
        var key: String=view._encounter_identity_asset_id(encounter)
        check(key=="encounter_recurring_beacon_wardens","actual Beacon Wardens identity")
        authored["encounter"]=normalized(encounter)
        await capture(view,tile,key,encounter,"actual authored Beacon Wardens after ordinary scouting")
    check(found,"actual original Beacon Wardens found")
    await save_control(session,before,"authored")
    session=SessionState.set_active_session(ScenarioFactory.create_session("bogbound-oath","normal",SessionState.LAUNCH_MODE_SKIRMISH))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal Bogbound Town exit")
        await settle()
    var wave4 := {"moves":[]}
    for tile in [Vector2i(1,2),Vector2i(2,2)]:
        var position: Vector2i=OverworldRules.hero_position(session)
        var result: Dictionary=OverworldRules.try_move(session,tile.x-position.x,tile.y-position.y)
        wave4.moves.append({"from":position,"to":tile,"result":result})
        check(bool(result.get("ok",false)),"ordinary Bogbound scouting: "+str(tile))
        if not bool(result.get("ok",false)):break
    AppRouter.resume_active_session()
    await settle()
    view=get_tree().current_scene._map_view
    before=normalized(session.to_dict())
    found=false
    for encounter in session.overworld.get("encounters",[]):
        if str(encounter.get("placement_id",""))!="bogbound_lantern_patrol":continue
        found=true
        var tile:=Vector2i(int(encounter.x),int(encounter.y))
        check(tile==Vector2i(3,1),"original Lantern Patrol placement")
        check(not OverworldRules.is_encounter_resolved(session,encounter),"actual Lantern Patrol remains unresolved")
        check(OverworldRules.is_tile_visible(session,tile.x,tile.y),"Lantern Patrol reached through ordinary vision")
        var key: String=view._encounter_identity_asset_id(encounter)
        check(key=="encounter_recurring_lantern_patrol","actual later-wave identity")
        wave4["encounter"]=normalized(encounter)
        await capture(view,tile,key,encounter,"actual Bogbound Lantern Patrol after ordinary scouting")
    check(found,"actual original Lantern Patrol found")
    await save_control(session,before,"wave4")
    authored["wave4"]=wave4
    before=normalized(session.to_dict())
    MusicAudio.stop_music("recurring_probe_complete")
    AmbientAudio.stop_overworld_ambient("recurring_probe_complete")
    await settle()
    await get_tree().create_timer(0.1).timeout
    check(int(MusicAudio.validation_summary().active_player_count)==0 and int(AmbientAudio.validation_summary().active_player_count)==0,"audio owners finish after gameplay")
    check(normalized(session.to_dict())==before,"probe teardown preserves full session")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"textures":textures,"routes":routes,"captures":captures,"galleries":galleries,"native_bodies":native_bodies,"affected_native":affected_native,"authored":authored,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
