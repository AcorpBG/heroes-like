"""Sixty identity routes; actual native control and earned authored recruitment.

No hero swaps, free resources, forced buildings, placements or fog grants. The
all-identity gallery and commander resolver inputs are explicitly detached.
"""
from overworld_legacy_cutout_probe import SCRIPT as LEGACY_SCRIPT

SCRIPT=LEGACY_SCRIPT.split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('label.text=key.trim_prefix("resource_site_neutral_").trim_prefix("hero_faction_").trim_prefix("generated_tree_")','''label.text=str(specs[key].entry.assigned_hero_id).trim_prefix("hero_").replace("_"," ")
            label.size=Vector2(cell.x-12,32)
            label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART''')
SCRIPT+=r'''
func capture_hero(view, session, category: String) -> void:
    var hero: Dictionary=HeroCommandRules.active_hero(session)
    var tile: Vector2i=OverworldRules.hero_position(session)
    var asset_id: String=view._hero_sprite_asset_id(hero)
    view.focus_on_tile(tile)
    await settle()
    var presentation: Dictionary=view.validation_tile_presentation(tile)
    var art: Dictionary=presentation.get("hero_presentation",{})
    check(OverworldRules.is_tile_visible(session,tile.x,tile.y),category+" ordinary earned hero vision")
    check(art.get("hero_id","")==hero.id,category+" actual active hero at original position")
    check(art.get("sprite_asset_id","")==asset_id and bool(art.get("uses_identity_sprite",false)),category+" exact identity painting")
    check(not bool(art.get("uses_procedural_fallback",true)),category+" no procedural hero fallback")
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(out.path_join(asset_id+".png"))
    captures.append({"asset_id":asset_id,"placement":normalized(hero),"tile":presentation,"category":category,"screenshot_requested":true})

func run() -> void:
    get_tree().current_scene=null
    out=OS.get_environment("CUTOUT_OUTPUT")
    var bytes:=FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"complete independent expectations transferred unchanged")
    if not errors.is_empty():
        print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":false,"checks":checks,"errors":errors}))
        get_tree().quit(1)
        return
    var specs: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session=SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal saved Town exit")
        await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"actual earned native Overworld entry")
    check(int(session.day)==97,"unchanged earned Medium Day97 checkpoint")
    var before: Dictionary=normalized(session.to_dict())
    var view=get_tree().current_scene._map_view
    var textures:={}
    var routes:={}
    for asset_id in specs:
        var spec: Dictionary=specs[asset_id]
        var hero_id: String=spec.entry.assigned_hero_id
        var hero: Dictionary=ContentService.get_hero(hero_id)
        check(not hero.is_empty(),asset_id+" real authored hero")
        check(view._hero_identity_asset_ids.get(hero_id,"")==asset_id,asset_id+" registered exact hero identity")
        check(view._hero_sprite_asset_id(hero)==asset_id,asset_id+" identity priority over faction fallback")
        check(view._object_asset_paths.get(asset_id,"")==spec.path,asset_id+" exact authoritative path")
        var texture=view._object_texture_for_asset(asset_id)
        check(texture is Texture2D,asset_id+" real raster, no fallback")
        if not texture is Texture2D:continue
        var raster: Image=texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,asset_id+" decompress")
        raster.convert(Image.FORMAT_RGBA8)
        var sha:=digest(raster.get_data())
        check(raster.get_size()==Vector2i(512,512),asset_id+" unchanged logical canvas")
        check(sha==spec.rgba_sha256,asset_id+" decoded RGBA matches independent source-image oracle")
        # Detached resolver input only; not inserted as an encounter in a map.
        var encounter:={"spawned_by_faction_id":hero.faction_id,"enemy_commander_state":{"roster_hero_id":hero_id,"faction_id":hero.faction_id}}
        var commander: Dictionary=view.validation_encounter_presentation_payload(encounter)
        check(commander.get("sprite_asset_id","")==asset_id and bool(commander.get("uses_commander_sprite",false)),asset_id+" matching enemy commander identity route")
        textures[asset_id]={"rgba_sha256":sha,"bounds":raster.get_used_rect()}
        routes[asset_id]={"hero_id":hero_id,"player_identity":asset_id,"enemy_identity":commander.get("sprite_asset_id",""),"coverage":"detached resolver inputs; no placement injection"}
    check(specs.size()==60,"all sixty reviewed identity sprites")
    var native_bodies:=0
    for body in view._generated_decorative_bodies_by_tile.values():
        if not body.get("generated_body_visual_anchor",false):continue
        native_bodies+=1
        var asset_id: String=view._decorative_object_asset_id(body)
        check(asset_id.begins_with("cohesive_") and view._object_texture_for_asset(asset_id) is Texture2D,"native blocker keeps separate painted palette")
    check(native_bodies==2380,"fixed native placement pool unchanged")
    await capture_hero(view,session,"unchanged earned native player hero control")
    var galleries: Array=await gallery(view,specs)
    await save_control(session,before,"native")
    var authored:={}
    # These source-authored starts have a Hall and an unobstructed east exit.
    # Bellwake's pressure deadline and Prismhearth's water/guarded entrances
    # are not suitable for an idle recruitment-and-departure art control.
    for item in [["daynote-kite-signal-accord","hero_thalen"],["mireford-skirmish","hero_thornwake_nara_graftsibyl"],["vowless-saltpan-circuit","hero_veilmourn_orso_nightchart"]]:
        session=SessionState.set_active_session(ScenarioFactory.create_session(item[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        AppRouter.go_to_town()
        await settle()
        check(get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"),str(item[0])+" ordinary starting Town entry")
        var hero_id: String=item[1]
        var cost: Dictionary=HeroCommandRules.hero_recruit_cost(ContentService.get_hero(hero_id))
        var actions:=[]
        # Original towns already have their Hall. Earn the price through the
        # normal economy, never patch resources, days, buildings or hero state.
        for day in range(8):
            if int(session.overworld.resources.gold)>=int(cost.gold):break
            var turn: Dictionary=OverworldRules.end_turn(session)
            check(bool(turn.get("ok",false)),hero_id+" ordinary income turn")
            actions.append({"turn":turn})
            check(session.scenario_status=="in_progress",hero_id+" recruitment case remains nonterminal")
            if session.scenario_status!="in_progress":
                print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":false,"errors":errors,"checks":checks,"scenario":item[0],"day":session.day,"summary":session.scenario_summary,"actions":actions}))
                get_tree().quit(1)
                return
        var resources: Dictionary=normalized(session.overworld.resources)
        var count: int=session.overworld.player_heroes.size()
        var hire: Dictionary=TownRules.hire_hero_at_active_town(session,hero_id)
        check(bool(hire.get("ok",false)),hero_id+" normal paid tavern recruitment")
        actions.append({"hire":hire})
        check(session.overworld.player_heroes.size()==count+1,hero_id+" exactly one new commander")
        for resource in cost:
            check(int(resources.get(resource,0))-int(session.overworld.resources.get(resource,0))==int(cost[resource]),hero_id+" exact original hire cost: "+str(resource))
        var switch: Dictionary=TownRules.switch_active_hero_at_town(session,hero_id)
        check(bool(switch.get("ok",false)),hero_id+" ordinary town command switch")
        check(str(session.overworld.active_hero_id)==hero_id,hero_id+" exact paid recruit is active")
        check(get_tree().current_scene.validation_leave_town().get("ok",false),hero_id+" ordinary Town exit")
        await settle()
        var start: Vector2i=OverworldRules.hero_position(session)
        var move: Dictionary=OverworldRules.try_move(session,1,0)
        check(bool(move.get("ok",false)),hero_id+" ordinary departure movement")
        check(OverworldRules.hero_position(session)==start+Vector2i(1,0),hero_id+" original movement/pathing retained")
        actions.append({"switch":switch,"move":move})
        AppRouter.go_to_overworld()
        await settle()
        check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),hero_id+" nonterminal ordinary departure")
        if not get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"):
            print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":false,"errors":errors,"checks":checks,"scenario":item[0],"day":session.day,"summary":session.scenario_summary,"actions":actions}))
            get_tree().quit(1)
            return
        view=get_tree().current_scene._map_view
        before=normalized(session.to_dict())
        await capture_hero(view,session,"actual authored paid recruit after normal departure")
        await save_control(session,before,str(item[0]))
        authored[hero_id]={"scenario_id":item[0],"day":session.day,"actions":actions,"cost":cost,"original_start":{"x":start.x,"y":start.y}}
    check(captures.size()==4 and authored.size()==3,"native control and all three corrected heroes captured in ordinary play")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"textures":textures,"routes":routes,"captures":captures,"galleries":galleries,"native_bodies":native_bodies,"authored":authored,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
