"""Plan six original H3 actions from reviewed Charcoal Maul key paintings."""
import json,urllib.request
import numpy as np
from PIL import Image
import produce as p
UID='unit_neutral_charcoal_mauls'
LEGACY=p.ROOT/'art/animation/source/poses'/UID
FRAMES=json.loads((LEGACY/'packing.json').read_bytes())['frames']
IDENTITY=('One original Charcoal Maul: stocky muscular adult human man, black beard and hair, red headband and neck scarf, dark studded metal shoulder and leg plates, dirty cream apron with black rune motifs, red sleeves and leg wraps, brown gloves and boots, leather belt with small coal basket on screen right hip. Exactly TWO arms and TWO legs. ONE long two-handed dark metal maul, thick straight shaft with red wrapping and ring at butt, large rectangular double-faced dark steel hammer head with a narrow orange-red metal seam. Screen-left gloved hand grips lower shaft, screen-right gloved hand grips upper shaft, BOTH real hands stay on this SAME original shaft throughout. No extra weapon, duplicate head, changing hammer material, loose hands or extra fingers. Original face, clothes, armor, maul, grips and body proportions remain stable. ')
PLATE=(' Locked original elevated three-quarter orthographic camera facing screen right, full body and entire maul inside960x544 with generous margins, fixed anatomical scale and centered root. Uniform saturated GREEN RGB0,255,0 background every frame, no floor or ground shadow. No other characters, text, incoming objects, lines, trails, energy, glow, particles, smoke or impact flash. Genuine limb and joint articulation, not whole-sprite warping. ')

def ref(index):
 f=dict(FRAMES[index]);f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 if not f['source'].endswith('idle-v2/hands-alpha.png'):f['scale']*=.94
 return f

def config(clip,refs,guides,last,description,seed,version='v1'):
 c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,key_rgb=[0,255,0],seed=seed,references=refs,guides=guides,last=last,prompt=(IDENTITY+description+PLATE).strip(),protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 out=p.SOURCE_DIR/(clip+'_h3_'+version);out.mkdir(exist_ok=True);assert not (out/'submission.json').exists();p.write(out/'config.json',c);p.prepare(out,c)
 maxima=[]
 for i in range(len(refs)):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);mask=a[:,:,3]>=245;maxima.append(int((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
 c['protected_foreground_chroma']=max(maxima)+2;p.write(out/'config.json',c);p.verify(out,c)
 p.write(out/'foreground_measurement.json',dict(opaque_alpha_minimum=245,original_guide_green_minus_max_red_blue=maxima,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

def main():
 pose,_=p.source_pose(ref(13),8);pose.save(p.SOURCE_DIR/'accepted_idle_reference.png')
 config('move',[ref(13),ref(2),ref(3)],[[22,1],[62,2],[96,1]],0,'One reciprocal WALK IN PLACE. First SCREEN-RIGHT knee lifts and boot swings forward22 while SCREEN-LEFT leg supports. Then SCREEN-LEFT leg swings behind and passes forward62 while SCREEN-RIGHT foot supports. Alternate both knees/ankles through planted contact, heel lift and passing phases, both legs visibly active. Both hands carry the same long maul across waist without releasing their original grips; elbows and shoulders adjust naturally to weight, apron and scarf sway. Return to original planted ready by end; no root translation, hopping or one-legged march.',2026102101)
 config('attack',[ref(13),ref(4),ref(5),ref(6)],[[22,1],[34,2],[68,3]],0,'One controlled two-handed downward HAMMER EXERCISE, no effects. Lift both original hands and same entire maul overhead22, shoulders and elbows bend. Pivot BOTH hands together to bring hammer head down and forward to screen right34 with sensible knee weight shift. Keep straight shaft, head and both grips intact, never throw or strike ground. Bring maul back across waist68, then smoothly return original ready. One stroke only, no sparks, trails, glow or extra head.',2026102102)
 config('hit',[ref(13),ref(9)],[[28,1]],0,'One plain backward BALANCE LEAN exercise. Chest and head lean backward28, both knees flex to retain balance while both hands keep the same maul in their original grips. No incoming object, action effect or collision. Then bend knees/waist forward and regain original upright ready. Both boots retain sensible grounded support, no fall or extra hand.',2026102103)
 config('defend',[ref(13),ref(7),ref(8)],[[22,1],[46,2]],2,'One dedicated defensive BRACE. Raise the same maul shaft across upper chest22 with BOTH hands still on original lower and upper grip. Bend both knees and elbows into supplied low guarding crouch46, hold hammer head toward screen right and shaft across chest. HOLD final crouched guard through end with planted boots, no return to ready, no shield or new weapon.',2026102104)
 config('cast',[ref(13),ref(4)],[[44,1],[66,1]],0,'One physical rally SALUTE, not magic. Raise BOTH arms with same original maul overhead44, both hands remain on original shaft, hammer head toward screen left as in supplied overhead guide. HOLD raised maul briefly44-66, no downstroke, strike or throw. Then lower it carefully to waist while keeping both grips and return to original ready. Planted boots, visible elbow/wrist/shoulder articulation, no sparks, magic or particles. Share original overhead key painting with hammer exercise, but perform a distinct held salute and controlled lowering.',2026102105)
 config('death',[ref(13),ref(10),ref(11),ref(12)],[[26,1],[60,2]],3,'One continuous physical collapse. Both knees buckle and lower into kneel26, shoulders sag while both hands lower original maul. Lose support and roll gently onto SCREEN LEFT side60; both arms and two legs fold naturally. End supplied prone corpse with head screen left and boots screen right, original dark hammer lying flat beside hands, entire shaft and head resting on ground. Hold motionless corpse through last frame. No stand-up, hovering, shrink, bright effects, additional limbs or weapons.',2026102106)
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[480,480],fixed_source_family_multipliers={'legacy_alpha_and_continuity':.94,'idle-v2/hands-alpha.png':1},reason='Accepted articulated idle204px body; original ready216px and passing220px. Fixed .94 factor for original legacy action paintings, no crouch/death normalization; preserve idle and map pixels.'))
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[n+'_h3_v1' for n in ['move','attack','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Solo Charcoal Mauls six separate original H3 actions. Inspect both arms, both legs, stable two-hand maul grips and original metal head; preserve personally reviewed eight-frame articulated idle. Full chronological/native/mirrored review required.')))
 prior=json.loads((p.ROOT/'art/units/source/generated/fluid_animation/batch_d/unit_neutral_frostwharf_cutters/runtime_profile.json').read_bytes());stats=json.load(urllib.request.urlopen(p.URL+'/system_stats'));prior.update(runtime=stats['system'],device=stats['devices'][0]['name'],unit_id=UID)
 for item in prior['models']['files']:assert (p.Path('H:/ai/minimax-h3/ComfyUI/models')/item['file']).stat().st_size==item['bytes']
 p.write(p.SOURCE_DIR/'runtime_profile.json',prior)

if __name__=='__main__':main()
