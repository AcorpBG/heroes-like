"""Python-owned decoration probe: real authored starts and earned native control.

Coverage inputs only exercise the resolver; no fixture objects or fog are added.
Native collision bodies deliberately retain their separate cohesive art palette.
"""

SCRIPT = r'''
extends Node
var errors := []
var checks := 0
var out := ""
var captures := []
var captured := {}
func _ready() -> void:
    call_deferred("run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: errors.append(label)
func normalized(value: Dictionary) -> Dictionary:
    return JSON.parse_string(JSON.stringify(value))
func digest(data: PackedByteArray) -> String:
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(data)
    return hash.finish().hex_encode()
func settle() -> void:
    for frame in range(8): await get_tree().process_frame
func save_control(session, before: Dictionary, label: String) -> void:
    check(normalized(session.to_dict())==before,label+" complete state unchanged by rendering")
    var path: String = SaveService.save_session(session.to_dict(),3)
    check(path!="",label+" real manual save")
    if path!="":
        var file := FileAccess.open(out.path_join(label+"_saved_session.json"),FileAccess.WRITE)
        file.store_buffer(FileAccess.get_file_as_bytes(path))
        file.close()
    session=SessionState.restore_session(SaveService.load_session(3))
    check(normalized(session.to_dict())==before,label+" complete actual save/load equality")
    AppRouter.resume_active_session()
    await settle()
    check(normalized(session.to_dict())==before,label+" ordinary re-entry unchanged")
func capture(view, tile: Vector2i, asset_id: String, placement: Dictionary, category: String) -> void:
    view.focus_on_tile(tile)
    await settle()
    var presentation: Dictionary = view.validation_tile_presentation(tile)
    var art: Dictionary = presentation.get("art_presentation",{})
    check(asset_id in art.get("sprite_asset_ids",[]),category+" exact art at original coordinates: "+asset_id)
    check(not bool(art.get("fallback_procedural_marker",true)),category+" no procedural fallback: "+asset_id)
    if not captured.has(asset_id):
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png(out.path_join(asset_id+".png"))
        captures.append({"asset_id":asset_id,"placement":normalized(placement),"tile":presentation,"category":category,"screenshot_requested":true})
        captured[asset_id]=true
func run() -> void:
    get_tree().current_scene=null
    out=OS.get_environment("CUTOUT_OUTPUT")
    var bytes := FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"complete independent expectations transferred unchanged")
    if not errors.is_empty():
        print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":false,"checks":checks,"errors":errors}))
        get_tree().quit(1)
        return
    var specs: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal saved Town exit")
        await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"actual earned native Overworld entry")
    check(int(session.day)==97,"unchanged earned Medium Day97 checkpoint")
    var before: Dictionary = normalized(session.to_dict())
    var view = get_tree().current_scene._map_view
    var textures := {}
    for asset_id in specs:
        var spec: Dictionary = specs[asset_id]
        check(view._decorative_object_asset_id({"object_id":spec.object_id})==asset_id,asset_id+" exact authored identity")
        check(view._decorative_object_asset_id({"object_family_id":spec.object_id})==asset_id,asset_id+" adopted family identity")
        check(view._decorative_object_asset_id({"overworld_sprite_asset_id":asset_id})==asset_id,asset_id+" explicit manifest identity")
        check(view._object_asset_paths.get(asset_id,"")==spec.path,asset_id+" exact authoritative path")
        var texture = view._object_texture_for_asset(asset_id)
        check(texture is Texture2D,asset_id+" real texture, no fallback")
        if not texture is Texture2D:continue
        var raster: Image = texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,asset_id+" decompress")
        raster.convert(Image.FORMAT_RGBA8)
        var sha := digest(raster.get_data())
        check(raster.get_size()==Vector2i(512,512),asset_id+" unchanged logical canvas")
        check(sha==spec.rgba_sha256,asset_id+" exact decoded RGBA matches independent source-image oracle")
        textures[asset_id]={"rgba_sha256":sha,"bounds":raster.get_used_rect()}
    var native_assets := {}
    var native_bodies := 0
    for body in view._generated_decorative_bodies_by_tile.values():
        if not body.get("generated_body_visual_anchor",false):continue
        native_bodies+=1
        var asset_id: String = view._decorative_object_asset_id(body)
        check(asset_id.begins_with("cohesive_"),"native collision body retains separate cohesive palette")
        check(not specs.has(asset_id),"authored recovery does not replace native collision-body art")
        check(view._object_texture_for_asset(asset_id) is Texture2D,"native body remains asset backed")
        native_assets[asset_id]=true
        var tile := Vector2i(int(body.x),int(body.y))
        if captures.size()<1 and OverworldRules.is_tile_visible(session,tile.x,tile.y,int(body.get("level",0))):
            await capture(view,tile,asset_id,body,"unchanged earned native collision-body control")
    check(native_bodies>0 and captures.size()==1,"actual visible earned native control captured without injection")
    await save_control(session,before,"native")
    var authored_seen := {}
    var authored_summaries := {}
    for scenario_id in ["third-hearths-confluence","ninefold-confluence"]:
        session=SessionState.set_active_session(ScenarioFactory.create_session(scenario_id,"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        AppRouter.resume_active_session()
        await settle()
        view=get_tree().current_scene._map_view
        before=normalized(session.to_dict())
        var visible_count := 0
        var affected_count := 0
        for object in session.overworld.get("map_objects",[]):
            var asset_id: String = view._decorative_object_asset_id(object)
            if not specs.has(asset_id):continue
            affected_count+=1
            var tile := Vector2i(int(object.x),int(object.y))
            check(view._decorative_object_at(tile)==object,asset_id+" exact authored record indexed without replacement")
            if not OverworldRules.is_tile_visible(session,tile.x,tile.y,int(object.get("level",0))):continue
            visible_count+=1
            authored_seen[asset_id]=true
            await capture(view,tile,asset_id,object,scenario_id+" normal initial vision")
        authored_summaries[scenario_id]={"affected_placements":affected_count,"naturally_visible":visible_count}
        check(affected_count>0,scenario_id+" contains real affected content")
        await save_control(session,before,scenario_id)
    check(authored_seen.size()>0,"corrected authored scenery captured with normal starting vision")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"textures":textures,"captures":captures,"native_bodies":native_bodies,"native_assets":native_assets.keys(),"authored":authored_summaries,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
