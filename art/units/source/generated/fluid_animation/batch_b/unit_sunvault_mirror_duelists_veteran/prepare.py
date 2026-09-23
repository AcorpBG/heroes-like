"""Register Parallax Blades articulated twin-saber actions and reciprocal gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 226px helmet-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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


# Native review rejected the first idle master: short blue sword and clipped
# final violet tip. The second master preserves the original saber proportions.
add('idle','idle_v2',[(325,180),(825,180),(325,535),(825,535),(325,885),(825,885),(325,1240),(825,1240)],[325,825,325,825,325,825,325,825],.665)
# Original attack first six poses have a coherent swing; use matching ready
# transitions for the two oversized recovery paintings at the master bottom.
add('attack','attack_v1',[(285,190),(750,200),(260,600),(745,565),(285,940),(745,940)],[285,750,260,745,285,745],.648)
add('attack','cast_v1',[(335,1200),(850,1200)],[330,845],.655)
entry['clips']['attack'].update(frame_msec=115,contact_frame=4,static_frame=0)
add('hit','reactions_v1',[(340,180),(900,190),(340,525),(890,535)],[340,900,340,890],.646)
add('defend','reactions_v1',[(330,860),(900,860),(330,1170),(920,1170)],[330,900,330,920],.646)
# The first cast row cuts helmet points. Begin with complete ready/lift poses.
add('cast','idle_v2',[(325,180),(825,180)],[325,825],.665)
add('cast','cast_v1',[(335,520),(850,520),(345,850),(850,870),(335,1200),(850,1200)],[330,845,340,845,330,845],.655)
add('death','death_v1',[(290,210),(790,250),(325,700),(810,740),(280,1080),(780,1090),(260,1380),(780,1390)],[290,790,325,810,280,780,270,790],.522,extras={4:[(440,1057),(210,1171)],5:[(930,1038),(710,1172)],6:[(430,1338),(200,1470)],7:[(920,1345),(690,1480)]})
# Select actual painted anatomy: the first walk master mixed leading legs.
add('move','move_missing_v1',[(510,345)],[505],.276)
add('move','move_far_corrections_v1',[(1850,265)],[1850],.345)
add('move','move_missing_v1',[(1350,345)],[1350],.276)
add('move','move_far_v1',[(960,870),(365,230),(960,230),(365,870)],[960,365,960,365],.395)
add('move','move_far_corrections_v1',[(430,265)],[430],.345)
entry['clips']['idle'].update(frame_msec=150)
entry['clips']['cast'].update(frame_msec=125,contact_frame=4)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['death'].update(frame_msec=150)
entry['clips']['move'].update(frame_msec=110,painted_phase_order=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach'])
entry['visual_review']=dict(status='accepted',notes='Original paintings and actual Godot 128px phases inspected for full masked design, blue/lavender cloth sides, firmly gripped blue-near/violet-far sabers and decorated-near-knee ownership. Idle v2 replaces a shortened-blue-blade/cropped-tip first master. Complete ready transitions replace clipped cast helmet points and oversized attack recoveries. Both dropped death swords are explicitly retained from original pixels. Fixed anatomical source scales, complete weapon tips, visible wrists/elbows, separate X guard and salute, reciprocal gait and grounded corpse reviewed. Imported battle/map checks follow publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
