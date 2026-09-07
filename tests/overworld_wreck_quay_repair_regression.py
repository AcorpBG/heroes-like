#!/usr/bin/env python3
"""Actual saved native-map Wreck Quay, decoded raster and unchanged full state."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

from generated_town_order_profile import OUTPUT, ROOT, run_probe

SCRIPT = r'''
extends Node
var errors := []
var checks := 0
func _ready() -> void:
    call_deferred("run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: errors.append(label)
func run() -> void:
    get_tree().current_scene = null
    var out := OS.get_environment("ART_REPAIR_OUTPUT")
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("ART_REPAIR_RESOLUTION"))
    var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("ART_REPAIR_SAVE"))))
    AppRouter.resume_active_session()
    for frame in range(8): await get_tree().process_frame
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"), "actual Overworld entered")
    var before: Dictionary = session.to_dict()
    var placement := {}
    for node in session.overworld.get("resource_nodes",[]):
        if String(node.get("placement_id",""))=="native_h3maped_93c0f05a_object_0961":
            placement = node
            break
    check(placement.get("object_id","")=="object_wreck_quay" and placement.get("site_id","")=="site_wreck_quay" and int(placement.get("x",-1))==39 and int(placement.get("y",-1))==30 and int(placement.get("level",-1))==0, "exact native source object adopted as the original resource site")
    check(placement.get("native_transit",{}).get("kind","")=="two_way_portal" and placement.get("package_block_tiles",[]).size()==1, "original transit identity and native one-cell block mask remain")
    var view = get_tree().current_scene._map_view
    view.focus_on_tile(Vector2i(39,30))
    for frame in range(4): await get_tree().process_frame
    var tile: Dictionary = view.validation_tile_presentation(Vector2i(39,30))
    check(JSON.stringify(tile).contains("mapobj_wreck_quay"), "exact visible Wreck Quay at original native tile 39,30")
    check(not bool(tile.get("art_presentation",{}).get("fallback_procedural_marker",true)), "no procedural fallback at Wreck Quay")
    check(tile.get("art_presentation",{}).get("sprite_footprints",[])==[{"width":3,"height":2}], "unchanged 3x2 visual footprint, distinct from the native block mask")
    check(view._object_asset_paths.get("mapobj_wreck_quay","") == "res://art/overworld/runtime/objects/map_objects/distinct/mapobj_wreck_quay.png", "exact authoritative asset path")
    var texture: Texture2D = view._object_textures.get("mapobj_wreck_quay")
    check(texture != null, "actual renderer texture is loaded")
    var raster: Image = texture.get_image() if texture != null else Image.new()
    if raster.is_compressed(): raster.decompress()
    check(raster.get_size()==Vector2i(512,512), "unchanged runtime canvas")
    var divider_pixels := 0
    var magenta_pixels := 0
    var painted_pixels := 0
    for y in range(raster.get_height()):
        for x in range(raster.get_width()):
            var pixel := raster.get_pixel(x,y)
            if pixel.a <= 0.0: continue
            painted_pixels += 1
            if x<108 or x>=402 or y<120 or y>=390: divider_pixels += 1
            if minf(pixel.r,pixel.b)-pixel.g>8.01/255.0: magenta_pixels += 1
    check(divider_pixels==0, "decoded renderer texture has no sheet divider")
    check(magenta_pixels==0, "decoded renderer texture has no magenta matte")
    check(painted_pixels>20000, "legitimate painted quay remains")
    await RenderingServer.frame_post_draw
    check(get_viewport().get_texture().get_image().save_png(out.path_join("wreck_quay_gameplay.png"))==OK,"gameplay capture")
    check(session.to_dict()==before,"full session unchanged by asset rendering and camera focus")
    print("WRECK_QUAY_ART_REPAIR "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"tile":tile,"divider_pixels":divider_pixels,"magenta_pixels":magenta_pixels,"painted_pixels":painted_pixels,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--save", required=True, type=Path)
    parser.add_argument("--resolution", choices=["1280x720", "1920x1080"], default="1280x720")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9_-]+", args.label):
        parser.error("label must be a fresh lowercase slug")
    output = OUTPUT / args.label
    output.mkdir(parents=True, exist_ok=False)
    original = args.save.read_bytes()
    with tempfile.TemporaryDirectory(prefix="wreck-quay-probe-", dir=OUTPUT) as temp, tempfile.TemporaryDirectory(prefix="wreck-quay-userdata-", dir="/dev/shm") as userdata:
        directory = Path(temp)
        script = directory / "probe.gd"
        script.write_text(SCRIPT)
        scene = directory / "probe.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="WreckQuayProbe" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=userdata, ART_REPAIR_OUTPUT=str(output), ART_REPAIR_SAVE=str(args.save.resolve()), ART_REPAIR_RESOLUTION=args.resolution)
        with (output / "runtime.log").open("w") as log:
            code = run_probe(["dbus-run-session", "--", "xvfb-run", "-a", "-s", "-screen 0 2200x1200x24", "godot4", "--path", str(ROOT), "--audio-driver", "Dummy", "--accessibility", "disabled", "res://" + str(scene.relative_to(ROOT))], env, log)
    lines = (output / "runtime.log").read_text().splitlines()
    marker = "WRECK_QUAY_ART_REPAIR "
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {"ok": False, "errors": ["missing report"]}
    report.update(returncode=code, save_sha256=hashlib.sha256(original).hexdigest(), source_unchanged=args.save.read_bytes()==original, resolution=args.resolution, runtime_errors=[line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line])
    report["ok"] = bool(report["ok"]) and code==0 and report["source_unchanged"] and not report["runtime_errors"]
    (output / "report.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps({key: value for key, value in report.items() if key != "tile"}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
