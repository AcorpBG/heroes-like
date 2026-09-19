"""Focused creature routing, actual shader playback, grounding and fog checks."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const View = preload("res://scenes/overworld/OverworldMapView.gd")
const Batch = preload("res://scenes/overworld/OverworldSceneryBatch.gd")
const Neutrals = preload("res://scripts/persistence/GeneratedNeutralEncounterRules.gd")
const BattleView = preload("res://scenes/battle/BattleBoardView.gd")
const Pose = preload("res://scripts/ui/BattleUnitPose.gd")
var failures := []
var checks := 0
var out := ""
var view
var session
var gallery
var painter = Batch.new()
var ids := ["unit_neutral_roadwardens", "unit_neutral_fenhound_runners", "unit_neutral_sunscale_lanternmoths", "unit_neutral_fenmirror_gallowshells", "unit_neutral_rootcrown_knotstags", "unit_neutral_gloambell_wake_mantas"]
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func image() -> Image:
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
func clock_for_frame(frame: int):
	for entry in painter.entries:
		var material: ShaderMaterial = entry.batch.material
		material.set_shader_parameter("phase", 0.0)
		material.set_shader_parameter("clock_override", (frame + 0.25) * float(material.get_shader_parameter("frame_seconds")))
func _ready(): call_deferred("run")
func run():
	out = OS.get_cmdline_user_args()[0]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	DisplayServer.window_set_size(Vector2i(1280,720))
	get_tree().root.size=Vector2i(1280,720)
	get_tree().root.content_scale_size=Vector2i(1280,720)
	SettingsService.set_reduced_motion_enabled(false)
	session = Factory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	load("res://scripts/core/OverworldRules.gd").normalize_overworld_state(session)
	view = View.new()
	view.size = Vector2(1280,720)
	add_child(view)
	view.set_map_state(session,session.overworld.map,Vector2i(session.overworld.map[0].size(),session.overworld.map.size()),Vector2i(-1,-1))
	var before: Dictionary = session.to_dict().duplicate(true)
	var profiles: Array = ContentService.load_json("res://content/generated_neutral_encounter_profiles.json").profiles
	for profile in profiles:
		var encounter: Dictionary = Neutrals.with_authored_guard_art({"encounter_id":profile.encounter_id})
		check(bool(encounter.get("prefer_identity_landmark",false)),"fixture missed generated identity precedence")
		var unit: String = view._encounter_idle_unit_id(encounter)
		check(unit==view._actor_unit_ids.get(profile.asset_id,""),"wrong generated creature: "+profile.encounter_id)
		check(view._creature_idle.units.has(unit),"generated creature has no idle: "+unit)
	var count := 0
	for unit in view._creature_idle.units:
		var entry: Dictionary = view._creature_idle.units[unit]
		check(int(entry.frames)>1 and int(entry.frame_msec)>0,"invalid idle: "+unit)
		count+=1
	check(count==160,"incomplete roster")
	check(view._encounter_idle_unit_id({"unit_id":"unit_river_guard"})=="unit_river_guard","direct guard not animated")
	check(view._encounter_idle_unit_id({"unit_id":"unit_river_guard","prefer_identity_landmark":true}).is_empty(),"building replaced by a creature")
	check(view._encounter_idle_unit_id({"spawned_by_faction_id":"faction_embercourt","enemy_commander_state":{"roster_hero_id":"hero_lyra","faction_id":"faction_embercourt"}}).is_empty(),"commander replaced by creature")
	# Exercise the real cached map draw, then make the same guard unexplored.
	var tile := Vector2i(3,3)
	var fog: Dictionary = session.overworld.fog
	fog.explored_tiles[tile.y][tile.x]=true
	fog.visible_tiles[tile.y][tile.x]=true
	var generated: Dictionary = Neutrals.resolve({"native_guard_quantity":12,"native_guard_level":1,"native_guard_creature_subtype":5,"placement_id":"idle_probe","x":tile.x,"y":tile.y})
	check(bool(generated.get("ok",false)),"real generated guard fixture failed")
	view._encounters_by_tile[view._tile_key(tile)]=generated.encounter
	view._invalidate_state_cache("creature_idle_fixture")
	await image()
	var found := false
	for entry in view._scenery_batches.entries:
		if entry.get("kind","")=="creature_idle" and entry.tile==tile: found=true
	check(found,"live map never routed creature into animated batch")
	var generation: int = view._scenery_batches.generation
	await get_tree().create_timer(0.8).timeout
	check(view._scenery_batches.generation==generation,"idle rebuilt map state commands")
	fog.explored_tiles[tile.y][tile.x]=false
	fog.visible_tiles[tile.y][tile.x]=false
	view._invalidate_state_cache("hidden_creature_fixture")
	await image()
	for entry in view._scenery_batches.entries:
		check(not(entry.get("kind","")=="creature_idle" and entry.tile==tile),"unexplored guard leaks through fog")
	session.overworld.fog = before.overworld.fog.duplicate(true)
	check(session.to_dict()==before,"idle changed saved simulation state")
	view.hide()
	# Six different body types at real 74px map scale and a larger inspection size.
	gallery=Control.new()
	add_child(gallery)
	painter.begin(gallery)
	painter.record(&"draw_rect",[Rect2(0,0,1280,720),Color(.085,.11,.09)])
	var boxes := []
	for i in range(ids.size()):
		var origin := Vector2(i%3,i/3)*Vector2(426,350)+Vector2(10,10)
		var box := Rect2(origin+Vector2(0,35),Vector2(412,295))
		boxes.append(Rect2i(box))
		painter.record(&"draw_rect",[box,Color(.42,.36,.23) if i%2==0 else Color(.14,.20,.14)])
		painter.record(&"draw_string",[ThemeDB.fallback_font,origin+Vector2(5,22),ids[i].trim_prefix("unit_neutral_"),HORIZONTAL_ALIGNMENT_LEFT,-1,18])
		for j in range(2):
			var extent := 74.0 if j==0 else 176.0
			var ground := origin+Vector2(94 if j==0 else 290,255)
			var pose: Dictionary = view._creature_idle.payload(ids[i],ground,extent)
			check(not pose.is_empty(),"missing sampled pose: "+ids[i])
			if pose.is_empty(): continue
			var entry: Dictionary = pose.entry
			check(int(entry.frames)==8,"expanded creature must expose eight painted poses: "+ids[i])
			var scale := extent / float(entry.painted_extent)
			check((pose.rect.position+Vector2(entry.ground_anchor[0],entry.ground_anchor[1])*scale).distance_to(ground)<.001,"anatomical anchor moved")
			var material = view.CreatureIdle.material(pose,ids[i]+str(j),true)
			var other = view.CreatureIdle.material(pose,ids[i]+str(j+100),true)
			check(material.get_shader_parameter("phase")!=other.get_shader_parameter("phase"),"neighboring creatures synchronized")
			painter.paint_material(pose.texture,pose.rect,Color.WHITE,material,{"kind":"creature_idle"})
	painter.finish()
	clock_for_frame(0)
	var first := await image()
	first.save_png(out+"/idle-a.png")
	clock_for_frame(1)
	var second := await image()
	second.save_png(out+"/idle-b.png")
	for box in boxes: check(first.get_region(box).get_data()!=second.get_region(box).get_data(),"sampled creature has no visible pose change")
	var seen_pixels := []
	for i in ids: seen_pixels.append({})
	for frame in range(8):
		clock_for_frame(frame)
		var sample := await image()
		sample.save_png(out+"/expanded-idle-%d.png"%frame)
		for i in range(boxes.size()): seen_pixels[i][hash(sample.get_region(boxes[i]).get_data())]=true
	for i in range(ids.size()): check(seen_pixels[i].size()==8,"map rendering lost idle drawings: "+ids[i])
	painter.set_motion_enabled(false)
	var reduced_a := await image()
	clock_for_frame(0)
	var reduced_b := await image()
	check(reduced_a.get_data()==reduced_b.get_data(),"reduced motion still animates")
	SettingsService.set_reduced_motion_enabled(true)
	check(not view._scenery_motion_enabled(),"live reduced-motion preference not honored")
	gallery.hide()
	# Real battle board, both facings, real idle clocks. No game input or simulation ticks.
	SettingsService.set_reduced_motion_enabled(false)
	session.battle = BattleRules.create_battle_payload(session,session.overworld.encounters[0])
	var stacks := []
	for i in range(ids.size()):
		for side in ["player","enemy"]:
			var stack: Dictionary = BattleRules._build_battle_stack(ids[i],10,side,i)
			stack.battle_id = "expanded_idle_"+side+str(i)
			stack.hex = {"q":1+(i%3)*4,"r":1+(i/3)*4+(2 if side=="enemy" else 0)}
			stacks.append(stack)
	session.battle.stacks=stacks
	session.battle.active_stack_id=stacks[0].battle_id
	session.battle.turn_order=stacks.map(func(s):return s.battle_id)
	BattleRules._sync_occupied_hexes(session.battle)
	BattleRules._sync_distance_from_hexes(session.battle)
	var battle_before: Dictionary = session.to_dict().duplicate(true)
	var board = BattleView.new()
	board.size=Vector2(1280,720)
	add_child(board)
	board.set_battle_state(session)
	var seen_regions := {}
	for stack in stacks: seen_regions[stack.battle_id]={}
	var started := Time.get_ticks_msec()
	var captures := 0
	var battle_images := []
	while Time.get_ticks_msec()-started<4600:
		await get_tree().process_frame
		for stack in stacks:
			var region: Rect2 = board._animation_frame_region_for_stack(stack)
			seen_regions[stack.battle_id][str(region)]=true
		if Time.get_ticks_msec()-started>captures*650:
			var sample := await image()
			# PNG compression must not block observation of the live pose clock.
			battle_images.append(sample)
			captures+=1
	for i in range(battle_images.size()): battle_images[i].save_png(out+"/battle-idle-%d.png"%i)
	for stack in stacks:
		var animation: Dictionary=ContentService.get_unit_animation(stack.unit_id)
		check(seen_regions[stack.battle_id].size()==8,"battle did not play all eight frames: "+stack.battle_id)
		var expected_flip: bool = (stack.side == "enemy") != (animation.get("pose_source_facing", "right") == "left")
		check(Pose.facing_flip(animation,stack.side)==expected_flip,"battle idle facing reversed")
		var first_clock := Pose.idle_elapsed_msec(animation,0,stack.unit_id+"/"+stack.battle_id)
		check(Pose.idle_elapsed_msec(animation,1000,stack.unit_id+"/"+stack.battle_id)==first_clock+1000,"idle phase drift")
		check(first_clock!=Pose.idle_elapsed_msec(animation,0,stack.unit_id+"/neighbor"),"battle stacks synchronized")
	SettingsService.set_reduced_motion_enabled(true)
	await image()
	for stack in stacks:
		var animation: Dictionary=ContentService.get_unit_animation(stack.unit_id)
		check(board._animation_frame_region_for_stack(stack)==Pose.region(animation,"idle_hold",0.0,0,true),"battle reduced motion did not freeze the idle")
	check(session.to_dict()==battle_before,"battle idle changed saved state")
	print("CREATURE_IDLE_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"units":count,"generated_profiles":profiles.size()}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--units', nargs='+', help='One to six expanded units to inspect together')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='idle-probe-', dir=out) as work:
        work = Path(work)
        script = SCRIPT
        if args.units:
            if not 1 <= len(args.units) <= 6:
                parser.error('--units accepts one to six units per visual gallery')
            roster = json.loads((ROOT/'content/unit_animation_manifest.json').read_text())['items']
            known = {row['unit_id'] for row in roster}
            if any(unit not in known for unit in args.units):
                parser.error('Unknown unit in --units')
            start = script.index('var ids := ')
            end = script.index('\n', start)
            script = script[:start] + 'var ids := ' + json.dumps(args.units) + script[end:]
        (work/'probe.gd').write_text(script, encoding='utf-8')
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="IdleProbe" type="Node"]\nscript=ExtResource("1")\n')
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        command = [args.godot, '--path', str(ROOT), '--rendering-method', 'gl_compatibility',
                   '--audio-driver', 'Dummy', '--position', '-16000,-16000', '--resolution', '1280x720',
                   '--quit-after', '1200',
                   '--log-file', str(out/'engine.log'), 'res://'+scene.relative_to(ROOT).as_posix(), '--', str(out)]
        if os.name != 'nt': command = ['xvfb-run', '-a'] + command
        with (out/'console.log').open('w', encoding='utf-8') as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
        text = (out/'console.log').read_text(encoding='utf-8')
        print(text)
        errors = [line for line in text.splitlines() if 'ERROR' in line
                  and line != 'ERROR: Failed to read the root certificate store.']
        return result.returncode or int(bool(errors) or 'CREATURE_IDLE_REPORT' not in text)


if __name__ == '__main__':
    raise SystemExit(main())
