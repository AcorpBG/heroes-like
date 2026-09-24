"""Register Knotroot Trapper original articulated hook and rope animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 231px hood-to-sole ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
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


add('idle','idle_v1',[(245,150),(740,150),(245,540),(740,540),(245,930),(740,930),(245,1310),(740,1310)],[260,755,260,755,260,755,260,755],.655)
add('attack','attack_v1',[(245,150),(710,150),(245,510),(690,550),(250,900),(700,900),(250,1300),(730,1300)],[260,720,245,700,255,710,255,745],.655)
add('hit','reactions_v1',[(230,160),(260,590),(260,930),(245,1320)],[245,260,265,250],.607)
add('defend','reactions_v1',[(760,160),(760,550),(770,970),(770,1320)],[770,770,770,770],.607)
add('cast','cast_v1',[(245,150),(720,150),(245,520),(720,520),(245,940),(720,940),(245,1310),(720,1310)],[260,735,260,735,260,735,260,735],.650)
add('death','death_v1',[(210,220),(750,270),(250,700),(750,750),(300,1100),(810,1110),(300,1390),(810,1390)],[235,740,235,740,235,740,235,740],.583)
# Corrected foreground leg contact and support; original draft repeats the
# far leg in the corresponding poses. Same original pixels, no mirroring.
add('move','move_near_v1',[(1110,300),(1810,300)],[1080,1800],.349)
add('move','move_v1',[(750,530),(750,1300),(260,930),(750,930),(260,1300)],[755,755,260,755,260],.655)
add('move','move_near_v1',[(370,300)],[330],.349)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':120,'hit':115,'defend':130,'cast':130,'death':150,'move':115}[name])
entry['clips']['attack']['contact_frame']=3
entry['clips']['cast']['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='48 distinct original poses across seven actions and seven original masters reviewed in the actual Godot 128px overview. Rope-adjusting idle, far-hand hook thrust with recovery, articulated recoil and coil guard, physical rally, grounded collapse with flat noose and corrected alternating foreground/background gait retain hood, mantle, brooch, pouch and tools. Corrected foreground step paintings replace repeated far-leg drafts; unused original poses preserved. No within-clip duplicates or whole-body warping. One fixed anatomical scale per master; original pixel cropping, transparent padding and downsampling only.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
