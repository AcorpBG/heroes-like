"""Correct the physical extension source, never skip its connected defect."""
import json
import numpy as np
from PIL import Image
import produce as p
from prepare import reference

if __name__=='__main__':
 a=p.SOURCE_DIR/'attack_h3_v2'
 for name in ['selection.json','handoff.json']:
  f=a/name
  if f.exists():f.rename(a/('rejected_effect_gap_'+name))
 r=json.loads((a/'full_take_rejection_initial.json').read_bytes());r['note']+=' Source42 connected white effect interrupts41->43 physical contact. The proposed26-frame selection is rejected; preserve it as rejected evidence, never publish that contact gap.';p.write(a/'rejection.json',r)
 d=p.SOURCE_DIR/'attack_h3_v4'
 if d.exists():assert not (d/'sampling_submission.json').exists() and not (d/'original.latent').exists()
 d.mkdir(exist_ok=True)
 prompt=('The original painted Whitegauge armored adult from the supplied images. Same enclosed ivory gauge helmet with red calibration marks, brass side fitting and red tassel, charcoal split coat with red lining, ivory shoulder and shin plates, round brass knees, black gloves and boots, hanging brass weights, rear brass tank and red hoses. Exactly two human arms and legs. The right near hand holds the middle of one complete long rigid calibrated pole, with original ivory tapered head, round brass gauge beneath it, black sleeves, ivory bands, brass couplers and pointed brass butt. Left far forearm carries the original small round ivory shield with brass rim and boss. Fixed three-quarter camera facing screen right, same body proportions and materials. The entire pole begins horizontal across the right shoulder as shown. One quiet continuous physical right-arm extension and retraction. Right elbow gradually straightens, moving the same hand and whole rigid horizontal pole forward along its long axis, with a grounded weight shift and bent forward knee, until the original extended-arm painting at frame62. Then right elbow bends and the same hand and entire horizontal pole slide back along exactly the same axis into the original shoulder position. Left elbow and small shield remain at chest; both boots stay planted in the same support locations as weight transfers forward and back. The pole remains a single unchanged straight physical object. Natural coat folds, weights and hoses follow the torso; complete hands, head, feet and both ends of the pole stay visible. Plain solid magenta backdrop identical to reference in every frame. Fixed root x480 and boot ground y576. Only the quiet physical arm, leg and cloth movement of this original character, smoothly moving between the three original poses. ')
 prompt=prompt.replace('The entire pole begins horizontal across the right shoulder as shown.','The entire pole begins upright in the right hand as shown. Right shoulder and elbow smoothly pivot the whole straight pole down into horizontal position above the shoulder.').replace('Then right elbow bends and the same hand and entire horizontal pole slide back along exactly the same axis into the original shoulder position.','Then right elbow bends and the same hand and entire horizontal pole slide back along exactly the same axis into the shoulder position. Smoothly pivot the whole straight pole back upright and recover the original balanced ready posture at the end.')
 c=dict(unit_id='unit_brasshollow_whitegauge_datum_lancers',clip='attack',canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=2026110432,references=[reference(14),reference(7)],guides=[[62,1]],last=0,prompt=prompt.strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.write(d/'config.json',c);p.prepare(d,c);p.verify(d,c)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes'][1]='attack_h3_v4';delivery['failed_takes']=['move_h3_v1','attack_h3_v1','move_h3_v2','attack_h3_v2','move_h3_v3','attack_h3_v3'];p.write(p.SOURCE_DIR/'delivery.json',delivery)
 records=[]
 for folder in sorted(p.SOURCE_DIR.glob('*_h3_v*')):
  for f in sorted(folder.glob('guide_*_rgba.png')):
   a=np.asarray(Image.open(f).convert('RGBA')).astype('int16');solid=a[:,:,3]>=250;v=int((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[solid].max());assert v<=24
   records.append(dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f),opaque_magenta_chroma_max=v,opaque_pixels=int(solid.sum())))
 p.write(p.SOURCE_DIR/'foreground_measurement.json',dict(unit_id=c['unit_id'],measured_guides=len(records),opaque_magenta_chroma_max=max(r['opaque_magenta_chroma_max'] for r in records),unchanged_protected_band=24,records=records,rule='Quiet physical arm/shoulder description, matched original ready endpoints, one full-arm extension midpoint. Model and matte settings unchanged.'))
 print('QUIET_FULL_PHYSICAL_ARM_SOURCE_PREPARED',len(records),flush=True)
