"""Correct visible subject material pulsing with neutral original guide plates."""
import json, shutil
from PIL import Image
import produce as p

if __name__ == '__main__':
    old = p.SOURCE_DIR / 'hit_h3_v2'
    new = p.SOURCE_DIR / 'hit_h3_v3'
    new.mkdir(exist_ok=False)
    c = json.loads((old / 'config.json').read_bytes())
    c['seed'] = 2026110451
    c['key_rgb'] = [128, 128, 128]
    c['prompt'] = c['prompt'].replace(
        'Plain solid magenta backdrop identical to the reference throughout.',
        'Plain solid neutral gray backdrop identical to the reference throughout. '
        'Constant neutral studio illumination throughout; the original ivory '
        'plates, charcoal cloth, red painted marks and brass fittings keep their '
        'same painted colors as the supplied original paintings.')
    p.write(new / 'config.json', c)
    p.prepare(new, c)
    p.verify(new, c)
    for i in range(2):
        assert Image.open(new / f'guide_{i}_rgba.png').tobytes() == Image.open(old / f'guide_{i}_rgba.png').tobytes()
    shutil.copyfile(old / 'source_interval_review.json', old / 'initial_source_review_native_pending.json')
    for name in ['selection', 'handoff']:
        (old / f'{name}.json').rename(old / f'rejected_material_pulse_{name}.json')
    rejection = dict(status='full_take_rejected', personal_rgb_frames=124,
        personal_rgba_frames=124, personal_original_size_matched_details=39,
        personal_selected_original_size_pairs=25,
        reason='Native128px dark/light original-pixel comparison reveals conspicuous red tint on ivory helmet/shoulder/shin plates and whole body at32-50 and92-108, despite intact anatomy and no connected effect. Full lean/recovery requires these phases. Do not skip motion, recolor opaque pixels or accept the material pulse.',
        correction='Same original RGBA paintings, anatomical scale, ground anchor, one62 midpoint and matched endpoints; composite only guide backdrop to neutral gray and describe constant neutral illumination. Fixed H3 model/quality and pinned semantic matte unchanged.',
        original_video_sha256=p.sha(old / 'original_lossless.mkv'),
        original_latent_sha256=p.sha(old / 'original.latent'))
    p.write(old / 'rejection.json', rejection)
    p.write(old / 'source_interval_review.json', rejection)
    delivery = json.loads((p.SOURCE_DIR / 'delivery.json').read_bytes())
    delivery['takes'][2] = 'hit_h3_v3'
    delivery['failed_takes'].append('hit_h3_v2')
    p.write(p.SOURCE_DIR / 'delivery.json', delivery)
    print('NEUTRAL_HIT_PREPARED_ORIGINAL_RGBA_EXACT', flush=True)
