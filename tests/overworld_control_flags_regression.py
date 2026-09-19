"""Focused town/mine ownership flag rendering, capture refresh and fog checks."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Players = preload("res://scripts/core/PlayerIdentityRules.gd")
const View = preload("res://scenes/overworld/OverworldMapView.gd")
const Flag = preload("res://scenes/overworld/OverworldControlFlag.gd")
var checks := 0
var failures := []
var view
var session
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func capture() -> Image:
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
func bind():
	view.set_map_state(session, session.overworld.map, Vector2i(18,12), Vector2i(-1,-1))
func flags(kind: String) -> Dictionary:
	var result := {}
	for part in view._scenery_batches.entries:
		if part.get("kind", "") == kind: result[part.pole_base] = part
	return result
func _ready(): call_deferred("run")
func run():
	var out: String = OS.get_cmdline_user_args()[0]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	SettingsService.set_reduced_motion_enabled(true)
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	session = Factory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	Rules.normalize_overworld_state(session)
	var rows := []; var explored := []
	for y in range(12):
		var row := []; var known := []
		for x in range(18): row.append("grass"); known.append(true)
		rows.append(row); explored.append(known)
	session.overworld.map = rows
	session.overworld.map_size = {"width":18,"height":12,"level_count":1}
	session.overworld.fog = {"explored_tiles":explored,"visible_tiles":explored.duplicate(true)}
	session.overworld.map_objects = []; session.overworld.artifact_nodes = []; session.overworld.encounters = []
	session.overworld.players = [
		{"player_id":"p1","slot":1,"faction_id":"faction_embercourt","human":true},
		{"player_id":"p2","slot":2,"faction_id":"faction_embercourt","computer":true}]
	session.overworld.active_player_id = "p1"
	var town: Dictionary = session.overworld.towns[0].duplicate(true)
	town.merge({"x":5,"y":7,"visit_tile":{"x":5,"y":7},"owner":"player","controlling_player_id":"p1","level":0},true)
	session.overworld.towns = [town]
	var nodes := []
	var sites := ["site_timber_camp","site_ridge_quarry","site_gold_mine","site_aetherglass_lens_house"]
	# Resolve common site aliases from content, avoiding assumptions about names.
	for site in ContentService.load_json("res://content/resource_sites.json").items:
		var resource: String = site.get("common_mine_resource", "")
		if resource in ["wood","ore","gold"]: sites[["wood","ore","gold"].find(resource)] = site.id
	for i in range(4):
		var point := Vector2i(11 + (i%2)*4, 5 + (i/2)*4)
		nodes.append({"site_id":sites[i],"placement_id":"flag_mine_"+str(i),"kind":"mine","x":point.x,"y":point.y,"level":0,"collected":false})
	session.overworld.resource_nodes = nodes
	view = View.new(); view.size=Vector2(1280,720); add_child(view); bind()
	var neutral := await capture(); neutral.save_png(out+"/neutral.png")
	check(flags("town_control_flag").size()==2,"town does not have exactly two entrance flags")
	check(flags("mine_control_flag").size()==4,"missing common/rare mine flag")
	for flag in flags("mine_control_flag").values(): check(flag.color==Flag.NEUTRAL,"unclaimed mine is not grey")
	var entry_rect: Rect2 = view._tile_rect(view._board_rect(),Vector2i(5,7))
	for flag in flags("town_control_flag").values():
		check(flag.color==Flag.SLOT_COLORS[0],"town player colour is wrong")
		check(flag.pole_base.y>entry_rect.position.y and flag.pole_base.y<entry_rect.end.y,"town flag is above gate row")
	var pair: Dictionary = view._town_owner_pennant_profile(entry_rect,Flag.SLOT_COLORS[0],false,"player",false)
	check(pair.flags[0].pole_base.x<entry_rect.get_center().x and pair.flags[1].pole_base.x>entry_rect.get_center().x,"flags do not flank entrance")
	var source_town: Dictionary = town.duplicate(true)
	var images := [neutral]
	for controller in ["p1","p2",""]:
		var before_signature: int = view._state_cache_signature_for(session)
		for node in nodes: Players.set_resource_controller(node,session,controller)
		check(view._state_cache_signature_for(session)!=before_signature,"capture/recapture does not invalidate flag cache")
		var expected: Color = Flag.NEUTRAL if controller.is_empty() else Flag.SLOT_COLORS[0 if controller=="p1" else 1]
		bind(); var frame := await capture(); images.append(frame)
		frame.save_png(out+"/"+(controller if not controller.is_empty() else "released")+".png")
		for flag in flags("mine_control_flag").values(): check(flag.color==expected,"mine flag does not follow actual controller")
	check(images[0].get_data()!=images[1].get_data(),"capture colour never reaches rendered pixels")
	check(images[1].get_data()!=images[2].get_data(),"same-faction enemy recapture never reaches pixels")
	var node: Dictionary = nodes[0]
	var mine_rect: Rect2 = view._tile_rect(view._board_rect(),Vector2i(node.x,node.y))
	var mine_flag: Dictionary = view._mine_control_flag_profile(node,mine_rect)
	check(mine_flag.rect.size.x<pair.flags[0].rect.size.x,"mine flag not smaller than town flag")
	check(view._mine_control_flag_profile({"site_id":sites[0],"kind":"reward_reference"},mine_rect).is_empty(),"loose pickup gained a mine flag")
	var marker_cell: Vector2i = flags("mine_control_flag").values()[0].cell
	session.overworld.fog.explored_tiles[marker_cell.y][marker_cell.x]=false
	session.overworld.fog.visible_tiles[marker_cell.y][marker_cell.x]=false
	bind(); await capture()
	for part in view._scenery_batches.entries:
		if part.get("kind", "") in ["mine_control_flag","town_control_flag"]: check(part.cell!=marker_cell,"ownership flag leaks through unexplored cell")
	check(town==source_town,"renderer mutated town authority")
	var before: Dictionary = session.to_dict().duplicate(true)
	bind(); await capture()
	check(session.to_dict()==before,"render changed saved state")
	# Legacy authored ownership has no player slot but still shares the town colour.
	session.overworld.players=[]; session.overworld.erase("active_player_id")
	var faction: String = ContentService.get_scenario_readonly(session.scenario_id).get("player_faction_id", "")
	check(view._controller_flag_color(faction)==view._town_owner_color({"owner":"player","controlling_faction_id":faction}),"legacy mine/town colours differ")
	print("CONTROL_FLAGS_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='flags-probe-', dir=out) as directory:
        work = Path(directory)
        (work/'probe.gd').write_text(SCRIPT, encoding='utf-8')
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="FlagProbe" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        command = [args.godot, '--path', str(ROOT), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--position', '-16000,-16000', '--resolution', '1280x720', '--quit-after', '900', '--log-file', str(out/'engine.log'), 'res://'+scene.relative_to(ROOT).as_posix(), '--', str(out)]
        if os.name != 'nt': command = ['xvfb-run', '-a'] + command
        with (out/'console.log').open('w', encoding='utf-8') as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120, creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        text = (out/'console.log').read_text(encoding='utf-8'); print(text)
        errors = [line for line in text.splitlines() if 'ERROR' in line and line != 'ERROR: Failed to read the root certificate store.']
        return result.returncode or int(bool(errors) or 'CONTROL_FLAGS_REPORT' not in text)


if __name__ == '__main__':
    raise SystemExit(main())
