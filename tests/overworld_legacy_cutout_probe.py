"""Mixed legacy art: exact atlas/runtime oracle, labeled gallery, real save control.

Faction fallback heroes and the older tree atlas are not injected into gameplay.
The gallery is explicitly a detached renderer fixture, never a generated map.
"""
from overworld_decoration_cutout_probe import SCRIPT as DECORATION_SCRIPT

SCRIPT = DECORATION_SCRIPT.split('func run() -> void:',1)[0] + r'''
func gallery(view, specs: Dictionary) -> Array:
    var names: Array = specs.keys()
    var files := []
    for page in range(ceili(names.size()/12.0)):
        var layer := CanvasLayer.new()
        layer.layer=100
        add_child(layer)
        var surface := ColorRect.new()
        surface.color=Color("334c3a")
        surface.size=Vector2(get_viewport().get_visible_rect().size)
        layer.add_child(surface)
        var heading := Label.new()
        heading.text="DETACHED ART COVERAGE — NOT GAMEPLAY | page %d" % (page+1)
        heading.position=Vector2(24,12)
        surface.add_child(heading)
        var cell := Vector2((surface.size.x-48)/4.0,(surface.size.y-72)/3.0)
        for j in range(12):
            var index := page*12+j
            if index>=names.size():break
            var key: String = names[index]
            var pos := Vector2(24+(j%4)*cell.x,48+(j/4)*cell.y)
            var texture := TextureRect.new()
            texture.texture=view._object_texture_for_asset(key)
            texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
            texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            texture.position=pos
            texture.size=Vector2(cell.x-12,cell.y-34)
            surface.add_child(texture)
            var label := Label.new()
            label.text=key.trim_prefix("resource_site_neutral_").trim_prefix("hero_faction_").trim_prefix("generated_tree_")
            label.position=pos+Vector2(0,cell.y-32)
            label.add_theme_font_size_override("font_size",13)
            surface.add_child(label)
        await settle()
        var filename := "detached_gallery_%d.png" % (page+1)
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png(out.path_join(filename))
        files.append(filename)
        layer.queue_free()
        await settle()
    return files

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
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/overworld/manifest.json"))
    var textures := {}
    var routes := {}
    for asset_id in specs:
        var spec: Dictionary = specs[asset_id]
        check(view._object_asset_paths.get(asset_id,"")==spec.path,asset_id+" exact authoritative path")
        var texture = view._object_texture_for_asset(asset_id)
        check(texture is Texture2D,asset_id+" real texture, no fallback")
        if not texture is Texture2D:continue
        var raster: Image = texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,asset_id+" decompress")
        raster.convert(Image.FORMAT_RGBA8)
        var sha := digest(raster.get_data())
        check(raster.get_size()==Vector2i(int(spec.size[0]),int(spec.size[1])),asset_id+" unchanged logical canvas")
        check(sha==spec.rgba_sha256,asset_id+" decoded RGBA matches independent full-atlas import oracle")
        if spec.has("atlas_region"):
            check(texture is AtlasTexture,asset_id+" authoritative atlas retained")
            check(view._object_asset_regions.get(asset_id,[])==spec.atlas_region,asset_id+" exact unchanged atlas region")
        if spec.mode=="original_hero":
            var faction: String = asset_id.replace("hero_faction_","faction_")
            check(view._hero_faction_asset_ids.get(faction,"")==asset_id,asset_id+" registered faction fallback remains available")
            routes[asset_id]="registered faction fallback; identity priority not bypassed"
        elif spec.mode=="generated_state":
            var controlled := {"site_id":"site_miremoon_crownmere","kind":"resource_site","collected_by_faction_id":"faction_embercourt"}
            check(view._resource_asset_id(controlled)==asset_id,"exact Crownmere controlled-state resolver, detached coverage input")
            check(view._resource_asset_id({"site_id":"site_miremoon_crownmere","kind":"resource_site"})=="mapobj_miremoon_crownmere","unclaimed state still uses its distinct original painting")
            routes[asset_id]="exact controlled-state route; no world state changed"
        else:
            check(view._standalone_map_object_asset_id({"overworld_sprite_asset_id":asset_id})==asset_id,asset_id+" explicit legacy asset route")
            routes[asset_id]="registered legacy/direct asset; no placement inferred"
        textures[asset_id]={"rgba_sha256":sha,"bounds":raster.get_used_rect()}
    check(specs.size()==35,"complete 35-row reviewed cohort")
    check(view._artifact_default_asset_id=="adventurers_bundle","original artifact default mapping retained")
    var identity_heroes := 0
    for hero in session.overworld.get("player_heroes",[]):
        var actual: String = view._hero_sprite_asset_id(hero)
        var expected: String = manifest.hero_identity_sprites.get(str(hero.get("id","")),"")
        if not expected.is_empty():
            check(actual==expected,"actual saved hero keeps identity priority: "+str(hero.get("id","")))
            identity_heroes+=1
    check(identity_heroes>0,"real saved heroes exercise unchanged identity priority")
    var native_bodies := 0
    for body in view._generated_decorative_bodies_by_tile.values():
        if not body.get("generated_body_visual_anchor",false):continue
        native_bodies+=1
        var asset_id: String = view._decorative_object_asset_id(body)
        check(asset_id.begins_with("cohesive_"),"native blockers retain current cohesive palette")
        check(not specs.has(asset_id),"older atlas does not replace current native art")
        check(view._object_texture_for_asset(asset_id) is Texture2D,"native body remains art backed")
        var tile := Vector2i(int(body.x),int(body.y))
        if captures.is_empty() and OverworldRules.is_tile_visible(session,tile.x,tile.y,int(body.get("level",0))):
            await capture(view,tile,asset_id,body,"unchanged earned native gameplay control")
    check(native_bodies>0 and captures.size()==1,"earned native control captured without placement/fog injection")
    var affected_native := []
    for node in session.overworld.get("resource_nodes",[]):
        var asset_id: String = view._resource_asset_id(node)
        if not specs.has(asset_id):continue
        affected_native.append({"asset_id":asset_id,"placement":normalized(node)})
        var tile := Vector2i(int(node.x),int(node.y))
        if OverworldRules.is_tile_visible(session,tile.x,tile.y,int(node.get("level",0))):
            await capture(view,tile,asset_id,node,"original affected earned native placement")
    var galleries: Array = await gallery(view,specs)
    await save_control(session,before,"native")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"textures":textures,"routes":routes,"captures":captures,"galleries":galleries,"native_bodies":native_bodies,"affected_native":affected_native,"identity_heroes":identity_heroes,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
