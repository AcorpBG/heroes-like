"""Register original Cinderwake poses, including detached bow/arrow ownership."""
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

add('idle','idle_v1',[(295,200),(710,200),(295,580),(710,580),(300,960),(710,960),(295,1340),(710,1340)],[295,710,295,710,300,710,295,710],.62)
indices=entry['clips']['idle']['indices'];entry['clips']['idle']['indices']=[indices[i] for i in [0,2,1,3,4,5,6,7]]
add('attack','attack_v1',[(265,200),(740,200),(290,580),(770,580),(275,970),(750,970)],[265,745,290,765,275,750],.60)
# Reject the extra-hand recovery and the unrequested held-arrow final pose.
# Distinct coherent elbow-return and neutral-ready paintings complete recovery.
add('attack','reactions_v1',[(320,570)],[320],.54)
add('attack','idle_v1',[(295,200)],[295],.62)
add('ranged','ranged_v1',[(270,195),(755,195),(270,575),(740,575),(270,970),(765,970),(275,1350),(760,1350)],[270,755,270,740,270,765,275,760],.65)
add('hit','reactions_v1',[(330,205),(765,220),(320,570),(745,585)],[330,765,320,745],.54)
add('defend','defend_v2',[(280,340),(875,350),(290,1040),(895,980)],[285,875,290,895],.387)
add('cast','cast_v1',[(310,200),(740,200),(310,580),(750,580),(310,970),(740,970),(310,1340),(740,1340)],[310,740,310,750,310,740,310,740],.64)
add('death','death_v1',[(245,230),(730,270),(270,730),(770,795),(245,1090),(740,1100),(245,1390),(740,1390)],[245,730,270,760,260,750,260,750],.515,
    floors=[462,462,862,878,1182,1160,1450,1450],extras={4:[(442,1151)],5:[(929,1168)],6:[(438,1458)],7:[(930, 1458)]})

# Far contact/support, then opposite near passing/reach/contact/support,
# then far passing and far heel reach to close the cycle.
add('move','move_v1',[(310,200),(745,200)],[310,745],.635)
add('move','move_near_v1',[(350,865),(880,870),(350,260),(875,260)],[350,880,350,875],.38,[1261,1270,638,639])
add('move','move_v1',[(300,575),(765,585)],[300,765],.635,[759,759])
entry['clips']['idle'].update(frame_msec=145)
entry['clips']['attack'].update(frame_msec=100,contact_frame=4,static_frame=0)
entry['clips']['ranged'].update(frame_msec=110,contact_frame=5,static_frame=0)
entry['clips']['cast'].update(frame_msec=120,contact_frame=4)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['death'].update(frame_msec=140)
entry['clips']['move']['painted_phase_order']=['far contact','far support','near passing','near heel reach','near contact','near support','far passing','far heel reach']
entry['visual_review']=dict(status='accepted',notes='Source paintings and 128px candidate render reviewed: visible string-hand and bow-arm gestures, anatomical bow bash, draw/release/recovery with no painted projectile after release, fixed bow-hand defense, reciprocal foot contacts, physical rally and grounded collapse. Reaction source uses corrected fixed scale to match approximately 216px anatomy; final imported live render follows.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({c:len(s['indices']) for c,s in entry['clips'].items()})
