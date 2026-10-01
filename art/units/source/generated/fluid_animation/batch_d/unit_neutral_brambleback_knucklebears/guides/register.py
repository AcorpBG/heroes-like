"""Preserve generated opposed contact lineage and register one anatomical scale."""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import produce as p
import prepare_h3 as prep


def record(name, original_output, references, review):
    folder = p.SOURCE_DIR / 'guides'
    master = folder / (name + '.png')
    prompt = folder / (name + '.prompt.txt')
    refs = [dict(path=path.relative_to(p.ROOT).as_posix(), sha256=p.sha(path)) for path in references]
    p.write(folder / (name + '.json'), dict(unit_id=prep.UID, generator='built-in image_gen image edit',
        image=master.relative_to(p.ROOT).as_posix(), image_sha256=p.sha(master),
        prompt=prompt.relative_to(p.ROOT).as_posix(), prompt_sha256=p.sha(prompt),
        original_tool_output=original_output, references=refs, review=review))


if __name__ == '__main__':
    folder = p.SOURCE_DIR / 'guides'
    origin = 'C:/Users/acorp/.codex/generated_images/01a0f615-67c7-7ef1-ac53-345d29d5700f/'
    record('opposed_contact_v1', origin + 'exec-68c71412-7bea-4afb-b006-a19862d1bdc9.png',
        [p.SOURCE_DIR / 'move_h3_v1/guide_0_rgba.png', p.ROOT / 'art/units/source/curated' / (prep.UID + '.png')],
        'Four limbs and opposed front contact are readable, but generated brown diffuse halo violates requested transparency. Excluded as direct video input; retained original master.')
    record('opposed_contact_plate_v1', origin + 'exec-1b3f2d34-f902-48e4-b8fe-7706bbcf242c.png',
        [folder / 'opposed_contact_v1.png'],
        'Blue plate corrected; pose retains two front arms and two hind legs. Near foreground forepaw bends unloaded below chest; far forepaw extends forward and bears weight. Near hind paw planted, far hind paw toe-off. Changed framing uses one fixed whole-painting registration; no body warp or per-pose normalization.')
    master = Image.open(folder / 'opposed_contact_plate_v1.png').convert('RGB')
    rgba, matte = p.key(master, dict(key_rgb=[0, 0, 255], protected_foreground_chroma=8))
    rgba.save(folder / 'opposed_contact_rgba.png')
    p.write(folder / 'opposed_contact_rgba.json', dict(unit_id=prep.UID,
        source='guides/opposed_contact_plate_v1.png', source_sha256=p.sha(folder / 'opposed_contact_plate_v1.png'),
        output_sha256=p.sha(folder / 'opposed_contact_rgba.png'), matte=matte,
        rule='Plate extraction only; exact generated anatomy retained. Fixed source scale .215 and anchor [768,1000] register shoulder mantle/head and hind contact to original .6-scale reference, not changing opaque bounds.'))
    out = p.SOURCE_DIR / 'move_h3_v1'
    config = json.loads((out / 'config.json').read_bytes())
    config['references'] = [prep.ref(2), prep.ref(0), dict(name='opposed_loaded_contact',
        source=(folder / 'opposed_contact_rgba.png').relative_to(p.ROOT).as_posix(),
        rects=[[0, 0, master.width, master.height]], anchor=[768, 1000], scale=.215, alpha_noise_cutoff=8)]
    config['guides'] = [[22, 1], [43, 2], [66, 1], [90, 0]]
    config['last'] = 0
    config['registration_note'] = 'Original paintings retain .6 runtime scale. Generated opposed-contact master uses fixed .215 runtime scale (.43 magnification into video) and [768,1000] source anchor, matching torso/bark/head anatomy and contact depth; no per-frame bounds scaling.'
    p.prepare(out, config)
    bands = []
    images = []
    for i in range(len(config['references'])):
        image = Image.open(out / f'guide_{i}_rgba.png')
        pixels = np.asarray(image).astype(float)
        mask = binary_erosion(pixels[:, :, 3] > 240, iterations=3)
        bands.append(float((pixels[:, :, 2] - np.maximum(pixels[:, :, 0], pixels[:, :, 1]))[mask].max()))
        images.append(image)
    config['protected_foreground_chroma'] = max(0, int(max(bands)) + 2)
    config['foreground_measurement'] = dict(per_guide_max=bands, separation=255-config['protected_foreground_chroma'],
        rule='Eroded opaque blue-minus-max(red,green) maximum plus two across original and generated opposite guides.')
    p.write(out / 'config.json', config)
    sheet = Image.new('RGB', (1440, 680), (39, 45, 36))
    draw = ImageDraw.Draw(sheet)
    for i, image in enumerate(images):
        image.thumbnail((470, 600), Image.Resampling.LANCZOS)
        sheet.paste(image, (i * 480, 45), image)
        draw.text((i*480+4, 8), ['Original near loaded', 'Original grounded passing', 'Generated far loaded'][i])
    sheet.save(p.ROOT / '.artifacts/knucklebear_h3_20261001/movement_guides.png')
    print('Opposed contact registered; protected blue band:', config['protected_foreground_chroma'])
