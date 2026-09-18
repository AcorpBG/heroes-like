"""Native-footprint scenery rendering, masks and fog slicing; no game generation."""
import re
import native_scenery_variety_regression as harness

names = ['_index_generated_decorative_body_cells', '_index_native_scenery_formations', '_index_native_rock_contacts', '_draw_native_rock_contacts',
         '_generated_decorative_body_asset_id', '_native_scenery_assets', '_native_scenery_modulate',
         '_generated_decorative_body_motif_key', '_generated_decorative_body_composition',
         '_stable_unit_fraction', '_tile_key', '_tiles_from_payloads',
         '_draw_generated_decorative_body_sprite', '_draw_native_scenery_formation',
         '_object_painted_sprite_draw_payload', '_object_texture_visible_region',
         '_object_canvas_draw_rect', '_object_world_tile_extent']
live = '\n'.join(re.search(rf'^func {name}\(.*?(?=^func |\Z)', harness.SOURCE, re.M|re.S).group().rstrip() for name in names)
constants = '\n'.join(re.findall(r'^const (?:GENERATED_DECORATIVE_BODY_\w+|OBJECT_PAINTED_BOUNDS_PADDING_PIXELS|OBJECT_MIN_PAINTED_EXTENT_FRACTION|OBJECT_VISIBLE_SCALE_MODEL|OBJECT_SPRITE_VISIBLE_MODULATE|OBJECT_SPRITE_MEMORY_MODULATE).*$', harness.SOURCE,re.M))
script = 'extends Node2D\n'+constants+'\n'+harness.CONSTANT+'\n'+live+'''
const Formation = preload("res://scripts/persistence/NativeSceneryFormation.gd")
var _map_size := Vector2i(20,15)
var _generated_decorative_bodies_by_tile := {}
var _generated_decorative_blocker_asset_ids_by_biome := {}
var _generated_decorative_blocker_fallback_asset_ids := []
var _object_texture_visible_regions := {}
var textures := {}
var failures := []
var checks := 0
var fogged := Vector2i(15,12)
func check(ok: bool, label: String):
    checks += 1
    if not ok: failures.append(label)
func _terrain_at(tile: Vector2i) -> String: return ["grass","rough","forest"][clampi(tile.y/5,0,2)]
func _board_rect() -> Rect2: return Rect2(0,0,960,720)
func _object_lift_fraction(_a,_b) -> float: return 0.12
func _decorative_object_asset_id(object) -> String: return object.overworld_sprite_asset_id
func _object_texture_for_asset(id: String):
    if not textures.has(id):
        var path: String = ContentService.load_json("res://art/overworld/manifest.json").object_assets[id].path
        textures[id] = ImageTexture.create_from_image(Image.load_from_file(ContentService.local_path(path)))
    return textures[id]
func _draw_mapped_sprite_grounding_anchor(_a,_b,_c,_d,_e): pass
func _draw_living_scenery(_id,texture,rect,tint,_tile): draw_texture_rect(texture,rect,false,tint)
func _canvas_draw_texture_rect_region(texture,rect,source,tint): draw_texture_rect_region(texture,rect,source,tint)
func _ready(): call_deferred("run")
func _draw():
    var keys := _generated_decorative_bodies_by_tile.keys()
    keys.sort()
    for key in keys:
        var cell: Dictionary = _generated_decorative_bodies_by_tile[key]
        var tile := Vector2i(cell.x,cell.y)
        if tile==fogged: continue
        _draw_generated_decorative_body_sprite(cell,Rect2(Vector2(tile)*48.0,Vector2(48,48)),false,tile)
func run():
    var originals := []
    for row in range(3):
        for column in range(4):
            var sizes := [Vector2i(1,1),Vector2i(2,2),Vector2i(3,2),Vector2i(5,3)]
            var starts := [1,4,8,13]
            var size: Vector2i = sizes[column]
            var body := []
            for y in range(size.y):
                for x in range(size.x):
                    # Exact 12-cell shape from the preserved 5x3 mountain record.
                    if column==3 and ((y==0 and x==0) or (y==2 and x>=3)): continue
                    body.append({"x":starts[column]+x,"y":row*5+1+y})
            var object := {"placement_id":"fixture_%d_%d"%[row,column],"runtime_object_role":"decorative_blocker_sprite","native_scenery_art_version":2,"h3m_type_id":134 if row==1 else 135,"package_block_tiles":body}
            var before := object.duplicate(true)
            _index_generated_decorative_body_cells(object)
            check(object==before,"source record mutated")
            originals.append(object)
    _index_native_rock_contacts()
    var expected := {}
    for object in originals:
        for tile in _tiles_from_payloads(object.package_block_tiles): expected[_tile_key(tile)] = true
    check(_generated_decorative_bodies_by_tile.size()==expected.size(),"body coverage changed")
    var formations := {}
    for key in expected:
        check(_generated_decorative_bodies_by_tile.has(key),"missing blocked cell")
        var cell: Dictionary = _generated_decorative_bodies_by_tile[key]
        var f: Dictionary = cell.get("generated_body_formation",{})
        if f.is_empty(): continue
        formations[f.source_placement_id] = f
        var tile := Vector2i(cell.x,cell.y)
        var bounds := Rect2(Vector2(tile)*48.0,Vector2(48,48))
        var part := Formation.slice(f,tile,bounds,Vector2(224,190))
        if not part.is_empty():
            check(bounds.encloses(part.rect),"formation escaped mask/fog cell")
            check(part.painted_rect.size.x>48.0 and part.painted_rect.size.y>48.0,"formation remains miniature")
    check(formations.size()==9,"multi-tile groups missing")
    check(not _generated_decorative_bodies_by_tile.has("13,1"),"irregular mask hole filled")
    var existing := _generated_decorative_bodies_by_tile.duplicate(true)
    var overlap: Dictionary = originals[1].duplicate(true)
    overlap.placement_id = "overlap"
    _index_generated_decorative_body_cells(overlap)
    for tile in _tiles_from_payloads(overlap.package_block_tiles):
        var key := _tile_key(tile)
        check(_generated_decorative_bodies_by_tile[key].generated_body_formation==existing[key].generated_body_formation,"overlap changed formation ownership")
    var sample: Dictionary = originals[3]
    var tiles := _tiles_from_payloads(sample.package_block_tiles)
    var a := Formation.groups(tiles)
    tiles.reverse()
    check(a==Formation.groups(tiles),"input order changes connected formation")
    check(Formation.groups([Vector2i(0,0),Vector2i(3,0)]).size()==2,"disconnected bodies merged")
    var legacy := sample.duplicate(true)
    legacy.native_scenery_art_version = 1
    _generated_decorative_bodies_by_tile.clear()
    _index_generated_decorative_body_cells(legacy)
    for cell in _generated_decorative_bodies_by_tile.values(): check(not cell.has("generated_body_formation"),"legacy presentation changed")
    _generated_decorative_bodies_by_tile=existing
    var ground = load("res://scenes/overworld/OverworldGroundSurface.gd").new()
    add_child(ground)
    ground.z_index=-2
    ground.configure(ContentService.load_json("res://art/overworld/ground_materials.json"),ImageTexture.create_from_image(Image.load_from_file(ContentService.local_path("res://art/overworld/runtime/terrain_tiles/ground_materials_v3.png"))))
    var rows := [];var fog := []
    for y in range(15):
        var row := [];var visible := []
        for x in range(20):
            row.append(_terrain_at(Vector2i(x,y)));visible.append(Vector2i(x,y)!=fogged)
        rows.append(row);fog.append(visible)
    ground.sync_lookup(rows,_map_size,1,fog,1)
    ground.sync_layout(Rect2(0,0,960,720),Rect2(0,0,960,720),_map_size)
    var shroud := Polygon2D.new()
    shroud.polygon=PackedVector2Array([Vector2.ZERO,Vector2(48,0),Vector2(48,48),Vector2(0,48)])
    shroud.position=Vector2(fogged)*48.0
    shroud.color=Color(0.015,0.015,0.015)
    shroud.z_index=-1
    add_child(shroud)
    queue_redraw()
    for i in range(3): await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var capture := get_viewport().get_texture().get_image()
    for offset in [Vector2i(1,1),Vector2i(24,24),Vector2i(46,46)]:
        var point: Vector2i = fogged*48+offset
        check(capture.get_pixel(point.x,point.y).v<0.05,"large scenery leaked into fogged cell")
    capture.save_png(OS.get_cmdline_user_args()[0]+"/formations.png")
    print("SCENERY_FORMATIONS "+JSON.stringify({"checks":checks,"failures":failures,"body_cells":expected.size(),"large_formations":formations.size()}))
    get_tree().quit(0 if failures.is_empty() else 1)
'''

script = re.sub(r'(?m)^( +)', lambda m: '\t' * (len(m[1]) // 4), script)

if __name__=='__main__':
    raise SystemExit(harness.main(script=script,node_type='Node2D'))
