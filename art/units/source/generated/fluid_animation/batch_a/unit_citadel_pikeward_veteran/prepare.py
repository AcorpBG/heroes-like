"""Register original Gateward paintings without painting or deforming pixels."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / 'tools'))
from refine_fluid_frame_crops import body_rectangles

entry = dict(unit_id=HERE.name, reference_height=256, source_facing='right', frames=[], clips={},
    source_scale_by_image={}, source_scale_reason='Fixed scale per original source matches the existing approximately 185px crest-to-sole anatomy at a 256px reference. Registration follows pelvis centers and planted soles; no pose-specific resizing.',
    provenance=dict(tool='builtin_image_gen', sources=[], reference=(HERE/'reference.png').relative_to(ROOT).as_posix(), generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

def add(clip, stem, seeds, centers, scale, floors=None, extra_seeds=None):
    source=HERE/(stem+'.png'); prompt=HERE/(stem+'.prompt.txt'); path=source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path]=scale
    for n,(seed,cx) in enumerate(zip(seeds,centers)):
        rects=body_rectangles(source,seed,8)
        extras=(extra_seeds or {}).get(n,[])
        for extra in extras:
            rects.extend(body_rectangles(source,extra,8))
        rects=[list(r) for r in sorted(set(tuple(r) for r in rects))]
        floor=(floors or [None]*len(seeds))[n]
        if floor is None: floor=max(r[3] for r in rects)
        index=len(entry['frames'])
        entry['frames'].append(dict(name=f'{clip}_{index}',clip=clip,source=path,rects=rects,anchor=[cx,floor],scale=scale,alpha_noise_cutoff=8,crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8,additional_seeds=extras)))
        entry['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ('idle','move')))['indices'].append(index)

add('idle','idle_v1',[(310,210),(730,210),(325,580),(755,580),(340,970),(735,970),(330,1360),(730,1360)],[310,730,330,750,340,730,330,730],.61)
add('attack','attack_v1',[(210,220),(700,250),(190,600),(720,620),(205,970),(730,970),(210,1350),(730,1350)],[210,695,195,720,205,730,210,730],.56)
add('hit','reactions_v1',[(345,230),(740,240),(350,610),(720,590)],[345,740,350,720],.59)
add('defend','reactions_v1',[(350,1010),(720,990),(380,1390),(720,1330)],[350,720,370,720],.59)
add('cast','cast_v3',[(290,210),(750,210),(300,580),(760,580),(330,970),(750,970),(300,1360),(760,1360)],[290,750,300,760,330,750,300,760],.61)
add('death','death_v1',[(280,245),(780,275),(280,685),(800,760),(295,1070),(800,1100),(290,1390),(800,1400)],[280,780,280,780,280,775,280,775],.53,
    extra_seeds={4:[(99,900)],5:[(932,1184)],6:[(440,1480)],7:[(944,1485)]})

# Reciprocal gait: far contact/support, near passing/reach/contact,
# early and late far swing over the near support leg, then far heel reach.
add('move','move_v1',[(295,210),(300,590)],[295,300],.61)
add('move','move_missing_v1',[(410,375),(970,375)],[420,970],.285,[781,781])
add('move','move_contact_v1',[(500,480)],[500],.242,[955])
add('move','move_v1',[(300,970)],[300],.61)
add('move','move_near_v1',[(350,1010)],[350],.35,[1314])
add('move','move_v1',[(755,970)],[755],.61)
entry['clips']['idle'].update(frame_msec=145)
entry['clips']['attack'].update(frame_msec=100,contact_frame=4,static_frame=0)
entry['clips']['cast'].update(frame_msec=120,contact_frame=4)
entry['clips']['death'].update(frame_msec=140)
entry['clips']['defend'].update(frame_msec=120,static_frame=3)
entry['clips']['move']['painted_phase_order']=['far contact','far support','near passing','near heel reach','near contact','early far swing over near support','late far swing over near support','far heel reach']
entry['visual_review']=dict(status='accepted',notes='Original paintings and native 128px render reviewed: visible elbow, wrist, shield and knee articulation; reciprocal contacts and passing legs; stable approximately 185px crest-to-sole anatomy, complete pike and shield silhouettes, grounded collapse with a persistent corpse. Rejected raised-pike support versions and repeated-foot gait poses remain original source history only.')
(HERE/'handoff.json').write_bytes((json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n').encode())
print({k:len(v['indices']) for k,v in entry['clips'].items()})
