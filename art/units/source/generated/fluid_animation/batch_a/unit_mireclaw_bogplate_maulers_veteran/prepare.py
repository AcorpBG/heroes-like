"""Register Bogplate Gatebreaker original articulated animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 230px head-to-sole ready silhouette and chest dimensions. Planted boots provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v2',[(235,170),(735,170),(235,545),(720,550),(235,940),(720,940),(235,1310),(720,1310)],[235,735,235,735,235,735,235,735],.660)
add('attack','attack_v1',[(215,160),(690,180),(210,580),(715,620),(250,1000),(715,1000),(245,1320),(730,1320)],[225,715,225,715,225,715,225,715],.675)
add('hit','reactions_v1',[(190,140),(700,185),(210,545),(715,535)],[215,715,215,715],.640)
add('defend','reactions_v1',[(210,930),(720,930),(275,1295),(730,1295)],[215,715,215,715],.640)
add('cast','cast_v1',[(235,165),(735,165),(230,550),(730,550),(225,945),(730,945),(235,1320),(725,1320)],[235,735,235,735,235,735,235,735],.663)
add('death','death_v1',[(210,200),(735,260),(200,665),(700,710),(180,1070),(690,1095),(165,1385),(680,1390)],[220,720,220,720,220,720,220,720],.631)
# Rejected move_near_v1 still favoured the far leg; preserved as original source only.
# Foreground thigh must cross in front of the skirt, far leg stays behind it.
add('move','move_cross_v1',[(985,225),(1740,225)],[990,1730],.354)
add('move','move_v1',[(235,1320),(740,1320),(235,940),(735,940),(235,550)],[235,735,235,735,235],.656)
add('move','move_cross_v1',[(280,225)],[275],.354)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':125,'hit':115,'defend':130,'cast':135,'death':155,'move':115}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Eight original masters preserved, seven used. Full articulated maul grip/lift idle, overhead swing/recovery, hit recoil, two-handed shaft brace, battle cry, grounded collapse and reciprocal gait. Corrective foreground-leg originals cross the reed skirt; first near-leg attempt rejected. Fixed master scales retain head/chest dimensions without individual pose deformation. All 48 original poses reviewed in Godot at 128px battle reference height: distinct grip, elbow, shoulder and knee motion; full weapon margins and grounded body/maul collapse, no joined sprites.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
