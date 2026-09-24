"""Register Fenbell Tollreaper articulated sickle-and-chain animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 228px hood-to-sole ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
    provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'identity_reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

def add(clip,stem,seeds,centers,scale,floors=None,extras=None,cutoff=8):
    source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt');path=source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path]=scale
    for n,(seed,cx) in enumerate(zip(seeds,centers)):
        rects=body_rectangles(source,seed,cutoff)
        extra=(extras or {}).get(n,[])
        for point in extra:rects.extend(body_rectangles(source,point,cutoff))
        rects=[list(r) for r in sorted(set(tuple(r) for r in rects))]
        floor=(floors or [None]*len(seeds))[n]
        if floor is None:floor=max(r[3] for r in rects)
        index=len(entry['frames'])
        entry['frames'].append(dict(name=f'{clip}_{index}',clip=clip,source=path,rects=rects,anchor=[cx,floor],scale=scale,alpha_noise_cutoff=cutoff,crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=cutoff,additional_seeds=extra)))
        entry['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ('idle','move')))['indices'].append(index)

add('idle','idle_v1',[(265,170)],[265],.644)
add('idle','corrections_v1',[(400,350)],[370],.252)
add('idle','idle_v1',[(265,550),(765,550),(265,930),(765,930),(265,1300),(765,1300)],[265,765,265,765,265,765],.644)
add('attack','attack_v1',[(265,170),(765,170),(265,550)],[265,765,265],.652)
add('attack','corrections_v1',[(1070,440)],[1050],.252)
add('attack','attack_v1',[(265,930),(765,930),(265,1300),(765,1300)],[265,765,265,765],.652)
add('hit','reactions_v1',[(265,180),(765,240),(265,560),(765,560)],[265,765,265,765],.614)
add('defend','reactions_v1',[(265,970),(765,970),(265,1330),(765,1330)],[265,765,265,765],.614)
add('cast','cast_v1',[(265,170),(765,170),(265,560),(765,560),(265,930),(765,930),(265,1300),(765,1300)],[265,765,265,765,265,765,265,765],.664)
add('death','death_v1',[(265,180),(765,240),(265,650),(765,670),(265,1030),(765,1080),(265,1390),(765,1390)],[265,765,265,765,265,765,265,765],.572)
# Reciprocal stalking steps: foreground thigh passes over the reed skirt,
# far thigh passes behind it, and each planted foot becomes the support.
add('move','move_v1',[(265,170),(765,170),(265,560),(765,560),(265,930),(765,930),(265,1300),(765,1300)],[280,780,280,780,280,780,280,780],.663)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':120,'hit':115,'defend':130,'cast':135,'death':150,'move':115}[name])
entry['clips']['attack']['contact_frame']=3
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='All 48 original paintings reviewed in the Godot 128px overview. Seven masters preserve hood, reed skirt, two sickles and connecting bell chain. Idle pose two and attack pose four use corrected original paintings to remove extra/missing blades; rejected versions remain in source masters. Visible elbow/wrist idle, alternating sickle cuts and recovery, recoil, crouched guard, raised bell-chain support, grounded collapse and reciprocal stalking steps. Fixed per-master anatomical scales and planted-foot registration, no per-pose resizing or deformation.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
