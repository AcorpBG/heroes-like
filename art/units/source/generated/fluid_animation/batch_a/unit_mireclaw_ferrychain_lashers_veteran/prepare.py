"""Register Blackwater Chainmaster original articulated hook-and-chain animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 232px head-to-sole ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(300,175),(760,175),(300,560),(760,560),(300,940),(760,940),(300,1310),(760,1310)],[305,765,305,765,305,765,305,765],.632)
add('attack','attack_v1',[(290,180),(770,200),(310,570),(790,610),(300,950),(770,960),(290,1300),(765,1300)],[290,770,290,760,285,765,285,765],.648)
# The generated reaction sheet alternates hit (left) and defense (right).
add('hit','reactions_v1',[(290,175),(290,570),(290,930),(290,1310)],[290,290,290,290],.640)
add('defend','reactions_v1',[(765,175),(765,560),(765,960),(765,1330)],[765,765,765,765],.640)
add('cast','cast_v1',[(285,175),(765,175),(285,560),(765,560),(285,930),(765,930),(285,1300),(765,1300)],[285,765,285,765,285,765,285,765],.636)
# The first death master enlarged its lower poses and is retained unused.
add('death','death_v2',[(260,180),(775,230),(300,650),(800,710),(300,1080),(800,1110),(280,1420),(800,1420)],[260,775,260,775,260,775,260,775],.577)
# Near thigh crosses in front of the kilt in the correction master.
# Its first attempt kept the far leg in front and is retained unused.
add('move','move_cross_v1',[(960,310),(1640,310)],[970,1640],.313)
add('move','move_v1',[(300,560),(300,1300),(765,1300),(300,930),(765,930)],[300,300,765,300,765],.635)
add('move','move_cross_v1',[(320,310)],[320],.313)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':120,'hit':115,'defend':130,'cast':135,'death':150,'move':115}[name])
entry['clips']['attack']['contact_frame']=3
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='All 48 original poses reviewed in Godot at 128px reference height. Seven selected masters preserve adult anatomy, tattooed arms, reed cloak, paired iron hooks and chain sling. Visible elbow/wrist idle, hook wind-up/lunge/recovery, recoil and crouched brace, chain-raising physical rally, grounded collapse and reciprocal walking. Dedicated near-thigh crossings in front of the kilt repair the far-leg-only attempt; replacement death master avoids enlarged lower poses. Two rejected originals remain preserved. One fixed anatomical scale per master; only original-pixel cropping, transparent padding and downsampling.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
