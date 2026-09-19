"""Focused real-renderer scenery motion, slice continuity, fog and rigid rock checks."""
import re
import native_scenery_formation_regression as formation

source = formation.harness.SOURCE
script = formation.script.replace('extends Node2D', 'extends Control', 1)
for name in ['_draw_living_scenery', '_draw_living_scenery_region']:
    live = re.search(rf'^func {name}\(.*?(?=^func |\Z)', source, re.M | re.S)[0].rstrip()
    script = re.sub(rf'^func {name}\(.*?(?=^func |\Z)', lambda _: live+'\n', script, count=1, flags=re.M | re.S)
script = script.replace('var textures := {}', '''const SceneryBatch = preload("res://scenes/overworld/OverworldSceneryBatch.gd")
var _scenery_manifest: Dictionary = ContentService.load_json("res://content/overworld_scenery_animation.json")
var _scenery_batches = SceneryBatch.new()
var _level := 0
var _state_layer: Control
var _draw_canvas_item: Control
var textures := {}''')
script = script.replace('func _ready():', 'func _canvas_draw_texture_rect(texture,rect,tiled,tint): draw_texture_rect(texture,rect,tiled,tint)\nfunc _scenery_motion_enabled() -> bool: return true\nfunc _ready():', 1)
script = script.replace('func _draw():', '''func _draw():
    _state_layer=self
    _draw_canvas_item=self
    _scenery_batches.begin(self)''', 1)
script = script.replace('func run():', '    _scenery_batches.finish()\nfunc run():', 1)

extra = '''
func set_clock(painter, time: float):
    for material in painter._materials.values(): material.set_shader_parameter("clock_override",time)
func frame() -> Image:
    for i in range(2): await get_tree().process_frame
    await RenderingServer.frame_post_draw
    return get_viewport().get_texture().get_image()
func motion_checks(out: String):
    check(not _scenery_batches.entries.is_empty(),"current formation renderer has no animation")
    var shared := {}
    var repeated := 0
    for entry in _scenery_batches.entries:
        check(entry.tile!=fogged,"animated formation leaks into fog")
        if not entry.has("phase_tile"): continue
        var key := str([entry.asset_id,entry.phase_tile])
        if shared.has(key):
            check(shared[key]==entry.batch.material,"slices do not share full-formation material/phase")
            repeated+=1
        shared[key]=entry.batch.material
    check(repeated>0,"test never exercised multi-tile animation")
    var generation: int = _scenery_batches.generation
    set_clock(_scenery_batches,0.0)
    var first: Image = await frame()
    first.save_png(out+"/motion-map-0.png")
    set_clock(_scenery_batches,1.5)
    var second: Image = await frame()
    second.save_png(out+"/motion-map-1.png")
    check(first.get_data()!=second.get_data(),"live formation map is motionless")
    check(_scenery_batches.generation==generation,"idle animation rebuilt map commands")
    for offset in [Vector2i(1,1),Vector2i(24,24),Vector2i(46,46)]:
        var point: Vector2i = fogged*48+offset
        check(first.get_pixel(point.x,point.y).v<.05 and second.get_pixel(point.x,point.y).v<.05,"motion leaks through fog")
    # Compare one large draw with the same sprite split into nine adjacent
    # tiles. This detects discontinuous phase, crop UVs and edge clamping.
    var gallery := Control.new()
    add_child(gallery)
    var backdrop := ColorRect.new()
    backdrop.size=Vector2(960,720)
    backdrop.color=Color(.055,.07,.06,1)
    gallery.add_child(backdrop)
    var painter = SceneryBatch.new()
    var ids := ["native_vegetation_woods_plains_full_v3","native_vegetation_deadwood_dirt_thicket_v3","native_vegetation_wetland_reed_beds_00","native_mountain_rough_ridge_v3","native_mountain_ash_lava_wastes_00","mapobj_cinder_kiln"]
    painter.begin(gallery)
    var cards := []
    for index in range(ids.size()):
        var id: String = ids[index]
        var texture: Texture2D = _object_texture_for_asset(id)
        var region := _object_texture_visible_region(id,texture)
        var raster: Texture2D = region.draw_texture
        var profile: Dictionary = SceneryBatch.profile_for_asset(_scenery_manifest,id)
        check(not profile.is_empty(),"current asset has no motion profile: "+id)
        var slot := Vector2(index%3,index/3)*Vector2(320,350)+Vector2(12,35)
        var a := Rect2(slot,Vector2(144,144))
        var b := Rect2(slot+Vector2(152,0),a.size)
        var original: Rect2 = region.normalized_source_rect
        painter.paint_region(raster,a,Rect2(Vector2.ZERO,raster.get_size()),Color.WHITE,profile,original,id,Vector2i(index,0),Vector2i(index,0),0,true)
        for y in range(3):
            for x in range(3):
                var part := Formation.clip(b,Rect2(b.position+Vector2(x,y)*48,Vector2(48,48)),raster.get_size())
                painter.paint_region(raster,part.rect,part.source,Color.WHITE,profile,original,id,Vector2i(x,y),Vector2i(index,0),0,true)
        cards.append({"id":id,"a":Rect2i(a),"b":Rect2i(b),"profile":profile,"original":original})
        var label := Label.new()
        label.text=id.trim_prefix("native_")
        label.position=slot-Vector2(0,25)
        label.add_theme_font_size_override("font_size",11)
        gallery.add_child(label)
    painter.finish()
    check(painter._materials.size()==ids.size(),"slice materials not reused")
    set_clock(painter,0.0)
    var a: Image = await frame()
    set_clock(painter,1.5)
    var b: Image = await frame()
    a.save_png(out+"/motion-gallery-0.png")
    b.save_png(out+"/motion-gallery-1.png")
    for card in cards:
        var delta := 0.0
        var changed := 0
        var rigid := true
        for y in range(card.a.size.y):
            for x in range(card.a.size.x):
                var p: Vector2i = card.a.position+Vector2i(x,y)
                var q: Vector2i = card.b.position+Vector2i(x,y)
                var left: Color = b.get_pixelv(p)
                var right: Color = b.get_pixelv(q)
                delta=maxf(delta,maxf(absf(left.r-right.r),maxf(absf(left.g-right.g),absf(left.b-right.b))))
                if a.get_pixelv(p)!=left: changed+=1
                var original_y: float = card.original.position.y+(y+.5)/144.0*card.original.size.y
                if card.profile.mode==1 and original_y>float(card.profile.anchor)+.03 and a.get_pixelv(p)!=left: rigid=false
        check(delta<=.012,"visible tile seam in moving texture: "+card.id+" delta="+str(delta))
        check(changed>10,"no visible motion/effect: "+card.id)
        check(rigid,"vegetation roots move: "+card.id)
    painter.set_motion_enabled(false)
    set_clock(painter,0)
    var disabled: Image = await frame()
    set_clock(painter,3)
    var disabled_later: Image = await frame()
    check(disabled.get_data()==disabled_later.get_data(),"disabled motion changes pixels")
    # Inspect actual alpha on a transparent viewport; comparing RGB against
    # ground would confuse quantized edge-lighting changes with geometry.
    var alpha_view := SubViewport.new()
    alpha_view.size=Vector2i(160,160)
    alpha_view.transparent_bg=true
    alpha_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(alpha_view)
    var alpha_host := Control.new()
    alpha_view.add_child(alpha_host)
    var alpha_painter = SceneryBatch.new()
    alpha_painter.begin(alpha_host)
    var rock: Texture2D = _object_texture_for_asset(ids[3])
    var rock_profile: Dictionary = SceneryBatch.profile_for_asset(_scenery_manifest,ids[3])
    alpha_painter.paint_region(rock,Rect2(8,8,144,144),Rect2(Vector2.ZERO,rock.get_size()),Color.WHITE,rock_profile,Rect2(0,0,1,1),ids[3],Vector2i.ZERO,Vector2i.ZERO,0,true)
    alpha_painter.finish()
    set_clock(alpha_painter,0)
    await frame()
    var alpha_a: Image = alpha_view.get_texture().get_image()
    set_clock(alpha_painter,1.5)
    await frame()
    var alpha_b: Image = alpha_view.get_texture().get_image()
    var silhouette_stable := true
    for y in range(160):
        for x in range(160):
            if alpha_a.get_pixel(x,y).a!=alpha_b.get_pixel(x,y).a: silhouette_stable=false
    check(silhouette_stable,"rock silhouette changes")
    alpha_view.queue_free()
    check(SceneryBatch.profile_for_asset(_scenery_manifest,"unregistered_asset").is_empty(),"unknown art acquires effects")
    gallery.queue_free()
'''
script = script.replace('func run():',extra+'\nfunc run():',1)
script = script.replace('\tprint("SCENERY_FORMATIONS ', '\tawait motion_checks(OS.get_cmdline_user_args()[0])\n\tprint("SCENERY_FORMATION_MOTION ',1)
script = re.sub(r'(?m)^( +)', lambda m: '\t'*(len(m[1])//4), script)

if __name__ == '__main__':
    raise SystemExit(formation.harness.main(script=script,node_type='Control'))
