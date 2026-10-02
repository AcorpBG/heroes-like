"""Original action-specific Seedshield Warden H3 guides and generation recipes."""
import json
import numpy as np
from PIL import Image
import produce as p
UID='unit_thornwake_seedshield_wardens'
LEGACY=p.ROOT/'art/animation/source/poses'/UID
FRAMES=json.loads((LEGACY/'packing.json').read_bytes())['frames']
IDENTITY=('One original Seedshield Warden, a humanoid woodland guardian with exactly TWO arms and TWO legs. Branching brown antler helm surrounds the original dark green face, layered green oak-leaf mantle and torn leaf skirt, brown vine-wrapped bark armor, leather gloves and armored root-like boots, bronze belt and knee fittings. SCREEN LEFT anatomical RIGHT hand grips ONE long brown vine-wrapped seed-spear polearm: full-length single wooden shaft, original curved bright amber leaf-shaped blade at its upper end, dark oval opening below the blade, green leaf accents and one small amber bottom pommel. SCREEN RIGHT anatomical LEFT forearm carries ONE tall oval pointed amber seedglass shield with branching brown wooden rim and the original green sapling/seed motif. RIGHT hand never releases its same shaft; LEFT arm retains same shield. Preserve original face, antlers, leaf layers, spear length, amber blade and shield pattern; never add weapons, swap grips or add limbs. ')
PLATE=(' Locked original elevated three-quarter orthographic camera facing SCREEN RIGHT. Full body, every antler and BOTH spear ends stay inside960x544 with generous margins. Fixed original anatomical size and centered root. Uniform saturated MAGENTA RGB255,0,255 background. No floor, shadow, other figures, scenery, lettering, particles, spell effects, sparks, trail or baked swing arc. No camera travel, body resizing, limb swaps or root translation. ')

def ref(i):
    f=dict(FRAMES[i]);f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
    return f

def config(clip,refs,guides,last,description,seed):
    c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,key_rgb=[255,0,255],seed=seed,references=refs,guides=guides,last=last,prompt=(IDENTITY+description+PLATE).strip(),protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
    assert not (out/'submission.json').exists(),'Original generation is immutable'
    p.write(out/'config.json',c);p.prepare(out,c)
    measured=[]
    for i in range(len(refs)):
        a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);opaque=a[:,:,3]>=245
        measured.append(int((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[opaque].max()))
    c['protected_foreground_chroma']=max(measured)+2
    assert 255-c['protected_foreground_chroma']>=80
    p.write(out/'config.json',c);p.verify(out,c)
    p.write(out/'foreground_measurement.json',dict(opaque_alpha_minimum=245,original_guide_min_red_blue_minus_green=measured,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

if __name__=='__main__':
    config('move',[ref(13),ref(2),ref(3),ref(4),ref(5)],[[20,1],[38,2],[64,3],[84,4]],0,'One reciprocal WALK IN PLACE. Alternate BOTH boots through opposite planted contact, weight loading, lifted passing knee and extension phases. RIGHT spear hand stays low holding upright full-length original polearm; LEFT shield arm carries original shield steady. Hips, knees and elbows articulate, leaf skirt and antler foliage answer the gait. Complete both legs and settle to ready. No one-leg repeated march, hopping, sliding feet, shrinking spear or attack.',2026102501)
    config('attack',[ref(13),ref(6),ref(7)],[[28,1],[48,2],[88,0]],0,'One controlled RIGHT-HAND SEED-SPEAR thrust. RIGHT hand draws the full original polearm diagonally above the RIGHT shoulder28 with amber blade high and complete bottom shaft visible. Rotate the same shaft smoothly and extend RIGHT elbow toward SCREEN RIGHT48, thrusting the amber curved leaf blade forward at opponent chest height. LEFT forearm retains shield before left torso. Both knees support shoulder transfer. Then pull the same right elbow and intact full-length polearm back88 into upright ready. No shield bash, thrown spear, telescoping shaft, detached blade or swing trail.',2026102502)
    config('hit',[ref(13),ref(9)],[[32,1],[88,0]],0,'One backward recoil with recovery. Chest and antlered head lean back32 as knees flex; RIGHT hand retains same upright seed-spear and LEFT forearm retains shield. Boots remain supported, torso length unchanged. Recover progressively through hips, knees, shoulders and elbows88 to original ready. No collapse, external attacker or effects.',2026102503)
    config('defend',[ref(13),ref(8)],[[42,1]],1,'One dedicated defensive SHIELD BRACE. Sink hips in a planted supported knee bend and bring the original LEFT forearm amber seedglass shield before torso42. RIGHT hand retains upright full-length seed-spear beside right thigh. HOLD the final guarded stance while leaves settle. No return to ready, spear attack, shrinking shaft, shield motif change or added limbs.',2026102504)
    config('cast',[ref(13),ref(6)],[[44,1],[94,0]],0,'One physical nonmagical RALLY signal. Keep both boots planted, bend RIGHT elbow and raise same full-length seed-spear diagonally above RIGHT shoulder44 as a calm held salute, amber blade and bottom shaft unchanged. LEFT arm retains amber seedglass shield. Lower RIGHT elbow and spear progressively94 to upright ready; leaf mantle settles. No forward thrust, spellcasting, glow pulse, particle, weapon throw or new equipment.',2026102505)
    config('death',[ref(13),ref(10),ref(11),ref(12)],[[36,1],[60,2],[92,3]],3,'One continuous physical collapse. Knees bend and hips descend36, support gives way and body rolls to its side60 with antlered head SCREEN LEFT and boots SCREEN RIGHT. RIGHT hand lowers the full seed-spear so its amber blade, shaft and bottom pommel lie horizontally on the ground in front of the body92. LEFT arm lowers same shield onto fallen torso and ground. Leaves and legs settle naturally. No hovering weapon or shield, sudden body shrinking, extra limbs, severed antlers, long kneeling pause or standing up. Final half-second remains motionless grounded.',2026102506)
    p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[480,480],source_family_scaling='Original .6/.155/.152/.19/.44 scales retained unchanged.',measured_reference_height=209,reason='Inspected legacy ready219px, gait223-226px, windup236px, extended thrust179px, brace205px and corpse85px; eight articulated idle phases208-209px. Inherited anatomical registration retained without per-pose normalization.'))
    p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[n+'_h3_v1' for n in ['move','attack','hit','defend','cast','death']],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Solo Seedshield Wardens. Eight original articulated idle phases personally reviewed; six original H3 actions require complete chronological, equipment/grounding and actual battle-scale review before acceptance.')))
