"""Prepare original fixed-scale Knucklebear guides; movement is generated first."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID = 'unit_neutral_brambleback_knucklebears'
BASE = p.ROOT / 'art/animation/source/poses' / UID
PACK = json.loads((BASE / 'packing.json').read_bytes())
IDENTITY = (
    'One original Brambleback Knucklebear, a massive brown-furred bear with two huge front arms and clawed paws, '
    'two shorter muscular hind legs and smaller hind paws, one bear head, rounded ears, broad muzzle and amber eyes. '
    'Layered rough brown bark and twisted vines armor both forearms, shoulders and back. '
    'Small muted olive-green leaves grow among its woody thorns. Preserve the original narrow amber-orange cracks '
    'in the bark without adding lights or effects. Exactly two front arms and two hind legs throughout. '
    'The near front arm is the large foreground limb toward lower center; the far front arm is beyond the chest '
    'toward screen right. Hind legs remain attached beneath the rear torso toward screen left. '
    'Keep original proportions, claw arrangement, face, fur, vine and bark structure. No equipment or clothing. ')
PLATE = (
    'Locked elevated three-quarter orthographic camera, facing screen right. '
    'Keep the anatomical scale and root position fixed, the complete body and every claw inside the image. '
    'The background stays perfectly uniform pure blue RGB 0,0,255 from first to last frame, '
    'with no color cycling, floor, shadows, scenery, text or other subjects. '
    'Articulated physical joints and unchanged anatomy. No magic, projectiles or additional glow. ')
TAKES = {
    'move_h3_v1': ([2, 4, 3], [[24, 1], [45, 2], [69, 1], [90, 0]], 0,
        'Perform one slow complete reciprocal knucklewalk cycle in place. Begin with the near front knuckles '
        'forward and loaded while the far front paw supports the opposite phase. Unload and lift the far front '
        'paw, swing it forward and plant its knuckles; transfer the chest weight onto that far front arm. '
        'Then lift the near front paw, swing it forward and plant it in the initial contact. '
        'The two hind paws alternate planted loading, lift, passing and forward contact behind the front limbs. '
        'Maintain at least a front paw and opposite hind paw grounded through each transition; no jumping or sprinting. '
        'Show separate elbows, wrists, front knuckles and hind ankles moving coherently. '
        'Planted contacts stay registered until they unload. End at the exact initial loaded contact.'),
    'attack_h3_v1': ([0, 5, 6], [[30, 1], [55, 2]], 0,
        'Perform one melee claw sweep. Shift weight onto the far front arm and both hind paws, lift the near '
        'front arm into the original raised windup, then make one forceful forward-down claw sweep toward screen right. '
        'Keep the other front arm supporting the chest throughout. Retract the sweeping arm and return its knuckles '
        'to the original ready contact. One windup, one sweep, complete recovery; no second strike.'),
    'hit_h3_v1': ([0, 8], [[30, 1]], 0,
        'React to one impact by rocking the shoulders and bear head backward, bending elbows and hind knees. '
        'Retain both front arms and hind legs, briefly hold a backward recoil, then regain the original loaded '
        'ready stance. Paws remain near their starting contacts. This is a short recoverable reaction, not a collapse.'),
    'defend_h3_v1': ([0, 7], [[58, 1]], 1,
        'Lower the shoulders and bend the hind knees. Bring both bark-armored forearms across the chest and face '
        'into the original closed brace. Both front paws remain distinct and the hind legs support the weight. '
        'Finish holding the compact defensive brace with the head alert toward screen right.'),
    'cast_h3_v1': ([0, 8], [[48, 1]], 0,
        'Make one physical rally roar. Extend the hind knees, raise the chest and tip the muzzle upward, '
        'open the jaws in a powerful roar while both front arms flex beside the chest. '
        'Keep two distinct front paws and two hind feet, with the hind feet planted and weight supported. '
        'Briefly hold the raised chest signal then lower both arms and chest into the original ready stance. '
        'A noncaster physical support gesture, no spell, aura or generated sound-wave effect.'),
    'death_h3_v1': ([0, 9, 10, 11], [[30, 1], [65, 2]], 3,
        'Perform one continuous defeat collapse. Both front elbows buckle, the chest lowers and the hind knees '
        'fold. Let one hip meet the ground and the shoulders roll gently onto the side. '
        'Maintain exactly two front arms and two hind legs, the bark mantle attached to the back throughout. '
        'Settle the head and torso onto the ground in the original final side-rest corpse with paws resting flat. '
        'Finish motionless; no return to standing or additional limbs.')}


def ref(index):
    frame = dict(PACK['frames'][index])
    frame['source'] = (BASE / frame['source']).relative_to(p.ROOT).as_posix()
    frame['alpha_noise_cutoff'] = 8
    return frame


if __name__ == '__main__':
    thumbs = []
    measured = []
    for number, (name, (indices, guides, last, action)) in enumerate(TAKES.items()):
        out = p.SOURCE_DIR / name
        out.mkdir(exist_ok=False)
        config = dict(unit_id=UID, clip=name.split('_')[0], canvas=[960, 640], anchor=[470, 560], scale=.5,
            key_rgb=[0, 0, 255], seed=2026100180 + number, references=[ref(i) for i in indices],
            guides=guides, last=last, prompt=' '.join(part.strip() for part in [IDENTITY, action, PLATE]),
            tiled_decode=dict(tile_size=512, overlap=64, temporal_size=16, temporal_overlap=4))
        p.prepare(out, config)
        bands = []
        for i in range(len(indices)):
            image = Image.open(out / f'guide_{i}_rgba.png')
            pixels = np.asarray(image).astype(float)
            mask = binary_erosion(pixels[:, :, 3] > 240, iterations=3)
            blue = pixels[:, :, 2] - np.maximum(pixels[:, :, 0], pixels[:, :, 1])
            green = pixels[:, :, 1] - np.maximum(pixels[:, :, 0], pixels[:, :, 2])
            bands.append(float(blue[mask].max()))
            measured.append(dict(take=name, guide=i, blue=float(blue[mask].max()), green=float(green[mask].max())))
            thumbs.append((f'{name}: {i} / original {indices[i]}', image.copy()))
        config['protected_foreground_chroma'] = max(0, int(max(bands)) + 2)
        config['foreground_measurement'] = dict(rule='Eroded opaque blue-minus-max(red,green) maximum plus two across original guides.',
            per_guide_max=bands, separation=255 - config['protected_foreground_chroma'])
        assert config['foreground_measurement']['separation'] >= 80
        p.write(out / 'config.json', config)
    p.write(p.SOURCE_DIR / 'palette_measurements.json', measured)
    p.write(p.SOURCE_DIR / 'delivery.json', dict(unit_id=UID, takes=list(TAKES), preserved_accepted_clips=['idle'],
        visual_review=dict(status='pending', notes='Original articulated idle8 retained. Review movement first before remaining generation. Original guides do not alone prove opposed fore/hind contacts; inspect every actual generated transition. No continuous playback claim.')))
    sheet = Image.new('RGB', (1440, ((len(thumbs) + 3) // 4) * 300), (39, 45, 36))
    draw = ImageDraw.Draw(sheet)
    for i, (name, image) in enumerate(thumbs):
        image.thumbnail((354, 272), Image.Resampling.LANCZOS)
        x, y = i % 4 * 360, i // 4 * 300
        sheet.paste(image, (x + (360 - image.width) // 2, y + 25), image)
        draw.text((x + 4, y + 4), name)
    sheet.save(p.ROOT / '.artifacts/knucklebear_h3_20261001/guides.png')
