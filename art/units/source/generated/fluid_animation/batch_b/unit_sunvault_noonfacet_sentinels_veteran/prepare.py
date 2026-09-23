"""Register Meridian Lockguard original sundial-shield poses and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 204px helmet-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(265,175),(750,175),(265,550),(750,550),(265,940),(750,940),(265,1320),(750,1320)],[265,750,265,750,265,750,265,750],.586)
# Replace the clipped first attack weapon with a matching complete ready painting.
add('attack','idle_v1',[(265,175)],[265],.586)
add('attack','attack_v1',[(700,200),(250,600),(700,600),(200,1000),(700,990),(210,1360),(720,1350)],[700,250,700,200,700,210,720],.600)
entry['clips']['attack'].update(frame_msec=120,contact_frame=4,static_frame=0)
# Death anticipation supplies a complete recoil, replacing the clipped reaction master pose.
add('hit','death_v1',[(240,215)],[240],.497)
add('hit','reactions_v1',[(710,195),(250,555),(745,555)],[710,250,745],.580)
add('defend','reactions_v1',[(260,970),(735,970),(265,1360),(750,1355)],[260,735,265,750],.580)
add('cast','cast_v1',[(260,200),(750,210),(280,640),(760,640),(260,1000),(750,1000),(260,1360),(745,1360)],[260,750,280,760,260,750,260,745],.600)
add('death','death_v1',[(240,215),(710,245),(245,675),(710,705),(240,1060),(715,1055),(215,1380),(735,1380)],[240,710,245,710,245,760,255,765],.497,extras={5:[(890,1120)],6:[(340,1439)],7:[(880,1435)]})
add('move','move_far_v1',[(325,300)],[325],.393,[599])
add('move','move_support_v1',[(570,600)],[570],.207,[1172])
add('move','move_far_v1',[(325,900)],[325],.393,[1185])
add('move','move_near_v1',[(880,940),(295,280)],[880,295],.366,[1220,615])
add('move','move_far_v1',[(935,300)],[935],.393,[605])
add('move','move_near_v1',[(290,945)],[290],.366,[1231])
add('move','move_far_v1',[(935,900)],[935],.393,[1189])
entry['clips']['idle'].update(frame_msec=150)
entry['clips']['hit'].update(frame_msec=115)
entry['clips']['cast'].update(frame_msec=130,contact_frame=3)
entry['clips']['defend'].update(frame_msec=125,static_frame=3)
entry['clips']['death'].update(frame_msec=150)
entry['clips']['move'].update(frame_msec=110,painted_phase_order=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach'])
entry['visual_review']=dict(status='accepted',notes='Original masters inspected. Eight articulated idle, polearm attack/recovery, shield brace, physical rally and progressive grounded collapse poses preserve the original identity. Clipped first attack/reaction paintings are excluded. Gait follows actual anatomical leg ownership rather than generation row labels; an additional original far-leg support pose completes the reciprocal cycle. Actual Godot 128px action phases inspected: complete weapon tips, matched body size, planted idle feet, visible polearm/gauntlet motion, shield impact absorption, salute recovery, reciprocal near/far steps and grounded retained equipment through collapse. Imported live battle and overworld verification follows publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
