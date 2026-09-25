"""Original Prism Adept guides and seven separate H3 action briefs."""
import json
from pathlib import Path
SOURCE=Path(__file__).resolve().parent
UNIT='unit_sunvault_prism_adepts'
IDENTITY=(
 'Locked orthographic camera, original richly painted fantasy strategy sprite on uniform vivid GREEN RGB(0,255,0), including all limb gaps. '
 'One young adult human with short wavy brown hair, exposed clean-shaven face and gold goggles with violet lenses resting on the forehead. '
 'Exactly two arms and two legs. Long white split coat with gold edging and blue lining, white shoulder armor, brown belts and gloves, '
 'brown thigh leggings, white/gold knee plates with violet gems, brown boots, and a brown satchel with small blue/violet crystal instruments at the hip. '
 'One compact brass-and-gold crystal projector held across the waist pointing toward IMAGE RIGHT. It has a cylindrical rear, blue/violet round lenses, '
 'and one gold triangular frame with a solid blue/violet triangular prism at the front. This is one handheld instrument, not a staff or crossbow. '
 'RIGHT hand at the rear grip on IMAGE LEFT, LEFT hand under the front housing on IMAGE RIGHT. These are the only two hands. '
 'Maintain fixed housing length, triangular prism geometry, lenses, grips, coat, face, goggles and anatomy. '
 'Stable three-quarter RIGHT-facing view, full body visible, identical anatomical scale and ground registration, no camera zoom, pan or rotation. '
 'No scenery, cast shadow, text, lighting change, floating parts, muzzle flash, beam, projectile, particles, duplicate equipment or magical ring. '
)
ACTIONS={
 'move':([2],0,[],
  'Walk in place through two complete reciprocal walking cycles. Alternate both legs through forward contact, load, lift, passing and planting. '
  'Keep two distinct boots and knees, same torso position for engine travel. Hold the projector steadily in both hands; coat tails and satchel follow gently. '
  'Return naturally to the original contact phase, no hopping, sliding, leg merging or aiming.'),
 'defend':([18,12],1,[],
  'Lower smoothly into a protective crouch, bending both knees and keeping both feet under the body. Bring the projector close to the chest with both hands. '
  'Keep the head alert and the coat following the bent legs. Hold the final low guarded stance; no discharge, collapse or return upright.'),
 'hit':([18,13],0,[[40,1]],
  'One moderate hit from image right causes shoulders to recoil backward and knees to flex. Keep both hands firmly on the projector and its front pointing right. '
  'Regain balance gradually and return the torso, hands and feet to the original ready stance. No weapon release, instant snap, attack or collapse.'),
 'attack':([18,6,7],0,[[30,1],[58,2],[104,0]],
  'One short physical RIGHT fist punch toward image right. The LEFT hand continues supporting the projector at the waist. '
  'Release the rear grip with the right hand, draw the right elbow back and the fist beside the shoulder, then punch that same right fist forward. '
  'Retract the right fist along the same path, lower it and regrip the rear housing naturally. Keep exactly two arms and the projector unchanged. '
  'No projectile, weapon discharge, left-hand punch, new hand, weapon morph or teleporting grip.'),
 'ranged':([18,8,9,10],0,[[30,1],[56,2],[94,3]],
  'One aimed ranged firing action with the handheld crystal projector. Both hands raise the same projector from waist to shoulder level, '
  'aim the triangular front to image right, brace, then absorb one short backward and upward recoil through wrists, elbows and shoulders. '
  'Steady the projector, lower it and return smoothly to ready. The game draws the shot: absolutely no emitted beam, projectile, flash or expanding lens. '
  'Keep all lenses and the triangular front attached with unchanged size and exactly two hands.'),
 'cast':([18,9],0,[[52,1]],
  'One deliberate instrument calibration and support gesture. Plant both boots, lift the projector diagonally upward with BOTH hands, '
  'tilt the chin toward its prism and briefly present it high with bent elbows, then lower it smoothly to the original waist-level ready stance. '
  'This is a calm inspection and rally gesture, no recoil, punch, firing, light beam, particles or new effects. Visible elbow and shoulder articulation.'),
 'death':([18,14,15,16],3,[[38,1],[80,2]],
  'One continuous collapse. Both knees buckle and descend onto the ground; the torso tips toward image left while both hands lower the projector. '
  'Fall onto the side with head toward IMAGE LEFT and feet toward IMAGE RIGHT. Settle the head and body on the floor with the projector horizontal beside the chest. '
  'Keep the original two arms and legs, coat and satchel coherent and all equipment grounded. No spinning, teleporting, dismemberment or standing again. End still.'),
}
def pose(index):
 x,y=index%4*512,index//4*256
 return dict(source=f'art/animation/runtime/poses/{UNIT}.png',rects=[[x,y,x+512,y+256]],anchor=[x+256,y+248],scale=1,alpha_noise_cutoff=8)
if __name__=='__main__':
 for number,(clip,(indices,last,guides,action)) in enumerate(ACTIONS.items()):
  out=SOURCE/f'{clip}_v1';out.mkdir(exist_ok=True)
  assert not (out/'submission.json').exists()
  config=dict(unit_id=UNIT,clip=clip,scale=.8,anchor=[480,480],key_rgb=[0,255,0],protected_foreground_chroma=56,
   references=[pose(i) for i in indices],last=last,guides=guides,seed=925941+number,
   tiled_decode=dict(tile_size=256,overlap=64,temporal_size=16,temporal_overlap=4),prompt=IDENTITY+action)
  (out/'config.json').write_text(json.dumps(config,indent=2)+'\n')
 (SOURCE/'delivery.json').write_text(json.dumps(dict(takes=[],visual_review=dict(status='pending',notes='Source and native visual review required.')),indent=2)+'\n')
