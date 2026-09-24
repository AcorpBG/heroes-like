"""Register Crown of the Drowned Fen original quadruped animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 234px crown-to-ground ready silhouette and shoulder/chest dimensions. Planted hooves provide registration; no per-pose resizing or deformation.',
    provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'identity_reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

def add(clip,stem,seeds,centers,scale,floors=None,extras=None,cutoff=8):
    source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt');path=source.relative_to(ROOT).as_posix()
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

add('idle','idle_v1',[(365,185),(950,190),(365,520),(950,530),(360,880),(935,875),(355,1210),(935,1210)],[355,940,355,940,355,940,355,940],.717)
add('attack','attack_v1',[(340,225),(775,240),(300,575),(810,580),(315,925),(805,960),(330,1320),(820,1320)],[330,820,330,820,330,820,330,820],.671)
add('hit','reactions_v1',[(340,240),(805,250),(345,610),(830,610)],[330,830,330,830],.673)
add('defend','reactions_v1',[(320,970),(800,970),(330,1340),(825,1340)],[330,830,330,830],.673)
add('cast','cast_v1',[(345,225),(840,225),(345,590),(840,590),(345,980),(840,980),(345,1360),(840,1350)],[335,835,335,835,335,835,335,835],.650)
add('death','death_v1',[(320,180),(900,260),(320,580),(900,615),(345,885),(935,920),(330,1170),(930,1180)],[330,930,330,930,330,930,330,930],.620)
# The near and far hind/fore hooves each receive distinct lift/plant paintings.
add('move','move_v1',[(390,180),(1035,180),(385,500),(1035,495),(385,810),(1035,810),(385,1125),(1035,1125)],[365,1005,365,1005,365,1005,365,1005],.770)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':125,'hit':115,'defend':130,'cast':135,'death':155,'move':120}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Six original masters preserve quadruped identity, crown, long tail, plates and hooves. Articulated forehoof/neck/jaw idle, grounded antler-jaw lunge and recovery, recoil, crown brace, raised-hoof call, grounded collapse and eight-pose walk. Fixed master scale follows shoulder/chest dimensions rather than normalizing raised/lowered antlers. All 48 original poses reviewed in the Godot battle overview at 128px reference height: crown/tail margins intact, distinct fore/hind hoof steps, four attached limbs with natural far-leg occlusion during the lunge, readable jaw/neck motion and grounded collapse. No joined sprite components.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
