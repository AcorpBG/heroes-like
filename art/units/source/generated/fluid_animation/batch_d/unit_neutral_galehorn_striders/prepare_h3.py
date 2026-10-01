"""Prepare fixed-anatomy Galehorn action guides; no service or GPU mutations."""
import json
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import binary_erosion
import produce as p
UID='unit_neutral_galehorn_striders'
IDENTITY=('One original Galehorn Strider, a silvery blue and ivory fantasy antelope with layered fur, copper fur tips, golden eye, narrow face, long flowing mane and feathered tail. '
 'Exactly FOUR slender antelope legs: two forelegs attached to the chest, two hindlegs attached to the pelvis, each with one dark cloven hoof. Count complete joint and ankle chains, never add a middle belly leg. '
 'Exactly TWO long swept curled ribbed horns attached to the head; retain full horn length and curvature. No equipment, wings, extra limbs or magic. ')
PLATE=('Locked elevated three-quarter orthographic camera, facing screen right, fixed body size and root. Full horns, tail and all four hooves stay inside the image. '
 'Every background pixel stays perfectly flat pure green RGB 0,255,0 from first to last frame, with no hue cycling, floor, shadow, horizon, scenery, particles, glow, text or other creatures. '
 'Articulated physical joint motion, stable anatomy, no morphing. ')
TAKES={
 'move_h3_v1':(['walk_contact_a_v1','walk_contact_b_v2'],[[31,1],[62,0],[93,1]],0,
  'Walk in place through two complete smooth four-beat reciprocal gait cycles at an even pace. Start and finish in the same contact A. '
  'Contact A has near foreleg reaching forward and near hindleg reaching backward; contact B exchanges these roles. '
  'Between contacts each fore and hind hoof passes underneath, lifts and advances, then plants and loads; supporting legs bear the level torso. '
  'Near and far forelegs alternate, near and far hindlegs alternate. Keep all four leg chains distinct throughout overlap. '
  'No rearing, leaping, galloping, simultaneous foreleg kick, same-side pacing or root translation. Mane and tail follow the gait softly. Continue through the loop boundary without a stop.'),
 'idle_h3_v1':(['ready_fourlegs_v1'],[],0,
  'Remain calmly standing on four supporting hooves. Make a gentle articulated breathing cycle: ribcage expands, neck and head turn slightly, ears twitch and tail sweeps softly, then return to the exact ready stance. '
  'Feet remain at their original contacts, knees and hocks retain their four-leg identity. Visible neck, ear and tail motion, no whole-body bobbing or extra limbs.'),
 'attack_h3_v1':(['ready_fourlegs_v1','horn_brace_v1','horn_contact_v1'],[[34,1],[61,2]],0,
  'Make exactly ONE close-range horn ram. First flex foreknees and lower the head with both original horns while hindlegs brace. '
  'Drive neck and shoulders once toward screen right, extend forelegs briefly into a grounded forward horn contact, then retract and step back to the same ready root. '
  'Keep four limbs and two swept horns throughout anticipation, single contact and recovery. No repeated charge, kick, rear, projectile or effect.'),
 'hit_h3_v1':(['ready_fourlegs_v1'],[],0,
  'React once to an external impact: head and neck recoil backward, knees flex and weight shifts onto the hindlegs while four hooves retain support. '
  'Recover through the forelegs and neck into the exact ready stance. A brief startled flinch with recovery, no attack, kick, rear, fall or effect.'),
 'defend_h3_v1':(['ready_fourlegs_v1','horn_brace_v1'],[],1,
  'Lower into a dedicated held horn brace. Spread the forehooves slightly, bend both foreknees, lower chest and narrow head, bring both original horns low toward screen right, and brace through both hindlegs. '
  'Settle and hold this low four-hoof guard to the end, never return to standing, no forward ram or repeated attack.'),
 'cast_h3_v1':(['ready_fourlegs_v1'],[],0,
  'Give a physical nonmagical rally call. Keep all four hooves supporting the body, lift neck and head, tilt muzzle upward and briefly open mouth in a clear call. '
  'Ears lift and tail swishes, then close the mouth and lower neck/head back to the exact ready stance. No rearing, spell, lightning, glow or projectile.'),
 'death_h3_v1':(['ready_fourlegs_v1','death_corpse_v2'],[],1,
  'Lose support continuously and collapse onto the side. Foreknees buckle first, chest lowers to the ground, hind hocks fold, then torso tips onto the near side. '
  'Head and both long horns settle on the ground with the torso; exactly four folded legs and original mane/tail remain connected. '
  'Finish motionless in the supplied grounded side corpse, no disappearing limbs, levitation or upright body substitute.')}

def ref(name):
 im=Image.open(p.SOURCE_DIR/(name+'.png'))
 # Masters were painted at different vertical canvas locations. These anchors
 # locate actual planted hoof/body contacts once per source painting; all H3
 # guides share the same world root and all decoded frames retain that root.
 ground={'horn_brace_v1':937,'horn_contact_v1':950,'death_corpse_v2':796}.get(name,988)
 return dict(name=name,source=(p.SOURCE_DIR/(name+'.png')).relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[900,ground],scale=.22,alpha_noise_cutoff=8)

if __name__=='__main__':
 thumbs=[];prepared=[]
 for n,(take,(names,guides,last,action)) in enumerate(TAKES.items()):
  if any(not (p.SOURCE_DIR/(name+'.png')).exists() for name in names):continue
  out=p.SOURCE_DIR/take;out.mkdir(exist_ok=True)
  if (out/'submission.json').exists():
   prepared.append(take)
   for i,name in enumerate(names):thumbs.append((take+' / '+name,Image.open(out/f'guide_{i}_rgba.png').copy()))
   continue
  c=dict(unit_id=UID,clip=take.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],seed=2026100310+n,references=[ref(name) for name in names],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(names)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3);chroma=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]);bands.append(float(chroma[mask].max()));thumbs.append((take+' / '+names[i],im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque green minus max(red,blue) foreground maximum plus two, measured over every guide.',per_guide_max=bands)
  p.write(out/'config.json',c);p.verify(out,c);prepared.append(take)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=prepared,preserved_accepted_clips=[],replaced_defective_clips=['idle'],identity_defect='Legacy ready, movement and all eight idle sources have five hoof/leg chains. Owner coordinator authorized corrected four-leg idle and map refresh; immutable original sources and baseline preserved.',visual_review=dict(status='pending',notes='Corrected four-legged guide identity reviewed; H3 originals, reciprocal gait, native scale, both facings and focused runtime still require review. No playback claim.')))
 target=p.ROOT/'.artifacts/galehorn_h3_20261001';target.mkdir(parents=True,exist_ok=True)
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*280),(37,45,39));d=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((350,245));x=j%4*360;y=j//4*280;sheet.paste(im,(x+(360-im.width)//2,y+25),im);d.text((x+4,y+4),name,fill=(233,213,145))
 sheet.save(target/'guides.png');print('Prepared',prepared,'without GPU operations')
