"""Prepare original Snowglass action references at their stored anatomical scale."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p
UID='unit_neutral_snowglass_markers'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=(
 'ONE original Snowglass Marker archer facing screen right in elevated three-quarter view. '
 'Preserve the white fur-trimmed hood and white winter coat, cobalt blue scarf over the mouth, round amber goggles, '
 'blue cape with white embroidered geometric edging, brown leather gloves, belt, fitted blue trousers, knee pads and fur-cuffed brown boots. '
 'A quiver of blue-fletched arrows stays behind the shoulder. Exactly two arms, two hands and two legs. '
 'The left bow hand carries ONE brown recurved bow with golden metal tips and a round blue gem at the handle; '
 'the right hand draws the string or gestures. Preserve the bow length, curvature, string and grip, adult proportions and painted materials. '
)
PLATE=(
 ' Locked orthographic camera, unchanged body scale and full-body view. Keep all boots, hood, bow tips and equipment inside the canvas. '
 'Perfectly uniform bright GREEN background, exactly the same green throughout the entire video. '
 'The flat green background remains empty. No scenery, camera motion, zoom, magic, glow, sparks, smoke or added equipment. '
 'Natural articulated limb movement with stable anatomy and physical ground contact.'
)
def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f
TAKES={
 'move_h3_v1':([2],[],0,
  'Walk in place through two complete reciprocal cycles, alternately lifting and planting each boot. Near and far legs alternate contact, loading, passing and extension. '
  'Keep the body centered for engine travel; the left hand carries the bow low and the free right arm swings naturally. The cape follows the stride. End in the starting gait phase.'),
 'attack_h3_v1':([17,4,5,6],[[25,1],[49,2],[77,3]],0,
  'Perform one close-range two-handed bow shove. Bring the bow horizontally across the chest with both hands, pull back into a low windup, '
  'step and extend both arms toward screen right in one forceful shove, keeping the entire bow rigid and intact. Retract the arms, '
  'raise the torso and recover the relaxed low one-handed bow carry. The bow stays in the hands; this is a physical push without an arrow.'),
 'ranged_h3_v1':([17,9,10,11,12],[[23,1],[48,2],[65,3],[89,4]],0,
  'Shoot ONE arrow toward screen right. Right hand nocks a single blue-fletched arrow onto the bowstring, left arm extends and aims the bow, '
  'right elbow draws the string and nock back beside the cheek. Briefly hold full draw, release once, and let the right hand follow through backward. '
  'The arrow leaves cleanly toward screen right; bow and string remain in the left grip. Lower the bow and recover the starting stance. '
  'Only one shot; preserve both real arms and the quiver.'),
 'hit_h3_v1':([17,13],[[45,1]],0,
  'Act one compact loss of balance and recovery: shoulders and head tilt backward, knees flex, free right hand comes toward the chest, '
  'and the left hand keeps its bow grip. Recover smoothly onto both boots and settle into the original ready stance. One controlled recoil, remaining upright.'),
 'defend_h3_v1':([17,7,8],[[30,1],[70,2]],2,
  'Raise the bow vertically beside the front shoulder, bring the free right hand inward to guard the chest, bend both knees and lower into a stable crouched brace. '
  'Keep the hood, face and bow visible. Hold the final low defensive stance with both feet supporting the body; do not fire or return to upright.'),
 'cast_h3_v1':([17,20],[[45,1],[72,1]],0,
  'Make one physical readiness signal: the free right hand rises across the chest, briefly touches the leather strap near the shoulder and opens in a small forward acknowledgement. '
  'Left hand holds the bow low throughout. Right elbow and wrist visibly articulate, then lower back to the relaxed original ready pose. Boots stay planted. This is a nonmagical support gesture.'),
 'death_h3_v1':([17,14,15,16],[[34,1],[74,2]],3,
  'Collapse continuously: knees buckle and lower onto one knee, right hand reaches the ground, torso tips and hips settle sideways. '
  'Roll gently onto the side with the head at screen left and boots extending right. The bow descends with the left hand and rests horizontally on the ground in front of the body. '
  'End in the supplied motionless grounded corpse with quiver and cape intact. No recovery, floating equipment, new limbs or disappearing bow.'),
}
if __name__=='__main__':
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[0,255,0],
   seed=2026092960+n,references=[ref(i) for i in indices],guides=guides,last=last,prompt=IDENTITY+action+PLATE,
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c)
  excess=[]
  for i in range(len(indices)):
   a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   excess.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
  c['protected_foreground_chroma']=max(0,int(max(excess))+2)
  c['foreground_measurement']=dict(rule='Maximum green-minus-max(red,blue) over opaque alpha>240 interiors eroded three pixels, plus two levels.',per_guide_max=excess)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
  visual_review=dict(status='pending',notes='Review all original chronological frames, bow grips/string, anatomy, alpha, grounding and native scale before publication.')))
