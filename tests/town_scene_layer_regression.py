#!/usr/bin/env python3
"""Exact-faction scene assets, cover-crop input and normal construction/save."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT
from generated_town_order_profile import run_probe
import town_overlay_ownership_regression as overlay

LATE_HARBOR_IDS = [
    'building_veilmourn_drowned_map_room', 'building_veilmourn_mistgate_slip',
    'building_veilmourn_memory_anchor', 'building_veilmourn_leviathan_sounding',
    'building_veilmourn_drowned_admiralty', 'building_veilmourn_memory_rite_court',
    'building_veilmourn_saltwake_factor',
]
LATE_HARBOR_SAVE_SHA256 = '69f4c289bb0bd273f175e24a0b2704391302c0cf2dcc0be76c4d487f91886537'
EMBERCOURT_SAVE_SHA256 = 'c0d67e4b2a8403ac82ae599391ae0a946ea16110beb4dd378a599af9a9ab7a59'
EMBERCOURT_DEVELOPED_SHA256 = '553ceb3ea972412cd72341ff627fa73c6864f9bcbfb6cc428923ebec5712de59'
EMBERCOURT_IDS = ['building_muster_yard', 'building_wayfarers_hall', 'building_market_square']
EMBERCOURT_GROWTH_IDS = ['building_stone_store', 'building_watch_barracks', 'building_bowyer_lodge', 'building_beacon_range']
EMBERCOURT_GROWTH_SAVE_SHA256 = '838606e03fc1dffd5cf5c2b79ca5d20cc59c77ecfb42b831005577d449652d18'
EMBERCOURT_SUPPLY_IDS = ['building_river_granary_exchange', 'building_quartermasters_depot', 'building_lantern_archive', 'building_starseer_annex', 'building_citadel_pikehall']
EMBERCOURT_SUPPLY_SAVE_SHA256 = '48ed86fb4babfd21b5aab898baae06e7bc3f2d45ba91a182d29260c01551e963'
EMBERCOURT_RIVERWORKS_IDS = ['building_embercourt_granary_lock_exchange', 'building_embercourt_lockhouse_tally', 'building_embercourt_tollstone_weir', 'building_embercourt_bargebow_slip', 'building_embercourt_oath_pikehall', 'building_embercourt_beacon_writs']
EMBERCOURT_RIVERWORKS_SAVE_SHA256 = '6c24033ca1d35971c9ca5b50fee30bed47cb0992fdfe737d07767839ca445d66'
EMBERCOURT_CIVIC_IDS = ['building_embercourt_lantern_court', 'building_embercourt_relief_quay']
EMBERCOURT_CIVIC_SAVE_SHA256 = '9f7dcbf9f69d49e21d9404d042e63e388c5ce959411af738dcf9b7422ff1884e'

EXTRA = r'''
func inspect_upgrade_order() -> void:
	var stage=get_tree().current_scene.get_node("%TownStage")
	var before: Dictionary=normalized(session.to_dict())
	var tested := 0
	for faction in stage._building_scene_layout_manifest.factions:
		for plot in stage._building_scene_layout_manifest.factions[faction].plots:
			var variants: Array=plot.building_ids
			for id in variants:
				var base: String=ContentService.get_building(id).get("upgrade_from","")
				if base=="" or base not in variants: continue
				for order in [[base,id],[id,base]]:
					check(stage._visible_town_plot_building_id(order,[])=="","unbuilt upgrade plot became visible")
					check(stage._visible_town_plot_building_id(order,[base])==base,"unbuilt upgrade hides its base: "+id)
					check(stage._visible_town_plot_building_id(order,[id])==id,"upgrade-only compatible state selects a missing base: "+id)
					check(stage._visible_town_plot_building_id(order,[base,id])==id,"plot order selects predecessor: "+id)
					check(stage._visible_town_plot_building_id(order,[id,base])==id,"saved-id order selects predecessor: "+id)
				tested+=1
	check(tested>0,"no authored upgrade relationships exercised")
	check(stage._visible_town_plot_building_id(["building_wayfarers_hall","building_market_square"],["building_market_square","building_wayfarers_hall"])=="building_market_square","unrelated plot order changed")
	check(normalized(session.to_dict())==before,"visual upgrade selection mutated gameplay")
	rows.append({"label":"authored_upgrade_order_controls","authored_relationships":tested})

func layer_changed_paths(before, after, prefix: String = "", found: Array = []) -> Array:
	if before==after or found.size()>=20: return found
	if before is Dictionary and after is Dictionary:
		for key in before:
			if not after.has(key): found.append(prefix+"/"+str(key))
			else: layer_changed_paths(before[key],after[key],prefix+"/"+str(key),found)
		for key in after:
			if not before.has(key): found.append(prefix+"/"+str(key))
	elif before is Array and after is Array and before.size()==after.size():
		for i in range(before.size()): layer_changed_paths(before[i],after[i],prefix+"/"+str(i),found)
	else: found.append(prefix)
	return found
func layer_action(name: String) -> void:
	for pressed in [true,false]:
		var event := InputEventAction.new()
		event.action=name;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func layer_click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func layer_controller(button_index: int) -> void:
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=button_index;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func clear_layer_capture_focus() -> void:
	get_viewport().gui_release_focus()
	var motion := InputEventMouseMotion.new()
	motion.position=get_viewport().get_final_transform()*Vector2(640,20)
	Input.parse_input_event(motion)
	await settle()
func inspect_catalog_pixel_ownership(stage) -> void:
	var catalog_count := 0
	for entry in stage._town_building_scene_entries(stage._town_scene_rect()):
		var id: String=entry.visible_building_id
		if id=="" or entry.get("embedded_in_base",false) or entry.get("scene_layer",false): continue
		var button=stage._building_hotspots.get(id)
		check(button!=null and button.visible and button.painted_mask!=null,"catalog building still has rectangular pointer ownership: "+id)
		if button==null or not button.visible: continue
		var raster: Image=stage._town_building_texture(id).get_image()
		var ratio: Rect2=entry.texture_region_ratio
		var transparent := 0
		var painted := 0
		for y in range(1,20):
			for x in range(1,20):
				var pixel := Vector2i(Vector2(x/20.0,y/20.0)*Vector2(raster.get_size()))
				var uv := ((Vector2(pixel)+Vector2(0.5,0.5))/Vector2(raster.get_size())-ratio.position)/ratio.size
				if not Rect2(Vector2.ZERO,Vector2.ONE).has_point(uv): continue
				var solid: bool=raster.get_pixelv(pixel).a>0.25
				check(button._has_point(uv*button.size)==solid,"catalog transparent/cropped pixel intercepts scenery: "+id)
				if solid: painted+=1
				else: transparent+=1
		check(painted>0 and transparent>0,"catalog pixel control did not exercise both body and empty margin: "+id)
		catalog_count+=1
	rows.append({"label":"independent_catalog_pixel_ownership","faction":stage._town_faction_id(),"catalog_buildings":catalog_count})
func inspect_scene_layers(ids: Array = ["building_veilmourn_bell_harbor", "building_wayfarers_hall"]) -> void:
	var shell = get_tree().current_scene
	var stage = shell.get_node("%TownStage")
	var before: Dictionary = normalized(session.to_dict())
	var rows: Array = stage.validation_town_building_progression_summary().texture_rows
	UiAccessibility.refresh_tree(stage)
	inspect_catalog_pixel_ownership(stage)
	for id in ids:
		var matches: Array = rows.filter(func(row): return row.building_id == id)
		var expected := "res://art/towns/runtime/scene_layers/%s/%s.png" % [stage._town_faction_id(),id]
		check(matches.size()==1 and matches[0].texture_path==expected,"scenery still resolves catalog icon rather than exact faction layer: "+id)
		if matches.size()!=1 or matches[0].texture_path!=expected:
			continue # A missing layer is already a failure, not valid alpha/input evidence.
		var summary: Dictionary = stage.validation_building_hotspot_summary(id)
		check(summary.aligned and summary.visible and summary.focus_mode==Control.FOCUS_ALL,"scene layer focus/crop alignment: "+id)
		if not summary.visible: continue # Keep the failed assertion; never index a superseded plot as a visible one.
		check(summary.accessibility_name==ContentService.get_building(id).name+" building","missing exact building accessible name: "+id+" got "+str(summary.accessibility_name))
		var button = stage._building_hotspots[id]
		var texture: Texture2D = stage._town_building_texture(id)
		var raster := texture.get_image()
		var entry: Dictionary = stage._town_building_scene_entries(stage._town_scene_rect()).filter(func(e):return e.visible_building_id==id)[0]
		var ratio: Rect2 = entry.texture_region_ratio
		check(absf((entry.normalized_rect.size.x*1600.0)/(entry.normalized_rect.size.y*900.0)-texture.get_width()/float(texture.get_height()))<0.005,"non-square layer aspect changed: "+id)
		var opaque := Vector2(-1,-1)
		var transparent := Vector2(-1,-1)
		for y in range(1,20):
			for x in range(1,20):
				# Sample source pixel centers, not exact pixel boundaries whose
				# float32 screen round-trip may legitimately choose either neighbor.
				var pixel := Vector2i(Vector2(x/20.0,y/20.0)*Vector2(raster.get_size()))
				var uv := ((Vector2(pixel)+Vector2(0.5,0.5))/Vector2(raster.get_size())-ratio.position)/ratio.size
				if not Rect2(Vector2.ZERO,Vector2.ONE).has_point(uv): continue
				var painted: bool = raster.get_pixelv(pixel).a>0.25
				var point: Vector2 = uv*button.size
				check(button._has_point(point)==painted,"painted-alpha/cover-crop pointer ownership: "+id)
				if painted and opaque.x<0: opaque=point
				if not painted and transparent.x<0: transparent=point
		check(opaque.x>=0 and transparent.x>=0,"layer must have both solid and transparent pixels: "+id)
		var presses := [0]
		var observe := func(): presses[0]+=1
		button.pressed.connect(observe)
		await layer_click(button.get_global_transform_with_canvas()*transparent)
		check(presses[0]==0,"transparent image margin intercepted click: "+id)
		if shell._town_catalog_is_open(): shell._close_town_catalog(false)
		# Use an opaque body point outside the main-building overlap for actual pointer input.
		var body := Vector2(0.62,0.36) if id=="building_veilmourn_bell_harbor" else Vector2(0.55,0.60)
		if id=="building_quartermasters_depot" and stage._town_faction_id()=="faction_embercourt":
			# The Watch court is legitimately in front of the depot's left
			# facade. Prove that overlap, then use the exposed supply roof.
			var overlap: Vector2=button.get_global_transform_with_canvas()*(body*button.size)
			var watch=stage._building_hotspots["building_watch_barracks"]
			check(watch._has_point(watch.get_global_transform_with_canvas().affine_inverse()*overlap),"Depot overlap is not painted by foreground Watch")
			await layer_click(overlap)
			var foreground: Dictionary=shell.validation_building_information_snapshot("building_watch_barracks")
			check(presses[0]==0 and foreground.open and foreground.mode=="building_info" and foreground.title==foreground.expected_title,"foreground Watch did not own its Depot overlap")
			shell._close_town_catalog(false)
			body=Vector2(0.80,0.35)
		if id=="building_lantern_archive" and stage._town_faction_id()=="faction_embercourt": body=Vector2(0.50,0.30) # Solid records roof above the foreground granary.
		if id=="building_starseer_annex" and stage._town_faction_id()=="faction_embercourt": body=Vector2(0.80,0.10) # Solid turret roof above the open observation balcony and foreground granary.
		if id=="building_embercourt_oath_pikehall":
			if stage.validation_building_hotspot_summary("building_embercourt_lantern_court").get("visible",false):
				var overlap: Vector2=button.get_global_transform_with_canvas()*(Vector2(0.40,0.28)*button.size)
				var lantern=stage._building_hotspots["building_embercourt_lantern_court"]
				# The old catalog silhouette covers this roof; the lower scenic
				# arcade can expose it. Actual foreground alpha owns the click.
				var lantern_painted: bool=lantern._has_point(lantern.get_global_transform_with_canvas().affine_inverse()*overlap)
				check(lantern_painted or button._has_point(Vector2(0.40,0.28)*button.size),"Lantern/Oath overlap has no painted owner")
				var expected_owner: String="building_embercourt_lantern_court" if lantern_painted else id
				await layer_click(overlap)
				var foreground: Dictionary=shell.validation_building_information_snapshot(expected_owner)
				check(presses[0]==(0 if lantern_painted else 1) and foreground.open and foreground.mode=="building_info" and foreground.title==foreground.expected_title,"Lantern/Oath pointer ownership disagrees with the painted foreground")
				shell._close_town_catalog(false)
				presses[0]=0 # The independently checked overlap is not the body-click control below.
			if stage.validation_building_hotspot_summary("building_embercourt_bargebow_slip").get("visible",false):
				var overlap: Vector2=button.get_global_transform_with_canvas()*(Vector2(0.15,0.28)*button.size)
				var slip=stage._building_hotspots["building_embercourt_bargebow_slip"]
				check(slip._has_point(slip.get_global_transform_with_canvas().affine_inverse()*overlap),"Oath left-roof overlap is not painted by foreground Bargebow Slip")
				await layer_click(overlap)
				var foreground: Dictionary=shell.validation_building_information_snapshot("building_embercourt_bargebow_slip")
				check(presses[0]==0 and foreground.open and foreground.mode=="building_info" and foreground.title==foreground.expected_title,"foreground Bargebow Slip did not own its visible Oath roof overlap")
				shell._close_town_catalog(false)
			body=Vector2(0.90,0.35) # Exposed right gable, beyond the foreground Slip and Lantern Court silhouettes.
		if id=="building_veilmourn_salvage_ledger" and stage.validation_building_hotspot_summary("building_veilmourn_salt_counting_house").get("visible",false):
			# The treasury is visibly in front of the Ledger's lower facade.
			# Prove the foreground painting owns that overlap, then click the
			# still-exposed Ledger roof; never give a hidden rear pixel priority.
			var overlap: Vector2 = button.get_global_transform_with_canvas()*(body*button.size)
			var treasury = stage._building_hotspots["building_veilmourn_salt_counting_house"]
			check(treasury._has_point(treasury.get_global_transform_with_canvas().affine_inverse()*overlap),"Ledger overlap is not painted by foreground treasury")
			await layer_click(overlap)
			var foreground: Dictionary = shell.validation_building_information_snapshot("building_veilmourn_salt_counting_house")
			check(presses[0]==0 and foreground.open and foreground.mode=="building_info" and foreground.title==foreground.expected_title,"foreground treasury did not own its visible Ledger overlap")
			shell._close_town_catalog(false)
			body=Vector2(0.55,0.25)
		if id=="building_veilmourn_fog_signal_buoys": body=Vector2(0.55,0.82) # Central floating hull, not the open bell-frame gap.
		if id=="building_veilmourn_mourner_pilot_guild": body=Vector2(0.32,0.35) # Lookout remains exposed behind later waterfront buildings.
		if id=="building_veilmourn_bell_chain_watch": body=Vector2(0.35,0.20) # Upper bell, not the open frame behind the Market.
		if id=="building_veilmourn_wake_oratory": body=Vector2(0.80,0.60) # Right-hand funeral cloth, below expanded specialty/command controls and above the Drydock.
		if id=="building_veilmourn_tideglass_chapel": body=Vector2(0.55,0.40) # Exposed tideglass roof above the foreground Ledger.
		if id=="building_veilmourn_black_sail_loft": body=Vector2(0.35,0.35) # Exposed workshop roof above the foreground Harpoon Gantry.
		if id=="building_veilmourn_drowned_map_room": body=Vector2(0.55,0.35) # Navigation roof above the foreground sail workshop.
		if id=="building_veilmourn_memory_anchor": body=Vector2(0.55,0.60) # Exposed iron shank on the counting-house quay.
		if id=="building_veilmourn_leviathan_sounding": body=Vector2(0.65,0.16) # Right acoustic horn above foreground bell docks.
		if id=="building_veilmourn_memory_rite_court": body=Vector2(0.67,0.18) # Right acoustic horn remains exposed after the rite upgrade.
		if id=="building_veilmourn_drowned_admiralty": body=Vector2(0.50,0.25) # Navigation turret above Wayfarers Hall.
		if id=="building_market_square" and stage._town_faction_id()=="faction_embercourt" and stage.validation_building_hotspot_summary("building_embercourt_charter_flame").get("visible",false):
			var overlap: Vector2=button.get_global_transform_with_canvas()*(Vector2(0.80,0.68)*button.size)
			var flame=stage._building_hotspots["building_embercourt_charter_flame"]
			check(flame._has_point(flame.get_global_transform_with_canvas().affine_inverse()*overlap),"developed Market overlap is not painted by foreground Charter Flame")
			await layer_click(overlap)
			var foreground: Dictionary=shell.validation_building_information_snapshot("building_embercourt_charter_flame")
			check(presses[0]==0 and foreground.open and foreground.mode=="building_info" and foreground.title==foreground.expected_title,"foreground Charter Flame did not own its visible Market overlap")
			shell._close_town_catalog(false)
			body=Vector2(0.28,0.60) # Exposed weigh-house facade to the left of the later civic flame.
		if id=="building_market_square" and stage.validation_building_hotspot_summary("building_veilmourn_obituary_vault").get("visible",false):
			var overlap: Vector2 = button.get_global_transform_with_canvas()*(body*button.size)
			var vault = stage._building_hotspots["building_veilmourn_obituary_vault"]
			check(vault._has_point(vault.get_global_transform_with_canvas().affine_inverse()*overlap),"Market overlap is not painted by foreground Vault")
			await layer_click(overlap)
			var foreground: Dictionary = shell.validation_building_information_snapshot("building_veilmourn_obituary_vault")
			check(presses[0]==0 and foreground.open and foreground.mode=="building_info" and foreground.title==foreground.expected_title,"foreground Vault did not own its visible Market overlap")
			shell._close_town_catalog(false)
			body=Vector2(0.70,0.35) # Exposed right-hand trading canopy, not the concealed lower counter.
		check(button._has_point(body*button.size),"authored pointer test point is not painted: "+id)
		if not button._has_point(body*button.size):
			button.pressed.disconnect(observe)
			continue # Do not send Escape to the Town itself after a failed modal-open assertion.
		await layer_click(button.get_global_transform_with_canvas()*(body*button.size))
		var info: Dictionary = shell.validation_building_information_snapshot(id)
		check(presses[0]==1 and info.open and info.mode=="building_info" and info.title==info.expected_title,"painted pointer did not open exact building info: "+id)
		if not info.open or info.mode!="building_info":
			button.pressed.disconnect(observe)
			continue
		check(shell._building_info_icon.texture!=null and shell._building_info_icon.texture.resource_path==TownRules.building_icon_path(id),"scene layer replaced separate catalog/info icon: "+id)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(id+"_info.png"))
		await layer_action("ui_cancel")
		check(not shell._town_catalog_is_open(),"Escape did not dismiss info: "+id)
		check(get_viewport().gui_get_focus_owner()==button,"normal information close did not restore the building button: "+id)
		check(button.accessibility_name==ContentService.get_building(id).name+" building","focus refresh overwrote authored building identity: "+id)
		button.grab_focus()
		await layer_action("ui_accept")
		check(shell.validation_building_information_snapshot(id).title==ContentService.get_building(id).name and shell._town_catalog_is_open(),"keyboard did not open exact info: "+id)
		await layer_action("ui_cancel")
		button.grab_focus()
		await layer_controller(JOY_BUTTON_A)
		check(shell.validation_building_information_snapshot(id).title==ContentService.get_building(id).name and shell._town_catalog_is_open(),"controller A did not open exact info: "+id)
		await layer_controller(JOY_BUTTON_B)
		check(not shell._town_catalog_is_open(),"controller B did not dismiss info: "+id)
		button.pressed.disconnect(observe)
	# The main building still owns the authoritative construction route.
	var build: Dictionary = shell.validation_activate_main_building_hotspot()
	check(build.same_authoritative_build_route,"main building no longer opens the construction ledger")
	shell._close_town_catalog(false)
	# Detached view-only cache/negative mapping boundaries, never authored content mutation.
	var template: Dictionary = stage._town_template
	stage._town_template=template.duplicate(true)
	var faction: String=stage._town_faction_id()
	var other_faction := "faction_veilmourn" if faction=="faction_embercourt" else "faction_embercourt"
	stage._town_template.faction_id=other_faction
	check(stage._town_building_texture("building_wayfarers_hall").resource_path=="res://art/towns/runtime/scene_layers/%s/building_wayfarers_hall.png" % other_faction,"scenic texture leaked across faction cache keys")
	stage._town_template=template
	var manifest: Dictionary = stage._building_scene_art_manifest
	stage._building_scene_art_manifest=manifest.duplicate(true)
	stage._building_scene_art_manifest.factions[faction].building_wayfarers_hall.runtime_path="res://missing-declared-town-layer.png"
	check(stage._town_building_texture("building_wayfarers_hall")==null,"missing declared art fell back to catalog")
	stage._building_scene_art_manifest.factions[faction].building_wayfarers_hall={}
	check(stage._town_building_texture("building_wayfarers_hall")==null,"malformed declared art fell back to catalog")
	stage._building_scene_art_manifest=manifest
	check(stage._town_building_texture("building_wayfarers_hall").resource_path=="res://art/towns/runtime/scene_layers/%s/building_wayfarers_hall.png" % faction,"negative asset cache poisoned restored exact mapping")
	check(normalized(session.to_dict())==before,"scene asset inspection mutated gameplay")
func inspect_market_unbuilt() -> void:
	var town: Dictionary = TownRules.get_active_town(session)
	check(not "building_market_square" in town.built_buildings,"real opening already has the Market Square")
	check(not get_tree().current_scene.get_node("%TownStage").validation_building_hotspot_summary("building_market_square").visible,"unbuilt market is visible/clickable")
func inspect_market_constructed() -> void:
	var before: Dictionary = normalized(session.to_dict())
	var town: Dictionary = TownRules.get_active_town(session)
	check("building_market_square" in town.built_buildings,"real offered paid build was not Market Square")
	check(int(town.last_build_day)==int(session.day),"market did not consume the normal daily build")
	var enabled: Array = TownRules.get_build_actions(session).filter(func(a):return not a.get("disabled",true) and String(a.id).begins_with("build:"))
	check(enabled.is_empty(),"same-day market build incorrectly leaves construction enabled")
	await inspect_scene_layers(["building_market_square"])
	check(normalized(session.to_dict())==before,"post-build market information changed gameplay")
	var path: String = SaveService.save_session(session.to_dict(),3)
	session=SessionState.restore_session(SaveService.load_session(3))
	check(path!="" and normalized(session.to_dict())==before,"constructed market changed complete save/resume")
	AppRouter.go_to_town()
	await settle()
	var stage = get_tree().current_scene.get_node("%TownStage")
	check(stage.validation_building_hotspot_summary("building_market_square").visible,"constructed market disappeared on real saved Town re-entry")
	check(stage._town_building_texture_path("building_market_square")=="res://art/towns/runtime/scene_layers/%s/building_market_square.png" % stage._town_faction_id(),"saved market re-entry lost exact scenic art")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("market_saved_reentry.png"))
func layer_visibility_fixture() -> void:
	# These two structures are authored starting buildings, not purchasable orders.
	# Detached built-id visibility boundary only; normal paid construction is tested above.
	var fixture = SessionState.restore_session(normalized(session.to_dict()))
	var town: Dictionary = TownRules.get_active_town(fixture)
	town.built_buildings.erase("building_wayfarers_hall")
	town.last_build_day=0
	AppRouter.go_to_town()
	await settle()
	var shell = get_tree().current_scene
	var stage = shell.get_node("%TownStage")
	check(not stage.validation_building_hotspot_summary("building_wayfarers_hall").visible,"unbuilt scenic building is still visible/clickable")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("fixture_hall_unbuilt.png"))
	var offers: Array = TownRules.get_build_actions(fixture).filter(func(a):return a.id=="build:building_wayfarers_hall" and not a.get("disabled",true))
	check(offers.is_empty(),"starting-building art migration changed the authored construction catalog")
	town.built_buildings.append("building_wayfarers_hall")
	AppRouter.go_to_town()
	await settle()
	shell=get_tree().current_scene
	stage=shell.get_node("%TownStage")
	check(stage.validation_building_hotspot_summary("building_wayfarers_hall").visible,"restored built-id scenic layer/hotspot absent")
	var info: Dictionary = shell.validation_activate_building_information("building_wayfarers_hall")
	check(info.open and info.title=="Wayfarers Hall","restored built-id does not route exact info")
	shell._close_town_catalog(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("fixture_hall_built.png"))
	var path: String = SaveService.save_session(fixture.to_dict(),3)
	var restored = SessionState.restore_session(SaveService.load_session(3))
	check(path!="" and normalized(restored.to_dict())==normalized(fixture.to_dict()),"scene-layer built ids changed complete save/resume")
	rows.append({"label":"detached_starting_building_visibility_not_construction","built_ids":TownRules.get_active_town(fixture).built_buildings,"save_unchanged":normalized(restored.to_dict())==normalized(fixture.to_dict())})
'''

SCRIPT = overlay.SCRIPT.replace('await inspect("opening")', 'await inspect("opening")\n\tawait inspect_scene_layers()\n\tawait inspect_market_unbuilt()') + EXTRA
SCRIPT = SCRIPT.replace('print("TOWN_OVERLAY_OWNERSHIP "', 'await layer_visibility_fixture()\n\tprint("TOWN_OVERLAY_OWNERSHIP "')
SCRIPT = SCRIPT.replace('get_tree().current_scene._commit_build_action(building_id)', 'var paid_before: Dictionary = normalized(session.overworld.resources)\n\t\tvar cost: Dictionary = offered[0].cost\n\t\tget_tree().current_scene._commit_build_action(building_id)')
SCRIPT = SCRIPT.replace('await inspect("after_build")', 'for resource in cost:\n\t\t\tcheck(int(session.overworld.resources[resource])==int(paid_before[resource])-int(cost[resource]),"ordinary construction resource cost changed: "+resource)\n\t\tawait inspect("after_build")')
SCRIPT = SCRIPT.replace('await inspect("after_build")', 'await inspect("after_build")\n\t\tawait inspect_market_constructed()')

HARBOR_GROWTH = r'''
func inspect_harbor_growth() -> void:
	var placement: String = TownRules.get_active_town(session).placement_id
	var previous_id := "building_market_square"
	for id in __GROWTH_IDS__:
		print("HARBOR_GROWTH_BEGIN "+id+" "+str(Time.get_ticks_msec()))
		var shell = get_tree().current_scene
		check(not shell.get_node("%TownStage").validation_building_hotspot_summary(id).visible,"unbuilt growth layer is visible: "+id)
		var day_before: int = session.day
		var prior_info: Dictionary=shell.validation_activate_building_information(previous_id)
		check(prior_info.open,"immediate departure control did not open existing building information")
		shell._on_town_catalog_close_pressed()
		shell._on_leave_pressed()
		for frame in range(8): await get_tree().process_frame
		var field = get_tree().current_scene
		check(field.scene_file_path=="res://scenes/overworld/OverworldShell.tscn","normal Town departure did not reach Overworld")
		var turn: Dictionary = field.validation_request_end_turn()
		if turn.get("confirmation_required",false):
			turn=field.validation_confirm_end_turn()
		for frame in range(8): await get_tree().process_frame
		session=SessionState.ensure_active_session()
		check(turn.get("ok",false) and session.day==day_before+1 and session.scenario_status=="in_progress","normal confirmed End Turn did not advance exactly one day")
		check(session.battle.is_empty(),"unexpected battle during early harbor growth")
		var visit: Dictionary=OverworldRules.set_active_town_visit(session,placement)
		check(visit.get("ok",false),"hero cannot re-enter the same Town after End Turn")
		AppRouter.go_to_town()
		await settle()
		session=SessionState.ensure_active_session()
		shell=get_tree().current_scene
		var actions: Array=TownRules.get_build_actions(session).filter(func(a):return String(a.id)=="build:"+id and not a.get("disabled",true))
		check(actions.size()==1,"normal prerequisites/resources do not permit growth building: "+id)
		if actions.size()!=1: return
		var cost: Dictionary=actions[0].cost
		var expected: Dictionary=normalized(session.overworld.resources)
		for resource in cost: expected[resource]=int(expected.get(resource,0))-int(cost[resource])
		var selected: Dictionary=shell.validation_select_build_plan(id)
		check(selected.ok and selected.state_unchanged,"growth ledger selection changed state: "+id)
		var committed: Dictionary=shell.validation_confirm_build_plan()
		await settle()
		session=SessionState.ensure_active_session()
		var active: Dictionary=TownRules.get_active_town(session)
		check(committed.ok and id in active.built_buildings,"normal growth ledger did not build: "+id)
		check(normalized(session.overworld.resources)==normalized(expected),"growth construction costs changed: "+id)
		check(int(active.last_build_day)==int(session.day),"growth construction lost daily limit: "+id)
		check(TownRules.get_build_actions(session).filter(func(a):return not a.get("disabled",true) and String(a.id).begins_with("build:")).is_empty(),"growth allowed a second same-day build")
		shell._close_town_catalog(false)
		await inspect(id)
		await inspect_scene_layers([id])
		var before: Dictionary=normalized(session.to_dict())
		var path: String=SaveService.save_session(session.to_dict(),3)
		session=SessionState.restore_session(SaveService.load_session(3))
		check(path!="" and normalized(session.to_dict())==before,"growth changed complete save/resume: "+id)
		AppRouter.go_to_town()
		await settle()
		var stage=get_tree().current_scene.get_node("%TownStage")
		check(stage.validation_building_hotspot_summary(id).visible and stage._town_building_texture_path(id)=="res://art/towns/runtime/scene_layers/faction_veilmourn/%s.png" % id,"growth save/re-entry lost exact layer: "+id)
		await clear_layer_capture_focus()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(id+"_saved.png"))
		rows.append({"label":"ordinary_harbor_growth","building_id":id,"day":session.day,"cost":cost,"expected_resources":expected,"actual_resources":session.overworld.resources.duplicate(true),"complete_saved_state_equal":true})
		print("HARBOR_GROWTH_SAVED "+id+" "+str(Time.get_ticks_msec()))
		previous_id = id
	# Preserve the final actual paid-growth save separately from detached views.
	var earned_path: String=SaveService.save_session(session.to_dict(),3)
	check(earned_path!="" and DirAccess.copy_absolute(earned_path,out.path_join("earned_growth_save.json"))==OK,"could not retain actual earned-growth save")
	if OS.get_environment("TOWN_HARBOR_DEVELOPED_SAVE") != "":
		await inspect_developed_harbor_composition()
func inspect_developed_harbor_composition() -> void:
	# Exact recorded built ids in a detached scenic view, not a resumed match.
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TOWN_HARBOR_DEVELOPED_SAVE")))
	var actual: Dictionary=payload.overworld.towns.filter(func(t):return t.town_id=="town_veilmourn_bellwake_harbor")[0]
	var before: Dictionary=normalized(session.to_dict())
	var shell=get_tree().current_scene
	var stage=shell.get_node("%TownStage")
	# This is a detached UI model, not the active session or a paid build.
	# Its shell and stage must agree on the displayed recorded built-id set.
	var live_shell_session=shell._session
	var fixture=SessionStateStore.SessionData.new()
	fixture.from_dict(before)
	TownRules.get_active_town(fixture).built_buildings=actual.built_buildings.duplicate()
	var fixture_initial: Dictionary=normalized(fixture.to_dict())
	shell._session=fixture
	var view: Dictionary=shell._build_town_stage_view_state()
	view.town=shell._town_stage_town_payload(actual)
	stage.set_precomputed_town_state(fixture,view)
	await settle()
	# The injected view's new building set invalidates its copied forecast
	# signature. Initialize through the ordinary ledger read before testing
	# read-only input; never erase or exclude fields from state comparisons.
	shell._read_build_catalog()
	var fixture_before: Dictionary=normalized(fixture.to_dict())
	var preparation_paths: Array=layer_changed_paths(fixture_initial,fixture_before)
	check(preparation_paths.is_empty() or preparation_paths==["/overworld/command_risk_forecast/signature"],"detached setup changed more than its derived forecast signature: "+str(preparation_paths))
	rows.append({"label":"detached_model_preparation_changes","paths":preparation_paths})
	check(normalized(stage._town.built_buildings)==normalized(actual.built_buildings),"developed composition changed the actual terminal built ids")
	await inspect_scene_layers(__INSPECTION_IDS__)
	await clear_layer_capture_focus()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("developed_built_id_fixture.png"))
	check(normalized(fixture.to_dict())==fixture_before,"read-only developed information mutated its detached model: "+str(layer_changed_paths(fixture_before,normalized(fixture.to_dict()))))
	check(normalized(session.to_dict())==before,"detached developed composition changed the live session")
	rows.append({"label":"detached_recorded_built_id_composition_not_match_resume","source_day":payload.day,"source_scenario_status":payload.get("scenario_status",""),"source_town":actual.placement_id,"built_ids":actual.built_buildings.duplicate()})
	shell._session=live_shell_session
	stage.set_precomputed_town_state(session,shell._build_town_stage_view_state())
'''

RIGGING_ORE_PURCHASE = r'''
func purchase_growth_ore_if_needed(building_id: String) -> void:
	if building_id!="building_veilmourn_tideglass_chapel" or int(session.overworld.resources.ore)>=int(ContentService.get_building(building_id).cost.ore): return
	var shell=get_tree().current_scene
	var opened: Dictionary=shell.validation_open_town_catalog("trade")
	await settle()
	check(opened.open,"ordinary Trade dialog did not open")
	var offered: Array=TownRules.get_market_actions(session).filter(func(a):return a.id=="market:buy:ore:1" and not a.get("disabled",true))
	check(offered.size()==1,"normal market cannot cover the one-ore shortfall")
	if offered.size()!=1: return
	var before: Dictionary=normalized(session.to_dict())
	var control=SessionStateStore.SessionData.new()
	# Canonical JSON is for comparison only: its sorted dictionary keys can
	# change the rule's first-ready recruit recommendation in the control.
	control.from_dict(session.to_dict())
	check(OverworldRules.get_town_recruit_options(TownRules.get_active_town(control))==OverworldRules.get_town_recruit_options(TownRules.get_active_town(session)),"paid Trade control changed live recruit option order")
	var signature: Dictionary=TownRules.town_action_consequence_signature(control)
	var expected: Dictionary=TownRules.perform_market_action(control,"market:buy:ore:1")
	var recap: Dictionary=TownRules.build_town_action_recap(control,"market","market:buy:ore:1",offered[0],expected,signature)
	if recap.get("active",false): control.flags["last_town_action_recap"]=recap.duplicate(true)
	var traded: Dictionary=shell.validation_perform_town_action("market:buy:ore:1")
	await settle()
	check(expected.ok and traded.ok,"ordinary paid ore exchange failed")
	if normalized(session.to_dict())!=normalized(control.to_dict()):
		rows.append({"label":"paid_trade_state_mismatch","day":session.day,"expected_recap":control.flags.get("last_town_action_recap",{}).duplicate(true),"actual_recap":session.flags.get("last_town_action_recap",{}).duplicate(true),"changed_paths":layer_changed_paths(normalized(control.to_dict()),normalized(session.to_dict()))})
	check(normalized(session.to_dict())==normalized(control.to_dict()),"paid Trade UI diverged from complete authoritative market result: "+str(layer_changed_paths(normalized(control.to_dict()),normalized(session.to_dict()))))
	check(int(session.overworld.resources.ore)==int(before.overworld.resources.ore)+1 and int(session.overworld.resources.gold)<int(before.overworld.resources.gold),"ore was not paid for through the existing market")
	rows.append({"label":"ordinary_paid_growth_ore","day":session.day,"before_resources":before.overworld.resources,"after_resources":session.overworld.resources.duplicate(true),"complete_rule_state_equal":normalized(session.to_dict())==normalized(control.to_dict())})
	shell._close_town_catalog(false)
	await settle()
'''

LATE_HARBOR_ORDERS = r'''
		var actions: Array=[]
		var attempt := 0
		var shell=get_tree().current_scene
		check(not shell.get_node("%TownStage").validation_building_hotspot_summary(id).visible,"unbuilt late harbor layer is visible: "+id)
		while actions.is_empty():
			attempt+=1
			check(attempt<=28,"ordinary late construction remained unavailable for four weeks: "+id)
			if attempt>28: return
			var day_before: int=session.day
			shell=get_tree().current_scene
			var prior_info: Dictionary=shell.validation_activate_building_information(previous_id)
			check(prior_info.open,"late harbor departure did not open prior building information")
			shell._on_town_catalog_close_pressed()
			shell._on_leave_pressed()
			for frame in range(8): await get_tree().process_frame
			var field=get_tree().current_scene
			check(field.scene_file_path=="res://scenes/overworld/OverworldShell.tscn","late harbor departure did not reach Overworld")
			if field.scene_file_path!="res://scenes/overworld/OverworldShell.tscn": return
			var turn: Dictionary=field.validation_request_end_turn()
			if turn.get("confirmation_required",false): turn=field.validation_confirm_end_turn()
			for frame in range(8): await get_tree().process_frame
			session=SessionState.ensure_active_session()
			var valid_turn: bool=turn.get("ok",false) and session.day==day_before+1 and session.scenario_status=="in_progress" and session.battle.is_empty()
			check(valid_turn,"normal late growth turn interrupted by battle/outcome or did not advance one day")
			if not valid_turn: return
			var visit: Dictionary=OverworldRules.set_active_town_visit(session,placement)
			check(visit.get("ok",false),"hero cannot re-enter Bellwake after ordinary late End Turn: "+str(visit.get("message","")))
			if not visit.get("ok",false):
				# Preserve a real ownership/entry interruption, not a successful
				# growth save or an injected replacement Town.
				var failed_path: String=SaveService.save_session(session.to_dict(),3)
				check(failed_path!="" and DirAccess.copy_absolute(failed_path,out.path_join("interrupted_growth_save.json"))==OK,"could not retain interrupted growth state")
				rows.append({"label":"ordinary_growth_visit_interruption","day":session.day,"placement_id":placement,"message":visit.get("message",""),"town_owner":visit.get("town",{}).get("owner","")})
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join("interrupted_growth_overworld.png"))
				return
			AppRouter.go_to_town()
			await settle()
			session=SessionState.ensure_active_session()
			shell=get_tree().current_scene
			var ore_needed: int=int(ContentService.get_building(id).cost.get("ore",0))
			while int(session.overworld.resources.ore)<ore_needed:
				var offers: Array=TownRules.get_market_actions(session).filter(func(a):return a.id=="market:buy:ore:1" and not a.get("disabled",true))
				if offers.size()!=1: break # Normal stock cap or affordability: no bypass.
				var ore_before: int=int(session.overworld.resources.ore)
				await purchase_growth_ore_if_needed(id)
				check(int(session.overworld.resources.ore)==ore_before+1,"ordinary late ore order made no paid progress")
				if int(session.overworld.resources.ore)!=ore_before+1: return
			actions=TownRules.get_build_actions(session).filter(func(a):return String(a.id)=="build:"+id and not a.get("disabled",true) and a.get("direct_affordable",true))
			rows.append({"label":"ordinary_late_growth_turn","day":session.day,"building_id":id,"resources":session.overworld.resources.duplicate(true),"market_usage":TownRules.get_active_town(session).get("market_usage",{}).duplicate(true),"construction_available":actions.size()==1})
			print("LATE_HARBOR_DAY "+str(session.day)+" "+id+" available="+str(actions.size()==1))
'''

LATE_HARBOR_UPGRADE = r'''
		if id=="building_veilmourn_memory_rite_court":
			var current_stage=get_tree().current_scene.get_node("%TownStage")
			var entries: Array=current_stage._town_building_scene_entries(current_stage._town_scene_rect())
			var plot: Array=entries.filter(func(entry):return entry.plot_id=="building_veilmourn_leviathan_sounding")
			check(plot.size()==1 and plot[0].visible_building_id==id,"ordinary Court upgrade did not replace Sounding in its original plot")
			check(not current_stage.validation_building_hotspot_summary("building_veilmourn_leviathan_sounding").get("visible",false),"superseded Sounding retains a live hotspot")
			check("building_veilmourn_leviathan_sounding" in active.built_buildings,"Court erased the earned Sounding prerequisite from saved progression")
'''

RIVERWORKS_DEFENSE = r'''
var riverworks_defense_days := []
func prepare_riverworks_defense() -> void:
	# Normal player policy for the retained Day-10 save, not altered simulation.
	# Fortify before the recorded assault while keeping a field guard company.
	if session.day not in [10,11,12] or session.day in riverworks_defense_days: return
	riverworks_defense_days.append(session.day)
	var shell=get_tree().current_scene
	var opened: Dictionary=shell.validation_open_town_catalog("muster")
	await settle()
	check(opened.open,"ordinary defensive Muster dialog did not open")
	for unit_id in ["unit_river_guard","unit_ember_archer","unit_citadel_pikeward"]:
		var offered: Array=TownRules.get_recruit_actions(session).filter(func(a):return a.id=="recruit:"+unit_id and not a.get("disabled",true))
		if offered.size()==1:
			await perform_riverworks_defense_order("recruit:"+unit_id)
		var amount: String="half" if unit_id=="unit_river_guard" else "all"
		var action_id: String="transfer:%s:garrison:%s:%s" % [session.overworld.active_hero_id,unit_id,amount]
		var transfer: Array=shell.validation_action_catalog().get("transfer",[]).filter(func(a):return a.id==action_id and not a.get("disabled",true))
		if transfer.size()==1:
			await perform_riverworks_defense_order(action_id)
	check(not session.overworld.army.stacks.is_empty(),"defensive transfers emptied the field army")
	rows.append({"label":"ordinary_riverworks_defense_day","day":session.day,"resources":session.overworld.resources.duplicate(true),"garrison":TownRules.get_active_town(session).garrison.duplicate(true),"field_stacks":session.overworld.army.stacks.duplicate(true)})
	shell._close_town_catalog(false)
	await settle()
func perform_riverworks_defense_order(action_id: String) -> void:
	var shell=get_tree().current_scene
	var action: Dictionary=shell._validation_action_for_id(action_id)
	check(not action.is_empty(),"defensive order is not enabled in the normal catalog: "+action_id)
	if action.is_empty(): return
	var before: Dictionary=normalized(session.to_dict())
	var control=SessionStateStore.SessionData.new()
	control.from_dict(before)
	var signature: Dictionary=TownRules.town_action_consequence_signature(control)
	var lane: String="recruit" if action_id.begins_with("recruit:") else "order"
	if lane=="order": signature["transfer"]=shell._town_transfer_holder_snapshot(action_id)
	var expected: Dictionary
	if lane=="recruit": expected=TownRules.recruit_active_town(control,action_id.trim_prefix("recruit:"))
	else: expected=TownRules.transfer_in_active_town(control,action_id)
	var recap: Dictionary=TownRules.build_town_action_recap(control,lane,action_id,action,expected,signature)
	if recap.get("active",false): control.flags["last_town_action_recap"]=recap.duplicate(true)
	var result: Dictionary=shell.validation_perform_town_action(action_id)
	await settle()
	check(expected.ok and result.ok,"ordinary defensive order failed: "+action_id)
	check(normalized(session.to_dict())==normalized(control.to_dict()),"defensive UI diverged from complete authoritative result: "+action_id+" "+str(layer_changed_paths(normalized(control.to_dict()),normalized(session.to_dict()))))
	check(session.day==int(before.day),"defensive order changed the day")
	if lane=="recruit": check(int(session.overworld.resources.gold)<int(before.overworld.resources.gold),"defensive recruits were not paid for")
	else: check(normalized(session.overworld.resources)==before.overworld.resources,"garrison transfer changed resources")
	rows.append({"label":"ordinary_paid_riverworks_defense_order","day":session.day,"action_id":action_id,"complete_rule_state_equal":normalized(session.to_dict())==normalized(control.to_dict())})
'''

def embercourt_script(script, *, presentation_only=False):
    """Reuse the same engine input/save controls, not a second runtime path."""
    script = script.replace('building_veilmourn_bell_harbor', 'building_muster_yard')
    script = script.replace('town_veilmourn_bellwake_harbor', 'town_riverwatch')
    if presentation_only:
        # The real developed fixture contains the Watch Barracks upgrade.
        # Preserve it and independently prove that it supersedes the Muster,
        # whose new layer remains exercised in the real opening above.
        needle='await inspect_scene_layers(["building_muster_yard", "building_wayfarers_hall", "building_market_square"])'
        replacement='''check("building_muster_yard" in actual.built_buildings and "building_watch_barracks" in actual.built_buildings,"recorded Riverwatch fixture lost earned base or upgrade")
	var upgraded_plot: Array=stage._town_building_scene_entries(stage._town_scene_rect()).filter(func(entry):return entry.plot_id=="building_muster_yard")
	check(upgraded_plot.size()==1 and upgraded_plot[0].visible_building_id=="building_watch_barracks","developed Watch Barracks no longer supersedes Muster Yard")
	check(not stage.validation_building_hotspot_summary("building_muster_yard").visible,"superseded Muster retains a hotspot")
	check(not stage.validation_building_hotspot_summary("building_bowyer_lodge").visible,"superseded Bowyer retains a hotspot")
	check(not stage.validation_building_hotspot_summary("building_lantern_archive").visible,"superseded Archive retains a hotspot")
	await inspect_scene_layers(["building_wayfarers_hall","building_market_square","building_stone_store","building_watch_barracks","building_beacon_range","building_river_granary_exchange","building_quartermasters_depot","building_starseer_annex","building_citadel_pikehall","building_embercourt_granary_lock_exchange","building_embercourt_lockhouse_tally","building_embercourt_tollstone_weir","building_embercourt_bargebow_slip","building_embercourt_oath_pikehall","building_embercourt_beacon_writs","building_embercourt_lantern_court","building_embercourt_relief_quay"])'''
        if script.count(needle)!=1:
            raise ValueError('Missing exact Embercourt developed inspection boundary')
        script=script.replace(needle,replacement)
    script = script.replace('await inspect_scene_layers(["building_muster_yard","building_wayfarers_hall","building_veilmourn_harpoon_gantry","building_veilmourn_bell_chain_watch"])',
                            'await inspect_scene_layers(["building_muster_yard","building_wayfarers_hall"])')
    # The first affordable Riverwatch order need not be the Market. Select the
    # actual authored offered action explicitly, retaining its normal commit.
    script = script.replace('String(a.id).begins_with("build:")', 'String(a.id)=="build:building_market_square"', 1)
    if not presentation_only:
        script = script.replace('var paid_before: Dictionary = normalized(session.overworld.resources)',
                                'var built_before: Array=TownRules.get_active_town(session).built_buildings.duplicate()\n\t\tvar paid_before: Dictionary = normalized(session.overworld.resources)')
        script = script.replace('var cost: Dictionary = offered[0].cost',
                                'var cost: Dictionary = offered[0].cost\n\t\tcheck(int(cost.get("gold",0))==1000,"Riverwatch Market authored gold cost changed")\n\t\tfor resource in cost:\n\t\t\tif resource!="gold": check(int(cost[resource])==0,"Riverwatch Market gained a non-gold cost: "+resource)')
        script = script.replace('await inspect_market_constructed()',
                                'check(TownRules.get_active_town(session).built_buildings==built_before+[building_id],"Market changed more than its earned built-id append")\n\t\tawait inspect_market_constructed()\n\t\tawait inspect_scene_layers(["building_muster_yard","building_wayfarers_hall","building_market_square"])')
        # Preserve the legitimate save before the existing detached visibility
        # fixture. No fixture state is presented as normal construction.
        script = script.replace('await layer_visibility_fixture()',
                                'var earned_path: String=SaveService.save_session(session.to_dict(),3)\n\tcheck(earned_path!="" and DirAccess.copy_absolute(earned_path,out.path_join("earned_growth_save.json"))==OK,"could not retain ordinary Market save")\n\tawait layer_visibility_fixture()')
    return script


def embercourt_growth_script(*, supply=False, riverworks=False, civic=False):
    """Continue exact earned saves through existing daily build and market routes."""
    if sum((supply, riverworks, civic)) > 1:
        raise ValueError('select one normal construction sequence')
    ids = EMBERCOURT_CIVIC_IDS if civic else EMBERCOURT_RIVERWORKS_IDS if riverworks else EMBERCOURT_SUPPLY_IDS if supply else EMBERCOURT_GROWTH_IDS
    accepted = EMBERCOURT_IDS + EMBERCOURT_GROWTH_IDS + (EMBERCOURT_SUPPLY_IDS if supply or riverworks or civic else []) + (EMBERCOURT_RIVERWORKS_IDS if riverworks or civic else []) + (EMBERCOURT_CIVIC_IDS if civic else [])
    visible = 'stage._town_building_scene_entries(stage._town_scene_rect()).filter(func(entry):return entry.visible_building_id in '+json.dumps(accepted)+').map(func(entry):return entry.visible_building_id)'
    opening = overlay.SCRIPT
    start = opening.index('\tvar offered: Array=TownRules.get_build_actions(session)')
    end = opening.index('\tvar path: String=SaveService.save_session', start)
    opening = opening[:start] + '\tawait inspect_scene_layers(["building_muster_yard","building_wayfarers_hall","building_market_square"])\n\tawait inspect_harbor_growth()\n' + opening[end:]
    if supply or riverworks or civic:
        opening=opening.replace('await inspect_scene_layers(["building_muster_yard","building_wayfarers_hall","building_market_square"])', 'var stage=get_tree().current_scene.get_node("%TownStage")\n\tawait inspect_scene_layers('+visible+')')
    growth = HARBOR_GROWTH.replace('__GROWTH_IDS__',json.dumps(ids)).replace('__INSPECTION_IDS__',visible)
    if supply or riverworks or civic:
        start=growth.index('\t\tprint("HARBOR_GROWTH_BEGIN ')
        end=growth.index('\t\tvar cost: Dictionary=actions[0].cost',start)
        growth=growth[:start]+LATE_HARBOR_ORDERS.replace('Bellwake','Riverwatch')+growth[end:]
        growth+=RIGGING_ORE_PURCHASE.replace('building_id!="building_veilmourn_tideglass_chapel" or ', '')
    growth = growth.replace('town_veilmourn_bellwake_harbor','town_riverwatch').replace('scene_layers/faction_veilmourn/','scene_layers/faction_embercourt/').replace('ordinary_harbor_growth','ordinary_embercourt_growth')
    growth = growth.replace('\t\tvar cost: Dictionary=actions[0].cost','\t\tvar prior_built: Array=TownRules.get_active_town(session).built_buildings.duplicate()\n\t\tvar cost: Dictionary=actions[0].cost')
    growth = growth.replace('\t\tshell._close_town_catalog(false)\n\t\tawait inspect(id)', '''		check(active.built_buildings==prior_built+[id],"early construction changed more than the earned built-id append")
		var predecessor: String=ContentService.get_building(id).get("upgrade_from","")
		if predecessor!="":
			check(predecessor in active.built_buildings,"paid upgrade erased its saved predecessor: "+id)
			check(not shell.get_node("%TownStage").validation_building_hotspot_summary(predecessor).visible,"paid upgrade retained predecessor painting/input: "+id)
		shell._close_town_catalog(false)
		await inspect(id)''')
    growth = growth.replace('await inspect_scene_layers([id])', 'var growth_stage=shell.get_node("%TownStage")\n\t\tawait inspect_scene_layers('+visible.replace('stage.', 'growth_stage.')+')')
    if riverworks:
        opening=opening.replace('await inspect_harbor_growth()', 'await prepare_riverworks_defense()\n\tawait inspect_harbor_growth()')
        needle='\t\t\tvar ore_needed: int=int(ContentService.get_building(id).cost.get("ore",0))'
        if growth.count(needle)!=1:
            raise ValueError('Missing exact normal post-turn riverworks boundary')
        growth=growth.replace(needle,'\t\t\tawait prepare_riverworks_defense()\n'+needle)
        growth+=RIVERWORKS_DEFENSE
    return opening + EXTRA + growth


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080', '2048x1079'], required=True)
    parser.add_argument('--faction', choices=['veilmourn', 'embercourt'], default='veilmourn')
    parser.add_argument('--embercourt-growth', action='store_true', help='Four paid Stone/Watch/Bowyer/Beacon orders from the exact earned Medium11 Market save')
    parser.add_argument('--embercourt-supply-growth', action='store_true', help='Five paid supply/magic orders and ordinary ore trades from the exact earned Day-5 save')
    parser.add_argument('--embercourt-riverworks-growth', action='store_true', help='Six normal riverworks-chain builds from the exact earned Day-10 save')
    parser.add_argument('--embercourt-civic-growth', action='store_true', help='Paid Lantern Court and Relief Quay orders from the exact earned Day-17 save')
    parser.add_argument('--harbor-growth', action='store_true', help='Build Fog Buoys and Salvage Ledger after Market across real confirmed End Turns')
    parser.add_argument('--exchange-growth', action='store_true', help='Build Ransom Exchange and Mirror Drydock after Market across real confirmed End Turns')
    parser.add_argument('--salt-growth', action='store_true', help='Build Counting House, Fog Buoys, Ledger, Pilot Guild and Saltwake Factor after Market across real confirmed End Turns')
    parser.add_argument('--defense-growth', action='store_true', help='Build Fog Buoys, Bell-Chain Watch, Ransom Exchange, Mirror Drydock and Harpoon Gantry after Market across real confirmed End Turns')
    parser.add_argument('--memory-growth', action='store_true', help='Resume the earned Day-8 Bellwake save and normally build Obituary Vault, Wake Oratory and Mistgate Slip; never inject resources or reset built ids')
    parser.add_argument('--rigging-magic-growth', action='store_true', help='Six ordinary prerequisite/build orders and one paid ore purchase for Loft/Chapel from the earned Day-8 save')
    parser.add_argument('--late-harbor-growth', action='store_true', help='Seven normal late orders from exact earned Day-14 save, respecting paid ore, weekly caps and upgrade replacement')
    parser.add_argument('--presentation-only', action='store_true', help='Read-only opening/developed input checks; no purchases or match progression evidence')
    parser.add_argument('--developed-save', type=Path, help='Exact recorded built-id composition fixture; never resumed as a live match')
    args = parser.parse_args()
    if sum((args.harbor_growth, args.exchange_growth, args.salt_growth, args.defense_growth, args.memory_growth, args.rigging_magic_growth, args.late_harbor_growth, args.embercourt_growth, args.embercourt_supply_growth, args.embercourt_riverworks_growth, args.embercourt_civic_growth, args.presentation_only)) > 1:
        parser.error('select one normal construction sequence per run')
    if args.presentation_only and not args.developed_save:
        parser.error('presentation-only requires an exact --developed-save fixture')
    if args.faction=='embercourt' and any((args.harbor_growth,args.exchange_growth,args.salt_growth,args.defense_growth,args.memory_growth,args.rigging_magic_growth,args.late_harbor_growth)):
        parser.error('Bellwake growth sequences cannot run against Embercourt')
    if args.embercourt_growth and args.faction!='embercourt':
        parser.error('Embercourt growth requires --faction embercourt')
    if args.embercourt_supply_growth and args.faction!='embercourt':
        parser.error('Embercourt supply growth requires --faction embercourt')
    if args.embercourt_riverworks_growth and args.faction!='embercourt':
        parser.error('Embercourt riverworks growth requires --faction embercourt')
    if args.embercourt_civic_growth and args.faction!='embercourt':
        parser.error('Embercourt civic growth requires --faction embercourt')
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('fresh lowercase label required')
    save = args.save.resolve(strict=True)
    before_hash = hashlib.sha256(save.read_bytes()).hexdigest()
    if args.embercourt_growth and before_hash!=EMBERCOURT_GROWTH_SAVE_SHA256:
        parser.error('Embercourt growth requires the exact earned nonterminal Medium11 Market save')
    if args.embercourt_supply_growth and before_hash!=EMBERCOURT_SUPPLY_SAVE_SHA256:
        parser.error('Embercourt supply growth requires the exact earned nonterminal Medium11 Day-5 save')
    if args.embercourt_riverworks_growth and before_hash!=EMBERCOURT_RIVERWORKS_SAVE_SHA256:
        parser.error('Embercourt riverworks growth requires the exact earned nonterminal Medium11 Day-10 save')
    if args.embercourt_civic_growth and before_hash!=EMBERCOURT_CIVIC_SAVE_SHA256:
        parser.error('Embercourt civic growth requires the exact earned nonterminal Medium11 Day-17 save')
    if args.faction=='embercourt' and not (args.embercourt_growth or args.embercourt_supply_growth or args.embercourt_riverworks_growth or args.embercourt_civic_growth) and before_hash!=EMBERCOURT_SAVE_SHA256:
        parser.error('Embercourt opening requires the exact recorded nonterminal Medium11 Day-1 save')
    if args.late_harbor_growth and before_hash != LATE_HARBOR_SAVE_SHA256:
        parser.error('late-harbor growth requires the exact recorded nonterminal earned Day-14 save')
    if args.memory_growth or args.rigging_magic_growth:
        payload = json.loads(save.read_text())
        town = next((t for t in payload['overworld']['towns'] if t.get('town_id')=='town_veilmourn_bellwake_harbor' and t.get('owner')=='player'), {})
        required = {'building_market_square','building_veilmourn_harpoon_gantry','building_veilmourn_bell_chain_watch','building_veilmourn_salt_counting_house'}
        unbuilt = {'building_veilmourn_obituary_vault','building_veilmourn_wake_oratory','building_veilmourn_mistgate_slip'}
        if args.rigging_magic_growth:
            required |= {'building_veilmourn_mirror_drydock'}
            unbuilt = {'building_veilmourn_salvage_ledger','building_veilmourn_black_sail_loft','building_veilmourn_obituary_vault','building_veilmourn_wake_oratory','building_veilmourn_mourner_pilot_guild','building_veilmourn_tideglass_chapel'}
        if payload.get('day')!=8 or payload.get('scenario_status')!='in_progress' or not required.issubset(town.get('built_buildings',[])) or unbuilt.intersection(town.get('built_buildings',[])):
            parser.error('late Town growth requires the real nonterminal Day-8 Bellwake prerequisite save')
    developed = args.developed_save.resolve(strict=True) if args.developed_save else None
    developed_hash = hashlib.sha256(developed.read_bytes()).hexdigest() if developed else None
    if args.faction=='embercourt' and developed and developed_hash!=EMBERCOURT_DEVELOPED_SHA256:
        parser.error('Embercourt developed composition requires the exact recorded Medium Day-43 fixture')
    owners = ('scenes/town/TownShell.gd','scenes/town/TownStageView.gd','scenes/town/TownBuildingHotspot.gd',
              'scripts/autoload/LiveValidationHarness.gd',
              'content/town_building_scene_art_manifest.json','tests/town_scene_layer_regression.py')
    source_hashes = {path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in owners}
    out = OUTPUT / args.label
    out.mkdir(exist_ok=False)
    script_text = SCRIPT
    growth_enabled = args.harbor_growth or args.exchange_growth or args.salt_growth or args.defense_growth or args.memory_growth or args.rigging_magic_growth or args.late_harbor_growth or args.presentation_only
    sequence = 'late_harbor' if args.late_harbor_growth else 'rigging_magic' if args.rigging_magic_growth else 'presentation_only' if args.presentation_only else 'memory' if args.memory_growth else 'defense' if args.defense_growth else 'salt' if args.salt_growth else 'exchange' if args.exchange_growth else 'harbor' if args.harbor_growth else 'market'
    if growth_enabled:
        ids = ['building_veilmourn_fog_signal_buoys', 'building_veilmourn_salvage_ledger']
        if args.exchange_growth:
            ids = ['building_veilmourn_ransom_exchange', 'building_veilmourn_mirror_drydock']
        if args.salt_growth:
            ids = ['building_veilmourn_salt_counting_house', 'building_veilmourn_fog_signal_buoys', 'building_veilmourn_salvage_ledger', 'building_veilmourn_mourner_pilot_guild', 'building_veilmourn_saltwake_factor']
        if args.defense_growth:
            ids = ['building_veilmourn_fog_signal_buoys','building_veilmourn_bell_chain_watch','building_veilmourn_ransom_exchange','building_veilmourn_mirror_drydock','building_veilmourn_harpoon_gantry']
        if args.memory_growth:
            ids = ['building_veilmourn_obituary_vault','building_veilmourn_wake_oratory','building_veilmourn_mistgate_slip']
        if args.rigging_magic_growth:
            ids = ['building_veilmourn_salvage_ledger','building_veilmourn_black_sail_loft','building_veilmourn_obituary_vault','building_veilmourn_wake_oratory','building_veilmourn_mourner_pilot_guild','building_veilmourn_tideglass_chapel']
        if args.late_harbor_growth:
            ids = LATE_HARBOR_IDS
        inspection_ids = [id for id in ids if id not in ('building_veilmourn_fog_signal_buoys', 'building_veilmourn_salvage_ledger')] if args.salt_growth else ids
        if args.defense_growth or args.memory_growth or args.rigging_magic_growth or args.presentation_only:
            # Test earlier accepted paintings too: later foreground layers must
            # not silently make the rest of the developed Town unclickable.
            inspection_ids = [
                'building_veilmourn_bell_harbor', 'building_wayfarers_hall',
                'building_market_square', 'building_veilmourn_fog_signal_buoys',
                'building_veilmourn_salvage_ledger', 'building_veilmourn_ransom_exchange',
                'building_veilmourn_mirror_drydock', 'building_veilmourn_salt_counting_house',
                'building_veilmourn_mourner_pilot_guild', 'building_veilmourn_saltwake_factor',
                'building_veilmourn_harpoon_gantry', 'building_veilmourn_bell_chain_watch',
                'building_veilmourn_obituary_vault', 'building_veilmourn_wake_oratory',
                'building_veilmourn_mistgate_slip',
            ]
        if args.presentation_only:
            # Inspect the exact recorded Town, whether this is the original
            # terminal-16 fixture or a separately retained ordinary-growth save.
            payload = json.loads(developed.read_text())
            town = next(t for t in payload['overworld']['towns'] if t.get('town_id')==('town_riverwatch' if args.faction=='embercourt' else 'town_veilmourn_bellwake_harbor'))
            # Inspect visible plot owners, not superseded saved prerequisites.
            # The live renderer and independent reversed-order controls prove
            # ancestry selection; the fixture does not remove any earned ids.
            inspection_ids = EMBERCOURT_IDS if args.faction=='embercourt' else None
        inspection_expression = json.dumps(inspection_ids) if inspection_ids is not None else 'stage._town_building_scene_entries(stage._town_scene_rect()).filter(func(entry):return entry.visible_building_id!="" and not entry.get("embedded_in_base",false)).map(func(entry):return entry.visible_building_id)'
        growth = HARBOR_GROWTH.replace('__GROWTH_IDS__', json.dumps(ids)).replace('__INSPECTION_IDS__', inspection_expression).replace('ordinary_harbor_growth', 'ordinary_'+sequence+'_growth')
        if args.rigging_magic_growth or args.late_harbor_growth:
            growth = growth.replace('await inspect_scene_layers([id])', 'await inspect_scene_layers(shell.get_node("%TownStage")._town_building_scene_entries(shell.get_node("%TownStage")._town_scene_rect()).filter(func(entry): return entry.visible_building_id!="" and not entry.get("embedded_in_base",false)).map(func(entry): return entry.visible_building_id))')
        if args.rigging_magic_growth:
            growth = growth.replace('\t\tvar actions: Array=TownRules.get_build_actions', '\t\tawait purchase_growth_ore_if_needed(id)\n\t\tvar actions: Array=TownRules.get_build_actions') + RIGGING_ORE_PURCHASE
        if args.late_harbor_growth:
            start = growth.index('\t\tprint("HARBOR_GROWTH_BEGIN ')
            end = growth.index('\t\tvar cost: Dictionary=actions[0].cost', start)
            growth = growth[:start] + LATE_HARBOR_ORDERS + growth[end:]
            growth = growth.replace('\t\tvar cost: Dictionary=actions[0].cost', '\t\tvar prior_built: Array=TownRules.get_active_town(session).built_buildings.duplicate()\n\t\tvar cost: Dictionary=actions[0].cost')
            growth = growth.replace('\t\tshell._close_town_catalog(false)\n\t\tawait inspect(id)', '\t\tcheck(active.built_buildings==prior_built+[id],"late construction changed more than the earned built-id append")\n' + LATE_HARBOR_UPGRADE + '\t\tshell._close_town_catalog(false)\n\t\tawait inspect(id)')
            growth += RIGGING_ORE_PURCHASE.replace('building_id!="building_veilmourn_tideglass_chapel" or ', '')
        script_text = SCRIPT.replace('await inspect_market_constructed()', 'await inspect_market_constructed()\n\t\tawait inspect_harbor_growth()') + growth
        if args.memory_growth or args.rigging_magic_growth or args.late_harbor_growth or args.presentation_only:
            # Existing market/prerequisites and rare resources come from the
            # hash-recorded legitimate mid-match save, not a presentation fixture.
            # Skip only the opening-only Market purchase; keep actual daily
            # construction, complete save/resume and all layer/input controls.
            opening = overlay.SCRIPT
            start = opening.index('\tvar offered: Array=TownRules.get_build_actions(session)')
            end = opening.index('\tvar path: String=SaveService.save_session', start)
            continuation = 'inspect_developed_harbor_composition' if args.presentation_only else 'inspect_harbor_growth'
            opening = opening[:start] + '\tawait inspect_scene_layers(["building_veilmourn_bell_harbor","building_wayfarers_hall","building_veilmourn_harpoon_gantry","building_veilmourn_bell_chain_watch"])\n\tawait '+continuation+'()\n' + opening[end:]
            script_text = opening + EXTRA + growth
    script_text = script_text.replace('await inspect("opening")', 'await inspect("opening")\n\tinspect_upgrade_order()')
    if args.embercourt_growth or args.embercourt_supply_growth or args.embercourt_riverworks_growth or args.embercourt_civic_growth:
        script_text=embercourt_growth_script(supply=args.embercourt_supply_growth,riverworks=args.embercourt_riverworks_growth,civic=args.embercourt_civic_growth).replace('await inspect("opening")', 'await inspect("opening")\n\tinspect_upgrade_order()')
        sequence='embercourt_civic' if args.embercourt_civic_growth else 'embercourt_riverworks' if args.embercourt_riverworks_growth else 'embercourt_supply' if args.embercourt_supply_growth else 'embercourt'
    elif args.faction=='embercourt':
        script_text = embercourt_script(script_text, presentation_only=args.presentation_only)
    if args.resolution == '2048x1079':
        script_text = script_text.replace('SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))', 'get_window().content_scale_size = Vector2i(2048,1079)\n\tget_window().size = Vector2i(2048,1079)')
    with tempfile.TemporaryDirectory(prefix='town-layer-probe-', dir=OUTPUT) as temporary, tempfile.TemporaryDirectory(prefix='town-layer-data-', dir='/dev/shm') as data:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(script_text)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="TownLayer" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--resolution',args.resolution,'res://'+str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=data, TOWN_OVERLAY_OUTPUT=str(out), TOWN_OVERLAY_SAVE=str(save), TOWN_OVERLAY_RESOLUTION=args.resolution)
        if developed:
            env['TOWN_HARBOR_DEVELOPED_SAVE'] = str(developed)
        with (out / 'runtime.log').open('w') as log:
            # Rigging/magic covers every currently visible painting after each
            # of six orders, not only the newly constructed building.
            code = run_probe(command, env, log, timeout_seconds=3600 if args.late_harbor_growth else 1800 if args.rigging_magic_growth or args.embercourt_supply_growth or args.embercourt_riverworks_growth or args.embercourt_civic_growth else 900 if args.salt_growth or args.defense_growth or args.memory_growth or args.embercourt_growth else 600 if growth_enabled else 300)
    lines = (out / 'runtime.log').read_text().splitlines()
    marker = 'TOWN_OVERLAY_OWNERSHIP '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code, save_sha256=before_hash, input_unchanged=hashlib.sha256(save.read_bytes()).hexdigest()==before_hash, resolution=args.resolution,
                  faction=args.faction, runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
    report['source_hashes'] = source_hashes
    report['developed_save_sha256'] = developed_hash
    report['construction_sequence'] = sequence
    report['developed_save_unchanged'] = not developed or hashlib.sha256(developed.read_bytes()).hexdigest()==developed_hash
    report['executed_probe_sha256'] = hashlib.sha256(script_text.encode()).hexdigest()
    report['source_unchanged'] = all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha for path,sha in source_hashes.items())
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors'] and report['input_unchanged'] and report['source_unchanged'] and report['developed_save_unchanged']
    (out / 'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k != 'rows'}))
    return 0 if report['ok'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
