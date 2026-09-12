#!/usr/bin/env python3
"""Original-raster scenery controls alongside real travel/fog/save/AI coverage."""
import overworld_animation_readability_regression as animation

ROOT = animation.ROOT
OUTPUT = ROOT / '.artifacts/overworld_living_scenery_20260912'
run_probe = animation.run_probe
probe_environment = animation.probe_environment

SCENERY = r'''
func capture_scenery_clip(painter,prefix:String,out:String)->void:
	if DisplayServer.get_name()=="headless" or OS.get_environment("SCENERY_RECORD")!="1":return
	for frame in range(96):
		for entry in painter.entries:entry.batch.material.set_shader_parameter("clock_override",float(frame)/24.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(prefix+"-%03d.png"%frame))

func scenery_controls(shell,out:String)->void:
	var view=shell._map_view
	var session_before:Dictionary=shell._session.to_dict().duplicate(true)
	if DisplayServer.get_name()=="headless":view._draw_state_layer()
	var batches=view._scenery_batches
	for entry in batches.entries:
		check(OverworldRules.is_tile_explored(shell._session,entry.tile.x,entry.tile.y,entry.level),"animated hidden scenery")
		check(entry.level==view._level,"animated scenery from another level")
		check(entry.batch.get_parent()==view._state_layer,"scenery bypasses state/fog painter order")
	var generation:int=batches.generation
	var terrain_generation:int=view._session_static_cache_generation
	var batch_count:int=batches.batches.size()
	var start:int=Time.get_ticks_usec()
	for i in range(120):view._process(1.0/120.0)
	check(batches.generation==generation and batches.batches.size()==batch_count,"idle animation rebuilds state commands")
	check(view._session_static_cache_generation==terrain_generation,"idle animation rebuilds terrain")
	var tick_usec:int=Time.get_ticks_usec()-start
	start=Time.get_ticks_usec()
	for i in range(5):view._draw_state_layer()
	var redraw_usec:int=Time.get_ticks_usec()-start
	check(batches._cursor<=batches.entries.size()*2+1,"state batching scales with map area instead of visible art")
	print("LIVING_SCENERY_PROFILE "+JSON.stringify({"map_size":str(view._map_size),"animated_visible":batches.entries.size(),"cached_batches":batch_count,"ticks_120_usec":tick_usec,"state_rebuild_5_usec":redraw_usec}))
	if OS.get_environment("MENU_TURN_GENERATED")=="1":check(not batches.entries.is_empty(),"generated map has no live scenery")
	var was_processing:bool=view.is_processing()
	view.set_process(false)
	for index in range(4):
		for entry in batches.entries:entry.batch.material.set_shader_parameter("clock_override",float(index)*1.5)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("scenery-map-%02d.png"%index))
	await capture_scenery_clip(batches,"scenery-live-map",out)
	for entry in batches.entries:entry.batch.material.set_shader_parameter("clock_override",-1.0)
	var original_fog:Dictionary=shell._session.overworld.fog
	shell._session.overworld.fog=original_fog.duplicate(true)
	for row in shell._session.overworld.fog.explored_tiles:row.fill(false)
	view._draw_state_layer()
	check(batches.entries.is_empty(),"hidden map retains animated props")
	shell._session.overworld.fog=original_fog
	view._draw_state_layer()
	var reduced:bool=SettingsService.reduced_motion_enabled()
	SettingsService.set_reduced_motion_enabled(true)
	for entry in batches.entries:check(not entry.batch.material.get_shader_parameter("motion_enabled"),"reduced motion leaves asset animation enabled")
	SettingsService.set_reduced_motion_enabled(false)
	SettingsService.set_high_contrast_ui_enabled(true)
	for entry in batches.entries:check(not entry.batch.material.get_shader_parameter("motion_enabled"),"high contrast leaves asset animation enabled")
	SettingsService.set_high_contrast_ui_enabled(false)
	SettingsService.set_reduced_motion_enabled(reduced)
	# An explicit art-inspection gallery, not a fabricated gameplay screenshot.
	var gallery:=Control.new()
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(gallery)
	var backdrop:=ColorRect.new()
	backdrop.color=Color(.055,.07,.06,1)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.add_child(backdrop)
	var painter=load("res://scenes/overworld/OverworldSceneryBatch.gd").new()
	painter.begin(gallery)
	var cards:Array=[]
	var manifest:Dictionary=view._scenery_manifest
	var ids:Array=manifest.assets.keys()
	var cell:=Vector2(get_viewport().get_visible_rect().size.x/4.0,get_viewport().get_visible_rect().size.y/ceilf(float(ids.size())/4.0))
	for index in range(ids.size()):
		var id:String=ids[index]
		check(view._overworld_art_manifest.object_assets.has(id),"animation references missing art: "+id)
		var texture:Texture2D=view._object_texture_for_asset(id)
		check(texture!=null,"animation art failed to load: "+id)
		if texture==null:continue
		var profile:Dictionary=manifest.profiles[manifest.assets[id]]
		check(profile.strength>0.0 and profile.strength<=.01,"excessive scenery displacement: "+id)
		var slot:=Vector2(index%4,index/4)*cell
		var extent:float=minf(cell.x-25,cell.y-45)
		var payload:Dictionary=view._object_painted_sprite_draw_payload(id,texture,slot+cell*.5,extent)
		var region:Dictionary=view._object_texture_visible_regions[id]
		painter.paint(payload.draw_texture,payload.draw_rect,Color.WHITE,profile,region.normalized_source_rect,id,Vector2i(index,0),0,true)
		cards.append({"id":id,"rect":payload.draw_rect,"region":region.normalized_source_rect,"profile":profile})
		var label:=Label.new()
		label.text=id
		label.position=slot+Vector2(8,4)
		label.add_theme_font_size_override("font_size",12)
		gallery.add_child(label)
	painter.finish()
	check(painter.entries.size()==ids.size(),"gallery omitted listed assets")
	check(painter.batches.size()==ids.size(),"gallery duplicates sprites")
	if DisplayServer.get_name()!="headless":
		var images:Array[Image]=[]
		for index in range(4):
			for entry in painter.entries:entry.batch.material.set_shader_parameter("clock_override",float(index)*1.5)
			for frame in range(2):await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var capture:=get_viewport().get_texture().get_image()
			capture.save_png(out.path_join("scenery-gallery-%02d.png"%index))
			images.append(capture)
		for card in cards:
			var rect:Rect2=card.rect
			var crop:=Rect2i(rect.grow(-2.0))
			check(images[0].get_region(crop).get_data()!=images[2].get_region(crop).get_data(),"painted asset does not animate: "+card.id)
			if int(card.profile.mode)==1:
				var anchor:float=(float(card.profile.anchor)-card.region.position.y)/card.region.size.y
				var lower:=Rect2i(Vector2(rect.position.x+2,rect.position.y+rect.size.y*maxf(anchor,.75)+2),Vector2(rect.size.x-4,rect.size.y*(1.0-maxf(anchor,.75))-4))
				check(images[0].get_region(lower).get_data()==images[2].get_region(lower).get_data(),"tree grounding moves: "+card.id)
			else:
				var area:Array=card.profile.region
				var activity:=Rect2(area[0],area[1],area[2],area[3])
				var rigid:=true
				for y in range(crop.position.y,crop.end.y,4):
					for x in range(crop.position.x,crop.end.x,4):
						var original:Vector2=card.region.position+(Vector2(x+.5,y+.5)-rect.position)/rect.size*card.region.size
						if activity.has_point(original) or (int(card.profile.mode)==2 and original.y<float(card.profile.anchor)):continue
						if images[0].get_pixel(x,y)!=images[2].get_pixel(x,y):rigid=false
				check(rigid,"building moves outside its activity region: "+card.id)
		await capture_scenery_clip(painter,"scenery-live-gallery",out)
		painter.set_motion_enabled(false)
		var static_images:Array[Image]=[]
		for time in [0.0,2.0]:
			for entry in painter.entries:entry.batch.material.set_shader_parameter("clock_override",time)
			await RenderingServer.frame_post_draw
			static_images.append(get_viewport().get_texture().get_image())
		check(static_images[0].get_data()==static_images[1].get_data(),"disabled scenery still changes pixels")
		static_images[0].save_png(out.path_join("scenery-gallery-static.png"))
		for entry in painter.entries:
			entry.batch.material=null
			entry.batch.commands[0][1][1]=entry.rect
			entry.batch.queue_redraw()
		for i in range(2):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var original_paint:=get_viewport().get_texture().get_image()
		original_paint.save_png(out.path_join("scenery-gallery-original.png"))
		for card in cards:
			var crop:=Rect2i(card.rect.grow(-3.0))
			var max_delta:=0.0
			for y in range(crop.position.y,crop.end.y,3):
				for x in range(crop.position.x,crop.end.x,3):
					var a:Color=original_paint.get_pixel(x,y)
					var b:Color=static_images[0].get_pixel(x,y)
					max_delta=maxf(max_delta,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
			check(max_delta<=.025,"disabled shader distorts original asset/crop: "+card.id)
	gallery.queue_free()
	for i in range(4):await get_tree().process_frame
	check(shell._session.to_dict()==session_before,"scenery changes simulation/save state")
	view.set_process(was_processing)
'''

SCRIPT = animation.SCRIPT.replace('func run()->void:', SCENERY+'\nfunc run()->void:')
SCRIPT = SCRIPT.replace('await player_route_sequence(shell,out)',
                        'await scenery_controls(shell,out)\n\t\tawait player_route_sequence(shell,out)', 1)
# The first occurrence is in the headless helper with one-tab indentation.
SCRIPT = SCRIPT.replace('\tawait scenery_controls(shell,out)\n\t\tawait player_route_sequence(shell,out)',
                        '\tawait scenery_controls(shell,out)\n\tawait player_route_sequence(shell,out)', 1)
SCRIPT = SCRIPT.replace('\t\tvar order:Dictionary=shell._commit_end_turn()',
                        '\t\tawait scenery_controls(shell,out)\n\t\tvar order:Dictionary=shell._commit_end_turn()')

def main():
    animation.OUTPUT = OUTPUT
    animation.SCRIPT = SCRIPT
    animation.run_probe = run_probe
    animation.probe_environment = probe_environment
    return animation.main()

if __name__ == '__main__':
    raise SystemExit(main())
