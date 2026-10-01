"""Original Parallax Fencer guides with fixed anatomical scale and green plate.

The accepted eight-pose idle (idle-v2 hands) sets the body size. The older
continuity paintings were packed about 12.5% taller than that idle, so every
continuity reference receives the same whole-painting factor before guide
composition. One factor for all of them, never per pose; the measured standing
heights are recorded in each config.
"""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID = 'unit_sunvault_splitprism_parallax_fencers'
BASE = p.ROOT / 'art/animation/source/poses' / UID
PACK = json.loads((BASE / 'packing.json').read_bytes())
# Standing head-top above ground anchor at packing scale: accepted idle_hands_0
# 197px, legacy idle_0 225px and idle_1 227px. 197/225.5 = 0.874.
CONTINUITY_FACTOR = 0.875
IDENTITY = ('One original Parallax Fencer, a young adult woman duelist with warm tan skin and curly brown hair gathered into a bun, '
 'a white-and-gold diadem visor with a blue crystal emblem across her forehead, a fitted white plated jacket with gold trim '
 'and blue diamond shoulder emblems, a blue scarf, long blue sash panels hanging from a gold-buckled belt, white padded trousers '
 'and white-and-gold armored knee boots. Her forward hand toward screen right grips ONE long slender translucent blue crystal sword '
 'by its gold guard. Her rear hand at screen left grips ONE short golden flame-shaped dagger pointing down and back. '
 'Exactly two arms, two legs and two blades. Preserve the face, hair, blade lengths, both grips and the blue sash throughout. ')
PLATE = (' Locked elevated three-quarter orthographic camera at the reference angle, fixed anatomical scale and centered root. '
 'The entire fencer and both blades stay visible. Uniform pure saturated green RGB0,255,0 fills all surrounding pixels throughout. '
 'Keep clothing and blades attached, physical joints and stable foot contacts. No glow bursts, trails, sparks or magic effects.')
# Packing indices: 14 idle_hands_0 (accepted idle), 3 walk_passing_a (rear leg
# passing), 5 walk_passing_b (front knee raised), 6 melee_windup, 7 melee_thrust,
# 8/9 defend, 10 hit_recoil, 11 death_buckle, 12 death_fall, 13 dead,
# 17 idle_hands_3 (accepted idle, blade raised).
TAKES = {
 'move_h3_v1': ([14,3,5], [[18,1],[36,2],[54,1],[72,2]], 0,
  'Walk briskly in place through reciprocal stride cycles that match the supplied passing poses. '
  'First the rear leg at screen left lifts its knee and swings forward under the hips while the front leg supports her weight, then plants. '
  'Next the front leg lifts its knee forward toward screen right while the rear leg supports, then plants. Repeat both steps, '
  'keep walking in the same rhythm, then settle into the starting stance. Hips stay centered over the same spot. '
  'The crystal sword stays pointed forward and down toward screen right, the golden dagger stays low behind; the sash panels swing with each step.'),
 'attack_h3_v1': ([14,6,7], [[30,1],[52,2]], 0,
  'Perform one fencing lunge. Draw the crystal sword back level beside the chest with the elbow bent as in the first middle reference. '
  'Then drive forward: the front foot steps toward screen right, the front knee bends deeply, the rear leg straightens, '
  'and the sword arm extends fully so the crystal blade thrusts straight forward at chest height as in the second middle reference. '
  'Hold the extended thrust briefly, then push back off the front foot and recover into the starting ready stance. '
  'The golden dagger stays in the rear hand, low behind the body. One continuous grip on each blade.'),
 'hit_h3_v1': ([14,10], [[20,1],[34,1]], 0,
  'Perform one sharp recoil from a blow as a solitary fencer. The head and shoulders jolt backward away from screen right, '
  'the torso leans back and both knees yield while both feet stay planted, as in the middle reference. Both blades stay in their hands. '
  'Then regain balance, straighten and return to the starting ready stance. The full scene contains only this fencer against the uniform green plate.'),
 'defend_h3_v1': ([14,8,9], [[36,1]], 2,
  'Raise the crystal sword into a high diagonal parry guard. Lift the sword hand to shoulder height with the blade angled up and forward '
  'across the front of the body, bend both knees and settle the weight back, keeping the golden dagger low behind as a second guard. '
  'End holding the guarded stance with both boots grounded, without returning to ready.'),
 'cast_h3_v1': ([14,17], [[34,1],[58,1]], 0,
  'Perform a crisp duelist salute to rally allies. Raise the crystal sword so its gold guard comes up before the chest and the blade points upward, '
  'as in the middle reference, nod firmly and hold the salute briefly, then sweep the blade down and forward back to the starting ready stance. '
  'The golden dagger stays low in the rear hand. A nonmagical physical gesture only.'),
 'death_h3_v1': ([14,11,12,13], [[34,1],[66,2]], 3,
  'Perform one continuous defeat collapse. The knees buckle and she drops onto one knee with the head bowed and the sword tip lowering to the ground, '
  'as in the first middle reference. Then she topples sideways onto her hip and side with the head toward screen right, as in the second middle reference. '
  'Finish lying still on her side in the supplied final corpse pose, the crystal sword lying beside her forward hand and the golden dagger beside her rear hand. '
  'Exactly two blades remain. Maintain continuous body motion through the fall.'),
}

def ref(i):
 f = dict(PACK['frames'][i])
 f['source'] = (BASE / f['source']).relative_to(p.ROOT).as_posix()
 f['alpha_noise_cutoff'] = 8
 if not f['source'].split('/')[-2] == 'idle-v2':
  f['packing_scale'] = f['scale']
  f['scale'] = round(f['scale'] * CONTINUITY_FACTOR, 5)
  f['scale_reason'] = 'Continuity painting matched to accepted idle-v2 body size by one shared factor 0.875 (standing head-top 197px idle vs 225.5px legacy).'
 return f

if __name__ == '__main__':
 thumbs = []
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out = p.SOURCE_DIR / name
  out.mkdir(exist_ok=False)
  c = dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,
   key_rgb=[0,255,0],seed=2026100140+n,references=[ref(i) for i in indices],guides=guides,last=last,
   prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c)
  bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float)
   mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
   thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
  visual_review=dict(status='pending',notes='Review both blade grips and lengths, reciprocal gait, lunge contact and recovery, recoil, held parry, physical salute, continuous fall, alpha and native scale. Preserve reviewed eight-pose idle.')))
 target=p.ROOT/'.artifacts/parallax_h3_20261001';target.mkdir(parents=True,exist_ok=True)
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(target/'guides.png')
