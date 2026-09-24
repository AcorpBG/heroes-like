#!/usr/bin/env python3
"""Extract original idle poses without repainting, warping or resampling pixels.

All frames share one crop and anatomical anchor. Independent per-frame trimming
would turn breathing into foot sliding and change the creature's scale.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'art/overworld/creature_idle.json'
DESTINATION = ROOT / 'art/overworld/runtime/creature_idle'


def extract(row):
    source = ROOT / row['pose_sheet'].removeprefix('res://')
    spec = row['pose_clips']['idle']
    width, height = (row['pose_frame_size'][key] for key in ('width', 'height'))
    columns = row['pose_columns']
    indices = spec.get('indices', [spec.get('row', 0) * columns +
                                 spec.get('column', 0) + i for i in range(spec['frames'])])
    with Image.open(source) as sheet:
        frames = [sheet.crop(((i % columns) * width, (i // columns) * height,
                              (i % columns + 1) * width, (i // columns + 1) * height))
                  for i in indices]
    assert len(frames) > 1 and len({f.tobytes() for f in frames}) > 1, row['id']
    bounds = [f.getchannel('A').getbbox() for f in frames]
    assert all(bounds), row['id']
    left, top = min(b[0] for b in bounds), min(b[1] for b in bounds)
    right, bottom = max(b[2] for b in bounds), max(b[3] for b in bounds)
    # Shared transparent gutter for linear filtering and the runtime outline.
    padding = 8
    crop = (left - padding, top - padding, right + padding, bottom + padding)
    fw, fh = crop[2] - crop[0], crop[3] - crop[1]
    strip = Image.new('RGBA', (fw * len(frames), fh))
    for i, frame in enumerate(frames):
        strip.paste(frame.crop(crop), (i * fw, 0))
    entry = {
        'path': 'res://art/overworld/runtime/creature_idle/' + row['id'] + '.png',
        'frame_size': [fw, fh], 'frames': len(frames),
        'frame_msec': spec.get('frame_msec', 600),
        'static_frame': spec.get('static_frame', 0),
        'ground_anchor': [row.get('pose_anchor_x', width / 2) - crop[0], height - row.get('pose_ground_margin', 0) - crop[1]],
        'painted_extent': max(right - left, bottom - top),
        'source_sheet': row['pose_sheet'], 'source_indices': indices,
        'source_crop': list(crop),
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_provenance': row['pose_provenance'],
    }
    return strip, entry


def main():
    rows = json.loads((ROOT / 'content/unit_animation_manifest.json').read_text())['items']
    DESTINATION.mkdir(parents=True, exist_ok=True)
    units = {}
    for row in rows:
        strip, entry = extract(row)
        path = ROOT / entry['path'].removeprefix('res://')
        strip.save(path, optimize=True)
        entry['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        units[row['unit_id']] = entry
    MANIFEST.write_text(json.dumps({
        'schema_id': 'overworld_creature_idle_v1',
        'preparation_tool': 'tools/pack_overworld_creature_idle.py',
        'policy': 'Original painted idle poses; shared crop/ground anchor; no synthesized motion.',
        'units': units,
    }, indent=2) + '\n', encoding='utf-8')
    print(f'Packed {len(units)} creature idle strips; {sum(p.stat().st_size for p in DESTINATION.glob("*.png")):,} bytes.')


if __name__ == '__main__':
    main()
