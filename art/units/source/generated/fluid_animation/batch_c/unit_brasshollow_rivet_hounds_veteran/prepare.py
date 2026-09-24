"""Register Seambreaker Hound original mechanical quadruped animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 206px chimney-to-ground ready silhouette and shoulder plate size. Planted paws provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(250,175),(760,175),(250,550),(760,550),(250,930),(760,930),(250,1300),(760,1300)],[250,760,250,760,250,760,250,760],.606)
add('attack','attack_v1',[(250,170),(760,200),(250,550),(760,550),(250,920),(770,920),(250,1280),(760,1280)],[250,760,250,760,260,770,250,760],.621)
# Reaction poses retain the same shoulder-plate/body scale despite compressed leg stances.
add('hit','reactions_v1',[(315,140),(890,180),(320,465),(890,465)],[320,890,320,890],.565)
add('defend','reactions_v1',[(310,795),(895,795),(315,1105),(905,1105)],[320,890,320,890],.565)
add('cast','cast_v1',[(270,175),(780,155),(265,550),(770,550),(260,945),(770,945),(270,1325),(770,1325)],[260,770,260,770,260,770,260,770],.630)
add('death','death_v1',[(270,170),(850,220),(265,600),(855,600),(260,925),(850,925),(260,1210),(850,1210)],[285,860,285,860,285,860,285,860],.542)
# Slow four-beat gait: near hind lift/plant, near fore lift/plant,
# far hind lift/plant, far fore lift/plant, preserving all four limb attachments.
add('move','move_v1',[(260,170),(765,170),(260,550),(765,550),(260,935),(765,935),(260,1310),(765,1310)],[260,765,260,765,260,765,260,765],.585)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':120,'hit':115,'defend':130,'cast':135,'death':155,'move':120}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='All 48 original paintings reviewed at Godot 128px reference height. Six masters preserve four attached piston legs, clamp muzzle, twin chimneys, segmented tail and existing shoulder/body scale. Forepaw/neck idle, crouch-bite-recovery, recoil/guard, alert support and grounded collapse are readable. Four-beat crawl visibly lifts and plants near hind, near fore, far hind and far fore paws in order. Source-specific fixed anatomical scale matches plate dimensions without resizing individual crouches; only original pixel cropping/padding/downsampling.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
