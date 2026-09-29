"""Prepare Scarshield's original hammer/shield guides at fixed anatomical scale."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_scarshield_veterans'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('One original Scarshield Veteran, a broad-shouldered adult human man with tousled dark brown hair, short beard and stern weathered face. '
 'Dark layered steel and bronze armor, grey neck scarf, torn red cape and red cloth skirt, brown armored boots. Exactly two arms and two legs. '
 'His right hand at screen left holds ONE short heavy square-headed warhammer with a brown handle, orange seams and red cloth ties. '
 'His left arm at screen right carries ONE tall pointed dark shield with a bronze central boss, jagged metal edge and orange seams. '
 'Keep the same solid hammer, shield outline, armor and face throughout. The hammer stays in the right hand and shield attached to the left arm. ')
PLATE=(' Locked elevated three-quarter orthographic camera at the reference angle, fixed anatomical scale and centered root. '
 'Full body and equipment stay visible. Uniform pure saturated green RGB0,255,0 fills the entire background. '
 'Continuous physical joint movement, stable ground contacts, only this one warrior in the shot. ')
TAKES={
 'move_h3_v1':([13],[],0,'Walk steadily in place through three complete reciprocal gait cycles. Alternate both boots through contact, loading, passing and lift, with clear knee and ankle movement. Carry the heavy hammer low beside the right thigh and keep the shield raised beside the left shoulder. The torn cape follows the stride. Finish in the starting stance.'),
 'attack_h3_v1':([13,4,5],[[34,1],[65,2]],0,'Perform ONE powerful overhead hammer strike. Gradually bend and raise the right elbow to bring the hammer above the right shoulder into the supplied windup. Then step forward and swing the same rigid hammer downward across the body into the supplied low contact pose. Keep the left shield between the torso and opponent. Retract the hammer and recover smoothly to the original ready stance. Show every phase of the arm swing continuously.'),
 'hit_h3_v1':([13,9],[[45,1]],0,'Perform one startled backward impact recoil. Shoulders and head lean back, knees flex and the shield arm absorbs the jolt. The right hand keeps the hammer low beside the hip. Regain balance and return to the original ready stance. A solitary physical flinch.'),
 'defend_h3_v1':([13,8],[[65,1]],1,'Brace behind the shield. Spread the feet, bend the knees into the supplied guarded crouch, and bring the left shield forward to protect chest and face. The right hand holds the hammer close beside the thigh. End holding the crouched guard with both boots firmly planted.'),
 'cast_h3_v1':([13,16],[[48,1],[75,1]],0,'Give a practical rally signal to allies. Bend the right elbow and raise the heavy hammer from the hip across the chest beside the shield, briefly hold the compact readiness gesture, then lower the hammer back beside the right thigh. The left arm keeps the shield steady. This is a nonmagical veteran signaling readiness, with visible elbow and wrist movement.'),
 'death_h3_v1':([13,10,12],[[35,1]],2,'Perform one continuous defeat collapse. Knees buckle and lower onto the knees as shoulders droop. Tip onto the right side with head toward screen right and boots toward screen left. The left arm lowers the shield onto the ground in front of the chest, and the right arm lowers the hammer to rest beside the body. Finish lying motionless in the supplied side-rest pose. Shield and hammer stay solid and settle on the ground.'),
}

def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

if __name__=='__main__':
 thumbs=[]
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],seed=2026093200+n,
   references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()));thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review gait, right-hand hammer grip, left shield geometry, support signal and grounded collapse. Preserve eight articulated original idle poses.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/scarshield_h3/guides.png')
