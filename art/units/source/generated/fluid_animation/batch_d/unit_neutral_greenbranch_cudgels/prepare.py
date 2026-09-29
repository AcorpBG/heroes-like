"""Prepare original Greenbranch Cudgel action guides at fixed body scale."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID = 'unit_neutral_greenbranch_cudgels'
BASE = p.ROOT/'art/animation/source/poses'/UID
PACK = json.loads((BASE/'packing.json').read_bytes())
IDENTITY = ('One original Greenbranch Cudgel, a sturdy adult human woodland militia man with a short brown beard. '
 'Brown segmented wooden armor, olive green scarf and ragged green skirt, brown strapped boots and knee guards. '
 'Brown helmet with a crown of small bare branching twigs. Exactly two arms and two legs. '
 'His right hand at screen left grips ONE wooden cudgel with a knotted rounded head, vines and tiny leaves. '
 'His left arm at screen right carries ONE round woven branch shield with crisscross wooden ribs. '
 'Keep the same face, solid cudgel, round shield outline and branching helmet throughout. ')
PLATE = (' Locked elevated three-quarter orthographic camera matching the reference, fixed anatomical scale and centered root. '
 'Full body and all equipment visible. Uniform pure saturated magenta RGB255,0,255 fills the entire background. '
 'Continuous physical joint motion, stable ground contacts, only this one woodland man. ')
TAKES = {
 'move_h3_v1': ([13], [], 0, 'Walk steadily in place through three complete reciprocal gait cycles. Alternate both boots through contact, loading, passing and lift with clear knee and ankle motion. Carry the upright cudgel in the right hand beside the right shoulder, shield on the left arm. The green skirt follows the stride. Finish in the starting stance.'),
 'attack_h3_v1': ([13,4,5], [[34,1],[65,2]], 0, 'Perform ONE powerful cudgel strike. Bend and raise the right elbow, lifting the club above the right shoulder into the supplied windup. Step forward and swing the same rigid wooden cudgel downward in front of the shield into the supplied low contact pose. Retract the cudgel with visible elbow and wrist motion and recover smoothly to the original upright ready stance. Keep the right hand connected to the shaft throughout.'),
 'hit_h3_v1': ([13,9], [[45,1]], 0, 'Perform one startled backward impact recoil. Shoulders and head lean back, knees flex and the shield arm absorbs the jolt. The right hand retains the wooden club beside the hip. Regain balance and return to the original ready stance. One physical flinch with continuous recovery.'),
 'defend_h3_v1': ([13,8], [[65,1]], 1, 'Brace behind the woven shield. Spread the feet, bend both knees into the supplied guarded crouch and bring the left shield forward to protect chest and face. Hold the club close beside the right shoulder. End holding the crouched guard with both boots firmly planted.'),
 'cast_h3_v1': ([13,16], [[48,1],[75,1]], 0, 'Give a practical readiness signal to nearby allies. Bend the right elbow and lift the cudgel hand slightly forward and outward beside the shoulder, briefly hold the raised ready gesture, then deliberately lower the hand back to its original height. The left arm holds the round woven shield steady. Nonmagical militia signal with clear elbow and wrist articulation.'),
 'death_h3_v1': ([13,10,12], [[35,1]], 2, 'Perform one continuous defeat collapse. Knees buckle, lower onto the knees while shoulders droop. Tip onto the right side with head toward screen right and boots toward screen left. Lower the woven shield onto the body, and settle the right hand and wooden cudgel onto the ground in front. Finish lying motionless in the supplied side-rest pose. Preserve both arms, both legs and solid equipment during the entire fall.'),
}

def ref(index):
 frame = dict(PACK['frames'][index])
 frame['source'] = (BASE/frame['source']).relative_to(p.ROOT).as_posix()
 frame['alpha_noise_cutoff'] = 8
 return frame

if __name__ == '__main__':
 thumbs = []
 for number,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out = p.SOURCE_DIR/name
  out.mkdir(exist_ok=False)
  config = dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[255,0,255],seed=2026093300+number,
   references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,config)
  bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png'); a=np.asarray(im).astype(float); mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[mask].max())); thumbs.append((name+':'+str(i),im.copy()))
  config['protected_foreground_chroma']=max(0,int(max(bands))+2)
  config['foreground_measurement']=dict(rule='Eroded opaque min(red,blue)-green maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',config)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review reciprocal gait, right-hand cudgel grip, round left shield, support signal and grounded collapse. Preserve eight original articulated idle poses.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43)); draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237)); x,y=j%4*360,j//4*260; sheet.paste(im,(x,y+23),im); draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/greenbranch_h3/guides.png')
