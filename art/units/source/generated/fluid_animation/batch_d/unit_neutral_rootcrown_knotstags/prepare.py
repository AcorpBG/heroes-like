"""Original six-legged Knotstag action guidance; fixed scale and ground anchor."""
import json
import numpy as np
from PIL import Image
import produce as p
UID='unit_neutral_rootcrown_knotstags';LEGACY=p.ROOT/'art/animation/source/poses'/UID
FRAMES=json.loads((LEGACY/'packing.json').read_bytes())['frames']
IDENTITY=('ONE original Rootcrown Knotstag: a long-bodied SIX-LEGGED wooden stag, '
 'three pairs of legs, with two large claw-root front feet and four slimmer '
 'bark hind/middle hoof legs. Near and far limbs remain anatomically attached; '
 'far legs may be occluded naturally but never disappear or fuse. Brown layered '
 'bark body, pale gray bark flank plates, shaggy green/gold foliage mane, leaf '
 'tufts on joints and curved vine tail. Deer muzzle faces SCREEN RIGHT, amber '
 'eye and narrow pointed ears. ONE wide, branching wooden antler crown carries '
 'exactly THREE attached amber seed lanterns, one center and one each side, '
 'with original green leaves. Keep every branch, three hanging pods, eye, '
 'root claws, leaf mane, tail and six-leg proportions unchanged. No humanoid '
 'arms, reins, rider, weapon or additional lantern. ')
PLATE=(' Locked original elevated three-quarter orthographic camera facing '
 'SCREEN RIGHT. Fixed body size, centered root. Entire antler crown and all '
 'feet remain inside960x544 with generous margins. Flat uniform BLUE RGB0,0,255 '
 'backdrop EVERY frame; no ground, scenery, shadow, particles, floating leaves, '
 'aura, text, zoom or camera motion. Amber pods keep original painted warm '
 'color, never emit effects. Only original creature anatomy moves. ')
def ref(i):
 f=dict(FRAMES[i]);f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8;return f
def config(clip,refs,guides,last,action,seed):
 out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
 c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,
  key_rgb=[0,0,255],seed=seed,references=refs,guides=guides,last=last,
  prompt=(IDENTITY+action+PLATE).strip(),protected_foreground_chroma=0,
  tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.prepare(out,c);measure=[]
 for i in range(len(refs)):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int)
  measure.append(int((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[a[:,:,3]>=245].max()))
 c['protected_foreground_chroma']=max(measure)+2;assert 255-c['protected_foreground_chroma']>=80
 p.write(out/'config.json',c);p.verify(out,c)
 p.write(out/'foreground_measurement.json',dict(blue_minus_max_red_green=measure,
  opaque_alpha_minimum=245,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))
if __name__=='__main__':
 config('idle',[ref(16),ref(19),ref(21)],[[34,1],[72,2]],0,
  'One quiet idle cycle. Keep middle and rear hooves planted. Flex the near '
  'large FRONT root wrist and lift its toes slightly, then settle it back down. '
  'Neck raises slightly34, ears turn, attached seed pods sway from their '
  'branches, leafy shoulder mane and tail respond72. Return smoothly to exact '
  'initial ready. Visible articulated foreleg and neck motion, no whole-body '
  'bobbing or rigid rocking. No walking or spell. ',2026102901)
 config('move',[ref(16),ref(3),ref(4),ref(5),ref(6)],[[20,1],[42,2],[66,3],[88,4]],0,
  'One slow six-legged WALK IN PLACE. Alternate the near and far groups '
  'through lift, forward passing, root-claw/hoof contact and weight loading. '
  'Three original leg pairs remain attached. Flex both large FRONT root '
  'wrists in opposed phases while middle and hind hooves cycle. Neck, mane '
  'and vine tail respond to weight transfer; antler crown and all three '
  'pods remain stable. Complete opposite support phases and return to ready. '
  'No foot sliding, galloping, jumping or repeated same-leg lift. ',2026102902)
 config('attack',[ref(16),ref(7),ref(8),ref(9)],[[24,1],[46,2],[88,3]],0,
  'One close-range crown SWEEP. Load weight and lower the wooden antler '
  'crown24 with a supported knee/wrist bend. Drive neck and crown forward '
  'SCREEN RIGHT46, keeping three pods attached and all branches complete. '
  'Recover progressively88, lifting neck back to ready. Large front root '
  'feet support the thrust, hind legs stay grounded. No projectile, weapon '
  'or detaching antlers; the contact is the crown sweep. ',2026102903)
 config('hit',[ref(16),ref(12)],[[20,0],[40,1],[78,0]],0,
  'One brief backward recoil. Chest and neck lean back40, all three '
  'attached lanterns sway naturally, six legs flex to absorb impact. Then '
  'recover78 into ready. Keep original root feet and slim hind hooves; '
  'no collapse, incoming attacker or camera shift. ',2026102904)
 config('defend',[ref(16),ref(11)],[[38,1]],1,
  'One dedicated low brace. Bend six legs and lower head/crown38, large '
  'front root feet spread only slightly with supported weight. Tuck neck '
  'behind protective antler crown; all three pods remain attached. HOLD '
  'guarded low stance through the end as foliage settles. No forward '
  'attack and no return to ready. ',2026102905)
 config('cast',[ref(16),ref(1)],[[48,1],[94,0]],0,
  'One physical rally gesture, NOT magic. Lift the near large FRONT root '
  'foot slightly and fold its wrist while other five limbs support the '
  'body. Raise neck and antler crown48 as if giving a silent woodland '
  'signal, turn pointed ears, then lower that same front root foot and '
  'return94 to ready. Crown pods stay their original warm painted color, '
  'no light pulse, particle, staff or spell. ',2026102906)
 config('death',[ref(16),ref(15)],[],1,
  'One uninterrupted physical collapse. All six knees/root wrists slowly '
  'buckle, shoulder descends, support gives way and long bark torso rolls '
  'onto its side. Head/crown finish SCREEN RIGHT and hind legs extend '
  'SCREEN LEFT, large front roots fold in front. Antlers descend with '
  'the neck onto the ground without detaching. Three original pods stay '
  'attached and become dark like final reference. Leaves and tail settle '
  'into a grounded corpse; final second motionless. Every transition '
  'continuous, no hard cuts, shrinking or hovering legs. ',2026102907)
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,
  output_scale=.5,ground_anchor=[480,480],original_source_scales=[.62,.18,.3,.48],
  reason='Original scale/anchors preserved for all guides, fixed extraction .5. Standing ready214px; crouch and corpse retain proportions without pose normalization.'))
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[c+'_h3_v1' for c in ['idle','move','attack','hit','defend','cast','death']],
  preserved_accepted_clips=[],visual_review=dict(status='pending',notes='Solo original Rootcrown Knotstags. Previous gait repeats planted poses; replace all deficient actions and improve articulated idle. Require temporal, six-leg/crown identity, native-scale and actual shell-clock review.')))
