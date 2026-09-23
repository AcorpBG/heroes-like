"""Register Covenant Bastion paintings with heavy joint articulation and reciprocal steps."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 228px lantern-tip-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(295,210),(755,210),(295,585),(755,585),(295,960),(755,960),(295,1340),(755,1340)],[295,755,295,755,295,755,295,755],.62)
add('attack','attack_v1',[(300,220),(785,220),(315,580),(780,595),(325,965),(795,965),(310,1340),(790,1340)],[300,785,315,780,325,795,310,790],.633)
entry['clips']['attack'].update(frame_msec=125,contact_frame=4,static_frame=0)
add('hit','reactions_v1',[(330,220),(805,220),(350,610),(785,610)],[330,805,350,785],.615)
# Read posture rather than source grid order: raised guard, chest guard,
# deeper knee flexion, then the final low shield brace.
add('defend','reactions_v1',[(310,1340),(310,975),(795,985),(795,1380)],[310,310,795,795],.615)
add('cast','cast_v1',[(300,210),(780,210),(295,590),(785,590),(300,965),(785,965),(300,1340),(775,1340)],[300,780,295,785,300,785,300,775],.62)
add('death','death_v1',[(330,245),(845,265),(320,640),(845,690),(250,1000),(850,1000),(280,1260),(845,1270)],[330,845,320,845,300,850,300,850],.555,[415,418,775,780,1090,1060,1325,1330])
# The initial walking masters mix leg halves. Select by visible hip/knee
# ownership. Only the first missing-pose painting has the requested near lift.
# Repainted far reach/contact/support also restore complete lantern caps.
add('move','far_corrections_v2',[(1120,330),(1780,330)],[1120,1780],.365,[670,670])
add('move','move_missing_v1',[(370,300)],[370],.364,[635])
add('move','move_far_v1',[(970,955),(370,295),(985,305)],[970,370,985],.377,[1218,616,617])
add('move','move_far_v1',[(365,960)],[365],.377,[1220])
add('move','far_corrections_v2',[(465,330)],[465],.365,[670])
entry['clips']['idle'].update(frame_msec=155)
entry['clips']['cast'].update(frame_msec=135,contact_frame=4)
entry['clips']['defend'].update(frame_msec=130,static_frame=3)
entry['clips']['death'].update(frame_msec=160)
entry['clips']['move'].update(frame_msec=135,painted_phase_order=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach'])
entry['visual_review']=dict(status='accepted',notes='Original paintings and actual Godot 128px phases reviewed for headless lantern/stone identity, two-toe feet, articulated near hand and far shield. Repeated leg leads excluded; selected complete tower tips and opposing gait. Native-scale review confirms consistent body mass, free-hand flexion and punch, protective palm support, progressively lowered shield brace and complete grounded collapse. Imported battle/map verification follows publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
