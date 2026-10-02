"""Two narrow original motion repairs; prior videos remain immutable."""
import json
import numpy as np
from PIL import Image
import produce as p
import prepare
def make(clip,refs,guides,last,description,seed):
 out=p.SOURCE_DIR/(clip+'_h3_v2');out.mkdir(exist_ok=True);assert not (out/'submission.json').exists()
 c=dict(unit_id=prepare.UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,key_rgb=[0,255,0],seed=seed,references=refs,guides=guides,last=last,prompt=(prepare.IDENTITY+description+prepare.PLATE).strip(),protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4));p.write(out/'config.json',c);p.prepare(out,c)
 measured=[]
 for i in range(len(refs)):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);opaque=a[:,:,3]>=245;measured.append(int((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[opaque].max()))
 c['protected_foreground_chroma']=max(measured)+2;p.write(out/'config.json',c);p.verify(out,c);p.write(out/'foreground_measurement.json',dict(opaque_alpha_minimum=245,original_guide_green_minus_max_red_blue=measured,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))
if __name__=='__main__':
 make('attack',[prepare.ref(13),prepare.ref(6),prepare.ref(7)],[[26,1],[62,2],[100,0]],0,'One PLAIN SLOW LEFT ARM shoulder mobility exercise with the original axe. RIGHT hand keeps original lantern standard vertical and still, its central ring and TWO small hanging lanterns unchanged. LEFT hand slowly lifts original axe upward/back26, then smoothly lowers it downward and forward62, then lifts it back into original low resting grip100. Axe remains solid, sharp and unchanged length in every frame, exactly ONE steel blade and ONE wood shaft. The left FOREARM shield follows that SAME real left arm, no separate hand or limb supporting it. Show every intermediate elbow and wrist rotation at moderate even speed. This is a quiet mobility demonstration, not a combat strike: ABSOLUTELY NO SWING ARC, motion trail, afterimage, blur, dust, sparks, ghost axe or other visual effect. Background must remain completely flat green around all moving equipment.',2026102312)
 make('defend',[prepare.ref(13),prepare.ref(8)],[[18,0],[40,1]],1,'One slow supported partial KNEE BEND while raising the LEFT FOREARM shield closer to chest. RIGHT hand continuously holds EXACTLY SAME wooden lantern standard upright at same height; RIGHT elbow bends naturally as hips lower, shaft stays rigid and original central brass lantern RING, finial and BOTH small hanging lamps retain their exact size and shape. Do NOT simplify, shrink, reshape or lift lantern head. Original LEFT hand still holds lowered axe as shield remains attached to SAME LEFT forearm. Both knees bend gradually18-40 into supplied supported wide shield guard. HOLD final guard. Quiet physical posture demonstration, no magic, strike, waving standard, moving camera, prop deformation or effects.',2026102314)
 p.write(p.SOURCE_DIR/'correction_review.json',dict(status='pending',rejected={'attack_h3_v1':'Baked axe swing arc and over-emphasized release, source42-45; preserve original, regenerate slow articulated clean movement.','defend_h3_v1':'Lantern head simplified/shrunk during transition21-36; regenerate steady original standard and clear shield brace.'},retained_candidates=['move_h3_v1','hit_h3_v1','cast_h3_v1','death_h3_v1']))
