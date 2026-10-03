"""Exclude the adjacent third-cell blades from idle_03/07, retaining original art.

The fourth 384x512 source cell contains the previous cell's blade at
x1152..1158/y251..280, and lower cell x1152..1153/y774..786. Split rectangles preserve the original
canvas, Lanczos registration, anatomical scale and ground anchor.
"""
from pathlib import Path
import argparse, copy, hashlib, json, shutil, sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
from integrate_fluid_creature_animation import pack_unit, read
from pack_overworld_creature_idle import extract
from creature_animation_lock import exclusive

SOURCE = Path(__file__).resolve().parent
UID = SOURCE.name
ORIGINAL_HASH = '1030bca552143cd9cee7d131a922a98fd4a2ca9da58bf9f374d87ed666e5bf43'

def prepare(output):
    output.mkdir(parents=True, exist_ok=True)
    for name in ['reviewed_handoff', 'provenance']:
        retained = SOURCE / (name + '_before_idle_bleed_fix.json')
        if not retained.exists():
            shutil.copyfile(SOURCE / (name + '.json'), retained)
    original = read(SOURCE / 'reviewed_handoff_before_idle_bleed_fix.json')
    handoff = copy.deepcopy(original)
    entry = handoff['units'][0]
    frame = entry['frames'][3]
    assert frame['name'] == 'idle_03' and frame['rects'] == [[1152, 0, 1536, 512]]
    image = ROOT / frame['source']
    assert hashlib.sha256(image.read_bytes()).hexdigest() == ORIGINAL_HASH
    # This exclusion is wholly within the measured foreign component's bbox.
    frame['rects'] = [[1152, 0, 1536, 251], [1159, 251, 1536, 281], [1152, 281, 1536, 512]]
    lower = entry['frames'][7]
    assert lower['name'] == 'idle_07' and lower['rects'] == [[1152, 512, 1536, 1024]]
    lower['rects'] = [[1152, 512, 1536, 774], [1154, 774, 1536, 787], [1152, 787, 1536, 1024]]
    entry['extraction_correction'] = {
        'frames': ['idle_03', 'idle_07'], 'excluded_source_rectangles': [[1152, 251, 1159, 281], [1152, 774, 1154, 787]],
        'reason': 'Third-cell blades crossed into fourth grid cells; excluded only proven foreign fragments.',
        'original_handoff': 'reviewed_handoff_before_idle_bleed_fix.json',
        'original_provenance': 'provenance_before_idle_bleed_fix.json',
        'original_source_sha256': ORIGINAL_HASH}
    target = SOURCE / 'idle_bleed_fixed_handoff.json'
    target.write_text(json.dumps(handoff, indent=2) + '\n', encoding='utf-8')
    baseline = read(SOURCE / 'baseline.json')
    patch = pack_unit(entry, baseline, output / 'candidate')
    old_patch = pack_unit(original['units'][0], baseline, output / 'original_rebuild')
    old = np.array(Image.open(ROOT / old_patch['animation']['pose_sheet'].removeprefix('res://')))
    retained = read(SOURCE / 'provenance_before_idle_bleed_fix.json')
    assert old_patch['atlas_sha256'] == retained['atlas_sha256'], 'Original recipe must reproduce accepted atlas'
    new = np.array(Image.open(ROOT / patch['animation']['pose_sheet'].removeprefix('res://')))
    changed = np.any(new != old, axis=2)
    y, x = np.where(changed)
    allowed = ((x >= 1563) & (x < 1573) & (y >= 125) & (y < 145)) | ((x >= 459) & (x < 470) & (y >= 385) & (y < 405))
    assert len(x) == 57 and allowed.all(), 'Only the two measured foreign fragments may change'
    assert np.all(new[:, :, 3][changed] == 0), 'Only foreign ink may be removed'
    assert patch['animation'] == dict(old_patch['animation'], pose_sheet=patch['animation']['pose_sheet'])
    strip, meta = extract(patch['animation'])
    strip.save(output / 'candidate-map.png')
    (output / 'manifest_patch.json').write_text(json.dumps({'schema_version': 1, 'units': [patch]}, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'changed_atlas_pixels': len(x), 'changed_bounds': [int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1)], 'atlas_sha256': patch['atlas_sha256'], 'map_geometry': meta}, indent=2))
    return target

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--publish', action='store_true')
    a = p.parse_args()
    handoff = prepare(a.output.resolve())
    if a.publish:
        from publish_fluid_creature_animation import publish
        entry = read(handoff)['units'][0]
        with exclusive('content'):
            print(publish(handoff, list(entry['clips']), 'Current native both-facing review: exclude only proven adjacent-cell blade bleed in idle phases3/7; preserve all subject art, registration and other actions.'))

if __name__ == '__main__':
    main()
