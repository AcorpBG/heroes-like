"""Create original two-hook action guides; preserve accepted articulated idle."""
import json
import numpy as np
from PIL import Image
import produce as p
UID='unit_neutral_frostwharf_cutters'
LEGACY=p.ROOT/'art/animation/source/poses'/UID
FRAMES=json.loads((LEGACY/'packing.json').read_bytes())['frames']
IDENTITY=('One original Frostwharf Cutter, dark-haired adult human man, exactly TWO arms and TWO legs, TWO short silver hooked blades with brown grips, one in each gloved hand. Navy blue winter coat with brass trim/buttons, cream fur collar, blue scarf, rope waist belt with red/white/blue charms and chains, dark trousers and brown rope-wrapped boots with original metal ice-claw toes. Face and gaze toward screen right. Screen-left arm and screen-right arm each hold their OWN original hook continuously; hooks remain short original steel shapes, never long scythes or new swords. Original human anatomy, face, costume, grips and equipment remain coherent. ')
PLATE=(' Locked original elevated three-quarter orthographic camera, full body and BOTH hook tips inside960x544 with generous margins, fixed anatomical body scale and centered root. Uniform saturated GREEN RGB0,255,0 backdrop EVERY frame, no floor, gradient, ground shadow, text, other characters, smoke, glow, flashes, lines or magic. Actual joints, not whole-sprite warping; never add equipment or duplicate limbs. ')

def ref(index):
 f=dict(FRAMES[index]);f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 if f['source'].endswith('alpha/poses.png'):f['scale']*=.86
 elif 'continuity-alpha/' in f['source']:f['scale']*=.85
 return f

def walk(index):
 return dict(name=['opposed_passing','opposed_contact'][index],source=(p.SOURCE_DIR/'walk_guides.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,887,887]] if index==0 else [[887,0,1774,887]],anchor=[[485,829],[1360,829]][index],scale=.238,alpha_noise_cutoff=8)

def config(clip,references,guides,last,description,seed):
 c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,key_rgb=[0,255,0],seed=seed,references=references,guides=guides,last=last,prompt=(IDENTITY+description+PLATE).strip(),protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True);assert not (out/'submission.json').exists();p.write(out/'config.json',c);p.prepare(out,c)
 maxima=[]
 for i in range(len(references)):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);mask=a[:,:,3]>=245;maxima.append(int((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
 c['protected_foreground_chroma']=max(maxima)+2;p.write(out/'config.json',c);p.verify(out,c)
 p.write(out/'foreground_measurement.json',dict(opaque_alpha_minimum=245,original_guide_green_minus_max_red_blue=maxima,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

def main():
 # This reference is an unchanged crop of the existing accepted idle painting.
 pose,offset=p.source_pose(ref(13),8)
 reference=p.SOURCE_DIR/'accepted_idle_reference.png'
 if reference.exists():
  actual=Image.open(reference).convert('RGBA');assert actual.size==pose.size and actual.tobytes()==pose.tobytes()
 else:pose.save(reference)
 config('move',[ref(13),ref(2),walk(0),walk(1),ref(3)],[[22,1],[48,2],[72,3],[96,4]],0,'One complete reciprocal human WALK IN PLACE. First screen-left leg lifts behind while screen-right leg supports22. Then alternate: SCREEN-RIGHT knee swings forward48, screen-right boot plants in front72 while screen-left heel lifts behind. Both knees and ankles articulate in opposite support phases; both planted-foot and passing phases visible. Arms swing naturally opposite legs without releasing either short hook, blades stay clear of knees. Coat hem and rope charms sway, no root travel or hopping. Return to original ready by last frame. ONE complete cycle with BOTH legs, no one-legged marching.',2026102001)
 config('attack',[ref(13),ref(4),ref(5),ref(6)],[[26,1],[56,2],[88,3]],0,'One physical hooked-blade melee strike. Raise SCREEN-LEFT arm and its short original hook above shoulder in anticipation26; screen-right hand keeps second hook as guard. Swing screen-left hook down and forward toward screen right56 with elbow/shoulder rotation and knee weight transfer. Both hands keep original grips, two short hooks always present. Recover blade88 then return to original ready. One slash only, no flying blade, magic, trail, glow or invented impact.',2026102002)
 config('hit',[ref(13),ref(9)],[[34,1]],0,'One plain physical hit RECOIL, no incoming object or impact effect. Lean shoulders and head backward34, flex knees and elbows, retain BOTH hooks securely in original hands. Then smoothly regain balance and lower shoulders into original ready. Two feet stay grounded with sensible weight shift. No fall, extra hand, particles, throw, new weapon or action repetition.',2026102003)
 config('defend',[ref(13),ref(7),ref(8)],[[24,1],[44,2]],2,'One dedicated held defensive brace. Raise and CROSS the two original short hooked blades in front of chest24, each gloved hand keeps its own grip. Bend both knees into supplied low crossed-blades guard44, elbows tucked and torso lowered. HOLD this final guarded crouch through end, no return to idle. Keep BOTH hands, arms, legs and hook tips readable, no shield or extra blades.',2026102004)
 config('cast',[ref(13),ref(6)],[[44,1]],0,'One physical support/rally readiness SALUTE, not magic. Keep screen-left short hook held across low torso. Raise ONLY screen-right gloved arm, bend its elbow to bring its own short hooked blade UPRIGHT beside shoulder44. Two actual arms, two held hooks throughout, no empty-hand replacement or extra prop. Briefly hold upright blade, then lower SAME arm and return both original hooks to ready. Boots stay planted, visible elbow/wrist motion, no slash, magic, particles, cheering jump or transformation.',2026102005)
 config('death',[ref(13),ref(10),ref(11),ref(12)],[[26,1],[66,2]],3,'One continuous human DEATH collapse. Both knees buckle and sink to kneel26, shoulders sag and both hooks lower. Lose support and fall on side toward SCREEN LEFT66, arms and legs fold naturally, hooks settle in loosely held hands onto ground. End supplied prone corpse: head screen left, boots screen right, BOTH original arms, TWO folded legs and TWO original short hooked blades resting on ground. Same face, coat, scarf and equipment intact; corpse grounded and motion stops. No stand-up recovery, floating, shrinking, lost or extra limbs/weapons.',2026102006)
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[480,480],fixed_source_family_multipliers={'alpha/poses.png':.86,'continuity-alpha':.85,'idle-v2/hands-alpha.png':1,'walk_guides.png':.238},reason='Original218px standing and224px continuity versus accepted187px articulated idle. Fixed factor per original painting family, crouches/corpse never independently normalized; accepted idle unchanged. New opposed walking references fixed187px anatomical standing height.'))
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[n+'_h3_v1' for n in ['move','attack','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Solo Frostwharf Cutters six dedicated H3 actions; exactly two arms, two legs and two original hooked blades. Full original chronology, enlarged details and native/mirrored review required before acceptance. Preserve reviewed eight-pose articulated idle/map.')))

if __name__=='__main__':main()
