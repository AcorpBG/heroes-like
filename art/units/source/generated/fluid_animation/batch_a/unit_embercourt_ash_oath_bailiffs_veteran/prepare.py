"""Register original Ashseal poses, including released gavel ownership."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 230px head-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
    provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

def add(clip,stem,seeds,centers,scale,floors=None,extras=None):
    source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt');path=source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path]=scale
    for n,(seed,cx) in enumerate(zip(seeds,centers)):
        rects=body_rectangles(source,seed,8)
        extra=(extras or {}).get(n,[])
        for point in extra:rects.extend(body_rectangles(source,point,8))
        rects=[list(r) for r in sorted(set(tuple(r) for r in rects))]
        floor=(floors or [None]*len(seeds))[n]
        if floor is None:floor=max(r[3] for r in rects)
        index=len(entry['frames'])
        entry['frames'].append(dict(name=f'{clip}_{index}',clip=clip,source=path,rects=rects,anchor=[cx,floor],scale=scale,alpha_noise_cutoff=8,crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8,additional_seeds=extra)))
        entry['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ('idle','move')))['indices'].append(index)

add('idle','idle_v1',[(300,180),(740,180),(300,565),(740,565),(300,950),(740,950),(300,1330),(740,1330)],[300,740,300,740,300,740,300,740],.635)
add('attack','attack_v1',[(215,260),(600,260),(980,280),(1360,290),(240,800),(620,780),(980,770),(1360,770)],[215,600,980,1360,240,620,980,1360],.575,[510,510,510,510,963,973,981,981])
add('hit','reactions_v1',[(290,170),(745,200),(300,560),(750,550)],[290,745,300,750],.59)
add('defend','reactions_v1',[(285,950),(755,950),(295,1330),(755,1330)],[285,755,295,755],.59)
add('cast','cast_v1',[(215,240),(600,240),(980,240),(1360,240),(210,745),(600,745),(980,745),(1350,745)],[215,600,980,1360,210,600,980,1350],.49,[505,505,505,505,1010,1010,1010,1010])
add('death','death_v1',[(275,220),(760,250),(280,700),(770,750),(240,1080),(740,1100),(260,1390),(770,1390)],[275,760,280,770,275,770,270,770],.525,[460,460,854,860,1180,1178,1475,1475],extras={4:[(230,1175)],5:[(620,1174)],6:[(155,1460)],7:[(665,1460)]})
# Exclude the first sheet's incorrect near passing pose; a dedicated painting
# supplies that phase without mirroring either armor or weapon ownership.
add('move','move_far_v1',[(400,260),(980,260)],[400,980],.406)
add('move','near_passing_v1',[(870,340)],[870],.241)
add('move','move_far_v1',[(1000,860)],[1000],.406)
add('move','move_near_v1',[(380,240),(1030,240),(380,830),(1025,840)],[380,1030,380,1025],.415)
entry['clips']['idle'].update(frame_msec=145)
entry['clips']['attack'].update(frame_msec=100,contact_frame=4,static_frame=0)
entry['clips']['cast'].update(frame_msec=120,contact_frame=4)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['death'].update(frame_msec=140)
entry['clips']['move']['painted_phase_order']=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach']
entry['visual_review']=dict(status='accepted',notes='Original sources reviewed for two-arm anatomy, gavel ownership, opposing foot contacts, physical oath support, recoil, brace and collapse. One incorrect near-passing source pose excluded. All seven sequences reviewed in the native 128px Godot overview: matched armor/body size, visible arm articulation, alternating gait and grounded final corpse. Walk ground anchors use the actual painted planted soles.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
