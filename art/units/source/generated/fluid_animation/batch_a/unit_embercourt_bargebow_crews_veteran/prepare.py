"""Register Winchbow originals with complete crossbow silhouettes and reciprocal gait."""
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

add('idle','idle_v1',[(285,240),(750,240),(280,620),(750,620),(280,1000),(750,1000),(280,1380),(750,1380)],[280,745,280,745,280,745,280,745],.635)
add('attack','attack_v1',[(255,240),(735,240),(260,610),(740,610),(240,990),(740,1000),(250,1380),(740,1380)],[255,735,260,740,240,740,250,740],.635)
entry['clips']['attack'].update(frame_msec=100,contact_frame=4,static_frame=0)
add('ranged','ranged_v1',[(275,250),(730,250),(260,640),(730,640),(250,1010),(740,1010),(260,1370),(735,1370)],[275,730,260,730,250,740,260,735],.635)
entry['clips']['ranged'].update(frame_msec=115,contact_frame=5,static_frame=0)
add('hit','reactions_v1',[(275,240),(755,250),(300,645),(750,645)],[275,755,300,750],.60)
add('defend','reactions_v1',[(280,1010),(750,1010),(295,1370),(770,1370)],[280,750,295,770],.60)
# Exclude undersized high-hand and wrong-arm source poses. A corrected high
# gesture and a distinct crank-return painting provide continuous recovery.
add('cast','cast_v1',[(275,240),(745,240),(280,620)],[275,745,280],.635)
add('cast','corrections_v1',[(1300,500)],[1300],.307)
add('cast','cast_v1',[(750,1000),(280,1380)],[750,280],.635)
add('cast','idle_v1',[(750,1000)],[745],.635)
add('cast','cast_v1',[(750,1380)],[750],.635)
add('death','death_v1',[(310,240),(895,250),(310,620),(900,620),(320,895),(835,910),(240,1150),(870,1150)],[310,895,310,900,320,895,300,900],.582,[403,403,734,729,986,978,1208,1208])
# Earlier far_v1 has clipped right tips and a wrong knee; retain it only as
# rejected provenance. near_v1 actually paints the far-leg phases, so the
# explicitly authored phase order below follows the pixels, not its filename.
add('move','move_near_v1',[(400,290),(1110,290)],[400,1110],.48)
add('move','corrections_v1',[(445,520)],[445],.307)
add('move','move_near_v2',[(1120,290),(425,810),(1120,810)],[1120,425,1120],.483)
add('move','move_near_v1',[(410,810),(1110,810)],[410,1110],.48)
entry['clips']['idle'].update(frame_msec=145)
entry['clips']['cast'].update(frame_msec=120,contact_frame=3)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['death'].update(frame_msec=140)
entry['clips']['move']['painted_phase_order']=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach']
entry['visual_review']=dict(status='accepted',notes='Original sources inspected for winch-arm articulation, two-hand weapon ownership, reload/aim/release, recoil/guard, physical rally and grounded collapse. Wrong-arm, wrong-knee, clipped-tip and undersized high-hand paintings excluded. All eight sequences inspected in the native 128px Godot render: stable anatomy and weapon, visible crank/arm motion, reciprocal foot contacts, reload/release/recovery and grounded corpse. Final imported battle/map check follows.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
