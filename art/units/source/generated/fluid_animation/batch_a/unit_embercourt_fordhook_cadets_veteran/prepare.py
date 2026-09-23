"""Register Chainford Marshal original chained-hook poses and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 216px head-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(285,185),(750,185),(285,565),(750,565),(285,945),(750,945),(285,1330),(750,1330)],[285,750,285,750,285,750,285,750],.615)
add('attack','attack_v1',[(330,160),(845,170),(325,500),(860,500),(330,815),(865,820),(335,1140),(865,1140)],[330,845,325,860,330,865,335,865],.68)
entry['clips']['attack'].update(frame_msec=120,contact_frame=4,static_frame=0)
add('hit','reactions_v1',[(305,185),(735,185),(310,570),(745,570)],[305,735,310,745],.58)
add('defend','reactions_v1',[(310,960),(750,960),(320,1330),(750,1350)],[310,750,320,750],.58)
add('cast','cast_v1',[(355,175),(745,175),(350,540),(745,540),(350,970),(745,970),(350,1340),(745,1340)],[355,745,350,745,350,745,350,745],.656)
# Actual death source is column-major: four descending poses at left,
# then four side-lying poses at right. Keep both dropped hooks and chain.
add('death','death_v1',[(275,195),(280,565),(290,885),(305,1180),(840,290),(840,610),(835,925),(840,1200)],[275,280,290,305,850,860,870,870],.545,[407,736,1020,1270,383,693,1007,1273],extras={4:[(850,383)],5:[(850,699)],6:[(850,1013)],7:[(870,1272)]})
add('move','move_far_v1',[(355,260),(985,260)],[355,985],.393,[584,586])
add('move','move_near_v1',[(350,250),(990,250),(350,850),(990,850)],[350,990,350,990],.384,[583,583,1163,1165])
add('move','move_far_v1',[(355,835),(985,835)],[355,985],.393,[1165,1158])
entry['clips']['idle'].update(frame_msec=145)
entry['clips']['cast'].update(frame_msec=125,contact_frame=4)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['death'].update(frame_msec=145)
entry['clips']['move'].update(frame_msec=110,painted_phase_order=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach'])
entry['visual_review']=dict(status='accepted',notes='Original sources and actual Godot 128px action phases inspected for face/coat identity, dual hooks, chain attachments and anatomical leg ownership. Attack has a near-hook windup/swing followed by a far-hook lunge and two-arm recovery. Death reordered by actual posture, with both grounded hooks and their chain retained. Native review confirms visible grip/forearm idle, crossed-hook brace, raised-hook rally, reciprocal gait, stable body scale and full weapon tips. Imported battle/map verification follows publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
