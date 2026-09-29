"""Prepare original Orchard Halberd references without normalizing body poses."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p
UID='unit_neutral_orchard_halberds'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=(
 'ONE original adult male Orchard Halberd soldier facing screen right in elevated three-quarter view. '
 'Preserve the brown broad-brimmed hat with red apples and green leaves, dark moustache and short beard, '
 'olive green scarf, long red quilted coat with cream edging, brown belt and apple pouch, loose brown trousers, calf wraps and brown boots. '
 'Exactly two arms, two hands and two legs. His right hand carries ONE long straight wooden billhook polearm: '
 'a single broad curved steel blade and small back hook at the upper end, a small metal ferrule on the other end. '
 'His left forearm carries ONE oval wicker shield with dark metal cross braces and a round steel boss. '
 'Keep the same rigid shaft length, blade shape, shield size, grips, adult body proportions and painted materials. '
)
PLATE=(
 ' Locked orthographic camera and fixed body scale. Entire soldier, shield, polearm blade and butt stay inside the canvas. '
 'Perfectly flat uniform saturated BLUE background throughout every frame, unchanged in color and brightness. '
 'No scenery, ground shadow, camera motion, zoom, spells, particles, sparks, new weapons or extra limbs. '
 'Natural articulated limb motion with physical grounding.'
)
def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f
TAKES={
 'move_h3_v1':([2],[],0,
  'Walk in place through two complete reciprocal cycles. Alternate near and far knees and boots through forward contact, loading, passing and lift. '
  'Keep the torso centered for engine travel. Carry the polearm upright with the blade above the right shoulder and the oval shield on the left forearm. '
  'Weapon and shield move gently with the hands without changing shape. Coat hem follows the gait. Finish in the starting gait phase.'),
 'attack_h3_v1':([13,4,5,6],[[30,1],[53,2],[76,3]],0,
  'Perform ONE broad overhead billhook chop toward screen right. Raise the polearm diagonally above the right shoulder while keeping the left wicker shield in front of the chest. '
  'Rotate the shoulder and extend the right elbow, driving the single curved blade forward and down in one continuous arc. '
  'Bend the front knee and shift weight into the strike. Draw the shaft back, straighten and lift the same blade to the original upright ready carry. '
  'The right hand grips the continuous shaft throughout; the left arm keeps its shield. No weapon throw, thrust, spinning shaft or extra attack.'),
 'hit_h3_v1':([13,9],[[43,1]],0,
  'Act one compact recoil and recovery. Shoulders tilt back, chin lifts, knees flex to absorb the motion, and the left shield arm yields briefly. '
  'Right hand retains the upright billhook. Regain balance on both boots and return smoothly to ready. Remain standing with all equipment held.'),
 'defend_h3_v1':([13,7,8],[[25,1],[65,2]],2,
  'Raise the wicker shield over the chest and lower into a strong defensive crouch. The left forearm braces behind the shield boss; '
  'the right hand draws the upright billhook close beside the shoulder. Bend both knees and hold the final low guard. '
  'The steel blade stays attached to its original shaft, and both boots support the body. No strike or return to upright.'),
 'cast_h3_v1':([13,16],[[42,1],[68,1]],0,
  'Make a physical readiness salute: the right forearm raises the upright billhook a short distance with a deliberate firm regrip, '
  'while the left elbow brings the wicker shield upward and slightly forward in acknowledgement. Briefly hold the signal, then lower both hands '
  'and settle the polearm and shield into the original ready pose. Boots stay planted. A nonmagical disciplined support gesture.'),
 'death_h3_v1':([13,10,11,12],[[33,1],[76,2]],3,
  'Collapse continuously: knees buckle, lower onto one knee, then tip the hips sideways and lower the torso toward screen left. '
  'The shield follows the left arm onto the body; the polearm descends with the right hand and rotates onto the ground. '
  'End on the side with the head at screen left and boots at screen right, shield resting over the torso and one straight billhook lying horizontally in front. '
  'Keep the hat, apples, shield, blade and limbs intact. Final corpse is motionless and fully grounded, with no recovery or floating equipment.'),
}
if __name__=='__main__':
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  tall=name.startswith('attack')
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,768 if tall else 640],anchor=[430,688 if tall else 560],scale=.5,key_rgb=[0,0,255],
   seed=2026092980+n,references=[ref(i) for i in indices],guides=guides,last=last,prompt=IDENTITY+action+PLATE,
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);excess=[]
  for i in range(len(indices)):
   a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   excess.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
  c['protected_foreground_chroma']=max(0,int(max(excess))+2)
  c['foreground_measurement']=dict(rule='Maximum blue-minus-max(red,green) over alpha>240 opaque interiors eroded three pixels, plus two levels.',per_guide_max=excess)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Inspect complete original sequences, blade/shaft/shield continuity, reciprocal gait, grounding and native scale before publication.')))
