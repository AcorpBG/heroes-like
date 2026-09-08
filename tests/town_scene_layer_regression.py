#!/usr/bin/env python3
"""Real Bellwake scene assets, cover-crop input and normal construction/save."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT
from generated_town_order_profile import run_probe
import town_overlay_ownership_regression as overlay

EXTRA = r'''
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
func inspect_scene_layers(ids: Array = ["building_veilmourn_bell_harbor", "building_wayfarers_hall"]) -> void:
	var shell = get_tree().current_scene
	var stage = shell.get_node("%TownStage")
	var before: Dictionary = normalized(session.to_dict())
	var rows: Array = stage.validation_town_building_progression_summary().texture_rows
	UiAccessibility.refresh_tree(stage)
	for id in ids:
		var matches: Array = rows.filter(func(row): return row.building_id == id)
		var expected := "res://art/towns/runtime/scene_layers/faction_veilmourn/%s.png" % id
		check(matches.size()==1 and matches[0].texture_path==expected,"scenery still resolves catalog icon rather than exact Veilmourn layer: "+id)
		if matches.size()!=1 or matches[0].texture_path!=expected:
			continue # A missing layer is already a failure, not valid alpha/input evidence.
		var summary: Dictionary = stage.validation_building_hotspot_summary(id)
		check(summary.aligned and summary.visible and summary.focus_mode==Control.FOCUS_ALL,"scene layer focus/crop alignment: "+id)
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
	stage._town_template.faction_id="faction_embercourt"
	check(stage._town_building_texture("building_wayfarers_hall").resource_path==TownRules.building_icon_path("building_wayfarers_hall"),"scenic texture leaked across faction cache keys")
	stage._town_template=template
	var manifest: Dictionary = stage._building_scene_art_manifest
	stage._building_scene_art_manifest=manifest.duplicate(true)
	stage._building_scene_art_manifest.factions.faction_veilmourn.building_wayfarers_hall.runtime_path="res://missing-declared-town-layer.png"
	check(stage._town_building_texture("building_wayfarers_hall")==null,"missing declared art fell back to catalog")
	stage._building_scene_art_manifest.factions.faction_veilmourn.building_wayfarers_hall={}
	check(stage._town_building_texture("building_wayfarers_hall")==null,"malformed declared art fell back to catalog")
	stage._building_scene_art_manifest=manifest
	check(stage._town_building_texture("building_wayfarers_hall").resource_path.contains("scene_layers/faction_veilmourn"),"negative asset cache poisoned restored exact mapping")
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
	check(stage._town_building_texture_path("building_market_square")=="res://art/towns/runtime/scene_layers/faction_veilmourn/building_market_square.png","saved market re-entry lost exact scenic art")
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
	control.from_dict(before)
	var signature: Dictionary=TownRules.town_action_consequence_signature(control)
	var expected: Dictionary=TownRules.perform_market_action(control,"market:buy:ore:1")
	var recap: Dictionary=TownRules.build_town_action_recap(control,"market","market:buy:ore:1",offered[0],expected,signature)
	if recap.get("active",false): control.flags["last_town_action_recap"]=recap.duplicate(true)
	var traded: Dictionary=shell.validation_perform_town_action("market:buy:ore:1")
	await settle()
	check(expected.ok and traded.ok,"ordinary paid ore exchange failed")
	check(normalized(session.to_dict())==normalized(control.to_dict()),"paid Trade UI diverged from complete authoritative market result: "+str(layer_changed_paths(normalized(control.to_dict()),normalized(session.to_dict()))))
	check(int(session.overworld.resources.ore)==int(before.overworld.resources.ore)+1 and int(session.overworld.resources.gold)<int(before.overworld.resources.gold),"ore was not paid for through the existing market")
	rows.append({"label":"ordinary_paid_growth_ore","day":session.day,"before_resources":before.overworld.resources,"after_resources":session.overworld.resources.duplicate(true),"complete_rule_state_equal":normalized(session.to_dict())==normalized(control.to_dict())})
	shell._close_town_catalog(false)
	await settle()
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080', '2048x1079'], required=True)
    parser.add_argument('--harbor-growth', action='store_true', help='Build Fog Buoys and Salvage Ledger after Market across real confirmed End Turns')
    parser.add_argument('--exchange-growth', action='store_true', help='Build Ransom Exchange and Mirror Drydock after Market across real confirmed End Turns')
    parser.add_argument('--salt-growth', action='store_true', help='Build Counting House, Fog Buoys, Ledger, Pilot Guild and Saltwake Factor after Market across real confirmed End Turns')
    parser.add_argument('--defense-growth', action='store_true', help='Build Fog Buoys, Bell-Chain Watch, Ransom Exchange, Mirror Drydock and Harpoon Gantry after Market across real confirmed End Turns')
    parser.add_argument('--memory-growth', action='store_true', help='Resume the earned Day-8 Bellwake save and normally build Obituary Vault, Wake Oratory and Mistgate Slip; never inject resources or reset built ids')
    parser.add_argument('--rigging-magic-growth', action='store_true', help='Six ordinary prerequisite/build orders and one paid ore purchase for Loft/Chapel from the earned Day-8 save')
    parser.add_argument('--presentation-only', action='store_true', help='Read-only opening/developed input checks; no purchases or match progression evidence')
    parser.add_argument('--developed-save', type=Path, help='Exact recorded built-id composition fixture; never resumed as a live match')
    args = parser.parse_args()
    if sum((args.harbor_growth, args.exchange_growth, args.salt_growth, args.defense_growth, args.memory_growth, args.rigging_magic_growth, args.presentation_only)) > 1:
        parser.error('select one normal construction sequence per run')
    if args.presentation_only and not args.developed_save:
        parser.error('presentation-only requires an exact --developed-save fixture')
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('fresh lowercase label required')
    save = args.save.resolve(strict=True)
    before_hash = hashlib.sha256(save.read_bytes()).hexdigest()
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
    owners = ('scenes/town/TownShell.gd','scenes/town/TownStageView.gd','scenes/town/TownBuildingHotspot.gd',
              'scripts/autoload/LiveValidationHarness.gd',
              'content/town_building_scene_art_manifest.json','tests/town_scene_layer_regression.py')
    source_hashes = {path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in owners}
    out = OUTPUT / args.label
    out.mkdir(exist_ok=False)
    script_text = SCRIPT
    growth_enabled = args.harbor_growth or args.exchange_growth or args.salt_growth or args.defense_growth or args.memory_growth or args.rigging_magic_growth or args.presentation_only
    sequence = 'rigging_magic' if args.rigging_magic_growth else 'presentation_only' if args.presentation_only else 'memory' if args.memory_growth else 'defense' if args.defense_growth else 'salt' if args.salt_growth else 'exchange' if args.exchange_growth else 'harbor' if args.harbor_growth else 'market'
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
            town = next(t for t in payload['overworld']['towns'] if t.get('town_id')=='town_veilmourn_bellwake_harbor')
            inspection_ids = [id for id in town['built_buildings'] if id != 'building_town_hall']
        growth = HARBOR_GROWTH.replace('__GROWTH_IDS__', json.dumps(ids)).replace('__INSPECTION_IDS__', json.dumps(inspection_ids)).replace('ordinary_harbor_growth', 'ordinary_'+sequence+'_growth')
        if args.rigging_magic_growth:
            growth = growth.replace('await inspect_scene_layers([id])', 'await inspect_scene_layers(shell.get_node("%TownStage")._town_building_scene_entries(shell.get_node("%TownStage")._town_scene_rect()).filter(func(entry): return entry.visible_building_id!="" and not entry.get("embedded_in_base",false)).map(func(entry): return entry.visible_building_id))')
            growth = growth.replace('\t\tvar actions: Array=TownRules.get_build_actions', '\t\tawait purchase_growth_ore_if_needed(id)\n\t\tvar actions: Array=TownRules.get_build_actions') + RIGGING_ORE_PURCHASE
        script_text = SCRIPT.replace('await inspect_market_constructed()', 'await inspect_market_constructed()\n\t\tawait inspect_harbor_growth()') + growth
        if args.memory_growth or args.rigging_magic_growth or args.presentation_only:
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
            code = run_probe(command, env, log, timeout_seconds=1800 if args.rigging_magic_growth else 900 if args.salt_growth or args.defense_growth or args.memory_growth else 600 if growth_enabled else 300)
    lines = (out / 'runtime.log').read_text().splitlines()
    marker = 'TOWN_OVERLAY_OWNERSHIP '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code, save_sha256=before_hash, input_unchanged=hashlib.sha256(save.read_bytes()).hexdigest()==before_hash, resolution=args.resolution,
                  runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
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
