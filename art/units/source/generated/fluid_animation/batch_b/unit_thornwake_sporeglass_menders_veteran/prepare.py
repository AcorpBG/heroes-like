"""Rebuild Dewglass Restorer animations from original, reviewed paintings."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'project.godot').is_file())
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles

entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},
    source_scale_reason='Fixed scale per original master preserves approximately 193px human anatomy plus the approximately 230px total canopy-to-sole silhouette of the existing 256px reference. No per-pose height normalization: crouched and fallen poses retain source standing scale. Anatomical foot/body contacts anchor independently from nozzle/hose extents.',
    provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'identity_reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))

def add(clip,stem,seeds,anchors,scale,extras=None):
    source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt');path=source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path]=scale
    for n,(seed,anchor) in enumerate(zip(seeds,anchors)):
        rects=body_rectangles(source,seed,8)
        extra=(extras or {}).get(n,[])
        for point in extra:rects.extend(body_rectangles(source,point,8))
        rects=[list(r) for r in sorted(set(tuple(r) for r in rects))]
        spec=entry['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ('idle','move')))
        spec['indices'].append(len(entry['frames']))
        entry['frames'].append(dict(name=f'{clip}_{len(spec["indices"])-1}',clip=clip,source=path,rects=rects,anchor=anchor,scale=scale,alpha_noise_cutoff=8,
            crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8,additional_seeds=extra,reason='Connected original painted pixels with anatomical ground/body anchor.')))

# idle_v1 clips top canopies and final boots; no frames from it are used.
add('idle','idle_v2',[(300,170),(775,170),(300,540),(775,540),(300,920),(775,920),(300,1310),(775,1310)],
    [(300,370),(775,370),(300,745),(775,745),(300,1128),(775,1128),(300,1504),(775,1504)],.648)
# Near v1 hid the hip crossing; v2 exposed it but copied the motion guide's
# ivory greaves. v3 retains the corrected gait with original leaf/bark armor.
add('move','move_near_v3',[(370,220),(1020,220),(370,820),(1020,820)],
    [(370,578),(1020,578),(370,1171),(1020,1175)],.405)
add('move','move_far_v1',[(375,240),(1010,240),(375,850),(1010,850)],
    [(380,588),(1010,588),(380,1205),(1010,1205)],.405)
add('attack','attack_v1',[(295,190),(770,225),(290,565),(770,565),(290,950),(770,950),(290,1310),(770,1310)],
    [(295,383),(770,383),(290,761),(770,761),(290,1137),(770,1137),(290,1520),(770,1520)],.626)
add('ranged','ranged_v1',[(295,180),(775,180),(290,570),(775,570),(290,940),(775,940),(290,1310),(775,1310)],
    [(295,375),(775,375),(290,762),(775,762),(290,1140),(775,1140),(290,1524),(775,1524)],.634)
add('hit','reactions_v1',[(300,220),(310,600),(325,1010),(335,1340)],
    [(305,401),(310,793),(325,1140),(335,1517)],.605)
add('defend','reactions_v1',[(750,210),(760,600),(770,1000),(760,1340)],
    [(750,399),(760,789),(770,1140),(760,1517)],.605)
add('cast','cast_v1',[(300,180),(770,180),(300,570),(770,570),(300,945),(775,945),(300,1310),(775,1310)],
    [(300,379),(770,379),(300,760),(770,760),(300,1144),(775,1144),(300,1524),(775,1524)],.632)
add('death','death_v1',[(270,240),(760,260),(270,720),(760,735),(260,1110),(760,1110),(260,1400),(760,1400)],
    [(285,438),(770,438),(285,835),(770,833),(285,1180),(770,1178),(285,1450),(770,1455)],.555)
for name,spec in entry['clips'].items():
    spec.update(static_frame=0,frame_msec={'idle':155,'move':110,'attack':115,'ranged':120,'hit':115,'defend':135,'cast':130,'death':150}[name])
for name in ('attack','ranged','cast'):entry['clips'][name]['contact_frame']=4
entry['clips']['attack']['frame_durations_msec']=[95,115,130,95,110,125,125,130]
entry['clips']['ranged']['frame_durations_msec']=[100,120,130,160,115,125,130,130]
entry['clips']['cast']['frame_durations_msec']=[110,120,130,130,190,130,130,140]
entry['clips']['defend']['static_frame']=3
entry['clips']['death']['static_frame']=7
entry['visual_review']=dict(status='accepted_selected_clips',notes='Reviewed original paintings and ordered Windows Godot phases at actual 128px reference height. Fifty-six distinct originals across eight actions: arm/nozzle equipment-check idle; reciprocal near/far walk; two-handed melee shove; aimed medicinal ranged release with brief muzzle mist; four recoils; four dedicated guards; empty near-hand physical rally signal while far hand supports sprayer; eight-stage collapse ending grounded with attached pack and tethered nozzle. Canopy, flask, hose and original leaf/bark armor are retained. Excluded clipped idle_v1 and ambiguous near-walk v1. Near-walk v2 supplies motion reference only because it copied ivory greaves; v3 corrects costume while retaining exposed foreground thigh rooted below side pouch and apron swept behind it. Far half has opposite thigh from below centered apron. One fixed anatomical scale per master, no duplicates, mirrored phases, warping or per-pose height normalization. Native final candidate passes132 assertions. Ordered phase/timing inspection supports acceptance; continuous playback, Linux execution and a manual playtest are not claimed.')
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
for name,spec in entry['clips'].items():
    print(name,[(min(r[0] for r in f['rects']),min(r[1] for r in f['rects']),max(r[2] for r in f['rects']),max(r[3] for r in f['rects'])) for f in [entry['frames'][i] for i in spec['indices']]])
print('Prepared',len(entry['frames']),'paintings across',len(entry['clips']),'actions')
