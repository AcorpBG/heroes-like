"""Exact artifact field routes, original pickups/scouting and full saved states."""
from overworld_legacy_cutout_probe import SCRIPT as LEGACY_SCRIPT
from overworld_remaining_encounter_cutout_probe import SCRIPT as SCOUT_SCRIPT

SCRIPT=LEGACY_SCRIPT.split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('extends Node','extends Node\nconst ArtifactRulesScript=preload("res://scripts/core/ArtifactRules.gd")')
SCRIPT=SCRIPT.replace('label.text=key.trim_prefix("resource_site_neutral_").trim_prefix("hero_faction_").trim_prefix("generated_tree_")',
'''label.text=key.trim_prefix("artifact_field_").replace("_"," ")
            label.size=Vector2(cell.x-12,30)
            label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART''')
SCRIPT+='func seal_scout_route('+SCOUT_SCRIPT.split('func seal_scout_route(',1)[1].split('func run() -> void:',1)[0]
SCRIPT+=r'''
func enter_overworld() -> void:
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary Town exit")
        await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"actual Overworld entry")

func run() -> void:
    get_tree().current_scene=null
    out=OS.get_environment("CUTOUT_OUTPUT")
    var bytes := FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"complete independent expectations transferred unchanged")
    var specs: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
    check(specs.size()==69,"36 recovered atlas paintings and 33 unchanged field controls")
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session=SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    await enter_overworld()
    check(int(session.day)==97,"unchanged earned native Medium Day97")
    var before: Dictionary=normalized(session.to_dict())
    var view=get_tree().current_scene._map_view
    var textures := {}
    var routes := {}
    for key in specs:
        var spec: Dictionary=specs[key]
        var identity: String=key.replace("artifact_field_","artifact_")
        var input := {"artifact_id":identity}
        check(view._artifact_sprite_asset_id(input)==key,key+" exact artifact identity resolver; detached input")
        var texture=view._object_texture_for_asset(key)
        check(texture is Texture2D,key+" authoritative raster")
        if not texture is Texture2D:continue
        check(view._object_asset_paths.get(key,"")==spec.path,key+" exact path")
        if spec.has("atlas_region"):
            check(texture is AtlasTexture,key+" authoritative atlas")
            check(view._object_asset_regions.get(key,[])==spec.atlas_region,key+" exact high-resolution region")
        else:
            check(not texture is AtlasTexture,key+" unchanged standalone field route")
        var raster: Image=texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,key+" decompress")
        raster.convert(Image.FORMAT_RGBA8)
        check(raster.get_size()==Vector2i(int(spec.size[0]),int(spec.size[1])),key+" original-source canvas")
        check(digest(raster.get_data())==spec.rgba_sha256,key+" independent full-atlas PNG oracle")
        var icon_path: String=ArtifactRulesScript.artifact_icon_path(identity)
        var profile: Dictionary=view._artifact_object_profile(input)
        var extent: float=view._sprite_extent_fraction(profile,Vector2i(1,1))
        check(icon_path==spec.entry.source_icon and icon_path!=spec.path,key+" exact inventory icon remains separate")
        check(extent>0.0 and extent<=1.0,key+" unchanged single-tile extent")
        textures[key]={"rgba_sha256":digest(raster.get_data()),"bounds":raster.get_used_rect()}
        routes[key]={"identity":identity,"field":key,"icon_path":icon_path,"profile":profile,"extent":extent,"coverage":"detached resolver input; no world injection"}
    var native_bodies := 0
    for body in view._generated_decorative_bodies_by_tile.values():
        if not body.get("generated_body_visual_anchor",false):continue
        native_bodies+=1
        var asset: String=view._decorative_object_asset_id(body)
        check(asset.begins_with("cohesive_") and view._object_texture_for_asset(asset) is Texture2D,"unchanged manifest-backed native blocker")
        var tile:=Vector2i(int(body.x),int(body.y))
        if captures.is_empty() and OverworldRules.is_tile_visible(session,tile.x,tile.y,int(body.get("level",0))):
            await capture(view,tile,asset,body,"unchanged earned native gameplay control")
    check(native_bodies==2380 and captures.size()==1,"exact earned native body control; no placement/fog injection")
    var affected_native := []
    for node in session.overworld.get("artifact_nodes",[]):
        var key: String=view._artifact_sprite_asset_id(node)
        check(specs.has(key),"native artifact retains its exact field identity")
        var tile:=Vector2i(int(node.x),int(node.y))
        var presentation: Dictionary=view.validation_tile_presentation(tile)
        var visible: bool=OverworldRules.is_tile_visible(session,tile.x,tile.y,int(node.get("level",0)))
        var collected: bool=node.get("collected",false)
        if collected:
            check(not key in presentation.get("art_presentation",{}).get("sprite_asset_ids",[]),"collected native artifact stays absent")
        elif visible:
            await capture(view,tile,key,node,"unchanged original uncollected native artifact")
        affected_native.append({"asset_id":key,"placement":normalized(node),"collected":collected,"visible":visible})
    check(affected_native.size()==22,"all original native artifact placements retained")
    var galleries: Array=await gallery(view,specs)
    await save_control(session,before,"native")
    var authored := []
    var cases := [
        ["lockfire-three-seal-pilgrimage","lockfirepilgrim_relic_1","artifact_field_lockfire_assize_seal",Vector2i(4,1),true],
        ["lockfire-three-seal-pilgrimage","lockfirepilgrim_relic_2","artifact_field_rainwrit_beacon_seal",Vector2i(7,3),true],
        ["lockfire-three-seal-pilgrimage","lockfirepilgrim_relic_3","artifact_field_ashcrown_crownring",Vector2i(4,6),true],
        ["last-bell-three-sounding-pilgrimage","lastbellpilgrim_relic_3","artifact_field_saltwake_resonance_bell",Vector2i(4,6),true],
        ["rainledger-amberweir-lockpike-trial","amberweirtrial_heirloom","artifact_field_amberweir_lockpike_tallychain",Vector2i(10,5),false],
        ["blackgauge-muster-bell-march","blackgauge_relic","artifact_field_blackgauge_muster_bell",Vector2i(12,7),false],
        ["sevenfold-reserve-prism-march","sevenfold_relic","artifact_field_sevenfold_reserve_prism",Vector2i(12,7),false]
    ]
    for item in cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(item[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        await enter_overworld()
        var original_node := {}
        for node in session.overworld.artifact_nodes:
            if node.get("placement_id","")==item[1]:original_node=normalized(node)
        check(not original_node.is_empty(),str(item[1])+" original artifact exists")
        check(Vector2i(int(original_node.get("x",-1)),int(original_node.get("y",-1)))==item[3],str(item[1])+" exact original coordinates")
        var actions := []
        for attempt in range(8):
            if OverworldRules.is_tile_visible(session,item[3].x,item[3].y):break
            var route: Array=legal_scout_route(session,item[3])
            check(route.size()>1,str(item[1])+" legal ordinary scouting route exists")
            if route.size()<2:break
            var travel: Dictionary=OverworldRules.try_move_along_route(session,route)
            check(bool(travel.get("ok",false)),str(item[1])+" ordinary scouting move")
            actions.append({"route":route,"travel":travel})
            if OverworldRules.is_tile_visible(session,item[3].x,item[3].y):break
            var turn: Dictionary=OverworldRules.end_turn(session)
            check(bool(turn.get("ok",false)),str(item[1])+" ordinary end turn")
            actions.append({"turn":turn})
        await enter_overworld()
        view=get_tree().current_scene._map_view
        var current_node := {}
        for node in session.overworld.artifact_nodes:
            if node.get("placement_id","")==item[1]:current_node=node
        check(normalized(current_node)==original_node,str(item[1])+" scouting preserves full original placement and guard")
        check(OverworldRules.is_tile_visible(session,item[3].x,item[3].y),str(item[1])+" actual earned vision")
        check(view._artifact_sprite_asset_id(current_node)==item[2],str(item[1])+" exact actual artifact identity")
        before=normalized(session.to_dict())
        await capture(view,item[3],item[2],current_node,"original artifact after ordinary scouting; guard state unchanged")
        await save_control(session,before,"scout_"+str(item[1]))
        session=SessionState.active_session
        if item[4]:
            var pickup_route: Array=seal_scout_route(session,item[3])
            check(pickup_route.size()>1,str(item[1])+" ordinary unguarded pickup route")
            if pickup_route.size()>1:
                var pickup: Dictionary=OverworldRules.try_move_along_route(session,pickup_route)
                check(bool(pickup.get("ok",false)),str(item[1])+" ordinary artifact pickup move")
                actions.append({"pickup":pickup})
            await enter_overworld()
            view=get_tree().current_scene._map_view
            var collected := false
            for node in session.overworld.artifact_nodes:
                if node.get("placement_id","")==item[1]:collected=bool(node.get("collected",false))
            check(collected,str(item[1])+" ordinary pickup collected the original artifact")
            check(not item[2] in view.validation_tile_presentation(item[3]).get("art_presentation",{}).get("sprite_asset_ids",[]),str(item[1])+" collected art is no longer drawn")
            before=normalized(session.to_dict())
            await save_control(session,before,"pickup_"+str(item[1]))
        authored.append({"scenario":item[0],"placement":original_node,"day":session.day,"actions":actions})
    before=normalized(session.to_dict())
    MusicAudio.stop_music("artifact_cutout_complete")
    AmbientAudio.stop_overworld_ambient("artifact_cutout_complete")
    await settle()
    await get_tree().create_timer(0.1).timeout
    check(int(MusicAudio.validation_summary().active_player_count)==0 and int(AmbientAudio.validation_summary().active_player_count)==0,"audio owners finish after gameplay")
    check(normalized(session.to_dict())==before,"probe teardown preserves full session")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"textures":textures,"routes":routes,"captures":captures,"galleries":galleries,"native_bodies":native_bodies,"affected_native":affected_native,"authored":authored,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
