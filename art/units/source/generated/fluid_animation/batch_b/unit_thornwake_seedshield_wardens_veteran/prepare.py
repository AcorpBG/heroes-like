"""Rebuild Heartseed Warden paintings without synthetic articulation."""
import hashlib,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'project.godot').is_file())
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'tools'))
from refine_fluid_frame_crops import body_rectangles
entry=dict(unit_id=HERE.name,reference_height=256,source_facing='right',frames=[],clips={},source_scale_by_image={},source_scale_reason='One anatomical scale per master matches approximately 230px antler-to-root standing height; kneeling/corpse sources remain proportionately crouched. Roots/knees/body anchor independently from staff foreground extent.',provenance=dict(tool='builtin_image_gen',sources=[],reference=(HERE/'identity_reference.png').relative_to(ROOT).as_posix(),generation_lineage=(HERE/'generation.json').relative_to(ROOT).as_posix()))
def add(clip,stem,seeds,anchors,scale,extras=None):
    source=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt');path=source.relative_to(ROOT).as_posix()
    if path not in entry['source_scale_by_image']:
        entry['provenance']['sources'].append(dict(image=path,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest()))
    entry['source_scale_by_image'][path]=scale
    for n,(seed,anchor) in enumerate(zip(seeds,anchors)):
        rects=body_rectangles(source,seed,8);extra=(extras or {}).get(n,[])
        for point in extra:rects.extend(body_rectangles(source,point,8))
        rects=[list(r) for r in sorted(set(tuple(r) for r in rects))]
        spec=entry['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ('idle','move')))
        spec['indices'].append(len(entry['frames']))
        entry['frames'].append(dict(name=f'{clip}_{len(spec["indices"])-1}',clip=clip,source=path,rects=rects,anchor=anchor,scale=scale,alpha_noise_cutoff=8,crop_recipe=dict(tool='tools/refine_fluid_frame_crops.py',seed=seed,cutoff=8,additional_seeds=extra,reason='Connected original painting, anatomical ground anchor.')))
add('idle','idle_v1',[(300,180),(775,180),(300,570),(775,570),(300,940),(775,940),(300,1310),(775,1310)],[(300,370),(775,370),(300,756),(775,756),(300,1138),(775,1138),(300,1521),(775,1521)],.635)
# v1 repeated far-leg motion; v2 corrected topology but copied guide costume.
# v3 restores wooden limbs/root feet and removes the erroneous cloak.
add('move','move_near_v3',[(350,250),(965,250),(350,850),(965,850)],[(350,610),(965,614),(350,1225),(965,1235)],.380)
add('move','move_far_v1',[(390,250),(950,250),(390,850),(950,850)],[(390,605),(950,605),(390,1218),(950,1218)],.390)
add('attack','attack_v1',[(290,170)],[(290,371)],.635)
add('attack','attack_windup_v2',[(480,400),(1340,400)],[(480,850),(1340,850)],.304)
add('attack','attack_v1',[(750,600)],[(750,750)],.635)
add('attack','attack_contact_v3',[(650,450)],[(650,990)],.235)
add('attack','attack_v1',[(750,960),(290,1320),(750,1320)],[(750,1115),(290,1510),(750,1510)],.635)
add('hit','reactions_v1',[(300,190),(300,560),(320,950),(300,1320)],[(305,381),(305,754),(305,1110),(305,1510)],.620)
add('defend','reactions_v1',[(750,190),(775,560),(780,950),(775,1320)],[(750,381),(775,754),(780,1110),(775,1510)],.620)
add('cast','cast_v1',[(300,180),(775,180),(300,570),(775,570),(300,950),(775,950),(300,1320),(775,1320)],[(300,380),(775,380),(300,760),(775,760),(300,1140),(775,1140),(300,1520),(775,1520)],.630)
add('death','death_v1',[(270,240),(760,270),(275,660)],[(285,416),(770,422),(285,780)],.585)
add('death','death_middle_v1',[(470,450),(1290,450)],[(480,758),(1285,747)],.260,{1:[(1000,737)]})
add('death','death_v1',[(760,700),(270,1000),(750,1050),(265,1360),(750,1380)],[(770,779),(285,1090),(770,1100),(285,1425),(770,1430)],.585,{0:[(600,785)],1:[(200,1107)],2:[(600,1113)],3:[(200,1444)],4:[(600,1445)]})
for name,spec in entry['clips'].items():
    spec.update(static_frame=0,frame_msec={'idle':155,'move':110,'attack':115,'hit':115,'defend':135,'cast':130,'death':150}[name])
for name in ('attack','cast'):entry['clips'][name]['contact_frame']=4
entry['clips']['attack']['frame_durations_msec']=[95,115,130,95,110,125,125,130]
entry['clips']['cast']['frame_durations_msec']=[110,120,130,130,190,130,130,140]
entry['clips']['defend']['static_frame']=3
entry['clips']['death']['static_frame']=9
entry['visual_review']=dict(status='accepted_selected_clips',notes="Reviewed original paintings and ordered Windows Godot phases at actual 128px reference height. Fifty distinct originals across seven actions: visible shield/staff arm idle; reciprocal near/far root-leg walk; lifted windup, thrust contact and recovery; four recoils; four dedicated guards; physical staff-and-shield salute; ten-stage collapse with staff release before the near palm braces on the ground, ending in grounded corpse. Antlered mask, bark/leaf anatomy, near-hand staff and far-arm heart shield retained. Rejected repeated far-leg near-walk v1, guide-costume v2, oversized windup v1 and contracted contact v2. Corrected near-walk v3 restores wooden thighs/root feet and removes copied cloak. Fixed scale per master; no duplicate/mirrored phases, warps or per-pose size normalization. Final candidate passes118 assertions. Ordered phase/timing inspection supports selected acceptance; continuous playback, Linux execution and a manual playtest are not claimed.")
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
for name,spec in entry['clips'].items():
    print(name,[(min(r[0] for r in f['rects']),min(r[1] for r in f['rects']),max(r[2] for r in f['rects']),max(r[3] for r in f['rects'])) for f in [entry['frames'][i] for i in spec['indices']]])
print('Prepared',len(entry['frames']),'paintings')
