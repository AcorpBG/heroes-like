"""Register Arrestor Spooler original rope, crank and articulated body sequences."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 233px reel-top-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(280,165),(750,165),(280,545),(750,545),(280,925),(750,925),(280,1310),(750,1310)],[280,750,280,750,280,750,280,750],.645)
add('attack','attack_v1',[(270,160),(750,165),(265,550),(750,565),(260,965),(750,945),(270,1340),(750,1310)],[270,750,265,750,250,750,270,750],.659)
add('ranged','ranged_v1',[(300,160),(770,170),(295,575),(770,575)],[290,770,285,765],.697)
# First ranged release had an extra hand. Replace with this correctly handed original.
add('ranged','release_v1',[(480,550)],[480],.228)
add('ranged','ranged_v1',[(760,940),(280,1330),(740,1330)],[750,275,740],.697)
add('hit','reactions_v1',[(310,165),(755,200),(320,555),(755,555)],[310,750,310,750],.634)
add('defend','reactions_v1',[(310,945),(755,970),(310,1340),(750,1340)],[310,750,310,750],.634)
add('cast','cast_v1',[(295,165),(735,165),(295,545),(735,545),(295,925),(735,925),(295,1305),(735,1305)],[295,735,295,735,295,735,295,735],.633)
add('death','death_v1',[(275,260),(775,300),(250,700),(745,740),(265,1090),(770,1090),(270,1390),(770,1390)],[270,770,270,770,270,770,270,770],.514)
# Near contact/support, far passing/reach/contact/support, near passing/reach.
add('move','move_v1',[(750,160),(320,930),(740,930)],[735,320,735],.649)
add('move','move_transitions_v1',[(495,400)],[490],.299)
add('move','move_v1',[(320,550),(750,550)],[320,735],.649)
add('move','move_transitions_v1',[(1300,400)],[1300],.299)
add('move','move_v1',[(750,1320)],[735],.649)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':120,'ranged':125,'hit':115,'defend':130,'cast':130,'death':155,'move':115}[name])
for name in ('attack','ranged','cast'):entry['clips'][name]['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='All 56 original frames reviewed at Godot 128px reference height. Nine masters preserve the stocky respirator soldier, 233px reel-to-sole source silhouette and correct near rope/far crank hands. Short melee swing and longer overhead ranged cast have distinct windups and recovery; brace/recoil, open far-hand support signal and grounded collapse are readable. Corrected release removes extra hand from first proposal. Foreground passing and background reach originals complete reciprocal gait. No per-pose deformation or resizing; unused/rejected original poses and exact lineage retained.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
