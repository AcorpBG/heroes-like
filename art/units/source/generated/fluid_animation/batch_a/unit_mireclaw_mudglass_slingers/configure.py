"""Original pose guides and action briefs for Mudglass Slingers H3 production."""
import json
from pathlib import Path

SOURCE=Path(__file__).resolve().parent
UNIT='unit_mireclaw_mudglass_slingers'
IDENTITY=(
 'Locked camera, original richly painted fantasy strategy game sprite on a perfectly uniform flat vivid GREEN RGB(0,255,0) background. '
 'The background stays the identical solid green throughout, including inside sling cords and between limbs. No scenery, colored lighting, shadows, text or particles. '
 'One adult human female Mudglass Slinger, brown hair in a long loose ponytail with yellow reed ornaments, green cloth scarf covering mouth and nose, olive and brown layered leather clothing, '
 'ochre-yellow reed fringe on both shoulders and legs, brown wrapped boots, small round pale shell charms across belt, one brown ammunition pouch at IMAGE RIGHT hip. '
 'Exactly TWO arms and TWO legs. The IMAGE LEFT hand holds the two dark leather cords of ONE small traditional sling; its single brown/gold leather pouch hangs below that hand. '
 'The IMAGE RIGHT hand is the free hand, normally near her belt pouch. Preserve the same face, scarf, hair, shoulder fringe, belt charms, sling cords and pouch, and boots. '
 'No staff, bow, shield, sword, extra sling, duplicated hand or additional limb. Stable three-quarter RIGHT-facing camera, no camera rotation, zoom or root translation. '
 'Full figure and sling remain visible at the same anatomical scale throughout. No background hue cycling or transitions. '
)
ACTIONS={
 'move':([17],0,[[62,0]],
  'Walk in place through two reciprocal human walking cycles. First one foot swings forward and plants heel then toe while the other supports; then the OTHER leg swings and plants. '
  'Both legs have distinct passing, swing and grounded support phases. Pelvis transfers weight, torso stays centered, scarf and ponytail sway gently. '
  'The IMAGE LEFT hand retains the dangling sling and its weighted leather pouch; its two cords sway gently rather than becoming rigid. Free hand swings a little by her belt. '
  'Cross the original ready stance at the middle guide and return to ready at the end. No hopping, sliding, foot swaps or changing direction.'),
 'attack':([17,6,7],0,[[30,1],[60,2],[104,0]],
  'One close-range unarmed punch with the FREE IMAGE RIGHT hand. Draw that fist back near shoulder and load the rear leg, drive the fist toward IMAGE RIGHT with shoulder/hip rotation, '
  'then withdraw the fist and smoothly restore the original ready stance. The IMAGE LEFT sling hand stays down beside the body holding the same dangling sling. '
  'Do not throw, spin or strike with the sling during this melee punch. No projectile or magic. Continuous windup, contact and recovery.'),
 'ranged':([17,10,11,12,13],0,[[24,1],[49,2],[70,3],[98,4]],
  'Perform ONE traditional sling throw toward IMAGE RIGHT. The free IMAGE RIGHT hand seats a stone into the sling pouch, then returns toward the belt. '
  'The IMAGE LEFT sling hand lifts above the head and swings the loaded sling through a clear overhead arc. At release the throwing arm follows through toward IMAGE RIGHT, '
  'one cord end releases so the two cords open into the supplied trailing empty sling pose. The projectile itself is NOT drawn: the game supplies the flying stone separately. '
  'After release, recover the loose cord with the free hand, bring the sling back down and return to the ready pose. Keep one pouch and two flexible cords, '
  'with the same throwing hand throughout. No bow, gun, extra sling, duplicated cord bundles, free-flying painted rock or magic. Show all intervening arm motion continuously.'),
 'defend':([17,8],1,[[65,1]],
  'Lower into a defensive crouch while bringing the FREE IMAGE RIGHT forearm across the face/chest to guard. Both knees bend and feet retain support. '
  'The IMAGE LEFT hand keeps the same sling low beside the body, with pouch above or resting near the ground. Hold the final crouched guard. '
  'No shield, attack, sling spin or return to idle at the end. Continuous bracing transition.'),
 'hit':([17],0,[],
  'One moderate physical hit from IMAGE RIGHT. Animate continuously: head and shoulders recoil away, knees soften, the free hand opens reflexively, '
  'then the torso and head gradually regain balance and return to the original ready stance. Both boots stay planted. The IMAGE LEFT hand keeps the sling, '
  'whose pouch swings with inertia and settles. No frozen pose holds, cuts, instant resets, extra reactions, weapon attack or collapse. Show a gradual articulated recovery.'),
 'cast':([17,20],0,[[58,1]],
  'Perform ONE physical rally/support gesture, not spellcasting. Close the FREE IMAGE RIGHT hand into a fist, bring it firmly up to the upper chest and give a decisive nod. '
  'Square the shoulders, hold briefly, then lower that hand back to the belt in the original ready pose. The IMAGE LEFT hand holds the sling down at her side throughout. '
  'Feet stay planted; the elbow and fist move clearly. No punch toward the opponent, throwing, light, runes or particles. Continuous raise and recovery.'),
 'death':([17,14,16],2,[[36,1],[100,2]],
  'One continuous collapse. Knees lose support and lower to the kneeling guide, free IMAGE RIGHT hand reaches to the ground. '
  'Then the torso pitches toward IMAGE RIGHT; legs fold/extend toward IMAGE LEFT as she settles onto her side with head IMAGE RIGHT, matching the final corpse. '
  'The IMAGE LEFT hand lowers the same sling with the body; both cords and its pouch settle flat on the ground in front. Scarf and clothing stay on. '
  'Exactly two arms and legs, no roll that reverses the corpse orientation, no standing again. Finish motionless, body and sling grounded.'),
}

def pose(index):
 x,y=index%4*512,index//4*256
 return dict(source=f'art/animation/runtime/poses/{UNIT}.png',rects=[[x,y,x+512,y+256]],anchor=[x+256,y+236],scale=1.03 if index<17 else 1,alpha_noise_cutoff=8)

if __name__=='__main__':
 for number,(clip,(indices,last,guides,prompt)) in enumerate(ACTIONS.items()):
  target=SOURCE/f'{clip}_v1';target.mkdir(exist_ok=True)
  assert not (target/'submission.json').exists(),'Submitted takes are immutable'
  config=dict(unit_id=UNIT,clip=clip,scale=.8,anchor=[480,480],key_rgb=[0,255,0],protected_foreground_chroma=32,
   references=[pose(i) for i in indices],last=last,guides=guides,seed=925601+number,
   tiled_decode=dict(tile_size=256,overlap=64,temporal_size=16,temporal_overlap=4),prompt=IDENTITY+prompt)
  (target/'config.json').write_text(json.dumps(config,indent=2)+'\n')
 (SOURCE/'delivery.json').write_text(json.dumps(dict(takes=[f'{c}_v1' for c in ACTIONS]),indent=2)+'\n')
