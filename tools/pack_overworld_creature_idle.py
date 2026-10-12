#!/usr/bin/env python3
"""Extract original idle poses without repainting, warping or resampling pixels.

All frames share one crop and anatomical anchor. Independent per-frame trimming
would turn breathing into foot sliding and change the creature's scale. A unit
whose idle plays a derived loop sheet (RIFE in-betweens, see
tools/integrate_idle_inbetweens.py) uses that sheet directly.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'art/overworld/creature_idle.json'
DESTINATION = ROOT / 'art/overworld/runtime/creature_idle'
POLICY = ('Original painted idle poses on a shared crop/ground anchor; the RIFE in-betweens of '
          'docs/idle-inbetweens.md where a unit has them; no other synthesized motion.')


def shared_sheet(row):
    """A derived idle loop (tools/integrate_idle_inbetweens.py) already sits on one
    shared crop and ground anchor, so the map plays its sheet instead of a copy."""
    spec = row['pose_clips']['idle']
    path = ROOT / spec['sheet'].removeprefix('res://')
    width, height = spec['frame_size']['width'], spec['frame_size']['height']
    with Image.open(path) as sheet:
        alpha = sheet.getchannel('A')
        bounds = [alpha.crop((i % spec['columns'] * width, i // spec['columns'] * height,
                              (i % spec['columns'] + 1) * width, (i // spec['columns'] + 1) * height)).getbbox()
                  for i in spec['indices']]
    assert all(bounds), row['id']
    extent = max(max(b[2] for b in bounds) - min(b[0] for b in bounds), max(b[3] for b in bounds) - min(b[1] for b in bounds))
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return {
        'path': spec['sheet'], 'frame_size': [width, height], 'columns': spec['columns'],
        'frames': spec['frames'], 'frame_msec': spec['frame_msec'], 'static_frame': spec.get('static_frame', 0),
        'ground_anchor': [spec['anchor_x'], height - spec['ground_margin']], 'painted_extent': extent,
        'source_sheet': spec['sheet'], 'source_indices': spec['indices'], 'source_crop': [0, 0, width, height],
        'source_sha256': digest, 'source_provenance': row['pose_provenance'], 'sha256': digest,
    }


def write_strip(strip, entry):
    """Saves an extracted strip and records its hash; a shared sheet needs neither."""
    if strip is not None:
        path = ROOT / entry['path'].removeprefix('res://')
        strip.save(path, optimize=True)
        entry['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()


def extract(row):
    """(strip, entry) for the unit's map idle; strip is None when it plays a shared sheet."""
    spec = row['pose_clips']['idle']
    if spec.get('sheet'):
        return None, shared_sheet(row)
    source = ROOT / row['pose_sheet'].removeprefix('res://')
    width, height = (row['pose_frame_size'][key] for key in ('width', 'height'))
    columns = row['pose_columns']
    indices = spec.get('indices', [spec.get('row', 0) * columns +
                                 spec.get('column', 0) + i for i in range(spec['frames'])])
    with Image.open(source) as sheet:
        if row.get('pose_frame_rects'):
            # Restore the common anatomical canvas before the shared idle crop.
            # Per-frame storage trims must not normalize breathing or foot lift.
            from integrate_fluid_creature_animation import old_pose
            frames = []
            for i in indices:
                pose, (x, y) = old_pose(sheet, row, i)
                frame = Image.new('RGBA', (width, height))
                frame.paste(pose, (row.get('pose_anchor_x', width//2)+x,
                                   height-row.get('pose_ground_margin', 0)+y))
                frames.append(frame)
        else:
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
    # One row past Godot's 16384 px texture limit fails to load (a wide 62-frame
    # H3 idle reached 26412), so such a loop wraps into rows at most 4096 px wide.
    columns = len(frames) if fw * len(frames) <= 16384 else max(1, 4096 // fw)
    strip = Image.new('RGBA', (fw * columns, fh * -(-len(frames) // columns)))
    for i, frame in enumerate(frames):
        strip.paste(frame.crop(crop), (i % columns * fw, i // columns * fh))
    entry = {
        'path': 'res://art/overworld/runtime/creature_idle/' + row['id'] + '.png',
        'frame_size': [fw, fh], **({'columns': columns} if columns < len(frames) else {}), 'frames': len(frames),
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
        write_strip(strip, entry)
        units[row['unit_id']] = entry
    MANIFEST.write_text(json.dumps({
        'schema_id': 'overworld_creature_idle_v1',
        'preparation_tool': 'tools/pack_overworld_creature_idle.py',
        'policy': POLICY,
        'units': units,
    }, indent=2) + '\n', encoding='utf-8')
    print(f'Packed {len(units)} creature idle strips; {sum(p.stat().st_size for p in DESTINATION.glob("*.png")):,} bytes.')


if __name__ == '__main__':
    main()
