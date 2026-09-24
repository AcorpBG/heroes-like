"""Register Horizon Arbiter original articulated lens-staff animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 233px orbital-arc-to-sole ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(320,180),(770,180),(320,550),(770,550),(320,940),(770,940),(320,1320),(770,1320)],[310,760,315,770,310,770,310,770],.638)
add('attack','attack_v1',[(220,190),(730,190),(230,600),(750,540),(250,920),(750,950)],[220,720,235,745,255,745],.638)
# The final two draft attack bodies grew; recover using two original ready
# paintings from idle instead. There are no duplicate frames within a clip.
add('attack','idle_v1',[(320,1320),(770,1320)],[310,770],.638)
add('ranged','ranged_v1',[(265,190),(740,190),(275,570),(730,570),(270,950),(740,950),(270,1320),(740,1320)],[265,745,280,740,280,745,275,745],.621)
add('hit','reactions_v1',[(270,190),(280,550),(280,980),(300,1340)],[280,300,285,300],.613)
add('defend','reactions_v1',[(780,210),(780,580),(780,970),(780,1350)],[775,780,780,780],.613)
add('cast','cast_v1',[(290,180),(750,180),(300,580),(755,580),(290,980),(750,980),(285,1330),(750,1330)],[285,750,295,750,280,750,285,750],.638)
# Anatomical knees/hip ground anchors exclude the staff and pendant projecting
# below the body into the foreground, while preserving every original pixel.
add('death','death_v1',[(240,250),(750,320),(250,720),(790,760),(285,1100),(800,1120),(300,1410),(800,1410)],[240,750,250,770,270,770,270,770],.510,floors=[485,465,880,877,1192,1195,1490,1490])
# Foreground contact and loading from the corrected original, then the far-leg
# step, foreground lift and extension. No mirror or repeated frame padding.
add('move','move_near_v1',[(1160,260),(420,770),(1150,770)],[1150,420,1150],.475)
add('move','move_v1',[(780,580),(290,980),(780,950),(285,1350)],[770,295,775,285],.638)
add('move','move_near_v1',[(420,260)],[420],.475)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':120,'ranged':120,'hit':115,'defend':130,'cast':135,'death':150,'move':115}[name])
for name in ('attack','ranged','cast'):entry['clips'][name]['contact_frame']=3 if name=='attack' else 4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Reviewed at native Godot 128px reference scale: articulated two-handed staff idle, windup/thrust/recovery, aimed lens release, recoil, low diagonal guard, raised-staff support, reciprocal walking and grounded collapse. The staff retains both grips and the back lens remains attached. Corrected foreground step paintings replace repeated far-leg stepping. Two oversized attack recovery paintings are excluded in favor of two correctly scaled original idle paintings reused across clips only. All 56 entries (54 distinct paintings) across eight original masters retain source pixels and one fixed anatomical scale per master; no duplicates within any clip, mirroring or warping. Anatomical corpse anchors retain foreground equipment below the body contact plane.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
