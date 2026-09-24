"""Register Orchardheart Matriarch original four-armed tree animations."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='One fixed anatomical scale per original source matches the existing approximately 231px canopy-to-root ready silhouette and torso size. Planted feet provide registration; no per-pose resizing or deformation.',
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

# Order the intermediate hand lift before the higher cradle pose.
add('idle','idle_v1',[(320,190),(315,550),(770,190),(770,550),(320,950),(770,950),(320,1330),(770,1330)],[310,310,770,770,310,770,310,770],.670)
add('attack','attack_v1',[(310,180),(810,200),(310,570),(810,570),(310,950),(810,950),(310,1330),(810,1330)],[310,800,310,810,310,800,310,800],.650)
# ranged_v1 lost arms. Exclude v2's abrupt upright bow pose too: enter from
# a relaxed original ready painting, then raise the drawing arm into action.
add('ranged','idle_v1',[(320,190)],[310],.670)
add('ranged','ranged_v2',[(315,180),(310,550),(780,550),(310,920),(780,920),(310,1300),(780,1300)],[310,310,780,310,780,310,780],.658)
# Keep the pipeline's edge-preserving cutoff. The two bottom poses share a
# faint bridge; split its original pixels at their reviewed row boundary.
add('hit','reactions_v1',[(270,190),(270,560),(285,960),(300,1330)],[285,275,290,295],.642,cutoff=16)
for hit_number,low,high in [(2,754,1128),(3,1128,1536)]:
    f=entry['frames'][entry['clips']['hit']['indices'][hit_number]]
    f['rects']=[[x0,max(y0,low),x1,min(y1,high)] for x0,y0,x1,y1 in f['rects'] if max(y0,low)<min(y1,high)]
    f['anchor'][1]=max(q[3] for q in f['rects'])
    f['crop_recipe']['vertical_clip']=[low,high]
# Progress from ready through the half brace to the crossed upper-arm guard.
add('defend','reactions_v1',[(810,200),(810,1350),(800,570),(800,970)],[810,810,805,805],.642)
add('cast','cast_v1',[(300,190),(780,190),(300,570),(780,570),(300,960),(780,960),(300,1340),(780,1340)],[300,780,300,780,300,780,300,780],.658)
# Preserve the separate fallen bow. Ground anchors use body/root contact,
# rather than pulling the body upward because its bow lies in foreground.
add('death','death_v1',[(265,250),(805,300),(300,700),(825,730),(300,1060),(820,1060),(300,1370),(820,1400)],[265,805,280,790,270,790,270,790],.525,floors=[448,450,838,820,1115,1120,1460,1460],extras={4:[(335,1140)],5:[(815,1140)],6:[(300,1480)],7:[(810,1480)]})
# v1 foreground correction lost arms/bow; v2 elongated legs. Only v3 is used.
add('move','move_near_v3',[(1130,250),(535,730),(1130,730)],[1130,535,1130],.465)
add('move','move_v1',[(795,560),(300,930),(795,930),(300,1320)],[790,295,790,295],.658)
add('move','move_near_v3',[(535,250)],[535],.465)
for name,clip in entry['clips'].items():
    clip.update(static_frame=0,frame_msec={'idle':160,'attack':125,'ranged':125,'hit':120,'defend':130,'cast':135,'death':155,'move':125}[name])
for name in ('attack','ranged','cast'):entry['clips'][name]['contact_frame']=3 if name=='attack' else 4
entry['clips']['defend']['static_frame']=3
entry['visual_review']=dict(status='accepted',notes='Native Godot 128px review: articulated four-armed idle, upper branch-arm swat, lower-braced living-bow draw/release using the free upper hand, recoil, crossed upper-arm guard, raised seed-pod healing gesture, reciprocal root-fan steps and grounded canopy collapse. 56 entries/55 distinct paintings from eight selected masters; eleven originals retained. Two-armed ranged draft, simplified walking equipment draft and overlong root legs are excluded. A ready idle painting replaces the abrupt upright-bow entry across clips only. No duplicate frames within clips or whole-sprite warping. One fixed anatomical scale per master. Faint joined hit alpha is separated at cutoff16 and the reviewed row boundary1128 without removing opaque artwork; fallen bows remain separately captured below body ground anchors.')
(HERE/'handoff.json').write_bytes((json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n').encode('utf-8'))
for name,clip in entry['clips'].items():
    print(name,[(min(x[0] for x in f['rects']),min(x[1] for x in f['rects']),max(x[2] for x in f['rects']),max(x[3] for x in f['rects'])) for f in [entry['frames'][i] for i in clip['indices']]])
print('Prepared',len(entry['frames']),'frames across',len(entry['clips']),'clips')
