"""Select reviewed source phases; build pending full candidate on CPU."""
import json,copy
import produce as p
from integrate_fluid_creature_animation import pack_unit
uid='unit_veilmourn_saltwake_eulogists'
selection=dict(source_frames=[0,4,6,10,14,18,20]+list(range(22,51,2))+list(range(54,83,4))+list(range(86,115,2))+[118,123],frame_msec=42,review_note='All124 original RGB, original semantic alpha and corrected RGBA reviewed chronologically. Enlarged6/22/34/46/60/76/100 retain one straight bronze staff, three glass cylinders, single hanging lantern, two arms and legs. Original far palm lifts continuously22-50, fingers inward, head and torso bow60-82, genuine return86-123. Measured cyan recovery stays within original soft semantic enclosed silhouette; every outside alpha byte exact. Native/mirror review pending.')
p.write(p.SOURCE_DIR/'cast_h3_v1/selection.json',selection)
delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes']=[t.replace('cast_h3_v2','cast_h3_v1') for t in delivery['takes']];p.write(p.SOURCE_DIR/'delivery.json',delivery)
rejected=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes())
for take in rejected['takes']:
 if take['take']=='cast_h3_v1':take['status']='original_motion_retained_corrected_extraction_candidate';take['correction']='Two-take reassessment proves first original motion continuous. Cyan matte recovery derives original RGB opacity on G-R axis protected original palette120, only inside enclosed semantic alpha>=8; preserve initial failed extraction recipes and all semantic masks. Native review pending.'
if not any(t['take']=='cast_h3_v2' for t in rejected['takes']):rejected['takes'].append(dict(take='cast_h3_v2',status='rejected',defect='Original RGB hand jumps from down to face in21→22 and abruptly back in75→76; two held body states do not qualify as fluid gesture.',correction='Reassess genuine first source motion and measured cyan plate extraction; no blind third sampler.'))
p.write(p.SOURCE_DIR/'rejected_takes.json',rejected)
for take in delivery['takes']:p.build(p.SOURCE_DIR/take,json.loads((p.SOURCE_DIR/take/'config.json').read_bytes()))
p.assemble();entry=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0];rows=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())['items'];previous=next(r for r in rows if r['unit_id']==uid)
target=p.ROOT/'.artifacts/parallel_animation_20261002'/uid/'cpu_packing';target.mkdir(parents=True,exist_ok=True)
patch=pack_unit(entry,copy.deepcopy(previous),target);p.write(target/'patch.json',patch)
print('FULL_PENDING_CANDIDATE',len(entry['frames']),'new frames', {k:len(v['indices']) for k,v in entry['clips'].items()},flush=True)
