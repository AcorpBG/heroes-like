"""Register Ledgerwall Porter original articulated animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 233px helmet-to-sole ready silhouette and shoulder plate size. Planted boots provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(280,170),(750,170),(290,555),(750,555),(290,945),(750,945),(290,1305),(750,1305)],[290,750,290,750,290,750,290,750],.665)
add('attack','attack_v1',[(300,175),(790,175),(300,565),(790,565),(300,950),(770,950)],[300,790,300,790,300,790],.708)
# Original ready paintings are shared only across clips for anatomical continuity.
# The last two attack-master paintings grew taller and are not shipped.
add('attack','idle_v1',[(750,170),(750,1305)],[750,750],.665)
add('hit','reactions_v1',[(285,170),(765,185),(285,565),(780,565)],[285,780,285,780],.670)
add('defend','reactions_v1',[(285,935),(780,935),(285,1330),(780,1330)],[285,780,285,780],.670)
add('cast','cast_v1',[(280,175),(750,175),(280,560),(780,560),(290,950),(760,950),(290,1320),(750,1320)],[280,750,280,750,280,750,280,750],.658)
add('death','death_v1',[(410,170),(1080,180),(410,470),(1100,470),(410,695),(1110,720),(410,875),(1110,880)],[425,1110,425,1110,425,1110,425,1110],.745)
# Foreground thigh crosses in front of the apron, far leg stays behind it.
# Near reach/contact/support -> far passing/reach/contact/support -> near passing.
add('move','move_near_v1',[(955,275),(340,875),(955,880)],[960,340,960],.414)
add('move','move_v1',[(750,555),(265,170),(750,170),(265,555)],[750,265,750,265],.668)
add('move','move_near_v1',[(340,260)],[340],.414)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':120,'hit':115,'defend':130,'cast':135,'death':150,'move':115}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Seven original masters; hatchet lift/wrist idle, overhead chop/recovery, hit recoil, shield brace, tool salute, grounded collapse and reciprocal gait. Fixed master scale matches original helmet/shoulder dimensions; corrected near-leg paintings visibly cross the apron. The eight-frame attack uses six dedicated attack paintings then idle paintings 2 and 8 as correctly scaled return-to-guard recovery, replacing two oversized source recovery paintings. No repeated image within any clip; 46 distinct paintings populate 48 frame entries. Actual Godot 128px battle review confirms readable hands/elbows, leg contacts and grounded equipment, with no cropping or joined sprites.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
