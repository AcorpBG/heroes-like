"""Choose a desaturated neutral plate outside every opaque original guide color."""
import json
import numpy as np
from PIL import Image
import produce as p

if __name__ == '__main__':
    old = p.SOURCE_DIR / 'hit_h3_v3'
    new = p.SOURCE_DIR / 'hit_h3_v4'
    new.mkdir(exist_ok=False)
    c = json.loads((old / 'config.json').read_bytes())
    c['key_rgb'] = [190, 206, 222]
    c['prompt'] = c['prompt'].replace('solid neutral gray backdrop', 'solid pale cool-gray backdrop')
    p.write(new / 'config.json', c)
    p.prepare(new, c)
    p.verify(new, c)
    distances = []
    for i in range(2):
        im = Image.open(new / f'guide_{i}_rgba.png')
        assert im.tobytes() == Image.open(old / f'guide_{i}_rgba.png').tobytes()
        a = np.asarray(im).astype(np.int16)
        opaque = a[:, :, :3][a[:, :, 3] >= 250]
        distances.append(float(np.linalg.norm(opaque - np.array(c['key_rgb']), axis=1).min()))
    assert min(distances) > 16 > 12
    p.write(new / 'plate_measurement.json', dict(plate_rgb=c['key_rgb'],
        original_guide_opaque_rgb_min_distance=distances,
        unchanged_matte_uniform_plate_band=12,
        original_foreground_rgba_identical=True,
        reason='Pure128gray would collide with70 opaque guide highlights. Pale cool-gray is desaturated and more than16RGB units from every opaque original guide pixel; no matte threshold or source painting changes.'))
    p.write(old / 'superseded_preparation.json', dict(status='superseded_before_submission',
        reason='Pure128gray plate overlaps70 original opaque highlight pixels inside unchanged12RGB matte band. Never submitted; use measured pale cool-gray without changing matte or foreground pixels.'))
    delivery = json.loads((p.SOURCE_DIR / 'delivery.json').read_bytes())
    delivery['takes'][2] = 'hit_h3_v4'
    delivery['superseded_unsubmitted_takes'].append('hit_h3_v3')
    p.write(p.SOURCE_DIR / 'delivery.json', delivery)
    print('SAFE_NEUTRAL_HIT_GUIDE_PLATE_OK', distances, flush=True)
