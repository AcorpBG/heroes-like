"""Register Mireglass Dissonant original articulated staff animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 232px reed-crest-to-sole ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
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

add('idle','idle_v1',[(330,175),(690,175),(330,550),(690,550),(330,940),(690,940),(330,1320),(690,1320)],[335,695,335,695,335,695,335,695],.642)
add('attack','attack_v1',[(270,180),(740,200),(260,570),(760,610),(270,960),(765,960),(265,1330)],[285,740,270,740,260,740,280],.664)
# Restore a correctly held staff; the final attack draft let the hand float.
add('attack','idle_v1',[(690,1320)],[695],.642)
add('ranged','ranged_v1',[(290,180),(750,180),(290,560),(750,570),(290,960),(750,960),(290,1320),(750,1320)],[315,750,310,745,310,745,310,745],.637)
add('hit','reactions_v1',[(290,190),(270,580),(270,960),(270,1350)],[300,280,280,280],.610)
add('defend','reactions_v1',[(750,210),(750,590),(750,990),(750,1360)],[765,765,765,765],.610)
# A low-alpha bridge between the raised staff and preceding foot separates
# at cutoff 16; original opaque artwork remains isolated without repainting.
add('cast','cast_v1',[(290,180),(750,180),(290,560),(750,560),(285,980),(750,950),(290,1340),(750,1340)],[310,750,310,750,310,750,310,750],.642,cutoff=16)
# Share an original held-staff ready pose as collapse entry. No duplicate
# frames occur within a clip. Replace final draft with grounded chime art.
add('death','idle_v1',[(330,175)],[335],.642)
add('death','death_v1',[(750,250),(265,680),(750,760)],[750,280,750],.548)
add('death','death_ground_v1',[(270,350),(1130,370),(350,780),(1130,780)],[380,1140,380,1140],.345)
add('move','move_v1',[(290,175),(750,175),(290,560),(750,560),(290,940),(750,940),(290,1320),(750,1320)],[310,755,310,755,310,755,310,755],.637)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':155,'attack':120,'ranged':120,'hit':115,'defend':130,'cast':135,'death':150,'move':115}[name])
for name in ('attack','ranged','cast'):entry['clips'][name]['contact_frame']=4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='All 56 frame entries reviewed in the Godot 128px overview: 54 distinct paintings across eight original masters. Articulated free-hand idle, two-handed staff thrust, aimed ranged release, recoil/brace, raised-hand support incantation, alternating gait and grounded collapse preserve reed hood, split coat, belt lens and three-lens staff. Attack recovery and death entry reuse valid held-staff ready originals across clips only; no duplicates within any clip. Grounded final collapse replaces vertically hanging chimes, and rejected source poses remain preserved. Casting alpha cutoff 16 removes only a faint inter-pose bridge. One fixed anatomical scale per master, planted-foot registration, original-pixel cropping/padding/downsampling only.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
