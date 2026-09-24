"""Register Shattermire Slinger original articulated sling animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 234px hair-to-sole ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
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


add('idle','idle_v1',[(330,170),(720,170),(330,550),(720,550),(330,940),(720,940),(330,1330),(720,1330)],[335,715,335,715,335,715,335,715],.644)
add('attack','attack_v1',[(330,170),(760,170),(330,550),(760,550),(330,920),(760,920),(330,1310),(760,1310)],[330,755,330,755,330,755,330,755],.642)
add('ranged','ranged_v1',[(300,160),(745,160),(300,550),(760,550),(290,940)],[320,745,320,750,320],.644)
# The first follow-through draft switched the sling to the far hand. These
# two replacement originals retain the wrapped near arm and show reload.
add('ranged','ranged_recovery_v1',[(550,350),(1300,350)],[550,1300],.285)
add('ranged','ranged_v1',[(300,1300),(745,1300)],[320,745],.644)
add('hit','reactions_v1',[(300,190),(340,570),(320,950),(330,1320)],[320,330,320,320],.613)
add('defend','reactions_v1',[(750,190),(750,570),(750,950),(750,1320)],[755,755,755,755],.613)
add('cast','cast_v1',[(330,170),(730,170),(330,550),(730,550),(330,970),(730,970),(330,1320),(730,1320)],[335,725,335,725,335,725,335,725],.644)
add('death','death_v1',[(300,230),(745,270),(315,710),(790,780),(305,1100),(775,1120),(290,1380),(790,1400)],[295,740,295,740,295,740,295,740],.510)
# Correct near-leg contact/weight bearing from the explicit foreground
# thigh reference; preserve rejected move_cross_v1 artwork as provenance.
add('move','move_near_v1',[(950,310),(1630,310)],[925,1635],.306)
add('move','move_v1',[(740,550),(740,1320),(320,930),(740,930),(310,1320)],[740,740,325,740,320],.644)
add('move','move_near_v1',[(330,310)],[330],.306)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':120,'ranged':115,'hit':115,'defend':130,'cast':130,'death':150,'move':115}[name])
for name in ('attack','ranged','cast'):entry['clips'][name]['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='57 distinct original poses across eight actions reviewed in the actual Godot 128px overview. Visible wrist/elbow idle, fist strike, nine-pose sling loading/release/reload, recoil, forearm guard, physical rally, grounded collapse and alternating near/far gait retain mask, jars and correct sling hand. Ten original masters retained, including a rejected near-step attempt. Corrected foreground leg overlap and two follow-through poses replace deficient draft paintings. No duplicate frames or whole-body warping. One fixed anatomical scale per master; original pixel cropping, transparent padding and downsampling only.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
