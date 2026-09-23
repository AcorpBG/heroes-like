"""Register Foreclosure Engine original articulated clamp poses and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 231px chimney-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(340,150),(785,150),(340,530),(785,530),(340,910),(785,910),(340,1290),(785,1290)],[340,785,340,785,340,785,340,785],.640)
add('attack','attack_v1',[(320,155),(790,165),(335,550),(775,555),(350,925),(820,960),(320,1310),(785,1300)],[320,780,330,760,325,795,320,775],.654)
# Replacement reaction sheet preserves broad furnace/chassis proportions.
add('hit','reactions_v2',[(320,160),(790,210),(330,540),(790,540)],[320,780,320,780],.625,cutoff=12)
add('defend','reactions_v2',[(320,920),(790,950),(320,1330),(790,1300)],[310,775,310,775],.625,cutoff=12)
add('cast','cast_v1',[(305,150),(790,150),(305,545),(795,550),(300,925),(795,925),(305,1300),(795,1300)],[300,790,300,790,300,790,300,790],.675)
add('death','death_v1',[(325,215),(815,275),(335,660),(815,700),(300,1040),(820,1070),(300,1370),(820,1370)],[300,790,310,790,290,790,290,790],.560)
# Far contact and support; near passing, reaching, contact and support;
# far passing and reach. Exclude repeated-near-leg proposals from the first sheet.
add('move','move_far_v1',[(460,280),(1170,280)],[425,1135],.354)
add('move','move_v1',[(315,510),(810,510),(315,880),(810,880),(315,1260)],[310,800,310,800,310],.695)
add('move','move_far_v1',[(1880,280)],[1845],.354)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':125,'hit':115,'defend':130,'cast':130,'death':155,'move':120}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=3
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Original paintings reviewed at Godot 128px: heavy clamp reach/closure/recovery, broad chassis recoil/guard, articulated open-hand support salute, reciprocal eight-step gait and grounded wreck with settled debt tags. Corrected far-leg poses preserve side ownership; replacement reactions match stocky proportions. Alpha cutoff 12 separates faintly connected reaction paintings. All eight masters including rejected narrow/clipped reactions and repeated-near-leg proposals preserved.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
