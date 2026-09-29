"""Prepare original-only H3 guides for the six deficient Kilnward actions."""
import json
import produce as p
from pathlib import Path

UID='unit_neutral_kilnward_mallets'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('Original fantasy strategy game sprite of ONE burly human blacksmith warrior facing screen right in elevated three-quarter view. '
 'Keep his black beard, brown tied headband, weathered copper shoulder plates, dark leather apron with red kiln emblems, metal wrist cuffs, segmented thigh armor and leather boots. '
 'Exactly two arms, two hands and two legs. Both hands hold ONE long straight wooden mallet shaft with ONE heavy rectangular dark iron hammer head bearing red markings at its far end. '
 'Right hand at screen left grips the butt half, left hand at screen right grips nearer the head. Preserve the same head, straight shaft, constant handle length and both grips. '
 'No shield, helmet or additional weapon. Retain his stocky adult anatomy and original painted materials. ')
PLATE=(' Locked orthographic camera and fixed body scale throughout. Full body, boots and mallet remain completely inside the frame. '
 'The studio background is perfectly flat uniform bright MAGENTA and remains exactly that one color in every frame. '
 'Only the warrior moves. No camera movement, zoom, scene, cast shadow, flash, sparks, flames, magic, smoke, debris, extra people, limbs or equipment.')

def ref(index):
 f=dict(PACK['frames'][index]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix()
 f['scale']*=.91 if index<15 else 1
 f['alpha_noise_cutoff']=8
 return f

TAKES={
 'move_h3_v1':([2,5,4],[[30,1],[62,0],[94,2]],0,
  'Walk in place through two complete heavy reciprocal walking cycles. Alternate the near and far legs: heel contact, weight loading, knee passing, lift, forward extension, opposite foot contact. '
  'Each boot lifts and plants cleanly; the other supports his weight. Bend knees and ankles naturally, never slide planted boots. The apron sways slightly. '
  'Both arms carry the intact mallet steadily across his waist. Keep the torso rooted in place for engine-driven travel and return smoothly to the starting walking phase.'),
 'attack_h3_v1':([0,6,7,8],[[26,1],[50,2],[76,3],[110,0]],0,
  'Perform one forceful two-handed mallet attack. From ready, flex both elbows and lift the intact mallet back above the near shoulder; rotate the torso and plant weight on the rear boot. '
  'Step into a powerful downward-forward blow toward an opponent at screen right, extending both arms while keeping both hands on the shaft. '
  'The rigid rectangular head follows one continuous arc, then the warrior recovers the mallet to his original waist-level ready position. Distinct anticipation, contact, follow-through and recovery. Do not throw or release the hammer.'),
 'hit_h3_v1':([0,11],[[32,1],[86,0]],0,
  'React to one unseen hit. Torso recoils backward, elbows and knees bend, shoulders contract and head tips back briefly, while both hands keep the intact mallet across his waist. '
  'Absorb the impact through planted boots, then return naturally to the original ready posture. A compact recoil and recovery, not a collapse. No attacker, projectile or impact effect is visible.'),
 'defend_h3_v1':([0,10],[[40,1]],1,
  'From ready, lower into a firm wide-legged defensive brace. Flex both knees and lean slightly forward while lifting the rigid mallet horizontally across his torso as a guard, both hands firmly gripping. '
  'Hold the low stable guard for the remainder, with complete boots planted and no weapon swing or attack. Final pose remains braced.'),
 'cast_h3_v1':([0,9],[[38,1],[70,1],[108,0]],0,
  'Perform a clear physical rally signal, not magic. Remain upright and deliberately lift the mallet diagonally across his chest with both arms, bringing the iron head near shoulder level. '
  'Hold this proud mallet salute briefly, look forward, then lower both hands and the intact mallet to the original waist-level ready position. Keep both boots planted and shoulders steady. Do not crouch, attack, swing, conjure or release the hammer.'),
 'death_h3_v1':([0,12,13,14],[[30,1],[64,2]],3,
  'One continuous defeat and collapse. Knees buckle, shoulders slump, mallet lowers with both hands; the near knee and hip reach the ground, then the body falls onto its side. '
  'The head and torso settle, both legs come to rest, and the intact mallet settles flat beside his hands. Keep the straight shaft and single iron head intact through the fall. '
  'End as a fully grounded motionless corpse with the mallet lying on the ground. No disappearance, standing weapon or recovery.')
}

if __name__=='__main__':
 for n,(indices,guides,last,action) in TAKES.items():
  out=p.SOURCE_DIR/n;out.mkdir(exist_ok=True)
  if (out/'config.json').exists():raise RuntimeError('Use a new take version; do not overwrite submitted originals')
  c=dict(unit_id=UID,clip=n.split('_')[0],canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[255,0,255],protected_foreground_chroma=8,
    seed=2026092900+list(TAKES).index(n),references=[ref(i) for i in indices],guides=guides,last=last,prompt=IDENTITY+action+PLATE,
    tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.write(out/'config.json',c);p.prepare(out,c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review mallet rigidity, both grips, anatomy, gait, action transitions and native scale.')))
