"""Register Dawnwrit originals with consistent lantern staff, book and ground anchors."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 200px crown-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(320,230),(740,230),(320,610),(745,610),(325,1000),(740,1000),(320,1380),(740,1380)],[320,740,320,745,325,740,320,740],.597)
# Select intact original windups, repainted strike phases and full ready
# recoveries. Clipped staff/book ends and oversize contact experiments remain
# in generation provenance but never enter the runtime atlas.
add('attack','attack_v1',[(160,320),(510,320),(840,320)],[160,510,840],.465)
add('attack','attack_corrections_v3',[(380,450),(1140,460),(1840,460)],[365,1110,1830],.37)
add('attack','attack_v1',[(840,960)],[840],.465)
add('attack','idle_v1',[(740,1380)],[740],.597)
entry['clips']['attack'].update(frame_msec=110,contact_frame=4,static_frame=0)
add('ranged','ranged_v1',[(295,240),(745,240),(295,620),(750,620),(305,1000),(750,1000),(290,1380),(745,1380)],[295,745,295,750,305,750,290,745],.645)
entry['clips']['ranged'].update(frame_msec=120,contact_frame=4,static_frame=0)
# The source placed recoil/recovery and guarding out of intended row order.
add('hit','reactions_v1',[(320,230),(320,625),(795,625),(295,1380)],[320,320,795,295],.57)
add('defend','reactions_v1',[(795,240),(310,995),(795,1010),(795,1390)],[795,310,795,795],.57)
add('cast','cast_v1',[(300,245),(730,245),(300,625),(730,625),(310,1005),(730,1005),(295,1380),(730,1380)],[300,730,300,730,310,730,295,730],.588)
add('death','death_v1',[(365,260),(865,270),(390,690),(910,700),(385,940),(1010,950),(400,1150),(1015,1170)],[365,865,390,910,385,960,370,970],.55,[440,440,790,790,1005,1008,1214,1214],extras={4:[(50,970),(417,997)],5:[(680,991),(1020,1004)],6:[(80,1195),(392,1210)],7:[(670,1199),(1041,1212)]})
add('move','move_far_v1',[(440,260),(1190,260)],[440,1190],.465,[475,475])
add('move','move_near_v1',[(510,260),(1125,260),(510,775),(1125,775)],[510,1125,510,1125],.444,[500,505,999,1000])
add('move','move_far_v1',[(450,780),(1220,780)],[450,1220],.465,[981,970])
entry['clips']['idle'].update(frame_msec=145)
entry['clips']['cast'].update(frame_msec=125,contact_frame=3)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['death'].update(frame_msec=140)
entry['clips']['move']['painted_phase_order']=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach']
entry['visual_review']=dict(status='accepted',notes='Original sources inspected for staff/book ownership, equipment length, physical melee strike, ranged release, book invocation, recoil/guard, opposing gait and grounded collapse. Fixed anatomical scale per source; selected late book/staff components retained. All eight clips inspected at native 128px Godot scale: consistent staff length through the corrected strike, broad book invocation, alternating leg phases and complete grounded corpse equipment. Imported battle/map review follows.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
