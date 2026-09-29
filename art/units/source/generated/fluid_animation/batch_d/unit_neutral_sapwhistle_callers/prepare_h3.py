"""Prepare original fixed-scale Sapwhistle action guides; retain reviewed idle."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID = 'unit_neutral_sapwhistle_callers'
BASE = p.ROOT/'art/animation/source/poses'/UID
PACK = json.loads((BASE/'packing.json').read_bytes())
IDENTITY = ('One original Sapwhistle Caller, an athletic adult woman with fair skin and brown shoulder-length hair, '
 'a pointed green hood with orange-yellow feathers, layered green and ochre leaf cloak, ivory wrapped chest armor, '
 'brown leather straps, brown trousers, pale round knee guards and wrapped brown leather boots. '
 'Her LEFT hand grips one short brass-and-wood cylindrical dart launcher with a pale brass muzzle and dangling green leaf charm. '
 'Her RIGHT hand is free to hold the small whistle near her chin. A belt carries short orange resin darts. '
 'Exactly two arms and two legs. Preserve the same face, launcher length, left-hand grip and layered cloak throughout. ')
PLATE = (' Fixed elevated three-quarter orthographic camera and body scale matching the original references. '
 'Keep the complete body, launcher, cloak and fallen equipment inside the frame. '
 'The entire background remains perfectly flat pure magenta RGB255,0,255 in every frame: no hue changes, '
 'floor, shadow, horizon, scenery, text or other people. Smooth physical joint articulation. ')
TAKES = {
 'move_h3_v1': ([17], [], 0,
  'Walk briskly in place with three reciprocal stride cycles. Alternate both legs through heel contact, loading, passing and toe lift. '
  'Keep hips centered as the knees flex; the left hand carries the same launcher pointing safely down and right. '
  'The right forearm counterbalances naturally, leaf cloak follows each stride. End in the initial stance.'),
 'attack_h3_v1': ([17,4,5], [[32,1],[60,2]], 0,
  'Make one close-range shove using the held launcher. Raise the left forearm into the supplied preparation, '
  'then extend the left elbow and shoulder to push the launcher forward toward screen right without releasing it. '
  'Keep the right hand guarding by the chest. Retract the same left arm and recover the initial ready stance. '
  'No shooting or projectile during this physical shove.'),
 'ranged_h3_v1': ([17,4,5], [[32,1],[56,2]], 0,
  'Perform one aimed launcher shot. Raise the left-hand dart launcher, straighten that arm toward screen right, '
  'sight along the barrel and briefly hold aim. The left trigger finger fires once; a small backward forearm recoil follows, '
  'then lower the same launcher to ready. Right hand remains near the whistle. '
  'Only the shooter is visible; projectile flight and impact are rendered separately by the game. No muzzle flash or smoke.'),
 'hit_h3_v1': ([17,12], [[24,1],[45,1]], 0,
  'The solitary woman performs one brief backward torso bend and straightens again. Bend both knees slightly, '
  'tilt the shoulders and head back as in the middle reference, keeping both feet planted and the left-hand launcher attached. '
  'The right hand draws close to the chest. Pause briefly, then regain the upright starting stance. '
  'Only her body, attached clothing and held launcher move; the empty magenta space stays identical.'),
 'defend_h3_v1': ([17,7], [[60,1]], 1,
  'Lower into the supplied compact defensive crouch. Bend both knees and lean forward, '
  'bring the right forearm across the face while keeping the left-hand launcher close and pointed right. '
  'Both feet support her weight. Finish holding the guarded crouch, without standing back up.'),
 'cast_h3_v1': ([17,20], [[40,1],[65,1]], 0,
  'Perform a practical ready signal and equipment check. Bring the launcher inward and upward across the chest in the left hand. '
  'The right hand briefly checks the launcher near its breech, then lifts toward the small whistle at her chin as a rally signal. '
  'Return both hands and the launcher to the initial ready pose. Physical hand and elbow movement, not magic; '
  'no shooting, glowing effects or added equipment.'),
 'death_h3_v1': ([17,13,14,16], [[35,1],[65,2]], 3,
  'Perform one continuous defeat collapse. Knees buckle and she lowers onto one knee, then bends forward, '
  'reaches toward the ground, lowers the hip and rolls gently onto her side with head toward screen right. '
  'The launcher stays in the left hand until that hand reaches the ground, then rests immediately beside it. '
  'Settle into the supplied side-rest corpse with both legs and arms intact, the leaf cloak draped over the body. '
  'Finish motionless; retain exactly one launcher on the ground.')
}

def ref(index):
    f = dict(PACK['frames'][index])
    f['source'] = (BASE/f['source']).relative_to(p.ROOT).as_posix()
    f['alpha_noise_cutoff'] = 8
    return f

if __name__ == '__main__':
    thumbs = []
    for number, (name, (indices, guides, last, action)) in enumerate(TAKES.items()):
        out = p.SOURCE_DIR/name
        out.mkdir(exist_ok=False)
        c = dict(unit_id=UID, clip=name.split('_')[0], canvas=[960,640], anchor=[470,560], scale=.5,
                 key_rgb=[255,0,255], seed=2026093700+number, references=[ref(i) for i in indices],
                 guides=guides, last=last, prompt=(IDENTITY+action+PLATE).strip(),
                 tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
        # The first pair exposed magenta color cycling. These four takes had
        # not been submitted, so their original guides use a blue plate.
        blue = c['clip'] in {'hit','defend','cast','death'}
        if blue:
            c['key_rgb'] = [0,0,255]
            c['prompt'] = c['prompt'].replace('magenta RGB255,0,255','blue RGB0,0,255').replace('empty magenta space','empty blue space')
        p.prepare(out,c)
        bands = []
        for i in range(len(indices)):
            im = Image.open(out/f'guide_{i}_rgba.png')
            a = np.asarray(im).astype(float)
            mask = binary_erosion(a[:,:,3]>240,iterations=3)
            chroma = a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]) if blue else np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
            bands.append(float(chroma[mask].max()))
            thumbs.append((name+':'+str(i),im.copy()))
        c['protected_foreground_chroma'] = max(0,int(max(bands))+2)
        c['foreground_measurement'] = dict(rule=('Eroded opaque blue-minus-max(red,green) maximum plus two across original guides.' if blue else 'Eroded opaque min(red,blue)-green maximum plus two across original guides.'),per_guide_max=bands)
        p.write(out/'config.json',c)
    p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
        visual_review=dict(status='pending',notes='Review left-hand launcher continuity, gait, shove, ranged aim/recoil, clean backward bend, guarded crouch, physical support and collapse. Preserve reviewed eight-pose articulated idle.')))
    sheet = Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(43,48,43))
    draw = ImageDraw.Draw(sheet)
    for j,(name,im) in enumerate(thumbs):
        im.thumbnail((356,237));x,y=j%4*360,j//4*260
        sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
    sheet.save(p.ROOT/'.artifacts/sapwhistle_h3/guides.png')
