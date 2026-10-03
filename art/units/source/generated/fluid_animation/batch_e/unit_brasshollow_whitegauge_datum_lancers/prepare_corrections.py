"""Correct only documented gait/rigid-lance guide gaps; originals immutable."""
import json
from PIL import Image,ImageDraw
import numpy as np
import produce as p
from prepare import IDENTITY,PLATE,reference
UID='unit_brasshollow_whitegauge_datum_lancers'
MASTERS=[
('move_near_contact_v1','C:/Users/acorp/.codex/generated_images/01a0fd50-f23a-7d32-8303-80fafa7a2272/exec-a1fa5e5b-83c7-4345-8052-c4a3256093c9.png'),
('move_near_passing_v1','C:/Users/acorp/.codex/generated_images/01a0fd50-f23a-7d32-8303-80fafa7a2272/exec-24527c27-ae97-4ecf-adc3-796c922b55d1.png'),
('attack_diagonal_carry_v1','C:/Users/acorp/.codex/generated_images/01a0fd50-f23a-7d32-8303-80fafa7a2272/exec-ae559ffd-9c86-4a38-890a-2cd679c87d2a.png')]
def new_reference(name,anchor,scale):
 path=p.SOURCE_DIR/(name+'.png');im=Image.open(path)
 return dict(name=name,source=path.relative_to(p.ROOT).as_posix(),rects=[[0,0,im.width,im.height]],anchor=anchor,scale=scale,alpha_noise_cutoff=8)
def make(take,clip,refs,guides,action,seed):
 out=p.SOURCE_DIR/take;out.mkdir(exist_ok=False)
 c=dict(unit_id=UID,clip=clip,canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=seed,references=refs,guides=guides,last=0,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 target=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
 sheet=Image.new('RGB',(960,320*((len(refs)+1)//2)),(31,41,31));draw=ImageDraw.Draw(sheet)
 for i in range(len(refs)):
  im=Image.open(out/f'guide_{i}_rgba.png');im.thumbnail((480,300))
  x,y=(i%2)*480,(i//2)*320;sheet.paste(im,(x,y+20),im);draw.text((x+4,y+4),f'{take} original guide {i}',fill='white')
 sheet.save(target/(take+'_guides.png'));print('PREPARED_CORRECTION',take,flush=True)
if __name__=='__main__':
 curated=p.ROOT/'art/units/source/curated'/f'{UID}.png'
 for name,original in MASTERS:
  image=p.SOURCE_DIR/(name+'.png');prompt=p.SOURCE_DIR/(name+'.prompt.txt')
  assert p.sha(image)==p.sha(original)
  p.write(p.SOURCE_DIR/(name+'.generation.json'),dict(tool='builtin_imagegen',date='2026-10-03',original_tool_path=original,image=dict(path=image.relative_to(p.ROOT).as_posix(),sha256=p.sha(image)),prompt=dict(path=prompt.relative_to(p.ROOT).as_posix(),sha256=p.sha(prompt)),references=[dict(path=curated.relative_to(p.ROOT).as_posix(),sha256=p.sha(curated))],transparent_background_requested=True,review=dict(status='accepted_original_pose_guide',identity='One enclosed gauge-armored adult, full original lance, small round shield, tank/hoses/weights and original two-arm/two-leg anatomy.',note='Personally inspected original returned full-size pixels. Near contact has foreground right thigh crossing to forward boot; near passing raises lance-side knee with opposite shield-side foot planted; diagonal carry retains complete shaft and both grips. Fixed whole-painting scale and anatomical ground anchor only; no authored motion.')))
 rejected={
 'move_h3_v1':'All124 RGB and all124 RGBA frames plus14 enlarged matched RGB/RGBA details personally inspected. Original named walk_planted_bridge pose4 repeats the far/shield-side leading stance; H3 repeats that lead instead of a true opposed near/lance-side step. Reject entire take; supply original explicit near-leg contact and passing paintings.',
 'attack_h3_v1':'All124 RGB and all124 RGBA frames plus24 enlarged matched RGB/RGBA details personally inspected. Spear bends/smears during ready-to-horizontal at14-19, changes orientation and loses its butt during36-39, and lifts overhead again during66-71 recovery. Reject entire take; supply original complete diagonal carry and denser physical windup/contact guides.'}
 for take,note in rejected.items():
  out=p.SOURCE_DIR/take
  p.write(out/'rejection.json',dict(status='rejected_full_take',personal_rgb_frames=124,personal_rgba_frames=124,note=note,original_sha256=p.sha(out/'original_lossless.mkv'),latent_sha256=p.sha(out/'original.latent'),matte_sha256=p.sha(out/'matte.json'),segmentation_tool_sha256=p.sha(p.SOURCE_DIR/'segment.py'),rule='Preserve original art, videos, latents, guide/prompt/workflow and exact failed extraction provenance. No synthetic limb motion, reversal, frame duplication or geometry repair.'))
 near_pass=new_reference('move_near_passing_v1',[630,1400],.14)
 near_contact=new_reference('move_near_contact_v1',[650,1385],.15)
 diagonal=new_reference('attack_diagonal_carry_v1',[680,1155],.176)
 make('move_h3_v2','move',[reference(14),reference(2),reference(3),near_pass,near_contact],[[20,1],[40,2],[56,3],[77,4],[105,0]],
  'One genuine complete reciprocal walking cycle IN PLACE. First the FAR LEFT SHIELD-side leg steps forward to original contact around frame20 while NEAR RIGHT LANCE-side leg trails. Then transfer weight onto that shield-side foot. Around56 the NEAR RIGHT LANCE-side thigh and knee visibly rise in the foreground at SCREEN LEFT, its lower leg swings FORWARD across in front of the planted far leg. Around77 the NEAR RIGHT thigh continues diagonally in the foreground to its forward SCREEN RIGHT boot and round knee cap, while FAR LEFT shield-side leg extends backward SCREEN LEFT behind it. Follow the supplied opposite-leg paintings literally: two different legs must lead on the two half cycles. Continue naturally to balanced original ready around105 and at the end. Original two hips/knees/ankles articulate, coat and weights follow, no leg ownership swap or same-leg repeated hopping. RIGHT hand holds unchanged upright complete lance; LEFT arm holds shield beside chest. No root travel, thrust or firing. ',2026110411)
 make('attack_h3_v2','attack',[reference(14),diagonal,reference(6),reference(7)],[[14,1],[24,2],[34,2],[44,3],[57,3],[66,3],[77,2],[87,2],[103,1],[116,0]],
  'One physical lance thrust with a continuous rigid weapon and recover. Smoothly lower the original upright lance through the supplied complete diagonal carry at14 to horizontal shoulder-height windup at24-34. Only pivot about unchanged RIGHT middle grip: spear tip moves toward upper SCREEN RIGHT and butt toward lower SCREEN LEFT, entire unchanged shaft always visible, NEVER bend, shorten, melt, reverse or truncate its butt. At34-44 extend RIGHT arm and one grounded lunge directly SCREEN RIGHT, thrusting along the horizontal shaft axis into supplied full contact. Around44-66 the entire physical lance is horizontal and extended. LEFT arm keeps small shield in front of chest, never grabs spear. At66-77 retract RIGHT arm directly BACK along that same horizontal axis to windup; NO overhead lift, spin, circular swing, point reversal, back-facing torso or repeated thrust. Keep horizontal windup through87 then smoothly pivot back through original diagonal carry103 to original upright ready116. Exactly one deliberate thrust and one complete recovery, no firing or magic. Preserve full pointed butt behind hand, shaft bands, couplers, spearhead and gauge with fixed proportions at every transition. ',2026110412)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes'][0:2]=['move_h3_v2','attack_h3_v2'];delivery['failed_takes']=['move_h3_v1','attack_h3_v1'];delivery['visual_review']['notes']+=' First move/thrust take pair rejected for repeated same-leg lead and nonrigid shaft transitions; original near-leg and diagonal-carry guides prepared for exact documented correction, acceptance still pending.'
 p.write(p.SOURCE_DIR/'delivery.json',delivery)
 records=[]
 for take in sorted(p.SOURCE_DIR.glob('*_h3_v*')):
  if not (take/'config.json').exists():continue
  for f in sorted(take.glob('guide_*_rgba.png')):
   a=np.asarray(Image.open(f).convert('RGBA')).astype('int16');solid=a[:,:,3]>=250
   value=int((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[solid].max());assert value<=24,(f,value)
   records.append(dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f),opaque_magenta_chroma_max=value,opaque_pixels=int(solid.sum())))
 p.write(p.SOURCE_DIR/'foreground_measurement.json',dict(unit_id=UID,measured_guides=len(records),opaque_magenta_chroma_max=max(r['opaque_magenta_chroma_max'] for r in records),unchanged_protected_band=24,records=records,rule='Measure all original prepared guide pixels before submitting correction. No relaxed matte or model settings.'))
 registration=json.loads((p.SOURCE_DIR/'runtime_registration.json').read_bytes());registration['correction_original_guides']=dict(near_passing=near_pass,near_contact=near_contact,diagonal_carry=diagonal);p.write(p.SOURCE_DIR/'runtime_registration.json',registration)
 print('ALL_GUIDE_PALETTE_OK',len(records),max(r['opaque_magenta_chroma_max'] for r in records),flush=True)
