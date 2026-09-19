"""Read-only dense saved-map scenery review and focused scale assertions."""
import argparse
import json
import re
import sys
import native_scenery_formation_regression as formation

parser=argparse.ArgumentParser(add_help=False)
parser.add_argument('--save',required=True)
parser.add_argument('--origin',required=True,help='Top-left tile of the 20 x 15 review area, as x,y')
args,remaining=parser.parse_known_args()
sys.argv=[sys.argv[0]]+remaining
x,y=map(int,args.origin.split(','))
script=formation.script.split('func _ready():')[0]
script=script.replace('func _terrain_at(tile: Vector2i) -> String: return ["grass","rough","forest"][clampi(tile.y/5,0,2)]','func _terrain_at(tile: Vector2i) -> String: return review.map[clampi(tile.y,0,_map_size.y-1)][clampi(tile.x,0,_map_size.x-1)]')
script=script.replace('func _board_rect() -> Rect2: return Rect2(0,0,960,720)','func _board_rect() -> Rect2: return Rect2(-Vector2(crop_origin)*48.0,Vector2(_map_size)*48.0)')
script=script.replace('func _draw_living_scenery(_id,texture,rect,tint,_tile): draw_texture_rect(texture,rect,false,tint)', '''var drawn_bodies := {}
func _draw_living_scenery(id,texture,rect,tint,tile):
    drawn_bodies[_tile_key(tile)] = {"id":id,"size":rect.size}
    draw_texture_rect(texture,rect,false,tint)
''')
script+='\nvar review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string('+json.dumps(args.save.replace('\\','/'))+')).overworld\n'
script+=f'var crop_origin := Vector2i({x},{y})\n'
script+='''
func _ready(): call_deferred("run")
func _draw():
    var view := Rect2i(crop_origin-Vector2i(2,2),Vector2i(24,19))
    for cell in _generated_decorative_bodies_by_tile.values():
        var tile := Vector2i(cell.x,cell.y)
        if not view.has_point(tile) or tile==fogged: continue
        _draw_generated_decorative_body_sprite(cell,Rect2(Vector2(tile-crop_origin)*48.0,Vector2(48,48)),false,tile)
    for y in range(15):
        for x in range(20):
            var tile := crop_origin+Vector2i(x,y)
            if tile!=fogged: _draw_native_scenery_layers_at(tile,Rect2(Vector2(x,y)*48.0,Vector2(48,48)),false)
func run():
    _map_size=Vector2i(review.map[0].size(),review.map.size())
    fogged=crop_origin+Vector2i(18,13)
    var original := JSON.stringify(review.map_objects)
    var expected := {}
    for object in review.map_objects:
        if object.get("runtime_object_role","")!="decorative_blocker_sprite" or int(object.get("level",0))!=0: continue
        _index_generated_decorative_body_cells(object)
        for tile in _tiles_from_payloads(object.get("package_block_tiles",[])): expected[_tile_key(tile)]=true
    _index_native_rock_contacts()
    check(original==JSON.stringify(review.map_objects),"saved source records mutated")
    check(_generated_decorative_bodies_by_tile.size()==expected.size(),"saved collision coverage changed")
    for key in expected: check(_generated_decorative_bodies_by_tile.has(key),"saved blocked cell lost")
    var patches := {}
    var joined_records := 0
    for cell in _generated_decorative_bodies_by_tile.values():
        var f: Dictionary = cell.get("generated_body_formation",{})
        if f.get("connected_landscape",false): patches[f.source_placement_id]=f
    for f in patches.values():
        var sources := {}
        for tile in f.tiles:
            check(expected.has(_tile_key(tile)),"landscape patch base covers an open tile")
            var cell: Dictionary = _generated_decorative_bodies_by_tile[_tile_key(tile)]
            check(cell.get("generated_body_rock_contacts",[]).is_empty(),"patch retains repeated rubble contacts")
            check(_terrain_at(tile)==_terrain_at(f.anchor),"landscape patch crossed terrain boundary")
            sources[cell.generated_body_anchor_placement_id]=true
        if sources.size()>1: joined_records+=1
    var layers_before := _native_scenery_layers_by_tile.duplicate(true)
    _index_native_rock_contacts()
    check(_native_scenery_layers_by_tile==layers_before,"patches change on reindex")
    var rules=preload("res://scripts/persistence/NativeSceneryRules.gd")
    var tree:=rules.body_scale({"h3m_type_id":135},"biome_component_v2_highland_ridge_woods_00")
    for type in [116,125,129]:
        var low:=rules.body_scale({"h3m_type_id":type},"biome_component_v2_highland_ridge_undergrowth_20")
        check(low.y<=tree.y*0.4,"ground plant can exceed tree height")
    var ground=load("res://scenes/overworld/OverworldGroundSurface.gd").new()
    add_child(ground);ground.z_index=-2
    ground.configure(ContentService.load_json("res://art/overworld/ground_materials.json"),ImageTexture.create_from_image(Image.load_from_file(ContentService.local_path("res://art/overworld/runtime/terrain_tiles/ground_materials_v3.png"))))
    var rows:=[];var fog:=[]
    for y in range(15):
        var row:=[];var visible:=[]
        for x in range(20):
            row.append(_terrain_at(crop_origin+Vector2i(x,y)));visible.append(crop_origin+Vector2i(x,y)!=fogged)
        rows.append(row);fog.append(visible)
    ground.sync_lookup(rows,Vector2i(20,15),1,fog,1)
    ground.sync_layout(Rect2(0,0,960,720),Rect2(0,0,960,720),Vector2i(20,15))
    queue_redraw()
    for i in range(3): await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var low_draws := 0
    var tallest_low := 0.0
    for key in drawn_bodies:
        var cell: Dictionary = _generated_decorative_bodies_by_tile[key]
        var policy: Dictionary = rules.policy(cell)
        var family: String = policy.get("landscape_family",policy.get("variation_family",""))
        if family not in ["wetland","scrub","fungi"]: continue
        low_draws += 1
        tallest_low = maxf(tallest_low,drawn_bodies[key].size.y)
        check(drawn_bodies[key].size.y<=48.0*0.42+0.01,"rendered ground plant exceeds scale limit")
    var capture:=get_viewport().get_texture().get_image()
    capture.save_png(OS.get_cmdline_user_args()[0]+"/dense-map.png")
    print("SCENERY_SCALE "+JSON.stringify({"checks":checks,"failures":failures,"saved_body_cells":expected.size(),"small_plant_draws":low_draws,"tallest_small_plant_px":tallest_low,"landscape_patches":patches.size(),"patches_joining_source_records":joined_records}))
    get_tree().quit(0 if failures.is_empty() else 1)
'''
script=re.sub(r'(?m)^( +)',lambda m:'\t'*(len(m[1])//4),script)
if __name__=='__main__':
    raise SystemExit(formation.harness.main(script=script,node_type='Node2D'))
