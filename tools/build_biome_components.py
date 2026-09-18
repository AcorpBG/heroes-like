#!/usr/bin/env python3
"""Bake distinct generated atlas components and family-compatible clusters.

Python owns provenance/recipes/registration; Godot crops and composites the
original pixels. Recoloring, mirroring and rotation never create components.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'art/overworld/source/generated/terrain/biome_components_20260919'
RUNTIME = ROOT/'art/overworld/runtime/objects/decorations/biome_components_20260919'
PREFIX = 'biome_component_v2_'
CLUSTER = 'biome_cluster_v2_'

BAKER = r'''extends SceneTree
func split_atlas(atlas: Image) -> Array:
\t# Use connected alpha islands, not blind grid crops: generated canopies can
\t# cross nominal cell boundaries while remaining separated from neighbors.
\tvar w := atlas.get_width()
\tvar h := atlas.get_height()
\tvar data := atlas.get_data()
\tvar labels := PackedInt32Array()
\tlabels.resize(w*h)
\tvar regions: Array = [{}]
\tvar groups: Array = []
\tfor i in range(25): groups.append([])
\tfor start in range(w*h):
\t\tif labels[start]!=0 or data[start*4+3]<16: continue
\t\tvar label := regions.size()
\t\tvar queue := PackedInt32Array([start])
\t\tlabels[start]=label
\t\tvar head := 0
\t\tvar x0 := start%w
\t\tvar x1 := x0
\t\tvar y0 := start/w
\t\tvar y1 := y0
\t\twhile head<queue.size():
\t\t\tvar p := queue[head]
\t\t\thead+=1
\t\t\tvar x := p%w
\t\t\tvar y := p/w
\t\t\tx0=mini(x0,x);x1=maxi(x1,x);y0=mini(y0,y);y1=maxi(y1,y)
\t\t\tfor offset in [-w,-1,1,w]:
\t\t\t\tvar q: int=p+offset
\t\t\t\tif q<0 or q>=w*h or (offset==-1 and x==0) or (offset==1 and x==w-1): continue
\t\t\t\tif labels[q]==0 and data[q*4+3]>=16:
\t\t\t\t\tlabels[q]=label
\t\t\t\t\tqueue.append(q)
\t\tvar cell := clampi(int((y0+y1)*2.5/h),0,4)*5+clampi(int((x0+x1)*2.5/w),0,4)
\t\tregions.append({"area":queue.size(),"rect":Rect2i(x0,y0,x1-x0+1,y1-y0+1)})
\t\tgroups[cell].append(label)
\tvar result: Array = []
\tfor cell in range(25):
\t\tvar largest := 0
\t\tfor label in groups[cell]: largest=maxi(largest,regions[label].area)
\t\tif largest<=300:
\t\t\tpush_error("Missing distinct alpha island in cell "+str(cell));quit(1);return []
\t\tvar bounds := Rect2i()
\t\tvar kept := {}
\t\tfor label in groups[cell]:
\t\t\tif regions[label].area<maxi(12,largest/200): continue
\t\t\tkept[label]=true
\t\t\tbounds=regions[label].rect if bounds.size==Vector2i.ZERO else bounds.merge(regions[label].rect)
\t\tif bounds.size.x>=w*0.38 or bounds.size.y>=h*0.38:
\t\t\tpush_error("Touching atlas subjects need regeneration in cell "+str(cell));quit(1);return []
\t\tvar cutout := Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
\t\tcutout.fill(Color.TRANSPARENT)
\t\tfor y in range(bounds.position.y,bounds.end.y):
\t\t\tfor x in range(bounds.position.x,bounds.end.x):
\t\t\t\tif kept.has(labels[y*w+x]): cutout.set_pixel(x-bounds.position.x,y-bounds.position.y,atlas.get_pixel(x,y))
\t\tresult.append(cutout)
\treturn result

func _init() -> void:
\tvar job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
\tvar sheets := {}
\tvar components := {}
\tfor entry in job.components:
\t\tif not sheets.has(entry.atlas):
\t\t\tvar image := Image.load_from_file(entry.atlas)
\t\t\tif image==null or image.is_empty(): push_error("Missing atlas"); quit(1); return
\t\t\timage.convert(Image.FORMAT_RGBA8)
\t\t\tsheets[entry.atlas]=split_atlas(image)
\t\t\tif sheets[entry.atlas].size()!=25: push_error(entry.atlas);return
\t\tvar cutout: Image = sheets[entry.atlas][int(entry.cell)].duplicate()
\t\tvar bounds := cutout.get_used_rect()
\t\tif bounds.size.x<20 or bounds.size.y<20: push_error("Empty component: "+entry.id); quit(1); return
\t\tcutout=cutout.get_region(bounds)
\t\tvar scale := 224.0/maxi(cutout.get_width(),cutout.get_height())
\t\tcutout.resize(maxi(1,roundi(cutout.get_width()*scale)),maxi(1,roundi(cutout.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
\t\tvar canvas := Image.create(256,256,false,Image.FORMAT_RGBA8)
\t\tcanvas.fill(Color.TRANSPARENT)
\t\tcanvas.blend_rect(cutout,Rect2i(Vector2i.ZERO,cutout.get_size()),Vector2i((256-cutout.get_width())/2,240-cutout.get_height()))
\t\tif canvas.save_png(entry.output)!=OK: quit(1); return
\t\tcomponents[entry.id]=canvas
\tfor entry in job.clusters:
\t\tvar canvas := Image.create(256,256,false,Image.FORMAT_RGBA8)
\t\tcanvas.fill(Color.TRANSPARENT)
\t\tfor layer in entry.layers:
\t\t\tvar part: Image = components[layer.component].duplicate()
\t\t\tvar r: Array = layer.rect
\t\t\tpart.resize(r[2],r[3],Image.INTERPOLATE_LANCZOS)
\t\t\tcanvas.blend_rect(part,Rect2i(Vector2i.ZERO,part.get_size()),Vector2i(r[0],r[1]))
\t\tif canvas.save_png(entry.output)!=OK: quit(1); return
\tprint("BIOME_COMPONENT_BAKE "+JSON.stringify({"components":components.size(),"clusters":job.clusters.size()}))
\tquit()
'''.replace('\\t', '\t')


def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path, value): path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
def resource(path): return 'res://'+path.relative_to(ROOT).as_posix()


def family(category, cell):
    if category == 'woods': return 'woods' if cell < 15 else 'conifers'
    if category == 'undergrowth': return 'fungi' if cell < 10 else 'scrub' if cell < 20 else 'wetland'
    return category


def entries(production, partial=False):
    components=[]
    for sheet in production['sheets']:
        atlas=SOURCE/sheet['atlas']
        if not atlas.exists():
            if partial: continue
            raise ValueError('Atlas not generated: '+sheet['id'])
        slug=sheet['biome'].removeprefix('biome_')
        folder=RUNTIME/slug
        folder.mkdir(parents=True, exist_ok=True)
        for cell,name in enumerate(sheet['names']):
            aid=PREFIX+sheet['id']+f'_{cell:02}'
            components.append(dict(id=aid, name=name.title(), biome=sheet['biome'], family=family(sheet['category'],cell),
                                   kind='original_atlas_component', atlas=str(atlas), cell=cell,
                                   output=str(folder/(sheet['category']+f'_{cell:02}.png'))))
    pools=defaultdict(list)
    for entry in components: pools[entry['biome'],entry['family']].append(entry['id'])
    clusters=[]
    # Each original component anchors its own composition. A second, different
    # component from the same family supplies structure without drowning the
    # main silhouette in a repeated all-purpose filler layer.
    layouts=[[[4,55,184,184],[111,106,137,137]], [[72,55,180,180],[0,94,151,151]],
             [[30,42,192,192],[100,107,136,136]], [[0,67,171,171],[96,87,156,156]],
             [[73,57,181,181],[2,95,147,147]], [[12,45,192,192],[117,112,129,129]]]
    for index,component in enumerate(components):
        pool=pools[component['biome'],component['family']]
        others=[key for key in pool if key!=component['id']]
        if not others: raise ValueError('Insufficient family components')
        rng=random.Random(component['id'])
        members=[component['id'],rng.choice(others)]
        aid=component['id'].replace(PREFIX,CLUSTER,1)
        output=Path(component['output']).with_name('cluster_'+Path(component['output']).name)
        clusters.append(dict(id=aid,name=component['name']+' Cluster',biome=component['biome'],family=component['family'],
                             kind='assembled_distinct_components',output=str(output),
                             layers=[dict(component=member,rect=rect) for member,rect in zip(members,layouts[index%len(layouts)])]))
    clusters.extend(plains_groves(components))
    return components,clusters


def plains_groves(components):
    """Small, staggered trees read as woodland patches within one blocked body."""
    trees=[c for c in components if c['biome']=='biome_grasslands' and c['family'] in ('woods','conifers')]
    if not trees: return []
    # Back-to-front rows with open edges, rather than two full-size trees.
    # Individual crowns use 47-64% of a standalone component's linear size.
    layouts=[[(24,40,144),(105,65,142),(48,89,164)],
             [(81,24,138),(8,64,144),(125,84,128),(52,100,152)],
             [(26,22,134),(116,40,124),(3,81,140),(121,113,120),(48,95,154)],
             [(111,24,138),(30,63,150),(116,110,132),(6,111,128)]]
    groves=[]
    for tree in trees:
        # Keep each patch coherent: broadleaf groves and evergreen groves.
        partners=[c for c in trees if c['family']==tree['family'] and c['id']!=tree['id']]
        for variant,layout in enumerate(layouts):
            rng=random.Random(tree['id']+'|grove|'+str(variant))
            members=[tree]+rng.sample(partners,len(layout)-1)
            aid=tree['id'].replace(PREFIX,'plains_grove_v2_',1)+f'_{variant}'
            output=Path(tree['output']).with_name(f'grove_{Path(tree["output"]).stem}_{variant}.png')
            groves.append(dict(id=aid,name=tree['name']+f' Grove {variant+1}',biome=tree['biome'],family=tree['family'],
                               kind='assembled_plains_grove',output=str(output),
                               layers=[dict(component=c['id'],rect=[x,y,size,size]) for c,(x,y,size) in zip(members,layout)]))
    return groves


def register(components, clusters):
    manifest_path=ROOT/'art/overworld/manifest.json'
    decorative_path=ROOT/'art/overworld/decorative_object_sprites.json'
    native_path=ROOT/'art/overworld/native_scenery.json'
    manifest=read(manifest_path);decorative=read(decorative_path);native=read(native_path)
    palettes={f:{} for f in ['rock','woods','conifers','deadwood','fungi','scrub','wetland']}
    hashes=set()
    for entry in components+clusters:
        path=Path(entry.pop('output'))
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        if digest in hashes: raise ValueError('Duplicate image: '+entry['id'])
        hashes.add(digest);entry['sha256']=digest;entry['runtime_path']=resource(path)
        if 'atlas' in entry: entry['atlas']=resource(Path(entry['atlas']))
        aid=entry['id'];biome=entry['biome']
        palettes[entry['family']].setdefault(biome,[]).append(aid)
        manifest['object_assets'][aid]=dict(path=resource(path),source_generated=entry.get('atlas',resource(SOURCE/'recipes.json')),
            source_model=entry['kind'],source_manifest=resource(SOURCE/'recipes.json'),asset_policy='original_generated_no_copied_pixels')
        decorative['generated_body_appearances'][aid]=dict(name=entry['name'],description=entry['name']+' is original, impassable '+entry['family']+' scenery. It has no interaction or reward; native body masks determine blocked cells.',biome_ids=[biome],
            runtime_path=resource(path),source_path=resource(SOURCE/'recipes.json'),availability='Live semantic RMG scenery palette.',
            placement_authority='Native generated obstacle body masks; art does not change footprint.',production_kind=entry['kind'],contains_dead_tree=entry['family']=='deadwood')
        pool=decorative['generated_body_palette'][biome]
        if aid not in pool: pool.append(aid)
        if not path.with_suffix('.png.import').exists():
            path.with_suffix('.png.import').write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="'+resource(path)+'"\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit=256\n',encoding='utf-8')
    # Owner-directed plains art mix. Rock-shaped source bodies stay impassable,
    # but about 40% can be dressed as wooded patches instead of bare stone.
    # Other biomes and the native source object/type/mask remain untouched.
    groves=[c['id'] for c in clusters if c['kind']=='assembled_plains_grove']
    palettes['rock']['biome_grasslands'].extend(groves[::3])
    native['rock_contact_palettes']={biome:[c['id'] for c in components if c['biome']==biome and c['family']=='rock' and c['cell'] in (8,13,18,21)] for biome in palettes['rock']}
    native['component_palettes']=palettes
    native['component_palette_source']=resource(SOURCE/'recipes.json')
    write(SOURCE/'recipes.json',dict(version=2,canvas=[256,256],production=resource(SOURCE/'production.json'),components=components,clusters=clusters))
    for path,data in [(manifest_path,manifest),(decorative_path,decorative),(native_path,native)]: write(path,data)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--partial',action='store_true',help='Bake available sheets for review only; never register an incomplete library.')
    args=parser.parse_args()
    production=read(SOURCE/'production.json')
    components,clusters=entries(production,args.partial)
    counts=Counter(c['biome'] for c in components)
    if not args.partial and (len(counts)!=9 or set(counts.values())!={100}): raise ValueError('Require 100 components in each of nine biomes')
    with tempfile.TemporaryDirectory(prefix='biome-component-bake-') as temporary:
        work=Path(temporary)
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="ComponentBaker"\n',encoding='utf-8')
        (work/'bake.gd').write_text(BAKER,encoding='utf-8')
        write(work/'job.json',dict(components=components,clusters=clusters))
        env=dict(os.environ,APPDATA=str(work/'profile'),XDG_DATA_HOME=str(work/'profile'))
        result=subprocess.run([args.godot,'--headless','--path',str(work),'--log-file',str(work/'engine.log'),'--script',str(work/'bake.gd'),'--',str(work/'job.json')],capture_output=True,text=True,env=env,timeout=240)
        print(result.stdout);print(result.stderr)
        if result.returncode or 'SCRIPT ERROR' in result.stderr or 'BIOME_COMPONENT_BAKE' not in result.stdout: raise RuntimeError('Component bake failed')
    if not args.partial: register(components,clusters)
    print(json.dumps(dict(components=dict(counts),clusters=len(clusters),registered=not args.partial)))


if __name__=='__main__': main()
