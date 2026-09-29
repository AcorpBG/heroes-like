"""Original Frostbeacon key poses for six dedicated H3 actions."""
import json
import produce as p
UID='unit_neutral_frostbeacon_pikes'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=(
 'ONE original human Frostbeacon Pikeman, an adult soldier facing screen right in elevated three-quarter view. '
 'Preserve the blue fur-trimmed hood, blue quilted long coat with pale fur edging, silver steel chest and shoulder plates, '
 'small round amber chest badge, brown leather gloves, belt, trousers and fur-cuffed brown boots. Exactly two arms, two hands and two legs. '
 'Hold ONE long straight rigid brown wooden pike with ONE broad steel spearhead on one end and ONE small metal butt spike on the other. '
 'The large spearhead and tiny butt spike NEVER swap ends, grow, bend or disappear. Hands grip the same continuous shaft naturally. '
 'No shield, sword, new weapon, extra limbs or equipment. Keep the original adult proportions, body size and painted materials. '
)
PLATE=(
 ' Locked orthographic camera and fixed body scale. Full body, hands and both pike ends stay inside the canvas. '
 'Perfectly flat uniform bright MAGENTA background throughout all frames. No changing background colors, scenery, shadow, '
 'camera motion, zoom, magic, glow, sparks, smoke or projectile. Boots remain grounded except the deliberately lifted walking or falling limb.'
)
def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f
TAKES={
 'move_h3_v1':([2],[],0,
  'Walk in place through two complete reciprocal gait cycles. Alternate near and far knees and boots through forward contact, loading, passing, lift and opposite contact. '
  'Both hands carry the pike diagonally with its broad spearhead toward upper screen right and butt toward lower screen left, without spinning it. '
  'Keep the torso centered for engine-driven travel, boots visibly lifting and planting, coat hem swaying gently. Finish in the starting gait phase.'),
 'attack_h3_v1':([13,7,4,5,6],[[25,1],[43,2],[64,3],[83,4],[102,1]],0,
  'Perform ONE two-handed pike thrust toward screen right. From ready with the broad spearhead upper left, smoothly rotate the entire rigid pike through upright '
  'until the broad spearhead points upper right, then lower it horizontally. Draw the shaft back beside the waist, bend both knees, then lunge and extend '
  'both arms in one forceful horizontal thrust to screen right. The front hand guides and rear hand drives the shaft; both remain attached. '
  'Retract after contact, straighten the legs, lift the same spearhead back through upright and recover the starting diagonal ready pose. No swinging slash or weapon throw.'),
 'hit_h3_v1':([13,9],[[43,1]],0,
  'Perform one compact physical recoil: shoulders pull backward, elbows flex, torso leans back and knees absorb the motion, then recover to ready. '
  'Retain the pike in both hands in the same upper-left broad-head orientation throughout. Boots stay planted. No visible attacker, impact ray or falling.'),
 'defend_h3_v1':([13,8],[[60,1]],1,
  'Lower into a wide stable defensive brace, bending knees and lowering the hips while both hands hold the pike firmly across the body. '
  'The broad spearhead remains at upper screen left, butt at lower right. Bring the elbows close and hold the final braced crouch. No attack or return to upright.'),
 'cast_h3_v1':([13,16],[[40,1],[72,1]],0,
  'Make a physical readiness signal, not a spell: draw both forearms upward and inward, lifting the diagonal pike slightly in a brief disciplined salute. '
  'Tighten and visibly readjust the two grips on the shaft, hold the salute, then lower the hands and pike back to ready. '
  'Keep the broad spearhead at upper left and the butt at lower right. Boots remain planted and shoulders articulate naturally.'),
 'death_h3_v1':([13,10,11,12],[[34,1],[83,2]],3,
  'Collapse continuously: knees buckle, lower onto one knee, then bring the torso and hip down toward screen right. '
  'The pike descends with the hands and rotates onto the ground, with the broad steel spearhead finally pointing right. '
  'The soldier rolls onto the side, head at screen right, boots extending left. Both hands release or rest naturally beside the grounded straight shaft. '
  'End as one fully grounded motionless body and one pike. No recovery, floating weapon, extra limb or disappearing equipment.'),
}
if __name__=='__main__':
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[255,0,255],
   protected_foreground_chroma=34,seed=2026092940+n,references=[ref(i) for i in indices],guides=guides,last=last,
   prompt=IDENTITY+action+PLATE,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.write(out/'config.json',c);p.prepare(out,c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
  visual_review=dict(status='pending',notes='Review all original chronological frames, pike endpoints/grips, anatomy, alpha, grounding and native scale before publication.')))
