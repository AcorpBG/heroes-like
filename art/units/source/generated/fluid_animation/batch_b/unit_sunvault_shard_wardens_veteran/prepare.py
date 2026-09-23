"""Register Mirrorback Warden original articulated sword/shield poses and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 233px crest-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(300,180),(730,180),(300,560),(735,560),(310,955),(730,955),(300,1335),(730,1335)],[310,740,310,740,310,740,310,740],.612)
add('attack','attack_v1',[(300,170),(755,185),(310,560),(760,560),(330,930),(750,930),(310,1320),(755,1320)],[310,765,320,770,330,760,310,755],.625)
add('hit','reactions_v1',[(295,160),(770,230),(320,580),(785,580)],[310,775,320,785],.605)
add('defend','reactions_v1',[(310,955),(800,955),(320,1330),(805,1330)],[310,800,320,805],.605)
add('cast','cast_v1',[(275,180),(760,180),(265,570),(770,570),(270,945),(780,945),(275,1340),(775,1340)],[280,770,275,770,275,780,280,775],.618)
add('death','death_v1',[(350,180),(910,220),(360,580),(935,625),(340,900),(950,920),(320,1190),(930,1190)],[355,920,360,935,350,950,340,950],.55)
# Actual source anatomy overrides prompt labels. Far contact/support, near passing/reach,
# near contact/support, far passing/reach. Repeated near support proposal is excluded.
add('move','move_b_v1',[(350,290)],[360],.396,[600])
add('move','move_support_v1',[(730,520)],[720],.200,[1188])
add('move','move_a_v1',[(350,880),(950,880)],[360,960],.394,[1206,1206])
add('move','move_a_v1',[(350,280),(950,280)],[360,960],.394,[590,595])
add('move','move_b_v1',[(350,930),(920,930)],[360,930],.396,[1231,1235])
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':150,'attack':115,'hit':115,'defend':125,'cast':125,'death':145,'move':110}[name])
entry['clips']['idle']['indices']=[0,2,1,3,4,5,7,6]
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Original paintings reviewed at 128px Godot battle size: articulated sword windup/strike/recovery, shield brace and channel salute, grounded collapse, reciprocal eight-step gait with explicit far-leg support correction. Stable ivory/gold/crystal identity and fixed per-source anatomical scale; idle poses ordered by actual wrist progression. Unused repeated-support proposal retained in original sources.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
