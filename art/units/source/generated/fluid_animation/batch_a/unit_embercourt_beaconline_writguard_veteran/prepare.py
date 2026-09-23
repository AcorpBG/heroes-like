"""Register Lanternwall originals with grounded spear, shield and opposing leg phases."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 190px helmet-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(325,220)],[325],.597)
add('idle','corrections_v1',[(490,400)],[490],.282,[840])
add('idle','idle_v1',[(335,610),(755,610),(335,985),(755,985),(335,1380),(755,1380)],[335,755,335,755,335,755],.597)
add('attack','attack_v1',[(335,220),(840,230)],[335,840],.655)
add('attack','corrections_v1',[(1160,520)],[1160],.282,[840])
add('attack','attack_v1',[(850,510),(290,785),(840,790),(350,1120),(870,1120)],[850,290,840,350,870],.655)
entry['clips']['attack'].update(frame_msec=110,contact_frame=4,static_frame=0)
add('hit','reactions_v1',[(380,220),(910,230),(415,515),(890,505)],[380,910,415,890],.65)
add('defend','reactions_v1',[(400,815),(895,820),(410,1150),(900,1150)],[400,895,410,900],.65)
add('cast','cast_v1',[(375,210),(825,210),(370,545),(825,545),(370,870),(825,885),(370,1200),(825,1200)],[375,825,370,825,370,825,370,825],.645)
# Released spears remain part of the last four original death paintings.
add('death','death_v1',[(310,230),(800,250),(305,680),(810,710),(295,1030),(775,1040),(300,1360),(800,1370)],[305,800,305,805,290,780,290,790],.528,[443,443,835,839,1120,1105,1410,1425],extras={4:[(35,1062)],5:[(545,1080)],6:[(36,1400)],7:[(545,1405)]})
# The first far sheet repeats the near-leg gait and is deliberately not used.
add('move','move_far_v2',[(415,255),(1080,255)],[415,1080],.395,[575,574])
add('move','move_near_v1',[(435,255),(1060,255),(435,820),(1070,820)],[435,1060,435,1070],.386,[583,586,1144,1148])
add('move','move_far_v2',[(420,820),(1070,820)],[420,1070],.395,[1148,1148])
entry['clips']['idle'].update(frame_msec=145)
entry['clips']['cast'].update(frame_msec=125,contact_frame=3)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['death'].update(frame_msec=140)
entry['clips']['move']['painted_phase_order']=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach']
entry['visual_review']=dict(status='accepted',notes='Original paintings and actual Godot 128px phase render inspected for near-arm spear and far-arm shield ownership, articulated grip, thrust, brace/rally and collapse. Clipped idle tip, excessive windup spear and repeated same-leg gait replaced. Consistent anatomical size, visible alternating knees, dedicated shield raise, complete pennons and released corpse equipment verified at battle size. Imported battle/map verification follows publication.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
