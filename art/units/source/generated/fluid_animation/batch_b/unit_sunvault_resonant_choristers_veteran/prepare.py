"""Register Harmonic Precentor original tuning-fork actions and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 232px crest-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
    provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'identity_reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

def add(clip,stem,seeds,centers,scale,floors=None,extras=None):
    source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt');path=source.relative_to(ROOT).as_posix()
    cutoff=12 if stem=='ranged_v1' else 8
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

add('idle','idle_v1',[(270,195),(760,195),(270,575),(760,575),(270,970),(760,970),(270,1345),(760,1345)],[270,760,270,760,270,760,270,760],.619)
add('attack','attack_v1',[(275,210),(715,230)],[275,715],.610)
# Replace malformed fork/pommel windup with a complete original raised-staff pose.
add('attack','corrections_v1',[(480,420)],[480],.298)
add('attack','attack_v1',[(710,590),(245,955),(740,970),(275,1325),(735,1325)],[710,245,740,275,735],.610)
entry['clips']['attack'].update(frame_msec=120,contact_frame=4,static_frame=0)
# Alpha-joined release/recovery proposals are replaced, not counted as new frames.
add('ranged','ranged_v1',[(270,195),(750,195),(265,565),(740,565)],[270,750,265,740],.619)
add('ranged','ranged_corrections_v1',[(450,370)],[450],.319)
add('ranged','ranged_v1',[(740,965)],[740],.619)
add('ranged','ranged_corrections_v1',[(1620,370)],[1620],.319)
add('ranged','ranged_v1',[(740,1320)],[740],.619)
entry['clips']['ranged'].update(frame_msec=125,contact_frame=4,static_frame=0)
add('hit','reactions_v1',[(300,200),(730,210),(340,585),(715,585)],[300,730,340,715],.620)
add('defend','reactions_v1',[(300,955),(740,980),(310,1340),(730,1310)],[300,740,310,730],.620)
# Source actually keeps FAR hand on staff; one switched-hand middle proposal is excluded.
add('cast','cast_v1',[(265,190),(760,190),(265,570)],[265,760,265],.627)
add('cast','corrections_v1',[(1280,430)],[1280],.298)
add('cast','cast_v1',[(265,955),(760,955),(265,1330),(760,1330)],[265,760,265,760],.627)
add('death','death_v1',[(250,245),(750,285),(275,710),(755,760),(275,1090),(760,1130),(250,1400),(765,1400)],[250,750,275,755,280,765,265,770],.509)
add('move','move_far_v1',[(360,325),(950,325),(350,945)],[360,950,350],.383,[600,619,1231])
add('move','move_near_v1',[(365,315),(950,325),(370,940),(950,940)],[365,950,370,950],.383,[610,605,1226,1225])
add('move','move_far_v1',[(960,945)],[960],.383,[1226])
entry['clips']['idle'].update(frame_msec=155)
entry['clips']['hit'].update(frame_msec=115)
entry['clips']['cast'].update(frame_msec=130,contact_frame=3)
entry['clips']['defend'].update(frame_msec=125,static_frame=3)
entry['clips']['death'].update(frame_msec=150)
entry['clips']['move'].update(frame_msec=110,painted_phase_order=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach'])
entry['visual_review']=dict(status='accepted',notes='Original sources inspected. Ten masters retain closed mask, rounded chime halo, ivory/blue robes and complete tuning-fork staff. Corrected windup restores fork/pommel identity; corrected conducting downbeat keeps far hand on shaft and near hand free. Gait follows actual robe/leg occlusion, with reciprocal foreground steps. Grounded collapse retains halo, staff and resting chimes. Original and actual Godot 128px phases inspected: stable scale and full weapon tips, visible idle grip and conducting hand, melee recovery, separate ranged aim/release/recoil, brace, reciprocal steps and grounded retained halo/chimes. Alpha-joined ranged release/recovery proposals are replaced with separate original paintings; the remaining ranged source uses cutoff 12 to remove low-alpha bridges. Imported live battle/map verification follows publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
