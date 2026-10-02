"""Correct the inherited four-leg guide error using the actual six-leg identity."""
import json
import numpy as np
from PIL import Image
import produce as p
from prepare import UID,IDENTITY,PLATE
CURATED=p.ROOT/'art/units/source/curated'/f'{UID}.png'
def original():
 return dict(name='original_six_leg_identity',source=CURATED.relative_to(p.ROOT).as_posix(),rects=[[0,0,512,512]],anchor=[256,488],scale=.45,alpha_noise_cutoff=8)
def recipe(clip,last,action,seed):
 out=p.SOURCE_DIR/(clip+'_h3_v2');out.mkdir(exist_ok=True)
 refs=[original()]
 if clip=='death':
  # Folded far-side limbs naturally occlude in the original grounded corpse;
  # this end reference does not guide any standing or walking anatomy.
  legacy=p.ROOT/'art/animation/source/poses'/UID
  f=dict(json.loads((legacy/'packing.json').read_bytes())['frames'][15]);f['source']=(legacy/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8;refs.append(f)
 c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,key_rgb=[0,0,255],seed=seed,references=refs,guides=[],last=last,prompt=(IDENTITY+action+PLATE).strip(),protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.prepare(out,c);measure=[]
 for i in range(len(refs)):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);measure.append(int((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[a[:,:,3]>=245].max()))
 c['protected_foreground_chroma']=max(measure)+2;assert 255-c['protected_foreground_chroma']>=80
 p.write(out/'config.json',c);p.verify(out,c);p.write(out/'foreground_measurement.json',dict(blue_minus_max_red_green=measure,opaque_alpha_minimum=245,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))
if __name__=='__main__':
 for t in p.SOURCE_DIR.glob('*_h3_v1'):
  p.write(t/'review.json',dict(status='rejected',reason='Inherited legacy standing/gait guides have only four visible anatomical leg chains instead of the curated original six. Confirmed in all124 idle and move frames; every v1 action starts from that same wrong guide. Preserve originals; no v1 action published. Correction uses the actual six-legged curated identity and removes four-leg standing temporal guides.'))
 recipe('move',0,'One deliberate SIX-LEGGED WALK IN PLACE. Three distinct leg PAIRS: front large root-claws, middle slender hoof pair, rear slender hoof pair. The middle pair is visible beneath the belly and MUST remain present throughout, separately from rear legs. Alternate near and far legs through supported lift, passing, extension, contact and loading. Keep several original feet planted at every phase. Walk slowly, root centered, return to exact starting ready. No turning, galloping, sliding or removing the middle pair. ',2026103002)
 recipe('idle',0,'One quiet idle cycle. All SIX original legs remain visible as three attached pairs, with the middle pair beneath the belly separate from rear hooves. Flex and lift the near FRONT claw-root wrist slightly, then set its toes down. Other five feet keep supported weight. Neck/ears, attached three pods and leafy mane respond gently. Return to exact ready. No walking, whole-body rocking, or missing middle leg pair. ',2026103001)
 recipe('attack',0,'One supported close-range crown SWEEP. First lower neck/crown and load weight into SIX legs. Drive original antler crown forward SCREEN RIGHT once while knees/root wrists flex. Keep middle legs beneath the belly separate from hind legs, all three pods attached. Recover neck/crown smoothly into exact ready. No projectile or detaching branches, no walk and no removing a leg pair. ',2026103003)
 recipe('hit',0,'One brief backward recoil and gradual recovery. Neck and chest lean back, SIX attached legs flex to absorb impact while keeping support. Middle pair stays present separately beneath belly. Crown pods sway with antlers, root toes and rear hooves remain intact. Return smoothly into exact ready, no fall or missing limbs. ',2026103004)
 recipe('defend',None,'One dedicated held defensive brace. Lower shoulder, head and crown as SIX knees/root wrists bend. Original front roots bear weight, middle pair beneath belly and hind pair remain separately attached. Neck tucks behind complete protective crown. Hold low guard through final second; all three pods attached. No return to ready, attack, extra limb or missing middle pair. ',2026103005)
 recipe('cast',0,'One physical woodland rally, not magic. Lift the near large FRONT root claw and fold its wrist, while the other FIVE legs support the long body. Raise neck/crown as a silent signal, move ears, then lower the same root foot and return smoothly into ready. Middle slender pair remains beneath belly throughout, separate from rear legs. No light pulse or spell. ',2026103006)
 recipe('death',1,'One uninterrupted supported collapse. All SIX attached leg chains buckle progressively; middle pair folds under belly, rear pair extends SCREEN LEFT, front root-claws fold ahead. Long torso descends and rolls onto side, head/crown end SCREEN RIGHT on ground. Far limbs may occlude only as body physically settles onto side. Three attached pods darken to final corpse. Original full antler crown, tail and all folded legs settle; final second still. No hard cuts, body shrinking, detached branch or hovering. ',2026103007)
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[480,480],curated_source_scale=.45,curated_source_anchor=[256,488],reason='Actual six-leg original identity replaces deficient four-leg legacy ready/gait guides. Fixed .45 original identity scale gives~213px full silhouette, matching prior~214px ready. All H3 frames use fixed .5 extraction and root480,480; no per-pose normalization. Original folded corpse guide retains .62 scale.'))
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[c+'_h3_v2' for c in ['idle','move','attack','hit','defend','cast','death']],preserved_accepted_clips=[],visual_review=dict(status='pending',notes='Corrected curated six-leg guidance replaces inherited four-leg reference problem. Seven v1 originals retained but rejected. Need review of all new action footage, middle pair continuity, three crown pods and grounding before acceptance.')))
