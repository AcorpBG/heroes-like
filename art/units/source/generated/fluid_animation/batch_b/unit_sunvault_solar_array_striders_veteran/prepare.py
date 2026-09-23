"""Register Heliostat Pathfinder original articulated mechanism poses and sequential gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 233px array-tip-to-sole body. Chassis and planted feet provide registration; no per-pose resizing or deformation.',
    provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'identity_reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

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

add('idle','idle_v1',[(300,150),(785,150),(295,530),(785,530),(305,910),(785,910),(300,1290),(785,1290)],[290,780,290,780,290,780,290,780],.675)
add('attack','attack_v1',[(295,150),(805,180),(285,530),(790,550),(295,910),(790,930),(290,1290),(785,1290)],[290,790,280,780,275,775,285,780],.675)
# Exclude the first reaction proposal whose middle support leg vanished.
add('hit','death_v1',[(280,200)],[265],.510)
add('hit','reactions_v1',[(790,230),(305,570),(795,570)],[785,295,785],.655)
add('defend','reactions_v1',[(310,930),(795,960),(320,1340),(805,1320)],[300,785,300,785],.655)
add('cast','cast_v1',[(380,135),(875,135),(375,455),(875,455),(380,790),(880,800),(375,1110),(880,1110)],[375,875,375,875,375,875,375,875],.755)
add('death','death_v1',[(280,200),(800,290),(280,710),(800,755)],[265,790,270,790],.510)
add('death','death_corrected_v1',[(795,575)],[775],.230)
add('death','death_v1',[(300,1100),(300,1430),(800,1430)],[300,300,800],.510)
# Follow the three-foot silhouette in the shipped original artwork; the old prompt's
# four-leg wording was not realized. Sequential rear, middle, front steps retain anatomy.
add('move','move_tripod_v1',[(245,160),(645,160),(1050,160),(245,580),(645,580),(1050,580),(245,1000),(645,1000),(1050,1000)],[250,650,1055,250,650,1055,250,650,1055],.638,[383,383,383,800,800,800,1218,1218,1218])
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':150,'attack':115,'hit':115,'defend':125,'cast':125,'death':145,'move':105}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Original paintings reviewed in Godot at 128px: articulated lens-blade thrust with recovery, folding-array idle/support/brace, sequential rear-middle-front nine-step gait and grounded mechanical collapse. Fixed per-source scale preserves helmet and array size. Shipped reference has a three-foot silhouette despite historical four-leg prompt wording; retain the actual artwork. Clipped fallen pose, missing-middle-leg reaction and incoherent first walking sheet are excluded but preserved.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
