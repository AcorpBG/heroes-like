"""Register Kilnwall Warden original two-person combat poses."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 233px shield-tip-to-ground team. Shield center and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(270,150),(775,150),(270,540),(775,540),(270,920),(775,920),(270,1300),(775,1300)],[270,775,270,775,270,775,270,775],.695)
add('attack','attack_v1',[(260,160),(760,160),(265,550),(780,550),(300,930),(800,930),(265,1300),(760,1300)],[260,755,265,750,265,755,265,760],.69)
add('hit','reactions_v1',[(265,170),(770,180),(265,560),(770,560)],[265,770,265,770],.67)
add('defend','reactions_v1',[(265,940),(770,940),(270,1300),(770,1300)],[265,770,270,770],.67)
add('cast','cast_v1',[(270,160),(760,160),(270,550),(760,550),(270,940),(760,940),(270,1320),(760,1320)],[270,760,270,760,270,760,270,760],.675)
add('death','death_v1',[(260,200),(760,240),(270,600),(780,670),(270,1050),(770,1050),(265,1380),(770,1400)],[260,760,260,760,260,760,260,760],.64,extras={2:[(485,740)],3:[(969,760)],4:[(460,1075)],5:[(970,1110)],6:[(456,1460)],7:[(970,1470)]})
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':125,'hit':115,'defend':130,'cast':130,'death':155}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted_selected_clips',notes='Six original two-person combat sequences reviewed in actual Godot 128px renders: rim-grip and poker idle, shove/jab with recovery, recoil, brace, physical support signal and grounded two-body collapse. Five movement proposal sheets are retained but explicitly unaccepted: alternating leg ownership is not yet coherent for both crew. Movement remains unfinished.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
