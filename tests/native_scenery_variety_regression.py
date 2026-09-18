"""Focused live scenery selector checks and original-art renders; no map generation."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_native_scenery_palettes import library_palettes, MANIFEST, RECIPES

SOURCE = (ROOT / 'scenes/overworld/OverworldMapView.gd').read_text(encoding='utf-8')
METHODS = ['_generated_decorative_body_asset_id', '_native_scenery_assets', '_generated_decorative_body_motif_key']
LIVE = '\n'.join('\n'.join('\t' + line for line in re.search(
    rf'^func {name}\(.*?(?=^func |\Z)', SOURCE, re.M | re.S).group().rstrip().splitlines()) for name in METHODS)
CONSTANT = re.search(r'const GENERATED_DECORATIVE_BIOME_BY_TERRAIN := \{.*?\n\}', SOURCE, re.S).group()
SCRIPT = '''extends Node
const Rules = preload("res://scripts/persistence/NativeSceneryRules.gd")
class Selector extends RefCounted:
\tconst GENERATED_DECORATIVE_BODY_ASSET_CLUSTER_TILES := 1
\tvar terrain := "lava"
\tvar _generated_decorative_blocker_asset_ids_by_biome := {}
\tvar _generated_decorative_blocker_fallback_asset_ids := []
\tfunc _terrain_at(_tile) -> String: return terrain
''' + '\n'.join('\t'+line for line in CONSTANT.splitlines()) + '\n' + LIVE + r'''
var failures := []
var checks := 0
func check(ok: bool, label: String) -> void:
\tchecks += 1
\tif not ok: failures.append(label)
func _ready() -> void: call_deferred("run")
func run() -> void:
\tvar output := OS.get_cmdline_user_args()[0]
\tvar manifest := ContentService.load_json(Rules.MANIFEST)
\tvar catalog: Dictionary = ContentService.load_json("res://art/overworld/manifest.json").object_assets
\tvar library: Dictionary = ContentService.load_json("res://art/overworld/source/generated/terrain/biome_components_20260919/recipes.json")
\tvar recipes: Array = library.components + library.clusters
\tvar selector := Selector.new()
\tvar seen := {}
\tvar counts := {}
\tvar terrains := ["grass","forest","mire","coast","rough","badlands","snow","lava","cavern"]
\tfor terrain in terrains:
\t\tselector.terrain = terrain
\t\tvar biome: String = selector.GENERATED_DECORATIVE_BIOME_BY_TERRAIN[terrain]
\t\tvar biome_seen := {}
\t\tfor type_id in manifest.source_types:
\t\t\tvar object := {"h3m_type_id":int(type_id),"native_scenery_art_version":2,"package_blocked_tiles":[{"x":4,"y":5}],"placement_id":"fixture"}
\t\t\tvar before := object.duplicate(true)
\t\t\tvar candidates := Rules.asset_candidates(object,biome)
\t\t\tcheck(candidates.size()>1,"single-sprite palette: "+terrain+"/"+type_id)
\t\t\tvar selected := {}
\t\t\tvar repeated := 0
\t\t\tfor y in range(32):
\t\t\t\tvar previous := ""
\t\t\t\tfor x in range(32):
\t\t\t\t\tvar id := selector._generated_decorative_body_asset_id(object,Vector2i(x,y))
\t\t\t\t\tcheck(id in candidates,"selector escaped semantic palette")
\t\t\t\t\tif previous == id: repeated += 1
\t\t\t\t\tprevious = id
\t\t\t\t\tselected[id] = true
\t\t\t\t\tseen[id] = true
\t\t\t\t\tbiome_seen[id] = true
\t\t\tcheck(selected.size() >= mini(10,candidates.size()),"insufficient visible variety: "+terrain+"/"+type_id)
\t\t\tif candidates.size() >= 10: check(repeated<160,"repeated horizontal bands: "+terrain+"/"+type_id)
\t\t\tvar id := selector._generated_decorative_body_asset_id(object,Vector2i(9,12))
\t\t\tRules._candidate_cache.clear()
\t\t\tcheck(id==selector._generated_decorative_body_asset_id(object.duplicate(true),Vector2i(9,12)),"reload changes appearance")
\t\t\tcheck(object==before,"selector mutated authoritative object/mask")
\t\t\tobject.native_scenery_art_version = 1
\t\t\tcheck(Rules.asset_candidates(object,biome)==manifest.source_types[type_id].get("asset_ids",[]),"legacy save palette changed")
\t\tcounts[terrain] = biome_seen.size()
\tfor recipe in recipes:
\t\tcheck(seen.has(recipe.id),"approved blocker unreachable: "+recipe.id)
\t\tvar image := Image.load_from_file(ContentService.local_path(catalog[recipe.id].path))
\t\tcheck(image!=null and image.get_width()==256,"missing or unbounded blocker texture: "+recipe.id)
\tvar viewport := SubViewport.new()
\tviewport.size = Vector2i(960,720)
\tviewport.disable_3d = true
\tviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
\tget_tree().root.add_child(viewport)
\tfor terrain in terrains:
\t\tselector.terrain = terrain
\t\tvar container := Node2D.new()
\t\tviewport.add_child(container)
\t\tvar ground = load("res://scenes/overworld/OverworldGroundSurface.gd").new()
\t\tcontainer.add_child(ground)
\t\tground.configure(ContentService.load_json("res://art/overworld/ground_materials.json"),ImageTexture.create_from_image(Image.load_from_file(ContentService.local_path("res://art/overworld/runtime/terrain_tiles/ground_materials_v3.png"))))
\t\tvar rows := []
\t\tvar fog := []
\t\tfor y in range(7):
\t\t\tvar row := [];row.resize(8);row.fill(terrain);rows.append(row)
\t\t\tvar visible := [];visible.resize(8);visible.fill(true);fog.append(visible)
\t\tground.sync_lookup(rows,Vector2i(8,7),1,fog,1)
\t\tground.sync_layout(Rect2(0,0,960,720),Rect2(0,0,960,720),Vector2i(8,7))
\t\tfor y in range(7):
\t\t\tfor x in range(8):
\t\t\t\tvar type_id: int = [127 if terrain=="lava" else 117,135,137,119,129,116,125][y]
\t\t\t\tvar id := selector._generated_decorative_body_asset_id({"h3m_type_id":type_id,"native_scenery_art_version":2},Vector2i(x+12,y+8))
\t\t\t\tvar entry: Dictionary = catalog[id]
\t\t\t\tvar image := Image.load_from_file(ContentService.local_path(entry.path))
\t\t\t\tif entry.has("atlas_region"):
\t\t\t\t\tvar r: Array = entry.atlas_region
\t\t\t\t\timage=image.get_region(Rect2i(r[0],r[1],r[2],r[3]))
\t\t\t\tvar sprite := Sprite2D.new()
\t\t\t\tsprite.texture = ImageTexture.create_from_image(image)
\t\t\t\tsprite.position = Vector2(x*110+80,y*98+65)
\t\t\t\tsprite.scale = Vector2.ONE*130.0/maxi(image.get_width(),image.get_height())
\t\t\t\tcontainer.add_child(sprite)
\t\tfor i in range(3): await get_tree().process_frame
\t\tawait RenderingServer.frame_post_draw
\t\tviewport.get_texture().get_image().save_png(output.path_join(terrain+".png"))
\t\tcontainer.queue_free()
\t\tawait get_tree().process_frame
\tprint("SCENERY_VARIETY "+JSON.stringify({"checks":checks,"failures":failures,"selected_by_terrain":counts,"reachable_library":recipes.size()}))
\tget_tree().quit(0 if failures.is_empty() else 1)
'''.replace('\\t', '\t')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    recipes = json.loads(RECIPES.read_text(encoding='utf-8'))['entries']
    assert manifest['library_palettes'] == library_palettes(manifest, recipes), 'stale semantic library'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='scenery-probe-', dir=output) as temporary:
        work = Path(temporary)
        (work/'scripts/persistence').mkdir(parents=True)
        (work/'scenes/overworld').mkdir(parents=True)
        for name in ['OverworldGroundSurface.gd','overworld_ground_surface.gdshader']:
            shutil.copyfile(ROOT/'scenes/overworld'/name,work/'scenes/overworld'/name)
        shutil.copyfile(ROOT/'scripts/persistence/NativeSceneryRules.gd', work/'scripts/persistence/NativeSceneryRules.gd')
        (work/'content.gd').write_text('extends Node\nvar cache := {}\nfunc local_path(path: String) -> String:\n\treturn '+json.dumps(ROOT.as_posix()+'/')+' + path.trim_prefix("res://")\nfunc load_json(path: String) -> Dictionary:\n\tif not cache.has(path): cache[path]=JSON.parse_string(FileAccess.get_file_as_string(local_path(path)))\n\treturn cache[path]\n', encoding='utf-8')
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="SceneryProbe"\n[autoload]\nContentService="*res://content.gd"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
        (work/'probe.gd').write_text(SCRIPT, encoding='utf-8')
        (work/'probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        command = [args.godot, '--path', str(work), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--position', '-16000,-16000', '--resolution', '960x720', '--log-file', str(output/'engine.log'), 'res://probe.tscn', '--', str(output)]
        if os.name != 'nt': command = ['xvfb-run', '-a'] + command
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        with (output/'console.log').open('w', encoding='utf-8') as log:
            subprocess.run([args.godot, '--headless', '--path', str(work), '--editor', '--import', '--quit', '--log-file', str(output/'import.log')], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=30, check=True)
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        print((output/'console.log').read_text(encoding='utf-8'))
        return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
