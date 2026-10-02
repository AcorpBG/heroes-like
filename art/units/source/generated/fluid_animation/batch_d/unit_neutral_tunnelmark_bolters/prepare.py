"""Seven dedicated original H3 actions; preserve the reviewed articulated idle."""
import json
import numpy as np
from PIL import Image
import produce as p
UID='unit_neutral_tunnelmark_bolters'
LEGACY=p.ROOT/'art/animation/source/poses'/UID
FRAMES=json.loads((LEGACY/'packing.json').read_bytes())['frames']
IDENTITY=('One original Tunnelmark Bolter: slender adult human, youthful pale face, dark charcoal pointed hood and long split coat, weathered riveted grey shoulder armor and vambraces, mustard-yellow neck scarf, brown leather belts and hip pouches, tan wood bolt quiver at SCREEN LEFT hip with several short dark bolts, grey trousers, metal knee plates and brown strapped boots. Exactly TWO arms and TWO legs. ONE compact wooden crossbow with original dark steel limbs, intact stock, stirrup and front string. At ready SCREEN LEFT/near gloved right hand holds rear stock and trigger, SCREEN RIGHT/far left hand supports wooden fore-end. Same original face, costume, body proportions and weapon dimensions. No extra arms, crossbow, sword or shield. ')
PLATE=(' Locked original elevated three-quarter orthographic camera facing screen right, entire body, hands, boots and crossbow inside960x544 with safe margins, fixed anatomical scale and centered root. Uniform saturated GREEN RGB0,255,0 background, no floor, shadow, scenery, other people, text, particles, glow, smoke, trails, incoming objects or flying bolts. Real limb/weapon articulation, no whole-sprite warping or motion-blurred duplicate limbs. ')

def ref(index):
    f=dict(FRAMES[index]);f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
    return f

def config(clip,refs,guides,last,description,seed,version='v1'):
    c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,key_rgb=[0,255,0],seed=seed,references=refs,guides=guides,last=last,prompt=(IDENTITY+description+PLATE).strip(),protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    out=p.SOURCE_DIR/(clip+'_h3_'+version);out.mkdir(exist_ok=True)
    assert not (out/'submission.json').exists()
    p.write(out/'config.json',c);p.prepare(out,c)
    measured=[]
    for i in range(len(refs)):
        a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);opaque=a[:,:,3]>=245
        measured.append(int((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[opaque].max()))
    c['protected_foreground_chroma']=max(measured)+2;p.write(out/'config.json',c);p.verify(out,c)
    p.write(out/'foreground_measurement.json',dict(opaque_alpha_minimum=245,original_guide_green_minus_max_red_blue=measured,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

if __name__=='__main__':
    idle,_=p.source_pose(ref(17),8);idle.save(p.SOURCE_DIR/'accepted_idle_reference.png')
    config('move',[ref(17),ref(3),ref(4)],[[22,1],[62,2],[96,1]],0,
        'One reciprocal WALK IN PLACE. SCREEN RIGHT leg lifts knee and boot swings forward22 while SCREEN LEFT supports; then SCREEN LEFT leg passes forward62 while SCREEN RIGHT supports. Alternate knees, ankles, heel lifts, contacts and weight transfer through both complete leg phases. BOTH hands carry the same crossbow at waist; elbows adjust naturally, hood, coat hem and scarf sway lightly. Return to original planted ready. No root travel, hopping or one-legged march.',2026102201)
    config('attack',[ref(17),ref(5),ref(6),ref(7)],[[20,1],[38,2],[72,3]],0,
        'One plain right-fist forward PUNCH exercise. LEFT arm continuously cradles the ORIGINAL crossbow across waist. RIGHT hand releases rear stock, folds into ONE fist beside right shoulder20; RIGHT elbow then straightens forward with a controlled shoulder/waist pivot38. LEFT arm and original crossbow remain clearly separate, stable and cradled. Retract RIGHT fist toward shoulder72 and return RIGHT hand to original stock/trigger ready. Sensible knee transfer, unchanged adult proportions. Exactly two real arms and hands, one fist and one crossbow; no additional hand emerging from the bow, bow strike, flight, thrown weapon or effect.',2026102202)
    config('hit',[ref(17),ref(9)],[[30,1]],0,
        'One plain backward BALANCE LEAN. Both knees flex and chest/head lean backwards30, BOTH original hands keep the SAME crossbow in their original stock and fore-end grips. Boots stay supported; recover through shoulders and bent knees into original upright ready. No incoming object, collision effect, fall or extra hands.',2026102203)
    config('defend',[ref(17),ref(8)],[[44,1]],1,
        'One gradual low defensive GUARD. Keep BOTH hands on original crossbow stock and fore-end. Bend knees and hips into supplied low guard44, bring SAME crossbow across chest with original intact limbs and string. HOLD final supported low guard through end. Original arms, bow, boots and proportions; no shield, weapon expansion, aiming/firing or return to ready.',2026102204)
    config('cast',[ref(17),ref(5)],[[32,1],[58,1],[92,0]],0,
        'One physical rally FIST SALUTE. LEFT arm cradles same original crossbow at waist throughout. RIGHT hand releases stock and raises closed fist beside own shoulder32 as in supplied pose. HOLD raised fist32-58 as a brief physical encouragement. Lower RIGHT forearm and return RIGHT hand to rear stock92, hold original ready. No forward punch, striking, casting, glowing hand, magical effect or firing. Keep two original arms and one original wooden crossbow, planted boots and sensible wrist/elbow movement.',2026102205)
    config('ranged',[ref(17),ref(11),ref(12),ref(13),ref(10)],[[24,1],[38,2],[60,3],[88,4]],0,
        'One measured crossbow trigger-and-reload exercise, no visible projectile: runtime owns bolt flight. Raise original compact WOODEN crossbow from waist to supplied horizontal shoulder aim24. Original RIGHT hand remains on rear trigger/stock, LEFT hand supports fore-end. Bow limbs stay fixed; ORIGINAL drawn string releases FORWARD to front nocks38 with slight shoulder recoil, fore-end and both grips intact, no extra string. Keep empty crossbow during lowering60. RIGHT hand operates a short reload adjustment at stock88 while LEFT cradles original fore-end, then return original loaded waist-ready. No flying bolt, projectile trail, energy, elongated bow, additional weapon, disembodied hand or duplicated forearm.',2026102206)
    config('death',[ref(17),ref(16)],[],1,
        'One uninterrupted gradual physical collapse from upright ready to supplied corpse with HEAD SCREEN RIGHT and BOOTS SCREEN LEFT. Knees bend progressively, hips descend and shoulders sag; BOTH hands continuously lower same original crossbow. Knees touch ground, then lose support and gently roll onto side, folding two legs naturally. Head and shoulder settle onto ground at screen right, original bow rests flat beside chest and hands. Keep adult body proportions, hood, yellow scarf, quiver and TWO arms/TWO legs. Do not pause in kneel/seated plateaus, teleport, stand up, shrink or leave weapon hovering. Last half-second motionless grounded corpse. No effects or incoming object.',2026102207)
    p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[480,480],source_family_scaling='Retain existing legacy source-resolution scales (.68/.255/.24/.185/.44) unchanged; no per-pose normalization.',measured_reference_height=223,reason='Accepted articulated idle221-224px; original ready215-216, movement213-219 and firing212-227 are compatible with the same authored body scale. Corpse82px retains original folded anatomy.'))
    p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[n+'_h3_v1' for n in ['move','attack','hit','defend','cast','ranged','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Solo Tunnelmark Bolters seven dedicated original H3 actions; preserve personally reviewed eight articulated idle phases. Review both legs, exactly two arms, correct near/far grips, original crossbow limbs/string, no baked projectile and gradual collapse. Full chronological/native/mirrored review required.')))
