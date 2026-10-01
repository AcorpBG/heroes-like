"""Reproduce fixed-scale original Flaremast H3 action guides."""
import json
import numpy as np
from scipy.ndimage import binary_erosion
from PIL import Image, ImageDraw
import produce as p

UID='unit_neutral_flaremast_crews'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('One original Flaremast operator, an adult woman with brown wavy hair, blue cap and amber goggles, '
 'teal jacket with cream cuffs and lapels, brown quilted vest, red neck scarf and long red waist sash, '
 'cream trousers and tall brown strapped boots. Exactly two arms and two legs. '
 'Both hands hold one long brass signal launcher with a flared muzzle and red chamber: RIGHT hand remains at its trigger, '
 'LEFT hand supports the barrel ahead of the red chamber. Preserve face, cap, goggles, launcher length and grip. '
 'One tall brass signal mast carries three red, orange and blue glass canisters and three tripod legs. ')
PLATE=(' Fixed elevated three-quarter orthographic camera facing screen right and constant anatomical scale. '
 'Full body, long launcher and complete mast stay inside the frame. Entire background stays perfectly flat pure magenta '
 'RGB255,0,255 throughout: no hue cycling, shadows, floor, horizon, smoke, scenery, captions or additional people. '
 'Smooth physical joint articulation, no morphing or duplicate equipment. ')
TAKES={
 'move_h3_v1':([0],[],0,
  'First keep the launcher in the right hand, use the left hand to fold the three tripod legs of the single mast and physically lift it onto the back strap. Then restore both launcher grips. The same full-length mast is carried diagonally on her back with red, orange and blue canisters retained. '
  'Walk naturally in place through two complete reciprocal stride cycles. Each boot alternates heel contact, loading, passing '
  'and toe lift while the other leg supports the body. Body stays centered, no forward translation. Both hands carry the launcher '
  'low pointing down-right. The red sash follows the leg motion. Stop walking, use left hand to lift the same mast down, spread its tripod and place it upright at the original screen-left ground contact. Restore both launcher grips and ready stance.'),
 'attack_h3_v1':([0],[],0,
  'The mast remains deployed upright at screen left, its tripod stationary. Make one close-range physical launcher shove. '
  'Bring the launcher up across the chest with both hands, lean forward and extend both elbows to shove the same muzzle toward '
  'screen right. Keep right trigger and left supporting grips. Retract the arms and return to ready. No shooting or projectile.'),
 'ranged_h3_v1':([0],[],0,
  'The mast remains deployed upright at screen left, its tripod stationary. Perform one aimed launcher shot: bring both hands '
  'and barrel to shoulder level, sight toward screen right, hold aim, squeeze the right trigger once, absorb a small backward '
  'shoulder and elbow recoil, then lower to ready. The left hand remains supporting the barrel. Projectile flight and impact '
  'are separately rendered by the game; show no detached projectile, muzzle flash or smoke.'),
 'hit_h3_v1':([0],[],0,
  'The mast stays deployed upright and stationary at screen left. Briefly recoil from an impact: shoulders and head bend '
  'back, knees flex, both boots remain supporting the body, launcher retained in both hands. Recover through the knees '
  'and shoulders back to the original upright ready stance, no fall or magical effect.'),
 'defend_h3_v1':([0],[],None,
  'The mast stays deployed upright and stationary at screen left. Lower into a dedicated defensive guard: bend both knees, '
  'bring launcher close across the chest, settle onto the rear knee while forward boot stays firmly planted. Both hands retain '
  'their original launcher grips. Finish holding the supplied compact kneeling guard, without standing up.'),
 'cast_h3_v1':([0],[],0,
  'The mast stays deployed upright and stationary at screen left. Make a practical support signal and equipment check. '
  'Keep launcher supported in the left hand while right hand checks the red chamber and then briefly lifts open beside '
  'the chest as a readiness signal. Restore the right trigger grip and ready posture. Real hand, wrist and elbow movement '
  'only; she is a noncaster, no magic, glow, shooting, new cartridge or added equipment.'),
 'death_h3_v1':([0,17],[],1,
  'Collapse continuously into defeat. Knees buckle and she lowers to one knee, reaches down, loses support and tips onto '
  'her side with head toward screen left. Launcher stays held until her hands touch the ground then rests beside her. '
  'The one deployed mast tips over with her and its complete pole, all three canisters and folded tripod settle horizontally '
  'behind the body. Retain cap, goggles, two arms and two legs. End motionless in the supplied grounded corpse pose.')}

def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

if __name__=='__main__':
 thumbs=[]
 for n,(take,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/take;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=take.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[255,0,255],
   seed=2026100110+n,references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   chroma=np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1];bands.append(float(chroma[mask].max()));thumbs.append((take+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque min(red,blue)-green maximum plus two over all original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
  visual_review=dict(status='pending',notes='Inspect reciprocal boots, right trigger/left barrel support, red/orange/blue mast canisters, stable deployed tripod, launcher contact/recoil, physical support and grounded collapse. Accepted eight-pose idle preserved; continuous playback not yet verified.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*280),(38,42,40));d=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,253));x,y=j%4*360,j//4*280;sheet.paste(im,(x,y+24),im);d.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/flaremast_h3/guides.png')
