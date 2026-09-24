"""Register Gorefen Packlord original reptilian quadruped animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 237px trophy-to-ground ready silhouette and shoulder dimensions. Planted paws provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(280,180),(790,180),(290,530),(810,530),(280,950),(790,940),(285,1330),(790,1320)],[295,805,295,805,295,805,295,805],.740)
add('attack','attack_v1',[(260,180),(765,220),(275,590),(770,590),(285,960),(795,950),(285,1300),(800,1310)],[280,785,280,785,280,785,280,785],.724)
# Left column is recoil/recovery; right column is progressive bracing.
add('hit','reactions_v1',[(340,140),(340,480),(340,800),(340,1110)],[355,355,355,355],.724)
add('defend','reactions_v1',[(965,160),(965,480),(965,810),(975,1130)],[965,965,965,965],.724)
add('cast','cast_v1',[(280,180),(790,180),(290,550),(800,530),(295,960),(800,960),(290,1320),(790,1320)],[290,800,290,800,290,800,290,800],.779)
add('death','death_v1',[(285,210),(790,250),(285,650),(790,690),(285,1050),(790,1070),(285,1410),(790,1410)],[290,800,290,800,290,800,290,800],.685)
# The first master repeated near-side lifts in its lower rows. Replace those
# with four dedicated far-hind/far-fore lift and plant original paintings.
add('move','move_v1',[(280,210),(790,210),(280,580),(790,580)],[290,800,290,800],.740)
add('move','move_far_v1',[(420,250),(1150,250),(420,750),(1150,750)],[425,1170,425,1170],.525)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':120,'hit':115,'defend':130,'cast':135,'death':155,'move':120}[name])
entry['clips']['attack']['contact_frame']=4
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='All 48 original poses reviewed in the Godot 128px overview. Seven masters preserve four-leg reptilian anatomy, long muzzle/tail, red mane, shoulder trophies and medallion. Articulated forepaw/neck idle, bite-lunge and recovery, recoil/bracing, rising physical roar and grounded collapse. Four-beat near-hind, near-fore, far-hind, far-fore gait uses dedicated far-side originals to replace repeated near-side lifts. Natural far-foreleg occlusion during the lunge is preserved. Reaction source has only a faint two-pixel antler-tip alpha edge, not a broad cut through the trophy. Planted paw registration and one anatomical scale per source; original-pixel cropping/padding/downsampling only, no per-pose deformation.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
