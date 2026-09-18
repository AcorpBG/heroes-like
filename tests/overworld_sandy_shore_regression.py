"""Render the actual ground shader in an isolated project; no game is launched."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEPENDENCIES = ['OverworldGroundSurface.gd', 'overworld_ground_surface.gdshader']
SCRIPT = r'''extends SceneTree
var surface
var viewport: SubViewport
var failures := []
var checks := 0
var serial := 0
var output := ""
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func capture(rows: Array, fog: Array) -> Image:
	serial += 1
	surface.sync_lookup(rows, Vector2i(8, 6), serial, fog, serial)
	surface.sync_layout(Rect2(0, 0, 960, 720), Rect2(0, 0, 960, 720), Vector2i(8, 6))
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func distance(a: Color, b: Color) -> float:
	return Vector3(a.r-b.r, a.g-b.g, a.b-b.b).length()
func run() -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	output = job.output
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	surface = load("res://scenes/overworld/OverworldGroundSurface.gd").new()
	viewport.add_child(surface)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(job.config))
	surface.configure(config, ImageTexture.create_from_image(Image.load_from_file(job.atlas)))
	var rows: Array = []
	var fog: Array = []
	for y in range(6):
		rows.append(["grass", "grass", "grass", "grass", "water", "water", "water", "water"])
		fog.append([true, true, true, true, true, true, true, true])
	var before: Array = rows.duplicate(true)
	var beach := await capture(rows, fog)
	beach.save_png(output.path_join("straight-beach.png"))
	surface.material.set_shader_parameter("water_slots", Vector3(-1, -1, -1))
	var direct := await capture(rows, fog)
	surface.material.set_shader_parameter("water_slots", Vector3(12, 13, 14))
	var changed := 0
	for y in range(80, 640, 8):
		for x in range(448, 504, 4):
			if distance(beach.get_pixel(x,y), direct.get_pixel(x,y)) > 0.08: changed += 1
	check(changed > 300, "sandy band is missing from the rendered coast")
	for y in range(60, 720, 120):
		for x in range(60, 960, 120):
			check(distance(beach.get_pixel(x,y), direct.get_pixel(x,y)) < 0.001, "beach altered tile-center terrain identity")
	check(rows == before, "rendering mutated terrain data")
	for y in range(6):
		for x in range(4,8): fog[y][x] = false
	var hidden := await capture(rows, fog)
	for y in range(6):
		for x in range(4,8): rows[y][x] = "lava"
	var changed_hidden := await capture(rows, fog)
	check(hidden.get_data() == changed_hidden.get_data(), "beach reveals unexplored neighboring terrain")
	for row in fog: row.fill(true)
	for y in range(6):
		for x in range(8): rows[y][x] = "grass" if x+y < 7 else "water"
	rows[3][6] = "grass"
	rows[1][2] = "water"
	var corners := await capture(rows, fog)
	corners.save_png(output.path_join("island-inlet-diagonal.png"))
	var uploads: int = surface.map_uploads
	surface.sync_layout(Rect2(-30, 0, 960, 720), Rect2(0,0,960,720), Vector2i(8,6))
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var panned := viewport.get_texture().get_image()
	var max_delta := 0.0
	for y in range(40,680,8):
		for x in range(20,900,8): max_delta = maxf(max_delta, distance(panned.get_pixel(x,y), corners.get_pixel(x+30,y)))
	check(max_delta < 0.015, "shore texture moves relative to world when camera pans")
	check(surface.map_uploads == uploads, "camera pan rebuilt map lookup")
	print("SANDY_SHORE " + JSON.stringify({"checks":checks,"failures":failures,"changed_coast_pixels":changed,"pan_max_delta":max_delta}))
	quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='shore-probe-', dir=output) as tmp:
        work = Path(tmp)
        folder = work / 'scenes/overworld'
        folder.mkdir(parents=True)
        for name in DEPENDENCIES:
            shutil.copyfile(ROOT / 'scenes/overworld' / name, folder / name)
        (work / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="ShoreProbe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
        (work / 'probe.gd').write_text(SCRIPT, encoding='utf-8')
        (work / 'job.json').write_text(json.dumps(dict(output=str(output), config=str(ROOT / 'art/overworld/ground_materials.json'), atlas=str(ROOT / 'art/overworld/runtime/terrain_tiles/ground_materials_v3.png'))), encoding='utf-8')
        env = dict(os.environ, APPDATA=str(work / 'profile'), XDG_DATA_HOME=str(work / 'profile'), XDG_CONFIG_HOME=str(work / 'config'))
        command = [args.godot, '--path', str(work), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--position', '-16000,-16000', '--resolution', '960x720', '--log-file', str(output / 'engine.log'), '--script', str(work / 'probe.gd'), '--', str(work / 'job.json')]
        if os.name != 'nt': command = ['xvfb-run', '-a'] + command
        with (output / 'console.log').open('w', encoding='utf-8') as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        print((output / 'console.log').read_text(encoding='utf-8'))
        return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
