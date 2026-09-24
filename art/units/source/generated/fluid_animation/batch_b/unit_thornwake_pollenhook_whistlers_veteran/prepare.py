"""Register Bloomchime Whistler original articulated dart-pipe animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 233px hair-to-sole ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(270,170),(770,170),(270,550),(770,550),(270,940),(770,940),(270,1310),(770,1310)],[270,770,270,770,270,770,270,770],.625)
# Exclude the unarmed windup, reversed-pipe followthrough and switched-shin
# step. Keep grips and the marked near leg consistent through the thrust.
add('attack','attack_v1',[(250,180)],[265],.632)
add('attack','attack_correction_v1',[(440,360)],[445],.289)
add('attack','ranged_v1',[(750,180)],[745],.628)
add('attack','attack_v1',[(760,580)],[740],.632)
add('attack','attack_correction_v1',[(1170,420)],[1160],.289)
add('attack','attack_v1',[(750,960),(280,1310),(760,1310)],[755,275,760],.632)
add('ranged','ranged_v1',[(255,170),(750,180),(255,560),(750,560),(255,940),(750,940),(255,1320),(750,1320)],[260,745,260,745,260,745,260,745],.628)
add('hit','reactions_v1',[(270,200),(285,580),(330,970),(305,1350)],[285,300,325,305],.600,cutoff=12)
# A translucent bridge joins the first two source paintings. Preserve the
# edge-safe cutoff and split original pixels at their reviewed row boundary.
for number,low,high in [(0,0,405),(1,405,770)]:
    f=entry['frames'][entry['clips']['hit']['indices'][number]]
    f['rects']=[[x0,max(y0,low),x1,min(y1,high)] for x0,y0,x1,y1 in f['rects'] if max(y0,low)<min(y1,high)]
    f['anchor'][1]=max(q[3] for q in f['rects'])
    f['crop_recipe']['vertical_clip']=[low,high]
add('defend','reactions_v1',[(775,190),(780,590),(790,980),(790,1390)],[775,780,790,790],.600)
# The early signal draft grew a third arm. Use the valid chest-hand pose
# as anticipation; a correctly held idle painting provides early recovery.
add('cast','cast_v1',[(305,175),(750,920),(305,550),(750,550),(305,930)],[305,750,305,750,305],.632)
add('cast','idle_v1',[(770,940)],[770],.625)
add('cast','cast_v1',[(305,1310),(750,1310)],[305,750],.632)
add('death','death_v1',[(270,260),(750,350)],[270,750],.486,floors=[503,500])
# A precise generated correction removes the extra third hand from the
# kneeling draft while preserving both legitimate pipe grips.
add('death','death_correction_v1',[(880,600)],[875],.167,floors=[947])
add('death','death_v1',[(790,790),(290,1090),(790,1090),(300,1400),(800,1410)],[760,275,775,275,775],.486,floors=[883,1148,1157,1458,1470],extras={1:[(250,1149)],2:[(750,1159)],3:[(250,1460)],4:[(750,1468)]})
add('move','move_v1',[(300,170),(780,170),(300,550),(780,550),(300,940),(780,940),(300,1320),(780,1320)],[295,775,295,775,295,775,295,775],.642)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':120,'ranged':125,'hit':115,'defend':130,'cast':130,'death':150,'move':110}[name])
for name in ('attack','ranged','cast'):entry['clips'][name]['contact_frame']=3 if name=='attack' else 4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Reviewed at native Godot 128px reference scale: visible two-hand pipe idle, braced thrust and recovery, aimed pollen release, recoil, kneeling diagonal guard, physical hand-signal support, reciprocal two-leg gait and grounded collapse. Nine original masters provide 56 entries/54 distinct paintings. Rejected unarmed/reversed-pipe melee, switched-shin step and extra-arm signal are excluded. Dedicated correction originals restore melee grips and remove a third collapse hand. Two ready paintings are shared across clips only; no duplicates within a clip. Hit alpha bridge separated with cutoff12 and original-pixel row boundary405. One fixed anatomical scale per master, original-pixel extraction/padding/downsampling only, planted-foot/body anchors retain grounded foreground equipment.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
