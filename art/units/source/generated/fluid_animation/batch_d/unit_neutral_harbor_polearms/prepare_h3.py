"""Prepare fixed-scale original Harbor Polearms guides for six H3 actions."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID = 'unit_neutral_harbor_polearms'
BASE = p.ROOT/'art/animation/source/poses'/UID
PACK = json.loads((BASE/'packing.json').read_bytes())
IDENTITY = ('One original Harbor Polearms infantryman: adult human man, tan skin, brown beard and mustache, '
 'navy maritime cap with round brass badge and small pale gold feather, navy long coat with gold trim, '
 'white open collar, brown crossed straps over chest mail, beige trousers, tall brown folded boots and brown gloves. '
 'Exactly two arms, two hands and two legs. Both hands hold ONE long straight brown boarding pole, '
 'with a silver hook and point at its screen-right end and small metal butt at its screen-left end. '
 'His LEFT hand on viewer-right grips the forward shaft toward the hook. His RIGHT hand on viewer-left '
 'grips the rear shaft. A small round navy-and-wood brass-rimmed buckler stays strapped to his LEFT forearm. '
 'Preserve the full continuous pole length, silver hook shape and both separate grips. '
 'One brass belt lantern and a coil of rope hang at his hip. ')
PLATE = (' Locked elevated three-quarter orthographic camera and consistent original body scale. '
 'All boots, pole tips, buckler and fallen equipment remain fully inside the image. '
 'Perfectly flat pure green RGB0,255,0 background in every frame, with no scenery, floor, horizon, '
 'shadow, text, other figures, color changes or effects. Physical joint motion; stable face and clothing. ')
TAKES = {
 'move_h3_v1': ([13], [], 0,
  'Walk briskly in place for two complete reciprocal stride cycles. Alternate LEFT and RIGHT legs through '
  'forward heel contact, weight bearing, passing and rear toe lift; bend each knee in turn. '
  'Keep pelvis centered while the legs alternate. Carry the pole diagonally across the body with both hands, '
  'hook pointing up and right; elbows and coat respond subtly to the steps. Return to the original planted stance.'),
 'attack_h3_v1': ([13,4,5], [[28,1],[52,2]], 0,
  'Perform one deliberate boarding-pole melee attack. Raise both elbows and the pole into the supplied '
  'overhead windup, then lower the shaft to chest height and thrust its silver hooked point toward screen right, '
  'extending the forward left arm and driving with the rear right arm. Brace the legs and lean into the thrust. '
  'Retract both arms, shift weight back and recover the starting diagonal ready stance. '
  'The pole stays a single solid continuous shaft held in both hands, never thrown or fired.'),
 'hit_h3_v1': ([13,9], [[24,1],[42,1]], 0,
  'Perform one backward torso recoil and recovery. Bend both knees slightly with boots supporting his weight, '
  'tilt chest, shoulders and head back as in the supplied middle pose, keeping the left buckler attached '
  'and both hands gripping the diagonal pole. Briefly hold the recoil, then straighten to the initial stance. '
  'No incoming object, flash or effect; only the man and his attached clothing and equipment move.'),
 'defend_h3_v1': ([13,8], [[60,1]], 1,
  'Lower into the supplied guarded crouch. Bend both knees and raise the left forearm buckler across the chest '
  'and chin while both hands keep the pole horizontal across the body, hook pointing screen right. '
  'Plant both boots, lean forward behind the buckler and finish holding this compact guard.'),
 'cast_h3_v1': ([13,4], [[48,1],[65,1]], 0,
  'Perform a physical rally salute with the boarding pole. Both hands lift the pole from its diagonal '
  'carry to the supplied overhead horizontal salute. Extend the elbows upward, briefly hold the pole above '
  'his cap while looking toward the right, then lower it smoothly back into the starting two-handed grip. '
  'Boots stay planted and the forearm buckler follows the left arm. This is a deliberate support signal, '
  'not an attack, spell or projectile; no glow or new equipment.'),
 'death_h3_v1': ([13,10,11,12], [[35,1],[65,2]], 3,
  'Perform one continuous defeat collapse. Knees buckle; lower onto one knee, lean down and lower the hip '
  'toward the ground. Place the boarding pole along the ground with its hook to the right as the body '
  'rolls onto its side and then settles on the back, head toward screen right and boots toward screen left. '
  'The same left forearm buckler settles over the chest. The single straight pole lies fully grounded beside '
  'the hands. Keep the full coat, boots and two legs intact, ending motionless in the supplied corpse pose.')
}

def ref(index):
    f = dict(PACK['frames'][index])
    f['source'] = (BASE/f['source']).relative_to(p.ROOT).as_posix()
    if '/idle-v2/' not in f['source']:
        # The legacy ready pose is221px high at its previous source scale,
        # versus191px for the accepted articulated idle. Apply the same
        # anatomical correction to every legacy sheet, including continuity.
        f['scale'] *= 13/15
    f['alpha_noise_cutoff'] = 8
    return f

if __name__ == '__main__':
    thumbs = []
    for number,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
        out = p.SOURCE_DIR/name
        out.mkdir(exist_ok=False)
        c = dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[420,560],scale=.5,
                 key_rgb=[0,255,0],seed=2026094000+number,references=[ref(i) for i in indices],
                 guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),
                 tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
        p.prepare(out,c)
        bands = []
        for i in range(len(indices)):
            im = Image.open(out/f'guide_{i}_rgba.png')
            a = np.asarray(im).astype(float)
            mask = binary_erosion(a[:,:,3]>240,iterations=3)
            chroma = a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2])
            bands.append(float(chroma[mask].max()))
            thumbs.append((name+':'+str(i),im.copy()))
        c['protected_foreground_chroma'] = max(0,int(max(bands))+2)
        c['foreground_measurement'] = dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two across original guides.',per_guide_max=bands)
        p.write(out/'config.json',c)
    p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
        visual_review=dict(status='pending',notes='Review reciprocal gait, continuous pole and two grips, forearm buckler, thrust/recovery, recoil, held guard, overhead support salute and grounded collapse. Preserve original eight-pose articulated idle.')))
    sheet = Image.new('RGB',(1440,((len(thumbs)+3)//4)*270),(43,48,43))
    draw = ImageDraw.Draw(sheet)
    for j,(name,im) in enumerate(thumbs):
        im.thumbnail((356,245));x,y=j%4*360,j//4*270
        sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
    sheet.save(p.ROOT/'.artifacts/harbor_h3/guides.png')
