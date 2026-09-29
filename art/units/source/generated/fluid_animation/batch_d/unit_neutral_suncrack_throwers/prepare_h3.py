"""Prepare fixed-scale original Suncrack guides; retain the reviewed idle."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_suncrack_throwers'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('One original Suncrack Thrower, an athletic adult human woman with tan skin and brown hair in a messy high bun. '
 'Brass goggles with pale blue lenses rest on her forehead. Turquoise scarf with long gold-trimmed tails, '
 'ivory sleeveless wrapped tunic and split ragged skirt over ivory trousers, crossed brown chest straps, '
 'white wrist wraps and brown knee-high strapped sandals. A brown belt carries round brass flasks with blue glass centers. '
 'Exactly two arms, two hands and two legs, same face and outfit throughout. No shield, sword, staff or additional people. ')
PLATE=(' Fixed elevated three-quarter orthographic camera matching the reference, fixed body scale, centered root. '
 'Full body and scarf remain visible. Entire background stays perfectly uniform pure green RGB0,255,0 throughout, '
 'no color change, no floor, shadow, horizon, dust, text or scenery. Continuous physical joint articulation. ')
TAKES={
 'move_h3_v1':([18],[],0,'Walk briskly in place with three complete reciprocal gait cycles. Alternate the two feet through contact, loading, passing and lift, with bent knees and coordinated opposing arm swing. Belt flasks stay secured, scarf follows the stride. Maintain centered hips and same scale. Finish in the initial stance.'),
 'attack_h3_v1':([18,4,5],[[32,1],[60,2]],0,'Perform one unarmed right-handed punch. Draw the right fist behind the shoulder into the windup, keep the left hand guarding. Turn the shoulders and extend the right elbow toward screen right into the supplied contact. Retract the same right fist and recover to the ready stance. No held flask during the punch; belt flasks remain attached.'),
 'ranged_h3_v1':([18,10,11],[[36,1],[65,2]],0,'Perform one overarm flask throw. The right hand lifts ONE round blue-and-brass flask from the belt, draws it beside the right ear in the supplied windup, and swings forward toward screen right. Fingers release the single flask beyond the hand, then the empty right hand follows through and lowers to ready. The left arm counterbalances. Only one thrown flask, no trail, blast, sparks or second projectile. Preserve the same belt and remaining flasks.'),
 'hit_h3_v1':([18,13],[[44,1]],0,'React once to a chest impact. Lean the shoulders back, flex knees, raise the left hand defensively while the right forearm draws across the belly. Keep both feet supporting the body; regain balance and recover to the initial stance. No wound or particles.'),
 'defend_h3_v1':([18,8],[[65,1]],1,'Lower into the supplied guarded crouch. Bend the knees, brace the lower leg and raise both wrapped forearms over the head to protect the face. Keep both hands distinct and connected to their forearms. End holding the guarded kneeling pose, without standing back up.'),
 'cast_h3_v1':([18,21],[[42,1],[68,1]],0,'Give allies a practical ready signal with a belt flask. Lift one blue-and-brass flask to the chest in the right hand, raise the left hand beside it in a small checking gesture, and then lower both hands back toward the belt. Physical coordination signal, not spellcasting. Do not throw or duplicate the held flask. Clear elbow and wrist articulation, scarf follows subtly.'),
 'death_h3_v1':([18,14,15,17],[[35,1],[65,2]],3,'Perform one continuous defeat collapse. Knees buckle, lower onto one knee with shoulders drooping, then lean forward and reach both hands toward the ground. Lower the hip and roll onto the side with head toward screen left and legs toward screen right. Settle into the supplied curled side-rest pose, scarf and belt flasks resting with the body. End motionless on the ground with both arms and legs intact.')
}

def ref(index):
 f=dict(PACK['frames'][index]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

if __name__=='__main__':
 thumbs=[]
 for number,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],seed=2026093400+number,references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()));thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review gait, punching fist, single flask release, physical flask support, forearm guard and grounded collapse. Preserve the eight original articulated idle poses after native review.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(43,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/suncrack_h3/guides.png')
