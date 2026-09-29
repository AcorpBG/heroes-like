"""Generate the missing gradual return from Scarshield's rally signal."""
import json
import produce as p
from prepare import IDENTITY, PLATE

if __name__ == '__main__':
    original = p.SOURCE_DIR / 'cast_h3_v1'
    out = p.SOURCE_DIR / 'cast_lower_h3_v1'
    out.mkdir(exist_ok=False)
    c = json.loads((original / 'config.json').read_bytes())
    c.update(seed=2026093303, guides=[], last=1)
    c['references'] = [dict(
        source=(original / 'matte' / f'rgba_{i:03}.png').relative_to(p.ROOT).as_posix(),
        rects=[[0, 0, 960, 640]], anchor=c['anchor'], scale=c['scale'],
        alpha_noise_cutoff=0) for i in [74, 83]]
    c['prompt'] = (IDENTITY + (
        'Start with the hammer held diagonally across the chest in the first reference. '
        'Over the whole shot, slowly lower the right hand and hammer to the right thigh. '
        'Continuously open the bent right elbow and rotate the wrist so the same short '
        'solid hammer traces a gradual downward arc. Show many intermediate positions '
        'between chest, waist, hip and thigh. Finish at the supplied ready pose. '
        'The right hand stays closed around the handle. The left shield arm and both '
        'planted boots remain steady. This is a controlled nonmagical readiness gesture, '
        'not an attack or an instantaneous drop. Do not raise the hammer again. '
    ) + PLATE).strip()
    c['correction_reason'] = 'Original support frames 75-76 jump directly from chest to hip. Retain the raising gesture and replace the lowering interval.'
    p.prepare(out, c)
    p.write(out / 'config.json', c)
    print('Prepared support return correction; no generation submitted.')
