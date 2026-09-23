"""Register Flarepot Engineer articulated actions and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 230px head-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
    provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

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


add('idle','idle_v1',[(325,185),(750,185),(325,565),(750,565),(325,945),(750,945),(325,1330),(750,1330)],[325,750,325,750,325,750,325,750],.65)
# Retain the painted airborne pot: this is a short-range melee action,
# which does not spawn the battle renderer's separate ranged projectile.
add('attack','attack_v1',[(310,180),(750,180),(310,565),(750,565),(300,945),(745,945),(300,1320),(750,1320)],[310,750,310,750,300,745,300,750],.676,extras={4:[(553,825)]})
entry['clips']['attack'].update(frame_msec=120,contact_frame=4,static_frame=0)
add('hit','reactions_v1',[(310,180),(755,180),(315,570),(775,570)],[310,755,315,775],.635)
add('defend','reactions_v1',[(320,970),(785,970),(330,1350),(790,1350)],[320,785,330,790],.635)
add('cast','cast_v1',[(300,180),(740,180),(300,560),(740,560),(300,960),(745,960),(300,1320),(745,1320)],[300,740,300,740,300,745,300,745],.668)
# The first death-master tank cap touches the canvas edge. Start with the
# complete ready pose, then use the seven new descending/corpse postures.
add('death','idle_v1',[(325,185)],[325],.65)
add('death','death_v1',[(1120,190),(410,540),(1090,540),(410,800),(1090,800),(410,1000),(1090,1000)],[1100,410,1090,440,1150,440,1150],.62)
add('move','move_far_v1',[(350,250),(935,250)],[350,935],.416)
add('move','move_near_v1',[(350,270)],[350],.425)
add('move','move_near_corrections_v1',[(350,300),(1020,300),(1700,300)],[350,1020,1700],.327)
add('move','move_far_v1',[(350,850),(935,850)],[350,935],.416)
entry['clips']['idle'].update(frame_msec=150,indices=[0,1,2,3,5,6,4,7])
entry['clips']['cast'].update(frame_msec=125,contact_frame=4)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['death'].update(frame_msec=145)
entry['clips']['move'].update(frame_msec=110,painted_phase_order=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach'])
entry['visual_review']=dict(status='accepted',notes='Original sources and actual Godot 128px phases inspected. Pot remains in the near hand and lantern in the far hand throughout idle, windup/throw/reload, recoil, crouched defense, raised-lantern support and reciprocal gait. The tank and hose follow the torso without changing ownership or size. Near heel reach/contact/support use corrected original paintings. Death starts from the complete ready stance, avoiding the cropped tank cap in the rejected first death-master pose, then uses seven descending/settled poses. Painted thrown pot is retained for this melee-only action. Body scale, ground registration and complete silhouettes reviewed; live imported battle/map checks follow publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
