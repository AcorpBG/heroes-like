"""Focused common-mine economy, geometry, fog and actual GPU animation checks."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Mines = preload("res://scripts/core/CommonMineRules.gd")
const Art = preload("res://scenes/overworld/OverworldMine.gd")
const View = preload("res://scenes/overworld/OverworldMapView.gd")
const Batch = preload("res://scenes/overworld/OverworldSceneryBatch.gd")
var failures := []
var checks := 0
var out := ""
var painter = Batch.new()
var samples := []
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func capture() -> Image:
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
func clock_at(t: float):
	for entry in painter.entries:
		entry.batch.material.set_shader_parameter("clock_override", t)
		entry.batch.material.set_shader_parameter("phase", 0.0)
func _ready(): call_deferred("run")
func run():
	out = OS.get_cmdline_user_args()[0]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	SettingsService.set_reduced_motion_enabled(false)
	var session = Factory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	Rules.normalize_overworld_state(session)
	var view = View.new()
	view.size = Vector2(1280,720)
	add_child(view)
	var aliases := []
	for site in ContentService.load_json("res://content/resource_sites.json").items:
		if not site.has("common_mine_resource"): continue
		aliases.append(site)
		var node := {"site_id":site.id,"x":5,"y":5,"placement_id":site.id}
		var resource := String(site.common_mine_resource)
		check(site.control_income[resource] == (1000 if resource=="gold" else 2), "incorrect income: "+site.id)
		check(view._resource_asset_id(node)=="mapobj_common_%s_mine"%resource,"alias art: "+site.id)
		check(view._object_profile_footprint(view._resource_object_profile(node))==Vector2i(3,2),"alias footprint: "+site.id)
		check(Mines.body_tiles(node).size()==6 and Mines.block_tiles(node).size()==5,"six-cell footprint: "+site.id)
		node.collected_by_player_id="mine_test_player"
		session.overworld.resource_nodes=[node]
		for day in [2,8]:
			check(Rules.controlled_resource_site_income(session,"mine_test_player",day)[resource]==(1000 if resource=="gold" else 2),"controlled daily income: "+site.id)
		check(Rules.controlled_resource_site_income(session,"other_player",2)[resource]==0,"income credited to wrong owner: "+site.id)
	check(aliases.size()==12,"missing legacy aliases")
	var rare := {"kind":"mine","object_id":"object_cinder_ore_face","site_id":"site_aetherglass_lens_house","x":5,"y":5}
	check(Mines.resource(rare).is_empty(),"rare mine reclassified as ore")
	check(view._resource_asset_id(rare)=="mapobj_aetherglass_lens_house","rare mine uses obsolete ore art")
	check(Mines.resource({"kind":"reward_reference","site_id":"site_ridge_quarry"}).is_empty(),"loose reward turned into mine")
	var node := {"site_id":"site_ridge_quarry","kind":"mine","object_id":"object_ridge_quarry","placement_id":"geometry_mine","x":3,"y":3,"visit_tile":{"x":3,"y":3},"level":0,"package_block_tiles":[{"x":8,"y":8}],"runtime_footprint":{"width":1,"height":1},"object_footprint_catalog_ref":{"test":"retained"},"collected":false}
	var original := node.duplicate(true)
	session.overworld.resource_nodes=[node]
	session.overworld.map_objects=[]
	session.overworld.towns=[]
	session.overworld.encounters=[]
	var index: Dictionary = Rules._build_blocked_tile_index(session,0)
	for tile in Mines.block_tiles(node): check(index.has("%d,%d"%[tile.x,tile.y]),"missing mine body cell")
	check(not index.has("3,3"),"mine entrance is blocked")
	check(not index.has("8,8"),"obsolete runtime mine mask still blocks movement")
	check(Rules._resource_node_world_interaction_tiles(ContentService.get_map_object("object_ridge_quarry"),node)==[Vector2i(3,3)],"approach moved")
	check(node==original,"source package record mutated")
	var fog: Dictionary = session.overworld.fog
	for row in fog.explored_tiles: row.fill(true)
	for row in fog.visible_tiles: row.fill(true)
	view.set_map_state(session,session.overworld.map,Vector2i(session.overworld.map[0].size(),session.overworld.map.size()),Vector2i(-1,-1))
	var before: Dictionary = session.to_dict().duplicate(true)
	var map_image := await capture()
	map_image.save_png(out+"/mine-live-map.png")
	var cells := []
	for entry in view._scenery_batches.entries:
		if entry.get("kind","")=="common_mine": cells.append(entry.cell)
	check(not cells.is_empty(),"live renderer never painted mine")
	var generation: int = view._scenery_batches.generation
	await get_tree().create_timer(.4).timeout
	check(view._scenery_batches.generation==generation,"mine animation rebuilt cached map")
	if not cells.is_empty():
		var hidden: Vector2i = cells[0]
		fog.explored_tiles[hidden.y][hidden.x]=false
		fog.visible_tiles[hidden.y][hidden.x]=false
		view._invalidate_state_cache("mine_partial_fog")
		await capture()
		for entry in view._scenery_batches.entries:
			check(not(entry.get("kind","")=="common_mine" and entry.cell==hidden),"mine smoke/body leaks through fog")
	session.overworld.fog=before.overworld.fog.duplicate(true)
	check(session.to_dict()==before,"presentation changed saved game state")
	view.hide()
	var gallery := Control.new()
	add_child(gallery)
	var art := Art.new()
	art.configure(ContentService.load_json("res://art/overworld/common_mines.json"))
	painter.begin(gallery)
	painter.record(&"draw_rect",[Rect2(0,0,1280,720),Color(.095,.10,.085)])
	var resources := ["wood","ore","gold"]
	for i in range(3):
		var terrain: String = ["grass","sand","snow"][i]
		var region := Rect2(i*426+8,20,410,680)
		painter.record(&"draw_rect",[region,[Color(.25,.31,.16),Color(.57,.45,.28),Color(.68,.72,.74)][i]])
		painter.record(&"draw_string",[ThemeDB.fallback_font,Vector2(i*426+20,48),resources[i].to_upper()+" — "+terrain,HORIZONTAL_ALIGNMENT_LEFT,-1,18])
		for j in range(2):
			var width := 330.0 if j==0 else 174.0
			var footprint := Rect2(Vector2(i*426+213-width/2,425 if j==0 else 641)-Vector2(0,width*2/3),Vector2(width,width*2/3))
			var pose: Dictionary = art.payload(resources[i],footprint)
			var material: ShaderMaterial = Art.material(pose,resources[i]+str(j),true)
			painter.paint_material(pose.texture,pose.rect,Color.WHITE,material,{"kind":"mine_sample"})
			samples.append(pose)
	painter.finish()
	clock_at(0)
	var first := await capture()
	first.save_png(out+"/mines-0.png")
	clock_at(.85)
	var second := await capture()
	second.save_png(out+"/mines-1.png")
	for pose in samples:
		var rect: Rect2=pose.rect
		var canvas: Vector2=pose.canvas
		var scale: Vector2=rect.size/canvas
		var chimney := Vector2(pose.entry.chimney[0],pose.entry.chimney[1])
		var smoke := Rect2i(rect.position+(chimney-Vector2(20,95))*scale,Vector2(70,92)*scale)
		check(first.get_region(smoke).get_data()!=second.get_region(smoke).get_data(),"no moving chimney smoke: "+pose.resource)
		for part in pose.entry.parts:
			var region := Rect2i(rect.position+Vector2(part.rect[0],part.rect[1])*scale,Vector2(part.rect[2],part.rect[3])*scale)
			check(first.get_region(region).get_data()!=second.get_region(region).get_data(),"machinery static: "+pose.resource)
		for point in pose.entry.lights:
			var lamp := Rect2i(rect.position+(Vector2(point[0],point[1])-Vector2(5,5))*scale,Vector2(10,10)*scale)
			check(first.get_region(lamp).get_data()!=second.get_region(lamp).get_data(),"lamp static: "+pose.resource)
		var foundation := Rect2i(rect.position+Vector2(210,578)*scale,Vector2(70,22)*scale)
		check(first.get_region(foundation).get_data()==second.get_region(foundation).get_data(),"stationary foundation moves: "+pose.resource)
	painter.set_motion_enabled(false)
	var reduced_a := await capture()
	clock_at(4.7)
	var reduced_b := await capture()
	check(reduced_a.get_data()==reduced_b.get_data(),"reduced motion still changes pixels")
	for frame in range(12):
		painter.set_motion_enabled(true)
		clock_at(float(frame)*.25)
		var sample := await capture()
		sample.save_png(out+"/motion-%02d.png"%frame)
	print("UNIFIED_MINES_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mine-probe-', dir=out) as directory:
        work = Path(directory)
        (work/'probe.gd').write_text(SCRIPT, encoding='utf-8')
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="MineProbe" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        command = [args.godot, '--path', str(ROOT), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--position', '-16000,-16000', '--resolution', '1280x720', '--quit-after', '900', '--log-file', str(out/'engine.log'), 'res://'+scene.relative_to(ROOT).as_posix(), '--', str(out)]
        if os.name != 'nt': command = ['xvfb-run', '-a'] + command
        with (out/'console.log').open('w', encoding='utf-8') as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120,
                                    creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        text = (out/'console.log').read_text(encoding='utf-8')
        print(text)
        errors = [line for line in text.splitlines() if 'ERROR' in line and line != 'ERROR: Failed to read the root certificate store.']
        return result.returncode or int(bool(errors) or 'UNIFIED_MINES_REPORT' not in text)


if __name__ == '__main__':
    raise SystemExit(main())
