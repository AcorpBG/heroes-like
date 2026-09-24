"""Register Rotchoir Cantor original articulated staff and censer animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 232px crown-to-sole ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
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


add('idle','idle_v1',[(330,180),(755,180),(330,550),(755,550),(330,950),(755,950),(330,1320),(755,1320)],[330,755,330,755,330,755,330,755],.644)
add('attack','attack_v1',[(320,170),(770,190),(290,570),(745,580),(300,970),(770,970),(320,1300),(770,1300)],[320,755,320,755,320,755,320,755],.645)
add('ranged','ranged_v1',[(290,180),(735,180),(285,550),(735,550),(300,930),(735,930),(290,1310),(735,1310)],[300,740,300,740,300,740,300,740],.640)
add('hit','reactions_v1',[(315,180),(330,560),(330,940),(320,1320)],[315,325,325,315],.636)
# First draw the cross-body ready guard, then lower into the planted brace.
add('defend','reactions_v1',[(775,190),(800,1320),(780,570),(810,970)],[785,795,785,800],.636)
add('cast','cast_v1',[(330,180),(765,180),(330,560),(765,560),(330,930),(765,930),(330,1320),(765,1320)],[330,765,330,765,330,765,330,765],.648)
# Anatomical contact points rather than dangling foreground bells or staff
# tips keep the kneeling/fallen body grounded while loose props settle.
add('death','death_v1',[(300,220),(775,260),(310,700),(785,760),(300,1090),(790,1100),(280,1380),(790,1380)],[295,775,295,775,295,775,295,775],.568,floors=[444,456,850,842,1161,1157,1428,1430])
# First near-step correction clipped the lantern. Repainted 2x2 originals
# retain the complete props and show foreground contact/support/passing.
add('move','move_near_v2',[(1200,220),(440,750),(1200,750)],[1200,440,1200],.502)
add('move','move_v1',[(755,550),(330,940),(755,940),(330,1320)],[755,330,755,330],.647,floors=[737,1103,1111,1484])
add('move','move_near_v2',[(440,220)],[440],.502)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':120,'ranged':120,'hit':115,'defend':130,'cast':135,'death':150,'move':115}[name])
entry['clips']['attack']['contact_frame']=3
for name in ('ranged','cast'):entry['clips'][name]['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='56 distinct original poses across eight actions reviewed in the actual Godot 128px overview. Visible lantern-arm idle, physical crook strike, aimed censer release, raised-lantern support chant, recoil, planted guard, grounded collapse and corrected alternating gait retain mushroom mantle, bone crown, staff grip and lantern chains. Nine masters retained including rejected cropped gait source; roomy complete foreground steps replace repeated far-leg drafts. Attack windup top edge contains only alpha 9-10 fringe pixels, with solid crook intact; fallen props remain fully inside canvas. One anatomical scale per master and explicit kneeling/fallen/step contact anchors; original pixels cropped/padded/downsampled only. No duplicated frames or whole-body warping.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
