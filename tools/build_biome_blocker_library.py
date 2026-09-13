#!/usr/bin/env python3
"""Build the owner-approved mixed original/assembled biome blocker library.

Python owns recipes and registration. A disposable, empty Godot project bakes
original raster components with the engine's Image compositor; no game runs.
The resulting PNGs use the existing live RMG palette path without new rules.
"""
import argparse
from collections import Counter
import hashlib
import itertools
import json
from pathlib import Path
import random
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'art/overworld/source/generated/terrain/biome_blocker_library_20260913'
RUNTIME = ROOT/'art/overworld/runtime/objects/decorations/biome_blocker_library_20260913'
OUTPUT = ROOT/'.artifacts/biome-blocker-library-20260913'
PREFIX = 'cohesive_library_'

BAKER = r'''extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var images := {}
	for id in job.components:
		var row: Dictionary = job.components[id]
		var image := Image.load_from_file(row.path)
		if image == null or image.is_empty(): push_error("Missing component: " + id); quit(1); return
		image.convert(Image.FORMAT_RGBA8)
		if row.get("atlas_region") is Array:
			var r: Array = row.atlas_region
			image = image.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		images[id] = image
	var sheets := {}
	var counts := {}
	for entry in job.entries:
		var canvas := Image.create(256,256,false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		for layer in entry.layers:
			var part: Image = images[layer.component].duplicate()
			var rect: Array = layer.rect
			part.resize(int(rect[2]),int(rect[3]),Image.INTERPOLATE_LANCZOS)
			canvas.blend_rect(part,Rect2i(Vector2i.ZERO,part.get_size()),Vector2i(int(rect[0]),int(rect[1])))
		if canvas.save_png(entry.output) != OK: push_error("Cannot save " + entry.output); quit(1); return
		var biome: String = entry.biome
		if not sheets.has(biome):
			var sheet := Image.create(1280,1280,false,Image.FORMAT_RGBA8)
			sheet.fill(Color(0.16,0.19,0.17,1.0))
			sheets[biome] = sheet
			counts[biome] = 0
		var thumb: Image = canvas.duplicate()
		thumb.resize(128,128,Image.INTERPOLATE_LANCZOS)
		var n := int(counts[biome])
		sheets[biome].blend_rect(thumb,Rect2i(0,0,128,128),Vector2i((n%10)*128,(n/10)*128))
		counts[biome] = n+1
	for biome in sheets:
		if sheets[biome].save_png(job.review_dir.path_join(biome + ".png")) != OK: quit(1); return
	print("BLOCKER_ASSET_BUILD " + JSON.stringify(counts))
	quit(0)
'''

LAYOUTS = {
    3: [
        ('Crescent', [[10,34,154,154],[98,42,148,148],[43,80,170,170]]),
        ('Ridge', [[4,54,164,164],[88,12,160,160],[68,94,154,154]]),
        ('Crown', [[46,5,166,166],[7,96,150,150],[98,97,150,150]]),
    ],
    4: [
        ('Tangle', [[40,4,150,150],[2,78,146,146],[111,67,142,142],[57,109,141,141]]),
        ('Spur', [[9,18,146,146],[102,34,146,146],[14,106,143,143],[91,102,149,149]]),
        ('Knoll', [[54,4,148,148],[7,67,144,144],[103,75,146,146],[48,109,141,141]]),
    ],
}


def read(path): return json.loads(path.read_text(encoding='utf-8'))
def write(path, value): path.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def resource(path): return 'res://'+path.relative_to(ROOT).as_posix()


def recipes(components):
    result=[]
    used_combinations=set()
    for biome, definition in components['biomes'].items():
        slug=biome.removeprefix('biome_')
        folder=RUNTIME/slug
        folder.mkdir(parents=True,exist_ok=True)
        dead=definition['new_dead_tree']
        pool=definition['existing_components']+[dead]
        rng=random.Random('aurelion-blocker-library-v1:'+biome)
        candidates=[c for n in [3,4] for c in itertools.combinations_with_replacement(pool,n)
                    if len(set(c))>=2 and max(Counter(c).values())<=2
                    and tuple(sorted(c)) not in used_combinations]
        with_dead=[c for c in candidates if dead in c]
        without_dead=[c for c in candidates if dead not in c]
        rng.shuffle(with_dead); rng.shuffle(without_dead)
        selected=with_dead[:45]+without_dead[:54]
        if len(selected)!=99: raise ValueError('Insufficient distinct ingredient combinations for '+biome)
        used_combinations.update(tuple(sorted(c)) for c in selected)
        result.append({'id':PREFIX+slug+'_000','name':components['components'][dead]['name'],
                       'biome':biome,'kind':'original_dead_tree','dead_tree':True,
                       'output':str(folder/'000.png'),'layers':[{'component':dead,'rect':[0,0,256,256]}]})
        for index, members in enumerate(selected,1):
            members=list(members)
            rng.shuffle(members)
            # Deadwood stays in the foreground so it remains a visible motif.
            members.sort(key=lambda value:value==dead)
            shape,layout=LAYOUTS[len(members)][(index-1)%3]
            word='Deadwood' if dead in members else 'Wildland'
            result.append({'id':PREFIX+slug+f'_{index:03d}',
                           'name':slug.replace('_',' ').title()+f' {word} {shape} {index:03d}',
                           'biome':biome,'kind':'assembled_cluster','dead_tree':dead in members,
                           'output':str(folder/f'{index:03d}.png'),
                           'layers':[{'component':member,'rect':rect} for member,rect in zip(members,layout)]})
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default=shutil.which('godot4') or shutil.which('godot'))
    args=parser.parse_args()
    if not args.godot: parser.error('--godot is required')
    OUTPUT.mkdir(parents=True,exist_ok=True)
    components=read(SOURCE/'components.json')
    entries=recipes(components)
    inputs={key:{**row,'path':str(ROOT/row['path'].removeprefix('res://'))}
            for key,row in components['components'].items()}
    with tempfile.TemporaryDirectory(prefix='asset-baker-',dir=OUTPUT) as temporary:
        work=Path(temporary)
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="BlockerAssetBaker"\n[debug]\nfile_logging/enable_file_logging=false\n')
        (work/'bake.gd').write_text(BAKER,encoding='utf-8')
        write(work/'job.json',{'components':inputs,'entries':entries,'review_dir':str(OUTPUT)})
        with (OUTPUT/'build.log').open('w',encoding='utf-8') as log:
            process=subprocess.Popen([args.godot,'--headless','--path',str(work),'--log-file',str(work/'engine.log'),'--script',str(work/'bake.gd'),'--',str(work/'job.json')],stdout=log,stderr=subprocess.STDOUT)
            try: code=process.wait(timeout=240)
            finally:
                if process.poll() is None: process.kill(); process.wait(timeout=10)
        if code: raise RuntimeError('Asset bake failed; see '+str(OUTPUT/'build.log'))
    # These are build invariants, not a game/validator run. Refuse to register
    # absent or identical outputs as new content.
    hashes={}
    for entry in entries:
        digest=hashlib.sha256(Path(entry['output']).read_bytes()).hexdigest()
        if digest in hashes: raise ValueError('Duplicate blocker output: '+entry['id']+' / '+hashes[digest])
        hashes[digest]=entry['id']
        entry['sha256']=digest
        entry['runtime_path']=resource(Path(entry.pop('output')))
    write(SOURCE/'recipes.json',{'version':1,'canvas':[256,256],'components':resource(SOURCE/'components.json'),
                               'composition':'Godot Image alpha layering of original art; no recolor, mirroring or synthetic geometry',
                               'entries':entries})
    manifest_path=ROOT/'art/overworld/manifest.json'
    palette_path=ROOT/'art/overworld/decorative_object_sprites.json'
    manifest=read(manifest_path); palette=read(palette_path)
    for biome in components['biomes']:
        palette['generated_body_palette'][biome]=[i for i in palette['generated_body_palette'][biome] if not i.startswith(PREFIX)]
    for entry in entries:
        aid=entry['id'];biome=entry['biome'];path=entry['runtime_path']
        source=components['components'][entry['layers'][-1]['component']]['path']
        manifest['object_assets'][aid]={'path':path,'source_generated':source,
            'source_model':'original_art_cluster_assembly' if entry['kind']=='assembled_cluster' else 'built_in_image_gen_original_dead_tree',
            'source_manifest':resource(SOURCE/'recipes.json'),'asset_policy':'original_generated_no_copied_pixels'}
        description=(entry['name']+' is impassable RMG scenery in '+biome.removeprefix('biome_').replace('_',' ')+'. '+
                     ('A standalone dead tree with exposed roots.' if entry['kind']=='original_dead_tree' else
                      'A dense cluster of deadwood and surrounding terrain features.' if entry['dead_tree'] else
                      'A dense cluster of vegetation or stone suited to this biome.')+
                     ' It cannot be visited, cleared or collected and grants no resources. Native obstacle body masks determine blocked cells.')
        palette['generated_body_appearances'][aid]={'name':entry['name'],'description':description,'biome_ids':[biome],
            'runtime_path':path,'source_path':resource(SOURCE/'recipes.json'),
            'availability':'Live RMG blocker appearance; selected deterministically for generated terrain.',
            'placement_authority':'Native generated obstacle body masks; appearance does not change the footprint.',
            'production_kind':entry['kind'],'contains_dead_tree':entry['dead_tree']}
        palette['generated_body_palette'][biome].append(aid)
        imp=ROOT/path.removeprefix('res://')
        if not imp.with_suffix('.png.import').exists():
            imp.with_suffix('.png.import').write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="'+path+'"\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit=256\n')
    write(manifest_path,manifest);write(palette_path,palette)
    counts=Counter(entry['biome'] for entry in entries)
    result={'new_blockers':len(entries),'original_sprites':9,'assembled_clusters':len(entries)-9,
            'new_per_biome':dict(counts),'dead_tree_entries':sum(entry['dead_tree'] for entry in entries),
            'unique_png_hashes':len(hashes),'runtime_png_bytes':sum((ROOT/entry['runtime_path'].removeprefix('res://')).stat().st_size for entry in entries)}
    write(OUTPUT/'build-summary.json',result)
    print(json.dumps(result))


if __name__=='__main__': main()
