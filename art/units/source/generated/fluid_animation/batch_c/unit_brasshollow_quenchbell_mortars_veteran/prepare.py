"""Register Staybell Bombardier original articulated operator and mortar sequences."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 230px finial-to-wheel-ground silhouette. Rigid carriage and wheel contact provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(285,125),(795,125),(290,490),(795,490),(290,865),(795,865),(290,1220),(795,1220)],[275,785,275,785,275,785,275,785],.744)
add('attack','attack_v1',[(290,150),(800,150),(285,540),(800,540),(330,915),(805,915),(300,1280),(805,1280)],[275,785,270,785,310,790,285,790],.691)
add('ranged','ranged_v1',[(290,150),(790,150),(290,510),(790,510),(275,885),(785,885),(290,1280),(785,1280)],[275,780,275,780,260,775,275,775],.728,extras={4:[(455,797)],5:[(955,785)],6:[(435,1180)]})
# Reaction master is four columns and two rows, despite requested 2x4 layout.
add('hit','reactions_v1',[(250,175),(695,175),(1140,175),(1580,175)],[240,685,1130,1570],.696)
add('defend','reactions_v1',[(250,605),(695,605),(1140,605),(1580,605)],[240,685,1130,1570],.696)
add('cast','cast_v1',[(285,130),(785,130),(290,510),(785,510),(290,890),(785,890),(290,1280),(785,1280)],[275,775,275,775,275,775,275,775],.732)
add('death','death_v1',[(285,130),(800,130),(285,530),(800,530),(285,900),(800,900),(285,1290),(800,1290)],[275,790,275,790,275,790,275,790],.732,extras={4:[(130,1075)],5:[(635,1095)],6:[(130,1465)],7:[(635,1465)]})
# Corrected foreground thigh crosses over tabard: near reach/contact/support,
# far passing/reach/contact/support, then near passing. Original pixels only.
add('move','move_cross_v1',[(375,275),(1105,275),(1840,275)],[355,1085,1820],.464)
add('move','move_near_v1',[(975,860)],[940],.511)
add('move','move_v1',[(285,140),(795,140),(795,900),(285,1280)],[275,785,785,275],.759)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':125,'ranged':130,'hit':115,'defend':130,'cast':130,'death':155,'move':115}[name])
for name in ('attack','ranged','cast'):entry['clips'][name]['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='All 56 poses reviewed at Godot 128px reference height. Nine original masters preserve the hooded operator, bell tabard and rigid two-wheel mortar at the existing approximately 230px finial-to-ground source scale. Separate carriage shove, lever-primed elevated firing/recoil/recovery, handbell support, brace/recoil and grounded collapse remain readable. Corrected foreground thigh crosses in front of the tabard, complementing background-leg reach/support and distinct passing poses. Original painted wheel spokes vary with the rolling cycle. Only pixel crops, transparent padding and fixed scale per source; unused gait proposals retained with exact generation lineage.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
