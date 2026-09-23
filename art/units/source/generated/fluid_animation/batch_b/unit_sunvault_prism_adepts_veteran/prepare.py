"""Register Lattice Conjurer original staff actions and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 232px mitre-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(255,195),(735,190),(255,575),(735,565),(255,965),(735,960),(255,1340),(735,1340)],[255,735,255,735,255,735,255,735],.615)
add('attack','attack_v1',[(240,190),(730,210),(275,570),(725,580),(240,960),(710,960),(240,1310),(750,1305)],[240,730,275,725,240,710,240,750],.622)
entry['clips']['attack'].update(frame_msec=120,contact_frame=4,static_frame=0)
add('ranged','ranged_v1',[(235,190),(720,190),(240,570),(735,570),(235,950),(720,955),(250,1330),(725,1340)],[235,720,240,735,235,720,250,725],.625)
entry['clips']['ranged'].update(frame_msec=125,contact_frame=4,static_frame=0)
add('hit','reactions_v1',[(255,190),(750,215),(270,590),(745,570)],[255,750,270,745],.628)
add('defend','reactions_v1',[(270,960),(755,1000),(250,1340),(740,1310)],[270,755,250,740],.628)
# Keep the supporting near hand fixed on the shaft through all free far-hand gestures.
# The original cast middle poses float the staff and are intentionally excluded.
add('cast','cast_v1',[(270,195)],[270],.628)
add('cast','cast_transitions_v1',[(310,310),(890,310)],[310,890],.385)
add('cast','cast_corrections_v1',[(325,375),(970,375)],[325,970],.307)
add('cast','cast_transitions_v1',[(890,940),(325,940)],[890,325],.385)
add('cast','cast_v1',[(735,1340)],[735],.628)
add('death','death_v1',[(240,270),(725,325),(250,700),(725,765),(245,1110)],[240,725,250,725,250],.483)
# Grounded original follow-through: pendants rest flat rather than hanging under corpse.
add('death','death_grounded_v1',[(1150,425),(375,790),(1130,810)],[1120,400,1130],.340,extras={0:[(1450,544),(1510,519),(1320,523)],1:[(520,895),(733,905),(699,833)],2:[(1293,910),(1495,912),(1479,841)]})
add('move','move_far_v1',[(350,320),(945,320)],[350,945],.389,[606,609])
add('move','move_near_v1',[(320,320)],[320],.395,[600])
add('move','move_reach_v1',[(630,610)],[630],.200,[1187])
add('move','move_foreground_v1',[(1110,330),(1830,330)],[1110,1830],.343,[695,699])
add('move','move_far_v1',[(350,945),(965,945)],[350,965],.389,[1219,1215])
entry['clips']['idle'].update(frame_msec=155)
entry['clips']['hit'].update(frame_msec=115)
entry['clips']['cast'].update(frame_msec=130,contact_frame=4)
entry['clips']['defend'].update(frame_msec=125,static_frame=3)
entry['clips']['death'].update(frame_msec=150)
entry['clips']['move'].update(frame_msec=110,painted_phase_order=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach'])
entry['visual_review']=dict(status='accepted',notes='Original identity and new source paintings inspected. Eight action families retain concealed face, prismatic mitre, layered robes and caged-crystal staff. Dedicated ranged aim/release has internal crystal light only; support keeps near hand on shaft while free far hand gestures. Wrong-hand and repeated far-leg proposals are excluded. Foreground leg paintings and a separate original near heel reach complete the reciprocal gait. Original and final actual Godot 128px action phases inspected: visible two-hand idle, melee recovery, separate aim/release/recoil, staff brace, consistent support-hand ownership and full reciprocal gait. Repainted final collapse rests body, staff and pendant crystals on one ground plane. Stable body size and complete staff ends verified. Imported live battle/map verification follows publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
