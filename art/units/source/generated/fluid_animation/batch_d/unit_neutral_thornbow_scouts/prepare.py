"""Prepare original Thornbow Scouts guides at one anatomical scale."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_thornbow_scouts'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=(
 'ONE original adult female Thornbow Scout, facing screen right in elevated three-quarter view. '
 'Preserve her brown braided hair, leaf hair clasp, pointed ears, olive scarf, layered olive leaf-shaped shoulder and skirt panels, '
 'fitted brown leather tunic, belts, long brown bracers and fingerless gloves, brown trousers and knee-high wrapped leather boots. '
 'A small green tattoo is visible on her left upper arm. A brown quiver of arrows sits at her right rear hip. '
 'Exactly two arms, two hands and two legs. The LEFT hand grips the wrapped central handle of ONE short golden-brown wooden thornbow. '
 'Keep its original curved limbs, small wooden thorns, curled tips, thin bowstring, size and grip position unchanged. '
 'The RIGHT hand is the free drawing hand. Preserve her face, adult proportions, original equipment and painted fantasy style. '
)
PLATE=(
 ' Locked orthographic camera, centered anatomical root at fixed scale. Entire head, boots and bow remain within the canvas. '
 'Perfectly flat saturated BLUE background through every frame, with no gradients, scenery, floor shadow, camera motion or zoom. '
 'Natural joint articulation with physical support. No extra limbs, extra bows, swords, shields, magic, glowing effects or trails. '
)

def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

TAKES={
 'move_h3_v1':([2,3],[[30,1],[92,1]],0,
  'Walk in place for two complete reciprocal gait cycles, alternating both legs through contact, loading, passing and lift. '
  'The left hand carries the lowered bow at her left side; the right arm swings naturally. '
  'Keep the torso centered for engine-driven travel. Both boots alternate taking weight. Finish in the starting gait phase.'),
 'attack_h3_v1':([17,4,5,6],[[25,1],[52,2],[86,3]],0,
  'Perform ONE short physical melee shove with the bow. Raise the bow vertically, bring the right hand beside the left hand at its central grip, '
  'then push both hands forward toward screen right as the front knee bends. The bow is a rigid wooden object, not a drawn bow. '
  'Recover the bow toward the chest, release only the right hand, and lower the bow back to the original ready stance. '
  'No arrow, shooting, sword swing, string pulling or second shove.'),
 'ranged_h3_v1':([17,9,10,11,6],[[20,1],[52,2],[66,3],[93,4]],0,
  'Shoot ONE arrow. The right hand takes and nocks one arrow, the left hand raises the bow toward screen right. '
  'Extend the left arm and draw the string back with the right hand beside the cheek, holding the arrow aligned toward screen right. '
  'Release once: the right fingers relax beside the cheek and the string springs forward, the arrow leaves screen right. '
  'Hold the follow-through, then lower the same bow to the original ready position. Keep a single bow and string, no second arrow or repeated shot.'),
 'hit_h3_v1':([17,13],[[42,1]],0,
  'React once to an impact: shoulders and head recoil backward, knees flex, right forearm draws inward protectively. '
  'The left hand keeps the original short bow low. Regain balance on both feet and return to the original stance. No collapse or firing.'),
 'defend_h3_v1':([17,7,8],[[28,1],[68,2]],2,
  'Raise the bow upright close beside the left shoulder, bring the free right forearm in front of the chest and duck into a low braced crouch. '
  'Bend both knees with planted boots. Finish holding the low guard with bow held securely, no firing and no return to standing.'),
 'cast_h3_v1':([17,7],[[43,1],[69,1]],0,
  'Give a clear nonmagical acknowledgement: lift the bow upright with the left hand while the right hand closes and rises firmly to the upper chest. '
  'Hold this readiness gesture briefly, then lower the right arm and left bow together to the original ready stance. '
  'Both boots remain planted. No arrow, string draw, shooting or spell effects.'),
 'death_h3_v1':([17,14,15,16],[[34,1],[76,2]],3,
  'Collapse continuously from standing. Knees buckle and she lowers onto one knee; the free right hand reaches for the ground. '
  'Her hips descend, torso tips toward screen right and she lies on her side with head at screen right and feet at screen left. '
  'The left hand lowers the same bow flat to the ground in front as the body lands. Keep both arms and legs intact. '
  'Finish motionless, bow and quiver grounded, no recovery, floating equipment or disappearing body.'),
}

if __name__=='__main__':
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[0,0,255],seed=2026092920+n,
   references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);excess=[]
  for i in range(len(indices)):
   a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   excess.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
  c['protected_foreground_chroma']=max(0,int(max(excess))+2)
  c['foreground_measurement']=dict(rule='Maximum blue-minus-max(red,green) in alpha>240 interiors eroded three pixels plus two.',per_guide_max=excess)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review original chronological frames, bow/string/arrow continuity, grips, reciprocal gait, grounded actions and native battle/map scale.')))
