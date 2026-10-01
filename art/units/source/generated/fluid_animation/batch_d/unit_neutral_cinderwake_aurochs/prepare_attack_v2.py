"""Register the original closed-jaw contact correction and prepare a new H3 take."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

OUT = p.SOURCE_DIR / 'attack_h3_v2'
MASTER = p.SOURCE_DIR / 'horn_contact_closedjaw_v1.png'

def main():
    assert MASTER.exists()
    assert not (OUT / 'submission.json').exists(), 'Submitted take is immutable'
    OUT.mkdir(exist_ok=True)
    old = json.loads((p.SOURCE_DIR / 'attack_h3_v1/config.json').read_bytes())
    im = Image.open(MASTER).convert('RGBA')
    assert im.size == (1537, 1023) and im.getchannel('A').getextrema() == (0, 255)
    corrected = dict(source=MASTER.relative_to(p.ROOT).as_posix(),
                     rects=[[0, 0, *im.size]], anchor=[845, 884], scale=.204,
                     alpha_noise_cutoff=8)
    old['references'][2] = corrected
    old['seed'] = 2026100291
    old['guides'] = [[27, 1], [52, 2], [64, 2], [94, 0]]
    old['prompt'] = (
        'One original Cinderwake Aurochs, massive dark charcoal armored bull with '
        'exactly four muscular legs and four split hooves, two bronze-edged curled horns, '
        'one stone-tufted tail, angular dark back plates, attached orange chin beard '
        'and glowing orange seams within the body. Keep the lip line sealed and jaw '
        'closed throughout. Perform one forceful physical horn ram: bend the neck '
        'and lower the two horns, plant the rear hooves, push shoulders and horns '
        'forward to the supplied closed-jaw contact, then retract and recover the '
        'starting ready stance. Four hooves visibly support the weight. Only the '
        'bull body moves; all surrounding pixels stay uniform saturated green '
        'RGB0,255,0. Locked elevated three-quarter orthographic camera, unchanged '
        'anatomical torso scale and centered root. Entire body, horns, hooves and '
        'tail remain visible. The dark muzzle stays closed and its short beard '
        'stays attached under the chin throughout the strike.')
    p.prepare(OUT, old)
    bands = []
    for i in range(3):
        a = np.asarray(Image.open(OUT/f'guide_{i}_rgba.png')).astype(float)
        mask = binary_erosion(a[:, :, 3] > 240, iterations=3)
        bands.append(float((a[:, :, 1]-np.maximum(a[:, :, 0], a[:, :, 2]))[mask].max()))
    old['protected_foreground_chroma'] = max(0, int(max(bands))+2)
    old['foreground_measurement'] = dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two.', per_guide_max=bands)
    old['residency_log'] = '.artifacts/creature_sets_20261001/server-reserve4-stderr.log'
    p.write(OUT/'config.json', old)
    p.write(OUT/'registration_review.json', dict(
        status='pending', source=corrected, decoded_scale=.5,
        rule='One anatomical scale for the entire original painting; same contact torso registration, no per-frame fitting.',
        correction='Closed lip line and attached short chin beard; four leg chains and original identity retained.'))
    preview = p.ROOT/'.artifacts/aurochs_h3_20261001/closedjaw_registration.png'
    preview.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGB', (1440, 420), (32, 40, 32))
    draw = ImageDraw.Draw(sheet)
    for j, (label, path) in enumerate([
        ('original ready', OUT/'guide_0_rgba.png'),
        ('old open-jaw contact', p.SOURCE_DIR/'attack_h3_v1/guide_2_rgba.png'),
        ('new closed-jaw contact', OUT/'guide_2_rgba.png')]):
        im = Image.open(path).convert('RGBA').resize((480, 320), Image.Resampling.LANCZOS)
        sheet.paste(im, (j*480, 30), im)
        draw.text((j*480+8, 8), label, fill=(230, 220, 195))
    sheet.save(preview)
    print('Prepared new immutable attack take with fixed .204 guide scale; registration requires review.')

if __name__ == '__main__':
    main()
