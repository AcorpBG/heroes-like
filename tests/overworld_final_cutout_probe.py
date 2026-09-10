"""Final 71 art routes; original native bodies and 29 ordinary encounter scouts."""
from overworld_recurring_cutout_probe import SCRIPT as ENCOUNTER_SCRIPT
from overworld_remaining_encounter_cutout_probe import SCRIPT as SCOUT_SCRIPT

SCRIPT = ENCOUNTER_SCRIPT.split('func run() -> void:', 1)[0]
SCRIPT = SCRIPT.replace('asset_id.begins_with("encounter_recurring_")', 'asset_id.begins_with("encounter_")')
SCRIPT = SCRIPT.replace('label.text=key.trim_prefix("encounter_recurring_")', 'label.text=key.trim_prefix("encounter_").replace("_"," ")\n            label.size=Vector2(cell.x-12,32)\n            label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART')
SCRIPT += 'func seal_scout_route(' + SCOUT_SCRIPT.split('func seal_scout_route(', 1)[1].split('func run() -> void:', 1)[0]
SCRIPT += r'''
func enter_overworld() -> void:
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary Town exit")
        await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"ordinary Overworld entry")

func run() -> void:
    get_tree().current_scene=null
    out=OS.get_environment("CUTOUT_OUTPUT")
    var bytes:=FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"complete independent expectations transferred unchanged")
    var specs: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
    check(specs.size()==71,"exact 71-row final complement")
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session=SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    await enter_overworld()
    check(int(session.day)==97,"original earned native Day97")
    var before: Dictionary=normalized(session.to_dict())
    var view=get_tree().current_scene._map_view
    var textures:={}
    var routes:={}
    var restored:=0
    for key in specs:
        var spec: Dictionary=specs[key]
        var entry: Dictionary=spec.entry
        check(view._object_asset_paths.get(key,"")==spec.path,key+" authoritative path")
        var texture=view._object_texture_for_asset(key)
        check(texture is Texture2D,key+" original raster without fallback")
        if not texture is Texture2D:continue
        var raster: Image=texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,key+" decompress")
        raster.convert(Image.FORMAT_RGBA8)
        check(raster.get_size()==Vector2i(int(spec.size[0]),int(spec.size[1])),key+" exact original-paint canvas")
        check(digest(raster.get_data())==spec.rgba_sha256,key+" independent decoded-raster oracle")
        if spec.has("atlas_region"):
            check(texture is AtlasTexture and view._object_asset_regions.get(key,[])==spec.atlas_region,key+" original atlas region preserved")
        if key.begins_with("encounter_"):
            var input:={"encounter_id":entry.assigned_encounter_id}
            check(view._encounter_identity_asset_id(input)==key,key+" exact identity route; detached input")
        elif key.begins_with("mapobj_"):
            check(view._standalone_map_object_asset_id({"object_id":entry.assigned_map_object_id})==key,key+" exact foundation identity")
        elif key.begins_with("cohesive_"):
            check(view._decorative_object_asset_id({"overworld_sprite_asset_id":key})==key,key+" original explicit body art route")
        elif key.begins_with("ownership_pennant_"):
            check(view._ownership_pennant_asset_id(key.trim_prefix("ownership_pennant_"))==key,key+" original ownership pennant route")
        else:
            check(key=="hostile_camp" and view._encounter_asset_id({})==key,"original camp default; detached unknown input only")
        if spec.mode=="creature_silhouette":
            restored+=1
            check(spec.path.begins_with("res://art/overworld/runtime/objects/encounters/creature_silhouettes/"),key+" world cutout separate from unit UI")
            check(not texture is AtlasTexture,key+" exact standalone original creature")
        textures[key]={"rgba_sha256":digest(raster.get_data()),"size":raster.get_size(),"bounds":raster.get_used_rect()}
        routes[key]={"path":spec.path,"mode":spec.mode,"coverage":"detached authoritative resolver; no world injection"}
    check(restored==29,"29 exact creature silhouettes; 42 unchanged controls")
    var native_bodies:=0
    var native_assets:={}
    for body in view._generated_decorative_bodies_by_tile.values():
        if not body.get("generated_body_visual_anchor",false):continue
        native_bodies+=1
        var asset_id: String=view._decorative_object_asset_id(body)
        check(specs.has(asset_id) and asset_id.begins_with("cohesive_"),"original native body remains in exact reviewed palette")
        check(view._object_texture_for_asset(asset_id) is Texture2D,"native body original raster available")
        native_assets[asset_id]=true
        var tile:=Vector2i(int(body.x),int(body.y))
        if not captured.has(asset_id) and OverworldRules.is_tile_visible(session,tile.x,tile.y,int(body.get("level",0))):
            await capture(view,tile,asset_id,body,"unchanged original earned native blocker control")
    check(native_bodies==2380 and not captures.is_empty(),"2380 original native bodies; natural visible controls")
    var affected_native:=[]
    for encounter in session.overworld.encounters:
        var asset_id: String=view._encounter_identity_asset_id(encounter)
        if specs.has(asset_id):affected_native.append({"asset_id":asset_id,"placement":normalized(encounter),"resolved":OverworldRules.is_encounter_resolved(session,encounter)})
    var galleries: Array=await gallery(view,specs)
    await save_control(session,before,"native")
    var cases:=[
        ["encounter_auxiliary_canopy_breachers","three-hearth-auxiliary-charter","auxiliary_canopy_breachers"],
        ["encounter_auxiliary_redline_lancers","three-hearth-auxiliary-charter","auxiliary_redline_lancers"],
        ["encounter_auxiliary_wakeglass_pilots","three-hearth-auxiliary-charter","auxiliary_wakeglass_pilots"],
        ["encounter_commission_beaconline_writguard","three-banner-field-commission","commission_beaconline_writguard"],
        ["encounter_commission_fenbell_chainstalkers","glassmarshal-fenbell-refraction","glassmarshal_front_2"],
        ["encounter_commission_zenith_lensbearers","reedscript-murkward-three-hook-garrison-warrant","murkwardwarrant_warrant_guard"],
        ["encounter_elite_cinderwake_fold_watch","beaconscribe-frostbeacon-circuit","beaconscribe_cinderwake_fold_watch"],
        ["encounter_elite_tideglass_roost_watch","vowless-saltpan-circuit","vowless_tideglass_roost_watch"],
        ["encounter_horizon_specialist_quenchbell_proving","heatpriest-redgauge-fogbreak-survey","redgauge_west_guard"],
        ["encounter_horizon_specialist_saltwake_recital","vowless-drowned-horizon-fogbreak-survey","drownedhorizon_west_guard"],
        ["encounter_horizon_specialist_seedglass_trial","seedseer-rootstar-fogbreak-survey","rootstar_west_guard"],
        ["encounter_frontier_mythic_cindervane_updraft_roost_watch","emberwell-censerwing-updraft","cindervane_updraft_roost_front_1"],
        ["encounter_frontier_mythic_fenmirror_shell_basin_watch","fenhook-fenmirror-muster","fenmirror_shell_basin_front_1"],
        ["encounter_frontier_mythic_gaugecoil_pressure_burrow_watch","debtrune-gaugecoil-burrow","gaugecoil_pressure_burrow_front_1"],
        ["encounter_frontier_mythic_gloambell_sounding_deep_watch","mistcorsair-gloambell-sounding","gloambell_sounding_deep_front_1"],
        ["encounter_frontier_mythic_knotstag_root_court_watch","boltroot-knotstag-circuit","knotstag_root_court_front_1"],
        ["encounter_frontier_mythic_prismwake_refraction_shelf_watch","glasswind-prismwake-crossing","prismwake_refraction_shelf_front_1"],
        ["encounter_sovereign_wild_ashcrown_cinderfold_watch","tollbrand-toll-chain-muster","tollchain_front_1"],
        ["encounter_sovereign_wild_miremoon_crownmere_watch","fenwake-bogbell-convergence","fenwake_miremoon_crownmere_watch"],
        ["encounter_sovereign_wild_noonshard_prism_aviary_watch","sunvein-sun-thread-muster","sunthread_front_1"],
        ["encounter_sovereign_wild_quenchbell_pressure_den_watch","debtrune-debt-seal-muster","debtseal_front_2"],
        ["encounter_sovereign_wild_rootvault_heartwood_hollow_watch","graftsibyl-lantern-convergence","graftsibyl_rootvault_heartwood_watch"],
        ["encounter_sovereign_wild_saltwake_belldeep_watch","mistcorsair-fog-sail-muster","fogsail_front_2"],
        ["encounter_unbound_wild_brambleback_hedgecourt_watch","loamchant-chorus-bough-muster","chorusbough_front_1"],
        ["encounter_unbound_wild_flaremast_pilotage_watch","mistcorsair-flaremast-concord","flaremastconcord_dwelling_guard"],
        ["encounter_unbound_wild_mireglass_bellfen_watch","mudkeel-mireglass-concord","mireglassconcord_dwelling_guard"],
        ["encounter_unbound_wild_sapwhistle_greenward_watch","thorncart-greenbranch-concord","greenbranchconcord_dwelling_guard"],
        ["encounter_unbound_wild_scarshield_breakyard_watch","varn-scarshield-concord","scarshieldconcord_dwelling_guard"],
        ["encounter_unbound_wild_windcairn_wayhouse_watch","daynote-windcairn-concord","windcairnconcord_dwelling_guard"]]
    var authored:={}
    for item in cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(item[1],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        await enter_overworld()
        var original:={}
        for encounter in session.overworld.encounters:
            if encounter.get("placement_id","")==item[2]:original=normalized(encounter)
        check(not original.is_empty(),str(item[2])+" original authored encounter exists")
        if original.is_empty():continue
        var tile:=Vector2i(int(original.x),int(original.y))
        var actions:=[]
        for attempt in range(8):
            if OverworldRules.is_tile_visible(session,tile.x,tile.y):break
            var route: Array=legal_scout_route(session,tile)
            check(route.size()>1,str(item[2])+" legal ordinary scouting route")
            if route.size()<2:break
            var position: Vector2i=OverworldRules.hero_position(session)
            var travel: Dictionary=OverworldRules.try_move_along_route(session,route)
            actions.append({"route":route,"travel":travel})
            if OverworldRules.is_tile_visible(session,tile.x,tile.y):break
            check(OverworldRules.hero_position(session)!=position or int(session.overworld.get("movement_points",0))==0,str(item[2])+" real scouting progress")
            var turn: Dictionary=OverworldRules.end_turn(session)
            check(bool(turn.get("ok",false)),str(item[2])+" ordinary scouting end turn")
            actions.append({"turn":turn})
        await enter_overworld()
        view=get_tree().current_scene._map_view
        var current:={}
        for encounter in session.overworld.encounters:
            if encounter.get("placement_id","")==item[2]:current=encounter
        check(normalized(current)==original,str(item[2])+" entire encounter/army/coordinates/masks preserved")
        check(not OverworldRules.is_encounter_resolved(session,current),str(item[2])+" original front remains unresolved")
        check(OverworldRules.is_tile_visible(session,tile.x,tile.y),str(item[2])+" normal earned visibility")
        check(view._encounter_identity_asset_id(current)==item[0],str(item[2])+" exact creature identity")
        var profile: Dictionary=view._enemy_commander_presentation_payload(current)
        check(not profile.get("uses_unit_icon_fallback",true) and profile.get("uses_identity_encounter_sprite",false),str(item[2])+" actual renderer uses original creature, not UI badge fallback")
        check(profile.get("identity_encounter_path","")==specs[item[0]].path,str(item[2])+" exact separate world sprite")
        before=normalized(session.to_dict())
        await capture(view,tile,item[0],current,"actual original encounter after ordinary scouting")
        await save_control(session,before,item[2])
        authored[item[0]]={"scenario_id":item[1],"day":session.day,"encounter":original,"actions":actions,"presentation":profile}
    check(authored.size()==29,"all 29 restored creature paintings in original authored play")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"textures":textures,"routes":routes,"captures":captures,"galleries":galleries,"native_bodies":native_bodies,"native_assets":native_assets.keys(),"affected_native":affected_native,"authored":authored,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
