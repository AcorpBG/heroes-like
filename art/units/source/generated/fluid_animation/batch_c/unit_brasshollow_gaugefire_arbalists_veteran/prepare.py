"""Register Datumline Piercer original articulated arbalist poses and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 234px helmet-crest-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(245,170),(735,170),(245,550),(740,550),(265,930),(735,930),(250,1310),(735,1310)],[245,735,245,735,255,735,245,735],.625)
add('attack','attack_v1',[(230,180),(685,180),(230,550),(725,550),(240,960),(755,935),(250,1320),(720,1320)],[230,685,230,715,250,735,250,720],.592)
add('ranged','ranged_v1',[(240,170),(710,170),(230,550),(725,550),(260,940),(715,940)],[235,710,235,720,250,715],.655)
# Last two ranged proposals grew taller; use matching original lowered-weapon
# recovery paintings. Each remains unique within this clip, with no alias/padding.
add('ranged','idle_v1',[(250,1310),(735,1310)],[245,735],.625)
add('hit','reactions_v1',[(230,165),(705,235),(245,550),(725,550)],[235,715,245,725],.59)
add('defend','reactions_v1',[(235,925),(735,940),(280,1350),(740,1340)],[235,735,260,735],.59)
add('cast','cast_v1',[(255,175),(735,175),(255,550),(735,550),(255,930),(735,930),(255,1310),(735,1310)],[255,735,255,735,255,735,255,735],.635)
add('death','death_v1',[(225,190),(735,265),(230,610),(790,670),(300,1010),(880,1030),(305,1280),(880,1280)],[245,775,245,775,245,775,245,775],.55,extras={3:[(850,800)],4:[(300,1080)],5:[(880,1100)],6:[(285,1380)],7:[(850,1370)]})
# Near contact/support, far passing/reach/contact/support, near passing/reach.
# The first move sheet's repeated same-leg proposals and near-sheet first pose are excluded.
add('move','move_near_v1',[(950,285),(1630,285)],[950,1630],.327)
add('move','move_v1',[(265,550),(745,550),(270,920),(745,920),(270,1280)],[265,745,270,745,270],.665)
add('move','move_reach_v1',[(400,470)],[415],.188)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':125,'ranged':125,'hit':115,'defend':130,'cast':130,'death':155,'move':115}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['ranged']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Nine original masters reviewed at Godot battle 128px. Articulated grip idle, two-handed melee shove, aimed shot/recoil, hit/brace, physical hand signal, grounded collapse and reciprocal gait preserve the long arbalist and forked helmet. Foreground-leg contact/support/reach corrections complete the gait. Last two oversized ranged proposals replaced by matching original lowered-weapon recovery paintings, unique within that clip; unused proposals retained.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
for name,c in entry['clips'].items():
    print(name,[(round((max(r[2] for r in entry['frames'][i]['rects'])-min(r[0] for r in entry['frames'][i]['rects']))*entry['frames'][i]['scale']),round((max(r[3] for r in entry['frames'][i]['rects'])-min(r[1] for r in entry['frames'][i]['rects']))*entry['frames'][i]['scale'])) for i in c['indices']])
