"""Focused town art, footprint selection and fog review; no map generation."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const View = preload("res://scenes/overworld/OverworldMapView.gd")
const Batch = preload("res://scenes/overworld/OverworldSceneryBatch.gd")
var checks := 0
var failures := []
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures.append(message)
func capture() -> Image:
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
func _ready(): call_deferred("run")
func run():
	var out: String=OS.get_cmdline_user_args()[0]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	get_tree().root.size=Vector2i(1280,720)
	get_tree().root.content_scale_size=Vector2i(1280,720)
	var session=Factory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	Rules.normalize_overworld_state(session)
	var rows := []
	var explored := []
	for y in range(12):
		var row := []; var known := []
		for x in range(18): row.append("grass"); known.append(true)
		rows.append(row); explored.append(known)
	session.overworld.map=rows
	session.overworld.map_size={"width":18,"height":12,"level_count":1}
	session.overworld.fog={"explored_tiles":explored,"visible_tiles":explored.duplicate(true)}
	session.overworld.resource_nodes=[]
	session.overworld.map_objects=[]
	session.overworld.artifact_nodes=[]
	session.overworld.encounters=[]
	var entry := Vector2i(9,8)
	var town: Dictionary=session.overworld.towns[0].duplicate(true)
	town.merge({"placement_id":"town_scale_fixture","x":11,"y":8,"visit_tile":{"x":9,"y":8},"level":0,"package_block_tiles":[{"x":8,"y":7}]},true)
	session.overworld.towns=[town]
	var original_town: Dictionary=town.duplicate(true)
	var view=View.new();view.size=Vector2(1280,720);add_child(view)
	view.set_map_state(session,rows,Vector2i(18,12),Vector2i(-1,-1))
	var live := await capture();live.save_png(out+"/town-live.png")
	check(Rules.is_tile_explored(session,entry.x,entry.y,0),"fixture town was not rendered in explored terrain")
	# Initial map binding refreshes the existing command-risk forecast cache.
	# Compare saved state after that lifecycle step, and source town data across it.
	var before: Dictionary=session.to_dict().duplicate(true)
	check(town==original_town,"initial presentation mutated source town")
	check(view._town_entry_tile(town)==entry,"source entrance moved")
	check(view.TOWN_PRESENTATION_FOOTPRINT==Vector2i(5,3),"wrong ground envelope")
	var cells: Array=view._town_footprint_cells_for_entry(entry)
	check(cells.size()==13,"ground mask is not tapered 3/5/5")
	check(not cells.has(entry+Vector2i(-2,-2)) and not cells.has(entry+Vector2i(2,-2)),"rear corner included")
	for cell in cells:
		check(view.town_footprint_selection(cell).get("entry_tile")==entry,"wall click misses entrance")
	var blocks: Dictionary=Rules._build_blocked_tile_index(session,0)
	check(blocks.has("8,7") and not blocks.has("7,7"),"native collision mask changed")
	var rect: Rect2=view._town_visual_rect_for_entry(entry)
	var slices: Array=view._town_explored_sprite_slices(rect,Vector2(512,512))
	check(not slices.is_empty(),"no explored town draw cells")
	var hidden: Vector2i=slices[0].cell
	session.overworld.fog.explored_tiles[hidden.y][hidden.x]=false
	for part in view._town_explored_sprite_slices(rect,Vector2(512,512)):
		check(part.cell!=hidden,"tower leaks through unexplored tile")
	session.overworld.fog=before.overworld.fog.duplicate(true)
	check(session.to_dict()==before,"presentation mutated source/save data")
	view.hide()
	var gallery:=Control.new();add_child(gallery)
	var painter=Batch.new()
	var manifest := ContentService.load_json("res://art/overworld/manifest.json")
	var skins := ContentService.load_json("res://art/overworld/town_biome_sprites.json")
	var ids := []
	for key in manifest.town_faction_sprites.values(): ids.append(key)
	for base in skins.appearances:
		if not ids.has(base): ids.append(base)
		for key in skins.appearances[base].biome_asset_ids.values():
			if not ids.has(key): ids.append(key)
	var ground_data := ContentService.load_json("res://art/overworld/ground_materials.json")
	var ground: Texture2D=load(ground_data.atlas)
	for start in range(0,ids.size(),6):
		painter.begin(gallery)
		painter.record(&"draw_rect",[Rect2(0,0,1280,720),Color(.09,.10,.085)])
		for local_index in range(mini(6,ids.size()-start)):
			var id: String=ids[start+local_index]
			var origin:=Vector2((local_index%3)*426,(local_index/3)*360)
			var texture: Texture2D=view._object_texture_for_asset(id)
			check(texture!=null,"missing town art: "+id)
			if texture==null: continue
			painter.record(&"draw_texture_rect_region",[ground,Rect2(origin+Vector2(30,50),Vector2(340,280)),Rect2(0,0,512,512)])
			var footprint:=Rect2(origin+Vector2(80,75),Vector2(240,240))
			var pose: Dictionary=view._town_sprite_draw_payload(id,texture,footprint,48)
			var drawn: Rect2=pose.draw_rect
			check(drawn.size.x<=4.801*48 and drawn.size.y<=4.351*48,"town exceeds reference envelope: "+id)
			check(is_equal_approx(drawn.size.x/drawn.size.y,float(pose.source_aspect)),"art stretched: "+id)
			check(maxf(drawn.size.x/4.8,drawn.size.y/4.35)>47.9,"town remains miniature: "+id)
			painter.record(&"draw_texture_rect",[pose.draw_texture,drawn,false])
			for cell in cells:
				var offset: Vector2i=cell-entry
				var cell_rect:=Rect2(footprint.position+Vector2(offset.x+2,offset.y+4)*48,Vector2(48,48))
				painter.record(&"draw_rect",[cell_rect,Color(.95,.76,.22,.85) if offset==Vector2i.ZERO else Color(.8,.15,.10,.4),false,1.0])
			painter.record(&"draw_string",[ThemeDB.fallback_font,origin+Vector2(12,25),id,HORIZONTAL_ALIGNMENT_LEFT,-1,14])
		painter.finish()
		var page := await capture();page.save_png(out+"/towns-%02d.png"%(start/6))
	print("TOWN_SCALE_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"appearances":ids.size()}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='town-probe-', dir=out) as directory:
        work = Path(directory)
        (work/'probe.gd').write_text(SCRIPT, encoding='utf-8')
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="TownProbe" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        command = [args.godot, '--path', str(ROOT), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--position', '-16000,-16000', '--resolution', '1280x720', '--quit-after', '900', '--log-file', str(out/'engine.log'), 'res://'+scene.relative_to(ROOT).as_posix(), '--', str(out)]
        if os.name != 'nt': command = ['xvfb-run', '-a'] + command
        with (out/'console.log').open('w', encoding='utf-8') as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120, creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        text = (out/'console.log').read_text(encoding='utf-8'); print(text)
        errors = [line for line in text.splitlines() if 'ERROR' in line and line != 'ERROR: Failed to read the root certificate store.']
        return result.returncode or int(bool(errors) or 'TOWN_SCALE_REPORT' not in text)


if __name__ == '__main__':
    raise SystemExit(main())
