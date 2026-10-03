"""Use the unambiguous foreground near knee instead of ambiguous contact art."""
import json
import numpy as np
from PIL import Image
import produce as p
from prepare import IDENTITY,reference
from prepare_corrections import new_reference

if __name__=='__main__':
 for take,note in {
  'move_h3_v3':'Full124 RGB/RGBA chronology and12 original-size matched details inspected. Continuous walking is smoother, but the old far-contact and new near-contact paintings both show the screen-right boot leading with no unambiguous near thigh ownership; source12/18/30/44/56/62 confirms the same leading boot repeats. The contact-painting control itself is insufficient. Background cycles through colors, and associated source material tint varies. Reassess to one explicit raised near-knee painting, with far foot planted, and retain magenta endpoints.',
  'attack_h3_v3':'Full124 RGB/RGBA chronology and16 original-size matched details inspected. Source56-60 adds connected white/green lance effects and74-78 adds connected butt flash, while background cycles and tints foreground. Semantic extraction removes some effects but that is not acceptance. Reject take and preserve original effects. Earlier v2 clean physical motion intervals are separately reassessed with defective42 excluded, without repainting or masking any source subject pixels.'
 }.items():
  d=p.SOURCE_DIR/take;p.write(d/'rejection.json',dict(status='rejected_full_take',personal_rgb_frames=124,personal_rgba_frames=124,note=note,original_sha256=p.sha(d/'original_lossless.mkv'),latent_sha256=p.sha(d/'original.latent'),matte_sha256=p.sha(d/'matte.json'),segmentation_tool_sha256=p.sha(p.SOURCE_DIR/'segment.py'),rule='All original pixels/latents/videos/prompts/guides and exact failed matte recipes retained. No connected effect masking or synthetic motion.'))
 d=p.SOURCE_DIR/'move_h3_v4';d.mkdir(exist_ok=False)
 refs=[reference(2),new_reference('move_near_passing_v1',[630,1400],.14)]
 action=('One smooth natural reciprocal marching cycle in place. The first and last far-leg contact paintings match. Begin with FAR LEFT shield-side leg forward and NEAR RIGHT lance-side leg back. The NEAR RIGHT lance-side thigh swings forward in the foreground, lifting its round knee at SCREEN LEFT and its boot forward across the planted far leg, matching the supplied raised near-knee painting in the middle. This marked foreground near knee is the lead, with the FAR LEFT shield-side leg planted straight at SCREEN RIGHT. Continue the NEAR RIGHT foot forward and plant it in front, transferring body weight to it. Then FAR LEFT leg swings forward while the near leg supports the body, returning to the original far-leg contact. Both hips, knees and ankles bend continuously, with two opposed leading steps and natural loading and passing. Whole original upright lance stays in RIGHT hand, shield stays in LEFT arm, and coat and weights follow the march. Anatomical contact plane y576, root x480. Plain solid magenta chroma-key backdrop stays exactly as reference in every frame. Fixed original tactical camera, body proportions and original equipment materials, entire creature and full pole inside canvas. ')
 c=dict(unit_id='unit_brasshollow_whitegauge_datum_lancers',clip='move',canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=2026110431,references=refs,guides=[[62,1]],last=0,prompt=(IDENTITY+action).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.write(d/'config.json',c);p.prepare(d,c);p.verify(d,c)
 indices=[11,*range(12,19),39,40,41,43,44,68,69,70,71,72,73,101,102,103,104,105,106,107]
 a=p.SOURCE_DIR/'attack_h3_v2'
 p.write(a/'selection.json',dict(source_frames=indices,frame_msec=45,contact_frame=indices.index(43),review_note='All124 original RGB/RGBA frames and28 matched original-size details personally inspected. Select clean observed physical ready pivot, windup, axial thrust/contact, axial recovery and ready return. Omit source42 entirely because of its connected white tip extension; clean41->43 spans two original frames and will require native/action review of that contact. Long near-static guide holds are thinned to representative unique observed frames; moving transition frames retained densely at45ms, deliberate action retiming. Diagonal transition has original whole-pole directional blur rather than missing equipment. No duplicated/reversed/interpolated motion, no masked effect or shaft repair. Native acceptance remains pending.'))
 previous=json.loads((a/'rejection.json').read_bytes());p.write(a/'full_take_rejection_initial.json',previous);previous.update(status='reassessed_selected_intervals_pending_native',note=previous['note']+' Later reassessment retains only clean unique original intervals with connected effect42 excluded entirely and densely sampled natural moving transitions; original whole-take rejection and all source failures retained. Native continuity remains pending.');p.write(a/'rejection.json',previous)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes'][0:2]=['move_h3_v4','attack_h3_v2'];delivery['failed_takes']=['move_h3_v1','attack_h3_v1','move_h3_v2','move_h3_v3','attack_h3_v3'];p.write(p.SOURCE_DIR/'delivery.json',delivery)
 records=[]
 for folder in sorted(p.SOURCE_DIR.glob('*_h3_v*')):
  for f in sorted(folder.glob('guide_*_rgba.png')):
   a=np.asarray(Image.open(f).convert('RGBA')).astype('int16');solid=a[:,:,3]>=250;v=int((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[solid].max());assert v<=24
   records.append(dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f),opaque_magenta_chroma_max=v,opaque_pixels=int(solid.sum())))
 p.write(p.SOURCE_DIR/'foreground_measurement.json',dict(unit_id=c['unit_id'],measured_guides=len(records),opaque_magenta_chroma_max=max(r['opaque_magenta_chroma_max'] for r in records),unchanged_protected_band=24,records=records,rule='Original raised foreground near knee replaces ambiguous contact control; fixed model and matte settings.'))
 print('PREPARED_UNAMBIGUOUS_NEAR_PASSING_CONTROL',len(records),len(indices),flush=True)
