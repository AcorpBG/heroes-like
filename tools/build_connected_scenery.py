#!/usr/bin/env python3
"""Import original connected landscape cutouts and their production provenance."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
from build_biome_components import ROOT, read, write, resource

SOURCE = ROOT/'art/overworld/source/generated/terrain/connected_patches_20260919'
RUNTIME = ROOT/'art/overworld/runtime/objects/decorations/connected_patches_20260919'
BAKER = '''extends SceneTree
func _init():
    var job = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
    for entry in job:
        var image := Image.load_from_file(entry.source)
        if image == null: quit(1); return
        image.convert(Image.FORMAT_RGBA8)
        var cutout := image.get_region(image.get_used_rect())
        var factor := 480.0 / maxf(cutout.get_width(),cutout.get_height())
        cutout.resize(roundi(cutout.get_width()*factor),roundi(cutout.get_height()*factor),Image.INTERPOLATE_LANCZOS)
        var canvas := Image.create(512,512,false,Image.FORMAT_RGBA8)
        canvas.fill(Color.TRANSPARENT)
        canvas.blend_rect(cutout,Rect2i(Vector2i.ZERO,cutout.get_size()),Vector2i((512-cutout.get_width())/2,496-cutout.get_height()))
        if canvas.save_png(entry.output)!=OK: quit(1); return
    print("CONNECTED_SCENERY_BAKE "+str(job.size()))
    quit()
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    production = read(SOURCE/'production.json')
    RUNTIME.mkdir(parents=True, exist_ok=True)
    entries = production['sprites']
    with tempfile.TemporaryDirectory(prefix='connected-scenery-bake-') as temporary:
        work = Path(temporary)
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="ConnectedSceneryBaker"\n',encoding='utf-8')
        (work/'bake.gd').write_text(BAKER,encoding='utf-8')
        write(work/'job.json',[dict(source=str(SOURCE/e['file']),output=str(RUNTIME/(e['id']+'.png'))) for e in entries])
        env = dict(os.environ,APPDATA=str(work/'profile'),XDG_DATA_HOME=str(work/'profile'))
        result = subprocess.run([args.godot,'--headless','--path',str(work),'--log-file',str(work/'engine.log'),'--script',str(work/'bake.gd'),'--',str(work/'job.json')],capture_output=True,text=True,env=env,timeout=90)
        if result.returncode or 'SCRIPT ERROR' in result.stderr or 'CONNECTED_SCENERY_BAKE' not in result.stdout:
            raise RuntimeError(result.stdout+result.stderr)
    manifest = read(ROOT/'art/overworld/manifest.json')
    decorative = read(ROOT/'art/overworld/decorative_object_sprites.json')
    recipes = []
    for entry in entries:
        aid = entry['id']
        path = RUNTIME/(aid+'.png')
        biome = 'biome_coast_archipelago' if entry['terrain']=='sand' else 'biome_grasslands'
        manifest['object_assets'][aid] = dict(path=resource(path),source_generated=resource(SOURCE/entry['file']),source_model=entry['kind'],source_manifest=resource(SOURCE/'recipes.json'),asset_policy='original_generated_no_copied_pixels')
        decorative['generated_body_appearances'][aid] = dict(name=entry['file'].removesuffix('.png').replace('_',' ').title(),description='Connected original landscape artwork spanning compatible neighboring blocker bodies. No interaction or reward; native movement masks remain authoritative.',biome_ids=[biome],runtime_path=resource(path),source_path=resource(SOURCE/'recipes.json'),availability='Live connected '+entry['terrain']+' scenery patches.',placement_authority='Existing blocked cells; visual patch grouping only.',production_kind=entry['kind'],contains_dead_tree=False)
        if aid not in decorative['generated_body_palette'][biome]: decorative['generated_body_palette'][biome].append(aid)
        recipes.append(dict(id=aid,kind=entry['kind'],biome=biome,runtime_path=resource(path),atlas=resource(SOURCE/entry['file']),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        settings = path.with_suffix('.png.import')
        if not settings.exists(): settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="'+resource(path)+'"\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit=512\n',encoding='utf-8')
    write(SOURCE/'recipes.json',dict(version=1,canvas=[512,512],production=resource(SOURCE/'production.json'),entries=recipes))
    write(ROOT/'art/overworld/manifest.json',manifest)
    write(ROOT/'art/overworld/decorative_object_sprites.json',decorative)
    print('Registered four original connected-landscape sprites.')


if __name__=='__main__': main()
