"""39 Town mappings, unchanged native Towns and eleven real authored visits.

All-identity gallery inputs are detached. Gameplay uses original owned Town
records, normal Town vision and the existing selected-Town visit/exit actions.
"""
from overworld_legacy_cutout_probe import SCRIPT as LEGACY_SCRIPT

SCRIPT=LEGACY_SCRIPT.split('func run() -> void:',1)[0]
SCRIPT=SCRIPT.replace('label.text=key.trim_prefix("resource_site_neutral_").trim_prefix("hero_faction_").trim_prefix("generated_tree_")','''label.text=key.trim_prefix("town_identity_").trim_prefix("town_faction_").replace("_"," ")
            label.size=Vector2(cell.x-12,32)
            label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART''')
SCRIPT+=r'''
func enter_overworld() -> void:
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"ordinary saved Town exit")
        await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"ordinary Overworld entry")

func capture_town(view, session, town: Dictionary, category: String) -> void:
    # Native Town x/y is its source image anchor. Adoption restores a separate
    # visit_tile from the package; authored Towns use their original x/y.
    var visit: Dictionary=town.get("visit_tile",town)
    var tile:=Vector2i(int(visit.x),int(visit.y))
    check(view._town_entry_tile(town)==tile,str(town.town_id)+" source-owned visit tile, not image anchor")
    var asset_id: String=view._town_sprite_asset_id(town)
    var profile: Dictionary=view.validation_tile_presentation(tile).get("town_presentation",{})
    check(OverworldRules.is_tile_visible(session,tile.x,tile.y,int(town.get("level",0))),asset_id+" ordinary earned Town vision")
    check(normalized(view._town_at(tile))==normalized(town),asset_id+" complete original Town record indexed")
    check(profile.get("town_id","")==town.town_id and profile.get("sprite_asset_id","")==asset_id,asset_id+" real Town identity and art")
    check(profile.get("entry_tile",{})=={"x":tile.x,"y":tile.y},asset_id+" exact original doorway tile")
    check(bool(profile.get("entry_is_visit_tile",false)) and bool(profile.get("non_entry_tiles_blocked",false)),asset_id+" original entrance and body contract")
    check(not bool(profile.get("filled_underlay",true)) and not bool(profile.get("visible_helper_cues",true)),asset_id+" painted Town without procedural helper plate")
    await capture(view,tile,asset_id,town,category)

func run() -> void:
    get_tree().current_scene=null
    out=OS.get_environment("CUTOUT_OUTPUT")
    var bytes:=FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"independent expectations transferred unchanged")
    if not errors.is_empty():
        print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":false,"checks":checks,"errors":errors}))
        get_tree().quit(1)
        return
    var specs: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session=SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    await enter_overworld()
    check(int(session.day)==97,"unchanged earned native Day97 checkpoint")
    var before: Dictionary=normalized(session.to_dict())
    var view=get_tree().current_scene._map_view
    var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/overworld/manifest.json"))
    var textures:={}
    var routes:={}
    for asset_id in specs:
        var spec: Dictionary=specs[asset_id]
        check(view._object_asset_paths.get(asset_id,"")==spec.path,asset_id+" exact authoritative path")
        var texture=view._object_texture_for_asset(asset_id)
        check(texture is Texture2D,asset_id+" real raster without fallback")
        if not texture is Texture2D:continue
        var raster: Image=texture.get_image()
        if raster.is_compressed():check(raster.decompress()==OK,asset_id+" decompress")
        raster.convert(Image.FORMAT_RGBA8)
        var sha:=digest(raster.get_data())
        check(raster.get_size()==Vector2i(512,512),asset_id+" original-source 512px canvas")
        check(sha==spec.rgba_sha256,asset_id+" decoded RGBA matches independent full-atlas oracle")
        if spec.has("atlas_region"):
            check(texture is AtlasTexture,asset_id+" authoritative atlas retained")
            check(view._object_asset_regions.get(asset_id,[])==spec.atlas_region,asset_id+" exact fourfold normalized region")
        var town_id: String=spec.entry.get("assigned_town_id","")
        if town_id!="":
            check(not ContentService.get_town(town_id).is_empty(),asset_id+" real authored Town")
            check(view._town_identity_asset_ids.get(town_id,"")==asset_id,asset_id+" registered identity")
            check(view._town_sprite_asset_id({"town_id":town_id})==asset_id,asset_id+" identity priority over faction/default")
            routes[asset_id]={"town_id":town_id,"coverage":"detached exact resolver input; no world injection"}
        elif asset_id.begins_with("town_faction_"):
            var faction: String=asset_id.replace("town_faction_","faction_")
            check(view._town_faction_asset_ids.get(faction,"")==asset_id,asset_id+" registered original faction route")
            routes[asset_id]={"faction_id":faction,"coverage":"registered faction fallback; all normal identities keep priority"}
        else:
            check(view._town_default_asset_id==asset_id and view._town_sprite_asset_id({})==asset_id,"frontier original default retained for detached unknown identity")
            routes[asset_id]={"coverage":"detached unknown identity; no default injected into gameplay"}
        textures[asset_id]={"rgba_sha256":sha,"bounds":raster.get_used_rect()}
    check(specs.size()==39,"all 39 exact Town dispositions")
    var native_bodies:=0
    for body in view._generated_decorative_bodies_by_tile.values():
        if not body.get("generated_body_visual_anchor",false):continue
        native_bodies+=1
        var asset_id: String=view._decorative_object_asset_id(body)
        check(asset_id.begins_with("cohesive_") and view._object_texture_for_asset(asset_id) is Texture2D,"original native blocker palette retained")
    check(native_bodies==2380,"unchanged native collision-body pool")
    var native_towns:=[]
    for town in session.overworld.towns:
        native_towns.append(normalized(town))
        check(view._town_sprite_asset_id(town) in ["town_identity_riverwatch","town_identity_duskfen"],"native Town remains original preserved identity")
        await capture_town(view,session,town,"unchanged original earned native Town control")
    check(native_towns.size()==7 and captures.size()==2,"seven original native Towns; two unique unchanged paintings")
    var galleries: Array=await gallery(view,specs)
    await save_control(session,before,"native")
    var cases:=[
        ["third-hearths-confluence","town_cinderlock_bastion"],
        ["three-banner-field-commission","town_dawnmirror_observatory"],
        ["rootway-graftmarch","town_briarwheel_enclave"],
        ["ashen-clausemarch","town_cindercoil_foundry"],
        ["false-channel-pursuit","town_gloamwake_anchorage"],
        ["horizon-compact-six-citadels","town_rainwrit_bastion"],
        ["hollowreed-noonwire-dispute","town_hollowreed_sanctuary"],
        ["meridian-rootglass-appeal","town_meridian_choirhold"],
        ["crownroot-quenchline-verdict","town_crownroot_refuge"],
        ["blackbell-saltwake-foreclosure","town_blackbell_foundry"],
        ["pale-sounding-tidewrit-reckoning","town_pale_sounding_harbor"]]
    var authored:={}
    for item in cases:
        session=SessionState.set_active_session(ScenarioFactory.create_session(item[0],"normal",SessionState.LAUNCH_MODE_SKIRMISH))
        await enter_overworld()
        view=get_tree().current_scene._map_view
        var original_town:={}
        for town in session.overworld.towns:
            if town.town_id==item[1] and town.owner=="player":original_town=normalized(town)
        check(not original_town.is_empty(),str(item[1])+" real original owned Town")
        if original_town.is_empty():continue
        var hero_position: Vector2i=OverworldRules.hero_position(session)
        var resources: Dictionary=normalized(session.overworld.resources)
        await capture_town(view,session,original_town,"actual authored starting Town using ordinary ownership vision")
        var shell=get_tree().current_scene
        shell.validation_select_tile(int(original_town.x),int(original_town.y))
        check(shell._visit_selected_town(),str(item[1])+" normal selected-owned-Town visit action")
        await settle()
        check(get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"),str(item[1])+" real Town screen opened")
        if not get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):continue
        check(TownRules.get_active_town(session).get("town_id","")==item[1],str(item[1])+" exact active Town after visit")
        check(get_tree().current_scene.validation_leave_town().get("ok",false),str(item[1])+" normal Town exit")
        await settle()
        check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),str(item[1])+" ordinary return to Overworld")
        view=get_tree().current_scene._map_view
        check(normalized(view._town_at(Vector2i(int(original_town.x),int(original_town.y))))==original_town,str(item[1])+" Town buildings/garrison/recruits/ownership unchanged")
        check(OverworldRules.hero_position(session)==hero_position and normalized(session.overworld.resources)==resources,str(item[1])+" visit preserves hero coordinates and resources")
        before=normalized(session.to_dict())
        await save_control(session,before,str(item[0]))
        authored[item[1]]={"scenario_id":item[0],"day":session.day,"town":original_town,"normal_visit_and_exit":true}
    check(authored.size()==11 and captures.size()==13,"all eleven restored paintings captured in actual authored play plus two native controls")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"textures":textures,"routes":routes,"captures":captures,"galleries":galleries,"native_towns":native_towns,"native_bodies":native_bodies,"authored":authored,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''
