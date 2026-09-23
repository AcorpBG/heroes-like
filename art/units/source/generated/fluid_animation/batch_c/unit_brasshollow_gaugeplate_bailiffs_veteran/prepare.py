"""Register Warrant Anvil original hammer, shield and reciprocal armored gait."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 214px helmet-to-sole body. Pelvis and planted soles provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(270,140),(765,145),(275,520),(765,520),(270,905),(765,905),(270,1290),(765,1290)],[270,765,270,765,270,765,270,765],.606)
add('attack','attack_v1',[(270,150),(765,145),(270,560),(770,585),(270,905),(750,905),(270,1260),(765,1280)],[270,765,260,765,240,740,270,765],.629)
add('hit','reactions_v1',[(275,140),(765,155),(300,500),(765,500)],[285,765,285,765],.618)
add('defend','reactions_v1',[(290,895),(770,910),(310,1280),(760,1270)],[285,765,285,765],.618)
add('cast','cast_v1',[(280,140),(765,140),(285,535),(770,535),(280,900),(770,900),(280,1290),(765,1290)],[280,765,280,765,280,765,280,765],.635)
add('death','death_v1',[(275,200),(765,275),(265,625),(800,655),(250,1030),(790,1055),(235,1370),(800,1380)],[270,765,270,765,270,765,270,765],.562,extras={3:[(575,790)],4:[(45,1095)]})
# Near contact/support/passing from first master followed by far reach/contact/support/passing,
# then near reach. Far-leg correction is a separate unwarped original sheet.
add('move','move_v1',[(300,915),(770,915),(275,535)],[280,765,280],.592)
add('move','move_far_v1',[(345,200),(975,200),(340,815),(975,815)],[350,975,350,975],.389)
add('move','move_v1',[(775,1310)],[765],.592)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':120,'hit':115,'defend':130,'cast':130,'death':155,'move':115}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Reviewed all 48 paintings at Godot 128px reference height: stocky iron/brass proportions match the existing 214px source body; hammer nearhand and gauge shield fararm remain consistent. Opposite-leg correction supplies reciprocal planted/reach/passing poses. Full-arm hammer strike and recovery, shield brace, physical support salute, and grounded collapse remain readable. Original source crops and fixed scale per master only; all seven masters and unused first-walk proposals retained.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
