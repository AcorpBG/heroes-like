"""Reassess action control using original pixels and dedicated physical guides.

Fixed key-pose composition is reference preparation, never generated motion.
All animation frames are decoded original H3 output at one fixed scale.
"""
import json
import av
import numpy as np
from PIL import Image
from scipy.ndimage import label
import produce as p
import prepare_h3 as original

S = p.SOURCE_DIR

def read(path): return json.loads(path.read_bytes())

def decoded(take, index, name):
    out = S / take
    record = read(out / 'original.json')
    assert p.sha(out / 'original_lossless.mkv') == record['sha256']
    with av.open(str(out / 'original_lossless.mkv')) as v:
        for i, f in enumerate(v.decode(video=0)):
            if i == index:
                rgb = f.to_image().convert('RGB')
                import hashlib
                assert hashlib.sha256(rgb.tobytes()).hexdigest() == record['decoded_rgb_sha256'][i]
                rgba, detail = p.key(rgb, read(out / 'config.json'))
                break
    path = S / (name + '.png')
    rgba.save(path)
    p.write(S / (name + '.json'), dict(original=dict(path=(out/'original_lossless.mkv').relative_to(p.ROOT).as_posix(), sha256=p.sha(out/'original_lossless.mkv')), video_frame=index, video_time_seconds=index/24, rgba=dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path)), matte=detail, rebuild='prepare_solo_completion.py'))
    return rgba

def composite_body(name, anchor, factor, mast):
    source = S / (name + '.png')
    rgba, detail = p.key(Image.open(source).convert('RGB'), dict(key_rgb=[0,255,0], protected_foreground_chroma=24))
    # One fixed anatomical resize of the original guide; no pose deformation.
    rgba = rgba.resize((round(rgba.width*factor), round(rgba.height*factor)), Image.Resampling.LANCZOS)
    out = mast.copy()
    position = [round(470-anchor[0]*factor), round(560-anchor[1]*factor)]
    out.alpha_composite(rgba, tuple(position))
    path = S / (name + '_control.png'); out.save(path)
    p.write(S/(name+'_control.json'),dict(source=dict(path=source.relative_to(p.ROOT).as_posix(),sha256=p.sha(source)), fixed_anatomical_factor=factor,source_anchor=anchor,canvas=[960,640],ground_anchor=[470,560],body_position=position,mast_source='hit_h3_v2 original frame35 connected component at [325,250]',matte=detail,rule='Fixed original-pixel key-pose composition; neither morphing nor authored animation.',rebuild='prepare_solo_completion.py'))
    return path

def whole(name):
    path = S/(name+'.png');w,h=Image.open(path).size
    return dict(name=name,source=path.relative_to(p.ROOT).as_posix(),rects=[[0,0,w,h]],anchor=[470,560],scale=.5,alpha_noise_cutoff=0)

def prepare():
    recoil = decoded('hit_h3_v2',35,'mast_original35')
    arr=np.asarray(recoil).copy(); labs,n=label(arr[:,:,3]>=8,structure=np.ones((3,3),np.uint8))
    mast_label=int(labs[250,325]);assert mast_label>0
    ys,xs=np.where(labs==mast_label);assert xs.max()<396 and len(xs)>15000
    arr[labs!=mast_label]=0; mast=Image.fromarray(arr,'RGBA');mast.save(S/'mast_component35.png')
    p.write(S/'mast_component35.json',dict(source=dict(path=(S/'mast_original35.png').relative_to(p.ROOT).as_posix(),sha256=p.sha(S/'mast_original35.png')),component_seed=[325,250],alpha_cutoff=8,rule='Disconnected full original mast, all three canisters and tripod legs retained; no cut through body/equipment.'))
    decoded('ranged_h3_v2',36,'ranged_aim_original36')
    decoded('move_h3_v2',48,'walk_contact_original48')
    decoded('move_h3_v2',61,'walk_contact_original61')
    composite_body('melee_elbow_body_v2',[855,935],.49,mast)
    composite_body('hit_tucked_body_v2',[820,900],.49,mast)
    composite_body('ranged_recoil_body_v2',[768,863],.583,mast)
    common=read(S/'hit_h3_v2/config.json')
    identity=('One original Flaremast woman, same brown hair, blue cap/amber goggles, teal cream-cuff jacket, brown quilted vest covering waist, red scarf and sash, cream trousers, brown strapped boots. Exactly TWO arms/hands and TWO legs. Same long brass flared tube with red chamber, right hand at rear grip and left supporting barrel. Same brass signal mast with red/orange/blue canisters and three tripod legs. ')
    plate=(' Locked elevated three-quarter orthographic camera facing right, constant body and equipment scale, planted feet/root. Every detail inside canvas960x640. Perfectly uniform flat pure green RGB0,255,0 plate throughout, unchanged empty surroundings, no floor/shadow/gradient/hue changes/text/additional people. Smooth articulated physical joints, rigid equipment and stable grips.')
    definitions={
      'move':([whole('walk_contact_original48'),whole('walk_contact_original61')],[[30,1],[60,0],[90,1]],0,
        'The signal mast is ALREADY compactly stowed on the back strap, three hinged legs closed and all original canisters attached. It stays stowed for the ENTIRE video, never unpacked. Both hands carry the same long brass tube low pointing down-right. Walk continuously IN PLACE through two complete reciprocal stride cycles. Alternate near/far boot contacts, loading, passing and toe-off; opposite legs support each other, knees and ankles articulate independently. No start/stop, setup, equipment handling or translation; keep body centered. Red sash and coat follow gait. Match first contact at frame0/60/123 and opposite contact30/90.'),
      'attack':([original.ref(0),whole('melee_elbow_body_v2_control')],[[45,1]],0,
        'The deployed mast remains upright and stationary at screen left. Perform ONE right elbow STRIKE: twist torso, lift held brass tube diagonally across upper chest so its open end points UP LEFT; thrust bent RIGHT elbow forward toward screen right, matching the contact guide. Both hands keep original equipment grips. Then unwind elbows/torso and lower tube back to original ready. A small outward brace step precedes the strike; both boots ground at contact, then recover their original stance. Strike target with the right elbow, not the tube opening. One windup/contact/recovery, no repetition. Equipment is passive: no emissions, flashes, flame, smoke, sparks, detached objects or magic.'),
      'hit':([original.ref(0),whole('hit_tucked_body_v2_control')],[[38,1]],0,
        'The deployed mast remains upright and stationary at screen left. ONE outside blow pushes head/shoulders backward toward screen left. Flex knees while both boots support body; elbows tuck held tube across waist with its open end DOWN LEFT, matching recoil guide. Recover through knees and torso to original ready posture. Both hands retain equipment, two arms only. This is loss of balance followed by recovery; equipment is passive and emits nothing, no aiming/flash/flame/smoke/spark/detached object.'),
      'ranged':([original.ref(0),whole('ranged_aim_original36'),whole('ranged_recoil_body_v2_control')],[[30,1],[55,2]],0,
        'The deployed mast remains upright and stationary at screen left. One controlled equipment operation: raise brass tube to shoulder level in supplied aimed pose, both hands keep grips. At the central beat, pull both elbows and right shoulder briefly backward into supplied release-recoil pose, knees absorb the movement, then lower smoothly to ready. Preserve red chamber, tube length and dark open end. ONE aim/release/recovery sequence, no repeated action. Animation is ONLY body/held equipment articulation; surroundings remain unchanged and empty. No visible emissions, flame, flash, smoke, sparks, projectile, bullet, glow or detached part.')}
    for n,(clip,(refs,guides,last,action)) in enumerate(definitions.items()):
        out=S/(clip+'_solo_h3_v3');out.mkdir(exist_ok=False)
        c=dict(common,clip=clip,seed=2026100310+n,references=refs,guides=guides,last=last,prompt=identity+action+plate,protected_foreground_chroma=26)
        p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    print('Prepared four reassessed, fixed-scale solo action graphs')

if __name__=='__main__':prepare()
