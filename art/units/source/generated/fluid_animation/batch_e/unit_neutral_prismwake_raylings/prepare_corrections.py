"""Narrow original-guide corrections; immutable v1 sources remain preserved."""
import json,sys
import produce as p
from prepare import reference,IDENTITY,PLATE

def master(path,box,anchor,scale,reason):
 return dict(source=(p.SOURCE_DIR/'guides'/path).relative_to(p.ROOT).as_posix(),rects=[box],anchor=anchor,scale=scale,alpha_noise_cutoff=8,guide_registration_reason=reason)

def run():
 reason='Original generated guide master with one fixed anatomical scale0.43 for all of its poses; whole-reference placement aligns the single-eye hover origin without geometry changes. No output frame stabilization or per-frame scaling.'
 up=master('flight_jab_v2.png',[0,0,768,512],[475,498],.43,reason)
 down=master('flight_down_v2.png',[0,0,1536,1024],[814,822],.3,'Original single downstroke guide at fixed anatomical scale0.30, measured25x30 reference-eye match. Whole-reference registration only; both broad fins physically descend and all3 leaf tails remain attached.')
 wind=master('flight_jab_v2.png',[0,512,768,1024],[494,902],.43,reason)
 # Separate the lower-right original figure from the upper-right figure's
 # leaf tips crossing the row boundary; all contact anatomy starts below560.
 contact=master('flight_jab_v2.png',[768,560,1536,1024],[1189,940],.43,reason)
 specs=[('move',[reference(16),up,down],[[36,1],[76,2]],0,2026100341,'ONE slow continuous FLIGHT IN PLACE fin-beat cycle only. Begin raising BOTH broad fins smoothly from ready during the first second, continue through the supplied high upstroke, rotate both fin roots down into the low power stroke, then raise gently back to the exact ready. Core, eye diameter, head camera and full long beak stay steady; three separate leaf tails trail naturally. Continuous articulation between the supplied states, no static wait then pose jump, repeated cycles, body rotation or global bounce. '),('attack',[reference(16),wind,contact,reference(19)],[[32,1],[60,2],[92,3]],0,2026100342,'ONE deliberate close-range physical BEAK JAB, no flight wing-beat cycles. Slowly sweep BOTH broad fins backward and lean the core slightly back into the supplied windup, then lean forward so the SAME rigid full-length attached beak thrusts SCREEN RIGHT into one contact. Keep both fins swept back during contact. Withdraw the core and return to ready once. Exactly THREE separate visible leaf-ended tendrils follow this one lean/strike; none vanish, shorten, merge into fins or change their attachment. Single eye and head camera remain stable. No repeated attacks, fin flapping, nose contraction, projectile or effects. ')]
 hit=master('hit_guard_v2.png',[0,0,1086,724],[675,577],.3,'One fixed whole-master scale0.30 for both original recoil/guard paintings; one root registration places recoiling eye24px back and5px up without altering anatomy.')
 guard=master('hit_guard_v2.png',[1086,0,2172,724],[1660,640],.3,'One fixed whole-master scale0.30 for both original recoil/guard paintings; one root registration preserves original hover-eye position and full beak length.')
 specs.extend([('hit',[reference(16),hit],[[44,1]],0,2026100343,'ONE modest impact recoil. Lean the core slightly back, tilt the SAME ONE full-length attached beak up toward SCREEN RIGHT, bend the TWO broad fins into a brace and let all THREE separate leaf-ended tendrils curl behind. Then recover once to original ready. No extra pointed shape under the face, second beak, repeated fin beats, head spin or collapse. '),('defend',[reference(16),guard],[[58,1]],1,2026100344,'ONE physical FIN GUARD. Smoothly bend both broad rainbow membrane fins inward beside the same single eye and ivory/gold core, keeping both fins visibly distinct, the entire original long beak down-right and all THREE attached leaf-ended tendrils separate. The body keeps its original camera, size and head volume. Settle into the supplied protective guard and remain there during the final second. No sphere, shell replacement, shrinking, lost fins, idle return or effects. '),('cast',[reference(16),up,reference(19),reference(20)],[[32,1],[68,1],[96,2]],0,2026100345,'ONE deliberate physical SUPPORT SALUTE. Raise BOTH broad rainbow fins into the supplied wide attentive flare, hold that physical display with a small bow of the original long beak as a rally cue, then lower both fins and return to ready once. All THREE attached separate leaf-ended tendrils spread and settle. Original single-eye brightness remains steady; this is not a spell, flight-cycle repetition or global sprite bounce. No added light, symbols, pulses or magic objects. ')])
 specs.append(('ranged',[reference(16),reference(13),reference(14),reference(16)],[[36,1],[64,2],[96,3]],0,2026100346,'ONE coordinated original PRISMWAKE LENS RELEASE cue. Raise TWO broad rainbow membrane fins into the supplied V charge, focus the existing SINGLE blue eye/core within its original rim, open both fins into one clear forward release cue, then recover directly to the exact original ready painting. All THREE attached leaf-ended tendrils retain their original length and separate tips. The long beak, gold borders and single eye retain their original anatomy/camera. Only the existing eye briefly brightens; no new orb, pupil, particles, projected beam or baked projectile. The game owns projectile flight. '))
 selected=sys.argv[1:]
 for clip,refs,guides,last,seed,action in specs:
  if selected and clip not in selected:continue
  out=p.SOURCE_DIR/(clip+'_h3_v2');out.mkdir(exist_ok=True)
  c=dict(unit_id=p.SOURCE_DIR.name,clip=clip,canvas=[960,640],anchor=[480,568],scale=.5,key_rgb=[210,210,210],seed=seed,references=refs,guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  if (out/'sampling_submission.json').exists():
   assert json.loads((out/'config.json').read_bytes())==c,'Submitted correction immutable'
   p.verify(out,c);print('PRESERVED_SUBMITTED_CORRECTION',out.name);continue
  p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c);print('CORRECTED_GUIDES_PREPARED',out.name)
if __name__=='__main__':run()
