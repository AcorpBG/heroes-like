"""Action-specific original ray guides; preserve the accepted eight-phase idle."""
import json
import numpy as np
from PIL import Image
import produce as p
UID='unit_neutral_tideglass_skyrays'
BASE=p.ROOT/'art/animation/source/poses'/UID
IDENTITY=('Original painted fantasy TIDEGLASS SKYRAY. One elongated blue-teal manta-like body, slender pointed snout facing SCREEN RIGHT, pale pearly eye markings, exactly TWO broad translucent crescent pectoral wings with dark teal veins and pale cream panels. Small pale dorsal fins stay attached above back; one long curling tail and original soft white/aqua trailing fin ribbons flow behind to screen left. Original brass/teal hanging resonator bell harness stays attached beneath belly, with large front bell and smaller rear bell; never add duplicate bells, eyes, legs, arms, horns or wings. No human rider, hands, weapons or text. Locked orthographic side three-quarter camera and unchanged painted style, proportions, facing and body scale. Preserve the existing exact ray silhouette and near/far wing identities. ')
PLATE=(' SOLID CHROMA BLUE RGB0,0,255 fills the WHOLE background for EVERY FRAME without any colour change. This blue plate remains pure blue, never teal, cyan, gray, a gradient or transparent. No floor, shadow, scenery, particles or camera motion. All body and attached fin ribbons stay inside frame. The virtual ground is y480; normal flight body stays centered, original trailing fins and bells move naturally. Movement is jointed wing flex, not global sprite wobble. Keep complete ray geometry, do not turn toward camera or resize. ')

def ref(index):
 f=dict(json.loads((BASE/'packing.json').read_bytes())['frames'][index]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 if index==15:
  # Existing corpse had transparent bottom padding below its physical body.
  # Register this one original guide to ground; never stabilize video per frame.
  im,offset=p.source_pose(f,8);delta=offset[1]+im.height
  f['anchor']=[f['anchor'][0],round(f['anchor'][1]+delta/f['scale'])]
 return f

def recipe(clip,indices,guides,last,action,seed):
 out=p.SOURCE_DIR/(clip+'_h3_v2');out.mkdir(exist_ok=True)
 c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,key_rgb=[0,0,255],seed=seed+100,references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.prepare(out,c);bands=[]
 for i in range(len(indices)):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);bands.append(int((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[a[:,:,3]>=245].max()))
 c['protected_foreground_chroma']=max(0,max(bands)+2);assert 255-c['protected_foreground_chroma']>=80
 p.write(out/'config.json',c);p.verify(out,c);p.write(out/'foreground_measurement.json',dict(blue_minus_max_red_green=bands,opaque_alpha_minimum=245,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

if __name__=='__main__':
 recipe('move',[16],[],0,'Two slow complete flying-in-place cycles. Broad NEAR and FAR crescent wings flex at their roots, sweep down to push air then fold slightly and lift for recovery; both remain distinct attached wings. Tail and soft fin ribbons follow the strokes with a natural delayed response; resonator bells swing on their unchanged harness. Torso stays centered at the original hover reference with no root travel. End at exact starting ready. ',2026104001)
 recipe('attack',[16,5,6],[[32,1],[64,2]],0,'One close-range ram. Draw head and body back slightly while wings load, then thrust original pointed snout forward SCREEN RIGHT once. Near/far wings sweep back coherently, tail and bell harness trail behind. Recover smoothly to original hover ready. No ranged projectile or new appendage. ',2026104002)
 recipe('ranged',[16,11,12,13,14],[[28,1],[48,2],[64,3],[88,4]],0,'One Glasswing Broadside release. Align both original crescent membranes into a long broadside, open and tension the two wings, then snap their roots and ringing belly bells forward once at the release pose. Attached bell glass brightens slightly; wing action and harness recoil make the release clear. Settle the bell swing and wings back into exact original hover ready. Do NOT draw any flying bolt, arrow, beam, detached mist cloud or projectile: the game renders projectile flight separately. ',2026104003)
 recipe('hit',[16,8],[[42,1]],0,'One brief impact recoil. Head and chest pull back, both wings flex protectively and original tail/ribbons and bells react to the impact. Recover into the exact original hover ready without collapse or rotating the body. ',2026104004)
 recipe('defend',[16,7],[],1,'Dedicated defensive brace. Fold the two attached crescent wings down and inward around the intact belly bell harness, tuck head behind their protective membrane edges, tail/ribbons curl close. Torso retains hover support. Hold this distinct guarded pose through the final second rather than returning ready. ',2026104005)
 recipe('cast',[16],[],0,'One resonator support signal, no invented humanoid casting. Lift and arch the TWO wing tips, tilt original head slightly upward and give the attached resonator bell harness one clear swinging ring. Original dorsal fins and soft trailing ribbons respond. Let the wings lower and bells settle to exact ready. No projectile, magic circle, cloud or detached particles. ',2026104006)
 recipe('death',[16,15],[],1,'One continuous loss of flight and grounded collapse. The two wings lose lift and fold down, elongated ray body descends and rolls a little onto its belly/side. Tail, dorsal fins, attached soft ribbons and bell harness settle with it. End with original head SCREEN RIGHT, tail SCREEN LEFT, flattened wing membranes and all body/bells/ribbons resting on virtual ground y480. Final second completely still. No shrinking, dissolving, new limbs, detached bells, hard cut or levitating corpse. ',2026104007)
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[c+'_h3_v2' for c in ['move','attack','ranged','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='All eight existing idle paintings inspected: two wing membranes flex, trailing fins and bell harness respond, consistent original ray identity. Preserve idle pixels/timing; new seven H3 actions require full chronological/native review. First magenta flight take rejected: background changed to teal too close to foreground; original retained. Blue-plate correction requires review.')))
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[480,480],ready_guide=ref(16),corpse_guide=ref(15),reason='Existing articulated eight-phase idle retained. Original scales retained per legacy source painting; all videos use one fixed .5 extraction. One corpse end guide registers physical body contact instead of legacy transparent bottom padding. No per-video-frame scale/anchor normalization.'))
