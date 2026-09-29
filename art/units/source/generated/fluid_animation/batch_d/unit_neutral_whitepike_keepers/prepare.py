"""Prepare Whitepike's original guides at fixed scale for dedicated H3 actions."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_whitepike_keepers'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('One original Whitepike Keeper, an adult bearded human man in an ivory fur-trimmed winter coat, '
 'blue cloth cap with white fur rim, blue scarf, leather lamellar armor, blue central coat panel, brown gloves and tall brown boots. '
 'Exactly two arms and two legs. Both gloved hands hold ONE long straight ivory wooden pike with a large silver spearhead at one end '
 'and a small pointed steel butt at the other. Brown bindings below both metal tips. The same rigid straight shaft, fixed length, '
 'two metal tips and two continuous hand grips remain throughout. Preserve his face, costume and proportions. ')
PLATE=(' Locked elevated three-quarter orthographic camera at the reference angle, fixed anatomical scale and centered root. '
 'Full body and both pike tips stay visible. Uniform pure saturated green RGB0,255,0 fills the entire background. '
 'Continuous physical joint movement and stable ground contacts, with only this one keeper in the shot. ')
TAKES={
 'move_h3_v1':([13],[],0,'Walk steadily in place through three full reciprocal gait cycles. Alternate boots through forward contact, weight bearing, passing and lift. Both hands carry the pike diagonally in the starting orientation, large spearhead above screen left and small butt below screen right, with subtle arm counter-motion. Finish in the starting stance.'),
 'attack_h3_v1':([13,4,5],[[34,1],[60,2]],0,'Perform one pike thrust. Smoothly rotate the pike from diagonal ready into the supplied horizontal shoulder-height windup, pointing the large spearhead toward screen right. Step and thrust the rigid pike forward with both hands into the supplied extended contact pose. Retract the pike and smoothly return to the original diagonal ready stance. The hands slide only along the straight shaft.'),
 'hit_h3_v1':([13,9],[[45,1]],0,'Perform one backward impact recoil. Lean shoulders and head back, bend the knees and bring the pike low across the waist with both hands. Regain balance and smoothly return to the original stance. Keep the same shaft and both tips intact throughout.'),
 'defend_h3_v1':([13,8],[[70,1]],1,'Prepare a firm defensive crouch. Spread the feet, bend both knees and lower the pike across the body into the supplied low horizontal guard. Both hands hold the same straight shaft securely. Finish holding the crouched guard with both boots planted.'),
 'cast_h3_v1':([13,16],[[48,1],[75,1]],0,'Perform a physical readiness signal to allies. Keeping the upper hand firmly gripping the diagonal pike, slide the lower gloved hand upward along the shaft toward the chest and tighten the grip. Briefly nod, then return the lower hand to its original lower grip. The pike stays diagonal with the large spearhead above screen left. Nonmagical equipment preparation.'),
 'death_h3_v1':([13,10,12],[[38,1]],2,'Perform one continuous collapse. Knees buckle and lower onto the ground, then the keeper tips onto his side with head toward screen right and boots toward screen left. Both hands lower the straight pike with the body, bringing the shaft to rest horizontally along the ground. Finish lying motionless in the supplied side-rest pose with the pike resting in front.'),
}

def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

if __name__=='__main__':
 thumbs=[]
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],seed=2026093100+n,
   references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()));thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review reciprocal gait, pike shaft/tips and both grips, low guard, physical grip signal, continuous fall, alpha and native scale. Preserve existing articulated eight-pose idle.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/whitepike_h3/guides.png')
