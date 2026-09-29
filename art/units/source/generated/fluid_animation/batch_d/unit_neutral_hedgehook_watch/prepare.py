"""Prepare identity-preserving Hedgehook Watch H3 guides at fixed body scale."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_hedgehook_watch'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=(
 'ONE original adult female Hedgehook Watch warrior, facing screen right in elevated three-quarter view. '
 'Keep her youthful brown-haired face, muted olive green hood and scarf with small gold embroidery, '
 'brown overlapping leaf-shaped leather shoulder armour, fitted dark leather tunic, cream upper sleeves, '
 'brown gloves and bracers, belts, green ragged tabard, olive trousers, brown knee guards and wrapped leather boots. '
 'Exactly two arms, two hands, two legs. Her RIGHT hand holds ONE short-handled hooked steel billknife: '
 'brown grip, small round pommel, broad curved silver blade with notched inner edge and one pointed hooked tip. '
 'Her LEFT forearm carries ONE small round wooden buckler with metal rim, central steel boss, crossing twigs and short perimeter thorns. '
 'Preserve the original weapon length, hooked silhouette, shield size, right-hand grip, left shield straps, materials and adult proportions. '
)
PLATE=(
 ' Locked orthographic camera, fixed anatomical scale and centered body. Keep the full hood, limbs, boots, hook and shield within frame. '
 'The background is perfectly flat saturated BLUE throughout, no gradients or changes of hue. '
 'No scenery, floor shadow, camera motion, zoom, additional weapons, magic, glow, particles or extra limbs. '
 'Articulate joints naturally with physical planted-foot support; do not morph the equipment.'
)

def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

TAKES={
 'move_h3_v1':([3],[],0,
  'Walk in place through two complete reciprocal cycles. Alternate near and far legs through forward contact, weight loading, passing and lift. '
  'Her torso stays centered for engine-driven travel. The right hand carries the short billknife low across the waist, '
  'and the left forearm carries the round buckler in front of the ribs. Allow small natural arm and cloth motion. '
  'Both knees articulate, each boot alternates taking weight and swinging; finish in the original gait phase.'),
 'attack_h3_v1':([14,5,6,7],[[28,1],[58,2],[87,3]],0,
  'Make ONE controlled hooked-blade slash toward screen right. Raise the right elbow and short billknife above the right shoulder, '
  'then extend the right arm forward and down in a single cutting arc while the left buckler protects the chest. '
  'Bend the forward knee into contact, then draw the same short hook back across the waist and recover the original ready stance. '
  'The hand grips the original short handle throughout. No long sword, giant blade, weapon throw, second slash or shield strike.'),
 'hit_h3_v1':([14,10],[[42,1]],0,
  'Perform one brief impact recoil and complete recovery. The shoulders and head yield backward, both knees flex, '
  'and the shield arm gives slightly while the right hand retains the short hooked knife. '
  'Rebalance on both boots and return to the same guarded ready stance. Remain standing with all equipment held.'),
 'defend_h3_v1':([14,8,9],[[24,1],[66,2]],2,
  'Lift the round thorn-edged buckler to protect the chest and lower face. Bend both knees into a compact defensive crouch, '
  'with the left forearm braced behind the shield and the right hand keeping the billknife low and close beside it. '
  'Finish and hold the low guarded stance on both planted boots. No attack or return to upright.'),
 'cast_h3_v1':([14,17],[[43,1],[67,1]],0,
  'Perform a deliberate nonmagical readiness signal. The left elbow raises the buckler toward shoulder height, '
  'while the right elbow flexes and firmly regrips the short billknife, lifting its hooked steel blade across the upper waist. '
  'Hold the acknowledgement briefly, then lower both forearms smoothly to the original ready stance. '
  'Keep both boots planted and hood and face unchanged. This is physical support, with no spell or emitted effect.'),
 'death_h3_v1':([14,11,12,13],[[34,1],[74,2]],3,
  'Collapse continuously from standing. Knees buckle onto one knee, then lower the hips and tip the torso toward screen right. '
  'The left shield hand reaches down and the right billknife hand descends with the body. '
  'Lie motionless on the side with head at screen right and feet at screen left; the round buckler and short hook rest on the ground in front. '
  'Preserve both arms and legs, green hood, original short weapon and shield. No floating equipment, recovery or disappearing body.'),
}

if __name__=='__main__':
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[0,0,255],
   seed=2026092900+n,references=[ref(i) for i in indices],guides=guides,last=last,prompt=IDENTITY+action+PLATE,
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);excess=[]
  for i in range(len(indices)):
   a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   excess.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
  c['protected_foreground_chroma']=max(0,int(max(excess))+2)
  c['foreground_measurement']=dict(rule='Maximum blue-minus-max(red,green) over alpha>240 opaque interiors eroded three pixels, plus two levels.',per_guide_max=excess)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review all chronological originals, two-arm grip/short-hook/shield identity, reciprocal gait, grounding and native battle/map scale before publication.')))
