"""Original action-specific Seedglass Cantor H3 recipes, fixed anatomy/registration."""
import json
import numpy as np
from PIL import Image
import produce as p
UID='unit_thornwake_seedglass_cantors';LEGACY=p.ROOT/'art/animation/source/poses'/UID
FRAMES=json.loads((LEGACY/'packing.json').read_bytes())['frames']
IDENTITY=('One original Seedglass Cantor, a tall slim humanoid woodland archer with '
    'exactly TWO arms and TWO legs. Pale ivory bark mask/face with elongated dark '
    'eye openings, brown branching antler crown and original bright green leaves, '
    'ivory bark breast and thigh armor, layered green/golden leaf mantle and skirt, '
    'brown vine-wrapped limbs and two root-toed wooden feet. SCREEN RIGHT anatomical '
    'LEFT hand holds ONE original tall curved wooden recurve bow with both curled '
    'branch tips, green leaf accents, amber hanging seed pods and one thin bowstring. '
    'SCREEN LEFT anatomical RIGHT hand is the free drawing/punching hand. LEFT hand '
    'always holds the same bow grip; RIGHT hand moves freely or draws its string. '
    'Keep pale face, antlers, root toes, two limbs each, leaf layers and full bow '
    'shape/length unchanged. Never add a staff, sword, shield, second bow or arm. ')
PLATE=(' Locked original elevated three-quarter orthographic camera facing SCREEN '
    'RIGHT. Fixed original body size and root centered; every root toe, antler and '
    'both bow tips remain inside960x544 with generous margins. Empty uniform '
    'saturated BLUE RGB0,0,255 backdrop in EVERY frame. No floor, shadow, scenery, '
    'other figure, text, floating leaves, sparkle, trail, ribbon, glowing aura, '
    'camera travel, zoom, foot sliding or changing illumination. Only original '
    'body and held equipment move; amber pods keep their original painted color. ')

def ref(i):
    f=dict(FRAMES[i]);f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix()
    f['alpha_noise_cutoff']=8;return f

def config(clip,refs,guides,last,action,seed):
    out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
    assert not (out/'submission.json').exists(), 'Submitted original is immutable'
    c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[480,480],scale=.5,
           key_rgb=[0,0,255],seed=seed,references=refs,guides=guides,last=last,
           prompt=(IDENTITY+action+PLATE).strip(),protected_foreground_chroma=0,
           tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.prepare(out,c);measured=[]
    for i in range(len(refs)):
        a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int)
        measured.append(int((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[a[:,:,3]>=245].max()))
    c['protected_foreground_chroma']=max(measured)+2
    assert 255-c['protected_foreground_chroma']>=80
    p.write(out/'config.json',c);p.verify(out,c)
    p.write(out/'foreground_measurement.json',dict(blue_minus_max_red_green=measured,
        opaque_alpha_minimum=245,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

if __name__=='__main__':
    config('move',[ref(18),ref(2),ref(3),ref(4),ref(5)],[[20,1],[38,2],[64,3],[84,4]],0,
        'One reciprocal WALK IN PLACE. Alternate BOTH root feet through opposed '
        'planted contact, weight loading, passing knee lift and extension. LEFT '
        'hand carries original bow upright, RIGHT free arm swings naturally near '
        'waist. Both hips, knees, elbows and leaf skirt respond to gait. Complete '
        'both legs and settle to ready. No repeated same-leg march or bow drawing. ',2026102701)
    config('attack',[ref(18),ref(6),ref(7)],[[24,1],[46,2],[82,0]],0,
        'One close-range RIGHT FIST strike. RIGHT empty hand closes to a fist and '
        'draws back beside right shoulder24; LEFT hand holds bow away from strike. '
        'Extend RIGHT elbow and fist forward SCREEN RIGHT46 with supported knees '
        'and shoulder transfer, then withdraw right fist82 to original ready. '
        'Do not strike with bow or fire an arrow. No extra hand or extended arm. ',2026102702)
    config('ranged',[ref(18),ref(11),ref(12),ref(13)],[[30,1],[48,2],[82,3],[104,0]],0,
        'One original bow shot. LEFT hand raises and aims the same full bow toward '
        'SCREEN RIGHT. RIGHT hand draws the thin original string back near cheek30 '
        'with exactly ONE short amber seed-arrow nocked along it. RIGHT fingers '
        'release48 and follow through beside right shoulder while LEFT arm keeps '
        'bow aimed. The single released seed-arrow leaves SCREEN RIGHT quickly; '
        'no lingering arrow, beam, repeated shot or trail. Recover82 and lower '
        'bow104 to ready. Both branch tips, grip, string and anatomy stay intact. ',2026102703)
    config('hit',[ref(18),ref(10)],[[18,0],[36,1],[68,0]],0,
        'One silent backward recoil and recovery. Chest and antlered head lean '
        'back36 while both knees bend and RIGHT free hand guards chest. LEFT '
        'hand keeps same bow attached. Recover progressively68 to original '
        'ready. No incoming attacker, loose leaves, slash line or collapse. ',2026102704)
    config('defend',[ref(18),ref(9)],[[38,1]],1,
        'One dedicated defensive crouch. Lower hips in a supported deep knee '
        'bend38; RIGHT free forearm guards the pale bark torso. LEFT hand retains '
        'full original bow upright beside left shoulder. HOLD final guarded '
        'stance as leaves settle. No firing, punch, shield or return to ready. ',2026102705)
    config('cast',[ref(18),ref(21),ref(1)],[[34,1],[62,2],[94,0]],0,
        'One quiet physical support signal. Keep both root feet planted. RIGHT '
        'free hand rises from belt to throat/chest34 in a spoken rally, then opens '
        'outward62 with a relaxed palm and lowers94 back to ready. LEFT hand '
        'continues holding original bow, never draws its string. No spellcasting, '
        'projectile, brightening, emitted light or magic effect. ',2026102706)
    config('death',[ref(18),ref(14),ref(15),ref(16),ref(17)],[[26,1],[44,2],[66,3],[84,4]],4,
        'One continuous collapse: knees bend and hips descend26, support gives '
        'way and torso rolls forward/down44. Head and antlers end SCREEN RIGHT '
        'with root feet extending SCREEN LEFT66. LEFT hand lowers its original '
        'bow onto ground horizontally in front of fallen body. Original leaf '
        'layers, hands and legs settle84 into a motionless grounded corpse. '
        'No hovering bow, detached limb, long pause or sudden body shrinking. '
        'Final second remains still. ',2026102707)
    p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,
        output_scale=.5,ground_anchor=[480,480],source_family_scaling='Original .66/.165/.146/.177/.44 scales retained unchanged.',
        reason='Reviewed original ready213px, reciprocal gait214-217px, eight articulated idle phases, full bow/limb continuity and head-right grounded corpse. No per-pose normalization.'))
    p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[c+'_h3_v1' for c in ['move','attack','ranged','hit','defend','cast','death']],
        preserved_accepted_clips=['idle'],visual_review=dict(status='pending',
        notes='Solo Seedglass Cantors. Eight original articulated idle phases personally inspected and retained. Seven original H3 actions require chronological, identity/alpha, native and shell-clock review.')))
